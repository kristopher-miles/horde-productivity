---
name: horde-sprite-prototype
description: Create, repair, validate, package, and integrate replaceable pixel-art sprites and animation strips for The Horde. Use for Ember, kobolds, room layers, ambient effects, story-cue animations, Pixelorama `.pxo` sources, SpriteKit atlas frames, contact sheets, previews, or prototype-art staffing evidence in this repository.
---

# Horde Sprite Prototype

Produce one bounded, reproducible asset at a time. Favor the proven Codex ImageGen → deterministic cleanup → Pixelorama → SpriteKit path. Do not introduce a general asset system.

## Load the contract

Read [references/asset-contract.md](references/asset-contract.md) before every asset. Read [references/cue-language.md](references/cue-language.md) for character reactions or scene cues. Use `references/palette.png` as the allowed visible palette.

Use Codex's `imagegen` skill for generated bitmap inputs. Preserve the exact prompt and every materially evaluated attempt.

Run bundled scripts with `PrototypeArt/.venv/bin/python` when that environment exists; it owns the pinned Pillow dependency. If it is absent, create it and install `PrototypeArt/requirements.txt` before generating artifacts.

## Create the brief

Create `PrototypeArt/pilots/<asset>-<cue>/brief.md` and `manifest.json` before generation. Specify:

- gameplay purpose and cue;
- canvas, frame count, order, durations, loop/one-shot behavior;
- canonical identity seed and invariants;
- one motion beat per frame;
- bottom-center anchor, scene placement, and Reduce Motion frame;
- visual pass language at 1x.

Copy and fill [assets/manifest-template.json](assets/manifest-template.json). Do not leave filenames, durations, or geometry implicit.

## Generate a complete strip

1. Approve one canonical seed per character family. Reuse it across cues.
2. Read the matching layout in `assets/strip-layouts/`, then build a transparent edit canvas with `scripts/build_sprite_edit_canvas.py`. Four-frame rows use four 256-pixel slots on a 1024 canvas. Six-frame rows use six 160-pixel slots on a 1024 canvas.
3. Ask ImageGen for the entire ordered row in one result. Never generate animation frames independently.
4. State identity invariants, shared scale/baseline/facing, every frame beat, pixel treatment, and forbidden content.
5. Allow either genuine transparency or one removable uniform/checker matte. Do not ask ImageGen repeatedly to repair alpha.
6. Try at most one targeted correction before reassessing the brief or escalating.

Keep generated inputs under `generated/`; never install them directly into the app.

## Normalize and package

Inspect the strip edges and choose `--matte checker`, `dark`, or `none`. For a dark neutral checker, keep `--matte checker` and lower `--background-min` only as far as its sampled edge values require. Run:

```bash
PrototypeArt/.venv/bin/python .agents/skills/horde-sprite-prototype/scripts/run_pipeline.py \
  --input <generated-strip.png> \
  --asset-dir <PrototypeArt/pilots/asset-cue> \
  --manifest <manifest.json> \
  --palette .agents/skills/horde-sprite-prototype/references/palette.png \
  --anchor <approved-seed.png> \
  --scene-background PrototypeArt/references/dungeon-normal-320x180.png \
  --matte <checker|dark|none>
```

This locks frame 1 to the seed, applies one shared scale, registers every frame bottom-center, maps visible colors to the project palette, validates the contract, renders frame and native-scene QA, and writes a tagged `.pxo` source.

If cleanup would erase real sprite detail, stop and make the smallest justified Pixelorama edit. Re-run validation and QA after exporting. Automation must not redraw silhouettes or expressions.

## Review gates

Pass deterministic review only when:

- manifest order equals exported filenames;
- every frame has exact dimensions, RGBA binary alpha, non-empty content, safety inset, common baseline, and allowed colors;
- the `.pxo` has the expected size, frame count, palette, timing, and tag;
- the contact sheet and timed preview exist.

Pass visual review only when the asset reads at 1x in a `320x180` scene and preserves identity, silhouette, expression, facing, apparent scale, timing, and loop/settle quality. Remaining defects may be aesthetic, never structural.

When Pixelorama is installed, verify the source with absolute paths:

```bash
/Applications/Pixelorama.app/Contents/MacOS/Pixelorama --headless --quit -- --size <absolute-project.pxo>
/Applications/Pixelorama.app/Contents/MacOS/Pixelorama --headless --quit -- --framecount <absolute-project.pxo>
```

Ignore the known Godot dummy-renderer warnings only when the requested values print and the process succeeds.

## Integrate only approved frames

Do not change runtime code unless the user asked to integrate and both review gates pass.

For integration:

1. Copy only normalized PNGs into one bounded `<AssetCue>.atlas`.
2. Load frames in manifest order through application-owned identifiers.
3. Set every `SKTexture.filteringMode = .nearest`.
4. Use bottom-center anchors and integer scene coordinates.
5. Remove/replace keyed actions before starting a new cue.
6. Pause safely on backgrounding and settle one-shots deterministically.
7. Under Reduce Motion, show the manifest's representative frame without an action.
8. Preserve an equivalent accessibility description.
9. Run unit and targeted UI tests; inspect normal, story-result, and committed-state screenshots.

Never let generated narrative choose filenames, coordinates, timings, or blend modes.

## Retain evidence

Keep the brief, prompt, raw attempts, selected normalized frames, `.pxo`, manifest, contact sheet, timed preview, decision, and evidence-log row. Record attempts plus generation, editor, and integration minutes. Mark prototype art as replaceable.

Do not retain temporary caches in the repository. Do not ship prompts, raw generations, QA media, or evidence logs in the app bundle.

## Escalate narrowly

- Evaluate local ComfyUI only after two representative Codex strips fail for a recorded repeatability, privacy, latency, or cleanup-cost reason.
- Evaluate Aseprite only when a named Pixelorama editing/export requirement fails.
- Do not add runtime generation, downloading, provider abstractions, palette swapping, shaders, skeletal animation, or a general animation-data engine.
