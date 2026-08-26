# Hearth Fire Idle Brief

## Purpose

Create a calm four-frame hearth flame loop that gives the layered great room visible ambient life without competing with story reactions.

| Property | Requirement |
| --- | --- |
| Asset/cue | `hearth-fire` / `idle` |
| Runtime frame | `32x32` transparent RGBA PNG |
| Frame count | exactly 4 |
| Order | `hearth-fire-idle-01.png` through `hearth-fire-idle-04.png` |
| Timing | `140 ms` per frame, looping |
| Registration | two-pixel inset, bottom-center, common flame base |
| Scene placement | bottom-center at `(112, 73)` |
| Background | genuine transparency; no hearth masonry or floor |
| Reduce Motion | frame 01, the calmest flame |

## Motion beats

1. Calm compact flame with a broad orange base.
2. Center tongue rises slightly while the base stays planted.
3. Side tongue leans gently with no overall size jump.
4. Flame returns close to frame 01 for a seamless loop.

At native scale the flame must read clearly but remain quieter than a character reaction. Use connected hard clusters only; no smoke, sparks, embers, detached particles, glow field, labels, or scenery.

