#!/usr/bin/env python3
"""Bundle actual CURRENT Telegram PPA small artwork for the native Godot UI.

Source is the SAME production PPA Worker and its immutable, SHA256-named
assets, NOT another game/AI images. The manifest is a build artifact; no
repository blobs, server writes, database reads or credentials are involved.

The game loads the bundle lazily for visible inventory slots, while uncommon
oversized/new images can still fall back to the same Worker over HTTPS.
"""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor, as_completed
from io import BytesIO
import hashlib
import json
from pathlib import Path
import re
import time
from urllib.request import Request, urlopen

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets" / "ppa_item_icons"
BASE = "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
MAX_FILE = 2_000_000
MAX_PIXELS = 1024 * 1024
MAX_SIDE = 1024
MAX_TOTAL = 64_000_000
MAX_COUNT = 950
MIN_COUNT = 50
HASHED = re.compile(r"^[0-9a-f]{16}\.(?:png|webp|jpg|jpeg)$")
ALLOWED = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9._/-]*\.(?:png|webp|jpg|jpeg)$", re.I)
REFERENCE = re.compile(r"(?:\.\/|\/)assets\/([a-zA-Z0-9._/-]+\.(?:png|webp|jpe?g))", re.I)
CLASSES = ("tank", "barbarian", "paladin", "gnome", "archer", "mage", "assassin", "priest")
SLOTS = ("weapon", "helmet", "armor", "legs", "gloves", "boots")


def fetch(url: str, cap: int = MAX_FILE) -> bytes:
    problem = None
    for attempt in range(3):
        try:
            req = Request(url, headers={"User-Agent": "PPA-Native-Approved-Art/1"})
            with urlopen(req, timeout=35) as r:
                if r.status != 200:
                    raise ValueError(f"HTTP {r.status}")
                data = r.read(cap + 1)
                if len(data) > cap:
                    return b""
                return data
        except Exception as e:
            problem = e
            time.sleep(0.4 * (attempt + 1))
    raise RuntimeError(f"Could not fetch approved PPA resource {url}: {problem}")


def clean(relative: str) -> str | None:
    if not ALLOWED.fullmatch(relative):
        return None
    if ".." in relative or "//" in relative or relative.startswith("/"):
        return None
    return relative


def original_reference_list() -> list[str]:
    page = fetch(BASE + "/?ppa_native_icon_parity=20261009", cap=6_000_000)
    if not page or b"<html" not in page[:2000].lower():
        raise RuntimeError("Live PPA HTML source is unavailable; cannot assert art parity")
    original = page.decode("utf-8")
    matches = {s for s in REFERENCE.findall(original) if clean(s) is not None}
    hashed = {s for s in matches if HASHED.fullmatch(s)}
    if len(hashed) < 100:
        raise RuntimeError(f"Unexpectedly few original PPA hashed images: {len(hashed)}")
    # Include approved v514 legendary icons even if dynamically constructed in JS.
    for cls in CLASSES:
        for slot in SLOTS:
            matches.add(f"legendary/{cls}-{slot}.webp")
    # These are server-defined gear/consumables not always mentioned as URLs
    # in the compiled HTML due to dynamically constructed UI paths.
    matches.add("newbie-chest-gray.webp")
    print("PPA_ART_SOURCE_PARITY", f"referenced={len(matches)}", f"hashed={len(hashed)}",
          f"html_sha256={hashlib.sha256(page).hexdigest()}", flush=True)
    return sorted(matches)


def examine(path: str) -> tuple[str, bytes] | None:
    is_hash = bool(HASHED.fullmatch(path))
    try:
        data = fetch(BASE + "/assets/" + path)
    except Exception as exc:
        if is_hash:
            raise  # hashed URLs referenced by the deployed game must work
        print("PPA_ART_OPTIONAL_UNAVAILABLE", path, str(exc)[:100], flush=True)
        return None
    if not data:
        return None
    if is_hash and hashlib.sha256(data).hexdigest()[:16] != path[:16]:
        raise RuntimeError(f"PPA immutable asset hash changed: {path}")
    try:
        with Image.open(BytesIO(data)) as art:
            w, h = art.size
            fmt = str(art.format or "").lower()
            if fmt not in {"png", "webp", "jpeg"}:
                return None
            if min(w, h) < 16 or max(w, h) > MAX_SIDE or w * h > MAX_PIXELS:
                return None
            art.verify()
    except Exception as exc:
        raise RuntimeError(f"Invalid live PPA image: {path}") from exc
    return path, data


def main() -> None:
    paths = original_reference_list()
    if len(paths) > MAX_COUNT:
        raise RuntimeError(f"Unexpected changed PPA asset count: {len(paths)}")
    # CI workspace is disposable; regenerate exactly what the current live PPA
    # serves. Do not commit these images to the source repository.
    DEST.mkdir(parents=True, exist_ok=True)
    results: list[tuple[str, bytes]] = []
    with ThreadPoolExecutor(max_workers=10) as pool:
        futures = [pool.submit(examine, path) for path in paths]
        for i, future in enumerate(as_completed(futures), 1):
            item = future.result()
            if item is not None:
                results.append(item)
            if i % 100 == 0:
                print("PPA_ART_SCANNED", i, "/", len(paths), flush=True)

    total = 0
    manifest = {}
    for name, raw in sorted(results):
        if total + len(raw) > MAX_TOTAL:
            # The original URL still works; lazily downloaded on first use.
            continue
        target = DEST / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
        total += len(raw)
        manifest["/assets/" + name] = hashlib.sha256(raw).hexdigest()
    if len(manifest) < MIN_COUNT:
        raise RuntimeError(f"Live icon bundle incomplete: {len(manifest)} < {MIN_COUNT}")
    (DEST / "manifest.json").write_text(
        json.dumps({"source": BASE, "count": len(manifest), "bytes": total,
                    "originalPathsSha256": hashlib.sha256(
                        "\n".join(paths).encode()).hexdigest(),
                    "items": manifest}, sort_keys=True, indent=2) + "\n",
        encoding="utf-8",
    )
    print("PPA_NATIVE_LIVE_ITEM_ART_OK", f"bundled={len(manifest)}",
          f"total_mib={total/1048576:.1f}", "official_sha256=1",
          "oversize_fallback=same_server_https", flush=True)


if __name__ == "__main__":
    main()
