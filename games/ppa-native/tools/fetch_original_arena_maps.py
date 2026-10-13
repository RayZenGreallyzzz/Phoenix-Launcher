#!/usr/bin/env python3
"""Extract three EXACT publicly-deployed Telegram PPA arena maps and PvP walk masks.

The 1×1 duel and 3×3/5×5 team arenas use distinct backgrounds and two
768×512 zero/one collision bitmaps from the ORIGINAL live game source.
The XP arena uses its published 1024px background and original 40px bounds,
NOT a fabricated obstacle mask. Safe, read-only, no account or server writes.
"""
import base64
import hashlib
import re
import struct
import zlib
from pathlib import Path
from urllib.parse import urljoin
from urllib.request import Request,urlopen

HOST="https://ppa-phoenixpixarena.1988stella1988.workers.dev/"
OUT=Path(__file__).resolve().parents[1]/"assets"
SOURCE=OUT.parent/"scripts/ppa_arena_maps_generated.gd"
UA={"User-Agent":"PPA-Native-Original-Arena-Maps/1"}

def fetch(url, limit):
    with urlopen(Request(url,headers=UA),timeout=115) as response:
        data=response.read(limit+1)
    if len(data)>limit:
        raise RuntimeError("Arena asset exceeded size limit: "+url)
    return data

def match_var(html,name):
    m=re.search(r"\bconst\s+"+re.escape(name)+r"\s*=\s*['\"]([^'\"]+)['\"]",html)
    if not m:raise RuntimeError("Missing original PPA declaration "+name)
    return m.group(1)

def png_dimensions(blob):
    if blob[:8]!=b"\x89PNG\r\n\x1a\n": raise RuntimeError("PPA arena original background is not a PNG")
    return struct.unpack(">II",blob[16:24])

def jpeg_dimensions(blob):
    if not blob.startswith(b"\xff\xd8"):
        raise RuntimeError("Published XP arena is not the original JPEG")
    p=2
    while p<len(blob)-10:
        if blob[p]!=0xff:
            p+=1
            continue
        while p<len(blob) and blob[p]==0xff:
            p+=1
        marker=blob[p]
        p+=1
        if marker in (0xd8,0xd9) or 0xd0<=marker<=0xd7:
            continue
        if p+2>len(blob):break
        length=struct.unpack_from(">H",blob,p)[0]
        if length<2:break
        if marker in (0xc0,0xc1,0xc2,0xc3):
            height,width=struct.unpack_from(">HH",blob,p+3)
            return width,height
        p+=length
    raise RuntimeError("No JPEG SOF segment in original XP arena")

def png_chunk(typ,b):
    return struct.pack(">I",len(b))+typ+b+struct.pack(">I",zlib.crc32(typ+b)&0xffffffff)

def walk_png(raw,w,h):
    # Original JS Uint8Array uses one UNPACKED byte per walk cell: 1=walk,
    # 0=wall. Preserve its contents exactly as opaque/transparent PNG.
    if len(raw)!=w*h or not set(raw)<= {0,1}:
        raise RuntimeError("PPA original walk mask changed format")
    scan=bytearray()
    for y in range(h):
        scan.append(0)
        for x in range(w):
            scan.extend((255,255,255,255 if raw[y*w+x] else 0))
    return (b"\x89PNG\r\n\x1a\n"+
        png_chunk(b"IHDR",struct.pack(">IIBBBBB",w,h,8,6,0,0,0))+
        png_chunk(b"IDAT",zlib.compress(scan,8))+
        png_chunk(b"IEND",b""))

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    html=fetch(HOST+"?ppa_native_arena_export=20261014",16_000_000).decode("utf-8")
    mapping=[
        ("duel","BG_PVP_DUEL", (1536,1024)),
        ("team","BG_PVP_TEAM", (1536,1024)),
        ("xp","BG_ARENA", (1024,1024))
    ]
    checks={}
    for kind,symbol,expected in mapping:
        source=match_var(html,symbol)
        url=urljoin(HOST,source)
        data=fetch(url,22_000_000)
        if kind == "xp":
            # Original public URL ends in .png but serves an actual JPEG.
            # Preserve its original bytes and load it with the correct .jpg.
            dims=jpeg_dimensions(data)
        else:
            dims=png_dimensions(data)
        if dims!=expected:
            raise RuntimeError(f"Unexpected PPA {kind} art {dims}, expected {expected}")
        destination=OUT/f"ppa_original_arena_{kind}.{'jpg' if kind=='xp' else 'png'}"
        destination.write_bytes(data)
        checks[kind]={"sha":hashlib.sha256(data).hexdigest(),"dimensions":dims}
        print(f"PPA_ORIGINAL_ARENA_MAP kind={kind} dimensions={dims} "
              f"sha256={checks[kind]['sha']} bytes={len(data)}",flush=True)
    for kind,key in [("duel","DUEL"),("team","TEAM")]:
        pattern=(r"\bconst\s+PVP_MASK_"+key+
                 r"\s*=\s*\{\s*gw\s*:\s*(\d+)\s*,\s*gh\s*:\s*(\d+).*?"
                 r"\}\s*;\s*\(function\(\)\{const b=atob\(['\"]([A-Za-z0-9+/=]+)['\"]\)")
        found=re.search(pattern,html,re.S)
        if not found:
            raise RuntimeError("Original PPA "+kind+" 1-byte collision array missing")
        w,h=int(found.group(1)),int(found.group(2))
        raw=base64.b64decode(found.group(3),validate=True)
        if (w,h)!=(768,512) or len(raw)!=w*h or not 0.1<raw.count(1)/(w*h)<0.9:
            raise RuntimeError("Original "+kind+" collision data invalid")
        png=walk_png(raw,w,h)
        (OUT/f"ppa_original_arena_{kind}_walk.png").write_bytes(png)
        checks[kind]["walk_sha"]=hashlib.sha256(raw).hexdigest()
        print(f"PPA_ORIGINAL_ARENA_MASK kind={kind} walk_dims={w}x{h} "
              f"walk_ratio={raw.count(1)/(w*h):.5f} "
              f"sha256={checks[kind]['walk_sha']}",flush=True)
    if "blue:[{x:690,y:512}]" not in html or "blue:[{x:227,y:166}" not in html:
        raise RuntimeError("PPA original PvP spawns no longer match the map")
    if not re.search(r"arena:\{name:'АРЕНА'.*?bounds:\{minX:40,maxX:WORLD-40,minY:40,maxY:WORLD-40\}.*?center:\{x:512,y:512\}",html,re.S):
        raise RuntimeError("Original PPA XP arena bounds changed")
    SOURCE.write_text(
        "extends RefCounted\n"
        "# All coordinates and collision masks extracted from original PUBLIC PPA.\n"
        "const PVP_WORLD_SIZE := Vector2(1536,1024)\n"
        "const XP_WORLD_SIZE := Vector2(1024,1024)\n"
        "const MASK_SIZE := Vector2i(768,512)\n"
        "const DUEL_BLUE := Vector2(690,512)\n"
        "const DUEL_RED := Vector2(846,512)\n"
        "const TEAM_BLUE := [Vector2(227,166),Vector2(128,283),Vector2(100,421),Vector2(106,545),Vector2(253,803)]\n"
        "const TEAM_RED := [Vector2(1306,166),Vector2(1402,284),Vector2(1437,422),Vector2(1437,547),Vector2(1284,805)]\n"
        "const XP_CENTER := Vector2(512,512)\n"
        "const XP_BOUNDS := Rect2(40,40,944,944)\n"
        "const DUEL_WALK_SHA256 := "+repr(checks["duel"]["walk_sha"])+"\n"
        "const TEAM_WALK_SHA256 := "+repr(checks["team"]["walk_sha"])+"\n"
        "const MODE_NAMES := {'1x1':'АРЕНА 1 × 1','3x3':'АРЕНА 3 × 3','5x5':'АРЕНА 5 × 5','xp':'АРЕНА ОПЫТА'}\n",
        encoding="utf-8")
    print("PPA_ORIGINAL_ARENA_ASSETS_OK maps=3 modes=4 "
          "pvp_exact_masks=2 xp_original_bounds=1 server_writes=0",flush=True)

if __name__=="__main__":
    main()
