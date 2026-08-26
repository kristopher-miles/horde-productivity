# Great-Room Foreground Brief

## Purpose

Create the transparent near-floor occlusion layer that adds depth in front of the staged characters while aligning exactly with the approved great-room background.

| Property | Requirement |
| --- | --- |
| Asset/cue | `great-room-foreground` / `static` |
| Runtime frame | one transparent `320x180` RGBA PNG |
| Order | `great-room-foreground-static-01.png` |
| Registration | full-scene origin `(0, 0)`; integer placement |
| Scene placement | lower-left origin at `(0, 0)` |
| Motion | none |
| Background | genuine transparency outside isolated occluders |
| Pixel treatment | crisp hard-edged clusters in the project palette; no antialiasing |
| Reduce Motion | unchanged static frame |

## Layer content and invariants

- Include only a restrained scattering of near-floor stones, the closest rug edge, two or three low mushrooms, one small basket edge, and similarly compact props that may overlap feet or tails.
- Match the exact front-facing perspective and lower-edge positions of the approved `320x180` background.
- Keep all central face and torso zones clear, especially around `(52, 40)`, `(104, 40)`, `(184, 40)`, and `(269, 40)`.
- Exclude architecture, walls, full furniture, characters, fire, lantern flames, glows, hazard cracks, particles, borders, and text.

## Visual pass

Composite over the approved background at native scale. Pass when the few occluders create foreground depth without hiding faces or cue-defining silhouettes, and when every unused pixel is truly transparent with no fringe.

