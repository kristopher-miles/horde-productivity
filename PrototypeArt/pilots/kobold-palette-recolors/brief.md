# Kobold Palette Recolors Brief

## Purpose

Prove that Baby, Kid, and Adult kobold idle atlases support distinct persisted primary/secondary appearances without redrawing or modifying any of the twelve NPC-03 source frames.

## Contract

- Source: the committed `KoboldBabyIdle`, `KoboldKidIdle`, and `KoboldAdultIdle` atlases.
- Geometry: four `48x64` RGBA frames per age, bottom-center anchor `(0.5, 0)`, 200 ms loop, frame 1 for Reduce Motion.
- Body mask: exact RGB tones `(81,36,15)`, `(117,54,21)`, `(166,83,31)`, `(208,122,47)` only.
- Tunic mask: exact RGB tones `(106,85,70)`, `(154,122,91)`, `(208,181,138)` only.
- Preserve every other RGB value, every alpha value, silhouette bounds, frame order, and source atlas bytes.
- Review the three declared palettes across all three ages and all four frames at native 1x.

The machine-readable palette/ramp source of truth for QA is `contract.json`. Runtime keeps the same finite values in Swift and does not parse authoring manifests.
