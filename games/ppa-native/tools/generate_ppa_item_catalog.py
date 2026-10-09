#!/usr/bin/env python3
"""Extract exact public art/name catalogs from the deployed Telegram PPA.

No player data, tokens or Cloudflare database access. Generated constants are
for CLIENT DRAWING only. Item ownership/counts always come from the signed
/api/game/state response to the current player's authenticated session.
"""
from pathlib import Path
from urllib.request import Request, urlopen
import hashlib
import html
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "scripts" / "ppa_item_catalog_generated.gd"
BASE = "https://ppa-phoenixpixarena.1988stella1988.workers.dev"

def read_public_html() -> str:
    req = Request(BASE + "/?native_item_catalog=20261009",
                  headers={"User-Agent": "PPA-Godot-Approved-Item-Catalog/1"})
    with urlopen(req, timeout=80) as resp:
        data = resp.read(8_000_000)
    if len(data) < 200_000 or b"<html" not in data[:2000].lower():
        raise RuntimeError("Unexpected original PPA client source")
    return html.unescape(data.decode("utf-8"))

def constant(source: str, name: str, required: bool = True) -> dict:
    pat = re.compile(r"\b(?:const|var)\s+"+re.escape(name)+r"\s*=")
    match = pat.search(source)
    if match is None:
        if required:
            raise RuntimeError("Original PPA catalog not found: " + name)
        return {}
    try:
        value, _end = json.JSONDecoder().raw_decode(source[match.end():].lstrip())
    except (ValueError, TypeError) as exc:
        if required:
            raise RuntimeError("Original PPA catalog not JSON: " + name) from exc
        return {}
    if not isinstance(value, dict):
        raise RuntimeError("Expected original object for " + name)
    return value

MERCHANT_ICON_HASHES = {
    "hp_small":"a7616001c81c7b2a.png",
    "hp_medium":"3ead73ed35a31dbe.png",
    "hp_large":"5f26be941ad98049.png",
    "mp_small":"350f8d7330191080.png",
    "mp_medium":"ab3f519b4b0c8866.png",
    "mp_large":"47eda61e7ba0e4b8.png",
    "magic_small":"83b9f41262511bde.png",
    "atk_speed_small":"ca495b7a51e4a93e.png",
    "run_speed_small":"67ad5574901487d8.png",
    "phys_small":"64ce724d9678352c.png",
    "xp_scroll":"4b927f4034e34dc9.png",
    "portal_stone":"01697b96fcd7c995.png",
}

def main() -> None:
    source = read_public_html()
    materials = constant(source, "MATERIAL_DB")
    stones = constant(source, "PPA_V172_ART")
    grimoire_art = constant(source, "GRIMOIRE_ART")
    grimoire_classes = constant(source, "GRIMOIRE_CATALOG")
    original_shop = constant(source, "SHOP_ICON_ART", required=False)
    original_gear = constant(source, "CLASS_GEAR_ART")
    original_epic_gear = constant(source, "EPIC_CLASS_GEAR_ART", required=False)
    original_jewelry = constant(source, "JEWELRY_VARIANTS", required=False)
    if len(materials) < 10 or len(grimoire_art) != 72 or len(grimoire_classes) != 8 or len(original_gear) < 8:
        raise RuntimeError("Public original PPA item catalog changed")
    if not all(stones.get(key) for key in
               ("normalStone","premiumStone","premiumRune","feather","luckCoin","premiumHp","premiumMp")):
        raise RuntimeError("Original PPA sharpening / consumable art missing")
    shop_art = {"%s" % key: "./assets/" + name for key,name in MERCHANT_ICON_HASHES.items()}
    for key, value in original_shop.items():
        if isinstance(value, str) and value.startswith(("./assets/","/assets/")):
            shop_art[key] = value
    grimoire_titles = {}
    for cls, definition in grimoire_classes.items():
        for kind in ("active", "passive"):
            for skill in definition.get(kind, []):
                sid = skill.get("id","")
                if sid in grimoire_art:
                    grimoire_titles[sid] = {
                        "name": skill.get("n",""),
                        "classKey": cls,
                        "type": kind,
                        "card": grimoire_art[sid].get("card", ""),
                        "icon": grimoire_art[sid].get("icon", "")
                    }
    if len(grimoire_titles) != 72:
        raise RuntimeError("Not all original PPA grimoire names have matching art")
    catalog = {
        "materials": materials,
        "stone_art": stones,
        "shop_art": shop_art,
        "grimoires": grimoire_titles,
        "class_gear": original_gear,
        "epic_gear": original_epic_gear,
        "jewelry": original_jewelry,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        "extends RefCounted\n"
        "# Auto-extracted from original deployed PPA public art. Never use for player ownership.\n"
        "const ITEMS = " + json.dumps(catalog, ensure_ascii=False, separators=(",",":")) + "\n",
        encoding="utf-8"
    )
    print("PPA_CANONICAL_ITEM_CATALOG_OK",
          f"materials={len(materials)}",
          f"grimoires={len(grimoire_titles)}",
          f"stones={len(stones)}",
          f"shop={len(shop_art)}",
          f"gear_classes={len(original_gear)}",
          f"epic_classes={len(original_epic_gear)}",
          f"source_sha256={hashlib.sha256(source.encode()).hexdigest()}",
          "server_writes=0", flush=True)

if __name__ == "__main__":
    main()
