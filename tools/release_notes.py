#!/usr/bin/env python3
"""Prints a release's notes: .github/release-notes.md with the version's
CHANGELOG.md section and the download sizes filled in. Earlier patch releases
of the same minor version are listed under it, so the latest release page
still says what that line of releases brought (0.2.3 still mentions Act Two).

usage: tools/release_notes.py <version>   (run from the project root, after tools/package.sh)
"""
import json
import re
import sys

version = sys.argv[1]
template = open(".github/release-notes.md", encoding="utf-8").read()
changelog = open("CHANGELOG.md", encoding="utf-8").read()
sections = [(m.group(1), m.group(2).strip())
            for m in re.finditer(r"^## (\d+\.\d+\.\d+) .*?\n(.*?)(?=^## |\Z)", changelog, re.S | re.M)]
current = [body for v, body in sections if v == version]
if not current:
    sys.exit(f"CHANGELOG.md has no '## {version}' section")
changes = current[0]
major, minor, patch = (int(x) for x in version.split("."))
earlier = [(v, body) for v, body in sections
           if v.split(".")[:2] == [str(major), str(minor)] and int(v.split(".")[2]) < patch]
if earlier:
    changes += f"\n\n### Earlier in {major}.{minor}\n\n" + "\n\n".join(f"**{v}**\n\n{body}" for v, body in earlier)
manifest = json.load(open("dist/manifest.json", encoding="utf-8"))
notes = template.replace("{{VERSION}}", version).replace("{{CHANGES}}", changes)
for plat, entry in manifest["platforms"].items():
    download = entry.get("zip") or entry["apk"]   # what a player downloads for that system
    notes = notes.replace("{{%s_SIZE}}" % plat.upper().replace("-", "_"), "%.0f MB" % (download["size"] / 1048576))
leftover = re.findall(r"\{\{\w+\}\}", notes)
if leftover:
    sys.exit(f"unfilled placeholders: {leftover}")
print(notes.strip())
