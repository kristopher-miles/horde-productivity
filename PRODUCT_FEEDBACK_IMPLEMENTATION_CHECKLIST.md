# Product Feedback Implementation Checklist

Source of truth: [Product Feedback Requirements and Current-Product Gap Review](PRODUCT_FEEDBACK_REQUIREMENTS.md).

This checklist orders the work by dependency: apply the settled decisions, establish developer observability, evolve persisted contracts, build the model workflow, add user-facing flow, produce and integrate art, then complete cross-cutting verification. Each link names the requirement and points to its current source line. If the source document gains or loses lines, regenerate these line references before implementation begins.

## 0. Settled product decisions

These decisions have been resolved and are embedded in the requirements below.

- [x] 001 — [OD-01 — Use five total dungeon backgrounds (line 196)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L196)
- [x] 002 — [OD-02 — Start at Morale 5, Integrity 1, and Food 0 (line 197)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L197)
- [x] 003 — [OD-03 — Use non-regressing regular-use streaks for dragon growth (line 198)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L198)
- [x] 004 — [OD-04 — Use the closest 10 attempted goals for effort estimation (line 199)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L199)
- [x] 005 — [OD-05 — Allow optional effort override and model-selected varied consequences (line 200)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L200)
- [x] 006 — [OD-06 — Skip legacy migration and reset development data (line 201)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L201)
- [x] 007 — [OD-08 — Distinguish Cancel from story-advancing Fail (line 203)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L203)
- [x] 008 — [OD-07 — Retain 10 dev logs on every platform and expose every prompt (line 202)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L202)

## 1. Establish developer-mode infrastructure and observability

Build these first so every later model request and prompt can be inspected while the new workflow is developed.

- [x] 009 — [DV-01 — Add the dev-mode gate and navigation visibility rules (line 155)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L155)
- [x] 010 — [DV-02 — Centralize every model-facing prompt component in a registry (line 161)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L161)
- [x] 011 — [DV-04 — Retain the 10 most recent exact requests and responses on every platform (line 168)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L168)
- [x] 012 — [DV-03 — Add the all-platform editable and savable real-prompt window (line 162)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L162)
- [x] 013 — [DV-05 — Add the all-platform developer log browser (line 169)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L169)
- [x] 014 — [DV-06 — Add the Mac split modal and three clipboard controls (line 170)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L170)

## 2. Evolve persisted world, character, event, and history contracts

Land data contracts and reset behavior before UI or art depends on them.

- [x] 015 — [QA-01 — Persist all new resolution and visual-progression state (line 178)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L178)
- [x] 016 — [AP-01 — Initialize Morale 5, Integrity 1, and Food 0 (line 37)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L37)
- [x] 017 — [AP-02 — Keep only the Empty Cavern root location in the empty starting world (line 38)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L38)
- [x] 018 — [AP-03 — Store the exact young-dragon origin narrative (line 39)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L39)
- [x] 019 — [AP-04 — Define the starting lair as dirty, cold, empty, unruly, and dangerous (line 40)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L40)
- [x] 020 — [AP-05 — Remove the seeded harmless draft and padded threat default (line 41)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L41)
- [x] 021 — [AP-06 — Align the starting character record with a young Baby dragon (line 42)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L42)
- [x] 022 — [NPC-01 — Enforce zero kobolds on new and reset saves (line 138)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L138)
- [x] 023 — [NPC-02 — Add persisted Baby, Kid, and Adult kobold age state (line 139)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L139)
- [x] 024 — [VC-03 — Add durable Hoard-driven background progression independent of event cues (line 118)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L118)
- [x] 025 — [VC-08 — Store dragon age and room richness as independent axes (line 128)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L128)
- [x] 026 — [VC-09 — Persist non-regressing regular-use streak dragon growth (line 129)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L129)
- [x] 027 — [VC-07 — Persist curated or custom dragon color selection (line 127)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L127)
- [x] 028 — [RF-10 — Persist staged-resolution state and retain atomic final commit (line 104)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L104)
- [x] 029 — [QA-02 — Replace migration work with reliable development and test resets (line 179)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L179)

## 3. Replace the consequence engine with the staged model workflow

Build and validate the service pipeline before connecting screens to it.

- [x] 030 — [RF-01 — Select the closest 10 attempted goals and trim one at a time for context (line 80)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L80)
- [x] 031 — [RF-02 — Use optional user effort or model-estimated effort from 1–3 (line 81)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L81)
- [x] 032 — [TN-04 — Allow varied model-selected consequences across authorized attributes (line 65)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L65)
- [x] 033 — [VC-10 — Make Hoard one non-guaranteed model-selected world consequence (line 130)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L130)
- [x] 034 — [TN-01 — Replace gentle model instructions with mature epic-fantasy direction (line 62)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L62)
- [x] 035 — [TN-02 — Remove padded tone from schemas, fallbacks, validators, and corrections (line 63)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L63)
- [x] 036 — [TN-03 — Preserve security and structure without suppressing serious consequences (line 64)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L64)
- [x] 037 — [RF-03 — Generate a few-word suggested story action from effort (line 87)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L87)
- [x] 038 — [RF-06 — Parse custom actions faithfully with contextual safety fallback (line 95)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L95)
- [x] 039 — [RF-09 — Generate one 50–150 word paragraph from save, action, and prior prose (line 103)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L103)
- [x] 040 — [RF-11 — Support the staged pipeline for accomplished and failed goals (line 105)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L105)

## 4. Build the user-controlled resolution experience

Connect the staged services only after their persistence and request contracts are stable.

- [x] 041 — [RF-04 — Add suggestion acceptance and the custom-action branch (line 88)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L88)
- [x] 042 — [RF-05 — Add free-text custom action entry without committing state (line 94)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L94)
- [x] 043 — [RF-07 — Add the 3–5 word interpreted-action review screen (line 96)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L96)
- [x] 044 — [RF-08 — Require explicit action acceptance before final narration (line 102)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L102)
- [x] 045 — [RF-12 — Add distinct Cancel and story-advancing Fail actions (line 106)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L106)
- [x] 046 — [TN-06 — Make the accepted staged flow the only normal commit path (line 72)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L72)

## 5. Update first-run, Dungeon, Today, and authored copy

- [x] 047 — [AP-07 — Replace onboarding with the empty-cavern premise and curated/custom color choice (line 48)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L48)
- [x] 048 — [AP-08 — Add lone-dragon and empty-world presentation states (line 54)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L54)
- [x] 049 — [TN-05 — Remove padded tone from visible copy, fixtures, and accessibility text (line 71)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L71)

## 6. Produce character-free environment art

Complete the environment set before scene-wide character composition is finalized.

- [x] 050 — [VC-01 — Create five desolate-cave-to-golden-fortress backgrounds (line 116)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L116)
- [x] 051 — [VC-02 — Remove every living creature from every background (line 117)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L117)

## 7. Produce dragon and kobold progression assets

- [x] 052 — [VC-05 — Create five increasingly powerful dragon stages with idle animation (line 125)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L125)
- [x] 053 — [VC-06 — Ensure every dragon stage becomes more powerful, never decrepit (line 126)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L126)
- [x] 054 — [NPC-03 — Create idle-animated Baby, Kid, and Adult kobold models (line 145)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L145)
- [x] 055 — [NPC-04 — Make every kobold age model runtime-recolorable (line 146)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L146)

## 8. Integrate independent environment, dragon, and NPC rendering

- [x] 056 — [NPC-05 — Add data-driven NPC layers and placement (line 147)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L147)
- [x] 057 — [VC-04 — Render recorded environment progression consistently on every scene surface (line 119)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L119)

## 9. Complete automated and visual acceptance coverage

- [x] 058 — [QA-06 — Enforce prompt-registry completeness and exact log fidelity (line 188)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L188)
- [x] 059 — [QA-03 — Replace obsolete populated-home and gentle-story fixtures (line 185)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L185)
- [ ] 060 — [QA-04 — Cover overrides, 10-match context, Cancel/Fail, and staged resolution end to end (line 186)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L186)
- [ ] 061 — [QA-05 — Verify the complete room, dragon, recolor, and kobold visual matrix (line 187)](PRODUCT_FEEDBACK_REQUIREMENTS.md#L187)

## Completion rule

Implementation is complete only when all 53 requirement items (009–061) are checked, all settled decision items (001–008) remain reflected in the source requirements, and the source document’s definition of done is satisfied.
