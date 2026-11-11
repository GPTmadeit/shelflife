#!/usr/bin/env bash
# Render a screenshot on a hidden Hyprland workspace so it never takes over the
# desktop. User data is isolated in build/dev/xdg (never the real save).
# usage: tests/shot.sh <out.png> <seconds> [args after --]
set -euo pipefail
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" | head -1)
  export HYPRLAND_INSTANCE_SIGNATURE
fi
D=$(cd "$(dirname "$0")/.." && pwd)
out=$(realpath -m "$1"); secs=$2; shift 2
log="${out%.png}.log"
xdg="$D/build/dev/xdg"
mkdir -p "$xdg" "$(dirname "$out")"
case "$xdg" in "$D"/build/dev/xdg) ;; *) echo "bad xdg dir: $xdg"; exit 1 ;; esac
rm -f "$out" "$log"
cmd="XDG_DATA_HOME=$xdg godot --path $D --resolution ${RES:-1600x900} ${GODOT_ARGS:-} -- --shot $out $secs $* > $log 2>&1"
hyprctl dispatch "hl.dsp.exec_cmd(\"$cmd\", { workspace = \"special:shelfdev silent\" })" >/dev/null
for _ in $(seq 1 $(( ${secs%.*} * 6 + 240 ))); do
  grep -qE "shot saved|avg fps" "$log" 2>/dev/null && break
  sleep 0.5
done
grep -E "ERROR|SCRIPT|Parse|avg fps|shot saved|WARNING" "$log" | grep -v "^$" | head -30 || true
