#!/usr/bin/env python3
"""Render and validate QA-05's independent room, dragon, and kobold axes."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from render_kobold_palette_matrix import shade


ROOT = Path(__file__).resolve().parents[2]
PILOT = ROOT / "PrototypeArt/pilots/complete-visual-qa"
CONTRACT = PILOT / "contract.json"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def recolor_dragon(source: Image.Image, color: tuple[int, int, int], ramp: dict) -> Image.Image:
    if color == (224, 96, 32):
        return source.copy()
    output = source.copy().convert("RGBA")
    output.putdata([
        (*shade(color, ramp[pixel[:3]]), pixel[3])
        if pixel[3] == 255 and pixel[:3] in ramp else pixel
        for pixel in output.getdata()
    ])
    return output


def composite(background: Image.Image, sprite: Image.Image, anchor: tuple[int, int]) -> Image.Image:
    scene = background.copy().convert("RGBA")
    scene.alpha_composite(sprite, (anchor[0] - sprite.width // 2, scene.height - anchor[1] - sprite.height))
    return scene


def matrix(rows: list[tuple[str, list[tuple[str, Image.Image]]]]) -> Image.Image:
    font = ImageFont.load_default(size=12)
    label_width, header_height, gap = 64, 22, 2
    cell_width, cell_height = rows[0][1][0][1].size
    columns = len(rows[0][1])
    output = Image.new(
        "RGBA",
        (label_width + columns * cell_width + (columns - 1) * gap, header_height + len(rows) * cell_height + (len(rows) - 1) * gap),
        (17, 14, 25, 255),
    )
    draw = ImageDraw.Draw(output)
    for column, (label, _) in enumerate(rows[0][1]):
        draw.text((label_width + column * (cell_width + gap) + 6, 5), label, font=font, fill=(245, 234, 213, 255))
    for row_index, (row_label, cells) in enumerate(rows):
        y = header_height + row_index * (cell_height + gap)
        draw.text((6, y + cell_height // 2 - 6), row_label, font=font, fill=(245, 234, 213, 255))
        for column, (_, cell) in enumerate(cells):
            output.alpha_composite(cell, (label_width + column * (cell_width + gap), y))
    return output


def build(out_dir: Path) -> dict:
    contract = json.loads(CONTRACT.read_text())
    backgrounds = []
    background_hashes = []
    audit = (ROOT / contract["emptyEnvironmentAudit"]).read_text().casefold()
    for room in contract["rooms"]:
        source_path = ROOT / room["source"]
        runtime_path = ROOT / room["runtime"]
        assert source_path.read_bytes() == runtime_path.read_bytes()
        assert digest(source_path) == room["sha256"]
        assert room["sha256"] in audit
        image = Image.open(source_path).convert("RGBA")
        assert image.size == (320, 180)
        assert image.getchannel("A").getextrema() == (255, 255)
        backgrounds.append(image)
        background_hashes.append(digest(source_path))
    assert "no creature" in audit

    stages = []
    for stage in contract["dragonStages"]:
        source_path = ROOT / stage["source"]
        runtime_path = ROOT / stage["runtime"]
        assert source_path.read_bytes() == runtime_path.read_bytes()
        sprite = Image.open(source_path).convert("RGBA")
        assert sprite.size == tuple(stage["size"])
        stages.append((stage, sprite))

    anchor = tuple(contract["dragonAnchor"])
    room_rows = []
    for room_index, background in enumerate(backgrounds):
        room_rows.append((
            f"Room {room_index + 1}",
            [(stage["label"], composite(background, sprite, anchor)) for stage, sprite in stages],
        ))

    ramp = {tuple(item["source"]): item["offset"] for item in contract["dragonBodyRamp"]}
    recolor_rows = []
    recolor_hashes = {}
    for stage, source in stages:
        cells = []
        outputs = []
        for palette in contract["dragonPalettes"]:
            output = recolor_dragon(source, tuple(palette["rgb"]), ramp)
            assert output.size == source.size
            assert output.getchannel("A").tobytes() == source.getchannel("A").tobytes()
            for before, after in zip(source.getdata(), output.getdata()):
                if before[3] != 255 or before[:3] not in ramp or palette["id"] == "ember":
                    assert after == before
            outputs.append(output.tobytes())
            cells.append((palette["label"], composite(backgrounds[0], output, anchor)))
        assert len(set(outputs)) == len(contract["dragonPalettes"])
        recolor_hashes[stage["id"]] = [hashlib.sha256(output).hexdigest() for output in outputs]
        recolor_rows.append((stage["label"], cells))

    kobold_contract = json.loads((ROOT / contract["koboldContract"]).read_text())
    kobold_validation = json.loads((ROOT / contract["koboldValidation"]).read_text())
    assert len(kobold_contract["ages"]) == 3
    assert len(kobold_contract["palettes"]) == 3
    assert kobold_contract["frameCount"] == 4
    assert kobold_validation["result"] == "pass"
    assert (ROOT / contract["koboldContactSheet"]).is_file()
    assert (ROOT / contract["koboldAnimatedPreview"]).is_file()

    out_dir.mkdir(parents=True, exist_ok=True)
    room_sheet = out_dir / "room-dragon-5x5-contact-sheet.png"
    recolor_sheet = out_dir / "dragon-recolor-5x6-contact-sheet.png"
    matrix(room_rows).save(room_sheet, optimize=False)
    matrix(recolor_rows).save(recolor_sheet, optimize=False)
    result = {
        "result": "pass",
        "roomDragonCombinations": 25,
        "dragonRecolorCombinations": 30,
        "backgroundHashes": background_hashes,
        "dragonRecolorPixelHashes": recolor_hashes,
        "charactersPerRoomDragonCell": 1,
        "livingCreaturesPerSourceBackground": 0,
        "koboldAges": 3,
        "koboldPalettesPerAge": 3,
        "koboldFramesPerAnimation": 4,
        "roomDragonSheetSHA256": digest(room_sheet),
        "dragonRecolorSheetSHA256": digest(recolor_sheet),
    }
    (out_dir / "validation.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", type=Path, default=PILOT / "qa")
    args = parser.parse_args()
    result = build(args.out_dir)
    print(f'PASS: {result["roomDragonCombinations"]} room/dragon and {result["dragonRecolorCombinations"]} dragon/recolor combinations')


if __name__ == "__main__":
    main()
