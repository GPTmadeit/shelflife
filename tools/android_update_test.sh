#!/usr/bin/env bash
# End-to-end self-update test on Android. A fresh 0.0.0 install (the test
# kit's APK from tools/package.sh --testkit) finds the update on a local
# server, downloads the APK, checks it and hands it to Android's installer.
# This script then presses the installer's Update button, as a player would.
# Afterwards the phone has to hold the release's exact APK, and the new
# version has to know it was updated from 0.0.0.
#
#   ANDROID_SERIAL=emulator-5554 tools/android_update_test.sh <dist> <testkit>
#
# Needs an x86_64 Android 8+ emulator (or phone) on adb, and uninstalls Shelf
# Life from it first. The game's log goes to logcat (tag "godot"); when the
# test fails, the whole device log is left in android-logcat.txt.
set -euo pipefail
dist=$(realpath "$1"); kit=$(realpath "$2")
pkg=com.gptmadeit.shelflife
port=47613   # baked into the test kit's APK; adb reverse brings it to this machine
adb=${ADB:-adb}
py=$(command -v python3)
v=$("$py" -c 'import json, sys; print(json.load(open(sys.argv[1]))["version"])' "$dist/manifest.json")
want=$(sha256sum "$dist/ShelfLife-android-x86_64.apk" | cut -d' ' -f1)
work=$(mktemp -d)
server=""
cleanup() {
  if [ -n "$server" ]; then kill "$server" 2> /dev/null || true; fi
  $adb reverse --remove "tcp:$port" > /dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT
log() { $adb logcat -d -s godot:V; }
fail() {
  echo "ANDROID UPDATE TEST FAILED: $1" >&2
  $adb logcat -d > android-logcat.txt 2> /dev/null || true
  grep -E "godot|Godot|shelflife|AndroidRuntime|FATAL|DEBUG|libEGL|EGL_|GLES|ActivityTaskManager|ActivityManager: (Start|Kill|Process)" android-logcat.txt \
    | grep -vE "SceneShader|Program linking|exceed GL_MAX|^\s*$" | tail -80 >&2 || true
  exit 1
}

# Where on screen a clickable thing is: Android's "isn't responding" dialog's
# Wait button ("anr x y"), its first-time "Viewing full screen" hint's Got it
# ("hint x y"), or else the installer's Update/Install ("button x y").
find_button() {
  $adb shell uiautomator dump /sdcard/shelflife-ui.xml > /dev/null 2>&1 || true
  $adb shell cat /sdcard/shelflife-ui.xml > "$work/ui.xml" 2> /dev/null || true
  "$py" - "$work/ui.xml" << 'PY'
import re, sys
xml = open(sys.argv[1], encoding="utf-8", errors="replace").read()
def center(node):
    x1, y1, x2, y2 = map(int, re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', node).groups())
    return "%d %d" % ((x1 + x2) // 2, (y1 + y2) // 2)
nodes = re.findall(r"<node [^>]*>", xml)
for node in nodes:
    if 'resource-id="android:id/aerr_wait"' in node:
        print("anr", center(node))
        sys.exit()
for node in nodes:
    if 'resource-id="android:id/ok"' in node and 'package="android"' in node:
        print("hint", center(node))
        sys.exit()
for node in nodes:
    text = re.search(r' text="([^"]*)"', node)
    if text and text.group(1).strip().lower() in ("update", "install") and 'clickable="true"' in node:
        print("button", center(node))
        sys.exit()
PY
}

# A freshly booted emulator is busy for a minute or two: "System UI isn't
# responding" can cover the screen, and early configuration changes (the SIM
# showing up) can close the game before it gets going. Give it a moment, say
# Wait to those dialogs, and start the game again if it didn't start.
settle() {
  for _ in $(seq "${1:-5}"); do
    read -r kind x y <<< "$(find_button)" || true
    if [ "${kind:-}" = anr ]; then
      echo "(Android said something isn't responding: waiting)"
      $adb shell input tap "$x" "$y"
    elif [ "${kind:-}" = hint ]; then
      echo "(Android's first-time full-screen hint: Got it)"
      $adb shell input tap "$x" "$y"
    fi
    sleep 2
  done
}

"$py" -m http.server "$port" --bind 127.0.0.1 --directory "$dist" > "$work/http.log" 2>&1 &
server=$!
$adb reverse "tcp:$port" "tcp:$port" > /dev/null
$adb uninstall "$pkg" > /dev/null 2>&1 || true
$adb install "$kit/android/ShelfLife-0.0.0-x86_64.apk" > /dev/null
# what a player allows when Android first asks: "Install unknown apps" for Shelf Life
$adb shell appops set "$pkg" REQUEST_INSTALL_PACKAGES allow
settle 10
echo "== android: 0.0.0 -> $v"

# the old version finds the update, downloads and checks it, and opens the installer
opened=""
for attempt in 1 2 3; do
  $adb logcat -c
  $adb shell am start -n "$pkg/com.godot.game.GodotAppLauncher" > /dev/null
  for i in $(seq 150); do
    if log | grep -q '\[update\] open installer'; then opened=1; break; fi
    if log | grep -q '\[update\] FAILED'; then fail "$(log | grep -m1 '\[update\] FAILED')"; fi
    if [ "$i" -ge 45 ] && ! log | grep -q '\[update\] 0.0.0 start'; then break; fi
    sleep 1
  done
  [ -n "$opened" ] && break
  echo "(the game didn't get going, attempt $attempt: starting it again)"
  $adb shell am force-stop "$pkg"
  settle 5
done
[ -n "$opened" ] || fail "the old version never opened the installer"
log | grep -q '\[update\] install apk' || fail "the APK wasn't downloaded"

# press Update (or Install) in Android's installer
pressed=""
for _ in $(seq 60); do
  read -r kind x y <<< "$(find_button)" || true
  if [ "${kind:-}" = anr ]; then
    echo "(Android said something isn't responding: waiting)"
    $adb shell input tap "$x" "$y"
  elif [ "${kind:-}" = hint ]; then
    echo "(Android's first-time full-screen hint: Got it)"
    $adb shell input tap "$x" "$y"
  elif [ "${kind:-}" = button ]; then
    $adb shell input tap "$x" "$y"
    pressed=1
    break
  fi
  sleep 1
done
[ -n "$pressed" ] || fail "Android's installer never showed an Update button"

have=""
for _ in $(seq 120); do
  have=$($adb shell dumpsys package "$pkg" | grep -m1 'versionName=' | sed 's/.*versionName=//' | tr -d '\r')
  [ "$have" = "$v" ] && break
  sleep 1
done
[ "$have" = "$v" ] || fail "the installed version is '$have', not $v"
apk=$($adb shell pm path "$pkg" | head -1 | sed 's/^package://' | tr -d '\r')
$adb pull "$apk" "$work/installed.apk" > /dev/null
[ "$(sha256sum "$work/installed.apk" | cut -d' ' -f1)" = "$want" ] || fail "the installed APK isn't the release's"

# the new version starts and knows where it came from (saves and settings stay put)
ok=""
for attempt in 1 2 3; do
  $adb logcat -c
  $adb shell am start -n "$pkg/com.godot.game.GodotAppLauncher" > /dev/null
  for _ in $(seq 45); do
    if log | grep -q "\[update\] updated from 0.0.0 to $v"; then ok=1; break; fi
    sleep 1
  done
  [ -n "$ok" ] && break
  $adb shell am force-stop "$pkg"
  settle 5
done
[ -n "$ok" ] || fail "the new version didn't say it was updated from 0.0.0"
$adb shell am force-stop "$pkg"
$adb shell am force-stop com.google.android.packageinstaller > /dev/null 2>&1 || true   # its "App installed" window
echo "ANDROID UPDATE TEST PASSED: 0.0.0 -> $v through Android's installer"
