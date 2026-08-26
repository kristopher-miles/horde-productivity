#!/usr/bin/env python3
"""Render a deterministic, stage-name-free VC-06 review and its sealed key."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--family", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    family = json.loads(args.family.read_text(encoding="utf-8"))
    background = Image.open(args.root / family["background"]).convert("RGBA")
    if background.size != (320, 180):
        raise SystemExit(f"Expected a 320x180 runtime scene, found {background.size}")
    if len(family["stages"]) != 5:
        raise SystemExit(f'Expected five dragon stages, found {len(family["stages"])}')

    # Hash sorting is deterministic without baking the reveal order into the artifact.
    stages = sorted(
        family["stages"],
        key=lambda stage: hashlib.sha256(
            f'vc06-power-blind-v1:{stage["prefix"]}'.encode()
        ).digest(),
    )
    anchor = (family["anchor"]["x"], family["anchor"]["y"])
    if anchor != (184, 40):
        raise SystemExit(f"Expected runtime-equivalent scene anchor (184, 40), found {anchor}")
    font = ImageFont.load_default(size=12)
    review = Image.new("RGBA", (16 + 4 * 320, 5 * 180), (5, 4, 11, 255))
    key: dict[str, str] = {}
    metrics: dict[str, list[dict[str, object]]] = {}

    for row, stage in enumerate(stages):
        identifier = chr(ord("A") + row)
        key[identifier] = stage["label"]
        draw = ImageDraw.Draw(review)
        draw.text((4, row * 180 + 84), identifier, fill=(255, 224, 138, 255), font=font)
        stage_metrics = []
        for frame_index in range(1, 5):
            filename = f'{stage["prefix"]}-{frame_index:02d}.png'
            sprite = Image.open(args.root / stage["directory"] / filename).convert("RGBA")
            expected_size = (stage["width"], stage["height"])
            if sprite.size != expected_size:
                raise SystemExit(f"Expected {filename} to be {expected_size}, found {sprite.size}")

            scene = background.copy()
            position = (anchor[0] - sprite.width // 2, scene.height - anchor[1] - sprite.height)
            scene.alpha_composite(sprite, position)
            review.alpha_composite(scene, (16 + (frame_index - 1) * 320, row * 180))

            alpha = sprite.getchannel("A")
            bounds = alpha.getbbox()
            if bounds is None:
                raise SystemExit(f"Empty frame: {filename}")
            stage_metrics.append(
                {
                    "frame": filename,
                    "visibleBounds": list(bounds),
                    "silhouetteWidth": bounds[2] - bounds[0],
                    "silhouetteHeight": bounds[3] - bounds[1],
                    "visiblePixelCount": sum(value > 0 for value in alpha.getdata()),
                }
            )
        metrics[stage["label"]] = stage_metrics

    ordered_metrics = {stage["label"]: metrics[stage["label"]] for stage in family["stages"]}
    for earlier, later in zip(family["stages"], family["stages"][1:]):
        earlier_frames = ordered_metrics[earlier["label"]]
        later_frames = ordered_metrics[later["label"]]
        for measurement in ("silhouetteHeight", "visiblePixelCount"):
            if max(frame[measurement] for frame in earlier_frames) >= min(
                frame[measurement] for frame in later_frames
            ):
                raise SystemExit(
                    f'{measurement} does not separate {earlier["label"]} from {later["label"]}'
                )

    args.out_dir.mkdir(parents=True, exist_ok=True)
    review.save(args.out_dir / "vc06-blind-all-frames.png")
    (args.out_dir / "vc06-blind-review-key.json").write_text(
        json.dumps(
            {
                "method": "SHA-256 sort of vc06-power-blind-v1:<asset-prefix>",
                "mapping": key,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    (args.out_dir / "vc06-silhouette-metrics.json").write_text(
        json.dumps(ordered_metrics, indent=2) + "\n", encoding="utf-8"
    )
    print(
        "PASS: rendered five anonymous rows x four native 320x180 runtime scenes; "
        "height and occupied area separate every stage"
    )


if __name__ == "__main__":
    main()
