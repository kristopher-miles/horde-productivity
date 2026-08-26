# Phase 2 - Local Productivity Core

## Outcome

Deliver a useful offline goal tracker before introducing story generation. A user can create, edit, schedule, complete, expire, archive, delete, and inspect goals from Today and Goal Detail. Local notifications and foreground deadline reconciliation work. Every completion or expiration creates at most one durable pending story event, but the phase uses no model and applies no world mutation.

The app at this checkpoint is intentionally a complete productivity substrate with a visible "story pending" seam. This separates goal correctness from generative behavior.

## MVP scheduling decisions

The production proposal left recurrence presets, effort inputs, batching, and undo unresolved. Use these fixed MVP policies:

- A title is the only required field. Preserve title and notes exactly as entered, including capitalization, emoji, spacing inside the value, and unusual but valid text.
- Optional date and optional time are distinct. A dated goal without a time expires at the end of that local calendar day. A timed goal expires after its exact due instant.
- Recurrence supports Never, Daily, and Selected Weekdays. This covers the proposal's one-time, daily, and weekday examples without a general recurrence engine.
- Recurrence uses the user's current calendar and time zone to calculate future wall-clock occurrences. Time-zone changes do not rewrite historical source snapshots.
- Optional effort is Small, Medium, or Large. Optional category is one of Personal, Work, Study, Health, or Home. These values are prompt context and visual metadata, not a scoring system.
- One expired occurrence creates one negative story event. Do not batch expired occurrences in the MVP; this removes an unresolved policy and preserves "one action, one consequence."
- There is no completion undo in the MVP. The proposal marks it optional, and omitting it avoids a race between undo and story resolution.
- Editing a recurring definition affects future occurrences only. Historical occurrence and story-event snapshots never change.
- Archiving stops future occurrences but preserves history. Deleting a definition requires confirmation and removes its pending future occurrences; committed historical chronicle data remains until Reset Story or Delete All Local Data in Phase 4.

## Domain model

### GoalDefinition

Owns reusable user intent:

- Stable identifier.
- Exact title and optional notes.
- Optional category and effort.
- Schedule rule: no recurrence, daily, or selected weekdays.
- Optional local due time.
- Created/updated timestamps and archived state.
- A version used when creating occurrence source snapshots.

### GoalOccurrence

Represents one actionable instance:

- Stable identifier derived or generated once for the scheduled instance.
- Definition identifier and immutable source snapshot containing title, notes, category, effort, and schedule context as they existed when materialized.
- Due instant or all-day due date in the relevant calendar/time zone.
- State: pending, completed, expired, cancelled.
- Completion/expiration timestamp when resolved.
- Optional notification request identifier.

### StoryEvent

Represents exactly one narrative consequence waiting to be handled:

- Deterministic identity based on occurrence identity and resolution kind.
- Positive for completion or negative for expiration.
- Source occurrence identifier and immutable goal snapshot.
- Status: pending, resolving, resolved, or failed-retryable. In Phase 2 new events remain pending.
- Attempt/error metadata remains compact fields on the event. Do not create the proposal's optional `ResolutionAttempt` entity unless Phase 5 diagnostics demonstrate a real one-to-many need.
- Created/updated timestamps and eventual committed save revision.

The GameSave, character/world entities, and ChronicleEntry arrive in Phase 3. Phase 2 must not fabricate a story result.

## Application services

### GoalOccurrenceService

The service owns all commands that change definitions or occurrences:

- Validate and create/edit definitions.
- Materialize the current actionable occurrence and the next notification schedule.
- Complete a pending occurrence and create its positive StoryEvent in the same explicit persistence transaction.
- Expire due occurrences and create negative StoryEvents in the same transaction.
- Archive, cancel future occurrences, and perform confirmed deletion.
- Refuse transitions from terminal states and treat repeated commands as idempotent success where safe.

Views never construct occurrences or StoryEvents directly.

### DeadlineReconciler

Run after persisted data loads whenever the scene becomes active, before final Today counts are published:

1. Fetch pending occurrences whose due boundary has passed.
2. Resolve them in deterministic oldest-first order.
3. For each, atomically mark expired and create its deterministic negative StoryEvent if absent.
4. Update the Today read model once reconciliation finishes.

It does not start model inference and does not rely on background execution. Large backlogs remain individual events and are surfaced as a count/list rather than silently batched.

### NotificationScheduler

- Ask for notification permission only when a user saves the first scheduled goal or explicitly enables reminders in Settings later.
- Schedule local notifications only after authorization is granted.
- Use title-level, non-shaming copy; omit notes and story state from previews.
- Store stable occurrence and optional event identifiers in the local notification payload.
- Cancel or replace requests when a future occurrence is edited, archived, cancelled, completed early, or deleted.
- Notification delivery never changes occurrence state. Opening the app triggers the same persisted command path as Today.
- Assign the notification-center delegate during app launch so taps are not missed.

## Today feature

Today is the default tab after compatibility and onboarding gates. During Phase 2, use a simple placeholder world card that clearly says the story layer arrives after a goal resolves; do not invent uncommitted state.

Required content and order:

1. Date/Today title and toolbar actions for Add and Settings.
2. A pending-story banner when unresolved StoryEvents exist. It confirms that the real-world completion/expiration is saved.
3. Goal sections in this order: Overdue, Due Today, Upcoming.
4. Each GoalRow has a separate 44-point completion action, title, due/recurrence metadata, optional category/effort, and a distinct detail navigation action.
5. A compact placeholder world summary below the primary actionable goals.
6. A prominent contextual Add Goal action reachable near the bottom of the content.
7. The native three-tab bar.

Required states:

- Loading persisted data uses stable placeholders and never flashes a false empty state.
- Empty presents one primary Add Goal action.
- Populated shows the first actionable goal above secondary world content.
- Completed locks the row immediately and removes duplicate completion affordance.
- Pending story distinguishes saved productivity state from unresolved narrative.
- Overdue visibly differs using label, icon, and grouping rather than color alone.
- All goals complete provides calm confirmation without coins, streak fire, or reward clutter.

## Goal editor

Present creation/editing as a full-screen system sheet with an explicit Add or Save action.

- Give the title initial focus.
- Keep title visible as the only required field.
- Group notes, date, time, repeat, category, and effort in native controls.
- Put recurrence weekday selection and effort/category under progressive disclosure so title-only capture stays fast.
- Prevent save for an empty or whitespace-only title while preserving the actual accepted string.
- Date and repeat rows are fully tappable, labeled, and usable at large Dynamic Type.
- Cancel causes no mutation. If the user changed a persisted definition, ask before discarding; a blank new sheet can dismiss without ceremony.
- Do not request notification permission until a scheduled goal is successfully saved and contextual permission copy has been shown.

## Goal detail and definition management

Goal Detail is pushed within Today's navigation stack. It separates:

- Reusable definition: title, notes, category, effort, recurrence, archive state.
- Current occurrence: due state and complete action when pending.
- Immutable history: completed, expired, and cancelled occurrences with their source snapshots.
- Management: Edit Future Goal, Archive, and Delete with clear impact text.

Editing never updates a resolved occurrence or a StoryEvent source snapshot. Archive and delete actions are visually separated from the primary completion action and require confirmation when data will be removed or future occurrences cancelled.

## Persistence rules

- All command-side writes go through the concrete SwiftData model actor/store established in Phase 1. Feature views may use read models, but never mutate raw models.
- Disable autosave for transactional command work and explicitly commit.
- Completing or expiring an occurrence and creating its StoryEvent is one transaction.
- A deterministic StoryEvent identity plus persisted uniqueness prevents duplicates after double tap, deep link, scene activation, or relaunch.
- Persist date semantics explicitly: due instant for timed goals and local calendar date/time-zone context for all-day goals.
- Materialize only the current and next needed occurrence rather than generating an unbounded future series.
- Store immutable snapshots on occurrences/events instead of joining mutable GoalDefinition text for historical display.
- Phase 2 defines schema version 1 and representative fixtures. Migration code is not speculative; it begins when schema version 2 is introduced in Phase 3.

## UX and hardware behavior

- A completion tap gives immediate visual state change and one light haptic before any story work.
- Do not wait for model availability to update the goal row or Today counts.
- Respect Reduce Motion even though this phase uses only native transitions.
- Support dark and light appearances, safe areas, keyboard avoidance, and landscape functionality.
- VoiceOver exposes completion and detail as separate named actions and announces due state, category/effort when present, and whether a story is pending.
- Preserve readable content at all accessibility Dynamic Type sizes; horizontal scrolling is not an answer for goal rows.

## Required implementation sequence

1. Finalize domain value types and schedule calculations independently of SwiftData.
2. Add SwiftData records and mappings for definitions, occurrences, and StoryEvents.
3. Implement `GoalOccurrenceService` commands with explicit transactions and idempotency.
4. Implement Today loading, sections, completion, and empty/all-complete states.
5. Implement the editor and Goal Detail management flows.
6. Add foreground deadline reconciliation.
7. Add contextual notification permission, request scheduling/cancellation, and payload routing.
8. Add persisted pending-story banner and deep-link destination state.
9. Complete accessibility, calendar/time-zone, interruption, and relaunch tests before Phase 3.

## Testable failure modes

| Failure mode | Test | Expected result |
| --- | --- | --- |
| Blank title | Try whitespace-only title | Save remains unavailable; no definition is inserted. |
| Exact text corruption | Save emoji, line breaks, apostrophes, mixed case, and unusual spacing | Stored source snapshot matches accepted input exactly. |
| Double completion | Rapidly tap completion and repeat after relaunch | One terminal occurrence and one positive StoryEvent exist. |
| Completion/detail gesture collision | Activate each GoalRow action with touch and VoiceOver | Completion never navigates; detail never completes. |
| App killed after tap | Terminate immediately after completion | Relaunch shows completion and exactly one pending StoryEvent, or neither if the transaction failed; never one without the other. |
| Repeated foreground reconciliation | Activate the scene several times after a deadline | One expired occurrence and one negative StoryEvent exist. |
| All-day boundary | Cross midnight and daylight-saving changes | Expiration follows the stored local calendar rule without duplicate/missing occurrences. |
| Time-zone change | Travel before a recurring due time | Future wall-clock occurrences follow the current zone; history remains unchanged. |
| Weekday recurrence | Test every selected/unselected weekday and month/year boundary | Only selected days materialize, once each. |
| Edit recurring definition | Edit after one occurrence resolves | Future occurrence reflects the edit; historical snapshots do not. |
| Archive/delete | Archive or confirm delete with pending future instances | No new occurrence appears; affected pending requests are cancelled; preserved history stays readable. |
| Notification denied | Decline permission | Goal saves normally, Today works, and Settings can explain how to enable notifications. |
| Stale notification tap | Tap after occurrence completed, archived, or deleted | Route opens committed detail when it exists or safe Today; no new StoryEvent is created. |
| Notification reschedule | Edit date/time repeatedly | Only the current request remains scheduled. |
| Persistence still loading | Launch with a large fixture | Stable loading state appears, never false empty content. |
| Large text/VoiceOver | Run Today, editor, and detail at accessibility sizes | Actions remain reachable, labels do not clip, and reading order matches visual hierarchy. |

## Exit criteria

- A title-only goal can be created from Today with one-handed reachable controls.
- Never, Daily, and Selected Weekdays schedules behave correctly across calendar and time-zone fixtures.
- Today, editor, and detail cover loading, empty, populated, completed, overdue, pending-story, archived, and history states.
- Completion and expiration are exactly once under rapid input, relaunch, stale deep links, and repeated reconciliation.
- Each resolved occurrence has one durable pending StoryEvent and no world mutation or synthetic story.
- Local notification permission timing, scheduling, cancellation, denial, and exact routing pass tests.
- Goal history is immutable when the reusable definition changes.
- Phase 2 works entirely offline and without invoking Foundation Models.

## Proposal coverage

This phase implements the goal and event portions of Sections 1.2, 2.1, 3.1, 4.3-4.4, 5.1, and 9.1-9.3; `GoalDefinition`, `GoalOccurrence`, and `StoryEvent` from 6.1; layout/components from 7.1-7.5; SUR-003, SUR-004, SUR-005, the navigation behavior of SUR-010, and the productivity half of SUR-011; NFR-REL-001 and NFR-REL-003; NFR-PERF-001 and NFR-PERF-005; NFR-A11Y-001, NFR-A11Y-002, NFR-A11Y-004, and NFR-A11Y-006; DEC-008 and the goal-history portion of DEC-010.

It resolves DEF-004 with the limited recurrence/category/effort choices above, rejects expired-event batching for the MVP, and omits the optional pre-resolution undo. Phase 3 supplies the world state, schema-bounded mutation contract, and authored visual system needed to resolve the pending events.

## Implementation evidence — 22 August 2026

Implemented and simulator-tested: exact title/notes preservation, blank-title validation, limited recurrence, immutable snapshots, exactly-once completion/expiration, foreground reconciliation, notifications, Today, editor, detail, archive, and delete. Stage 2 tests pass without invoking Foundation Models.
