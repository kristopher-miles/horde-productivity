# Kobold Baby Idle Brief

## Purpose

Create the reusable Baby kobold model and its quiet four-frame idle loop for NPC-03. It must remain recognizably related to the approved adult kobold while reading younger through proportions rather than color.

| Property | Requirement |
| --- | --- |
| Asset/cue | `kobold-baby` / `idle` |
| Runtime frame | `48x64` transparent RGBA PNG |
| Frame count | exactly 4 |
| Timing | `200 ms` per frame, looping |
| Registration | minimum two-pixel inset; bottom-center `(0.5, 0)`; planted baseline at native y `62` |
| Occupied height | target `39 px`, strictly smaller than Kid and Adult |
| Scene placement | representative bottom-center at `(52, 40)` |
| Facing | three-quarter view facing right |
| Reduce Motion | frame 01 |

## Model identity and invariants

- Friendly baby kobold of the approved species: short snout, one readable cream eye, tiny swept horn buds, attached curled tail, two arms, and two planted feet.
- Baby proportions: head visibly larger relative to torso, limbs shorter, feet compact, posture slightly lower than Kid or Adult.
- Stone-brown/orange skin and neutral gray/cream tunic remain visibly palette-separated for later authored recoloring.
- Preserve face, horn count, tail attachment, tunic, facing, apparent scale, and planted baseline in all frames.

## Motion beats

1. Neutral reusable Baby model.
2. Tiny inhale with no foot movement.
3. Readable blink and minimal tail-tip follow-through.
4. Near-return to neutral for a seamless loop.

No role accessory, weapon, tool, particles, shadow patch, scenery, text, border, watermark, or additional character.

