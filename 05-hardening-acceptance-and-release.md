# Phase 5 — Hardening, Acceptance, and Release

## Outcome

Confirm that the completed app is reliable, accessible, local-only, visually polished, and suitable for MVP distribution. This phase fixes defects; it does not add product systems.

## Frozen MVP scope

- iPhone and iOS 26 or newer.
- Apple’s on-device system model; no cloud model or reduced template fallback.
- No account, sync, analytics, purchases, ads, social features, themes, widgets, or other Apple-platform targets.
- English UI and generated output for MVP, while preserving user-entered goal text exactly.
- Never, Daily, and Selected Weekdays recurrence; optional category and Small/Medium/Large effort.
- One recoverable negative consequence per expired occurrence; no punitive results or post-commit regeneration.
- Local JSON export, distinct Reset Dungeon, and complete Delete All Local Data actions.
- One authored dragon-and-kobold visual theme with normal, hazard, and recovery scenes.

## Automated acceptance

Keep the automated suite bounded and directly tied to product behavior.

### Deterministic tests

- Goal validation, recurrence, calendar boundaries, time zones, immutable snapshots, and exactly-once completion/expiration.
- Writable-field authority, operation/type/bounds checks, patch budgets, collection caps, and recoverable negative policy.
- Atomic world/event/Chronicle commit, rollback, stale-revision rejection, and a real SwiftData reopen.
- Notification destination routing, JSON export, Reset Dungeon, Delete All Local Data, and release schema version.
- Normal/hazard/recovery state mapping and every authored animation cue.

### Product-tour UI tests

- Compatibility and unavailable states.
- Interrupted onboarding and local-load recovery.
- Today empty/populated/pending/overdue/due/upcoming states.
- Goal creation, date/recurrence/category/effort options, detail, edit, complete, archive, delete, and history reachability.
- Dungeon scene/stats/residents/abilities/places/facts.
- Chronicle timeline, search, filters, positive/expired result detail, deltas, and immutable revision data.
- Settings notifications, Haptics, Motion, privacy copy, Export, Reset Dungeon, and Delete All Local Data.
- Largest Dynamic Type reachability and equivalent text for meaningful graphic states.

### Model integration

Run one goal-to-Chronicle flow through the shipping UI when the prompt/schema changes and before a release candidate. The independent validator and transaction tests—not repeated model sampling—prove authority and persistence safety.

## Visual acceptance

Inspect five simulator screenshots:

- Normal dungeon.
- Active hazard.
- Recovery state.
- Completed-goal consequence.
- Expired-goal consequence.

Confirm the authored art is crisp, the graphic matches the accompanying state text, generated prose remains selectable, and primary actions are visible.

## Physical-device checklist

On an eligible iPhone:

- Complete one goal and let one dated goal expire; confirm both results commit and reopen from Chronicle.
- Verify real notification delivery and exact deep-link destination.
- Check VoiceOver order, largest Dynamic Type, Reduce Motion, light/dark and increased contrast, portrait/landscape, haptics, and pixel crispness.
- Use the ordinary goal/story loop for ten minutes and confirm no sustained thermal or responsiveness problem.

Also launch once on an ineligible iPhone and confirm the compatibility gate is honest and finite.

## Privacy and release checks

- Release build succeeds with iPhone-only settings, privacy manifest, app icon, and no unused entitlements.
- Source/dependency inspection finds no app networking, analytics, crash SDK, remote endpoint, or third-party package.
- Settings accurately describes local processing without claiming the operating system never networks.
- Export occurs only after explicit user action; reset/delete confirmations accurately describe their scope.
- Generated text is rendered as plain selectable content and cannot select filenames, routes, or arbitrary assets.
- Signing, bundle identifier, App Store Connect record, support/privacy URLs, metadata, and asset rights are confirmed by the owner.

## Exit criteria

- The deterministic suite, product tour, five visual checks, one real-model integration flow, and Release build pass.
- The short physical-device checklist passes for the release candidate.
- No known release-blocking defect remains in the user-facing core loop, data integrity, model authority, accessibility, local-only behavior, or destructive-data actions.
- External distribution requirements are complete or explicitly listed in [OUTSTANDING_REQUIREMENTS.md](OUTSTANDING_REQUIREMENTS.md).

Current executable commands and the deliverable matrix are in [Phase 6 — User-Facing Product Verification](06-user-facing-product-verification.md).
