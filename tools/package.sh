#!/usr/bin/env bash
# Builds everything a release ships into dist/:
#   ShelfLife-<platform>-x86_64.zip     the game: engine + ShelfLife.pck + NOTICES.txt
#   shelflife-<version>-<platform>.pck  the game file alone, for the in-game updater
#   ShelfLife-android-<arch>.apk        the Android game (arm64 for phones, x86_64 for
#                                       Chromebooks and emulators), signed with the release key
#   manifest.json                       what the updater reads (sizes and SHA-256 sums)
#   SHA256SUMS.txt
# With --testkit DIR it also exports each platform's game file as version
# 0.0.0 to DIR/<platform>/ShelfLife.pck, for tools/update_test.sh, and a 0.0.0
# x86_64 APK to DIR/android/, for tools/android_update_test.sh. That APK has
# its test arguments built in (release APKs take none from outside).
#
# The APKs are signed with the key in GODOT_ANDROID_KEYSTORE_RELEASE_PATH
# (_USER is the alias, _PASSWORD its password); without those it reads
# ~/.config/shelflife/keystore.properties. The key never goes in the repo,
# and every APK's certificate has to match tools/android-cert.sha256.
#
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
declare -A APK_PRESET=([arm64]="Android" [x86_64]="Android x86_64")

if [ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]; then
  props=${SHELFLIFE_KEYSTORE_PROPERTIES:-$HOME/.config/shelflife/keystore.properties}
  [ -f "$props" ] || { echo "no Android signing key: set GODOT_ANDROID_KEYSTORE_RELEASE_* or write $props" >&2; exit 1; }
  GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$(grep '^path=' "$props" | cut -d= -f2-)
  GODOT_ANDROID_KEYSTORE_RELEASE_USER=$(grep '^alias=' "$props" | cut -d= -f2-)
  GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$(grep '^password=' "$props" | cut -d= -f2-)
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
fi
sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}
apksigner=$(ls -d "$sdk"/build-tools/*/apksigner 2> /dev/null | sort -V | tail -1)
[ -x "$apksigner" ] || { echo "apksigner not found under $sdk/build-tools" >&2; exit 1; }
want_cert=$(tr -d ' \n' < tools/android-cert.sha256)
# The APK has to carry the release key's certificate, or Android won't take
# it as an update of the installed game.
check_apk() {
  "$apksigner" verify "$1" > /dev/null || { echo "$1 doesn't verify" >&2; exit 1; }
  got=$("$apksigner" verify --print-certs "$1" | grep -m1 'certificate SHA-256 digest' | awk '{print $NF}')
  [ "$got" = "$want_cert" ] || { echo "$1 is signed with $got, not the release key ($want_cert)" >&2; exit 1; }
}

rm -rf build/linux build/windows build/android dist
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
mkdir -p build/android
for a in arm64 x86_64; do
  apk="build/android/ShelfLife-android-$a.apk"
  gd --headless --path . --export-release "${APK_PRESET[$a]}" "$root/$apk"
  [ -s "$apk" ] || { echo "export is missing $apk" >&2; exit 1; }
  check_apk "$apk"
  cp "$apk" dist/
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
  # the Android one checks a local server (tools/android_update_test.sh forwards
  # the port to the device) and installs whatever it finds, with no title screen
  sed -i 's/^version\/code=.*/version\/code=1/' "$tmp/export_presets.cfg"
  sed -i 's|^command_line/extra_args=.*|command_line/extra_args="-- --update-now --update-url http://127.0.0.1:47613/manifest.json"|' "$tmp/export_presets.cfg"
  mkdir -p "$kit/android"
  gd --headless --path "$tmp" --export-release "Android x86_64" "$kit/android/ShelfLife-0.0.0-x86_64.apk"
  [ -s "$kit/android/ShelfLife-0.0.0-x86_64.apk" ] || { echo "test kit export failed for android" >&2; exit 1; }
  check_apk "$kit/android/ShelfLife-0.0.0-x86_64.apk"
  rm -f "$kit"/android/*.idsig
fi
ls -la dist
