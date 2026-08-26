#!/usr/bin/env python3
"""Render the three native Phase 8 generation guides."""

from pathlib import Path

from PIL import Image, ImageDraw


SPECS = {
    "room-320x180.png": (320, 180, (0, 0)),
    "dragon-96x80.png": (96, 80, (48, 78)),
    "kobold-48x64.png": (48, 64, (24, 62)),
}


def main() -> None:
    output = Path("PrototypeArt/guides")
    output.mkdir(parents=True, exist_ok=True)
    for name, (width, height, anchor) in SPECS.items():
        image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        draw.rectangle((2, 2, width - 3, height - 3), outline=(69, 161, 154, 255))
        draw.line((2, height - 3, width - 3, height - 3), fill=(255, 208, 98, 255))
        x, y = anchor
        draw.line((max(0, x - 3), y, min(width - 1, x + 3), y), fill=(217, 77, 8, 255))
        draw.line((x, max(0, y - 3), x, min(height - 1, y + 1)), fill=(217, 77, 8, 255))
        image.save(output / name)
        assert Image.open(output / name).size == (width, height)


if __name__ == "__main__":
    main()
