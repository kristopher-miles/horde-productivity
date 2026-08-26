#!/usr/bin/env python3
"""Validate normalized sprite frames against a Horde manifest and palette."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def validate(manifest_path: Path, frames_dir: Path, palette_path: Path) -> list[str]:
    manifest = json.loads(manifest_path.read_text())
    width = manifest["frameSize"]["width"]
    height = manifest["frameSize"]["height"]
    inset = manifest.get("safetyInsetPixels", 0)
    expected = [entry["file"] for entry in manifest["frames"]]
    prefix = f'{manifest["asset"]}-{manifest["cue"]}-'
    actual = sorted(path.name for path in frames_dir.glob(f"{prefix}*.png"))
    allowed = set(Image.open(palette_path).convert("RGB").getdata())
    errors: list[str] = []
    bottoms: set[int] = set()

    if actual != expected:
        errors.append(f"frame order/count mismatch: expected {expected}, found {actual}")
    if len(expected) != len(set(expected)):
        errors.append("manifest contains duplicate frame names")

    for entry in manifest["frames"]:
        if entry["durationMilliseconds"] <= 0:
            errors.append(f'{entry["file"]}: duration must be positive')
        path = frames_dir / entry["file"]
        if not path.exists():
            continue
        source = Image.open(path)
        if source.mode != "RGBA":
            errors.append(f"{path.name}: expected RGBA mode, found {source.mode}")
        image = source.convert("RGBA")
        if image.size != (width, height):
            errors.append(f"{path.name}: expected {width}x{height}, found {image.width}x{image.height}")
        alpha_values = set(image.getchannel("A").getdata())
        if not alpha_values.issubset({0, 255}) or 0 not in alpha_values or 255 not in alpha_values:
            errors.append(f"{path.name}: alpha must contain both transparent and opaque binary pixels")
        bounds = image.getchannel("A").getbbox()
        if bounds is None:
            errors.append(f"{path.name}: frame is empty")
            continue
        left, top, right, bottom = bounds
        bottoms.add(bottom)
        if left < inset or top < inset or right > width - inset or bottom > height - inset:
            errors.append(f"{path.name}: visible bounds {bounds} violate {inset}px safety inset")
        visible = {pixel[:3] for pixel in image.getdata() if pixel[3]}
        extra = visible - allowed
        if extra:
            errors.append(f"{path.name}: {len(extra)} visible colors are outside the project palette")
    if len(bottoms) > 1:
        errors.append(f"bottom anchor drift: visible bottoms are {sorted(bottoms)}")
    return errors


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--frames-dir", type=Path, required=True)
    parser.add_argument("--palette", type=Path, required=True)
    args = parser.parse_args()
    errors = validate(args.manifest, args.frames_dir, args.palette)
    if errors:
        raise SystemExit("\n".join(f"ERROR: {error}" for error in errors))
    print(f"PASS: {args.manifest.name} matches frame, alpha, anchor, inset, and palette contracts")


if __name__ == "__main__":
    main()

