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
print("PPA_ORIGINAL_INVENTORY_SCHEMA_AUDIT_OK no_player_access=1", flush=True)
