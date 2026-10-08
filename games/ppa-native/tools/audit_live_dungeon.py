#!/usr/bin/env python3
"""Diagnostic only: inspect live PPA dungeon map refs for a faithful Godot port.

Read-only published HTML scan. Never access player saves or modify web game.
Print limited content near dungeon map/path identifiers, and candidate asset
URLs; no code evaluation, credentials or production deployments.
"""
import html
from collections import Counter
from urllib.request import Request, urlopen
import re

URL = "https://ppa-phoenixpixarena.1988stella1988.workers.dev/"
req = Request(URL+"?native_dungeon_audit=20261008", headers={"User-Agent":"PPA-Native-Dungeon-Audit/1"})
with urlopen(req,timeout=100) as response:
    source=response.read(10000000).decode("utf-8")
print("PPA_DUNGEON_SOURCE_OK",len(source))
queries=[
    "dungeonMask", "DUNGEON_MASK", "dungeonWalk", "dungeonFloor",
    "dungeonMap","dungeonTile","dungeon", "DUNGEON",
    "bossRoom","roomCenters","maskCanvas","maze",
    "FART_ZONE", "fartZone", "DUNG", "tileMap"
]
for name in queries:
    matches=list(re.finditer(re.escape(name),source,re.I))
    print("KEYWORD",name,"hits",len(matches))
    for match in matches[:7]:
        snippet=source[max(0,match.start()-180):match.end()+240]
        snippet=" ".join(html.unescape(snippet).split())
        print("AROUND",name,match.start(),snippet[:430])
candidates=Counter(re.findall(r'(?:(?:https?:)?//[^\s\x22\x27<>]+|/assets/[a-zA-Z0-9_./?=\-]+|[a-zA-Z0-9_.-]+\.(?:png|webp|jpg|svg))(?:\?[^\x22\x27<>\s]*)?',source))
for link, count in candidates.most_common():
    if re.search("dungeon|floor|wall|tile|mask|cave|stone",link,re.I):
        print("ASSET_CANDIDATE",count,link[:260])
