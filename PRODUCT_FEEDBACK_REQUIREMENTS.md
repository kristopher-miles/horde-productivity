# Product Feedback Requirements and Current-Product Gap Review

Status: requirements only; no product changes are authorized by this document.  
Review basis: current working-tree source and bundled runtime art reviewed on 2026-08-25.  
Organization: feedback type first, then target surface.  

## Purpose

This document turns the supplied feedback into a single traceable backlog. Every item states the requirement, the current-product gap, the work that must eventually be done, and observable acceptance criteria. “Current” describes the reviewed product; it does not mean the behavior should be preserved.

Status labels:

- **Conflicts** — current behavior directly opposes the requirement.
- **Absent** — the required behavior or surface does not exist.
- **Partial** — some supporting structure exists, but the requested behavior is not complete.

## Current-product comparison summary

The requested experience is not a tuning change to the current product. It requires replacing the initial world, changing the model workflow from one automatic generation/commit into several user-controlled stages, replacing the scene-art model, adding age and color progression, and adding developer-only prompt and request inspection.

| Area | Current product | Required direction |
|---|---|---|
| Starting world | Three kobolds, two furnished locations, one fact, one harmless threat, a warm home, and Morale/Integrity/Food at 50 (`TheHorde/Domain/WorldDomain.swift:54`) | A young dragon alone in the Empty Cavern with Morale 5, Integrity 1, Food 0, Hoard 0, and room to build a domain |
| Resolution | One model call invents prose and mutations; the result is committed before the user sees it (`TheHorde/Application/ResolutionCoordinator.swift:17`, `TheHorde/Features/StoryResolution/StoryResolutionView.swift:70`) | Optional user effort or model rating from the closest 10 attempts, suggested or user-authored action, explicit review/acceptance, then final prose and model-selected consequences |
| Tone | Prompts require “gentle,” “modest,” “small, recoverable” outcomes and forbid threats or permanent loss (`TheHorde/Infrastructure/FoundationModels/ModelContract.swift:8`) | Epic fantasy with meaningful agency and consequences; no preschool-style cushioning |
| Dungeon art | Three state/cue variants of the same furnished room; every image contains a dragon and three kobolds; the renderer adds another dragon sprite (`TheHorde/World/DungeonSceneView.swift:38`) | Five NPC-free environmental wealth stages, independently combined with five dragon stages and separately rendered NPCs |
| Dragon | One orange Ember model with idle and concern strips; no age or user-selected color | Baby, Adolescent, Adult, Elder, Great Wyrm; increasingly powerful; recolored from the chosen base color |
| Kobolds | Three pre-existing named residents are baked into every room image; no runtime kobold model | No starting kobolds; Baby, Kid, and Adult runtime models, each animated and recolorable |
| Developer tools | `DEBUG` fixtures exist, but no user-facing prompt editor or log; diagnostics use a no-op sink and are not persisted (`TheHorde/Infrastructure/FoundationModels/FoundationModelClient.swift:102`, `TheHorde/App/AppModel.swift:32`) | Dev mode on by default for now, editable/savable access to every model-facing instruction on all platforms, the 10 latest exact request/response logs, and a Mac split-view modal |

## Feedback type 1 — Aspirational progression and first-run world

### Target surface: world defaults, new saves, and dungeon reset

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| AP-01 | **Conflicts.** The three visible attributes start at 50. Progress must start from a deliberately low baseline. | Initialize Morale at **5**, Integrity at **1**, and Food at **0**. Use the same values for a new save and “Reset Dungeon.” | A clean first run and a reset both show Morale 5, Integrity 1, and Food 0; none silently fall back to 50; tests assert all three defaults and their available upward range. |
| AP-02 | **Conflicts.** The starting snapshot already has three residents, two furnished locations, a fact, and an active thread. | Retain exactly one root location representing the **Empty Cavern**, but start with no NPC residents, discovered secondary places, abilities, accumulated facts, or pre-existing active threads. | A clean first run contains the Empty Cavern root location and empty `residents`, `abilities`, `facts`, and `activeThreads`; no Mushroom Gallery or other developed sublocation exists; the UI handles each empty collection without placeholder inhabitants or lore. |
| AP-03 | **Conflicts.** The current rolling summary says Ember and three kobolds are making a calm home. | Use this exact starting narrative after substituting the chosen dragon name: “[name] has recently left the nest and searched for their own lair. After flying far from home, they arrived at an empty cavern extending deep into the rock. They are small now, but they will grow. They settle onto the cold stone, and plan for what's next.” | The first dungeon view and stored initial narrative contain the four sentences in that order, with only `[name]` substituted; no kobold, warmth, settled household, or existing accomplishment is added. |
| AP-04 | **Conflicts.** The root room is “Quiet” with warm lanterns and a broad hearth, and the second room has tidy mushroom beds. | Rewrite initial location data and all first-run presentation to make the cavern dirty, empty, unruly, cold, and dangerous. | Visible and model-supplied starting context consistently describes an untamed empty cavern; no initial copy describes it as tidy, calm, warm, comfortable, safe, or already cared for. |
| AP-05 | **Conflicts.** The starting active thread is a “harmless cold draft.” | Remove the seeded thread entirely. When threats later appear, permit them to be consequential and appropriate to an epic fantasy world. | No clean save contains “A Draft in the West Passage,” “harmless,” or an equivalent tutorial threat; later threat content is not automatically softened into harmlessness by a prompt or validator. |
| AP-06 | **Partial.** The dragon role says “Young dragon,” but its identity describes caring for an established home. | Make the starting character record explicitly young, small, newly independent, and not yet powerful or established. Align this identity with the Baby visual stage. | The starting character detail, accessibility copy, prompt context, and art all agree that the dragon is young/small and has just claimed an empty cavern. |

### Target surface: onboarding

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| AP-07 | **Conflicts.** Onboarding shows a warm furnished room with three kobolds and calls the destination a “little world.” | Replace first-run art and copy with the empty-cavern premise and the exact starting narrative. Keep dragon and dungeon naming, and add the color choice specified in VC-07. | Before entering the dungeon, the user sees no NPCs or furnished home and understands that the young dragon is beginning alone; the selected name appears in the narrative. |

### Target surface: Dungeon and Today summaries

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| AP-08 | **Conflicts.** Dungeon always titles the character section “Residents,” lists the dragon with the kobolds, and assumes places/facts already exist. Today shows the seeded thread. | Present the dragon independently, provide intentional empty states for population, discovered places, facts, abilities, and threats, and hide sections that have no useful content. | On a clean save, Dungeon and Today show the lone dragon and empty cavern without empty-list glitches, misleading “Residents” content, or an active-thread card. As the domain grows, new records appear normally. |

## Feedback type 2 — Mature epic-fantasy tone, agency, and consequences

### Target surface: model instructions, generated schemas, correction prompts, and validators

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| TN-01 | **Conflicts.** The main instructions require a “brief, gentle” consequence, slight benefits, and “small, recoverable setbacks” with no catastrophe, threats, or permanent loss. | Remove narrative cushioning from every model-facing instruction. Replace it with an adult epic-fantasy direction that respects the accepted action, established world, effort rating, and real consequences. | A repository-wide prompt inventory contains no instruction whose purpose is to make outcomes gentle, harmless, modest, calm, or automatically recoverable. Prompt tests demonstrate both meaningful success and meaningful failure. |
| TN-02 | **Conflicts.** Positive and negative generated schemas repeat “calm,” “modest,” and “small recoverable,” while fallback rewriting forces the same tone. | Rewrite generated-field guides, fallback prose, valence checks, mutation descriptions, error/correction language, and any other model-visible text that forces padded outcomes. | None of the system instructions, prompt templates, schema guides, tool descriptions, correction prompts, or fallback story text reintroduces the removed tone. Generated output may include danger, loss, conflict, and lasting consequences when supported by context. |
| TN-03 | **Partial.** Technical validation is currently mixed together with narrative infantilization. | Preserve necessary structural and security boundaries—plain output, valid schema, local persistence authority, prompt-injection isolation, context limits, and the custom-action fallback in RF-06—without using them to predetermine a harmless story. | Adversarial input cannot execute instructions or bypass the data contract, while valid adult fantasy outcomes are not rejected merely for containing danger, threats, loss, or serious consequences. |
| TN-04 | **Conflicts.** Negative mutation budgets and validation mechanically guarantee tiny setbacks (for example, scalar loss is capped at 2 and `catastrophicNegative` rejects larger consequences). | Revisit consequence/world-effect bounds so the model can choose meaningful consequences across the save’s many authorized attributes, informed by effort, accepted action, and world context. Hoard/wealth is only one possible attribute and must not be awarded by every success. Keep atomic validation, but do not encode “baby gates” as a universal severity ceiling. | Tests cover effort 1, 2, and 3 outcomes with varied model-selected effects; successes can affect different authorized attributes and do not automatically increase Hoard; failures can make the world worse; validation blocks malformed or unauthorized changes rather than all serious narrative stakes. |

### Target surface: user-visible copy, fixtures, and accessibility text

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| TN-05 | **Conflicts.** Onboarding says “gentle consequence”; the result says “Recoverable setback”; fixtures and accessibility copy repeatedly use calm, safe, small, and “without alarm.” | Audit and rewrite authored product copy, test fixtures, accessibility descriptions, empty states, and example stories that communicate a padded tone. Do not mechanically replace technical uses such as SwiftUI `safeAreaInset`. | User-facing strings and test scenarios support the same mature fantasy voice as production prompts. A string audit finds no remaining narrative use of “harmless,” “gentle consequence,” “small recoverable setback,” or equivalent cushioning. |
| TN-06 | **Conflicts.** The current model invents the consequence and commits it before the user can shape or approve it. | Make the user-facing action-selection and acceptance flow in RF-01 through RF-12 the only normal path to a committed story. | No model-created action, prose, or world effect is committed merely because a goal completes, expires, or is marked failed; the user has a meaningful choice and an explicit acceptance gate. |

## Feedback type 3 — Consequence interpretation and user-controlled story flow

### Target surface: historical context selection and effort rating

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| RF-01 | **Absent.** Current generation receives current goal metadata and world state but does not retrieve semantically similar attempted-goal history. | Compare the current goal’s text with all prior attempted goals, regardless of accomplishment or failure, and select the closest **10** by semantic similarity. Always use the closest available matches even when their similarity is weak. Send all 10 when they fit; if the request exceeds model context, remove exactly one least-similar goal at a time and retry the fit calculation until it fits. On a first-ever attempt, send the empty history collection; otherwise never substitute a “no match” result merely because similarity is low. | The effort request contains the 10 closest attempted goals whenever at least 10 exist and context permits, including each goal’s content and pass/failure outcome; it excludes the current, pending, and cancelled goals; context compaction removes one least-similar item per step rather than switching to an unrelated summary. |
| RF-02 | **Absent.** The optional user-entered Small/Medium/Large metadata is forwarded, but the model does not independently rate actual effort. | Store effort as integer **1, 2, or 3**. Goal creation may expose an optional user effort control. If the user supplies a value, use it and skip the effort-estimation model call entirely. If no value is supplied, run a dedicated effort-evaluation prompt using current goal text plus RF-01 history; routine attempts should be worth less and finally succeeding after similar failures should be worth more. | Every resolution has exactly one persisted effort rating in `1...3`; a supplied value maps directly to 1/2/3 and produces no effort-estimation log entry; an omitted value produces exactly one valid model rating; malformed ratings cannot advance the flow. |

### Target surface: suggested action screen

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| RF-03 | **Absent.** There is no separate action-suggestion call or review screen. | After effort evaluation, use a new prompt and the effort value to propose a concise story action for the dragon. Do not produce or commit final prose yet. | The request is distinguishable from the effort prompt, contains the rating, returns a few-word action (target 3–5 words), and opens a screen that displays the suggestion before any world change is applied. |
| RF-04 | **Absent.** The user cannot choose between the suggestion and their own action. | On the suggestion screen, provide an explicit accept/continue control and a separate button that opens free-text custom action entry. | Both paths are keyboard and accessibility operable; choosing neither and closing the flow commits nothing; choosing the custom path does not first accept the suggestion. |

### Target surface: custom action entry and interpretation

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| RF-05 | **Absent.** No free-text action entry exists. | Add a user-editable action field with a submit/interpret control. Preserve the entered text as user data for the parse request. | A user can enter and submit an action; the exact submitted text is available to the parser and developer request log; submitting does not commit story prose or world state. |
| RF-06 | **Absent.** No dedicated parser exists. | Use a different prompt to translate the user action into story context as faithfully as possible. If the text is completely out of context, inappropriate, or NSFW, ignore it and derive an appropriate action from the goal instead. User text remains delimited data, never model instructions. | Relevant input preserves its central intent; prompt-injection text cannot take control; disallowed/off-topic content does not appear in the interpreted action or prose and produces an action grounded in the goal. |
| RF-07 | **Absent.** There is no parsed-action review. | Show the parser result on a review screen equivalent to the suggestion screen, expressed as a 3–5 word action description. | The screen visibly contains only the interpreted 3–5 word action plus review controls; the user can accept it or return to revise without any world commit. |

### Target surface: acceptance gate, prose generation, and commit

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| RF-08 | **Absent.** Current generation begins automatically when the result sheet opens. | Require explicit acceptance of either the suggested action or the interpreted custom action before final narration begins. | UI automation proves that opening, closing, backing out, or editing before acceptance leaves the dungeon revision and Chronicle unchanged. One accepted action is persisted as the authoritative action for the event. |
| RF-09 | **Conflicts.** Current output is “two or three short sentences” capped by characters and is generated in the same call that chooses mutations. | Add a new final-prose prompt that receives: current save context, the accepted action, and the prose paragraph from the most recent prior success or failure. Generate exactly one paragraph of 50–150 words describing what happened. | The logged final request contains all three inputs (using an explicit “none” value when no prior result exists); output is one paragraph, 50–150 words, follows the accepted action, and does not include headings, bullets, or extra paragraphs. |
| RF-10 | **Partial.** Goal events are durably saved before generation and commits are atomic, which should be retained; however, no intermediate flow state exists. | Persist enough resolution state to keep the effort value, selected historical references, suggested/interpreted action, accepted action, prompt versions, and final result associated with the event. Commit final prose and authorized world changes atomically only after acceptance and validation. | Retrying or reopening an unresolved event does not create a duplicate Chronicle entry; a successful commit advances the world revision once; a failed generation leaves the prior world unchanged and the event retryable. |
| RF-11 | **Partial.** Completed and expired goals both produce events, but both currently enter the same automatic consequence call. | Run the staged flow for accomplished, expired, and explicitly failed goals, with outcome status supplied to every prompt that needs it. | End-to-end tests complete one goal, expire one goal, and explicitly fail one goal; all three allow suggested and custom-action paths, and each final story reflects its actual outcome rather than reversing success/failure. |
| RF-12 | **Absent.** The user cannot explicitly distinguish abandoning a pending goal from declaring that the goal failed. | When cancelling a pending goal, present two distinct actions: **Cancel** and **Fail**. Cancel removes/stops the goal without counting as an attempt and without opening story resolution. Fail records a failed attempt and opens the same staged story flow used for other story-advancing outcomes, with failure valence so the world can get worse. | Cancel creates no attempted-goal history item, story event, model request, or world change. Fail creates one failed attempt, appears in future effort-history candidates, opens the staged resolution flow, and can commit a negative consequence only after action acceptance. |

## Feedback type 4 — Visual progression and environment art

The settled count is **five total background stages**, with the empty cave as stage 1 and four increasingly rich stages after it.

### Target surface: dungeon background assets

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| VC-01 | **Conflicts.** The product has three normal/hazard/recovery variants of one already-furnished room, not wealth/progression levels. | Create five distinct environmental progression backgrounds. Stage 1 is a generic, unlit, desolate, sad cave with webs and no signs of settlement. Stages 2–5 become progressively more settled, rich, warm, and imposing. | A five-image contact sheet reads in an unambiguous poorest-to-richest order without labels; stage 1 is cold/empty and stage 5 is a vast underground fortress filled with hoarded gold and gemstones. |
| VC-02 | **Conflicts.** Every bundled background contains a dragon and three kobolds. | Remove all dragons, kobolds, people, animals, monsters, and other living creatures from every environment background. Treat characters as independent runtime layers. | Pixel-level visual QA of all five full backgrounds shows no living creature or baked-in character silhouette. Hiding character layers leaves a valid empty environment at every stage. |
| VC-03 | **Absent.** Background selection currently follows temporary animation cues and a simple stat threshold. | Add a durable background progression value and select the environment from it, independently of momentary success/failure animation cues and independently of dragon age. | Each of five background stages can be displayed with each dragon stage in a test fixture; changing a cue does not permanently change wealth stage; advancing dragon age alone does not advance the room. |
| VC-04 | **Partial.** Current scene art is shown in onboarding, Today, Dungeon, resolution, and Chronicle, but those surfaces do not share a five-stage contract. | Update every scene consumer to render the selected environment stage consistently while allowing event-specific animation overlays. | Given the same saved background stage, all live world surfaces show that stage; Chronicle uses the stage recorded for that event rather than constructing a fresh default world. |

### Target surface: dragon assets, character state, and onboarding color

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| VC-05 | **Absent.** Only one small orange dragon model exists. | Create five visually distinct dragon stages named Baby, Adolescent, Adult, Elder, and Great Wyrm. Provide at least one idle animation for every stage; event-specific behavior may use lightweight runtime effects until separately authored animation requirements are added. | A contact sheet and runtime fixture show exactly five ordered animated stages. Silhouette, scale, and presence increase at each step; labels use “Great Wyrm”; every stage’s idle loop plays with consistent pixel filtering and anchoring. |
| VC-06 | **Absent.** No age-progression art direction exists. | Make every later stage more powerful and formidable. Elder and Great Wyrm must not appear frail, decrepit, diminished, or comedic. | Blind visual review orders the stages by growing power; Elder and Great Wyrm read as the most powerful two stages, with Great Wyrm strongest. |
| VC-07 | **Absent.** Dragon color is fixed in authored orange pixels. | During dragon creation, offer a curated palette of art-directed base colors plus an unrestricted color-picker option. Persist the chosen color and shade/recolor every stage and animation from recolorable source art. | Curated choices produce approved readable palettes; an arbitrary picker color is also accepted; the selected color survives relaunch, appears consistently across every dragon stage/frame/surface, preserves highlights and shadows, and does not recolor eyes, outline, or unrelated scene pixels. |
| VC-08 | **Absent.** Dragon age and room richness are not separate progression axes. | Store and render dragon stage separately from background stage. | Tests cover at least Baby + richest room and Great Wyrm + emptiest room, proving neither value derives from or overwrites the other. |
| VC-09 | **Absent.** Dragon age has no regular-usage growth rule. | Define a regular-use day as a local calendar day in which at least one goal is accomplished. Baby is the starting stage. Advance to Adolescent after **7** consecutive regular-use days, Adult after **14**, Elder after **30**, and Great Wyrm after **60**. Once a stage is earned, the dragon never becomes younger. Missing a regular-use day resets only the in-progress streak toward the next unearned stage. | Tests cover every threshold, multiple completions on one day counting as one regular-use day, a missed day resetting current-stage progress, relaunch/time-zone handling, and permanent retention of the highest earned dragon stage. |
| VC-10 | **Absent.** There is no model-driven wealth progression among a broader set of world attributes. | Add Hoard/wealth as an authorized mutable attribute starting at **0**, among many possible save attributes. The model chooses story consequences from the available save context and writable contract; a success may increase Hoard, affect another attribute, or do something else appropriate. Background stages 2–5 unlock at committed Hoard values **10, 30, 60, and 100**. Background richness must not derive from goal count, effort points, or automatic success rewards. | Diverse successful goals produce varied authorized effects; no rule automatically grants Hoard for success; an explicitly wealth-seeking accepted action can plausibly increase it; background stages change only when committed Hoard crosses 10, 30, 60, or 100. |

## Feedback type 5 — Kobold NPC lifecycle and reusable sprites

### Target surface: NPC state and population rules

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| NPC-01 | **Conflicts.** Pip, Moss, and Rill exist at first run. | Begin with zero kobolds. Add kobolds only through later gameplay/story events, not by background choice or onboarding. | New and reset saves contain no kobold records; no NPC appears visually or in prose/context until a gameplay event has created that NPC. |
| NPC-02 | **Absent.** Character state has no kobold age. | Represent each kobold’s age stage as Baby, Kid, or Adult and make it available to rendering and story context. | Persisted NPC data round-trips all three values; the correct age is included in model save context and selects the correct sprite. |

### Target surface: kobold pixel art and animation

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| NPC-03 | **Absent.** There are no runtime kobold sprite assets; the only kobolds are baked into room images. | Create one reusable pixel model for Baby, one for Kid, and one for Adult, plus one idle-loop animation for each age. | Three source models and three idle animation deliverables pass sprite QA for consistent canvas, anchor, scale, transparent background, pixel filtering, and loop/playback. Each can render independently over all five rooms. |
| NPC-04 | **Absent.** Baked-in kobolds cannot be individualized. | Design the three models with palette separation/masks so the runtime can recolor them into distinct NPC appearances without redrawing the animation. | At least three visibly distinct recolors of each age render from the same underlying frames with unchanged silhouettes, anchors, transparency, and animation timing. |
| NPC-05 | **Absent.** The scene renderer only adds Ember; it has no NPC layer or placement contract. | Render NPCs as data-driven, separately positioned character layers and keep them out of all environment art. | Adding/removing one NPC updates only that character layer; backgrounds remain unchanged; multiple recolored ages can coexist without overlap or clipping in supported layouts. |

## Feedback type 6 — Developer-mode prompt editor and exact model logs

### Target surface: dev-mode configuration and navigation

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| DV-01 | **Partial.** Compile-time `DEBUG` behavior exists, but there is no explicit product dev mode or developer UI. | Add a single dev-mode gate that is enabled by default for the current development phase and can later default to off without removing the tools. Hide all prompt/log entry points when off. | Current development builds open with dev mode enabled; toggling/configuring it off removes prompt and log surfaces from navigation and prevents casual access; production-default behavior can later be changed in one defined place. |

### Target surface: prompt inventory, editor, and persistence

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| DV-02 | **Absent.** Prompt-bearing text is scattered across model instructions, output guides, a tool description, projection formatting, valence rules, and a dynamically appended correction. | Create a complete registry for every model-facing prompt component: effort evaluation, action suggestion, custom-action interpretation, final prose, system instructions, output/schema guides, tool instructions, retry/correction text, and shared context templates. | A test enumerates every model request stage and verifies all of its editable prompt components have stable IDs and appear in the dev editor; no production request uses an unregistered prompt-bearing literal. |
| DV-03 | **Absent.** Prompts cannot be viewed, edited, or saved. | Add a dev-only prompt window on all supported platforms that shows and edits the real effective text for every registered model-facing component, including system instructions, stage templates, output/schema guides, tool descriptions, shared context templates, and retry/correction instructions. Save overrides locally, and make subsequent requests use them. | Edit any registered component, save it, relaunch, and confirm both the editor and next exact request use the override; editing one component does not change another; unsaved changes do not affect requests; there is no hidden model-facing instruction outside the editor’s inventory. |

### Target surface: request/response log list and Mac detail modal

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| DV-04 | **Absent.** `ModelGenerationDiagnostics` can encode a transcript, but the configured diagnostics sink discards it and no exact request/response record is stored or shown. | In dev mode on every supported platform, log every model attempt and stage with its exact full request text and exact full response text, including retries/corrections and structured/tool-call material needed to reproduce what the app received. Retain only the **10 most recent entries**, deleting the oldest entry when an eleventh is stored. Do not truncate, summarize, rewrite, or substitute the post-processed story for the raw response. | For effort, suggestion, parser, and prose calls, the log text byte-for-byte matches what was sent and received; retries are separate entries; failed calls retain the request plus available raw response/error; each platform retains exactly the newest 10 entries; dev mode off does not expose logs. |
| DV-05 | **Absent.** No log browser exists. | Add a dev-only log screen on every supported platform with enough metadata to identify time, event/goal, stage, attempt, and success/failure, while keeping the exact text available. | A developer can locate all retained calls for one resolution and distinguish the four prompt stages and any retry without opening source code or an exported file. |
| DV-06 | **Absent.** No Mac inspection modal exists. | On Mac, clicking a log entry must open a large modal with the full request on one half and the full response on the other half. Provide **Copy Request**, **Copy Response**, and **Copy Both** controls above the content. | The modal is large enough for side-by-side reading, both halves scroll and allow text selection, no content is elided, and each copy control places exactly the promised complete content on the macOS clipboard. |

## Feedback type 7 — Cross-cutting persistence, history, and verification

### Target surface: data model and history

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| QA-01 | **Partial.** Current Chronicle persists final narration and outcome but not accepted actions, model-rated effort, chosen comparison history, visual progression stages, or dragon/NPC palette state. | Extend persisted save/event/history data to preserve all new authoritative choices and the visual state needed to replay a result faithfully. | Export/relaunch round-trip preserves effort, accepted action, final prose, dragon stage/color, background stage, NPC age/colors, and event-time scene state; Chronicle does not substitute `.initial()` for recorded state. |
| QA-02 | **Partial.** Existing local test saves and fixtures embody the obsolete populated world. There are no external users whose saves require preservation. | Do not build legacy-save migration for this change. Provide a reliable developer/test reset path and recreate fixtures from the new schema and empty-world defaults. Schema changes may require manually resetting local development data. | Clean install, automated reset, and documented manual test reset all produce the new schema and defaults; tests do not require loading or preserving pre-change saves. |

### Target surface: automated and visual acceptance coverage

| ID | Requirement and current gap | What must be done | Acceptance criteria |
|---|---|---|---|
| QA-03 | **Conflicts.** Existing fixtures and tests assert the old 50/50/50 populated home and gentle consequence model. | Replace obsolete assertions and fixtures with the new empty start, staged flow, mature tone, and independent visual progression contract. | Tests fail if a starting NPC/fact/thread returns, if any attribute returns to 50, if story generation bypasses acceptance, or if prohibited cushioning returns to prompts. |
| QA-04 | **Absent.** There is no end-to-end staged-resolution coverage. | Add deterministic tests for optional user effort bypass, first history-free effort rating, 10 closest mixed-outcome attempts, one-at-a-time context trimming, routine success, success after similar failure, suggestion acceptance, faithful custom interpretation, disallowed custom fallback, Cancel versus Fail, final word/paragraph bounds, retries, and all story-advancing outcomes. | Every path reaches either one atomic accepted commit or a retryable unchanged state; Cancel creates neither attempt nor story; Fail enters the negative flow; exact request fixtures prove the intended context was sent at each stage. |
| QA-05 | **Absent.** Existing art QA covers three cue variants rather than independent progression axes. | Add source and runtime visual QA for five rooms × five dragon stages, dragon recolors, three kobold ages/animations/recolors, and zero-character backgrounds. | Contact sheets and runtime fixtures prove all required combinations, nearest-neighbor pixel rendering, consistent anchors, no baked-in living creatures, and no unintended coupling between progression axes. |
| QA-06 | **Absent.** No automated completeness check protects “every single prompt.” | Add a prompt-registry completeness test and a dev-log fidelity test. | Introducing a new model call or prompt component without editor registration and exact logging fails the test suite. |

## Resolved product decisions

These decisions are part of the implementation specification and do not require reference to prior feedback or conversation.

| ID | Settled decision |
|---|---|
| OD-01 | There are five total dungeon backgrounds: the desolate empty cave plus four increasingly rich stages. |
| OD-02 | Starting attributes are Morale 5, Integrity 1, and Food 0. |
| OD-03 | Dragon growth comes from regular usage, where a regular-use day has at least one accomplished goal. Baby is the start; 7-day, 14-day, 30-day, and 60-day streaks unlock Adolescent, Adult, Elder, and Great Wyrm. Missing a day resets progress toward the next stage but never lowers an earned stage. Room richness is independent: Hoard starts at 0, and values 10, 30, 60, and 100 unlock background stages 2–5. |
| OD-04 | Effort estimation uses the closest 10 prior attempted goals regardless of pass/failure or weak similarity. Include content and outcome, exclude pending/cancelled/current goals, and drop one least-similar item at a time only when required to fit model context. |
| OD-05 | A user-supplied optional 1–3 effort value bypasses model estimation. Otherwise the model estimates effort. The model chooses consequences across many authorized save attributes; success does not automatically increase Hoard. |
| OD-06 | There are no external user saves to migrate. Development/test data may be manually reset, and fixtures must be recreated against the new schema. |
| OD-07 | Dev mode retains the 10 most recent exact request/response entries on every supported platform. The full prompt inventory is visible/editable in dev mode. Mac additionally provides the required side-by-side modal with Copy Request, Copy Response, and Copy Both. |
| OD-08 | Cancel and Fail are separate actions. Cancel is not an attempt and produces no story. Fail records a failed attempt and opens the same staged story flow with negative consequences. |

## Feedback-to-requirement traceability

| Feedback theme | Requirement IDs |
|---|---|
| Low starting point and aspirational growth | AP-01–AP-08, VC-01, VC-03, VC-05, VC-08–VC-10 |
| Young dragon and exact origin narrative | AP-03, AP-06, AP-07 |
| Empty, dirty, dangerous starting cavern and no NPCs | AP-02, AP-04, AP-05, AP-08, VC-01, VC-02, NPC-01 |
| Remove padded/child-safe tone and allow consequences | TN-01–TN-06 |
| Ten closest attempted goals and effort 1–3, with optional override | RF-01, RF-02, OD-04, OD-05 |
| Suggested action and user-authored alternative | RF-03–RF-08 |
| Custom-action contextual parser and inappropriate-input fallback | RF-05–RF-07, TN-03 |
| Final 50–150 word paragraph with save/action/previous prose | RF-09–RF-11 |
| Explicit Cancel versus story-advancing Fail | RF-12, OD-08 |
| Five dungeon stages with gold/warmth progression and no creatures | VC-01–VC-04, OD-01 |
| Five increasingly powerful dragon stages, usage streaks, and curated/custom color | VC-05–VC-09 |
| Model-selected Hoard progression among many attributes | TN-04, VC-10, OD-05 |
| Kobold Baby/Kid/Adult models, animations, and recolors | NPC-01–NPC-05 |
| Dev mode on now, off later; every prompt editable/savable | DV-01–DV-03, QA-06 |
| Exact request/response logs and Mac split modal with copy | DV-04–DV-06, QA-06 |

## Definition of done for this feedback set

This feedback set is complete only when:

1. Every requirement ID above has implementation evidence and passing acceptance evidence.
2. All resolved OD decisions are implemented exactly as recorded above.
3. A clean install visibly begins with the young dragon alone in the desolate cavern and the exact origin narrative.
4. A completed or failed goal cannot change the story/world until the user accepts a suggested or interpreted action.
5. The final prose is one 50–150 word paragraph generated from the required three context inputs.
6. Five independent room stages, five independently earned dragon stages, curated-plus-custom dragon color, and three recolorable animated kobold ages pass runtime visual QA.
7. Dragon growth follows regular-use streaks without age regression, while room richness follows model-selected Hoard consequences rather than automatic goal rewards.
8. Dev mode exposes and saves every model-facing prompt component and retains the 10 most recent exact complete request/response pairs on every platform; disabling dev mode hides those surfaces.
9. The mature epic-fantasy voice is consistent across prompts, validators, fallbacks, fixtures, accessibility text, and visible UI.
