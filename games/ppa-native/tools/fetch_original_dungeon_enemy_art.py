#!/usr/bin/env python3
"""Extract ORIGINAL dungeon enemy PNG/WebP from the deployed public PPA build.

The private original art repo is never accessed, and player/server state is
never fetched. Every downloaded hash-named sprite is verified against its
canonical filename, as produced by PPA build.mjs.
"""
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urljoin
from urllib.request import Request, urlopen

HOST = "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / "assets"

def fetch(uri: str, cap: int) -> bytes:
    req = Request(uri, headers={"User-Agent": "PPA-Godot-OriginalMobArt/1"})
    with urlopen(req, timeout=110) as response:
        b = response.read(cap + 1)
    if len(b) > cap:
        raise ValueError("Asset too large: " + uri)
    return b

def asset_source(source: str, symbol: str) -> str:
    # JS source has imgPhoenix.src=PATH or imgPhoenix.src='./assets/...'.
    value = re.search(r"\b" + re.escape(symbol) + r"\.src\s*=\s*([^;\n]+)", source)
    if not value:
        print("PPA_BOSS_ART_ASSIGNMENT_MISSING", symbol, flush=True)
        return ""
    expression = value.group(1).strip()
    print("PPA_BOSS_ART_ASSIGNMENT",symbol,expression[:200].replace("\n"," "),flush=True)
    direct = re.match(r"""['"]((?:\./|/)?assets/[\w.-]+\.(?:png|webp|jpg))['"]""", expression)
    if direct:
        return direct.group(1)
    # Resolve constant references without evaluating any deployed JS.
    symbol_ref = re.fullmatch(r"[A-Za-z_$][A-Za-z0-9_$]*", expression)
    if symbol_ref:
        const_ref = re.search(
            r"\b(?:const|let|var)\s+" + re.escape(expression)
            + r"""\s*=\s*['"]((?:\./|/)?assets/[\w.-]+\.(?:png|webp|jpg))['"]""",source)
        if const_ref:
            return const_ref.group(1)
    return ""

def approved_asset(path: str, local_name: str) -> str:
    # Never allow redirects off the approved hostname/path or traversal.
    if not re.fullmatch(r"(?:\./|/)?assets/[0-9a-f]{16}\.(?:png|webp|jpg)", path):
        raise ValueError("Unrecognized hashed PPA asset path " + path)
    dest = OUT / local_name
    u = urljoin(HOST + "/", path.lstrip("./"))
    data = fetch(u, 9_000_000)
    hash_name = re.search(r"/([0-9a-f]{16})\.(?:png|webp|jpg)$",path).group(1)
    if hashlib.sha256(data).hexdigest()[:16] != hash_name:
        raise ValueError("Original PPA PNG hash mismatch: " + path)
    ext = path.rsplit(".",1)[-1]
    valid=(ext=="png" and data.startswith(b"\x89PNG\r\n\x1a\n")) or (
        ext=="webp" and data[:4]==b"RIFF" and data[8:12]==b"WEBP") or (
        ext=="jpg" and data[:3]==b"\xff\xd8\xff")
    if not valid or len(data) < 300:
        raise ValueError("Invalid original PPA mob art file: " + path)
    dest.write_bytes(data)
    return "res://assets/" + local_name

def main():
    OUT.mkdir(exist_ok=True,parents=True)
    text=fetch(HOST + "/?godot_original_enemy_art=20261008",30_000_000).decode("utf-8")
    source = re.search(r"\bconst\s+DUNGEON_MOB_SPRITES\s*=\s*(\[[^\]]{200,7000}\])\s*;",text)
    if not source:
        raise ValueError("Original deployed PPA DUNGEON_MOB_SPRITES list not found")
    sprite_paths=re.findall(r"""['"]((?:\./|/)?assets/[0-9a-f]{16}\.(?:png|webp|jpg))['"]""",source.group(1))
    if len(sprite_paths)!=20:
        raise ValueError("Expected 20 authentic base mob sprite images, got "+str(len(sprite_paths)))
    sprites=[]
    for i,orig in enumerate(sprite_paths):
        extension=orig.rsplit(".",1)[-1]
        sprites.append(approved_asset(orig,"original_dungeon_mob_%02d.%s"%(i+1,extension)))

    bosses={}
    for tag,symbol in [("phoenix","imgPhoenix"),("lord","imgDungeon21Boss")]:
        path=asset_source(text,symbol)
        if path:
            bosses[tag]=approved_asset(path,"original_dungeon_boss_%s.%s"%(tag,path.rsplit(".",1)[-1]))
    # Canonical PPA Dragon60 renderer explicitly uses CLAN_BOSS_ART[4].
    # This is the SAME approved fourth-index clan event dragon image.
    # No phoenix/monster fallback is allowed for the level-60 dragon.
    clan_art = re.search(r"\\b(?:const|let|var)\\s+CLAN_BOSS_ART\\s*=\\s*(\\[[^;]{40,12000}\\])\\s*;",text,re.DOTALL)
    if clan_art:
        clan_files = re.findall(r"""['"]((?:\\./|/)?assets/[0-9a-f]{16}\\.(?:png|webp|jpg))['"]""",clan_art.group(1))
        if len(clan_files) >= 5:
            p=clan_files[4]
            bosses["dragon"]=approved_asset(p,"original_dungeon_boss_dragon."+p.rsplit(".",1)[-1])
            print("PPA_DRAGON60_CANONICAL_ART",p,"source=CLAN_BOSS_ART[4]",flush=True)
    if "dragon" not in bosses:
        print("PPA_DRAGON60_ART_UNRESOLVED: CLAN_BOSS_ART[4] unavailable",flush=True)
    resource = PROJECT / "scripts/ppa_dungeon_art_generated.gd"
    resource.write_text(
        "extends RefCounted\n"
        + "const MOB_RESOURCES := " + json.dumps(sprites,ensure_ascii=False) + "\n"
        + "const BOSS_RESOURCES := " + json.dumps(bosses,ensure_ascii=False) + "\n"
        + 'const CATALOG_SHA256 := "'+hashlib.sha256(source.group(1).encode()).hexdigest()+'"\n',
        encoding="utf-8")
    print("PPA_ORIGINAL_ENEMY_ART_OK",
          "authentic_mob_sprites="+str(len(sprites)),
          "bosses="+",".join(sorted(bosses)),
          "catalog_sha256="+hashlib.sha256(source.group(1).encode()).hexdigest(),
          "server_writes=0",flush=True)

if __name__ == "__main__":
    main()
