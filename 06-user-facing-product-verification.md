# Phase 6 — User-Facing Product Verification

## Outcome

Verify that The Horde looks and behaves like the promised local productivity app. Acceptance is based on visible product surfaces, authored graphics, options, settings, accessibility, and representative positive and negative story consequences.

## Verification layers

1. **Deterministic product tests** protect scheduling, persistence, notification routing, bounded mutation authority, export/reset/delete, and atomic commits without invoking the language model.
2. **iOS product tour** launches the shipping app with small DEBUG-only fixtures and proves the promised screens, controls, navigation, text, and authored art are reachable. Five screenshots cover the three scene states plus positive and negative story results.
3. **One real-model flow** creates and completes one goal through the shipping UI, waits for the local model, dismisses the consequence, and finds it in Chronicle. Run it when the prompt/schema changes and before a release candidate.
4. **Physical-iPhone review** covers model readiness, notification delivery, VoiceOver, motion, haptics, pixel crispness, orientation, and ordinary-use thermal behavior once per release candidate.

## User-facing acceptance matrix

| Promised deliverable | Reliable evidence |
| --- | --- |
| Compatibility guidance | Every unavailable state launches with finite guidance and a reachable retry action. |
| Two-step first run and naming | Interrupted onboarding launches at the saved naming step; naming controls and completion remain reachable. |
| Today states | The showcase visibly presents pending story, overdue, due-today, and upcoming sections with task-first actions. |
| Goal options | Editor exposes date, time, daily/selected-weekday recurrence, category, and effort; deterministic tests verify saved scheduling behavior. |
| Goal management | A created goal opens Goal Detail with complete, edit, archive, delete, and history surfaces. |
| Story results | Curated Chronicle data contains six distinct consequences spanning every authored cue and both completed/expired valences; one real flow proves model-to-Chronicle integration. |
| Dungeon | Product tour verifies authored scene, stats, active/recovered state, residents, ability, places, facts, and drill-in navigation. |
| Chronicle | Populated history, search, filter, immutable detail, source goal, revision, and change rows are exercised in the shipping UI. |
| Settings | Notifications, Haptics, Motion, on-device/privacy disclosure, Export, Reset Dungeon, and Delete All Local Data are visible and reachable. |
| Notification routing | Deterministic route-table tests cover pending result, committed Chronicle result, goal detail, and stale fallback. Physical delivery stays a device check. |
| Graphics and accessibility | Normal, hazard, and recovery assets render in-app; all six cues map only to those assets; scene meaning has an accessibility label. |

## Commands

Deterministic suite:

```sh
rtk xcodebuild test -project TheHorde.xcodeproj -scheme TheHorde \
  -only-testing:TheHordeTests -parallel-testing-enabled NO \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Product tour without the model:

```sh
rtk xcodebuild test -project TheHorde.xcodeproj -scheme TheHorde \
  -only-testing:TheHordeUITests \
  -skip-testing:TheHordeUITests/TheHordeUITests/testOneRealModelGoalToChronicleFlow \
  -parallel-testing-enabled NO \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Single real-model integration check:

```sh
rtk xcodebuild test -project TheHorde.xcodeproj -scheme TheHorde \
  -only-testing:TheHordeUITests/TheHordeUITests/testOneRealModelGoalToChronicleFlow \
  -parallel-testing-enabled NO \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Pass rule

Phase 6 passes when the deterministic suite and product tour are green, the five visual attachments have been inspected, and the single model flow passes on the current prompt/schema. Release acceptance additionally requires [the physical-device checklist](OUTSTANDING_REQUIREMENTS.md).
