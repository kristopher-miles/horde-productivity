# Great-Room Background Brief

## Purpose

Create the opaque architectural base for the Cinder Vault. This replaceable prototype layer must establish the warm underground home while leaving every animated or state-dependent element to separate layers.

| Property | Requirement |
| --- | --- |
| Asset/cue | `great-room-background` / `static` |
| Runtime frame | one opaque `320x180` RGBA PNG |
| Order | `great-room-background-static-01.png` |
| Registration | full-scene origin `(0, 0)`; integer placement |
| Scene placement | lower-left origin at `(0, 0)` |
| Motion | none |
| Background | opaque; no unused alpha |
| Pixel treatment | crisp hard-edged clusters in the project palette; no antialiasing |
| Reduce Motion | unchanged static frame |

## Composition invariants

- Preserve the reference's front-facing, slightly elevated view of one cozy stone great room.
- Include stone architecture, broad unlit hearth masonry, alcoves, heavy beams, shelving, and large furniture only.
- Leave open staging areas near `(52, 40)`, `(104, 40)`, `(184, 40)`, and `(269, 40)` for Pip, Moss, Ember, and Rill.
- Keep character staging dark enough for teal, moss, orange, and blue silhouettes to read.
- Exclude Ember, kobolds, other creatures, hearth fire, lantern flames or glow, foreground mushrooms, near-floor occluders, hazard cracks, recovery glow, particles, labels, borders, and text.

## Visual pass

At native `320x180`, the room must read as the warm Cinder Vault without characters. It should support faces and cue silhouettes rather than compete with them. Large forms must survive palette mapping and nearest-neighbor display.

