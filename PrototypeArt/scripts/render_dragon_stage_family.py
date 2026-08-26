#!/usr/bin/env python3
"""Render the five ordered dragon idle stages at exact runtime geometry."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def labeled_scene(background: Image.Image, sprite: Image.Image, label: str, anchor: tuple[int, int]) -> Image.Image:
    scene = background.copy().convert("RGBA")
    x = anchor[0] - sprite.width // 2
    y = scene.height - anchor[1] - sprite.height
    scene.alpha_composite(sprite, (x, y))
    output = Image.new("RGBA", (scene.width, scene.height + 20), (5, 4, 11, 255))
    output.alpha_composite(scene)
    draw = ImageDraw.Draw(output)
    font = ImageFont.load_default(size=12)
    bounds = draw.textbbox((0, 0), label, font=font)
    draw.text(((scene.width - (bounds[2] - bounds[0])) // 2, scene.height + 2), label, fill=(255, 224, 138, 255), font=font)
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--family", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    family = json.loads(args.family.read_text(encoding="utf-8"))
    stages = family["stages"]
    labels = [stage["label"] for stage in stages]
    if labels != ["Baby", "Adolescent", "Adult", "Elder", "Great Wyrm"]:
        raise SystemExit("Dragon stage labels or order changed")
    sizes = [(stage["width"], stage["height"]) for stage in stages]
    if not all(a[0] < b[0] and a[1] < b[1] for a, b in zip(sizes, sizes[1:])):
        raise SystemExit("Dragon stage sizes must increase")

    background = Image.open(args.root / family["background"]).convert("RGBA")
    anchor = (family["anchor"]["x"], family["anchor"]["y"])
    rows: list[list[Image.Image]] = []
    for stage in stages:
        frames = []
        for index in range(1, 5):
            path = args.root / stage["directory"] / f'{stage["prefix"]}-{index:02d}.png'
            sprite = Image.open(path).convert("RGBA")
            if sprite.size != (stage["width"], stage["height"]):
                raise SystemExit(f"Unexpected frame size: {path}")
            frames.append(labeled_scene(background, sprite, stage["label"], anchor))
        rows.append(frames)

    cell_width, cell_height = rows[0][0].size
    contact = Image.new("RGBA", (cell_width * 5, cell_height), (0, 0, 0, 255))
    for column, row in enumerate(rows):
        contact.alpha_composite(row[0], (column * cell_width, 0))

    all_frames = Image.new("RGBA", (cell_width * 4, cell_height * 5), (0, 0, 0, 255))
    for row_index, row in enumerate(rows):
        for column, frame in enumerate(row):
            all_frames.alpha_composite(frame, (column * cell_width, row_index * cell_height))

    preview = []
    for frame_index in range(4):
        composite = Image.new("RGBA", contact.size, (0, 0, 0, 255))
        for column, row in enumerate(rows):
            composite.alpha_composite(row[frame_index], (column * cell_width, 0))
        preview.append(composite.convert("P", palette=Image.Palette.ADAPTIVE))

    args.out_dir.mkdir(parents=True, exist_ok=True)
    contact.save(args.out_dir / "dragon-stage-family-contact-sheet.png")
    all_frames.save(args.out_dir / "dragon-stage-family-all-frames.png")
    preview[0].save(
        args.out_dir / "dragon-stage-family-preview.gif",
        save_all=True,
        append_images=preview[1:],
        duration=family["durationMilliseconds"],
        loop=0,
        disposal=2,
    )


if __name__ == "__main__":
    main()
