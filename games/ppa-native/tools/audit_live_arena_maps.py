#!/usr/bin/env python3
"""Read-only inspection of original publicly deployed PPA arena source."""
import re, json
from urllib.request import Request,urlopen
URL="https://ppa-phoenixpixarena.1988stella1988.workers.dev/?arena_map_port_audit=20261014"
with urlopen(Request(URL,headers={"User-Agent":"PPA-Godot-Arena-Map-Audit/1"}),timeout=90) as r:
    txt=r.read(16_000_000).decode("utf-8")
terms=[
    "pvp1","pvpteam","1x1","3x3","5x5",
    "arenaMap","arenaBg","PVP_MAP","PVP_ARENA","ARENA_MAP","ARENA_BG",
    "expArena","xpArena","arenaExp","арена опыта","арене опыта","опыта",
    "pvpDraw","function drawPvp","function drawArena","arenaBackground",
    "function pvp","arenaWalk","arenaCollision","pvpWall",
    "PVP1","PVPTEAM","ARENA_","trainingMap"
]
def minify(x):
    return x.replace("\n"," ").replace("\r"," ")[:500]
out={}
for word in terms:
    found=list(re.finditer(re.escape(word),txt,re.I))
    out[word]={"count":len(found),
        "contexts":[minify(txt[max(0,m.start()-180):m.start()+380])
                    for m in found[:4]]}
print("PPA_ARENA_SOURCE_TERMS",json.dumps(out,ensure_ascii=False))
vars_=re.findall(r"\b(?:const|let|var)\s+([A-Za-z0-9_]*(?:PVP|ARENA|Arena|arena|XP)[A-Za-z0-9_]*)\s*=",txt)
print("PPA_ARENA_SOURCE_VARIABLES",json.dumps(list(dict.fromkeys(vars_))[:180],ensure_ascii=False))
matches=re.findall(r"['\"](/assets/[^'\"<> ]+\.(?:png|webp|jpg))['\"]",txt,re.I)
print("PPA_ARENA_SOURCE_ASSET_CANDIDATES",json.dumps(list(dict.fromkeys(u for u in matches if re.search(r"arena|pvp|exp|xp|training",u,re.I)))[:100]))
print("PPA_ARENA_SOURCE_SIZE",len(txt))
