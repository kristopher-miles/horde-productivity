# Lantern Flame Idle Brief

## Purpose

Create a tiny two-frame lantern flame loop reusable at multiple room positions with phase offsets.

| Property | Requirement |
| --- | --- |
| Asset/cue | `lantern-flame` / `idle` |
| Runtime frame | `8x16` transparent RGBA PNG |
| Frame count | exactly 2 |
| Order | `lantern-flame-idle-01.png` through `lantern-flame-idle-02.png` |
| Timing | `220 ms` per frame, looping |
| Registration | two-pixel inset, bottom-center, common flame base |
| Scene placement | representative bottom-center at `(43, 100)`; runtime may reuse at other lanterns |
| Background | genuine transparency; no lantern housing |
| Reduce Motion | frame 01 |

Frame 01 is a calm three-color teardrop. Frame 02 is a one-pixel-height/facing variation with the same base. It must remain readable at native scale without flashing or changing apparent mass. No glow, smoke, sparks, detached pixels, scenery, labels, or text.

