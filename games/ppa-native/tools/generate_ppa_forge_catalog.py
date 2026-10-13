#!/usr/bin/env python3
"""Generate exact READ-ONLY Godot forge recipe cards from the live PPA smith.

The source is the anonymous PUBLIC production HTML blacksmithFrame srcdoc.
No account, DB, Cloudflare token, inventory, or player data is accessed.
Only the original PPA knows how to deduct or forge: this is VIEW DATA ONLY.
If the real rules drift, fail the build rather than ship misleading prices.
"""
from __future__ import annotations
from html.parser import HTMLParser
import html
from urllib.request import Request, urlopen
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "scripts/ppa_forge_catalog_generated.gd"
BASE = "https://ppa-phoenixpixarena.1988stella1988.workers.dev"

class Frames(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.smith: list[str] = []

    def handle_starttag(self, tag, attrs) -> None:
        if tag != "iframe":
            return
        data = dict(attrs)
        if data.get("id") == "blacksmithFrame":
            self.smith.append(data.get("srcdoc", ""))

def object_literal(source: str, key: str, expected_type):
    m = re.search(r"\bconst\s+" + re.escape(key) + r"\s*=\s*", source)
    if not m:
        raise RuntimeError(f"Canonical PPA smith {key} was not found")
    value, _ = json.JSONDecoder().raw_decode(source[m.end():])
    if not isinstance(value, expected_type):
        raise RuntimeError(f"Canonical PPA smith {key} changed type")
    return value

def numeric_js_object(source: str, key: str) -> dict[str, int]:
    m = re.search(r"\bconst\s+" + re.escape(key) + r"\s*=\s*\{([^{}]*)\}", source)
    if not m:
        raise RuntimeError(f"Canonical PPA smith numeric object {key} missing")
    result = dict((n, int(v)) for n, v in re.findall(r"\b(\w+)\s*:\s*(\d+)", m.group(1)))
    if len(result) < 4:
        raise RuntimeError(f"Canonical PPA smith {key} incomplete")
    return result


def original_legendary_bonuses(source: str) -> dict[str,list[str]]:
    """Copy the six exact displayed +0 base stat arrays from live PPA."""
    m = re.search(r"\bconst\s+LEGENDARY_GEAR_STATS\s*=\s*\{(.*?)\}\s*;", source, re.S)
    if not m:
        raise RuntimeError("Original legendary item stat definitions absent")
    found = {}
    for key, inner in re.findall(r"(\w+)\s*:\s*\[([^\]]*)\]", m.group(1)):
        found[key] = re.findall(r"'([^']+)'", inner)
    if set(found) != {"weapon","armor","helmet","legs","boots","gloves"} or not all(found.values()):
        raise RuntimeError("Original PPA legendary bonuses changed or incomplete")
    return found

def quantities(source: str, func: str) -> dict[str, list[int]]:
    m = re.search(r"function\s+" + re.escape(func) + r"\s*\([^)]*\)\s*\{", source)
    if not m:
        raise RuntimeError(f"Canonical PPA smith {func} missing")
    block = source[m.end():m.end()+350]
    found = re.findall(r"\b(common|uncommon|rare|epic):\s*\[\s*(\d+),\s*(\d+),\s*(\d+)\s*\]", block)
    if len(found) < 3 or "return base.map(v=>v*mult)" not in source[m.end():m.end()+500]:
        raise RuntimeError(f"Canonical PPA smith {func} changed; stop before wrong materials")
    return {key:[int(a),int(b),int(c)] for key,a,b,c in found}

def image_ref(src: str) -> str:
    if not isinstance(src, str):
        return ""
    m = re.fullmatch(r"(?:\./|/)?assets/([A-Za-z0-9._/-]+\.(?:png|webp|jpe?g))", src)
    if m and ".." not in m.group(1):
        # Keep the approved original URL format. The Godot art resolver maps\n    # it to bundled assets first, then the same PPA Worker over HTTPS.\n    return "./assets/" + m.group(1)
    return ""


def literal_art(source: str, name: str) -> str:
    # Explicit public PPA icon constants for normal and epic rarity.
    m = re.search(r"\b(?:const|var|let)\s+" + re.escape(name)
                  + r"\s*=\s*['\"]([^'\"]+)['\"]", source)
    return image_ref(m.group(1)) if m else ""

def array_first_art(source: str, name: str) -> str:
    # The original Telegram smith uses the FIRST approved visual for a
    # generic recipe. Specific owned items retain their own distinct art.
    m = re.search(r"\b(?:const|var|let)\s+" + re.escape(name) + r"\s*=\s*", source)
    if not m:
        return ""
    try:
        images, _ = json.JSONDecoder().raw_decode(source[m.end():].lstrip())
    except (ValueError, TypeError):
        return ""
    if not isinstance(images,list) or not images:
        return ""
    return image_ref(images[0])

def approved_accessory_art(source: str, kind: str, rarity: str,
                           wings: dict, jewelry: dict) -> str:
    # Match parent.PPA_UI_CRAFT_IMG / accessoryImg in deployed Telegram PPA.
    if kind == "wings":
        direction = wings.get(rarity, wings.get("rare",{}))
        return image_ref(direction.get("S",direction.get("E",""))) if isinstance(direction,dict) else ""
    if rarity == "legendary":
        list_names = {
            "ring":"LEGENDARY_RING_ART",
            "necklace":"LEGENDARY_NECKLACE_ART",
            "cloak":"LEGENDARY_CLOAK_ART",
            "artifact":"LEGENDARY_ARTIFACT_ART"
        }
        return array_first_art(source,list_names.get(kind,"")) if kind in list_names else ""
    if kind == "necklace":
        variants = jewelry.get("necklace",[])
        return image_ref(variants[0].get("img","")) if variants and isinstance(variants[0],dict) else ""
    if kind in ["cloak","artifact"]:
        rarity_prefix = "EPIC_" if rarity == "epic" else ""
        return literal_art(source,rarity_prefix + kind.upper() + "_ICON_DATA")
    return ""

def requirement(names: list, amounts: list[int]) -> list[dict]:
    if len(names) < len(amounts) or any(not isinstance(n, str) or not n for n in names[:len(amounts)]):
        raise RuntimeError("Original smith materials list incomplete")
    return [{"name":names[i], "count":int(amounts[i])} for i in range(len(amounts))]

def main() -> None:
    request = Request(BASE + "/?ppa_native_forge_catalog=20261010",
                      headers={"User-Agent":"PPA-Native-Source-Forge/1"})
    with urlopen(request, timeout=80) as r:
        original = r.read(8_000_000).decode("utf-8")
    # The outer page supplies the exact art bridge used by the smith iframe.
    # Parse only PUBLIC constants. No real player inventory is read here.
    outer_source = html.unescape(original)
    wing_art = object_literal(outer_source, "WING_DIR_ART", dict)
    jewelry_art = object_literal(outer_source, "JEWELRY_VARIANTS", dict)
    parser = Frames()
    parser.feed(original)
    if len(parser.smith) != 1 or not (75_000 <= len(parser.smith[0]) <= 180_000):
        raise RuntimeError("Original blacksmithFrame missing or unexpectedly changed")
    source = parser.smith[0]
    acc = object_literal(source, "ACC", dict)
    pets = object_literal(source, "PETS", dict)
    pet_art = object_literal(source, "PET_IMG", dict)
    gear = object_literal(source, "GEAR", list)
    legendary_bonuses = original_legendary_bonuses(source)
    mult = numeric_js_object(source, "CRAFT_RESOURCE_MULT")
    acc_base = quantities(source, "qtyForRarity")
    pet_base = quantities(source, "petQty")
    if len(gear) < 6 or len(acc) < 5 or len(pets) < 7:
        raise RuntimeError("Original PPA forge categories unexpectedly missing")
    for key in ["common","uncommon","rare","epic"]:
        if key not in mult or mult[key] < 1:
            raise RuntimeError("Original PPA forge resource multiplier missing: " + key)
    # Original JS handles legendary accessories with 1000 Abyss crystals, 12k PPA.
    if not all(x in source for x in ("{name:'Кристалл Бездны',count:1000}", "price=12000", "name:'Перо Феникса',count:2")):
        raise RuntimeError("Original PPA epic/legendary smith rules changed")

    rows = []
    for item in gear:
        mats = requirement(item.get("mats",[]), [24*mult["epic"],16*mult["epic"],8*mult["epic"]])
        mats.append({"name":"Перо Феникса","count":2})
        rows.append({
            "id":"gear:epic:"+str(item["slot"]), "tab":"equipment",
            "kind":"gear","slot":item["slot"],"name":item["name"],
            "rarity":"epic","price":int(item["price"]), "currency":"ppa",
            "icon":str(item.get("icon","")), "desc":str(item.get("stat","")),
            "sourceStats":[str(item.get("stat",""))] if str(item.get("stat","")) else [],
            "materials":mats, "img":""
        })
    for kind, item in acc.items():
        for rarity, price in item.get("prices",{}).items():
            if rarity not in ("common","uncommon","rare","epic","legendary"):
                continue
            if rarity == "legendary":
                mats = [{"name":"Кристалл Бездны","count":1000}]
                price = 12000
            else:
                sizes = acc_base.get(rarity)
                if not sizes:
                    raise RuntimeError("No quantity formula for accessory rarity "+rarity)
                mats = requirement(item.get("mats",[]), [q*mult[rarity] for q in sizes])
                if rarity == "epic":
                    mats.append({"name":"Перо Феникса","count":1})
            label = {
                "common":"Обычный","uncommon":"Необычный","rare":"Редкий",
                "epic":"Эпический","legendary":"Легендарный"
            }[rarity]
            rows.append({
                "id":"acc:"+kind+":"+rarity,
                "tab":"legendary" if rarity=="legendary" else "accessories",
                "kind":"accessory","slot":kind,
                "name":("Легендарное кольцо" if kind=="ring" else label+" · "+str(item.get("name",kind))),
                "rarity":rarity, "price":int(price), "currency":"ppa",
                "icon":str(item.get("icon","")),
                "desc":" · ".join(item.get("stats",{}).get(rarity,[])),
                "sourceStats":list(item.get("stats",{}).get(rarity,[])),
                "materials":mats,
                "img":approved_accessory_art(outer_source,kind,rarity,wing_art,jewelry_art)
            })
    for name, item in pets.items():
        for rarity, price in (("common",500),("uncommon",1200),("rare",3000)):
            sizes = pet_base.get(rarity)
            if not sizes:
                raise RuntimeError("Original pet rarity rule missing: "+rarity)
            rows.append({
                "id":"pet:"+name+":"+rarity,
                "tab":"pets","kind":"pet","slot":"pet",
                "name":name, "rarity":rarity,
                "price":price, "currency":"ppa","icon":"🐾",
                "desc":str(item.get("bonus",{}).get(rarity,"")),
                "sourceStats":[str(item.get("bonus",{}).get(rarity,""))] if str(item.get("bonus",{}).get(rarity,"")) else [],
                "materials":requirement(item.get("mats",[]), [q*mult[rarity] for q in sizes]),
                "img":image_ref(pet_art.get(name,""))
            })
    # The original Telegram legendary equipment uses an independent list,
    # not GEAR or ACC. Copy its six canonical rows; no invented recipes.
    match = re.search(r"\bLEGENDARY_CRAFT\s*=\s*\[(.*?)\];", source, re.S)
    if not match:
        raise RuntimeError("Original legendary smith equipment list missing")
    legendary_items = []
    for raw in re.findall(r"\{([^{}]+)\}", match.group(1)):
        props = {}
        for key, value, digits in re.findall(
                r"(\w+)\s*:\s*(?:'([^']*)'|(\d+))", raw):
            props[key] = int(digits) if digits else value
        if not {"name","slot","kind","icon","price","mat"} <= props.keys():
            raise RuntimeError("Original legendary equipment entry changed")
        legendary_items.append(props)
    if len(legendary_items) < 5:
        raise RuntimeError("Original legendary equipment list incomplete")
    for item in legendary_items:
        rows.append({
            "id":"legend:"+item["kind"]+":"+item["slot"],
            "tab":"legendary","kind":item["kind"],"slot":item["slot"],
            "name":item["name"],"rarity":"legendary","price":int(item["price"]),
            "currency":"ppa","icon":item["icon"],
            "desc":" · ".join(legendary_bonuses[item["slot"]]),
            "sourceStats":legendary_bonuses[item["slot"]],
            "materials":[{"name":item["mat"],"count":1000}],"img":""
        })
    # No silent empty forge images: the current Telegram PPA defines one
    # canonical preview art source for every accessory rarity and each pet.
    for offer in rows:
        if offer["tab"] in ("accessories","pets") or (
                offer["tab"] == "legendary" and offer["kind"] == "accessory"):
            if not offer.get("img"):
                raise RuntimeError("Original smith art missing for "+offer["id"])
    # Price/material parity with server. Differences in images, markup and
    # HTML order must not make two identical recipes appear incompatible.
    signed_rows = [[x["id"], int(x["price"]), x["rarity"],
                    [[v["name"], int(v["count"])] for v in x["materials"]]]
                   for x in sorted(rows,key=lambda row:row["id"])]
    recipe_signature = hashlib.sha256(json.dumps(
        signed_rows,ensure_ascii=False,separators=(",",":")
    ).encode()).hexdigest()
    # Client uses this immutable display catalog, never as an authorization
    # source for deduction. Real purchase/forge must be a server-side atomic action.
    data = {
        "recipe_sha256":recipe_signature,
        "source":"public-live-PPA:blacksmithFrame",
        "sha256":hashlib.sha256(source.encode()).hexdigest(),
        "rows":rows
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        "extends RefCounted\n"
        "# Generated from deployed PPA smith: read-only recipe preview only.\n"
        "const CATALOG = "+json.dumps(data,ensure_ascii=False,separators=(",",":"))+"\n",
        encoding="utf-8"
    )
    print("PPA_CANONICAL_FORGE_CATALOG_OK", "recipes="+str(len(rows)),
          "epic_gear="+str(len(gear)), "accessories="+str(len(acc)),
          "pets="+str(len(pets)), "source_sha256="+data["sha256"],
          "recipe_sha256="+data["recipe_sha256"],
          "write_actions=0",flush=True)

if __name__ == "__main__":
    main()
