# Ember Idle Pilot Brief

## Deliverable

A four-frame transparent idle loop for Ember, the young orange dragon in the current `DungeonNormal` composition.

| Property | Requirement |
| --- | --- |
| Runtime frame | `96x80` RGBA PNG |
| Frame count | exactly 4 |
| Order | `ember-idle-01.png` through `ember-idle-04.png` |
| Timing | `180 ms` per frame, looping |
| Registration | bottom-center; visible feet/belly/tail baseline remains stable |
| Scene placement | bottom-center anchor at integer point `(184, 40)` in the `320x180` SpriteKit scene |
| Facing | three-quarter view facing left, matching the current room composition |
| Motion | subtle breathing across all frames; one readable blink; tail and feet remain planted |
| Background | genuine transparency; no floor, shadow patch, scenery, labels, border, or detached effects |
| Pixel treatment | crisp hard-edged clusters; restrained palette; no antialiasing or resampling blur |

## Identity invariants

- Compact, friendly juvenile dragon silhouette rather than a fierce adult.
- Ember-orange scales with a pale warm belly and horns.
- Large cream eye with dark pupil and approachable expression.
- Two swept-back wings, small dorsal spikes, four grounded limbs, and a curled tail.
- Same silhouette family, proportions, palette family, face, and facing direction in every frame.

## Gameplay-scale judgment

Review at 1x inside a `320x180` composition. Pass when Ember is immediately distinguishable from the kobolds, the breathing reads without looking like translation or camera shake, the blink does not deform the face, and no frame visibly jumps at the bottom-center anchor.

Frame 01 becomes the canonical seed after approval. Reduce Motion uses frame 01.

## Generation prompt contract

Use the current `DungeonNormal` image only as a character/style reference. First generate a clean canonical seed. Then place that approved seed in a four-slot transparent edit canvas and request the entire strip in one edit. Retain the exact prompts next to the outputs.

