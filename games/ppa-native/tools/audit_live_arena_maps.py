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

important=["BG_ARENA","BG_PVP_DUEL","BG_PVP_TEAM","PVP_W","PVP_MASK_DUEL","PVP_MASK_TEAM","PVP_DUEL_SPAWNS","PVP_TEAM_SPAWNS","imgPvpDuel.src","imgPvpTeam.src","imgArena.src","pvpWalk","pvpBlocked","pvpColl","scene==='arena'"]
res={}
for key in important:
    mo=re.search(re.escape(key),txt)
    if not mo:
        res[key]=None
        continue
    start=max(0,mo.start()-70)
    snippet=txt[start:mo.start()+1350].replace("\n"," ")
    res[key]=snippet[:1350]
print("PPA_ARENA_KEY_DECLARATIONS",json.dumps(res,ensure_ascii=False))

extra={}
for key in ["const SCENES=","arena:{","pvp1:{","pvpteam:{","PVP_MASK_DUEL.walk","PVP_MASK_TEAM.walk","PVP_MASK_DUEL","PVP_DUEL_SPAWNS","imgArena.src=","imgPvpDuel","arenaCollide","pvpCollision","function movePlayer","function blocked","function isWalkable"]:
    match=re.search(re.escape(key),txt)
    if match:
        extra[key]=txt[max(0,match.start()-200):match.start()+1200].replace("\n"," ")[:1400]
print("PPA_ARENA_WORLD_COLLISION",json.dumps(extra,ensure_ascii=False))
