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


def measure(path: Path, columns: int = 1, rows: int = 1,
            source_rect: tuple[int, int, int, int] | None = None) -> dict:
    with Image.open(path) as image:
        width, height = image.size
        if columns < 1 or rows < 1 or width % columns or height % rows:
            raise ValueError(f"unequal frame cells: {path}")
        alpha = image.getchannel("A") if "A" in image.getbands() else Image.new("L", image.size, 255)
        alpha = alpha.point(lambda a: 255 if a >= 20 else 0)
        if source_rect is not None:
            x, y, rect_width, rect_height = source_rect
            if columns != 1 or rows != 1:
                raise ValueError(f"static region cannot also be an animation: {path}")
            if min(x, y) < 0 or min(rect_width, rect_height) <= 0 or x + rect_width > width or y + rect_height > height:
                raise ValueError(f"source region outside image: {path}: {source_rect}")
            visible = alpha.crop((x, y, x + rect_width, y + rect_height)).getbbox()
            if visible is None:
                raise ValueError(f"empty static region: {path}: {source_rect}")
            left, top, right, bottom = visible
            bounds = [x + left, y + top, x + right, y + bottom]
            return {"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                    "size": [width, height], "mode": image.mode, "visible_alpha_min": 20,
                    "bounds_ltrb": bounds, "frame_union_ltrb": bounds,
                    "frame_bounds_ltrb": [bounds],
                    "frame_pivots": [[rect_width * 0.5 - left, bottom - top]],
                    "frame_count": 1, "columns": 1, "rows": 1}
        cell = width // columns
        cell_height = height // rows
        bounds = [alpha.crop((column * cell, row * cell_height,
                             (column + 1) * cell, (row + 1) * cell_height)).getbbox()
                  for row in range(rows) for column in range(columns)]
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
                "frame_bounds_ltrb": [list(b) for b in bounds],
                "frame_pivots": [[cell * 0.5 - left, b[3] - top] for b in bounds],
                "frame_count": columns * rows, "columns": columns, "rows": rows}


def authored_layouts() -> dict[Path, tuple[int, int]]:
    """Production manifests own layout; image aspect ratios never imply a clip."""
    layouts = {}
    for group in ("characters", "enemies", "surfaces", "bureau"):
        data = json.loads((ART / group / "carbon_copy_assets.json").read_text())
        for asset in data["assets"] if isinstance(data, dict) else data:
            columns, rows = int(asset["columns"]), int(asset["rows"])
            if columns * rows != int(asset["frame_count"]):
                raise ValueError(f"inconsistent authored frame count: {asset['file']}")
            layouts[ROOT / asset["file"]] = (columns, rows)
    return layouts


def authored_visible_rects() -> dict[Path, dict[int, list[list[int]]]]:
    """Optional source slices suppress disconnected neighboring-cell fragments."""
    visible = {}
    for group in ("characters", "enemies", "surfaces", "bureau"):
        data = json.loads((ART / group / "carbon_copy_assets.json").read_text())
        for asset in data["assets"] if isinstance(data, dict) else data:
            frames = asset.get("frame_visible_rects", {})
            if frames:
                visible[ROOT / asset["file"]] = {int(frame): rects for frame, rects in frames.items()}
    return visible


def authored_regions() -> dict[str, tuple[Path, tuple[int, int, int, int]]]:
    """Static atlas regions are authored source-pixel XYWH rectangles per key."""
    regions = {}
    assets = []
    for group in ("weapons", "supports", "bureau"):
        assets.extend(json.loads((ART / group / "carbon_copy_assets.json").read_text()))
    for asset in assets:
        for key, rect in asset.get("regions", {}).items():
            if key in regions or len(rect) != 4 or any(type(value) is not int for value in rect):
                raise ValueError(f"invalid or duplicate static region: {key}")
            regions[key] = (ROOT / asset["path"], tuple(rect))
    return regions


def main() -> None:
    source = CATALOG.read_text()
    paths_block = source.split("const PATHS := {", 1)[1].split("\n}", 1)[0]
    pairs = re.findall(r'&"([^"]+)": "res://([^"]+)"', paths_block)
    layouts = authored_layouts()
    regions = authored_regions()
    visible_rects = authored_visible_rects()
    if set(regions) - {key for key, _ in pairs}:
        raise ValueError("authored static regions have no runtime identity")
    region_paths = {path for path, _ in regions.values()}
    metadata, frames = [], []
    records: dict[Path, dict] = {}
    for key, relative in pairs:
        path = ROOT / relative
        if (key.startswith("character_") or key.startswith("enemy_") or key == "shopkeeper") and path not in layouts:
            raise ValueError(f"animated identity has no authored layout: {key}")
        columns, rows = layouts.get(path, (1, 1))
        if path in region_paths and key not in regions:
            raise ValueError(f"static atlas identity has no authored region: {key}")
        if path not in records:
            records[path] = measure(path, columns, rows)
        record = records[path]
        if key in regions:
            region_path, rect = regions[key]
            if region_path != path or columns * rows != 1:
                raise ValueError(f"static atlas identity disagrees with its source: {key}")
            record = measure(path, source_rect=rect)
            records[path].setdefault("regions", {})[key] = {
                "source_rect_xywh": list(rect), "bounds_ltrb": record["bounds_ltrb"],
                "pivot": record["frame_pivots"][0]}
        width, height = record["size"]
        left, top, right, bottom = record["frame_union_ltrb"]
        il, it, ir, ib = record["frame_bounds_ltrb"][0]
        pivots = ", ".join(f"Vector2({x}, {y})" for x, y in record["frame_pivots"])
        extra = ""
        if path in visible_rects:
            frame_records = []
            for frame, rects in visible_rects[path].items():
                if not 0 <= frame < columns * rows or not 1 <= len(rects) <= 8:
                    raise ValueError(f"invalid visibility slice budget: {key}")
                for x, y, rw, rh in rects:
                    cell_x, cell_y = frame % columns * width // columns, frame // columns * height // rows
                    if rw <= 0 or rh <= 0 or x < cell_x or y < cell_y or x + rw > cell_x + width // columns or y + rh > cell_y + height // rows:
                        raise ValueError(f"visibility slice leaves its own frame: {key}")
                values = ", ".join("Rect2(%s)" % ", ".join(map(str, rect)) for rect in rects)
                frame_records.append(f"{frame}: [{values}]")
            extra = ', "visible_rects": {' + ", ".join(frame_records) + '}'
            records[path]["frame_visible_rects"] = visible_rects[path]
        metadata.append(f'\t&"{key}": {{"size": Vector2({width}, {height}), "region": Rect2({left}, {top}, {right-left}, {bottom-top}), "idle": Rect2({il}, {it}, {ir-il}, {ib-it}), "pivots": [{pivots}]{extra}}},')
        if columns * rows > 1:
            frames.append(f'\t&"{key}": Vector2i({columns}, {rows}),')
    replacement = "const SOURCE_METADATA := {\n" + "\n".join(metadata) + "\n}\n\nconst ATLAS_LAYOUTS := {\n" + "\n".join(frames) + "\n}\n\n"
    start = source.index("const SOURCE_METADATA := {")
    end = source.index("static var _textures", start)
    CATALOG.write_text(source[:start] + replacement + source[end:])
    for folder in [ART, ART / "characters", ART / "enemies", ART / "items", ART / "weapons", ART / "supports", ART / "surfaces", ART / "app_icon", ART / "bureau"]:
        assets = []
        for path in sorted(folder.glob("*.png")):
            assets.append(records.get(path) or measure(path))
        (folder / "manifest.json").write_text(json.dumps({"tool": "built-in imagegen", "art_direction": "Carbon Copy Purgatory", "assets": assets}, indent=2) + "\n")
    count = len(list(ART.rglob("*.png")))
    print(f"catalog: {len(pairs)} identities, {len(frames)} animation strips; {count} PNG provenance measured")


if __name__ == "__main__":
    main()
