#!/usr/bin/env bash
# Bump the game version everywhere it lives: tools/set_version.sh 0.2.0
# (Android also gets a version code, 10000 * major + 100 * minor + patch:
# a phone only installs an update whose code is higher.)
set -euo pipefail
v=${1:?usage: set_version.sh X.Y.Z}
[[ $v =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not a version: $v" >&2; exit 1; }
cd "$(dirname "$0")/.."
IFS=. read -r major minor patch <<< "$v"
code=$(( major * 10000 + minor * 100 + patch ))
sed -i "s/^const VERSION := \".*\"/const VERSION := \"$v\"/" scripts/core/version.gd
sed -i "s/^config\/version=\".*\"/config\/version=\"$v\"/" project.godot
sed -i "s/^version\/code=.*/version\/code=$code/" export_presets.cfg
grep -h 'VERSION :=\|config/version' scripts/core/version.gd project.godot
grep -h '^version/code=' export_presets.cfg | sort -u
grep -q "^## $v " CHANGELOG.md || echo "remember: CHANGELOG.md needs a '## $v' section (the release notes come from it)"
