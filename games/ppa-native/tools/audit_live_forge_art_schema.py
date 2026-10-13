#!/usr/bin/env python3
"""Read-only public PPA asset/schema audit; never accesses player data."""
import html, re, json
from html.parser import HTMLParser
from urllib.request import Request,urlopen

class Frame(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.smith=[]
    def handle_starttag(self,tag,attrs):
        if tag=="iframe":
            d=dict(attrs)
            if d.get("id")=="blacksmithFrame":
                self.smith.append(d.get("srcdoc",""))

base="https://ppa-phoenixpixarena.1988stella1988.workers.dev"
req=Request(base+"/?ppa_art_diagnostic=20261013",headers={"User-Agent":"PPA-Native-Art-Diagnostic/1"})
with urlopen(req,timeout=80) as response:
    public=response.read(8_000_000).decode("utf-8")
f=Frame();f.feed(public)
assert len(f.smith)==1
source=f.smith[0]
def const(src,name):
    m=re.search(r"\b(?:const|var)\s+"+re.escape(name)+r"\s*=\s*",src)
    if not m:return None
    try:return json.JSONDecoder().raw_decode(src[m.end():])[0]
    except Exception as e:return {"parse_error":str(e)[:100]}
acc=const(source,"ACC")
pet=const(source,"PET_IMG")
pets=const(source,"PETS")
all_source=html.unescape(public)
jewelry=const(all_source,"JEWELRY_VARIANTS")
epic=const(all_source,"EPIC_CLASS_GEAR_ART")
classgear=const(all_source,"CLASS_GEAR_ART")
sample=lambda d:{str(k):v for k,v in list(d.items())[:8]} if isinstance(d,dict) else str(type(d).__name__)
legend=re.search(r"\bLEGENDARY_CRAFT\s*=\s*\[(.*?)\];",source,re.S)
print("PPA_SOURCE_ART_SCHEMA",json.dumps({
 "petImages":pet,
 "petDefNames":list(pets.keys()) if isinstance(pets,dict) else str(type(pets)),
 "acc":{k:{"name":v.get("name"),"icon":v.get("icon"),"keys":list(v),"stats":v.get("stats")} for k,v in acc.items()} if isinstance(acc,dict) else acc,
 "jewelry":jewelry if len(str(jewelry))<5000 else sample(jewelry),
 "epicSamples":sample(epic),
 "classGearSamples":sample(classgear),
 "legendaryCraft":legend.group(1)[:2800] if legend else None,
 "sourceConstants":[z for z in re.findall(r"\\b(?:const|let|var)\\s+([A-Z][A-Z0-9_]*)\\s*=",source) if any(k in z for k in ["IMG","ART","LEGEND","STAT","CRAFT","PET","CLOAK","WING","ACCESSORY"])],
 "legendaryLogic":[source[max(0,m.start()-100):m.start()+900] for m in list(re.finditer(r"(?i)(?:function\\s+[^\\n]{0,30}legend|legendary_craft|legendary.*stat)",source))[:8]],
 "petArtInOuterHtml":[[k, k.split("/")[-1] in public] for k in (pet or {}).values()]
},ensure_ascii=False),flush=True)
