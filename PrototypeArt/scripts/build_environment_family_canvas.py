#!/usr/bin/env python3
"""Build the deterministic 3x2 ImageGen scaffold for a five-frame room family."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def build(seed: Image.Image, *, columns: int = 3, rows: int = 2, count: int = 5) -> Image.Image:
    seed = seed.convert("RGBA")
    if not 0 < count < columns * rows:
        raise ValueError("count must leave at least one unused grid cell")
    canvas = Image.new("RGBA", (seed.width * columns, seed.height * rows), (255, 0, 255, 255))
    for index in range(count):
        x = index % columns * seed.width
        y = index // columns * seed.height
        canvas.alpha_composite(seed, (x, y))
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = build(Image.open(args.seed))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output)


if __name__ == "__main__":
    main()
