# Phase 8 - Sprite Prototype Asset Plan

## Outcome

Produce the smallest coherent asset set that makes The Horde feel alive during ordinary use and makes every validated `AnimationCue` readable during a story reveal. Every asset follows the repository-scoped Horde sprite skill created at the end of [Phase 7](07-sprite-prototype-workflow.md).

These are disposable prototype assets with production intent. They are sufficient for playtesting and for measuring artist effort; they are not assumed to ship.

## Visual support threshold

The prototype crosses the threshold when:

- The room has visible ambient life while no story is resolving.
- Ember, Pip, Moss, and Rill are identifiable at gameplay scale.
- A positive, concern, hazard, recovery, or resource-change cue reads before the accompanying prose is read.
- Normal, hazard, and recovery are compositions of layers and animations rather than three flattened scene replacements.
- The pixel grid remains crisp in every app context.
- Reduce Motion communicates the same state with approved still frames.
- No missing animation, alpha fringe, scale pop, baseline jump, or identity drift distracts a playtester.

## Shared execution recipe

For each asset below:

1. Write one asset brief from its purpose and acceptance notes.
2. Approve one canonical source frame or composition reference.
3. Generate one complete animation strip per requested cue through the Horde skill.
4. Edit identity, silhouette, palette, and timing in Pixelorama.
5. Export normalized PNG frames and QA media.
6. Pass deterministic checks and inspect the loop at 1x in a `320x180` scene.
7. Add the frames to the bounded SpriteKit atlas and map them through application-owned identifiers.
8. Exercise normal motion, Reduce Motion, interruption, and accessibility behavior.
9. Record total approved-output effort in the evidence log.

Do not create bespoke infrastructure for an individual asset. If an asset exposes a generally missing workflow step, repair the Horde skill and rerun that asset.

## Cue composition

The six existing cues should reuse a small set of character and environment animations:

| `AnimationCue` | Character motion | Environment motion | Settle state |
| --- | --- | --- | --- |
| `idle` | Ember and kobold idle loops | Hearth and lantern loops | Continues idle |
| `celebrate` | Ember celebrate; kobolds celebrate | Warm ambient emphasis | Return to idle |
| `concern` | Ember concern; kobolds concern | Optional subtle room dim | Return to idle |
| `recover` | Ember recover; kobolds celebrate | Recovery glow | Return to idle |
| `hazardAppears` | Reuse concern reactions | Hazard overlay | Concern representative frame or idle, based on committed state |
| `resourceChanges` | Reuse recover or idle | Resource-change overlay | Return to idle |

This reuse is deliberate. The prototype does not need six unique rows for every character to prove the experience.

## Asset production order

### A1 - Project palette and layout guides

Deliverables:

- One shared palette file, target maximum 32 visible colors plus transparency.
- Native `320x180` room guide.
- `96x80` dragon frame guide.
- `48x64` kobold frame guide.
- Safe bounds, baseline, and bottom-center anchor marks for generation inputs only.

Acceptance:

- Ember orange, stone violet, warm cream, teal, moss green, blue, hazard accent, and recovery accent are distinguishable.
- Character silhouettes remain readable against both dark stone and warm light.
- Guide pixels never appear in exported art.

### A2 - Great-room background

Asset ID: `great-room-background`

Deliverable: one opaque `320x180` static layer containing the stone architecture, broad hearth structure, alcoves, beams, and large furniture. Use the current normal scene as composition reference, not as pixels to trace blindly.

Keep animated fire, lantern flames, characters, foreground mushrooms, and hazard/recovery changes out of this layer.

Acceptance:

- The room reads as the warm Cinder Vault without characters.
- Open staging areas remain behind Ember and all three kobolds.
- The background supports foreground contrast and does not compete with faces.
- It tiles nowhere and contains no baked lighting animation.

### A3 - Great-room foreground

Asset ID: `great-room-foreground`

Deliverable: one transparent `320x180` occlusion layer containing only near-floor stones, rug edges, baskets, mushrooms, and props that may appear in front of characters.

Acceptance:

- The layer aligns exactly with the background.
- Occluders add depth without covering faces or cue-defining poses.
- Alpha is clean at 1x and no opaque full-canvas pixels remain outside the art.

### A4 - Hearth and lantern ambience

| Asset ID | Canvas | Frames | Initial timing | Reuse |
| --- | ---: | ---: | ---: | --- |
| `hearth-fire-idle` | `32x32` | 4 | 140 ms loop | One hearth |
| `lantern-flame-idle` | `8x16` | 2 | 220 ms loop | All lantern instances with phase offsets |

Acceptance:

- Motion is visible but calmer than a story cue.
- The first and last frames loop without a flash or size jump.
- Reused lanterns do not animate in perfect lockstep.
- Reduce Motion uses the calmest representative frame.

Ambient life plus the layered room is the first playtest checkpoint. Do not proceed if the room still reads as a static illustration.

### A5 - Ember

Canonical identity: a thoughtful young ember-scaled dragon learning to care for a small underground home.

| Asset ID | Frames | Initial timing | Motion brief |
| --- | ---: | ---: | --- |
| `ember-idle` | 4 | 180 ms loop | Breath, blink, small tail or wing follow-through; fixed grounded pose |
| `ember-celebrate` | 6 | 90 ms one-shot | Clear lift and delighted expression; restrained enough for repeated goal completions |
| `ember-concern` | 4 | 140 ms one-shot | Ears/wings/head draw inward; readable but not catastrophic |
| `ember-recover` | 5 | 110 ms one-shot | Relax from tension into a steady, hopeful pose |

Acceptance:

- Name customization does not affect the visual identity.
- Horns, wings, face, scale color, and body proportions remain stable across every row.
- The four cues are distinguishable in silhouette at scene scale.
- No frame changes the baseline, apparent body size, or facing direction accidentally.
- Idle is subtle; the three authored reactions have clear beginnings and settle paths.

Ember is the second playtest checkpoint and the first meaningful artist-effort measurement.

### A6 - Shared kobold animation master

Canonical identity: one compact resident body plan that can support Pip, Moss, and Rill without making them look like unrelated species.

| Asset ID | Frames | Initial timing | Motion brief |
| --- | ---: | ---: | --- |
| `kobold-master-idle` | 4 | 200 ms loop | Small breath/blink with stable feet |
| `kobold-master-celebrate` | 4 | 100 ms one-shot | Upward gesture or bounce with no detached effects |
| `kobold-master-concern` | 4 | 150 ms one-shot | Shared glance or guarded posture, calm rather than alarmed |

Acceptance:

- All frames can be recolored and accessorized without redrawing the body motion.
- Hands, feet, snout, eyes, and tail remain readable inside `48x64`.
- The master is intentionally plain enough to receive the three resident identities.

### A7 - Pip, Moss, and Rill variants

Derive three complete exported frame sets from the approved kobold master. Runtime code receives ordinary frames; it does not need a palette-swap or accessory compositing system.

| Asset ID | Identity cue | Palette cue | Prop/accessory ceiling |
| --- | --- | --- | --- |
| `pip` | Practical, bright-eyed lantern keeper fond of careful lists | Teal and warm gold | One compact lantern-keeper detail; no readable list or text |
| `moss` | Patient, quietly inventive mushroom tender | Moss green and cream | One mushroom-tender detail that stays attached |
| `rill` | Steady-handed, curious stone mender | Slate blue and stone gray | One small mending-tool or apron detail that stays attached |

Each variant needs `idle`, `celebrate`, and `concern` using the master timing and anchors.

Acceptance:

- Residents are distinguishable by silhouette detail and palette, not color alone.
- Accessories remain attached and do not swap hands, disappear, or change shape between frames.
- Shared motion does not look like exact synchronized cloning when composed; use phase offsets for idle playback.
- Recoloring does not violate the project palette.

The resident group is the third playtest checkpoint. It also measures the difference between a new animation family and a controlled variant.

### A8 - Hazard overlay

Asset ID: `room-hazard-appears`

Deliverable: a transparent `320x180`, four-frame, approximately 120 ms one-shot overlay that can indicate a bounded dungeon concern without naming a specific generated story. Favor local light change, a crack/draft cue, or subtle environmental motion over global camera shake.

Acceptance:

- The cue reads as concern, not catastrophe or combat.
- It composes over the same room without replacing the room image.
- It does not obscure character reactions or rely on text.
- Its final state can remain as a restrained static layer when committed world state is hazardous.
- Reduce Motion displays that final representative state directly.

### A9 - Resource-change overlay

Asset ID: `room-resource-change`

Deliverable: a transparent `320x180`, six-frame, approximately 90 ms one-shot overlay that draws attention to meaningful room resources through restrained light, repaired stone, stocked food, or similarly reusable environmental cues.

Acceptance:

- The cue reads as a material change rather than generic celebration.
- It can accompany either a positive or recoverable state without contradicting prose.
- Effects remain inside the room and disappear cleanly before idle resumes.
- Reduce Motion displays the most informative still frame.

### A10 - Recovery treatment

Asset ID: `room-recovery-glow`

Deliverable: one transparent static room overlay or a two-frame restrained transition, chosen after in-engine review. Reuse Ember `recover` and kobold `celebrate`; do not create another full character animation family.

Acceptance:

- Recovery is warmer and steadier than normal without washing out the limited palette.
- The effect can persist behind the representative recovery frame under Reduce Motion.
- No separate flattened recovery scene is required.

### A11 - Scene compositions and cue mapping

Create three state compositions from the approved layers:

| Composition | Layers |
| --- | --- |
| Normal | Background, ambient fire/lanterns, character idles, foreground |
| Hazard | Normal base, concern reactions, hazard overlay, foreground |
| Recovery | Normal base, recover/celebrate reactions, recovery treatment, foreground |

Map all six `AnimationCue` cases through finite application-owned code. The generated narrative can select a validated cue only; it cannot choose filenames, coordinates, durations, or blend modes.

Acceptance:

- Every cue selects only existing atlas frames.
- A one-shot reaction returns to the correct committed-state composition.
- Multiple quick reveals do not stack actions or leave characters in a transient frame.
- Backgrounding, interruption, and Reduce Motion settle deterministically.
- Dungeon, Today, story result, and Chronicle contexts show the same committed visual state at appropriate scale.

## Playtest and staffing evidence

After each checkpoint, ask playtesters only observable questions:

- Which character drew your attention, and who did you think they were?
- What changed in the room?
- Did the reaction feel positive, concerned, recovering, or unclear?
- Did anything look broken, distracting, or too busy?
- Did the animation finish before you could understand it?

Record confusion and defects by asset/cue. Do not ask whether the art is “good enough”; determine whether it supports comprehension and delight.

Estimate production staffing from:

```text
sum(approved asset count × measured median approved-output hours by asset class)
÷ available focused art hours per artist in the target milestone
+ explicit revision and art-direction buffer
```

Keep separate medians for room layers, new character animation families, controlled character variants, and overlays. Generated attempts, cleanup, revisions, QA, and integration all count toward approved-output hours.

## Scope ceiling

Do not add these until playtesting identifies a visual-support failure:

- Walking/navigation directions or a traversable dungeon.
- Combat, attacks, inventories, equipment animation, or procedural rooms.
- Unique animation geometry for each kobold.
- More dungeon locations or seasonal room variants.
- Runtime palette swapping, skeletal animation, shaders, or a general animation data engine.
- Sound production beyond the existing product plan.
- Production polish, marketing art, or App Store screenshots.

## Phase exit criteria

- All assets A1-A11 pass their deterministic and visual gates.
- The room is layered and alive at rest.
- Ember and all three residents remain identifiable throughout their required motions.
- Every `AnimationCue` is readable and maps to bounded authored assets.
- Normal, hazard, and recovery are state compositions, not flattened replacement scenes.
- Reduce Motion, VoiceOver equivalence, background interruption, and nearest-neighbor rendering pass in every consuming surface.
- Playtesting meets the visual support threshold or leaves a short asset-specific repair list.
- Approved-output effort is complete enough to estimate production art staffing by asset class.
