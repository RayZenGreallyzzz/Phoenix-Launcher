from audit_live_dungeon_art import HOST,fetch
import re
from pathlib import Path
s=fetch(HOST+"/?combat_contract_20261009",11_000_000).decode()
for key in ("const MOB_TABLE", "const CLASS_BASE", "const CLASS_SKILLS", "const DUNGEON21_ARCHETYPES", "function dungeon21ReferenceStats", "function applyDungeon21MobStats", "function applyDungeon41MobStats","const GRIMOIRE_CATALOG"):
    match=re.search(re.escape(key),s)
    if not match:
        print("NOT_FOUND",key);continue
    p=match.start()
    text=s[p:p+4600].replace("\n"," ")
    text=re.sub(r"data:image/(png|webp|jpeg);base64,[A-Za-z0-9+/=]+","[image]",text)
    print("\nMARKER",key,"OFFSET",p,"\n",text[:4600],"\n")
print("END_COMBAT_AUDIT_MARKER")
