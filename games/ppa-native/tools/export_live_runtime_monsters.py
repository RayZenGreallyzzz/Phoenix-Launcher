#!/usr/bin/env python3
"""Extract the ACTUAL rendered 1-20 monster art from published PPA.

Do not use DUNGEON_MOB_SPRITES (some are old fallback placeholders).
Correct drawing paths:
- levels 1,3,5-20: MOB_ANIM_PACKS[level].img, 4x4 animation frames;
- level 2: CAVE_SPIDER_ATLAS, 4x4;
- level 4: SLIME_SCAVENGER_SPRITES[variant%3], three 165x160 PNGs.
This is read-only with respect to the published game and cannot mutate saves.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urlparse, urljoin

from audit_live_dungeon_art import HOST, VIDEO_LEVELS, fetch, js_array, image_properties

FILES = [
    "mob_01_ash_rat.png", "mob_02_cave_spider.png",
    "mob_03_charred_beetle.png", "mob_04_slime_green.png",
    "mob_05_bone_rodent.png", "mob_06_goblin_scout.png",
    "mob_07_bone_warrior.png", "mob_08_ash_wolf.png",
    "mob_09_mushroom_abomination.png", "mob_10_goblin_shaman.png",
    "mob_11_cultist.png", "mob_12_cursed_knight.png",
    "mob_13_stone_golem.png", "mob_14_lava_elemental.png",
    "mob_15_ash_guard.png", "mob_16_hell_hound.png",
    "mob_17_fire_demon.png", "mob_18_void_watcher.png",
    "mob_19_elite_golem.png", "mob_20_ash_executioner.png"
]


def main() -> None:
    cli = argparse.ArgumentParser()
    cli.add_argument("--output", type=Path, default=Path("audit-output/deployed-real-animation-art"))
    cli.add_argument("--html-file")
    args = cli.parse_args()
    html = Path(args.html_file).read_bytes() if args.html_file else fetch(
        HOST + "/?godot_exact_runtime_animation_export=20261009", 11_000_000)
    source = html.decode("utf-8")
    source_sha = hashlib.sha256(html).hexdigest()
    # Honor current mob names, rather than old posters or archived ZIP.
    table = js_array(source, "MOB_TABLE")
    rows = {int(lv):name for lv, _, name in re.findall(
        r"\{\s*lvl\s*:\s*(\d+)\s*,\s*n\s*:\s*(['\"])(.*?)\2", table)}
    if any(rows.get(lv) != VIDEO_LEVELS[lv - 1] for lv in range(1, 21)):
        raise ValueError("Current live monster roster differs from approved video: refusing to silently remap")
    packs = re.search(r"\bconst\s+MOB_ANIM_PACKS\s*=\s*\{([\s\S]*?)\}\s*;", source)
    if not packs:
        raise ValueError("Published 18-pack monster animation registry missing")
    entries = re.findall(
        r"\b(\d+)\s*:\s*\{\s*src\s*:\s*(['\"])(.*?)\2\s*,\s*h\s*:\s*(\d+)\s*,\s*ms\s*:\s*(\d+)\s*\}",
        packs.group(1))
    by_level = {int(level): {"src":src, "height_in_game":int(height), "frame_ms":int(ms)}
                for level,_,src,height,ms in entries}
    expected_animated = set(range(1, 21)) - {2,4}
    if set(by_level) != expected_animated or len(entries)!=18:
        raise ValueError("Approved 18 animated monster levels do not match the live registry")
    if "function applyApprovedMobAnimation(e)" not in source or "e.animPack=p;" not in source:
        raise ValueError("Published animated monster render hookup missing")
    if "function applyCaveSpiderVariant(e)" not in source or "e.sprite=CAVE_SPIDER_ATLAS" not in source:
        raise ValueError("Published cave spider renderer missing")
    if "function applyScavengerSlimeVariant(e)" not in source or "e.sprite=SLIME_SCAVENGER_IMAGES[v%3]" not in source:
        raise ValueError("Published three-color slime renderer missing")
    spider = re.search(
        r"\bconst\s+CAVE_SPIDER_ATLAS_SRC\s*=\s*(['\"])(.*?)\1\s*;", source)
    if not spider:
        raise ValueError("Cave spider animation atlas missing")
    slimes = [s for _, s in re.findall(
        r"(['\"])(.*?)\1\s*,?", js_array(source,"SLIME_SCAVENGER_SPRITES"), re.S)]
    if len(slimes) != 3:
        raise ValueError("Exactly three approved slime appearances expected")
    sources = []
    for lv in range(1, 21):
        filename = FILES[lv-1]
        if lv == 2:
            sources.append((lv,filename,spider.group(2),192,112,4,4,90))
        elif lv == 4:
            sources.append((lv,filename,slimes[0],165,160,1,1,0))
        else:
            pack=by_level[lv]
            sources.append((lv,filename,pack["src"],192,160,4,4,pack["frame_ms"]))
    sources += [(4,"mob_04_slime_red.png",slimes[1],165,160,1,1,0),
                (4,"mob_04_slime_blue.png",slimes[2],165,160,1,1,0)]
    assert len(sources)==22 and len(set(s[1] for s in sources))==22
    output=args.output
    output.mkdir(parents=True,exist_ok=True)
    imported=[]
    for lv, filename, src,fw,fh,columns,rows,ms in sources:
        full=urljoin(HOST+"/",src)
        if urlparse(full).netloc!=urlparse(HOST).netloc:
            raise ValueError("A monster sprite references a non-PPA origin: "+src)
        data=fetch(full,15_000_000)
        fmt,w,h=image_properties(data)
        if fmt!="png" or (w,h)!=(fw*columns,fh*rows):
            raise ValueError(f"Bad animation dimensions {filename} expected={fw*columns}x{fh*rows}, actual={w}x{h}")
        (output/filename).write_bytes(data)
        imported.append({
            "level":lv, "name":VIDEO_LEVELS[lv-1], "filename":filename,
            "src":src, "sha256":hashlib.sha256(data).hexdigest(),
            "bytes":len(data), "width":w,"height":h,
            "frame_width":fw, "frame_height":fh,
            "columns":columns,"rows":rows,"frame_ms":ms,
            "game_height":by_level[lv]["height_in_game"] if lv in by_level else None,
        })
    # The full approved visual contract can be reproduced bit-for-bit.
    manifest={"source":"currently published PPA","host":HOST,"html_sha256":source_sha,
              "count":22,"levels":20,"approved_slime_colors":["green","red","blue"],
              "slime_behavior":{"variants":24,"color_rule":"abs(mob.id)%24 then index%3",
                                "mirror_rule":"floor(variant/3)%2",
                                "width_multipliers":[0.88,0.96,1.04,1.12]},
              "assets":imported}
    (output/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
    print("PPA_LIVE_REAL_RENDER_ART_OK assets=22 levels=20 animated=19 slime_colors=3")
    print("SOURCE_SHA256="+source_sha)
    for row in imported:
        print(f"REAL_LEVEL_{row['level']:02d} {row['filename']} {row['width']}x{row['height']} "
              f"frames={row['columns']}x{row['rows']} sha256={row['sha256']}")
    print("NO_GAME_WRITES=1 NO_POSTER_ASSETS=1",flush=True)


if __name__=="__main__":
    main()
