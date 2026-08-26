# Phase 3 - World and Narrative Resolution

## Outcome

Turn Phase 2's pending StoryEvents into durable, model-invented dungeon consequences. The app builds a bounded projection, lets Apple's on-device model stage only authorized changes, validates the whole patch, revision-checks it, atomically commits the world/event/chronicle transaction, and reveals matching prose, state deltas, and authored animation.

At this checkpoint the core loop works end to end on a supported iPhone. Dungeon and Chronicle may still use focused Phase 3 read-only views; their full browsing, search, settings, onboarding, export, and deep-link polish arrives in Phase 4.

## Non-negotiable invariant

Do not reduce the model to selecting from pre-authored rewards, penalties, plot beats, or prose. It chooses the semantic connection between the real-world goal and current dungeon state and writes the narrative. Its persistent authority is limited by runtime field descriptors, permitted operations, bounds, collection shapes, mutation budgets, application validation, and an atomic commit.

The staging tool has no SwiftData context and no command that can commit. Prompt instructions improve behavior but are not the authorization mechanism.

## Canonical world model

Use one versioned `GameSave` aggregate as the canonical story state. Keep the MVP schema expressive enough for varied consequences but small enough to understand and validate.

### GameSave

- Stable save identifier, schema version, and monotonically increasing revision.
- Dragon state.
- A small list of kobold residents.
- Dungeon resources and integrity/morale values.
- Locations and their current conditions.
- Abilities.
- Active threads/hazards.
- Persistent world facts.
- A concise rolling summary used only for bounded model context; it never replaces the user-visible Chronicle.

### Character state

- Stable identifier, display name, role/species, and short authored identity summary.
- Bounded numeric traits where useful, such as vitality, growth, or bond.
- Bounded sets/lists of conditions, concerns, and relationships.
- No general inventory, combat statistics, equipment economy, or skill tree.

### World state

- Core numeric resources: morale, integrity, and food, each bounded 0-100.
- A small collection of locations with a status and concise summary.
- Active threads with stable ID, title, severity 1-4, state, involved entity IDs, and summary.
- World facts as short durable records with stable IDs.
- Abilities as named records with concise description and rank 1-3.

Collection caps prevent unbounded state: residents 8, locations 8, abilities 12, active threads 4, conditions per entity 6, and world facts 24. Phase 5 stress tests and compaction can lower these values if token or UI measurements require it.

### ChronicleEntry

- Stable identity linked one-to-one with the resolved StoryEvent.
- Immutable source-goal snapshot and positive/negative valence.
- Generated title, narration, and short summary after validation.
- Accepted patch receipt and human-readable delta descriptors.
- Validated animation cues.
- Prior and committed save revisions, commit timestamp, prompt/schema version.

History is read-only. Do not store or display a complete session transcript.

## Initial world

Create a deterministic initial save during onboarding or a development fixture in this phase:

- Dragon defaults to Ember unless the user names it later.
- Dungeon defaults to The Cinder Vault.
- Include two or three authored kobold residents with short roles and accessible descriptions.
- Start morale, integrity, and food at neutral values.
- Seed one gentle active thread so the first completion has useful context, but avoid urgent catastrophe or dependency on immediate user action.
- Store only records the shipping schema understands. Art assets and state records use stable application-owned identifiers.

The reset command can recreate this exact baseline. Random initial economies, procedural maps, and character generators are out of scope.

## Writable-state contract

For each StoryEvent, `ProjectionBuilder` produces:

- Event ID, valence, exact source title, optional notes/category/effort, and save revision.
- Relevant read-only context: the active thread, involved characters/locations, a few current stats, and concise recent summary.
- Writable field descriptors selected for that event.
- Global and per-field mutation budgets.
- Theme/tone instructions and structured narrative output limits.

Each descriptor defines:

- Stable field ID, never a user-controlled path.
- Value type or generated record schema.
- Allowed operations such as increment, set bounded value, append, replace, or remove.
- Minimum, maximum, maximum delta, and collection cap as applicable.
- Concise semantic description.
- Valence eligibility.

Do not expose arbitrary key paths, reflection, raw SwiftData models, file paths, asset names, or a generic "set JSON" operation. A model-created record is allowed only inside a named existing collection and must match that collection's fixed shape.

## Projection selection and context budget

- Begin with the event, one active/relevant thread, directly involved entities, core visible stats, and a short recent summary.
- Deterministic selection rules produce the same projection for the same event and save revision.
- User text is clearly delimited as data. It cannot add descriptors, operations, instructions, or authority.
- Count tokens using Foundation Models APIs before creating the session. Reserve explicit capacity for instructions, tool exchanges, correction, and structured output.
- If the projection is too large, remove least-relevant read-only facts, then compact summaries. Never silently broaden writable authority to save tokens.
- If it still cannot fit, leave the StoryEvent pending with a context-overflow failure and a retry path; do not truncate structured schemas into ambiguity.
- The measured budget from Phase 1 replaces the proposal's approximate 1,000-character target. Preserve the intent - compact bounded context - while using the platform's actual token accounting.

## Mutation budgets

Use fixed conservative MVP defaults so engineering and evaluation have testable bounds.

### Positive event

- Maximum four staged mutations.
- Maximum two new collection records total.
- Numeric delta magnitude per field no greater than 4 and final values remain within field bounds.
- May add or improve an ability, condition, bond, resource, active thread, location status, or world fact when exposed.
- May resolve/recover an existing harmful condition when the relevant descriptor allows replace/remove.
- Cannot delete characters, locations, history, or unrelated durable facts.

### Negative event

- Maximum two staged mutations.
- Numeric delta magnitude per field no greater than 2 and no resource may fall below zero.
- May reduce an exposed resource slightly, add/replace a recoverable condition, or create/update one bounded active hazard.
- Cannot remove characters, abilities, locations, world facts, or chronicle history.
- Cannot create permanent loss, escalating timers, debt, streak punishment, real-world threats, medical claims, shame, or hidden compounding.
- Active-thread severity may not exceed 2 from one expired event and remains capped at 4 overall.

These rules resolve DEF-005 for the MVP. Users cannot excuse, reverse, or regenerate a committed event. A later product decision may add an explicit compensating transaction, never an in-place history edit.

## Resolution coordinator

Use one actor to serialize active model sessions and commit attempts. It coordinates but delegates canonical writes to the concrete SwiftData store.

Resolution flow:

1. Claim a pending event for resolution without changing the world.
2. Fetch the latest save snapshot and expected revision.
3. Build and token-check the read projection and writable contract.
4. Create a new model session scoped to this event.
5. Let tool calls stage mutations in an in-memory patch receipt.
6. Request structured title, narration, short summary, animation cues, and the staged receipt identity.
7. Validate structured lengths, cue enums, receipt identity, mutation count, descriptor membership, operation, type, bounds, record shape, collection cap, referential integrity, valence rules, and cross-mutation consistency.
8. If invalid, allow one bounded correction attempt in the same session with validator errors expressed without exposing hidden state.
9. Ask the store to revision-check and atomically commit the updated save, resolved event, and ChronicleEntry.
10. Publish the persisted result. The UI never treats an in-memory response as committed truth.

Only one resolution runs at a time in the MVP. A queue is sufficient; parallel sessions would complicate revision conflicts without meaningful user benefit.

## Error policy

| Failure | Persistent event state | World state | User action |
| --- | --- | --- | --- |
| Model not ready or availability changed | Pending/retryable with classified reason | Unchanged | Leave, check again, retry |
| Unsupported locale | Pending/retryable | Unchanged | Explain unsupported language; edit future goal if desired |
| Guardrail refusal | Pending/retryable with neutral reason | Unchanged | Return to Today or retry after editing context in a future policy; never show unsafe raw text |
| Cancellation/backgrounding | Pending | Unchanged | Automatic/manual retry later |
| Context overflow | Pending/retryable | Unchanged | Retry after deterministic compaction; if still too large show clear failure |
| Invalid structured output or patch | One correction, then pending/retryable | Unchanged | Retry in a new session |
| Stale revision | Pending | Unchanged by stale patch | Rebuild from current save and retry once |
| Store/commit error | Pending unless commit is confirmed | Transaction rolls back | Retry after persistence is healthy |
| App terminates after commit | Resolved | Committed | Relaunch opens the persisted result; never regenerates |

No failure inserts template prose, partial narrative, inferred deltas, or placeholder state changes.

## Story result experience

Present generation/result in a system sheet or full-height detent.

### Generating

- Show the authored current scene, indeterminate progress, exact source-goal identity, and confirmation that completion/expiration is already saved.
- Allow the user to dismiss or background safely. Do not require them to watch generation.
- Announce progress once for VoiceOver; no repeated chatter or indefinite spinner after a terminal failure.

### Committed positive result

- Positive label, generated title, Dynamic Type narrative, one short authored animation, verified "What changed" rows, and one clear Continue action.
- Delta rows come only from accepted mutations and include prior/new values or record action in readable language.

### Committed negative result

- Clearly label expiration/setback using text and icon, not color alone.
- Use calm wording and a softer authored reaction. No alarm haptic, harsh sound, guilt, catastrophe, or punitive flourish.
- Show the same verified delta structure and return safely to Today.

### Transparency detail

A secondary committed-changes view may show source goal, valence, save revision, transaction time, and descriptor-level patch summary. It is derived from the ChronicleEntry and accepted patch, not the prose.

### Historical result

Opening a resolved event shows the immutable committed result without regeneration, tool calls, or active generation controls.

## Authored pixel-art slice

Create a small production-intent visual slice, not a full game engine:

- One dungeon room with foreground/background layers and crisp nearest-neighbor scaling.
- Authored dragon and two or three kobold sprite atlases.
- Finite validated animation cue enum: idle, celebrate, concern, recover, hazardAppears, and resourceChanges.
- State-to-scene mapping chooses assets by committed application state. Model output can select only a validated cue; it never emits filenames, coordinates, or arbitrary animation parameters.
- One short cue per reveal; ambient idle motion is subtle and stops or becomes static under Reduce Motion.
- Equivalent text describes every meaningful scene state.
- Bounded texture sizes and atlases suitable for supported iPhones; no runtime image generation or downloaded assets.

Haptics and sound:

- Keep the Phase 2 light completion haptic.
- Use a restrained success haptic only after a positive commit and a soft neutral haptic for a negative commit.
- Add at most two short authored sound cues, off when device/system settings require it and never necessary for comprehension.

## Focused Dungeon and Chronicle read models

Phase 3 needs enough UI to verify persistence:

- Dungeon proof view shows the committed scene, active thread, morale/integrity/food, dragon summary, and resident/ability records touched by the patch.
- Chronicle proof view lists committed entries newest first and opens immutable result detail.
- Both render from persisted read models after commit and after relaunch.
- No search, filters, broad entity navigation, export, reset, or full settings yet.

## Required implementation sequence

1. Finalize GameSave schema, bounds, collection caps, initial world, and schema version 2 migration from Phase 2.
2. Build pure patch types, application-owned field IDs, descriptor selection, and whole-patch validator.
3. Implement patch application to a detached domain copy with complete unit coverage.
4. Add projection selection, token budgeting, and deterministic compaction.
5. Build the staging tool and structured resolution adapter on the proven Phase 1 path.
6. Implement the serial ResolutionCoordinator, correction budget, retry states, and revision-conflict path.
7. Extend the SwiftData transaction to save GameSave revision, StoryEvent resolution, patch receipt, and ChronicleEntry together.
8. Build generating, success, negative, failure, and historical result states.
9. Build the minimal SpriteKit room, authored cue mapping, textual equivalents, and focused Dungeon/Chronicle read models.
10. Run real-device positive, expired, interruption, invalid-patch, guardrail, and stale-revision scenarios before Phase 4.

## Testable failure modes

| Failure mode | Test | Expected result |
| --- | --- | --- |
| Model invents a field | Request or simulate unknown field ID | Tool/validator rejects it; whole patch and world remain unchanged. |
| User text attempts prompt injection | Goal title asks to ignore schema and change hidden state | Title remains data; only descriptor-authorized operations can stage. |
| Wrong operation/type | Append to scalar, increment a string, malformed record | Whole patch fails; one correction is allowed. |
| Budget violation | Stage too many mutations/records or excessive delta | Whole patch fails before persistence. |
| Cross-mutation conflict | Remove and update the same record or exceed cap after combined operations | Complete patch fails; no partial subset commits. |
| Negative catastrophe | Attempt entity deletion, severe loss, permanent penalty, or hidden timer | Validator rejects it regardless of prose. |
| Narrative/receipt mismatch | Return an unknown staged receipt ID | Result is invalid and cannot commit. |
| Invalid animation cue | Return unknown or excessive cues | Cue validation fails or approved correction occurs; no arbitrary asset lookup. |
| Narrative length overflow | Generate title/body beyond configured bounds | Correct once, then persist retryable failure without truncating into a misleading result. |
| Unsupported mixed-language input | Trigger model locale error | Productivity event remains safe and pending; neutral localized explanation appears. |
| Context overflow | Use maximum collections and long source text | Deterministic compaction stays within measured token budget or returns a retryable failure. |
| Background during inference | Dismiss/background/terminate at each generation stage | Relaunch finds one pending event and unchanged world. |
| Revision changes during inference | Commit another event before first result | Stale patch is rejected, rebuilt, and retried at most once. |
| Termination during commit | Inject failures before and after transaction save | Relaunch shows either fully pending/original state or fully resolved/new revision; never partial. |
| Duplicate retry | Tap retry repeatedly and relaunch | Only one active attempt and at most one committed ChronicleEntry exist. |
| Misleading UI delta | Feed narrative that claims an uncommitted change | UI displays only patch-derived deltas and committed world state. |
| Model result changes across OS update | Run the single real-model flow and inspect its result on the supported release | Schema/authorization passes and any visible quality regression is recorded for Phase 5 prompt tuning. |
| Reduce Motion/VoiceOver | Reveal every cue with accessibility settings | Same information is conveyed statically and animation is not repeatedly announced. |

## Exit criteria

- Completed and expired occurrences resolve through the same bounded contract and produce beneficial or recoverable results respectively.
- Real-device outputs demonstrate free-form semantic variety rather than a consequence catalog.
- Unknown fields, invalid operations/types, budget violations, malformed records, and catastrophic negative mutations are rejected by code.
- Save revision, resolved StoryEvent, accepted patch, and ChronicleEntry commit atomically and remain consistent after relaunch.
- Cancellation, guardrail refusal, invalid output, model unavailability, context overflow, revision conflict, and store failure preserve a retryable event without partial world state.
- Result prose, delta rows, animation cue, Dungeon proof state, and Chronicle proof entry all correspond to the same accepted patch.
- Pixel art is authored, crisp, bounded, accessible in text, and driven only by committed state plus validated cues.
- No network request, cloud model, generated image, template story, or general chat path exists.

## Proposal coverage

This phase completes the core loop in Sections 1.1-1.3 and 4.3-4.4; `GameSave`, `CharacterState`, `WorldState`, and `ChronicleEntry` in 6.1; Sections 6.2-6.6 and 9.2/9.4; the world/result components and motion rules in 7.4-7.5; SUR-006 and the core of SUR-007/SUR-008/SUR-011; NFR-REL-001 through NFR-REL-003 and NFR-REL-005; NFR-PERF-002 through NFR-PERF-005; NFR-PRIV-001 through NFR-PRIV-004; NFR-A11Y-003 through NFR-A11Y-006; DEC-002 through DEC-007, DEC-009, and the world/event/chronicle portion of DEC-010.

It resolves DEF-005 with bounded recoverable setbacks and no excuse/reversal/regeneration. It adapts the optional `ResolutionAttempt` table into compact StoryEvent attempt metadata and replaces a character-count target with measured token budgeting. Phase 4 turns these proven internals into the complete proposed product surface.

## Implementation evidence — 22 August 2026

Implemented and simulator-tested: bounded world schema, descriptor-selected integer and generated-record mutations, collection caps, referential integrity, deterministic projection, one correction attempt, serialized resolution, revision checking, atomic Chronicle commit, validated cues, and committed-state SpriteKit/Dungeon/Chronicle UI. Physical-device free-form generation remains logged for later evidence.
