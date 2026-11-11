#!/usr/bin/env python3
"""Prints a release's notes: .github/release-notes.md with the version's
CHANGELOG.md section and the download sizes filled in.

usage: tools/release_notes.py <version>   (run from the project root, after tools/package.sh)
"""
import json
import re
import sys

version = sys.argv[1]
template = open(".github/release-notes.md", encoding="utf-8").read()
changelog = open("CHANGELOG.md", encoding="utf-8").read()
section = re.search(rf"^## {re.escape(version)} .*?\n(.*?)(?=^## |\Z)", changelog, re.S | re.M)
if not section:
    sys.exit(f"CHANGELOG.md has no '## {version}' section")
manifest = json.load(open("dist/manifest.json", encoding="utf-8"))
notes = template.replace("{{VERSION}}", version).replace("{{CHANGES}}", section.group(1).strip())
for plat, entry in manifest["platforms"].items():
    notes = notes.replace("{{%s_SIZE}}" % plat.upper(), "%.0f MB" % (entry["zip"]["size"] / 1048576))
leftover = re.findall(r"\{\{\w+\}\}", notes)
if leftover:
    sys.exit(f"unfilled placeholders: {leftover}")
print(notes.strip())
