#!/usr/bin/env python3
"""Read-only inspect current deployed PPA 21-40 and 41-60 sprite/level mechanics."""
import hashlib
import json
import re
from pathlib import Path
from audit_live_dungeon_art import HOST, fetch, js_array
def main():
    src=fetch(HOST+'/?tier_mobs_inspect=20261009', 11_000_000).decode('utf-8')
    print("LIVE_SHA",hashlib.sha256(src.encode()).hexdigest(),"CHARS",len(src))
    for name in ("MOB_TABLE","DUNGEON_MOB_SPRITES","MOB_ANIM_PACKS","DG_ROOM_META","DG_ACTIVE_SPAWNS"):
        try:
            match=js_array(src,name) if name!="MOB_ANIM_PACKS" else None
            print("TABLE",name,"length",len(match) if match is not None else 0,"opening",(match or "")[:250])
        except ValueError:print("TABLE_MISSING",name)
    patterns={
        "NORMALIZE_TYPES":["DUNGEON_MODE","dungeon21","dungeon41","function createDungeon","function spawnMobAtPoint","function mkMob(","function dungeonMob","function spawnDungeon","MOB_TABLE["],
        "TIER_TRANSFORMS":["+20","+40","-20","-40","%20","% 20","lvl+20","lvl+40","level+20","level+40","baseLevel","baseLvl","type.n","isDungeon60Boss"],
        "SPRITE_PATH":["applyApprovedMobAnimation","applyScavengerSlimeVariant","applyCaveSpiderVariant","MOB_ANIM_PACKS","DUNGEON_MOB_IMAGES","DUNGEON_MOB_SPRITES"],
    }
    extracts={}
    for family,terms in patterns.items():
        for term in terms:
            hits=list(re.finditer(re.escape(term),src,re.I))
            scored=[]
            for h in hits:
                line=src[max(0,h.start()-240):h.end()+320]
                if "data:image/" in line or len(line)>700:
                    line=re.sub(r"data:image/\w+;base64,[A-Za-z0-9+/=]+","[IMG]",line)
                line=re.sub(r"\s+"," ",line).strip()[:580]
                relevant=sum(bool(re.search(t,line,re.I)) for t in (r"dungeon",r"mob",r"sprite",r"spawn",r"level",r"lvl",r"type"))
                scored.append((relevant,h.start(),line))
            scored.sort(key=lambda x:(-x[0],x[1]))
            extracts[term]={"count":len(hits),"examples":[{"offset":pos,"text":context} for _,pos,context in scored[:min(8 if term in ("DUNGEON_MODE","dungeon41","dungeon21","function mkMob(","function spawnMobAtPoint") else 4,len(scored))]]}
    out=Path("audit-output/tier21-60")
    out.mkdir(parents=True,exist_ok=True)
    (out/"tier-debug.json").write_text(json.dumps(extracts,ensure_ascii=False,indent=2),encoding="utf-8")
    for term, result in extracts.items():
        print("TERM",repr(term),"HITS",result["count"])
        for p in result["examples"][:3]:
            print("OFFSET",p["offset"],p["text"][:490])
    print("PPA_READONLY_TIER_ANALYSIS_OK no_writes=1")
if __name__=="__main__":main()
