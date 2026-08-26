# VC-06 Blind Power Audit

## Method

`vc06-blind-all-frames.png` was rendered from the committed normalized frames in a deterministic SHA-256 shuffle. It contains five anonymous rows, A–E, with all four idle frames shown in native `320x180` scenes. Every sprite uses its manifest canvas at 1:1 scale, bottom-center anchor `(0.5, 0)`, and runtime-equivalent scene point `(184, 40)` (the SpriteKit-centered equivalent is `(24, -50)`). Stage names are absent from the image; the mapping is stored separately in `vc06-blind-review-key.json` and was not opened until after the following judgment was recorded.

## Judgment recorded before reveal

Predicted weakest to strongest: **A → B → D → C → E**.

- **A → B:** B is taller and more upright, with longer horns, a lifted chest, longer limbs, and a larger wing profile. A remains the smallest, lowest, roundest silhouette.
- **B → D:** D has substantially more torso and chest mass, heavier limbs and tail, broader wing structure, and a firmer forward gaze.
- **D → C:** C has the more imposing horn crown, taller chest, thicker neck and limbs, and a larger folded wing. Its erect posture reads as command, not old-age stoop.
- **C → E:** E is the widest and densest silhouette, with the deepest chest, heaviest forelimbs and haunches, largest wing mass, longest horn crown, and strongest scene presence.
- Across all four columns the same order remains legible. Idle motion changes the head, chest, and tail by only a few native pixels; no frame reverses the power judgment.
- C and E have open, alert eyes and firm mouths. Neither has a drooping head or tail, hunched/stooped back, thin limbs, ragged wings, weary/closed expression, diminished scale, or comic exaggeration.

## Reveal

The key reveals **A = Baby, B = Adolescent, D = Adult, C = Elder, E = Great Wyrm**. The blind prediction exactly matches the authored order: **Baby → Adolescent → Adult → Elder → Great Wyrm**. Elder and Great Wyrm were independently selected as the strongest two, and Great Wyrm as the strongest.

## Quantitative and consistency checks

`vc06-silhouette-metrics.json` records every frame's alpha bounds and occupied pixels. The visible-pixel ranges are strictly separated at every transition: Baby `4,295–4,396`, Adolescent `4,470–4,683`, Adult `6,040–6,322`, Elder `6,553–6,622`, and Great Wyrm `7,820–7,973`. Visible height also separates strictly: `75–76`, `82–86`, `96`, `106`, and `115–116` pixels. Width generally grows (`87–91`, `95–97`, `96`, `106` after Baby's `88–89`); the slight Baby/Adolescent width overlap is visually resolved by Adolescent's height, upright posture, horns, limbs, and wing mass rather than artificial stretching.

All four frames retain a stable baseline and the same posture, anatomy, expression, and relative mass. Source frames and installed atlas frames are byte-identical, and each Pixelorama source reports its matching native canvas with four frames. No correction or ImageGen attempt was needed.
