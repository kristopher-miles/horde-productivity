# The Horde Prototype Asset Contract

## Shared rules

| Property | Rule |
| --- | --- |
| Scene | Native `320x180` |
| Palette | `palette.png`, maximum 32 visible colors plus transparency |
| Pixel treatment | Hard clusters, nearest-neighbor transforms, no antialiasing |
| Silhouette border | Transparent inset assets use only the first six palette colors on exposed opaque edges |
| Character anchor | Bottom-center `(0.5, 0.0)` |
| Safety inset | Two pixels unless the brief explicitly proves another value |
| Naming | `<asset>-<cue>-<two-digit-frame>.png` |
| Generation | One complete ordered strip, never independent frames |
| Source | Tagged Pixelorama `.pxo`, PNG frames, JSON manifest |
| QA | Deterministic validation, contact sheet, timed preview, 1x scene review |
| Runtime | Bounded SpriteKit atlas, nearest filtering, integer placement |

## Standard cells

- Ember/dragon: `96x80`.
- Kobold/resident: `48x64`.
- Room layers and overlays: `320x180`.
- Hearth fire: `32x32`.
- Lantern flame: `8x16`.

Static room layers may be opaque only when designated as the background. Foreground, character, effect, and overlay assets require genuine alpha.
Set `"opaque": true` in the authoring manifest for that designated background; omit it everywhere else.
Sparse full-scene overlays may set an authoring-only `"contentScale"` from greater than `0` through `1` when native-scene review shows that fit-to-cell normalization overwhelms the composition.

## Ownership boundary

Automation owns extraction, matte cleanup, common scale, anchor, palette mapping, naming, validation, source packaging, and QA assembly. A human owns identity, silhouette, expression, motion, timing, and appeal.

Keep every approved asset structurally interchangeable with future production art. Important text must remain native UI, never pixels inside art.

## Runtime locations

- Sprite atlases: `TheHorde/Resources/<AssetCue>.atlas/`.
- Cue playback: extend the finite mappings in `TheHorde/World/DungeonSceneView.swift`.
- Contract tests: extend `TheHordeTests/Phase6QualificationTests.swift` and the smallest relevant UI test.

Do not parse general manifests at runtime. The JSON manifest is authoring/evidence metadata.
