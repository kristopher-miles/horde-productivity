#!/usr/bin/env python3
"""Validate NPC-04 exact-tone recolors and render deterministic native QA."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
PILOT = ROOT / "PrototypeArt/pilots/kobold-palette-recolors"
CONTRACT = PILOT / "contract.json"
QA = PILOT / "qa"


def shade(color: tuple[int, int, int], offset: float) -> tuple[int, int, int]:
    components = [channel / 255 for channel in color]
    maximum, minimum = max(components), min(components)
    delta = maximum - minimum
    saturation = 0 if maximum == 0 else delta / maximum
    if delta == 0:
        hue = 0
    elif maximum == components[0]:
        hue = ((components[1] - components[2]) / delta % 6) / 6
    elif maximum == components[1]:
        hue = ((components[2] - components[0]) / delta + 2) / 6
    else:
        hue = ((components[0] - components[1]) / delta + 4) / 6
    sector = hue * 6
    brightness = 0.35 + maximum * 0.35 + offset
    chroma = brightness * saturation
    secondary = chroma * (1 - abs(sector % 2 - 1))
    match = brightness - chroma
    if sector < 1:
        rgb = (chroma, secondary, 0)
    elif sector < 2:
        rgb = (secondary, chroma, 0)
    elif sector < 3:
        rgb = (0, chroma, secondary)
    elif sector < 4:
        rgb = (0, secondary, chroma)
    elif sector < 5:
        rgb = (secondary, 0, chroma)
    else:
        rgb = (chroma, 0, secondary)
    return tuple(math.floor((channel + match) * 255 + 0.5) for channel in rgb)


def recolor(image: Image.Image, palette: dict, body: dict, tunic: dict) -> Image.Image:
    output = image.copy().convert("RGBA")
    pixels = []
    for red, green, blue, alpha in output.getdata():
        source = (red, green, blue)
        if alpha == 255 and source in body:
            red, green, blue = shade(tuple(palette["primary"]), body[source])
        elif alpha == 255 and source in tunic:
            red, green, blue = shade(tuple(palette["secondary"]), tunic[source])
        pixels.append((red, green, blue, alpha))
    output.putdata(pixels)
    return output


def bounds(image: Image.Image):
    return image.getchannel("A").getbbox()


def checker(size: tuple[int, int]) -> Image.Image:
    image = Image.new("RGBA", size, (31, 27, 42, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], 4):
        for x in range(0, size[0], 4):
            if (x // 4 + y // 4) % 2:
                draw.rectangle((x, y, x + 3, y + 3), fill=(43, 38, 55, 255))
    return image


def main() -> None:
    contract = json.loads(CONTRACT.read_text())
    width = contract["frameSize"]["width"]
    height = contract["frameSize"]["height"]
    body = {tuple(item["source"]): item["offset"] for item in contract["bodyRamp"]}
    tunic = {tuple(item["source"]): item["offset"] for item in contract["tunicRamp"]}
    mapped = set(body) | set(tunic)
    font = ImageFont.load_default(size=12)
    QA.mkdir(exist_ok=True)
    sources: dict[str, list[Image.Image]] = {}
    hashes: dict[str, dict[str, object]] = {}

    for age in contract["ages"]:
        frames = []
        hashes[age["id"]] = {}
        for number in range(1, contract["frameCount"] + 1):
            filename = f'{age["prefix"]}-{number:02d}.png'
            atlas_path = ROOT / age["atlas"] / filename
            normalized_path = ROOT / age["normalized"] / filename
            assert atlas_path.read_bytes() == normalized_path.read_bytes(), f"source/runtime mismatch: {filename}"
            source = Image.open(atlas_path).convert("RGBA")
            assert source.size == (width, height)
            visible = {pixel[:3] for pixel in source.getdata() if pixel[3] == 255}
            assert mapped <= visible, f"missing authored ramp tone: {filename}"
            frames.append(source)
            hashes[age["id"]][filename] = {
                "sourceSHA256": hashlib.sha256(atlas_path.read_bytes()).hexdigest(),
                "outputs": {},
            }
        sources[age["id"]] = frames

    label_width, frame_gap, cell_pad, header_height, row_height = 56, 2, 8, 28, height + 24
    cell_width = width * contract["frameCount"] + frame_gap * (contract["frameCount"] - 1) + cell_pad * 2
    matrix = Image.new("RGBA", (label_width + cell_width * 3, header_height + row_height * 3), (17, 14, 25, 255))
    draw = ImageDraw.Draw(matrix)
    for column, palette in enumerate(contract["palettes"]):
        draw.text((label_width + column * cell_width + cell_pad, 7), palette["label"], font=font, fill=(245, 234, 213, 255))
    for row, age in enumerate(contract["ages"]):
        y = header_height + row * row_height
        draw.text((8, y + height // 2 - 6), age["label"], font=font, fill=(245, 234, 213, 255))
        for column, palette in enumerate(contract["palettes"]):
            x = label_width + column * cell_width + cell_pad
            matrix.alpha_composite(checker((cell_width - cell_pad * 2, height)), (x, y))
            output_hashes = []
            for frame_index, source in enumerate(sources[age["id"]]):
                output = recolor(source, palette, body, tunic)
                assert output.getchannel("A").tobytes() == source.getchannel("A").tobytes()
                assert bounds(output) == bounds(source)
                for source_pixel, output_pixel in zip(source.getdata(), output.getdata()):
                    expected = recolor(Image.new("RGBA", (1, 1), source_pixel), palette, body, tunic).getpixel((0, 0))
                    assert output_pixel == expected
                    if source_pixel[3] != 255 or source_pixel[:3] not in mapped:
                        assert output_pixel == source_pixel
                digest = hashlib.sha256(output.tobytes()).hexdigest()
                output_hashes.append(digest)
                filename = f'{age["prefix"]}-{frame_index + 1:02d}.png'
                hashes[age["id"]][filename]["outputs"][palette["id"]] = digest
                matrix.alpha_composite(output, (x + frame_index * (width + frame_gap), y))
            assert len(set(output_hashes)) == contract["frameCount"]

    matrix.save(QA / "kobold-palette-matrix-1x.png", optimize=False)
    for age_frames in hashes.values():
        for frame in age_frames.values():
            assert len(set(frame["outputs"].values())) == len(contract["palettes"])

    preview_frames = []
    preview_cell_width, preview_label_width = width + 20, 56
    for frame_index in range(contract["frameCount"]):
        preview = Image.new("RGBA", (preview_label_width + preview_cell_width * 3, header_height + row_height * 3), (17, 14, 25, 255))
        preview_draw = ImageDraw.Draw(preview)
        for column, palette in enumerate(contract["palettes"]):
            preview_draw.text((preview_label_width + column * preview_cell_width + 4, 7), palette["id"], font=font, fill=(245, 234, 213, 255))
        for row, age in enumerate(contract["ages"]):
            y = header_height + row * row_height
            preview_draw.text((8, y + height // 2 - 6), age["label"], font=font, fill=(245, 234, 213, 255))
            for column, palette in enumerate(contract["palettes"]):
                x = preview_label_width + column * preview_cell_width + 10
                preview.alpha_composite(checker((width, height)), (x, y))
                preview.alpha_composite(recolor(sources[age["id"]][frame_index], palette, body, tunic), (x, y))
        preview_frames.append(preview.convert("P", palette=Image.Palette.ADAPTIVE, colors=64))
    preview_frames[0].save(
        QA / "kobold-palette-matrix-preview.gif",
        save_all=True,
        append_images=preview_frames[1:],
        duration=contract["durationMilliseconds"],
        loop=0,
        disposal=2,
        optimize=False,
    )
    (QA / "validation.json").write_text(json.dumps({"contract": "contract.json", "result": "pass", "frames": hashes}, indent=2) + "\n")
    print("PASS: 3 ages × 3 palettes × 4 frames; exact ramps, alpha, bounds, and source/runtime equality verified")


if __name__ == "__main__":
    main()
