# MVP Implementation Evidence

Verified on 23 August 2026 with Xcode 26.6, the iOS 26.5 SDK, an iPhone 17 Pro simulator, and the host’s local Foundation Models system model.

## Delivered product

- Compatibility gate, two-step onboarding, and a native Today/Dungeon/Chronicle shell.
- Goal creation and management with optional date/time, Never/Daily/Selected Weekdays recurrence, category, effort, immutable occurrence history, notifications, archive, and delete.
- A bounded local world, independent patch validation, atomic story commits, retryable failure states, and immutable Chronicle entries.
- Settings for notification status, haptics, motion, on-device/privacy disclosure, JSON export, Reset Dungeon, and Delete All Local Data.
- Three authored scene families—normal, hazard, and recovery—with accessible text and six bounded presentation cues.
- No app networking, account, cloud sync, analytics, purchases, or third-party dependencies.

## Current passing evidence

- **43 deterministic tests** pass in 0.8 seconds. They cover scheduling, recurrence/time zones, exact event creation, bounded model authority, transaction rollback/commit, real SwiftData reopen, notification routing, export/reset/delete, collection caps, and product fixtures.
- **7 deterministic UI product-tour tests** pass on iPhone 17 Pro Simulator. They cover compatibility states, onboarding/load recovery, goal creation/management/options, Today states, Dungeon, Chronicle/search/filter/results, Settings, largest Dynamic Type reachability, and authored visuals.
- **5 inspected screenshots** demonstrate normal, hazard, recovery, completed-goal, and expired-goal presentations. The text and graphic state agree in each.
- **1 real-model UI integration test** passes in 25 seconds: create a goal, complete it, generate one local consequence, continue, and find the source goal in Chronicle.
- The iOS Simulator **Release build succeeds** after the verification restructure.
- The Xcode project contains only the app, deterministic-test, and UI-test targets.

The current pass rule and exact commands live in [Phase 6 — User-Facing Product Verification](06-user-facing-product-verification.md). Physical-device and distribution checks remain in [OUTSTANDING_REQUIREMENTS.md](OUTSTANDING_REQUIREMENTS.md).
