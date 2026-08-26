#!/usr/bin/env python3
"""Normalize a horizontal sprite strip into rectangular, bottom-anchored frames.

Adapted from OpenAI's sprite-pipeline normalizer at commit
11c74d6ba24d3a6d48f54a194cd00ef3beea18f9. The Horde adds rectangular
frames and optional edge-connected checkerboard removal.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--frames", type=int, required=True)
    parser.add_argument("--frame-width", type=int, required=True)
    parser.add_argument("--frame-height", type=int, required=True)
    parser.add_argument("--padding", type=int, default=0)
    parser.add_argument("--name", default="frame")
    parser.add_argument("--anchor")
    parser.add_argument("--lock-frame1", action="store_true")
    parser.add_argument("--remove-edge-background", action="store_true")
    parser.add_argument("--remove-dark-background", action="store_true")
    parser.add_argument("--dark-max", type=int, default=1)
    parser.add_argument("--background-min", type=int, default=210)
    parser.add_argument("--neutral-delta", type=int, default=14)
    parser.add_argument("--alpha-threshold", type=int, default=8)
    parser.add_argument("--palette", help="PNG containing the allowed visible RGB colors.")
    return parser.parse_args()


def remove_edge_background(image: Image.Image, minimum: int, neutral_delta: int) -> Image.Image:
    """Clear bright neutral pixels connected to an image edge.

    This removes generated checkerboards without erasing enclosed eye whites or
    warm cream sprite pixels. It intentionally does not guess at arbitrary
    scenery or colored mattes.
    """

    image = image.convert("RGBA")
    pixels = image.load()
    width, height = image.size
    seen: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    def eligible(x: int, y: int) -> bool:
        red, green, blue, alpha = pixels[x, y]
        return alpha > 0 and min(red, green, blue) >= minimum and max(red, green, blue) - min(red, green, blue) <= neutral_delta

    for x in range(width):
        for y in (0, height - 1):
            if eligible(x, y) and (x, y) not in seen:
                seen.add((x, y))
                queue.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            if eligible(x, y) and (x, y) not in seen:
                seen.add((x, y))
                queue.append((x, y))

    while queue:
        x, y = queue.popleft()
        for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            nx, ny = neighbor
            if 0 <= nx < width and 0 <= ny < height and neighbor not in seen and eligible(nx, ny):
                seen.add(neighbor)
                queue.append(neighbor)

    for x, y in seen:
        pixels[x, y] = (0, 0, 0, 0)
    return image


def crop_content(image: Image.Image, alpha_threshold: int) -> Image.Image | None:
    alpha = image.getchannel("A").point(lambda value: 255 if value > alpha_threshold else 0)
    bounds = alpha.getbbox()
    return image.crop(bounds) if bounds else None


def remove_dark_background(image: Image.Image, maximum: int, alpha_threshold: int) -> Image.Image:
    """Clear near-black matte and retain only the largest remaining component."""

    output = image.copy().convert("RGBA")
    pixels = output.load()
    for y in range(output.height):
        for x in range(output.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha <= alpha_threshold or max(red, green, blue) <= maximum:
                pixels[x, y] = (0, 0, 0, 0)

    remaining = {(x, y) for y in range(output.height) for x in range(output.width) if pixels[x, y][3] > alpha_threshold}
    largest: set[tuple[int, int]] = set()
    while remaining:
        component: set[tuple[int, int]] = set()
        queue = deque([remaining.pop()])
        while queue:
            point = queue.popleft()
            component.add(point)
            x, y = point
            for neighbor in (
                (x - 1, y - 1), (x, y - 1), (x + 1, y - 1),
                (x - 1, y), (x + 1, y),
                (x - 1, y + 1), (x, y + 1), (x + 1, y + 1),
            ):
                if neighbor in remaining:
                    remaining.remove(neighbor)
                    queue.append(neighbor)
        if len(component) > len(largest):
            largest = component

    for y in range(output.height):
        for x in range(output.width):
            if (x, y) not in largest:
                pixels[x, y] = (0, 0, 0, 0)
    return output


def split_strip(strip: Image.Image, frames: int) -> list[Image.Image]:
    step = strip.width / frames
    return [strip.crop((round(index * step), 0, round((index + 1) * step), strip.height)) for index in range(frames)]


def compose(content: Image.Image | None, width: int, height: int, scale: float, padding: int) -> Image.Image:
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    if content is None:
        return canvas
    target = content.resize(
        (max(1, round(content.width * scale)), max(1, round(content.height * scale))),
        Image.Resampling.NEAREST,
    )
    canvas.alpha_composite(target, ((width - target.width) // 2, height - padding - target.height))
    return canvas


def apply_palette(image: Image.Image, palette_image: Image.Image) -> Image.Image:
    palette = list(dict.fromkeys(palette_image.convert("RGB").getdata()))
    if not palette:
        raise SystemExit("The palette image contains no colors.")
    output = image.copy().convert("RGBA")
    pixels = output.load()
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    for y in range(output.height):
        for x in range(output.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            source = (red, green, blue)
            target = cache.get(source)
            if target is None:
                target = min(palette, key=lambda color: sum((a - b) ** 2 for a, b in zip(source, color)))
                cache[source] = target
            pixels[x, y] = (*target, alpha)
    return output


def main() -> None:
    args = parse_args()
    if min(args.frames, args.frame_width, args.frame_height) < 1 or args.padding < 0:
        raise SystemExit("Frame count and dimensions must be positive.")
    if args.padding * 2 >= min(args.frame_width, args.frame_height):
        raise SystemExit("--padding leaves no drawable frame area.")
    if args.lock_frame1 and not args.anchor:
        raise SystemExit("--lock-frame1 requires --anchor.")

    strip = Image.open(args.input).convert("RGBA")
    if args.remove_edge_background:
        strip = remove_edge_background(strip, args.background_min, args.neutral_delta)
    slots = split_strip(strip, args.frames)
    if args.remove_dark_background:
        slots = [remove_dark_background(slot, args.dark_max, args.alpha_threshold) for slot in slots]
    contents = [crop_content(slot, args.alpha_threshold) for slot in slots]

    anchor_image = Image.open(args.anchor).convert("RGBA") if args.anchor else None
    anchor_content = crop_content(anchor_image, args.alpha_threshold) if anchor_image else None
    nonempty = [content for content in [*contents, anchor_content] if content is not None]
    if not nonempty:
        raise SystemExit("No sprite content was detected.")
    scale = min(
        (args.frame_width - args.padding * 2) / max(content.width for content in nonempty),
        (args.frame_height - args.padding * 2) / max(content.height for content in nonempty),
    )

    output = Path(args.out_dir)
    output.mkdir(parents=True, exist_ok=True)
    palette_image = Image.open(args.palette) if args.palette else None
    for index, content in enumerate(contents, start=1):
        if index == 1 and args.lock_frame1 and anchor_image is not None and anchor_image.size == (args.frame_width, args.frame_height):
            frame = anchor_image
        elif index == 1 and args.lock_frame1:
            frame = compose(anchor_content, args.frame_width, args.frame_height, scale, args.padding)
        else:
            frame = compose(content, args.frame_width, args.frame_height, scale, args.padding)
        if palette_image is not None:
            frame = apply_palette(frame, palette_image)
        frame.save(output / f"{args.name}-{index:02d}.png")


if __name__ == "__main__":
    main()
