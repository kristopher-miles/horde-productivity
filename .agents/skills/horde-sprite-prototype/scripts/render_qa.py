#!/usr/bin/env python3
"""Render a scaled contact sheet and timed GIF from a Horde sprite manifest."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw


def _save_gif(frames: list[Image.Image], durations: list[int], path: Path, loop: bool) -> None:
    converted = [frame.convert("P") for frame in frames]
    path.parent.mkdir(parents=True, exist_ok=True)
    converted[0].save(
        path,
        save_all=True,
        append_images=converted[1:],
        duration=durations,
        loop=0 if loop else 1,
        disposal=2,
    )


def render(
    manifest_path: Path,
    frames_dir: Path,
    contact_path: Path,
    preview_path: Path,
    scale: int,
    scene_background: Path | None = None,
    scene_contact_path: Path | None = None,
    scene_preview_path: Path | None = None,
) -> None:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    frames = [Image.open(frames_dir / entry["file"]).convert("RGBA") for entry in manifest["frames"]]
    durations = [entry["durationMilliseconds"] for entry in manifest["frames"]]
    width, height = frames[0].size
    gap = 4
    sheet = Image.new("RGBA", (len(frames) * width + (len(frames) - 1) * gap, height), "white")
    draw = ImageDraw.Draw(sheet)
    for y in range(0, height, 8):
        for x in range(0, sheet.width, 8):
            color = (232, 235, 240, 255) if (x // 8 + y // 8) % 2 else (250, 250, 252, 255)
            draw.rectangle((x, y, x + 7, y + 7), fill=color)
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * (width + gap), 0))
    contact_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.resize((sheet.width * scale, sheet.height * scale), Image.Resampling.NEAREST).save(contact_path)

    gif_frames: list[Image.Image] = []
    for frame in frames:
        background = Image.new("RGBA", frame.size, (14, 11, 25, 255))
        background.alpha_composite(frame)
        gif_frames.append(background.resize((width * scale, height * scale), Image.Resampling.NEAREST))
    _save_gif(gif_frames, durations, preview_path, manifest.get("loop", False))

    if scene_background is not None:
        if scene_contact_path is None or scene_preview_path is None:
            raise ValueError("scene QA paths are required with a scene background")
        source_scene = Image.open(scene_background).convert("RGBA")
        position = manifest["scenePosition"]
        anchor = manifest["anchor"]
        left = round(position["x"] - width * anchor["x"])
        top = round(source_scene.height - position["y"] - height * (1 - anchor["y"]))
        scenes = []
        for frame in frames:
            scene = source_scene.copy()
            scene.alpha_composite(frame, (left, top))
            scenes.append(scene)
        scene_sheet = Image.new("RGBA", (source_scene.width * len(scenes), source_scene.height), "black")
        for index, scene in enumerate(scenes):
            scene_sheet.alpha_composite(scene, (index * source_scene.width, 0))
        scene_contact_path.parent.mkdir(parents=True, exist_ok=True)
        scene_sheet.save(scene_contact_path)
        _save_gif(scenes, durations, scene_preview_path, manifest.get("loop", False))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--frames-dir", type=Path, required=True)
    parser.add_argument("--contact-sheet", type=Path, required=True)
    parser.add_argument("--preview", type=Path, required=True)
    parser.add_argument("--scale", type=int, default=4)
    parser.add_argument("--scene-background", type=Path)
    parser.add_argument("--scene-contact-sheet", type=Path)
    parser.add_argument("--scene-preview", type=Path)
    args = parser.parse_args()
    if args.scale < 1:
        raise SystemExit("--scale must be positive")
    render(
        args.manifest,
        args.frames_dir,
        args.contact_sheet,
        args.preview,
        args.scale,
        args.scene_background,
        args.scene_contact_sheet,
        args.scene_preview,
    )


if __name__ == "__main__":
    main()
