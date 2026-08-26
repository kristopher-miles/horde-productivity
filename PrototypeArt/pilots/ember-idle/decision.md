# Ember Idle Pilot Decision

Selected identity seed: `normalized/ember-seed-v3-01.png` from seed attempt 01.

Selected animation: strip attempt 02.

## Why

- Attempt 02 keeps nearly identical gameplay-scale bounds across frames: `(4,2,92,78)`, `(3,3,92,78)`, `(4,3,92,78)`, `(4,2,92,78)` after lockback and normalization.
- The blink reads in frame 03 without changing facing direction.
- Bottom registration is identical in all frames.
- The loop is good enough for prototype playtesting; remaining differences are aesthetic cleanup, not structural breakage.

## Proven repairs

- Bright checkerboard: edge-connected neutral removal.
- Black matte: near-black removal plus largest connected component per slot.
- Rectangular contract: shared-scale `96x80` normalization with a two-pixel inset.
- Color drift: nearest-color mapping into the 32-color project palette.
- Seed drift: exact frame-01 lockback.

Do not ask ImageGen to repair transparency again; both direct transparency attempts failed. Apply the deterministic matte repair selected by edge samples, then inspect the result.

