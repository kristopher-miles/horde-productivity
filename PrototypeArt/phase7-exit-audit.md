# Phase 7 Exit Audit

Completed: 2026-08-24

## Outcome

The Codex-first prototype path is accepted for the Phase 8 asset batch. Ember idle and concern are reproducible, editable, previewed, integrated, and runtime-tested. The repository-scoped Horde skill passed a fresh-context Ember celebrate run and was repaired to include every setup detail that run exposed.

## Gate evidence

| Gate | Result | Evidence |
| --- | --- | --- |
| Pixelorama source round trip | Pass | Idle and concern `.pxo` sources open as `96x80`, four-frame tagged projects; horizontal exports are pixel-identical to approved frames. Celebrate opens as `96x80`, six frames. |
| Codex generation | Pass | Idle selected attempt 02/2, concern attempt 01/1, celebrate attempt 02/2 after one targeted correction. |
| Deterministic cleanup | Pass | Seven local script tests pass. Idle, concern, and celebrate pass exact dimension, binary alpha, inset, common baseline, palette, naming, and order validation. |
| Reproducibility | Pass | Saved inputs reproduce cleaned outputs without manual assembly. Celebrate's isolated full rerun produced a byte-identical `.pxo` hash: `50d8fdc05b674e5e9bf332602b7c72bd819d0ee4f1b6dfa025cf927bd14c31e2`. |
| Visual QA | Pass for prototype | Contact sheets, timed previews, and native `320x180` scene previews read correctly. Remaining variation is cluster-level aesthetic debt, not alpha, geometry, identity, or cue-read breakage. |
| SpriteKit integration | Pass | Idle loops; concern/hazard plays one-shot; nearest filtering, integer placement, bottom-center anchoring, keyed action replacement, background pause/resume, Reduce Motion stills, and accessibility equivalence are covered. |
| App tests | Pass | 45 unit tests passed. Two targeted UI tests passed across authored normal/hazard/recovery scenes and positive/negative story results. |
| Skill structure | Pass | Official `quick_validate.py` reports `Skill is valid!`; its bundled pipeline reproduced concern end to end. |
| Fresh-context skill acceptance | Pass | An isolated task created celebrate using only its brief and the repository skill, retained two prompts/attempts, passed deterministic and Pixelorama QA, and did not touch runtime files. |
| Optional tools | Not justified | No measured default-path failure warrants ComfyUI or Aseprite. |

## Frozen files

- Workflow decision: `PrototypeArt/workflow-decision.md`
- Toolchain/provenance: `PrototypeArt/toolchain.md`
- Staffing evidence: `PrototypeArt/evidence-log.md`
- Project skill: `.agents/skills/horde-sprite-prototype/`
- Pilot/acceptance assets: `PrototypeArt/pilots/ember-idle/`, `ember-concern/`, and `ember-celebrate/`
- Runtime atlases: `TheHorde/Resources/EmberIdle.atlas/` and `TheHorde/Resources/EmberConcern.atlas/`

## Known prototype debt

- ImageGen commonly returns opaque checker or dark mattes. Deterministic cleanup is therefore part of the default path, not an exception.
- Generated intermediate poses retain minor pixel-cluster variation and are explicitly replaceable by production art.
- The existing flattened room image still contains the old Ember painting behind the layered runtime sprite; the Phase 8 room-layer work removes that composition debt.
- Today exposes the same tested SpriteKit scene element but may place it below the initial viewport at large content sizes. Dungeon and story-result contexts received direct screenshot review.

None of these items blocks the Phase 8 visual-support batch or changes the staffing measurement purpose of the prototypes.
