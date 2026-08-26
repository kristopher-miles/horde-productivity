# Ember Celebrate Acceptance Decision

Selected animation: strip attempt 02.

## Why

- Attempt 01 established the intended neutral → anticipation → lift → delighted peak → settle → near-neutral choreography, but it was rejected because frames 3–4 became tall and bipedal, the wings and proportions drifted from the approved compact seed, and frame 6 did not return closely enough to neutral.
- The single targeted correction in attempt 02 restored a low quadrupedal silhouette, compact wings and legs, the three-quarter-left facing direction, a planted baseline, and a near-neutral final pose while preserving the ordered motion.
- At native `320x180` scene scale and the required bottom-center position `(184, 40)`, frame 2 reads as a crouched anticipation, frames 3–4 open upward, frame 4 is the clearest delighted pose without becoming airborne, and frames 5–6 settle cleanly.
- Deterministic validation passes all manifest, geometry, RGBA binary-alpha, safety-inset, baseline, naming, and palette checks.
- Frame 1 is byte-identical to `PrototypeArt/pilots/ember-idle/normalized/ember-seed-v3-01.png`.
- Pixelorama v1.2.1 opens the packaged source headlessly and reports `(96, 80)` and `6` frames. The source metadata records the `celebrate` tag over frames 1–6, `90 ms` timing, the 32-color project palette, and pixel payloads identical to all six normalized PNGs.
- A clean deterministic rerun reproduced the normalized frames, contact sheet, GIF preview, and `.pxo` byte-for-byte. The `.pxo` SHA-256 was `50d8fdc05b674e5e9bf332602b7c72bd819d0ee4f1b6dfa025cf927bd14c31e2` in both runs.

## Disposition

Accepted as replaceable prototype art. Do not integrate it into the app during this acceptance run.

Minor cluster-level variation in the generated intermediate poses remains aesthetic prototype debt, not a structural or cue-read defect.
