# Frozen Sprite Prototype Workflow

Decision date: 2026-08-24

## Default path

1. Write a cue brief with frame size/count, timing, anchor, motion beats, scene placement, and visual acceptance language.
2. Approve one canonical identity seed per character family.
3. Build a large edit canvas and ask Codex ImageGen for the complete strip in one generation.
4. Retain the prompt and every materially evaluated attempt.
5. Normalize all slots with one shared scale, bottom-center registration, seed lockback, matte cleanup, binary alpha, and nearest project-palette mapping.
6. Run deterministic validation, then inspect a contact sheet and timed preview at 1x.
7. Package approved frames as a tagged Pixelorama `.pxo`; use Pixelorama for subjective pixel edits and timeline review.
8. Re-export/revalidate after edits. Install only approved PNG frames in one bounded SpriteKit atlas.
9. Exercise authored motion, Reduce Motion, background interruption, integer placement, nearest filtering, accessibility equivalence, and the consuming UI contexts.
10. Record attempts and total approved-output effort.

## Frozen contract

| Property | Prototype rule |
| --- | --- |
| Scene | `320x180` |
| Ember cells | `96x80`, two-pixel safety inset |
| Kobold cells | `48x64`, two-pixel safety inset |
| Anchor | bottom-center `(0.5, 0.0)` |
| Palette | project 32-color palette plus transparency |
| Naming | `<asset>-<cue>-<two-digit-frame>.png` |
| Generation | complete strip, never independent frames |
| Runtime | bounded `SKTextureAtlas`, nearest filtering, integer placement |
| Source | tagged Pixelorama `.pxo`, PNG frames, JSON manifest |
| QA | deterministic report, contact sheet, timed preview, 1x in-app inspection |

## Judgment boundary

Automation owns slot extraction, matte/alpha repair, common scale, anchor, palette conformance, naming, validation, source packaging, and QA assembly. A human owns identity, silhouette, expression, motion beats, timing, appeal, and the final gameplay-scale decision.

Generated frames are replaceable prototype art. Keep briefs, prompts, selected and rejected attempts, normalized frames, `.pxo`, manifests, and QA media. Do not ship raw generations, contact sheets, previews, or evidence logs.

## Escalation rules

- Try one targeted Codex strip correction before changing tools.
- Evaluate local ComfyUI only after two representative strip attempts fail for a measured generation or repeatability reason.
- Evaluate Aseprite only when a named Pixelorama editing/export requirement fails.
- Do not add runtime asset-generation, provider, palette-swap, animation-data, or download systems.

Neither optional escalation is justified by the idle and concern pilots.
