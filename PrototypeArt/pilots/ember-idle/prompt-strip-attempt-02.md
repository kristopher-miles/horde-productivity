# Ember Idle Strip Prompt — Attempt 02

Provider: Codex built-in ImageGen

Reference/edit target: `generated/ember-idle-edit-canvas.png`

```text
Use case: identity-preserve
Asset type: corrected candidate production spritesheet for a 2D pixel-art game animation review
Input image: Image 1 is the original transparent 1024x1024 edit canvas with Ember's approved sprite in the leftmost of four equal 256x256 slots
Primary request: generate the same subtle four-frame idle loop, correcting only the silhouette and apparent-size drift seen in the prior attempt
Critical correction: frames 2, 3, and 4 must match frame 1's exact apparent bounding-box width-to-height ratio, body proportions, head size, wing height and angle, broad curled-tail footprint, horn size, and bottom-center baseline; do not make later frames taller, narrower, smaller, more upright, or more detailed than frame 1
Identity invariants: preserve the exact friendly juvenile dragon, three-quarter view facing left, ember-orange and warm-cream palette family, large readable eye, horns, wings, dorsal spikes, four grounded limbs, and curled tail; keep the supplied leftmost frame visually unchanged
Composition: keep one horizontal row of exactly four equal 256x256 slots across the middle of the 1024x1024 canvas; one complete dragon centered in each slot; equal visual scale; shared bottom-center baseline; genuine transparent alpha elsewhere
Action: frame 1 supplied calm open-eye pose; frame 2 subtle inhale with only a tiny chest rise; frame 3 same bounds and planted body with a closed-eye blink; frame 4 almost identical to frame 1, eye open, seamless loop
Style: authentic production pixel art, same coarse pixel-cluster density as the supplied seed, crisp hard edges, restrained palette, no antialiasing, blur, soft shading, or subpixel detail
Constraints: whole strip in one edit; no redesign of frame 1; no translation, scale drift, facing changes, detached effects, scenery, floor, shadow patch, labels, text, borders, slot dividers, poster layout, glow, watermark, or extra characters
```

Result: selected. Raw output used an opaque checkerboard, repaired deterministically. All four normalized frames share a `y=78` visible baseline, fit the two-pixel inset, and use 22–23 project-palette colors.

