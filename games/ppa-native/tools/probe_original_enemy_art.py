#!/usr/bin/env python3
"""Diagnose ORIGINAL deployed PPA enemy art symbols; never change live game."""
import re
from urllib.request import Request, urlopen
URL = "https://ppa-phoenixpixarena.1988stella1988.workers.dev/?godot_enemy_art_probe=20261008"
with urlopen(Request(URL, headers={"User-Agent":"PPA-Godot-Art-Audit/1"}),timeout=110) as response:
    src = response.read(30_000_000).decode("utf-8")
print("PPA_ORIGINAL_ENEMY_ART_PROBE_BYTES",len(src))
markers=[
  "mobByLvl", "spawnMobAtPoint", "function drawMob", "drawMob(", "function drawEnemy",
  "imgMob", "imgBoss", "imgPhoenix", "imgLord", "imgDragon",
  "spriteMob", "mobSprite", "mobSheet", "mobAtlas", "MOB_TYPES",
  "MOB_ART", "imgEnemy", "imgDungeon", "mobSprites", "bossImages",
  "MOB_SPRITES", "mobsImg", "mobImg", "mobTypes",
  "function drawEntity", "function drawDungeon", "e.skin", "e.type.skin",
  "e.img", "e.image", "e.sprite"
]
for symbol in markers:
    count=src.count(symbol)
    if not count:continue
    print("PPA_ART_MARKER",repr(symbol),"count",count)
    st=0
    for i in range(min(count,3)):
        at=src.find(symbol,st)
        st=at+len(symbol)
        sample=src[max(0,at-155):min(len(src),at+285)]
        sample=re.sub(r"data:image/(?:png|webp|jpeg);base64,[A-Za-z0-9+/=]+","DATA_IMAGE_BASE64",sample)
        print("PPA_ART_SNIP",repr(symbol),re.sub(r"\s+"," ",sample))
# Images with literal public asset URLs or DOM img variable names.
vars=re.findall(r"(?:const|let|var)\s+([\w$]+)\s*=\s*new\s+Image\s*\(",src)
print("PPA_ORIGINAL_IMAGE_VARS"," ".join(dict.fromkeys(vars) )[:1800])
srcs=list(re.finditer(r"""['"]((?:\./|/)?assets/[\w.-]+\.(?:png|webp|jpe?g))['"]""",src))
print("PPA_ORIGINAL_EXTERNAL_ASSET_USES",len(srcs))
for m in srcs[:100]:
    frag=src[max(0,m.start()-140):min(len(src),m.end()+55)]
    print("PPA_ORIGINAL_ASSET_BIND",re.sub(r"\s+"," ",frag))
