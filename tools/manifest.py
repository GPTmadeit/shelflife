#!/usr/bin/env python3
"""Writes dist/manifest.json, which the in-game updater reads (scripts/core/updater.gd).

usage: tools/manifest.py <version> <engine>   (run from the project root after the exports)
"""
import hashlib
import json
import os
import sys

version, engine = sys.argv[1], sys.argv[2]
EXE = {"linux": "ShelfLife.x86_64", "windows": "ShelfLife.exe"}
APK = {"android-arm64": "ShelfLife-android-arm64.apk", "android-x86_64": "ShelfLife-android-x86_64.apk"}


def spec(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return {"file": os.path.basename(path), "size": os.path.getsize(path), "sha256": h.hexdigest()}


manifest = {"game": "Shelf Life", "version": version, "engine": engine, "platforms": {}}
for plat, exe in EXE.items():
    manifest["platforms"][plat] = {
        "pck": spec(f"dist/shelflife-{version}-{plat}.pck"),   # the game alone
        "zip": spec(f"dist/ShelfLife-{plat}-x86_64.zip"),       # engine + game
        "exe": spec(f"build/{plat}/{exe}"),                     # the engine, inside the zip
    }
for plat, apk in APK.items():
    # Android's names its processors like the engine does: android-<Engine.get_architecture_name()>
    manifest["platforms"][plat] = {"apk": spec(f"dist/{apk}")}
with open("dist/manifest.json", "w") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")
print(json.dumps(manifest, indent=2))
