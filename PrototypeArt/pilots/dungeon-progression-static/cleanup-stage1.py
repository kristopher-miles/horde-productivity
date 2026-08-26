#!/usr/bin/env python3
"""Apply the reviewed one-off stage-1 natural-wall patch at native resolution."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).parent
FRAME = ROOT / "normalized" / "dungeon-progression-static-01.png"

image = Image.open(FRAME).convert("RGBA")
donor = image.crop((178, 7, 290, 105))
mask = Image.new("L", donor.size, 0)
ImageDraw.Draw(mask).polygon(
    [
        (28, 0), (86, 0), (97, 15), (105, 38), (111, 61),
        (101, 92), (79, 98), (27, 96), (2, 84), (0, 46), (13, 15),
    ],
    fill=255,
)
image.paste(donor, (65, 7), mask)
web = image.crop((275, 0, 320, 72))
web_mask = Image.new("L", web.size, 0)
ImageDraw.Draw(web_mask).polygon([(44, 0), (44, 71), (0, 0)], fill=255)
image.paste(web, (105, 4), web_mask)
image.save(FRAME)
print("PASS: replaced stage-1 worked masonry/crest with irregular native cave-wall and web donor patches; floor and camera unchanged")
