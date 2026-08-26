# Complete Visual QA Decision

The `5 rooms × 5 dragon stages` sheet renders all 25 independent combinations at native `320x180` scene geometry with exactly one dragon per cell. The `5 stages × 6 accepted colors` sheet proves the runtime-authored palette family without baking recolors into atlases. Both use native sprites, the shared bottom-center anchor `(184, 40)` in top-left image coordinates, and no interpolation.

The room sources remain byte-identical to the five audited zero-character runtime backgrounds. Dragon sources remain byte-identical to runtime atlas frames. Kobold coverage remains the existing native `3 ages × 3 palettes × 4 frames` contact sheet and timed preview, whose exhaustive validator preserves silhouette, alpha, anchors, and source atlases.

The DEBUG runtime fixture uses the same `PixelDungeonScene` compositor: all 25 room/stage combinations animate with nearest filtering at a 1:2 integer display scale, and all six curated dragon colors are independently selectable without changing the room or stage axes.

## Proof map

| Acceptance surface | Deterministic evidence |
| --- | --- |
| Five empty room sources | [`dungeon-progression-static-contact-sheet.png`](../dungeon-progression-static/qa/dungeon-progression-static-contact-sheet.png) and hash-locked [`vc02-creature-audit.md`](../dungeon-progression-static/qa/vc02-creature-audit.md) |
| Five rooms × five dragon stages | [`room-dragon-5x5-contact-sheet.png`](qa/room-dragon-5x5-contact-sheet.png), `DragonStageFixtureView`, and the 25-combination SpriteKit test |
| Five animated dragon stages | [`dragon-stage-family-all-frames.png`](../dragon-stage-family/qa/dragon-stage-family-all-frames.png), [`dragon-stage-family-preview.gif`](../dragon-stage-family/qa/dragon-stage-family-preview.gif), and runtime idle-action assertions |
| Six accepted dragon recolors | [`dragon-recolor-5x6-contact-sheet.png`](qa/dragon-recolor-5x6-contact-sheet.png), six runtime fixture cards, and exact per-stage pixel/alpha assertions |
| Three kobold ages, animations, and recolors | [`kobold-palette-matrix-1x.png`](../kobold-palette-recolors/qa/kobold-palette-matrix-1x.png), [`kobold-palette-matrix-preview.gif`](../kobold-palette-recolors/qa/kobold-palette-matrix-preview.gif), and the existing exhaustive atlas/runtime tests |
| Filtering, anchors, and independent axes | `validation.json`, the DEBUG SpriteKit fixture, and `Phase6QualificationTests` assertions for unchanged room pixels, unchanged dragon pixels, `.nearest`, bottom-center anchors, integer placement, and zero resident nodes |
