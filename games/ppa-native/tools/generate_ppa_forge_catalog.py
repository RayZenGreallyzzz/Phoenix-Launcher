#!/usr/bin/env python3
"""Generate exact READ-ONLY Godot forge recipe cards from the live PPA smith.

The source is the anonymous PUBLIC production HTML blacksmithFrame srcdoc.
No account, DB, Cloudflare token, inventory, or player data is accessed.
Only the original PPA knows how to deduct or forge: this is VIEW DATA ONLY.
If the real rules drift, fail the build rather than ship misleading prices.
"""
from __future__ import annotations
from html.parser import HTMLParser
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
        return "res://assets/ppa_item_icons/" + m.group(1)
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
    parser = Frames()
    parser.feed(original)
    if len(parser.smith) != 1 or not (75_000 <= len(parser.smith[0]) <= 180_000):
        raise RuntimeError("Original blacksmithFrame missing or unexpectedly changed")
    source = parser.smith[0]
    acc = object_literal(source, "ACC", dict)
    pets = object_literal(source, "PETS", dict)
    pet_art = object_literal(source, "PET_IMG", dict)
    gear = object_literal(source, "GEAR", list)
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
                "materials":mats, "img":""
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
            "currency":"ppa","icon":item["icon"],"desc":"Легендарный тир",
            "materials":[{"name":item["mat"],"count":1000}],"img":""
        })
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
