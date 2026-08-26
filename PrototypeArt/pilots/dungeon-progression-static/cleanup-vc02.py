#!/usr/bin/env python3
"""Remove creature-shaped heraldry from the stage 2–4 shield interiors."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).parent
FRAMES = ROOT / "normalized"
PLAIN_METAL = (23, 21, 42, 255)
SHIELD_INTERIORS = {
    2: [(97, 4), (109, 4), (112, 8), (111, 18), (103, 27), (96, 19), (95, 9)],
    3: [(91, 3), (105, 3), (109, 8), (108, 18), (100, 29), (91, 20), (89, 9)],
    4: [(101, 3), (114, 4), (118, 10), (116, 20), (107, 29), (99, 22), (98, 9)],
}

for stage, interior in SHIELD_INTERIORS.items():
    path = FRAMES / f"dungeon-progression-static-{stage:02d}.png"
    image = Image.open(path).convert("RGBA")
    ImageDraw.Draw(image).polygon(interior, fill=PLAIN_METAL)
    image.save(path)

print("PASS: replaced stage 2–4 creature-shaped shield emblems with plain native-pixel metal")
