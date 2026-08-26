# Phase 4 - Complete Product Experience

## Outcome

Turn the proven core loop into the complete production-intent MVP experience. This phase finishes every proposed iPhone surface, deep link, empty/loading/failure variant, local-data action, and visual/hardware interaction. At exit, a supported user can move from first launch through repeated goal/story cycles without developer fixtures or placeholder navigation.

Phase 4 is feature completion, not release hardening. Exhaustive model evaluation, long-run storage tests, final performance budgets, and submission readiness remain in Phase 5.

## Navigation and route model

- Root states are Compatibility, First Run, and Main App. Only one is active.
- Main App has three native tabs: Today, Dungeon, and Chronicle. Each retains its own `NavigationStack` path.
- Settings opens from the Today toolbar. It is a stable secondary surface, not a tab.
- Goal creation/editing and story resolution are sheets. Goal, resident, location, ability, active-thread, and Chronicle details push in their current tab's stack.
- Destructive confirmations use system confirmation dialogs or dedicated confirmation sheets when impact text needs more space.
- Notification/deep-link destinations are typed application routes containing stable occurrence/event IDs, not raw URLs interpreted by views.
- A route is resolved against current persistence state before navigation. Missing/stale targets fall back safely to Today with concise explanation.
- Temporary work never mutates tab ownership or creates a permanent fourth/fifth navigation item.

## SUR-001 - Compatibility and availability completion

Polish the Phase 1 gate into the shipping surface:

- Device ineligible: explain that the on-device story model is required and provide current supported-device requirements. Do not expose the tracker as a reduced substitute.
- Apple Intelligence disabled: explain the setting, offer Open Settings when the system permits, and provide Check Again.
- Model not ready: explain system-managed download/readiness without fabricated progress; suggest power/Wi-Fi only as guidance, not a guarantee.
- Unsupported locale: explain that the current app language cannot use the on-device model and provide a route to relevant system/app language settings where possible.
- Unknown unavailable: neutral explanation and retry.
- Recheck on foreground activation and manual action. Transition to onboarding/Today once, without recreating data.
- Provide complete VoiceOver state/action labels and test the longest localized placeholder strings at accessibility Dynamic Type sizes.

## SUR-002 - First run and initial world

Use no more than two explanatory screens plus an optional naming step:

1. Explain the value in one sentence: completing real goals changes a small local dungeon story. Show one authored static or gently animated scene and state that goal/story data stays on the iPhone.
2. Allow optional dragon and dungeon names, seeded with Ember and The Cinder Vault. Create the deterministic initial world from Phase 3 and continue to empty Today.

Requirements:

- No account, payment, cloud-sync, analytics, or notification request appears.
- Interrupted onboarding resumes at the correct step and does not duplicate the initial world.
- The world is created exactly once in an explicit transaction with onboarding completion.
- VoiceOver follows page order; scenes have concise descriptions; Reduce Motion uses static art/fades.
- A user reaches empty Today with no more than the specified screens.

## SUR-003 - Today production pass

Finish the Phase 2 Today surface using committed world state:

- Compact `WorldSummaryCard` includes authored scene, dungeon name, one active-thread headline, short readable status, and a distinct action to open Dungeon.
- Pending-resolution banner handles one or many unresolved events, identifies whether completions or expirations are waiting, and opens the next oldest event.
- Keep actionable goals above secondary world detail when both cannot fit above the fold.
- Maintain Overdue, Due Today, and Upcoming grouping; all-complete and empty states each have one clear next action.
- Loading uses stable placeholders; generation never blocks scrolling, editing, or switching tabs.
- Add Goal remains contextual and thumb reachable; it never becomes a tab item.
- Settings stays visually secondary to Add/Complete.
- Immediate completion feedback, haptic, locked row, and durable pending status remain visible while generation runs or after the user dismisses it.

## SUR-004/SUR-005 - Goal creation and management completion

- Preserve the Phase 2 title-first editor, limited recurrence/category/effort decisions, and immutable snapshots.
- Ensure keyboard, date/time, weekday selector, unsaved-change confirmation, archive, and delete interactions match native conventions.
- Add full history rows that route to the related immutable story result when present.
- Completed/expired/cancelled/archived states use text and symbols in addition to color.
- Destructive confirmations name whether they remove a future definition, pending occurrence, local story history, or the complete database; do not use one ambiguous "reset" action for everything.

## SUR-006/SUR-011 - Resolution and retry completion

Complete all result variants established in Phase 3:

- Generating, positive committed result, negative committed result, historical read-only.
- Model not ready, unsupported locale, guardrail refusal, invalid patch after correction budget, context overflow, revision conflict, interruption, and persistence failure.
- A terminal attempt ends the spinner and exposes Retry or Return to Today.
- Failure copy explicitly states: the goal completion/expiration is saved; no dungeon change was applied; retry remains available.
- Hide/dismiss never cancels the durable StoryEvent. Cancellation only stops the current in-memory inference.
- Revision conflict action rebuilds against current state; do not describe it as lost user data.
- No raw guardrail output, stack trace, prompt, token data, or model transcript appears to the user.
- One committed result has one dismissal action and optional drill-in to committed changes/Dungeon, not a cluster of reward actions.

## SUR-007 - Dungeon

Build the dedicated world tab as a readable state surface, not a second game system.

Required hierarchy:

1. Large authored scene driven by committed state.
2. Dungeon name and concise textual current-state summary.
3. Core stats: morale, integrity, and food with labels and values.
4. Current active thread/hazard with severity, summary, and drill-in.
5. Dragon and resident cards.
6. Abilities, relevant locations/conditions, and recent persistent facts through focused drill-in rather than one dense dashboard.

Required states:

- Normal, active hazard, recovery, no active thread, reduced motion, and missing optional entity.
- Entity detail gracefully omits absent optional fields.
- No raw JSON, schema terminology, writable flags, prompt context, or arbitrary model text masquerading as UI structure.
- Every meaningful scene condition has equivalent text; all drill-ins are reachable with VoiceOver.
- Scene updates only after committed save revision changes.

## SUR-008 - Chronicle

Build the third tab as an immutable local timeline:

- Entries are newest first, grouped by date, and visually identify completed versus expired source events.
- Each row includes generated title, short summary, source-goal snapshot, and compact patch-derived change summary.
- Detail shows authored scene, full validated narrative, source goal, committed changes, revision metadata, and timestamp.
- Search is local and covers source title, generated title, short summary, and narrative. It never becomes model prompt history.
- Filters are Completed, Expired, and date range. These fixed controls close the proposal's "when approved" ambiguity without a generic filter builder.
- Required states: empty, populated, long history, query result, no result, and reset/deleted data.
- History remains read-only. Editing goals, retrying unrelated events, or viewing details cannot rewrite entries.

## SUR-009 - Settings and local data

Use native grouped settings sections.

### Experience

- Notifications: current authorization state, explanatory status, and Open System Settings.
- Haptics: on by default; respect system accessibility and hardware behavior.
- Sound: optional, on by default only if the two restrained authored cues meet product review; always obey silent/device settings.
- Motion: System, Reduced, or Full, with System as default. System follows Reduce Motion.

### Model and privacy

- Current on-device model status and locale support.
- Plain disclosure that the core experience performs no app networking and uses the on-device system model.
- No claim that the phone or operating system performs zero networking; scope the statement to this app's build.
- No raw prompts or user goal text in diagnostic UI.

### Local data

- Export Local Data creates a versioned, human-inspectable JSON document containing goal definitions, occurrence/history snapshots, canonical world state, pending/resolved StoryEvents, Chronicle entries, and schema/prompt versions. It excludes transient model sessions and system notification internals. Present it through the system share sheet; the user chooses any destination.
- Reset Dungeon replaces world state with the deterministic initial world and removes story events/Chronicle entries after explicit confirmation. It preserves goal definitions and schedules. Pending story events must be resolved by policy: cancel them as part of reset and state that effect in confirmation.
- Delete All Local Data removes goals, occurrences, save, Chronicle, pending events, compact diagnostics, cached projections, and pending local notifications, then returns to the compatibility/first-run route. It is one confirmed local operation and is tested for relaunch.
- Export failure, reset failure, and delete failure retain current data and show a specific retryable message.

Approved About/Privacy links may be bundled. Accounts, sync, purchases, analytics, theme store, cloud model selection, and feedback upload are absent.

## SUR-010 - Notifications and exact deep links

- Notification payload identifies the relevant occurrence and, when already created, StoryEvent.
- Tapping a pending due notification opens Goal Detail; after foreground reconciliation creates an expired StoryEvent, route to the pending resolution state.
- Tapping a notification for an already resolved event opens immutable result detail.
- Archived/cancelled/deleted targets route to Today with a brief stale-notification explanation.
- Model unavailable keeps the user on the exact event with the correct availability action.
- Returning/back navigation is clear and never relies on remembering notification copy.
- Repeated taps and notification actions call the same idempotent application commands as in-app controls.
- Do not claim or attempt exact background model inference. Notification scheduling and story resolution stay separate.

## Visual and hardware production pass

### Pixel art

- Replace all temporary world assets with a coherent authored dragon/kobold/dungeon set.
- Use a single limited palette aligned to the dark world container and warm native shell.
- Supply normal, hazard, and recovery scene variants through state-driven layers rather than separate bespoke scenes for every story.
- Verify nearest-neighbor scaling at every supported display scale and orientation.
- Preload only the bounded current-scene atlas; avoid memory-heavy duplicate textures.
- Decorative pixels are hidden from accessibility; the container exposes one concise changing summary.

### Motion, haptics, and sound

- Completion: immediate light haptic.
- Positive commit: restrained success haptic plus at most one short cue.
- Negative commit: soft neutral/warning haptic, never alarm-like.
- Story reveal uses one validated authored animation, then settles to calm idle.
- Reduce Motion removes camera movement, parallax, particles, and large sprite transitions; information stays identical.
- System interruptions, silent mode, and app backgrounding stop or pause audiovisual work without affecting persistence.

### Native layout quality

- Preserve 44-point targets, safe areas, native tab/sheet behavior, Dynamic Type, and predictable back navigation.
- Test compact and largest supported iPhone classes, portrait baseline, landscape usability, light/dark appearance, and accessibility sizes.
- Keep generated narrative selectable and multiline. Never render it into art.
- Use skeletons sparingly and only while real persisted reads are pending.

## Required implementation sequence

1. Finalize typed route/deep-link resolution and independent tab navigation state.
2. Complete shipping compatibility and first-run flows with initial-world transaction.
3. Replace Today placeholder world content and finish all list/banner states.
4. Complete Goal Detail history links and destructive-flow copy.
5. Finish every Story Resolution success/failure/historical variant.
6. Build Dungeon hierarchy and entity/thread/location/ability details.
7. Build Chronicle timeline, detail, local search, and fixed filters.
8. Build Settings, JSON export/share, Reset Dungeon, Delete All Local Data, and notification cleanup.
9. Finish notification routing and every stale-target state.
10. Integrate production-intent pixel assets, state mapping, motion, haptics, and optional sounds.
11. Run cross-surface UI, accessibility, navigation, interruption, and local-data tests before Phase 5.

## Testable failure modes

| Failure mode | Test | Expected result |
| --- | --- | --- |
| Onboarding interrupted | Terminate at every step and relaunch | Resume safely; one initial save exists after completion. |
| Compatibility recovers | Enable Apple Intelligence or finish model download while app is backgrounded | Foreground recheck advances once without data recreation. |
| Multiple pending stories | Complete/expire several occurrences before resolution | Banner count/order is accurate; each opens one durable event; no batching occurs. |
| Generation dismissed | Leave the result sheet during inference | Other tabs remain usable; event remains pending or later displays its persisted result. |
| Failure spinner never ends | Force each terminal model/store error | Spinner stops; safe-state explanation and Retry/Today action appear. |
| Dungeon reads stale memory | Resolve event, background, terminate, relaunch | Scene and text reflect committed save revision, not cached pre-commit state. |
| Missing optional entity | Delete optional fixture entity before rendering a related card | UI omits/falls back safely; no crash or blank essential state. |
| Art/state mismatch | Exercise every committed state mapping and cue | Only existing authored assets are selected; text summary matches state. |
| Long Chronicle | Load maximum long-run fixture and search/filter it | Scrolling/search remain responsive, ordered, local, and read-only. |
| Search after reset | Reset story while search/results are active | Chronicle becomes the documented reset state and navigation exits stale detail safely. |
| Export with pending/failure data | Export representative maximum fixture | JSON is complete, versioned, parseable, and contains no transient transcript or remote identifier. |
| Export destination cancelled | Dismiss share sheet | No data changes and no false success state. |
| Reset fails midway | Inject store failure | Existing world/history remains intact; goals are not changed. |
| Delete/relaunch | Delete all data, inspect notification center, terminate, relaunch | Domain data and pending notifications are gone; first-run is shown after eligibility gate. |
| Stale deep link | Open resolved, archived, deleted, and unknown IDs | Correct committed detail or safe Today fallback; never duplicate event. |
| Notification privacy | Inspect delivered previews | Title-level copy only; no notes or dungeon secrets unless a future explicit opt-in exists. |
| Largest Dynamic Type | Exercise all 11 surfaces | Text reflows, primary actions stay reachable, and generated prose remains readable. |
| VoiceOver | Traverse each state and modal | Reading order follows hierarchy; separate actions are named; decorative sprites do not chatter. |
| Reduce Motion/system interruption | Toggle settings and interrupt every animation/sound | Information persists, animations simplify/stop, and no transaction behavior changes. |

## Exit criteria

- All eleven normative surfaces and their required states/actions are implemented.
- First run reaches empty Today in two explanatory screens plus optional naming, with no premature permission/account/payment request.
- Today remains task-first while showing committed world context and pending narrative clearly.
- Dungeon and Chronicle make durable state and history understandable without raw data, color dependence, or decorative art.
- Settings accurately reports local processing and model status and provides working export, distinct reset, and complete local deletion.
- Notifications route to exact current state, handle stale targets, and never imply background inference.
- Production-intent authored art is crisp, state-driven, bounded, accessible, and accompanied by restrained hardware feedback.
- Every loading, empty, success, negative, unavailable, retry, destructive, and historical state has a finite, tested user path.
- The product remains local-only, account-free, network-free in app code, and free of deferred commercial/social surfaces.

## Proposal coverage

This phase completes Sections 3.1-3.3, 4.1-4.4, 7.1-7.5, 8 and 8.1, and 9.1-9.4; SUR-001 through SUR-011; the UI portions of all NFR-PERF and NFR-A11Y requirements; NFR-PRIV-005; DEC-008 through DEC-010; and the reset/delete/deep-link portions of reliability requirements.

It resolves the apparent Settings-tab contradiction as a Today toolbar destination, makes Chronicle search/filters a simple local MVP feature, and defines export/reset/delete precisely. It keeps DEF-001, DEF-002, DEF-003, DEF-007, and DEF-009 out of the app rather than adding speculative controls. Phase 5 proves that the complete experience meets its quality and release bar.

## Implementation evidence — 22 August 2026

All eleven product surfaces have production-intent implementations with typed Today routes, exact notification routing, first run, local search/filtering, export, distinct reset/delete commands, settings, authored scene rendering, accessibility descriptions, and finite retry paths. Simulator lifecycle and UI flows pass.
