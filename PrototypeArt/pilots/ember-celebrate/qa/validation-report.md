# Ember Celebrate Validation Report

Validated 2026-08-24 against `manifest.json` and the repository `horde-sprite-prototype` contract.

## Deterministic frame validation

- Validator result: `PASS: manifest.json matches frame, alpha, anchor, inset, and palette contracts`.
- Manifest order: `ember-celebrate-01.png` through `ember-celebrate-06.png`.
- All frames: `96x80`, `RGBA`, non-empty, alpha values exactly `[0, 255]`, and no visible colors outside the 32-color project palette.
- Visible bounds:
  - frame 01: `(4, 2, 92, 78)`, 22 visible colors;
  - frame 02: `(9, 28, 87, 78)`, 23 visible colors;
  - frame 03: `(2, 18, 94, 78)`, 24 visible colors;
  - frame 04: `(4, 11, 91, 78)`, 22 visible colors;
  - frame 05: `(9, 16, 86, 78)`, 22 visible colors;
  - frame 06: `(10, 13, 86, 78)`, 22 visible colors.
- Every visible bottom is `78`, satisfying the shared baseline and two-pixel bottom inset.
- Frame 1 and the approved seed have the identical SHA-256 `e26b863d4501a29024b499f19bea7ba6d9e74b62a60f00e78d80d00996ec809a`.
- Both GIF previews contain 6 frames with durations `[90, 90, 90, 90, 90, 90]` ms and the repository renderer's expected `loop=1` metadata for a manifest with `loop: false`; the authored runtime behavior remains one-shot.

## Pixelorama source validation

- Pixelorama headless `--size` result: `(96, 80)`; exit status 0.
- Pixelorama headless `--framecount` result: `6`; exit status 0.
- Only the contract-documented Godot dummy-renderer shader warnings were emitted.
- Packaged source: Pixelorama `v1.2.1-stable`, 6 frames, `fps=11.11111111111111`, metadata duration `90 ms`, tag `celebrate` from frame 1 through frame 6, and 32 palette entries.
- Source frame order matches the manifest, and all six raw RGBA payloads are byte-identical to their normalized PNG pixels.

## Determinism check

The complete cleanup/package/QA pipeline was rerun in an isolated `/tmp/ember-celebrate-qa.*` directory with the selected raw strip, approved seed, checker-matte cleanup, manifest, and project palette. `diff`/`cmp` reported no differences for the six normalized frames, contact sheet, GIF preview, or `.pxo`. Both source files had SHA-256 `50d8fdc05b674e5e9bf332602b7c72bd819d0ee4f1b6dfa025cf927bd14c31e2`. The isolated directory was removed afterward.

## Native-scale visual review

`ember-celebrate-scene-1x-contact-sheet.png` and `ember-celebrate-scene-1x-preview.gif` render each frame in a `320x180` scene with the `96x80` frame's bottom center at integer point `(184, 40)` (raster top-left placement `(136, 60)`). The sequence reads neutral → crouched anticipation → compact lift → delighted peak → settle → near-neutral without accompanying prose. Frame 04 remains the clearest representative Reduce Motion pose.

## Undocumented workflow knowledge encountered

- The default system `python3` does not have Pillow, while the existing repository environment at `PrototypeArt/.venv/bin/python` does. The skill does not name that environment.
- The edit-canvas script's defaults cannot fit six `256`-pixel slots inside its default `1024`-pixel canvas. This asset used `--slot-size 160 --canvas-size 1024`, yielding a centered 960-pixel strip area without changing the brief's runtime geometry.
- Both generated attempts were opaque RGB images with a bright uniform checker matte, so deterministic `--matte checker` cleanup was required.
