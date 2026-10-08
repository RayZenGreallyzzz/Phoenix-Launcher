#!/usr/bin/env python3
import re
from urllib.request import Request,urlopen
host="https://ppa-phoenixpixarena.1988stella1988.workers.dev"
with urlopen(Request(host+"/?ppa_phoenix_art_diagnostic=1",headers={"User-Agent":"PPA-OriginalPhoenix-Art-Audit"}),timeout=100) as response:
    s=response.read(30_000_000).decode("utf-8")
def out(pattern, cap=16):
    m=list(re.finditer(pattern,s,re.I))
    print("PPA_PHOENIX_SCAN",pattern,"matches",len(m),flush=True)
    for match in m[:cap]:
        window=s[max(0,match.start()-160):min(len(s),match.end()+230)]
        window=re.sub(r"data:image/(?:png|webp|jpeg);base64,[A-Za-z0-9+/=]+","BASE64_IMAGE",window)
        window=re.sub(r"\s+"," ",window)
        print("PPA_PHOENIX_CONTEXT",window,flush=True)
out(r"\bimgPhoenix\b",20)
out(r"\b(?:const|let|var)\s+\w*(?:phoenix|fenix)\w*\s*=",25)
out(r"PHOENIX_(?:IMG|SRC|ART|SPRITE|ASSET)",10)
out(r"phoenix\.(?:png|webp|jpg)",10)
out(r"imgDungeon21Boss\.src",8)
out(r"dungeon21BossCol",5)

# Standalone fast audit: not part of live PPA gameplay.
