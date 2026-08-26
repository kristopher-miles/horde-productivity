# Phase 7 Workflow Status

Updated: 2026-08-24

## Gates

- [x] P0 pilot dimensions, action, placement, and visual reference are explicit.
- [x] P0 32-color candidate palette is extracted, regularized for character families, and recorded.
- [x] P1 Pixelorama UI checks: onion skin, per-frame timing, animation tag, palette selection, nearest-neighbor view, and playback pass.
- [x] P1 Pixelorama source/CLI checks: deterministic `.pxo` packaging replaces the inaccessible native save panel; Pixelorama reopens idle and concern as `96x80`, four-frame projects and re-exports byte-identical sheets.
- [x] P2 one approved Ember seed and two four-frame idle strip attempts are retained with exact prompts and a selection decision.
- [x] P3 deterministic normalization reproduces exact `96x80` frames, palette/alpha/anchor validation, contact sheets, and loop previews.
- [x] P4 idle is integrated in SpriteKit with nearest filtering, integer placement, interruption safety, Reduce Motion, and accessibility equivalence.
- [x] P5 concern is reproduced from the written workflow and integrated.
- [x] Workflow decisions are frozen in `workflow-decision.md`.
- [x] Repository-scoped skill exists and passes the Ember celebrate acceptance run from its written inputs; the run required no parent-task art knowledge and its two exposed setup gaps were repaired in the skill.

## Findings that affect the candidate contract

1. Existing dungeon images are opaque `1672x941` compositions, not native `320x180` layered assets.
2. Pixelorama `v1.2.1` launches headlessly on this machine.
3. The standalone OpenAI skill install omits its shared scripts and references.
4. The upstream normalizer accepts only square output frames; the proven Horde adaptation emits rectangular `96x80` and `48x64` cells with shared-scale bottom registration.
5. Pixelorama's native macOS save panel is not exposed to UI automation; deterministic v7 `.pxo` packaging is the proven source handoff.

## Optional-tool decisions

- ComfyUI: not justified; both required cues passed with Codex ImageGen and deterministic cleanup.
- Aseprite: not justified; Pixelorama passed every required editing and export operation once source packaging bypassed the native dialog.
