#!/usr/bin/env python3
"""Extract and palette-map a five-frame opaque environment family grid."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image

from normalize_sprite_strip import apply_palette


def grid_cells(image: Image.Image, columns: int, rows: int, count: int) -> list[Image.Image]:
    if min(columns, rows, count) < 1 or count > columns * rows:
        raise ValueError("invalid grid geometry")
    return [
        image.crop((
            round(index % columns * image.width / columns),
            round(index // columns * image.height / rows),
            round((index % columns + 1) * image.width / columns),
            round((index // columns + 1) * image.height / rows),
        ))
        for index in range(count)
    ]


def center_crop(image: Image.Image, width: int, height: int) -> Image.Image:
    target_ratio = width / height
    if image.width / image.height > target_ratio:
        cropped_width = round(image.height * target_ratio)
        left = (image.width - cropped_width) // 2
        return image.crop((left, 0, left + cropped_width, image.height))
    cropped_height = round(image.width / target_ratio)
    top = (image.height - cropped_height) // 2
    return image.crop((0, top, image.width, top + cropped_height))


def normalize(
    source: Image.Image,
    manifest: dict,
    palette: Image.Image,
) -> list[Image.Image]:
    layout = manifest["generationLayout"]
    width = manifest["frameSize"]["width"]
    height = manifest["frameSize"]["height"]
    cells = grid_cells(source.convert("RGBA"), layout["columns"], layout["rows"], len(manifest["frames"]))
    frames = []
    for cell in cells:
        opaque = Image.new("RGBA", cell.size, (5, 4, 11, 255))
        opaque.alpha_composite(cell)
        fitted = center_crop(opaque, width, height).resize((width, height), Image.Resampling.NEAREST)
        frames.append(apply_palette(fitted, palette))
    return frames


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    frames = normalize(Image.open(args.input), manifest, Image.open(args.palette))
    args.out_dir.mkdir(parents=True, exist_ok=True)
    for frame, entry in zip(frames, manifest["frames"], strict=True):
        frame.save(args.out_dir / entry["file"])
    print(f"PASS: extracted {len(frames)} row-major frames from {Image.open(args.input).size}; ignored grid cells {manifest['generationLayout'].get('ignoredCells', [])}")


if __name__ == "__main__":
    main()
