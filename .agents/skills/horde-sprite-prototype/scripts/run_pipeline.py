#!/usr/bin/env python3
"""Normalize, validate, package, and render QA for one generated Horde strip."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--asset-dir", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--anchor", type=Path, required=True)
    parser.add_argument("--scene-background", type=Path)
    parser.add_argument("--matte", choices=("none", "checker", "dark"), default="none")
    parser.add_argument("--background-min", type=int, default=210)
    parser.add_argument("--neutral-delta", type=int, default=14)
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    asset = manifest["asset"]
    cue = manifest["cue"]
    frame_count = len(manifest["frames"])
    width = manifest["frameSize"]["width"]
    height = manifest["frameSize"]["height"]
    padding = manifest.get("safetyInsetPixels", 0)
    content_scale = manifest.get("contentScale", 1.0)
    normalized = args.asset_dir / "normalized"
    qa = args.asset_dir / "qa"
    script_dir = Path(__file__).parent

    normalize = [
        sys.executable,
        str(script_dir / "normalize_sprite_strip.py"),
        "--input", str(args.input),
        "--out-dir", str(normalized),
        "--frames", str(frame_count),
        "--frame-width", str(width),
        "--frame-height", str(height),
        "--padding", str(padding),
        "--scale-multiplier", str(content_scale),
        "--name", f"{asset}-{cue}",
        "--anchor", str(args.anchor),
        "--lock-frame1",
        "--palette", str(args.palette),
    ]
    if args.matte == "checker":
        normalize.extend([
            "--remove-edge-background",
            "--background-min", str(args.background_min),
            "--neutral-delta", str(args.neutral_delta),
        ])
    elif args.matte == "dark":
        normalize.append("--remove-dark-background")
    run(normalize)

    run([
        sys.executable,
        str(script_dir / "validate_sprite_frames.py"),
        "--manifest", str(args.manifest),
        "--frames-dir", str(normalized),
        "--palette", str(args.palette),
    ])
    render_command = [
        sys.executable,
        str(script_dir / "render_qa.py"),
        "--manifest", str(args.manifest),
        "--frames-dir", str(normalized),
        "--contact-sheet", str(qa / f"{asset}-{cue}-contact-sheet.png"),
        "--preview", str(qa / f"{asset}-{cue}-preview.gif"),
    ]
    if args.scene_background is not None:
        render_command.extend([
            "--scene-background", str(args.scene_background),
            "--scene-contact-sheet", str(qa / f"{asset}-{cue}-scene-1x-contact-sheet.png"),
            "--scene-preview", str(qa / f"{asset}-{cue}-scene-1x-preview.gif"),
        ])
    run(render_command)
    frame_ms = manifest["frames"][0]["durationMilliseconds"]
    frame_paths = [normalized / entry["file"] for entry in manifest["frames"]]
    run([
        sys.executable,
        str(script_dir / "package_pixelorama_project.py"),
        "--output", str(args.asset_dir / f"{asset}-{cue}.pxo"),
        "--tag", cue,
        "--frame-ms", str(frame_ms),
        "--palette", str(args.palette),
        *map(str, frame_paths),
    ])


if __name__ == "__main__":
    main()
