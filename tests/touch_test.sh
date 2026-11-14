#!/usr/bin/env bash
# The touch controls drive the game. A thumb on the stick walks Baker right
# and the JUMP button jumps; then, with the first thumb still on the stick, a
# second finger held on the screen reads through the conversation that
# starts (fast-forwarding it), which Godot's own touch-to-mouse couldn't do.
# And tapping the Talk bubble over someone's head starts a conversation.
#
#   tests/touch_test.sh       (GAME=path/to/ShelfLife.x86_64 tests an export)
set -euo pipefail
cd "$(dirname "$0")/.."
run() {
  local data
  data=$(mktemp -d)
  # shellcheck disable=SC2086
  XDG_DATA_HOME=$data timeout 180 ${GAME:-godot --path .} --headless -- "$@" 2>&1 || true
  rm -rf "$data"
}
fail() { echo "TOUCH TEST FAILED: $1" >&2; exit 1; }

out=$(run --cp start --flags intro_done --touch-act "move>+130,0@1-3;jump@1.6-1.9" --trace --quit 3.4)
read -r x0 y0 < <(awk -F'[(,)]' '/^t=.* pos=/ { print $2 + 0, $3 + 0; exit }' <<< "$out")
read -r xmax ymax < <(awk -F'[(,)]' '/^t=.* pos=/ { if ($2 + 0 > x) x = $2 + 0; if ($3 + 0 > y) y = $3 + 0 } END { print x, y }' <<< "$out")
echo "walked from x=$x0 to $xmax, highest y=$ymax (from $y0)"
awk -v a="$x0" -v b="$xmax" 'BEGIN { exit !(b - a > 5) }' || fail "the stick didn't walk Baker right"
awk -v a="$y0" -v b="$ymax" 'BEGIN { exit !(b - a > 0.8) }' || fail "the JUMP button didn't jump"

out=$(run --cp start --flags intro_done --touch-act "move>+130,0@1-9;800,300@4-7" --trace --quit 8)
lines=$(grep -c '^SAY ' <<< "$out" || true)
echo "a second finger read $lines lines"
[ "$lines" -ge 5 ] || fail "a second finger didn't read through the conversation ($lines lines)"

out=$(run --cp start --flags intro_done --touch-act "bubble@1.5-1.6" --trace --quit 3)
grep -q '^SAY ' <<< "$out" || fail "tapping the Talk bubble didn't start a conversation"
echo "the Talk bubble started: $(grep -m1 '^SAY ' <<< "$out")"
echo "TOUCH TEST PASSED"
