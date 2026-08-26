# Ember Seed Prompt

Provider: Codex built-in ImageGen

Reference: `TheHorde/Resources/Assets.xcassets/DungeonNormal.imageset/dungeon-normal.png`

```text
Use case: stylized-concept
Asset type: canonical identity seed for a 2D pixel-art game sprite animation
Input image: use the current DungeonNormal image only as a character and style reference; the central orange juvenile dragon is Ember
Primary request: create one clean isolated canonical idle sprite of Ember, matching the central orange dragon's friendly identity and design
Subject: compact friendly juvenile dragon, ember-orange scales, pale warm cream belly and horns, large cream eye with dark pupil, approachable expression, two swept-back wings, small dorsal spikes, four grounded limbs, curled tail
Pose: calm grounded idle pose, three-quarter view facing left, all feet/belly/tail baseline visually stable, full silhouette visible
Style/medium: authentic production pixel art with crisp hard-edged pixel clusters and a restrained palette; readable at a final 96x80 game frame; no antialiasing, no soft brushwork, no blur, no subpixel detail
Composition: exactly one character centered with generous transparent padding; bottom-center registration; no cropping
Color palette: deep violet-black outline, ember orange and red-orange shadow, warm cream highlights, consistent with the supplied room art
Background: genuinely transparent alpha
Constraints: same friendly juvenile identity as the central orange dragon; no scenery, floor, cast shadow patch, labels, text, border, UI, extra characters, detached flame, poster composition, watermark, or glow outside the silhouette
```

Result: attempt 01 retained for identity. ImageGen rendered an opaque checkerboard instead of alpha; deterministic edge-connected cleanup repaired it. A targeted background-removal attempt remained opaque and drifted slightly, so it was rejected.

