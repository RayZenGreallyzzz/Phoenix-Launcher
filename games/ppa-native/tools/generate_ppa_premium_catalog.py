#!/usr/bin/env python3
"""Extract exact public Telegram PPA premium offers (NO credentials or writes).

Source: deployed premiumShopFrame only. This produces visual reference cards;
the Godot test client MUST NOT activate real Gram purchases or subscriptions.
"""
from __future__ import annotations
from html.parser import HTMLParser
from urllib.request import Request,urlopen
from pathlib import Path
import ast
import hashlib
import json
import re

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"scripts/ppa_premium_catalog_generated.gd"
BASE="https://ppa-phoenixpixarena.1988stella1988.workers.dev"

class Frames(HTMLParser):
    def __init__(self):super().__init__(convert_charrefs=True);self.items=[]
    def handle_starttag(self,tag,attrs):
        if tag!="iframe":return
        a=dict(attrs)
        if a.get("id")=="premiumShopFrame":self.items.append(a.get("srcdoc",""))

def static_object(source: str,name: str):
    m=re.search(r"\bconst\s+"+re.escape(name)+r"\s*=\s*",source)
    if not m:raise RuntimeError("Original PPA premium static catalog missing: "+name)
    start=m.end()
    opening=source[start]
    if opening not in "[{":raise RuntimeError("Unsupported dynamic premium catalog "+name)
    stack=[]
    quote=None
    escape=False
    end=-1
    for i in range(start,len(source)):
        ch=source[i]
        if quote:
            if escape:escape=False
            elif ch=="\\":escape=True
            elif ch==quote:quote=None
            continue
        if ch in "'\"":
            quote=ch
        elif ch in "[{":
            stack.append(ch)
        elif ch in "]}":
            if not stack:break
            prev=stack.pop()
            if (prev,ch) not in (("[","]"),("{","}")):
                raise RuntimeError("Original premium JS nested object malformed")
            if not stack:
                end=i+1
                break
    if end<0:raise RuntimeError("Premium catalog literal unterminated: "+name)
    raw=source[start:end]
    # Transform unquoted JS object keys to Python string keys only at structural
    # positions. ast.literal_eval NEVER runs the untrusted public JS.
    transformed=[]
    quote=None
    escape=False
    pos=0
    while pos<len(raw):
        ch=raw[pos]
        if quote:
            transformed.append(ch)
            if escape:escape=False
            elif ch=="\\":escape=True
            elif ch==quote:quote=None
            pos+=1
            continue
        if ch in "'\"":
            quote=ch
            transformed.append(ch)
            pos+=1
            continue
        if ch in "{,":
            transformed.append(ch)
            pos+=1
            spaces=re.match(r"\s*",raw[pos:]).group()
            transformed.append(spaces)
            pos+=len(spaces)
            key=re.match(r"([A-Za-z_$][\w$]*)\s*:",raw[pos:])
            if key:
                if "$" in key.group(1):raise RuntimeError("Unsupported premium JS key")
                transformed.append(repr(key.group(1))+":")
                pos+=len(key.group()
                )
            continue
        # JS boolean/null literals occur in the original premium offers.
        # Rewrite only outside quotes, so item titles and descriptions stay exact.
        keyword=re.match(r"(true|false|null)\\b",raw[pos:])
        if keyword:
            token=keyword.group(1)
            transformed.append({"true":"True","false":"False","null":"None"}[token])
            pos+=len(token)
            continue
        transformed.append(ch)
        pos+=1
    tree=ast.parse("".join(transformed), mode="eval")
    # Original PPA can refer to a predeclared icon or decorative theme.
    # Those unresolved public JS variables are NOT executed or substituted
    # with invented values; only required literal ID, name, price survive.
    def decode(node):
        if isinstance(node,ast.Expression):return decode(node.body)
        if isinstance(node,ast.Constant):return node.value
        if isinstance(node,(ast.List,ast.Tuple)):return [decode(x) for x in node.elts]
        if isinstance(node,ast.Dict):return {decode(k):decode(v) for k,v in zip(node.keys,node.values)}
        if isinstance(node,ast.UnaryOp) and isinstance(node.op,(ast.USub,ast.UAdd)):
            raw=decode(node.operand)
            if isinstance(raw,(int,float)):
                return -raw if isinstance(node.op,ast.USub) else raw
        if isinstance(node,ast.Name):
            print("PPA_PREMIUM_SOURCE_JS_REFERENCE",node.id,"ignored_no_eval=1",flush=True)
            return None
        raise RuntimeError("Premium catalog has nonliteral/dynamic JS entry; refusing to evaluate: "+type(node).__name__)
    value=decode(tree)
    if not isinstance(value,(dict,list)):raise RuntimeError("Premium catalog is not static")
    return value

def art_path(path: str) -> str:
    m=re.fullmatch(r"(?:\./|/)?assets/([A-Za-z0-9._/-]+\.(?:png|jpe?g|webp))",str(path))
    return "res://assets/ppa_item_icons/"+m.group(1) if m and ".." not in m.group(1) else ""

def main():
    r=urlopen(Request(BASE+"/?ppa_premium_native_catalog=20261010",headers={"User-Agent":"PPA-Premium-Public-Parity/1"}),timeout=80)
    with r: html=r.read(8000000).decode("utf-8")
    p=Frames();p.feed(html)
    if len(p.items)!=1 or len(p.items[0])<50000:
        raise RuntimeError("Original premiumShopFrame moved")
    source=p.items[0]
    goods=static_object(source,"PREMIUM_GOODS")
    bundles=static_object(source,"BUNDLES")
    plans=static_object(source,"PREMIUM_STATUS_PLANS")
    if not isinstance(goods,list) or len(goods)<8 or len(bundles)!=5 or len(plans)!=3:
        raise RuntimeError("Real PPA premium catalog changed unexpectedly")
    results={"goods":[],"bundles":[],"subscriptions":[]}
    for entry in goods:
        if not isinstance(entry,dict) or not all(k in entry for k in ("id","name","price")):
            raise RuntimeError("Premium offer without source ID/name/price")
        results["goods"].append({
            "id":str(entry["id"]),"name":str(entry["name"]),
            "price":entry["price"],"currency":"Gram",
            "desc":str(entry.get("desc","")),"img":art_path(entry.get("img",""))
        })
    for id,entry in bundles.items():
        results["bundles"].append({
            "id":str(id),"name":str(entry["name"]), "price":entry["price"],
            "currency":"Gram", "desc":"Набор PPA для текущего класса (состав определяет оригинальная игра)"
        })
    for id,entry in plans.items():
        results["subscriptions"].append({
            "id":str(id),"name":str(entry["name"]), "price":entry["price"],
            "currency":"Gram",
            "desc":str(entry["days"])+" дней · дроп +"+str(entry["drop"])+"% · золото +"+str(entry["gold"])+"%"
        })
    OUT.parent.mkdir(parents=True,exist_ok=True)
    OUT.write_text(
        "extends RefCounted\n# Exact public original premium offers: read-only cards, NOT an order API.\n"
        "const CATALOG = "+json.dumps(results,ensure_ascii=False,separators=(",",":"))+"\n",
        encoding="utf-8")
    print("PPA_ORIGINAL_PREMIUM_CATALOG_OK",f"goods={len(goods)}",
          f"bundles={len(bundles)}",f"subscriptions={len(plans)}",
          f"source_sha256={hashlib.sha256(source.encode()).hexdigest()}",
          "purchases=0",flush=True)

if __name__=="__main__":main()
