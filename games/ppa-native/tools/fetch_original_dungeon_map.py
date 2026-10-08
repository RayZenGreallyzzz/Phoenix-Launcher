#!/usr/bin/env python3
"""Fetch original approved PPA dungeon floor composite and exact walk-mask.

No procedural map generation and no writes to production PPA. The floor
matches build.mjs /assets/dungeon-layout-test.webp, including its dark exterior
and smooth buffer band. The mask is pinned to the approved Git blob SHA.
"""
from pathlib import Path
from urllib.request import Request, urlopen
import hashlib
import struct

DEST = Path(__file__).resolve().parents[1] / "assets"
HOST = "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
MAP_URL = HOST + "/assets/dungeon-layout-test.webp"
MASK_URL = ("https://raw.githubusercontent.com/"
            "RayZenGreallyzzz/ppa-phoenixpixarena/main/"
            "%D0%BC%D0%B0%D1%81%D0%BA%D0%B0s.png")
MASK_GIT_SHA = "8e1ba40111c0866bc1557963bf593f284b0018ad"

def fetch(uri):
    request = Request(uri, headers={"User-Agent": "PPA-Godot-Original-Dungeon/1"})
    with urlopen(request, timeout=100) as response:
        return response.read(45000000)

def git_blob_hash(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()

def main():
    DEST.mkdir(parents=True, exist_ok=True)
    mask = fetch(MASK_URL)
    if mask[:8] != bytes.fromhex("89504e470d0a1a0a"):
        raise ValueError("Original mask isn't PNG")
    if git_blob_hash(mask) != MASK_GIT_SHA:
        raise ValueError("Approved PPA mask has changed; re-audit before rebuilding")
    mw, mh = struct.unpack_from(">II", mask, 16)
    if not (1024 <= mw <= 12000 and 500 <= mh <= 10000):
        raise ValueError("Unexpected mask dimensions %sx%s" % (mw, mh))
    floor = fetch(MAP_URL)
    if len(floor) < 10000 or floor[:4] != b"RIFF" or floor[8:12] != b"WEBP":
        raise ValueError("Dungeon layout image was not supplied as WebP")
    # Full original output is 4096px wide, generated from the exact mask.
    # Dimension and decoded artwork are validated by Godot import + native UI.
    if not (10000 < len(floor) < 45000000):
        raise ValueError("Unexpected PPA dungeon art size")
    (DEST / "dungeon_walk_mask.png").write_bytes(mask)
    (DEST / "dungeon_layout.webp").write_bytes(floor)
    print("PPA_ORIGINAL_DUNGEON_ASSETS_OK",
          "mask=%sx%s" % (mw, mh),
          "mask_sha1=" + MASK_GIT_SHA,
          "floor_bytes=" + str(len(floor)),
          "floor_sha256=" + hashlib.sha256(floor).hexdigest(), flush=True)

if __name__ == "__main__":
    main()
