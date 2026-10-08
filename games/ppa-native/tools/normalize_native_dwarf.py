#!/usr/bin/env python3
"""Native-only Dwarf.glb rig correction.

The production PPA 2026-10-02 GLB contains a Blender hand-attachment export
error: DwarfCannon has local Y=24.171129 while dwarf bone translations occupy
~0.1-0.6. The cannon's offset expands the model bounds by >10x, so fitting a
model by visible bounds shrinks the dwarf into a speck.

Correct the static cannon child translation in original GLB coordinates.
No mesh vertex, skeleton, material, skin or animation samples are modified.
The cannon continues following the real left-hand bone in Idle/Run/Attack.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

SOURCE_SHA = "8b31dcbfd66f3c88fc5429da0adc35345d8c1a80412558c5a2567d5124f8ea81"
PATCHED_SHA = "0608fc70a602ebd0196f42ea2d19ef3779d7c129110e0d7dbc8104add340a747"
GLB_JSON = 0x4E4F534A


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    source = args.path.read_bytes()
    if hashlib.sha256(source).hexdigest() != SOURCE_SHA:
        raise ValueError("Dwarf GLB changed; do not patch an unknown rig")
    if len(source) < 20 or struct.unpack_from("<4sII", source) != (b"glTF", 2, len(source)):
        raise ValueError("Invalid glTF 2.0 container")

    chunks = []
    cursor = 12
    while cursor < len(source):
        byte_length, kind = struct.unpack_from("<II", source, cursor)
        cursor += 8
        payload = source[cursor:cursor+byte_length]
        if len(payload) != byte_length or byte_length % 4:
            raise ValueError("Invalid GLB chunk")
        chunks.append((kind, payload))
        cursor += byte_length
    if cursor != len(source) or len(chunks) < 2 or chunks[0][0] != GLB_JSON:
        raise ValueError("Missing glTF JSON/BIN")

    gltf = json.loads(chunks[0][1])
    nodes = gltf["nodes"]
    by_name = {node.get("name"): i for i, node in enumerate(nodes)}
    cannon_index = by_name["DwarfCannon"]
    hand_index = by_name["mixamorig:LeftHand"]
    if cannon_index not in nodes[hand_index].get("children", []):
        raise ValueError("Dwarf cannon is no longer attached to the left hand")
    cannon = nodes[cannon_index]
    original = list(cannon["translation"])
    if not math.isclose(original[1], 24.17112922668457, abs_tol=0.001):
        raise ValueError("Unexpected exporter cannon offset")
    if not math.isclose(cannon["scale"][0], 0.7, abs_tol=0.001):
        raise ValueError("Unexpected cannon mesh scale")

    animated = {
        channel.get("target", {}).get("node")
        for clip in gltf["animations"] for channel in clip["channels"]
    }
    if cannon_index in animated:
        raise ValueError("Cannot alter an animated attachment")
    clip_names = {a.get("name", "").lower() for a in gltf["animations"]}
    if not {"idle", "run", "attack"}.issubset(clip_names):
        raise ValueError("Skinned rig animation set changed")

    # Correct to hand-centred, original-GLB bone-local coordinates. X/Z, gun
    # rotation, scale and bone attachment remain untouched.  -0.12 positions
    # the long cannon within the model's foot-to-head extent in bind rest.
    cannon["translation"][1] = -0.12
    encoded = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    encoded += b" " * (-len(encoded) % 4)
    chunks[0] = (GLB_JSON, encoded)
    body = b"".join(struct.pack("<II", len(data), kind) + data for kind, data in chunks)
    output = struct.pack("<4sII", b"glTF", 2, 12+len(body)) + body
    actual = hashlib.sha256(output).hexdigest()
    if actual != PATCHED_SHA:
        raise ValueError("Patched asset differs from the audited native GLB: " + actual)

    args.path.write_bytes(output)
    print("PPA_NATIVE_DWARF_RIG_FIXED", "original local", original,
          "corrected local", cannon["translation"], "clips", sorted(clip_names),
          "sha256", actual, "bytes", len(output))


if __name__ == "__main__":
    main()
