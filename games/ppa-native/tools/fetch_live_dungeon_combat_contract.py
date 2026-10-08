#!/usr/bin/env python3
"""Generate dungeon TEST combat display data straight from current live PPA.

Exactly extracted CLASS_BASE, CLASS_SKILLS, MOB_TABLE. Never create or edit
server state, balance or the user's account. Contract locks source SHA.
"""
import ast
import hashlib
import json
from pathlib import Path
import re
from audit_live_dungeon_art import HOST,fetch

PROJECT=Path(__file__).resolve().parents[1]
OUT=PROJECT/"scripts"/"ppa_dungeon_combat_catalog_generated.gd"
SOURCE_HASH="3323076a3adb46677e8bf56036a93f6935817efd2b019a8c01d52368ce75bfce"
CLASS_KEYS=("tank","barbarian","paladin","gnome","archer","mage","assassin","priest")

def obj_literal(source,name):
    needle=re.search(r"\bconst\s+"+re.escape(name)+r"\s*=\s*",source)
    if needle is None:
        raise ValueError("Missing "+name)
    i=needle.end()
    if source[i] not in "[{":
        raise ValueError("Expected object/array for "+name)
    opener=source[i]
    closer={"{":"}","[":"]"}[opener]
    depth=0
    quote=None
    escaped=False
    for j in range(i,len(source)):
        char=source[j]
        if quote:
            if escaped:
                escaped=False
            elif char=="\\":
                escaped=True
            elif char==quote:
                quote=None
            continue
        if char in "'\"":
            quote=char
        elif char==opener:
            depth+=1
        elif char==closer:
            depth-=1
            if depth==0:
                return source[i:j+1]
    raise ValueError("Unterminated literal: "+name)

def parse_js_constant(source,name):
    raw=obj_literal(source,name)
    raw=re.sub(r"//[^\n]*","",raw)
    raw=re.sub(r"([,{]\s*)([a-zA-Z_]\w*)\s*:",r'\1"\2":',raw)
    raw=re.sub(r"\btrue\b","True",raw)
    raw=re.sub(r"\bfalse\b","False",raw)
    raw=re.sub(r"\bnull\b","None",raw)
    result=ast.literal_eval(raw)
    if not isinstance(result,(dict,list)):
        raise ValueError("Unexpected JS source literal "+name)
    return result

def main():
    payload=fetch(HOST+"/?godot_test_combat=20261009",11_000_000)
    digest=hashlib.sha256(payload).hexdigest()
    if digest!=SOURCE_HASH:
        raise ValueError("Deployed source hash changed, refusing silently modified balance: "+digest)
    source=payload.decode('utf-8')
    mobs=parse_js_constant(source,"MOB_TABLE")
    classes=parse_js_constant(source,"CLASS_BASE")
    abilities=parse_js_constant(source,"CLASS_SKILLS")
    assert len(mobs)==20, len(mobs)
    assert [m["lvl"] for m in mobs]==list(range(1,21))
    assert tuple(classes)==CLASS_KEYS and tuple(abilities)==CLASS_KEYS
    for key in CLASS_KEYS:
        char=classes[key]
        assert {"hp","mp","atk","def_","range","atkSpd","crit","dodge","attackMode"}<=char.keys(),key
        assert 0<char["hp"]<1000 and 0<char["mp"]<500 and 0<char["range"]<=500
        assert len(abilities[key]["active"])==4
        for entry in abilities[key]["active"]:
            assert {"id","n","cd","mp","fx"}<=entry.keys()
            assert entry["cd"]>0 and entry["mp"]>0
    for mob in mobs:
        assert {"lvl","n","hp","atk","def","xp"}<=mob.keys()
    native="extends RefCounted\n\n# Generated directly from CURRENT deployed game; no local guesses.\n"
    native+="# PPA_SOURCE_SHA256 = "+digest+"\n"
    native+="const MOB_TABLE = "+json.dumps(mobs,ensure_ascii=True,separators=(',',':'))+"\n"
    native+="const CLASS_BASE = "+json.dumps(classes,ensure_ascii=True,separators=(',',':'))+"\n"
    native+="const CLASS_SKILLS = "+json.dumps(abilities,ensure_ascii=True,separators=(',',':'))+"\n"
    OUT.write_text(native,encoding="utf-8")
    assert OUT.stat().st_size>3000
    print("PPA_DUNGEON_COMBAT_CONTRACT_OK mobs=20 classes=8 four_active_skills_per_class=1 source_sha="+digest)
    print("PPA_DUNGEON_COMBAT_CATALOG_BYTES",OUT.stat().st_size)
if __name__=="__main__":
    main()
