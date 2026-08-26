# The Horde

The Horde is a local productivity companion for iPhone and Mac. Completing or expiring a goal creates one durable story event; Apple’s on-device Foundation Models framework invents a bounded dragon-and-kobold consequence, and application code validates and atomically commits the world change.

## Requirements

- Xcode 26.6 or newer with the iOS 26 and macOS 26 SDKs
- iOS 26 or macOS 26 or newer
- An Apple Intelligence-capable iPhone or Mac with the on-device model ready for story resolution

No third-party packages, account, analytics SDK, cloud model, or application networking are used.
The initial Mac port uses its own local store; cross-device sync is intentionally deferred.

## Build and test

```sh
rtk xcodebuild build -project TheHorde.xcodeproj -scheme TheHorde \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

rtk xcodebuild test -project TheHorde.xcodeproj -scheme TheHorde \
  -only-testing:TheHordeTests -parallel-testing-enabled NO \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

rtk xcodebuild test -project TheHorde.xcodeproj -scheme TheHorde \
  -only-testing:TheHordeUITests -parallel-testing-enabled NO \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Build the native Mac app with:

```sh
rtk xcodebuild build -project TheHorde.xcodeproj -scheme TheHordeMac \
  -destination 'platform=macOS'
```

The desktop interaction and layout contract is documented in [The Horde for Mac — UX Design](MACOS_UX_DESIGN.md).

The UI target is a bounded product tour: it checks the promised screens, options, settings, three authored graphic states, positive/negative consequence presentation, and one real local-model flow. To run the fast deterministic product tour without the model, use the `-skip-testing` command in [Phase 6 — User-Facing Product Verification](06-user-facing-product-verification.md). Remaining physical-device evidence is tracked in [OUTSTANDING_REQUIREMENTS.md](OUTSTANDING_REQUIREMENTS.md).

## Architecture

- `Domain`: pure scheduling, world, mutation, validation, and projection rules.
- `Application`: serialized story resolution coordination.
- `Infrastructure`: SwiftData, Foundation Models, and local notifications.
- `Features`: compatibility, onboarding, Today, goal management, story resolution, Dungeon, Chronicle, and Settings.
- `World`: bounded SpriteKit scene driven only by committed state and validated cues.

SwiftData command writes use one model actor with autosave disabled and explicit transactions. Generated text is plain selectable content. Generated mutation proposals have no persistence access.
