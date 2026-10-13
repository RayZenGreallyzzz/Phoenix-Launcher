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

def source_snippets(src, tokens, cap=1700):
    out={}
    for term in tokens:
        m=re.search(re.escape(term),src,re.I)
        if m:
            out[term]=src[max(0,m.start()-150):m.start()+cap]
    return out

def declaration_peeks(src, names):
    result={}
    for name in names:
        m=re.search(r"\\b(?:const|var|let)\\s+"+re.escape(name)+r"\\s*=\\s*",src)
        if m:
            result[name]=src[m.start():m.start()+260]
    return result

const_names = sorted(set(re.findall(r"\b(?:const|var|let)\s+([A-Z][A-Z0-9_]+)\s*=",source)))
outer_names = sorted(set(re.findall(r"\b(?:const|var|let)\s+([A-Z][A-Z0-9_]+)\s*=",all_source)))
print("PPA_MORE_ART",json.dumps({
 "sourceNames":[v for v in const_names if any(w in v for w in ["ART","IMG","LEGEND","CRAFT","CLOAK","WING","JEWEL","ACC","PET"])],
 "outerNames":[v for v in outer_names if any(w in v for w in ["ART","IMG","LEGEND","CLOAK","WING","JEWEL","ACCESSORY","PIC_"])],
 "accessoryImageLogic":source_snippets(source,["function accessoryImg","function craftImg","function renderAcc","function accImg","PIC_CLOAK_ICON_DATA"],1400),
 "outerAccessoryLogic":source_snippets(all_source,["PIC_CLOAK_ICON_DATA","PIC_WINGS","PIC_ARTIFACT","JEWELRY_VARIANTS"],700),
 "legendStatSource":source_snippets(source,["const LEGENDARY_GEAR_STATS"],1000),
 "forgeVisualsBridge":source_snippets(all_source,["wingsByRarity:","PPA_UI_CRAFT_IMG","EPIC_CLOAK_ICON_DATA","LEGENDARY_CLOAK_ART","artifactsImg:","accessories:{"],2300),
 "parentArtArrays":source_snippets(all_source,["const LEGENDARY_CLOAK_ART=","const LEGENDARY_ARTIFACT_ART=","const LEGENDARY_RING_ART=","const LEGENDARY_NECKLACE_ART=","const EPIC_NECKLACE_ART=","const WING_DIR_ART="],450),
 "artDecl":declaration_peeks(all_source,["CLOAK_ICON_DATA","EPIC_CLOAK_ICON_DATA","ARTIFACT_ICON_DATA","EPIC_ARTIFACT_ICON_DATA","LEGENDARY_CLOAK_ART","LEGENDARY_ARTIFACT_ART","LEGENDARY_RING_ART","LEGENDARY_NECKLACE_ART","EPIC_NECKLACE_ART"]),
 "uiResolver":source_snippets(all_source,["PPA_UI_CRAFT_IMG=function","function PPA_UI_CRAFT_IMG","window.PPA_UI_CRAFT_IMG","wingsByRarity:{"],2800)
},ensure_ascii=False),flush=True)
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
