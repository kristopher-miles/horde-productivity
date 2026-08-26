#!/usr/bin/env python3
"""Render the NPC-03 three-age by five-room frame-01 QA matrix."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).parents[2]
PILOTS = ROOT / "pilots"
AGES = (("Baby", "baby"), ("Kid", "kid"), ("Adult", "adult"))
ROOMS = sorted((PILOTS / "dungeon-progression-static" / "normalized").glob("*.png"))
HEADER = 24
GAP = 4
CELL = (320, 180)

matrix = Image.new(
    "RGBA",
    (len(AGES) * CELL[0] + (len(AGES) - 1) * GAP, HEADER + len(ROOMS) * CELL[1] + (len(ROOMS) - 1) * GAP),
    (5, 4, 11, 255),
)
draw = ImageDraw.Draw(matrix)
font = ImageFont.load_default(size=14)

for column, (label, age) in enumerate(AGES):
    left = column * (CELL[0] + GAP)
    text_box = draw.textbbox((0, 0), label, font=font)
    draw.text((left + (CELL[0] - (text_box[2] - text_box[0])) // 2, 4), label, fill=(255, 224, 138, 255), font=font)
    model = Image.open(PILOTS / f"kobold-{age}-idle" / "normalized" / f"kobold-{age}-idle-01.png").convert("RGBA")
    for row, room_path in enumerate(ROOMS):
        scene = Image.open(room_path).convert("RGBA")
        scene.alpha_composite(model, ((CELL[0] - model.width) // 2, CELL[1] - 40 - model.height))
        matrix.alpha_composite(scene, (left, HEADER + row * (CELL[1] + GAP)))

output = Path(__file__).parent / "kobold-age-idle-3x5-matrix.png"
matrix.save(output)
print(f"PASS: rendered {len(AGES)} ages over {len(ROOMS)} rooms to {output}")
