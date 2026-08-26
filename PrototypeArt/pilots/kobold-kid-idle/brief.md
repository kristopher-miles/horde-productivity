# Kobold Kid Idle Brief

## Purpose

Create the reusable Kid kobold model and its quiet four-frame idle loop for NPC-03. It bridges Baby and the approved Adult through intermediate proportions rather than color.

| Property | Requirement |
| --- | --- |
| Asset/cue | `kobold-kid` / `idle` |
| Runtime frame | `48x64` transparent RGBA PNG |
| Frame count | exactly 4 |
| Timing | `200 ms` per frame, looping |
| Registration | minimum two-pixel inset; bottom-center `(0.5, 0)`; planted baseline at native y `62` |
| Occupied height | target `49 px`, strictly between Baby and Adult |
| Scene placement | representative bottom-center at `(52, 40)` |
| Facing | three-quarter view facing right |
| Reduce Motion | frame 01 |

## Model identity and invariants

- Friendly young kobold of the approved species: short snout, one readable cream eye, small swept horns, attached curled tail, two arms, and two planted feet.
- Kid proportions: head-to-body ratio and limb length visibly intermediate between Baby and Adult; upright but not adult-tall.
- Stone-brown/orange skin and neutral gray/cream tunic remain visibly palette-separated for later authored recoloring.
- Preserve face, horn count, tail attachment, tunic, facing, apparent scale, and planted baseline in all frames.

## Motion beats

1. Neutral reusable Kid model.
2. Small inhale with no foot movement.
3. Readable blink and tiny tail follow-through.
4. Near-return to neutral for a seamless loop.

No role accessory, weapon, tool, particles, shadow patch, scenery, text, border, watermark, or additional character.

