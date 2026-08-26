# Phase 7 - Sprite Prototype Workflow and Skill Handoff

Implementation status: complete on 2026-08-24. The frozen workflow is recorded in [PrototypeArt/workflow-decision.md](PrototypeArt/workflow-decision.md), the reusable skill lives at [.agents/skills/horde-sprite-prototype/SKILL.md](.agents/skills/horde-sprite-prototype/SKILL.md), and final evidence is in [PrototypeArt/phase7-exit-audit.md](PrototypeArt/phase7-exit-audit.md).

## Outcome

Prove one repeatable path from visual direction to a native-resolution SpriteKit animation, then capture that proven path in a repository-scoped Codex skill before producing the rest of the prototype assets in [Phase 8](08-sprite-prototype-asset-plan.md).

This phase plans the skill but does not create it. Skill creation is the first production step after the plumbing exit gate. Do not encode an unproven workflow into a skill.

## Constraints

- The shipped app performs no runtime image generation, asset downloading, or application networking.
- Source art is authored and stored locally. Generated images are development inputs only.
- The scene remains `320x180`, uses integer placement, and sets `SKTexture.filteringMode = .nearest`.
- Important text never appears inside raster art.
- Reduce Motion presents an equivalent static state.
- Use native SpriteKit/Xcode asset loading. Add no application dependency for art playback.
- Prototype files must be visibly marked as replaceable and retain their generation/editor provenance.

## Minimal toolchain

| Role | Default | Fallback trigger |
| --- | --- | --- |
| Visual generation and editing | Codex `imagegen` using OpenAI's `sprite-pipeline` workflow | Try local ComfyUI only if cloud use, iteration latency, or repeatability is unacceptable after the pilot |
| Pixel editor and editable source | Pixelorama stable macOS release | Consider Aseprite only if Pixelorama cannot perform a required export or editing operation |
| Deterministic normalization | OpenAI sprite-pipeline scripts, adjusted only where the app contract requires it | Add one small project script only for a missing, demonstrated operation |
| Motion preview | Pixelorama preview plus generated contact sheet/GIF; `ffmpeg` is already available locally | None |
| Runtime | SpriteKit `SKTextureAtlas` and `SKAction.animate` | None |

Do not configure ComfyUI, compile Aseprite, or build a custom editor integration during the default path. Those are contingency costs, not prerequisites.

## Candidate asset contract

The plumbing spike must validate or revise this contract before the skill is written.

| Property | Candidate value |
| --- | --- |
| Scene canvas | `320x180` opaque background plus transparent layers |
| Dragon frame canvas | `96x80`, bottom-center anchor |
| Kobold frame canvas | `48x64`, bottom-center anchor |
| Palette | One project palette, target maximum 32 visible colors plus transparency |
| Pixel treatment | Hard clusters, no resampling blur, no fractional placement |
| Source format | Pixelorama `.pxo` plus exported PNG frames |
| Runtime format | PNG frames in a bounded Xcode/SpriteKit atlas |
| Naming | `<asset>-<cue>-<two-digit-frame>.png` |
| Metadata | One checked-in JSON manifest with frame order, duration, loop behavior, anchor, source, and generation notes |
| QA media | Contact sheet and looping preview for each animated asset |

The manifest is development/build metadata. Runtime code should use application-owned cue and atlas identifiers rather than parsing a general asset system.

## Plumbing and infrastructure plan

### P0 - Freeze the pilot brief

Use Ember's idle loop as the pilot because it exercises character identity, transparency, animation continuity, anchoring, scale, palette cleanup, and SpriteKit playback without needing a dramatic action.

Before generating anything:

1. Save the current `DungeonNormal` image as composition and palette reference only.
2. Write the pilot specification: `96x80`, four idle frames, bottom-center anchor, transparent background, subtle breathing/blink motion, fixed facing direction, and no detached effects.
3. Select an initial project palette from the current dark-violet stone, ember orange, teal, moss green, warm cream, and outline colors.
4. Record the expected in-scene size and placement so art is judged at gameplay scale rather than zoomed-in editor scale.

Gate: another contributor can read the brief and identify exactly what is being generated and how it will be judged.

### P1 - Validate the editor round trip

Install Pixelorama locally and test the smallest complete round trip:

1. Create a four-frame transparent test animation at the candidate dragon canvas size.
2. Verify onion skinning, per-frame timing, tagged animation playback, palette editing, and nearest-neighbor display.
3. Save the editable `.pxo` source.
4. Export individual PNG frames, a horizontal spritesheet, and a GIF/APNG preview through both the UI and CLI.
5. Reopen the exported spritesheet and confirm slot order, alpha, dimensions, and colors.

Gate: Pixelorama can preserve the source contract and automate exports. If one required operation fails, document the exact failure before evaluating Aseprite.

### P2 - Validate Codex strip generation

Install the OpenAI `sprite-pipeline` skill and use Codex `imagegen` for the pilot:

1. Produce or approve one canonical Ember seed frame.
2. Place it in the pipeline's larger transparent edit canvas.
3. Generate all four idle poses in one strip. Do not generate frames independently.
4. Normalize the strip with one shared scale and bottom-center anchor.
5. Lock the first frame back to the approved seed if the generated first frame drifted.
6. Produce a contact sheet and loop preview.
7. Repeat the strip once with one targeted prompt correction to test whether repairs are controllable.

Record prompt, selected output, rejected outputs, generation attempts, elapsed hands-on time, and the reason for every manual repair.

Gate: one strip preserves Ember's silhouette, palette family, face, proportions, and anchor well enough that cleanup is cheaper than redrawing the animation.

### P3 - Validate deterministic cleanup

Use the pipeline scripts and Pixelorama to establish the boundary between automation and art judgment:

1. Extract exactly four equal frames.
2. Preserve transparent pixels and reject colored background remnants.
3. Apply one shared scale and bottom-center anchor across the strip.
4. Reduce to the candidate project palette without introducing transparency holes or unreadable features.
5. Confirm every output matches the frame canvas exactly.
6. Inspect at 1x and in a `320x180` contact scene, not only at editor zoom.
7. Make necessary pixel edits in Pixelorama and re-export from the editable source.

Do not automate subjective redrawing. Automation owns geometry, alpha, palette conformance, naming, assembly, and reports; a human owns silhouette, expression, timing, and appeal.

Gate: the same command sequence can reproduce the cleaned frames from saved inputs without undocumented hand assembly.

### P4 - Validate SpriteKit integration

Replace one development-only scene element with the pilot animation:

1. Put the four PNG frames in one bounded SpriteKit atlas.
2. Load frames in manifest order and set every texture to nearest filtering.
3. Play the idle loop with authored per-frame durations.
4. Confirm integer placement and stable bottom-center registration at every supported scene scale.
5. Confirm app backgrounding stops or pauses animation safely.
6. Confirm Reduce Motion displays the approved representative frame.
7. Confirm the existing accessibility description remains the meaningful equivalent of the visual.
8. Run the current build and relevant scene/UI tests.

Gate: the pilot looks crisp and stable in the Dungeon, Today summary, story reveal, and Chronicle snapshot contexts without changing persistence or cue authorization.

### P5 - Choose and freeze the workflow

Review the pilot evidence and make explicit decisions:

- Is Codex generation fast and consistent enough to remain the default?
- Which steps require Pixelorama judgment?
- Are the candidate palette, cell sizes, anchor, and naming rules correct?
- Is a local ComfyUI branch justified by a measured problem?
- Is Aseprite justified by a specific Pixelorama limitation?
- Which generated files are retained, and which are disposable intermediates?

Repeat one second animation strip, preferably Ember `concern`, using only the written workflow. Repair missing instructions rather than relying on memory.

Plumbing exits only when both pilot strips can be reproduced, previewed, and loaded in-engine; their remaining defects are aesthetic rather than structural.

## First production step - Create the Horde skill

After the plumbing exit gate, invoke Codex's `skill-creator` to create `.agents/skills/horde-sprite-prototype/`. Do this before the first asset batch.

The skill should contain only the proven workflow:

```text
.agents/skills/horde-sprite-prototype/
  SKILL.md
  references/
    asset-contract.md
    cue-language.md
    palette.png
  assets/
    strip-layouts/
  scripts/
    normalize-and-validate
    render-qa
```

Required skill behavior:

- Accept one asset brief and the canonical references for that asset.
- Generate a complete row per animation rather than independent frames.
- Preserve one approved identity seed.
- Normalize with the proven shared scale and anchor.
- Export editable-source expectations, PNG frames, atlas inputs, manifest entry, contact sheet, and loop preview.
- Validate frame count, dimensions, alpha, palette, filename order, non-empty bounds, and unused transparent cells.
- Require visual review for identity, silhouette, expression, timing, loop quality, and gameplay-scale readability.
- Save provenance and measured effort for staffing estimates.
- Never install an asset into the app until deterministic and visual gates pass.

Keep the skill repository-scoped. Do not package a plugin, add provider abstractions, or support other games during this phase.

Skill acceptance test: run Ember `celebrate` from a fresh Codex task using only the asset brief and the new skill. If undocumented parent-thread knowledge is required, repair the skill before continuing.

## Evidence log template

Record one row for each generated or edited animation:

| Asset/cue | Provider | Attempts | Generation minutes | Editor minutes | Integration minutes | Rejected because | Approved by | Replace for production? |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- |

Staffing estimates should use approved-output time, including rejected attempts and cleanup. Raw generation time alone is not an art-production estimate.

## Phase exit criteria

- Pixelorama passes the source/edit/export round trip or a documented replacement is selected.
- Ember `idle` and `concern` pass deterministic QA, visual QA, loop preview, and SpriteKit integration.
- The palette, cell sizes, anchors, naming, manifest, and retention rules are frozen for the prototype batch.
- Reduce Motion, accessibility equivalence, interruption behavior, and nearest-neighbor rendering are verified.
- The repo-scoped Horde skill is created from the proven workflow and passes Ember `celebrate` from a fresh task.
- Optional ComfyUI or Aseprite work exists only when a recorded default-path failure justifies it.
- The asset batch can begin using [Phase 8](08-sprite-prototype-asset-plan.md).
