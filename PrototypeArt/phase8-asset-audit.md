# Phase 8 Asset Suite Audit

Completed: 2026-08-25

## Outcome

The full documented prototype image and graphics suite exists as replaceable, reproducible development art. The batch adds 73 normalized runtime-candidate PNG frames to the 14 approved Phase 7 Ember frames, for 87 frames across the complete visual suite. It also includes three native layout guides, four native state-composition QA images, exact prompts, raw attempts, manifests, contact sheets, timed previews, decisions, and tagged Pixelorama sources.

Runtime integration was intentionally not performed. The Horde skill permits integration only when explicitly requested after both art gates pass; this run was scoped to creating the images and graphics. A11's visual compositions are proven in `PrototypeArt/phase8-qa/`, while SpriteKit atlas installation and cue mapping remain a separate implementation step.

## Asset inventory

| Plan item | Result |
| --- | --- |
| A1 palette and layout guides | Existing 32-color palette plus new `320x180`, `96x80`, and `48x64` guides |
| A2 great-room background | One opaque layered-room base with unlit hearth and lantern housings |
| A3 great-room foreground | One aligned transparent near-floor occlusion layer |
| A4 ambience | Four-frame hearth loop and two-frame lantern loop |
| A5 Ember | Existing idle, celebrate, and concern rows plus new five-frame recover row |
| A6 kobold master | Canonical compact seed plus idle, celebrate, and concern rows |
| A7 residents | Pip, Moss, and Rill idle, celebrate, and concern rows; 36 frames total |
| A8 hazard | Corrected four-frame narrow crack/draft overlay |
| A9 resource change | Six-frame repaired-stone and stocked-food overlay |
| A10 recovery | Two-frame restrained reflected-light treatment |
| A11 compositions | Native Normal, Hazard, Recovery, and Resource Change QA compositions; runtime mapping not changed |

## Gate evidence

- All 20 newly packaged asset manifests pass exact filename order, frame count, dimensions, binary alpha or designated opacity, safety inset, common baseline, and project-palette validation.
- Pixelorama `v1.2.1` reopens all 20 new `.pxo` sources with the expected dimensions and frame counts.
- Every animated asset has a contact sheet and timed GIF preview; scene-consuming assets also have native `320x180` scene contact sheets and previews.
- Native composite review confirms that all four characters remain identifiable and that hazard, recovery, and resource-change treatments remain composable layers rather than flattened scene replacements.
- The shared workflow was repaired for designated opaque backgrounds, dark neutral checker mattes, seed-baseline registration after resize, sparse overlay scale, five-frame dragon rows, and Phase 8 environment layouts.

## Recorded prototype debt

- ImageGen still commonly returns removable checker or dark mattes; deterministic cleanup remains part of the workflow.
- Generated intermediate poses retain minor cluster-level variation and are explicitly replaceable by production art.
- No app atlas, runtime mapping, accessibility string, unit test, or UI test was changed in this image-production run.
