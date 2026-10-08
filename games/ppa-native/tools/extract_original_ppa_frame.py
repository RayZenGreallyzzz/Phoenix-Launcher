#!/usr/bin/env python3
"""Build-time acquisition of PPA's REAL charFrame srcdoc, not a Godot imitation.

The deployed Telegram game embeds its complete character menu as an iframe
srcdoc: HTML, CSS, JS, real 5-page layout, touch, skill cards, rune popup,
icons and postMessage protocol. We ship that exact iframe in Android AAR
assets without modifying the published PPA code or introducing an alternate
inventory save. Any mutations remain impossible until an authenticated
server-state bridge exists.
"""
from __future__ import annotations
from html.parser import HTMLParser
from pathlib import Path
from urllib.request import Request, urlopen
import hashlib
import re

HOST = "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "webview-plugin/src/main/assets/ppa_original/charFrame.html"


class CharacterSrcdoc(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.matches: list[str] = []

    def handle_starttag(self, tag, attrs):
        if tag != "iframe":
            return
        attributes = dict(attrs)
        if attributes.get("id") == "charFrame":
            self.matches.append(attributes.get("srcdoc", ""))


def main() -> None:
    request = Request(HOST + "/?native_webview_source=20261008",
                      headers={"User-Agent": "PPA-Original-WebView-Android/1"})
    with urlopen(request, timeout=100) as response:
        deployed = response.read(8_000_000).decode("utf-8")
    parser = CharacterSrcdoc()
    parser.feed(deployed)
    if len(parser.matches) != 1:
        raise ValueError("Published Telegram PPA must expose exactly one charFrame iframe")
    source = parser.matches[0]
    required = [
        "<!DOCTYPE html>", 'id="box"', 'id="viewport"', 'id="activeSkills"',
        'id="passiveSkills"', 'id="runeSlotsGrid"', "charReady", "closeChar",
        "renderSkills(", "renderRunes(", "parent.postMessage(", "touch-action:pan-y",
    ]
    missing = [item for item in required if item not in source]
    if missing:
        raise ValueError("Original PPA charFrame changed; refusing to fabricate UI: " + repr(missing))
    if not (90_000 <= len(source.encode("utf-8")) <= 250_000):
        raise ValueError("Published character srcdoc has unexpected size")
    if re.search(r"<script[^>]+src=[\"'][^\"']+", source, re.I):
        raise ValueError("Original character frame unexpectedly gained external script loads")
    DEST.parent.mkdir(parents=True, exist_ok=True)
    DEST.write_text(source, encoding="utf-8")
    expected_head = hashlib.sha256(source.encode("utf-8")).hexdigest()
    print("PPA_ORIGINAL_CHARFRAME_EXTRACT_OK",
          "bytes=", DEST.stat().st_size,
          "sha256=", expected_head,
          "pages=5 exact_srcdoc=1",
          flush=True)


if __name__ == "__main__":
    main()
