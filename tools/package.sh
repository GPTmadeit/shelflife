#!/usr/bin/env bash
# Builds everything a release ships into dist/:
#   ShelfLife-<platform>-x86_64.zip     the game: engine + ShelfLife.pck + NOTICES.txt
#   shelflife-<version>-<platform>.pck  the game file alone, for the in-game updater
#   manifest.json                       what the updater reads (sizes and SHA-256 sums)
#   SHA256SUMS.txt
# With --testkit DIR it also exports each platform's game file as version
# 0.0.0 to DIR/<platform>/ShelfLife.pck, for tools/update_test.sh.
# usage: tools/package.sh [--testkit DIR]        (GODOT=/path/to/godot overrides)
set -euo pipefail
cd "$(dirname "$0")/.."
root=$PWD
GODOT=${GODOT:-godot}
# Each Godot step gets 15 minutes, so a stuck one fails the build instead of hanging it.
gd() { timeout 900 "$GODOT" "$@"; }
kit=""
if [ "${1:-}" = "--testkit" ]; then kit=$(realpath -m "${2:?--testkit needs a directory}"); fi
v=$(grep -oP 'VERSION := "\K[^"]+' scripts/core/version.gd)
engine=$("$GODOT" --version | cut -d. -f1-4)
declare -A EXE=([linux]=ShelfLife.x86_64 [windows]=ShelfLife.exe)
declare -A PRESET=([linux]=Linux [windows]=Windows)

rm -rf build/linux build/windows dist
mkdir -p build dist   # build/ isn't in git: a fresh checkout has neither
touch build/.gdignore # the editor leaves the exports alone
gd --headless --path . --script tools/notices.gd -- "$root/build/NOTICES.txt" > /dev/null
[ -s build/NOTICES.txt ] || { echo "NOTICES.txt wasn't written" >&2; exit 1; }
for p in linux windows; do
  mkdir -p "build/$p"
  gd --headless --path . --export-release "${PRESET[$p]}" "build/$p/${EXE[$p]}"
  for f in "${EXE[$p]}" ShelfLife.pck; do
    [ -s "build/$p/$f" ] || { echo "export is missing build/$p/$f" >&2; exit 1; }
  done
  cp build/NOTICES.txt "build/$p/"
  (cd "build/$p" && zip -q -9 -X "$root/dist/ShelfLife-$p-x86_64.zip" "${EXE[$p]}" ShelfLife.pck NOTICES.txt)
  cp "build/$p/ShelfLife.pck" "dist/shelflife-$v-$p.pck"
done
python3 tools/manifest.py "$v" "$engine" > /dev/null
(cd dist && sha256sum -- * > SHA256SUMS.txt)

if [ -n "$kit" ]; then
  # A copy of the project that calls itself 0.0.0. It lives outside the
  # project folder so Godot never sees two copies of every script.
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  tar --exclude=./build --exclude=./dist --exclude=./.git -cf - . | tar -xf - -C "$tmp"
  sed -i 's/^const VERSION := ".*"/const VERSION := "0.0.0"/' "$tmp/scripts/core/version.gd"
  sed -i 's/^config\/version=".*"/config\/version="0.0.0"/' "$tmp/project.godot"
  for p in linux windows; do
    mkdir -p "$kit/$p"
    gd --headless --path "$tmp" --export-pack "${PRESET[$p]}" "$kit/$p/ShelfLife.pck"
    [ -s "$kit/$p/ShelfLife.pck" ] || { echo "test kit export failed for $p" >&2; exit 1; }
  done
fi
ls -la dist
