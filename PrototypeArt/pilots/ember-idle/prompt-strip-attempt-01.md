# Ember Idle Strip Prompt — Attempt 01

Provider: Codex built-in ImageGen

Reference/edit target: `generated/ember-idle-edit-canvas.png`

```text
Use case: identity-preserve
Asset type: candidate production spritesheet for a 2D pixel-art game animation review
Input image: Image 1 is the edit target, a transparent 1024x1024 reference canvas with Ember's approved sprite in the leftmost of four equal 256x256 horizontal slots across the middle
Primary request: edit the provided canvas into a single horizontal four-frame idle animation strip
Identity invariants: the existing leftmost sprite is the exact anchor; preserve the same friendly juvenile dragon, three-quarter view facing left, silhouette family, proportions, ember-orange and warm-cream palette family, large readable eye, horns, wings, dorsal spikes, four grounded limbs, and curled tail
Composition: keep the 1024x1024 canvas; exactly one row of four equal 256x256 slots in left-to-right order; one complete dragon centered in each slot; shared scale and bottom-center baseline; genuine transparent alpha everywhere else
Action: frame 1 remains the supplied calm open-eye pose; frame 2 is a very subtle inhale with chest and shoulders raised slightly while feet and tail remain planted; frame 3 is the breath peak with a natural closed-eye blink and only slight body rise; frame 4 eases almost back to frame 1 with eye open, ready to loop seamlessly
Style: authentic production pixel art, crisp hard-edged pixel clusters, restrained palette, no antialiasing, no soft brushwork, no blur, no subpixel detail, not concept art
Constraints: generate the full strip together; frame 1 must not be redesigned; exact four characters only; no independent scale drift, facing changes, camera movement, translation, detached effects, scenery, floor, cast-shadow patch, labels, text, borders, slot dividers, poster layout, glow, watermark, or extra characters
```

Result: rejected for the final pilot because frames 2–4 were too tall/narrow relative to the locked seed. It remains in `normalized-attempt-01/` with a contact sheet and preview.

