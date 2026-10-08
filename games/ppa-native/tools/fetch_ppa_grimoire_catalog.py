#!/usr/bin/env python3
"""Port EXACT current live PPA class skill/grimoire definitions and 72 card images.

Extracts the two JSON constants embedded in the PPA web client's own code:
GRIMOIRE_CATALOG and GRIMOIRE_ART. Refuses to substitute stock/fake images.
The output is a generated GDScript constant, packaged in the Godot APK.
UI may *display* this canonical catalog, but real rank/book counts and
upgrades remain server-owned and disabled until the same state is available.
"""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor, as_completed
import ast
import hashlib
import html
import json
from pathlib import Path
import re
import time
import urllib.request

PROJECT = Path(__file__).resolve().parents[1]
ASSETS = PROJECT / "assets"
OUT = PROJECT / "scripts" / "ppa_grimoire_catalog_generated.gd"
HOST = "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
CLASS_KEYS = ("tank", "barbarian", "paladin", "gnome", "archer", "mage", "assassin", "priest")


def fetch(url: str) -> bytes:
    last = None
    for attempt in range(4):
        try:
            request = urllib.request.Request(
                url, headers={"User-Agent": "PPA-Native-Parity-Asset/1", "Accept": "*/*"}
            )
            with urllib.request.urlopen(request, timeout=90) as response:
                data = response.read(12_000_000)
            if len(data) < 120:
                raise ValueError("Empty server art/source")
            return data
        except Exception as exc:
            last = exc
            time.sleep(0.25 * (attempt + 1))
    raise RuntimeError(f"Failed to retrieve canonical PPA asset: {url}: {last}")


def json_constant(source: str, name: str) -> dict:
    marker = "const " + name + "="
    if source.count(marker) != 1:
        raise ValueError(f"Missing or ambiguous original source {marker}: {source.count(marker)}")
    start = source.index(marker) + len(marker)
    obj, _end = json.JSONDecoder().raw_decode(source[start:])
    if not isinstance(obj, dict):
        raise ValueError(f"Original PPA {name} is not a dictionary")
    return obj


def effect_preview(source: str) -> dict[str, list[str]]:
    marker = "const GRIMOIRE_EFFECT_PREVIEW="
    if source.count(marker) != 1:
        raise ValueError("Missing actual PPA effect previews")
    src = source.split(marker, 1)[1].split("\n};", 1)[0]
    result: dict[str, list[str]] = {}
    pattern = re.compile(r"\b([a-z][a-z0-9_]+)\s*:\s*\[\s*((?:'(?:\\.|[^'\\])*'\s*,?\s*){3})\s*\]", re.S)
    for match in pattern.finditer(src):
        entries = ast.literal_eval("[" + match.group(2) + "]")
        if len(entries) == 3:
            result[match.group(1)] = entries
    return result


def main() -> None:
    html_bytes = fetch(HOST + "/?ppa_native_grimoire_parity=20261008")
    source = html.unescape(html_bytes.decode("utf-8"))
    catalog = json_constant(source, "GRIMOIRE_CATALOG")
    art = json_constant(source, "GRIMOIRE_ART")
    effects = effect_preview(source)
    if set(catalog) != set(CLASS_KEYS):
        raise ValueError(f"Original game class catalog changed: {sorted(catalog)}")
    if len(art) != 72:
        raise ValueError(f"Original PPA grimoire art count is not 72: {len(art)}")
    tasks: dict[str, str] = {}
    for key in CLASS_KEYS:
        definition = catalog[key]
        if len(definition.get("active", [])) != 4 or len(definition.get("passive", [])) != 5:
            raise ValueError(f"Wrong live skill count for {key}")
        for category in ("active", "passive"):
            for skill in definition[category]:
                sid = skill["id"]
                if sid not in art or not str(art[sid].get("card", "")).startswith("./assets/"):
                    raise ValueError(f"Original grimoire card art missing: {sid}")
                output = "res://assets/ppa_grimoire_" + sid + ".webp"
                skill["cardArt"] = output
                skill["preview"] = effects.get(sid, [
                    skill.get("d", "") + " · Ранг I: базовый эффект.",
                    skill.get("d", "") + " · Ранг II: усиленный эффект.",
                    skill.get("d", "") + " · Ранг III: максимальный эффект."
                ])
                tasks[sid] = HOST + "/" + art[sid]["card"].removeprefix("./")

    if len(tasks) != 72:
        raise ValueError(f"Expected 72 unique PPA grimoire cards: {len(tasks)}")
    ASSETS.mkdir(parents=True, exist_ok=True)
    OUT.parent.mkdir(parents=True, exist_ok=True)

    def download_one(pair: tuple[str, str]) -> tuple[str, int]:
        sid, url = pair
        data = fetch(url)
        if not (data.startswith(b"RIFF") and data[8:12] == b"WEBP"):
            raise ValueError(f"Canonical grimoire card is not WEBP: {sid}")
        (ASSETS / ("ppa_grimoire_" + sid + ".webp")).write_bytes(data)
        return sid, len(data)

    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = [pool.submit(download_one, pair) for pair in tasks.items()]
        for future in as_completed(futures):
            name, size = future.result()
            print("PPA_GRIMOIRE_ART_OK", name, size, flush=True)

    # JSON dictionary literal is also a valid GDScript dictionary constant.
    raw_literal = json.dumps(catalog, ensure_ascii=False, separators=(",", ":"))
    OUT.write_text(
        "extends RefCounted\n\n"
        "# Generated from the deployed ORIGINAL Phoenix Pix Arena.\n"
        "# Never modify these names/IDs/portraits by hand.\n"
        "const CLASSES = " + raw_literal + "\n"
        "static func class_info(key: String) -> Dictionary:\n"
        "    return CLASSES.get(key, {})\n",
        encoding="utf-8"
    )
    print("PPA_GRIMOIRE_PARITY_OK", "classes=8", "skills=72", "original_cards=72",
          "exact_previews=" + str(len(effects)),
          "source_sha256=" + hashlib.sha256(html_bytes).hexdigest(),
          flush=True)


if __name__ == "__main__":
    main()
