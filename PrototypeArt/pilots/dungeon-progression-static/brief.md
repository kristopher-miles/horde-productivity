# Dungeon Progression Background Family Brief

## Purpose

Create one replaceable prototype family of five opaque dungeon environment backgrounds for VC-01. The set must communicate a clear environmental progression from a newly claimed desolate cave to a vast golden fortress before any runtime integration. This is a static background family, not an animation and not a runtime asset change.

| Property | Requirement |
| --- | --- |
| Asset/cue | `dungeon-progression` / `static` |
| Runtime candidates | five opaque `320x180` RGBA PNGs |
| Order | `dungeon-progression-static-01.png` through `-05.png`, poorest to richest |
| Registration | full-scene origin `(0, 0)`; identical front-facing, slightly elevated camera |
| Scene placement | lower-left origin at `(0, 0)` |
| Motion | none; the 1200 ms frame durations are QA-preview timing only |
| Loop | no |
| Reduce Motion | stage 1; static presentation is unchanged |
| Pixel treatment | hard-edged 16-bit-era clusters, nearest-neighbor transforms, project palette, at most 32 visible colors |
| Background | fully opaque; no unused alpha |

## Generation strategy and extraction geometry

Generate the complete family in one built-in ImageGen edit so lighting, cave silhouette, camera, floor plane, and structural landmarks remain coherent. The edit target is a deterministic `960x360` 3-by-2 grid. Cells 1–5 are contiguous unlabeled `320x180` copies of the same composition seed in row-major order. Cell 6 is solid chroma magenta, is explicitly unused, and must remain visually unmistakable. There are no separators or gutters to bleed into the five retained cells.

The selected raw generation will be split deterministically into a 3-by-2 grid using rounded equal cell bounds. Only row-major cells 1–5 are extracted; cell 6 is never emitted or listed in the manifest. Each retained cell is center-cropped only if needed to preserve 16:9, resized once to `320x180` with nearest-neighbor sampling, mapped to the project palette, and saved under the manifest filenames.

## Shared camera and staging invariants

- One wide cavern chamber seen front-on from a slightly elevated fixed camera.
- A broad central back-wall arch and the same left/right rock masses establish recognizable shared geometry.
- A readable open lower-center floor supports future independently layered characters.
- Added architecture and treasure may expand backward and upward but must not move the floor horizon or block the central staging area.
- No text, labels, numbers, logos, watermarks, UI, borders, panel dividers, gradients, antialiasing, or smooth painted edges.
- No dragons, kobolds, people, animals, monsters, faces, statues shaped like living creatures, or character silhouettes. VC-02 remains a separate dedicated audit and integration item.

## Ordered environmental beats

1. **Desolate cave:** generic unlit cold cave, rough unstable rock, sparse webs, damp bare floor, sad and empty, with no settlement, furniture, worked stone, fire, treasure, banners, doors, tools, or storage.
2. **Primitive claim:** the same cave minimally claimed with a swept patch, crude unlit stone fire ring, rough sleeping mat, and one primitive storage niche; still cold, sparse, precarious, and poor.
3. **Settled hall:** the same chamber becomes a modest fortified hall with timber braces, fitted stone, a practical hearth, basic shelves and supplies, warmer light, and clear defensibility while retaining open staging.
4. **Rich stronghold:** the hall becomes warm, imposing, and prosperous with carved pillars, ironwork, braziers, deep rugs, fine storage, and restrained gold accents.
5. **Golden fortress:** the same location opens into a vast underground fortress with monumental vaults and deep corridors, overflowing hoarded gold, coins, ingots, treasure chests, and bright gemstones; richest, warmest, largest, and most imposing.

## Visual pass at 1x

An unlabeled five-frame contact sheet must be sortable poorest-to-richest from visual evidence alone. Stage 1 must read as cold, unlit, webbed, sad, and wholly unsettled. Stage 5 must read as a vast underground fortress overflowing with gold and gemstones. All stages must retain the same camera and usable open lower-center staging area, remain legible at native `320x180`, and contain no obvious living creature.
