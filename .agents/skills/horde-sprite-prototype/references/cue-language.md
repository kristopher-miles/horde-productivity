# Cue Language

Use these meanings to keep generated motion compatible with the product's authored `AnimationCue` values.

| Cue | Read | Character motion | Environment | Settle |
| --- | --- | --- | --- | --- |
| `idle` | safe ambient life | breath, blink, restrained follow-through | hearth/lantern loops | loop |
| `celebrate` | clear positive outcome | lift, delighted expression, compact upward gesture | optional warm emphasis | return to idle |
| `concern` | bounded worry, not catastrophe | head/wings/body draw inward; readable eye | optional subtle dim | concerned hold, then committed state |
| `recover` | tension becoming steady hope | relax and open from concern | restrained recovery glow | return to idle |
| `hazardAppears` | concern is now present | reuse concern | local crack, draft, or light change | committed hazard still |
| `resourceChanges` | material room change | reuse recover or idle | repaired/stocked/light overlay | return to committed state |

## Motion constraints

- Preserve facing direction, planted baseline, apparent scale, body proportions, face, palette family, and attached accessories.
- Favor a readable silhouette change over particles or camera movement.
- Keep idle quieter than story reactions.
- Keep concern calm: no tears, panic, combat, global shake, or disaster imagery.
- Make one-shot frame 1 the approved neutral/committed seed unless the brief proves another start.
- Select a representative final or peak frame for Reduce Motion.

## Initial timing vocabulary

- Ember idle: 4 frames × 180 ms, loop.
- Ember concern: 4 frames × 140 ms, one-shot.
- Ember celebrate: 6 frames × 90 ms, one-shot.
- Ember recover: 5 frames × 110 ms, one-shot.
- Kobold idle: 4 frames × 200 ms, loop.
- Kobold celebrate: 4 frames × 100 ms, one-shot.
- Kobold concern: 4 frames × 150 ms, one-shot.
- Hearth idle: 4 frames × 140 ms, loop.
- Lantern idle: 2 frames × 220 ms, loop.

Treat these as authored starting values. Change them only after 1x review and record the decision.
