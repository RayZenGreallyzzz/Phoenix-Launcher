#!/usr/bin/env python3
"""Inspect PUBLIC Telegram PPA game code to discover how its inventory is built.

No accounts, tickets, bearer tokens, D1 records, or player saves are requested.
This diagnostics-only script prints small public source fragments from the
deployed game and its already downloaded original charFrame iframe.
"""
from pathlib import Path
import re
from urllib.request import Request, urlopen

HOST = "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
FRAME = Path(__file__).resolve().parents[1] / "webview-plugin/src/main/assets/ppa_original/charFrame.html"
PAGE = (
    urlopen(Request(HOST + "/?native_schema_audit=20261009",
                    headers={"User-Agent": "PPA-Native-Schema-Inspector/1"}), timeout=80)
    .read(8_000_000).decode("utf-8")
)
sources = {"main_game": PAGE, "character_frame": FRAME.read_text(encoding="utf-8")}
patterns = (
    r"СТАКОВ", r"стаков", r"шмот", r"function\s+renderInventory",
    r"function\s+renderBag", r"renderBag\s*=", r"materials",
    r"potions", r"grimoires", r"\binventory\b", r"msg\.items",
    r"renderInv", r"\bINV\.bag\b", r"resourceItems", r"resourceItems\s*:",
    r"function\s+sendInvState", r"sendInvState\s*=", r"function\s+buildBagView",
)
for label, source in sources.items():
    print(f"PPA_ORIGINAL_INVENTORY_PUBLIC_SOURCE {label} chars={len(source)}", flush=True)
    for pattern in patterns:
        matches = list(re.finditer(pattern, source, re.I))[:8 if "resourceItems" in pattern or "sendInvState" in pattern else 2]
        for match in matches:
            a = max(0, match.start() - 240)
            b = min(len(source), match.end() + (1300 if "resourceItems" in pattern or "sendInvState" in pattern else 340))
            excerpt = " ".join(source[a:b].split())
            print(f"PPA_SCHEMA {label} {pattern}: {excerpt[:1650]}", flush=True)
# Exact public inventory stack builder, not a player save. Print enough to
# reconstruct the same projection from D1 inventory fields in native Godot.
from html import unescape
needle = "resourceItems:(function(){"
match = PAGE.find(needle)
if match < 0:
    raise RuntimeError("Original resourceItems builder moved; fail closed")
end = PAGE.find("})();", match)
# The production inventory projection is long and can use nested closures.
# Print a bounded public-code window without requiring a specific formatter.
if end < 0 or end - match > 18000:
    end = min(len(PAGE), match + 14000)
else:
    end += 5
block = unescape(PAGE[match:end])
print("PPA_RESOURCE_ITEMS_BUILDER_BEGIN", len(block), flush=True)
for pos in range(0,len(block),2600):
    print("PPA_RESOURCE_ITEMS_PART",pos,repr(block[pos:pos+2600]),flush=True)
print("PPA_RESOURCE_ITEMS_BUILDER_END",flush=True)
for name in ("MATERIAL_DB", "PPA_V172_ART", "GRIMOIRE_ART"):
    match = PAGE.find("const " + name + "=")
    if match < 0:
        match = PAGE.find("var " + name + "=")
    print("PPA_PUBLIC_ASSET_CATALOG",name,"found=",match>=0,"excerpt=",repr(unescape(PAGE[match:match+900])) if match>=0 else "",flush=True)
from html import unescape as _unescape
for term in ("function classGearArt", "function refreshGearArt",
             "const CLASS_ART_SLOTS=", "var CLASS_ART_SLOTS=",
             "const CLASS_ITEM_NAMES=", "const CLASS_DISPLAY="):
    at = PAGE.find(term)
    print("PPA_PUBLIC_GEAR_SCHEMA", term, "found=", at>=0,
          "excerpt=", repr(_unescape(PAGE[at:at+2700])) if at>=0 else "",
          flush=True)
for term in ("function runeUiState()", "function runeUiState(", "function ppaBuildSaveObject()", "function sendInvState()", "function renderRunes("):
    at = PAGE.find(term)
    print("PPA_PUBLIC_LIVE_SCHEMA", term, "found=", at >= 0,
          "excerpt=", repr(PAGE[at:at+7300]) if at >= 0 else "", flush=True)
for term in ("function runeDefByKey(", "function runeUnlockedSlots(", "function normalizeRuneState(", "var RUNE_TYPES=", "const RUNE_TYPES=", "var RUNE_RARITIES=", "const RUNE_RARITIES=", "var RUNE_ART=", "var RUNE_IMG=", "function runeKey("):
    at = PAGE.find(term)
    print("PPA_PUBLIC_RUNE_DEFINITION", term, "found=", at >= 0,
          "excerpt=", repr(PAGE[at:at+2400]) if at >= 0 else "", flush=True)
# Public client source inspection only. No access to actual player balances.
for term in ("function ppaBuildSaveObject()", "function sendInvState()", "function sendWalletState()", "gold:INV.gold", "gold:INV", "ppa:INV.ppa", "gram:", "gramBalance", "walletBalance", "function renderItemTooltip(", "function itemStatsText("):
    at = PAGE.find(term)
    print("PPA_PUBLIC_MONEY_ATTR_SCHEMA", term, "found=", at >= 0,
          "excerpt=", repr(PAGE[at:at+4500]) if at >= 0 else "", flush=True)
# Review all live public UI catalogs without reading private saves. This
# shows which native NPC/arena/event panels are mere placeholders.
for term in ("ARENA_SHOP", "arenaShop", "arenaTokens", "arenaAttempts", "arenaPvp", "EVENT_CATALOG", "eventItems", "mimicSombrero", "titanShard", "WORLD_BOSS_SHARD_NAME", "merchantFrame", "arenaFrame", "eventsFrame", "EVENTS", "PPA_EVENT", "eventTimer", "arenaHistory"):
    at = PAGE.find(term)
    print("PPA_ORIGINAL_ARENA_EVENT_SCHEMA", term, "found=", at >= 0,
          "excerpt=", repr(PAGE[max(0,at-200):at+1900]) if at >= 0 else "", flush=True)
for term in ("const PVP_SHOP_ITEMS", "const PVP_SHOP_CATALOG", "const PVP_SHOP", "const ARENA_SHOP", "function sendArenaMenuState", "function sendEventsState", "function ppaSendEventsState", "const eventCatalog", "const offers=[", "const RURI_ART", "const TITAN_ART"):
    at = PAGE.find(term)
    print("PPA_EXACT_ARENA_EVENT_CODE", term, "found=", at>=0, "excerpt=", repr(PAGE[at:at+4600]) if at>=0 else "", flush=True)
print("PPA_ORIGINAL_INVENTORY_SCHEMA_AUDIT_OK no_player_access=1", flush=True)
