#!/usr/bin/env bash
# End-to-end self-update test. A fresh install whose game file says 0.0.0
# updates itself, restarts, and has to come back as the release's version
# with the release's exact files in place.
#
#   tools/update_test.sh <linux|windows> <dist> <testkit> <pck|zip|github>
#
#   pck     serve <dist> on 127.0.0.1; the normal update (game file only)
#   zip     same, but force the whole-zip path (engine + game)
#   github  update from the real latest release on GitHub; <dist> only needs
#           that release's manifest.json and zip
# <testkit> comes from tools/package.sh --testkit. Runs on Linux and in Git
# Bash on Windows. User data goes to a temporary folder, never the real one.
set -euo pipefail
plat=$1; dist=$(realpath "$2"); kit=$(realpath "$3"); mode=${4:-pck}
py=$(command -v python3 || command -v python)
native() { if command -v cygpath > /dev/null; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
exe=ShelfLife.x86_64
[ "$plat" = windows ] && exe=ShelfLife.exe
field() { "$py" -c $'import json, sys\nm = json.load(open(sys.argv[1]))\nfor k in sys.argv[2].split("."):\n    m = m[k]\nprint(m)' "$dist/manifest.json" "$1"; }
v=$(field version)

work=$(mktemp -d)
case "$work" in /*) ;; *) echo "bad temp dir: $work" >&2; exit 1 ;; esac
game="$work/game"
"$py" -m zipfile -e "$dist/ShelfLife-$plat-x86_64.zip" "$game"
cp "$kit/$plat/ShelfLife.pck" "$game/ShelfLife.pck"
chmod +x "$game/$exe"
mkdir -p "$work/data"
export XDG_DATA_HOME="$work/data"           # Linux user folder
export APPDATA; APPDATA=$(native "$work/data")  # Windows user folder
log="$work/update.log"
args=(--headless -- --update-now --update-log "$(native "$log")")

server=""
first=""
cleanup() { for p in $server $first; do kill "$p" 2> /dev/null || true; done; }
trap cleanup EXIT
if [ "$mode" != github ]; then
  port=$(( 20000 + RANDOM % 20000 ))
  "$py" -m http.server "$port" --bind 127.0.0.1 --directory "$dist" > "$work/http.log" 2>&1 &
  server=$!
  for _ in $(seq 50); do
    "$py" -c 'import sys,urllib.request; urllib.request.urlopen(sys.argv[1], timeout=1)' "http://127.0.0.1:$port/manifest.json" 2> /dev/null && break
    sleep 0.2
  done
  args+=(--update-url "http://127.0.0.1:$port/manifest.json")
fi
[ "$mode" = zip ] && args+=(--update-full)

echo "== $plat, $mode: 0.0.0 -> $v"
MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$game/$exe" "${args[@]}" > "$work/first.out" 2>&1 &
first=$!
# The first copy installs the update and restarts itself into the new
# version, which checks again and quits. Give the whole thing four minutes.
for _ in $(seq 240); do
  if [ -f "$log" ]; then
    after=$(sed -n "/^$v start/,\$p" "$log")
    if grep -qE "^(LATEST|FAILED)" <<< "$after"; then break; fi
    if [ -z "$after" ] && grep -q "^FAILED" "$log"; then break; fi
  fi
  sleep 1
done
sleep 2
echo "-- update log"; cat "$log" || true
fail() { echo "UPDATE TEST FAILED ($plat, $mode): $1" >&2; echo "-- first run output"; tail -40 "$work/first.out" >&2 || true; ls -la "$game" >&2; exit 1; }
grep -q "^0.0.0 start" "$log" || fail "the old version never ran"
grep -q "^AVAILABLE" "$log" || fail "the update wasn't found"
grep -q "^RESTARTING" "$log" || fail "the update didn't install"
grep -q "^$v start" "$log" || fail "the new version didn't start"
grep -q "^updated from 0.0.0" "$log" || fail "the new version didn't know it was updated"
sed -n "/^$v start/,\$p" "$log" | grep -q "^LATEST" || fail "the new version doesn't think it's up to date"
sha() { sha256sum "$1" | cut -d' ' -f1; }
[ "$(sha "$game/ShelfLife.pck")" = "$(field "platforms.$plat.pck.sha256")" ] || fail "the installed game file isn't the release's"
[ "$(sha "$game/$exe")" = "$(field "platforms.$plat.exe.sha256")" ] || fail "the installed engine isn't the release's"
want="install pck"
[ "$mode" = zip ] && want="install zip"
grep -q "^$want" "$log" || fail "expected the '$want' path"
leftovers=$(ls "$game" | grep -E '\.(part|new)$' || true)
[ -z "$leftovers" ] || fail "temporary files left behind: $leftovers"
echo "UPDATE TEST PASSED ($plat, $mode): $(grep '^install' "$log")"
rm -rf "$work" 2> /dev/null || true   # Windows may still be closing the last copy
