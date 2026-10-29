#!/usr/bin/env python3
"""Measure immutable PNG artwork offline; emit runtime bounds and provenance.

This reads images without resampling or editing them. Runtime never scans pixels.
Requires Pillow in the developer environment, not in the shipped game.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/presentation"
CATALOG = ROOT / "scripts/view/presentation_assets.gd"


def measure(path: Path, columns: int = 1) -> dict:
    with Image.open(path) as image:
        width, height = image.size
        if width % columns:
            raise ValueError(f"unequal frame cells: {path}")
        alpha = image.getchannel("A") if "A" in image.getbands() else Image.new("L", image.size, 255)
        alpha = alpha.point(lambda a: 255 if a >= 20 else 0)
        cell = width // columns
        bounds = [alpha.crop((i * cell, 0, (i + 1) * cell, height)).getbbox()
                  for i in range(columns)]
        if any(b is None for b in bounds):
            raise ValueError(f"empty animation cell: {path}")
        left = min(b[0] for b in bounds)
        top = min(b[1] for b in bounds)
        right = max(b[2] for b in bounds)
        bottom = max(b[3] for b in bounds)
        return {"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "size": [width, height], "mode": image.mode, "visible_alpha_min": 20,
                "bounds_ltrb": list(alpha.getbbox()),
                "frame_union_ltrb": [left, top, right, bottom],
                "frame_bounds_ltrb": [list(b) for b in bounds], "frame_count": columns,
                "columns": columns, "rows": 1}


def main() -> None:
    source = CATALOG.read_text()
    paths_block = source.split("const PATHS := {", 1)[1].split("\n}", 1)[0]
    pairs = re.findall(r'&"([^"]+)": "res://([^"]+)"', paths_block)
    metadata, frames = [], []
    records: dict[Path, dict] = {}
    for key, relative in pairs:
        path = ROOT / relative
        with Image.open(path) as image:
            animated = (key.startswith("character_") or key.startswith("enemy_") or key == "shopkeeper") and image.width >= image.height * 2.8
        count = 4 if animated else 1
        record = measure(path, count)
        records[path] = record
        width, height = record["size"]
        left, top, right, bottom = record["frame_union_ltrb"]
        metadata.append(f'\t&"{key}": {{"size": Vector2({width}, {height}), "region": Rect2({left}, {top}, {right-left}, {bottom-top})}},')
        if count > 1:
            frames.append(f'\t&"{key}": {count},')
    replacement = "const SOURCE_METADATA := {\n" + "\n".join(metadata) + "\n}\n\nconst FRAME_COUNTS := {\n" + "\n".join(frames) + "\n}\n\n"
    start = source.index("const SOURCE_METADATA := {")
    end = source.index("static var _textures", start)
    CATALOG.write_text(source[:start] + replacement + source[end:])
    for folder in [ART, ART / "characters", ART / "enemies", ART / "items", ART / "weapons", ART / "surfaces", ART / "app_icon"]:
        assets = []
        for path in sorted(folder.glob("*.png")):
            assets.append(records.get(path) or measure(path))
        (folder / "manifest.json").write_text(json.dumps({"tool": "built-in imagegen", "art_direction": "Carbon Copy Purgatory", "assets": assets}, indent=2) + "\n")
    count = len(list(ART.rglob("*.png")))
    print(f"catalog: {len(pairs)} identities, {len(frames)} animation strips; {count} PNG provenance measured")


if __name__ == "__main__":
    main()
