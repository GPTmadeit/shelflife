#!/usr/bin/env bash
# Bump the game version everywhere it lives: tools/set_version.sh 0.2.0
set -euo pipefail
v=${1:?usage: set_version.sh X.Y.Z}
[[ $v =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not a version: $v" >&2; exit 1; }
cd "$(dirname "$0")/.."
sed -i "s/^const VERSION := \".*\"/const VERSION := \"$v\"/" scripts/core/version.gd
sed -i "s/^config\/version=\".*\"/config\/version=\"$v\"/" project.godot
grep -h 'VERSION :=\|config/version' scripts/core/version.gd project.godot
grep -q "^## $v " CHANGELOG.md || echo "remember: CHANGELOG.md needs a '## $v' section (the release notes come from it)"
