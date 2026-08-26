# Phase 1 - Foundation and Platform Proof

## Outcome

Start from an empty repository and finish with a runnable iPhone application shell, verified platform assumptions, a fixed dependency direction, and executable proof that the two risky foundations work on real hardware:

1. Apple's on-device model can produce structured output and call a mutation-staging tool.
2. SwiftData can atomically commit the related records that make one story consequence durable.

This phase does not build the product loop. It removes uncertainty before feature work begins.

## Product boundaries carried through every phase

- The MVP is an iPhone-only, local productivity app with a lightweight dragon-and-kobold story layer.
- The app uses the on-device `SystemLanguageModel` for story generation. App code performs no networking and provides no cloud or template-story fallback.
- Productivity comes first. The stable navigation is Today, Dungeon, and Chronicle. Settings is a secondary toolbar destination, not a fourth tab. This resolves the wording conflict in DEC-008 in favor of the information architecture and UI proofs.
- The model invents consequences and prose. Application code constrains which fields and operations are writable, validates every proposed change, and owns persistence and UI truth.
- Use native Apple frameworks and the standard library. Do not add third-party architecture, dependency-injection, database, networking, animation, or testing packages unless a later measured need cannot be met natively.
- Preserve accessibility basics, data integrity, and input/output validation. Do not add accounts, encryption layers, key management, adversarial threat infrastructure, remote logging, or enterprise security controls to this single-user local MVP.

## Platform decisions

| Area | MVP decision | Reason |
| --- | --- | --- |
| Deployment | iPhone target, iOS 26 minimum | Foundation Models is available on iOS 26 and the proposal is explicitly iPhone-only. |
| Toolchain | Current full Xcode with the matching iOS SDK | This machine currently has Command Line Tools selected but not a usable full Xcode toolchain. Toolchain setup is the first implementation prerequisite. |
| UI | SwiftUI using `TabView`, independent `NavigationStack` state per tab, system sheets, and system controls | Matches the proposed native shell and minimizes custom interaction code. |
| Persistence | SwiftData in one concrete model actor/store; autosave disabled for command transactions | `ModelContext.transaction` and explicit saves give one inspectable write boundary. An interface with one implementation is unnecessary. Tests use an in-memory `ModelContainer`. |
| Model | `SystemLanguageModel.default`, one `LanguageModelSession` per resolution | Keeps all generation local and prevents an unbounded conversational transcript. |
| World rendering | SpriteKit embedded with `SpriteView` | Native, well-suited to crisp sprite atlases and short finite animations. |
| Notifications | UserNotifications local requests only | Deadlines can notify without a server. Foreground reconciliation remains the source of truth. |
| Tests | Swift Testing for unit/integration tests and XCUITest for user flows | Native tools cover the MVP without another dependency. Real-device model evaluation remains a separate suite. |

Current Apple API notes, rechecked 22 August 2026:

- `SystemLanguageModel.availability` distinguishes available, device-ineligible, Apple-Intelligence-disabled, model-not-ready, and unknown states. `supportsLocale` must also pass before a session begins.
- Model readiness can change as system-managed assets download. Recheck on foreground activation and manual retry.
- Use the model's `tokenCount(for:)` and `contextSize` instead of treating the proposal's approximate 1,000-character projection target as a correctness boundary. Phase 1 measures a conservative token budget on the shipping SDK; Phase 5 validates it across supported OS model versions.
- Apple documents required-device capability filtering generally, but no Apple-Intelligence-specific `UIRequiredDeviceCapabilities` value is assumed. Runtime gating is authoritative. App Store compatibility metadata is investigated but must not replace the gate.
- SwiftData provides model-actor isolation and explicit context transactions. The spike must prove rollback and relaunch behavior rather than relying on implicit autosave.

Primary references:

- [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
- [Foundation Models updates](https://developer.apple.com/documentation/updates/foundationmodels)
- [Supporting languages and locales](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)
- [SwiftData ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext)
- [SwiftData concurrency support](https://developer.apple.com/documentation/swiftdata/concurrencysupport)
- [Required device capabilities](https://developer.apple.com/support/required-device-capabilities/)

## Architecture

### Dependency direction

Dependencies point inward:

`Features and App shell -> Application services -> Domain types and rules`

`Application services -> Infrastructure adapters`

The domain layer imports no SwiftUI, SwiftData, SpriteKit, Foundation Models, or UserNotifications APIs. Infrastructure converts between platform records and domain values. Views dispatch named application actions and render read models; they never write model-proposed state directly.

### Responsibilities

| Boundary | Owns | Must not own |
| --- | --- | --- |
| App shell | Compatibility gate, first-run routing, tab/navigation state, dependency construction | Goal rules, model prompts, persistence mutations |
| Features | Screen state, user intent, presentation formatting, accessibility labels | Cross-feature transactions, raw SwiftData contexts, model tools |
| Domain | Goals, occurrences, story events, game state, mutations, validation rules, recurrence and due-state calculations | Apple framework types or UI state |
| Application services | Goal commands, deadline reconciliation, projections, resolution orchestration, export/reset commands | View layout or storage implementation details |
| Infrastructure | SwiftData store, Foundation Models adapter, local notification scheduler, JSON exporter | Product policy or presentation decisions |
| World presentation | Mapping committed domain state and validated animation cues to authored assets | Inventing state or accepting model-provided asset names |

### Initial project structure

Keep a single app target, one unit-test target, and one UI-test target.

- `App/`: app entry, dependency container, root compatibility/onboarding/tab routing.
- `Domain/`: value types, entity identifiers, recurrence, event state, world state, mutation descriptors, validators.
- `Application/`: goal occurrence service, deadline reconciler, projection builder, resolution coordinator, export/reset operations.
- `Infrastructure/Persistence/`: SwiftData models, schema versions, concrete model actor/store, migrations.
- `Infrastructure/FoundationModels/`: availability mapping, sessions, structured output, staging tool adapter.
- `Infrastructure/Notifications/`: permission state, scheduling, response routing.
- `Features/`: Compatibility, Onboarding, Today, Goals, StoryResolution, Dungeon, Chronicle, Settings.
- `World/`: SpriteKit scene, asset catalog, state-to-scene mapping, animation cue mapping.
- `DesignSystem/`: colors, spacing, reusable accessible controls and cards.
- `Resources/`: localized strings, prompt text/version metadata, sprite atlases, sound assets, privacy/about copy.
- Tests mirror these boundaries. Shared test fixtures live under the test target, not production code.

Do not split these into packages during the MVP. Folder and type boundaries provide enough separation; package extraction is justified only if build times or reuse demand it.

## Persistence transaction proof

Define the smallest provisional records needed to prove the critical write:

- A save record with a monotonically increasing revision.
- A story event with deterministic identity, valence, source occurrence identity, and pending/resolved status.
- A chronicle entry linked to the story event and committed save revision.
- A staged patch receipt that is not itself canonical game state.

The proof transaction must:

1. Fetch the pending event and current save inside the store's serialized context.
2. Verify event status and expected save revision.
3. Validate an authored test patch.
4. Apply it to a copy or staged representation.
5. In one explicit SwiftData transaction, update the save and revision, resolve the event, and insert the chronicle entry.
6. Roll back all changes when any validation or write step fails.

Use deterministic event identity derived from an occurrence identity and event kind. Also enforce uniqueness in persistence where the shipping SwiftData SDK supports it. Idempotency must not depend on a disabled button or an in-memory flag.

## Foundation Models proof

On an eligible real iPhone, establish one short-lived session that receives:

- A positive or negative event with a sample goal title.
- A small read-only world summary.
- A runtime-generated writable contract containing field identifiers, operations, bounds, and collection record shapes.
- A staging tool that records proposed mutations in memory and has no persistence access.

The proof succeeds only when the model invents a consequence not selected from a catalog, stages at least one valid mutation, returns structured narrative fields, and the application can validate the complete staged patch. A deliberately unauthorized field and an out-of-range mutation must both be rejected by application code.

The proof also records:

- Availability and locale behavior on the shipping SDK.
- Token counts for instructions, event, world projection, writable schema, tool exchange, and output allowance.
- Typical and slow-path inference latency on at least one supported phone.
- Cancellation behavior when the app backgrounds.
- Guardrail, unsupported-language, context-overflow, and invalid-structured-output error mapping.
- Whether Foundation Models API or model behavior differs across supported iOS 26.x and current iOS 27 test devices available to the team.

The result is an engineering note inside this phase document's implementation evidence, not a new product document.

## Compatibility shell requirements

Before product data is created, the root flow evaluates both model availability and locale support.

| State | Required presentation and action |
| --- | --- |
| Available and locale supported | Continue to onboarding or Today. |
| Device not eligible | Blocking explanation, supported-device information, no imitation story mode. |
| Apple Intelligence disabled | Blocking but recoverable explanation, open system Settings where possible, and Check Again. |
| Model not ready | Blocking download/readiness explanation, no invented percentage, Check Again, and automatic foreground recheck. |
| Locale unsupported | Blocking explanation that the current app language cannot use the local model; no session is started. |
| Unknown unavailable | Neutral blocking state with retry and diagnostic classification that contains no user goal text. |

The shell uses Dynamic Type, a logical VoiceOver order, descriptive actions, and a static/reduced-motion world mark. The unavailable reason is conveyed in text, not just color or iconography.

## Design foundation

Establish tokens rather than styling every screen independently:

- Calm adaptive application background; the proof value is warm off-white `#F4F1EB`.
- High-contrast primary text; proof value `#191722`.
- One ember action accent; proof value `#D7643D`.
- Positive and negative semantic roles, always paired with text/iconography; proof values `#2C8A68` and `#B85C4B`.
- Dark world-scene container; proof value `#17182B`.
- Spacing rhythm: 4, 8, 12, 16, 24, and 32 points.
- Primary list/card margins of 16 points; text-heavy reveals use 20-24 points.
- Native container shapes or 16-24 point card radii.
- Minimum 44 by 44 point action targets.
- System text styles with Dynamic Type. Important labels never live inside raster art.
- Portrait is the design baseline. Landscape must remain usable without a bespoke composition.
- Nearest-neighbor sprite scaling and finite authored motion only.

The app shell should already demonstrate safe-area handling, large accessibility text without clipped primary actions, dark/light appearance, and Reduce Motion behavior.

## Required implementation sequence

1. Install/select full Xcode and verify the iOS 26 SDK, signing, supported phone, and simulator destinations.
2. Create the app and test targets with no third-party packages.
3. Establish the folder boundaries and one composition root.
4. Add the design tokens and three-tab shell using placeholder content.
5. Implement the pre-data compatibility state machine and foreground recheck.
6. Complete the SwiftData transaction/rollback spike in isolation.
7. Complete the real-device Foundation Models staging-tool spike.
8. Record measured token/latency/error behavior and freeze the Phase 2 domain assumptions.

## Testable failure modes

| Failure mode | Test | Expected result |
| --- | --- | --- |
| No full Xcode or wrong SDK selected | Run the documented clean-build preflight | Preflight fails with a specific setup action before feature work begins. |
| Permanently ineligible phone | Launch with `.deviceNotEligible` | Blocking state appears; no local world, goal store, or story UI is initialized. |
| Apple Intelligence is off | Launch and foreground with disabled state | Correct action is shown and availability is re-evaluated after returning. |
| Model assets are downloading | Launch with `.modelNotReady` | No fake progress or fallback result appears; manual and foreground checks work. |
| Unsupported app locale | Force an unsupported locale | No model session begins; the reason is readable and actionable. |
| Availability changes during launch | Transition from unavailable to available | Root routing advances once without duplicating initialization. |
| Unauthorized tool mutation | Ask the proof prompt to change a hidden field | Tool/validator rejects it; persistent state remains unchanged. |
| Invalid value or record shape | Stage an out-of-range scalar or malformed collection record | Whole patch fails; no partial mutation survives. |
| Stale save revision | Commit against an older revision | Commit is rejected; save, event, and chronicle remain unchanged. |
| Failure during multi-record save | Inject a throw before the transaction completes | Relaunch shows the original revision and pending event, with no chronicle entry. |
| Background cancellation | Background during generation | Session ends or is abandoned safely; no canonical write occurs. |
| Accessibility expansion | Run the shell at the largest Dynamic Type size | Explanations reflow, actions remain reachable, and no text clips. |

## Exit criteria

- A clean build and test run works from a documented Xcode setup on this machine.
- The app launches into the correct compatibility state on eligible, disabled, not-ready, unsupported-locale, unknown, and ineligible conditions.
- A real supported iPhone completes the free-form structured-generation and mutation-staging proof.
- Unauthorized and invalid staged mutations are rejected without persistence changes.
- The transaction proof demonstrates atomic success, rollback, stale-revision rejection, and safe relaunch.
- The three-tab shell, design tokens, dependency direction, and folder ownership are fixed for later phases.
- Token budget and latency observations are recorded. No arbitrary 1,000-character hard limit is frozen without measurement.
- No product data leaves the phone and no account, analytics, cloud, payment, or third-party dependency exists.

## Proposal coverage

This phase establishes or validates: Sections 2.1-2.3, 3.3, 4.1, 5 and 5.1-5.2; the authorization boundary in 6.2-6.5; design-system foundations in 7.1-7.3; SUR-001; NFR-PERF-002 and NFR-PERF-004; NFR-PRIV-001 through NFR-PRIV-004; DEC-001 through DEC-005 and DEC-007; and the platform portions of DEF-006 and DEF-010.

Phase 2 begins only after these proofs pass. It builds the complete productivity loop without depending on story generation.

## Implementation evidence — 22 August 2026

Implemented with Xcode 26.6 and the iOS 26.5 SDK. The compatibility shell, staging-only Foundation Models adapter, independent mutation validation, atomic success, injected rollback, and stale-revision boundaries build and pass on the iOS simulator. Required physical-iPhone model measurements remain in the repository’s single outstanding-requirements log.
