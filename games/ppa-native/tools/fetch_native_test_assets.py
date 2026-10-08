#!/usr/bin/env python3
"""Fetch *exact* deployed PPA art for a private Android test gallery.

Original GLBs are pinned by sha256, as audited in GitHub Actions. Correct only
approved bone-local weapon positions which production Three.js replaces at
runtime. Preserve the original rig, mesh, materials and all animation clips.
Never modify the published PPA game or its player saves.
"""
import hashlib
import json
from pathlib import Path
import struct
import urllib.request

ROOT = Path(__file__).resolve().parents[1] / "assets"
BASE = "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
GLB_MODELS = {
    "tank": ("Tank_Mobile_Shield_Hammer_Final.glb", "5ebc5eb3bae8595819a862f8ec04d8faf678394c03d9992ae811e0d14fe0b42f"),
    "barbarian": ("Berserker_Final.glb", "20fcf5aef61c1e51303fd03017cc8dca44704fdbc6cee444179a102c76e704c6"),
    "paladin": ("Paladin_Final.glb", "e6ac570794c2d0cf6b379ee71080933a31bf5fb403698cdd4a21a8eedfb5a552"),
    "archer": ("Ranger_Mobile_Bow_Z90.glb", "0cbddd8acc6506388299d54bcf106a117a69d11617fab77ea04296b3b4cbbb28"),
    "mage": ("Mage_Final.glb", "26deef0f8ed53e0a5d36aca5390b4dda61e01e22ef3092ef7a3af6732aafe1c5"),
    "assassin": ("Assassin.glb", "9db56f879f5dab6b17a5caa0538387162ac976f583e3f3134f1b47eb383268cb"),
    "priest": ("Priest_Final_GitHub.glb", "32aad9468ccdfdf5375acd30473ac756cbbeb5235546f389c70c946e227be5cd")
}
# Positions are copied from applyApprovedWeaponPose() in live PPA.
# Only translation is corrected because the GLBs already carry the approved
# rotations and mesh scale. Parent links to hands must remain unmodified.
WEAPON_POSES = {
    # Production Three.js sets Dawnblade to [.31,.16,-.25] on RightHand.
    # Source GLB incorrectly exported Y=6.01708698; fix the actual source node
    # rather than adding a duplicate mesh or an overlay-time transform.
    "paladin": {
        "Dawnblade": ([0.31, 0.16, -0.25], "mixamorig:RightHand")
    },
    "barbarian": {
        "Embercleaver_Right": ([0.22, 0.30, 0.06], "mixamorig:RightHand"),
        "Embercleaver_Left": ([-0.28, 0.30, 0.06], "mixamorig:LeftHand")
    },
    "assassin": {
        "AssassinDagger_Right": ([-0.30, 0.15, 0.0], "mixamorig:RightHand"),
        "AssassinDagger_Left": ([-0.30, 0.15, 0.0], "mixamorig:LeftHand")
    },
    "priest": {
        "SunspireScepter": ([0.01, 0.12, 0.02], "mixamorig:RightHand")
    }
}
NPC_IMAGES = {
    "blacksmith": "a933cf293e178ce8.png",
    "storage": "b1d79c6c88b8add6.png",
    "auction": "fba48b0e5b3e9e7e.png",
    "arena": "6bad4d829ed1b7a3.png",
    "clan": "ff9207c640e47f8d.png",
    "merchant": "792ac1e215086a7c.png",
    "blackmarket": "1dc0efb6142292a8.png",
    "dungeon": "cd4c120b0c5831c8.png",
    "fartzone_guide": "9d06dac27cf50827.png"
}


def download(url: str) -> bytes:
    error = None
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "PPA-Native-Asset-CI/1"})
            with urllib.request.urlopen(req, timeout=90) as response:
                content = response.read(22_000_000)
            if len(content) < 128:
                raise ValueError(f"Unexpected empty source {url}")
            return content
        except Exception as exc:
            error = exc
            print("Asset download retry", attempt, url, repr(exc), flush=True)
    raise RuntimeError(f"Asset download failed {url}: {error}")


def patch_gltf(class_key: str, source: bytes) -> bytes:
    if source[:4] != b"glTF" or len(source) < 24:
        raise ValueError(f"Invalid GLB {class_key}")
    version, total = struct.unpack_from("<II", source, 4)
    if version != 2 or total != len(source):
        raise ValueError(f"Bad GLB header for {class_key}")
    chunks = []
    offset = 12
    while offset < len(source):
        size, kind = struct.unpack_from("<II", source, offset)
        offset += 8
        chunk = source[offset:offset + size]
        if len(chunk) != size or size % 4:
            raise ValueError(f"Broken chunk for {class_key}")
        chunks.append((kind, chunk))
        offset += size
    if offset != len(source) or chunks[0][0] != 0x4E4F534A:
        raise ValueError(f"Missing GLB JSON {class_key}")
    gltf = json.loads(chunks[0][1])
    nodes = gltf["nodes"]
    if not gltf.get("skins") or len(gltf.get("meshes", [])) < 2:
        raise ValueError(f"GLB has no skinned body/props: {class_key}")
    clips = {str(a.get("name", "")).lower() for a in gltf.get("animations", [])}
    if not {"idle", "run", "attack"} <= clips:
        raise ValueError(f"Animation clips missing in {class_key}: {clips}")
    names = {node.get("name"): i for i, node in enumerate(nodes)}
    parents = {}
    for i, node in enumerate(nodes):
        for child in node.get("children", []):
            parents[child] = i

    poses = WEAPON_POSES.get(class_key, {})
    for node_name, (pos, parent_name) in poses.items():
        idx = names.get(node_name)
        if idx is None or idx not in parents or nodes[parents[idx]].get("name") != parent_name:
            raise ValueError(f"Weapon bone attachment mismatch: {class_key}/{node_name}")
        animated = any(
            ch.get("target", {}).get("node") == idx
            for anim in gltf["animations"] for ch in anim.get("channels", [])
        )
        if animated:
            raise ValueError(f"Cannot overwrite animated weapon: {class_key}/{node_name}")
        old = nodes[idx].get("translation", [])
        if len(old) != 3:
            raise ValueError(f"No local weapon translation: {class_key}/{node_name}")
        if abs(old[0] - pos[0]) > .002 or abs(old[2] - pos[2]) > .002:
            raise ValueError(f"Unexpected XY/Z weapon coordinates: {class_key}/{node_name} {old}")
        if class_key == "paladin" and node_name == "Dawnblade":
            if abs(old[1] - 6.017086982727051) > 0.001:
                raise ValueError("Unknown paladin sword source transform: refusing to patch")
            expected_quat = (0.270598, 0.270598, 0.653282, 0.653281)
            rotation = nodes[idx].get("rotation", [])
            scale = nodes[idx].get("scale", [])
            if len(rotation) != 4 or max(abs(x - y) for x, y in zip(rotation, expected_quat)) > 0.00005:
                raise ValueError("Paladin sword rotation changed")
            if len(scale) != 3 or max(abs(x - .60) for x in scale) > .002:
                raise ValueError("Paladin sword scale changed")
        nodes[idx]["translation"] = pos[:]
        print("PPA_WEAPON_POSE_FIXED", class_key, node_name, old, "->", pos, flush=True)

    if not poses:
        return source
    json_data = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_data += b" " * (-len(json_data) % 4)
    chunks[0] = (0x4E4F534A, json_data)
    payload = b"".join(struct.pack("<II", len(data), kind) + data for kind, data in chunks)
    return struct.pack("<4sII", b"glTF", 2, 12 + len(payload)) + payload


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    for key, (filename, original_digest) in GLB_MODELS.items():
        url = BASE + "/game/" + filename + "?v=20261002u2"
        raw = download(url)
        sha = hashlib.sha256(raw).hexdigest()
        if sha != original_digest:
            raise ValueError(f"Official GLB changed {key}: {sha} != {original_digest}")
        corrected = patch_gltf(key, raw)
        dest = ROOT / f"hero_{key}.glb"
        dest.write_bytes(corrected)
        print("PPA_HERO_ASSET_OK", key, dest.stat().st_size,
              hashlib.sha256(corrected).hexdigest(), flush=True)

    for key, hashed_name in NPC_IMAGES.items():
        raw = download(BASE + "/assets/" + hashed_name)
        if raw[:8] != bytes.fromhex("89504e470d0a1a0a"):
            raise ValueError(f"NPC art not a PNG: {key}")
        width, height = struct.unpack(">II", raw[16:24])
        if not (16 <= width <= 2048 and 16 <= height <= 2048):
            raise ValueError(f"Unexpected NPC sprite size {key}: {width}x{height}")
        dest = ROOT / f"npc_{key}.png"
        dest.write_bytes(raw)
        print("PPA_NPC_SPRITE_OK", key, width, height,
              hashlib.sha256(raw).hexdigest(), flush=True)

    print("PPA_NATIVE_TEST_ASSETS_OK: 7 GLBs + 9 original 2D NPC art")


if __name__ == "__main__":
    main()
