# The Horde for Mac — UX Design

Status: initial top-level port  
Source of truth: the existing iPhone app and its product-verification fixtures  
Target: native SwiftUI app for macOS 26+

## Product intent

The Mac app is the same private, local productivity companion as the iPhone app. A person creates and completes goals, each resolved goal produces one durable story event, and Apple’s on-device model proposes a bounded dungeon consequence that application code validates before committing.

This port does not add accounts, networking, cloud sync, collaboration, purchases, or a reduced story mode. Mac and iPhone data are separate for this first version.

## Design inheritance

Keep the visual identity already established on iPhone:

- warm parchment background and near-black ink, with equivalent dark-mode colors;
- ember orange as the primary action and selection color;
- large, friendly typography and softly rounded cards;
- authored 16:9 pixel-art dungeon scenes with nearest-neighbor rendering;
- green for completed consequences and muted red for recoverable setbacks;
- plain, reassuring privacy and failure language.

The Mac app should feel like the same place with more room, not an enlarged phone screen.

## Desktop information architecture

Use a persistent sidebar in the main window:

1. **Today** — pending goals grouped as Overdue, Due Today, and Upcoming; pending-story entry point; compact dungeon summary.
2. **Dungeon** — current scene, world summary, resources, active thread, residents, abilities, places, and facts.
3. **Chronicle** — searchable and filterable immutable story history.

Settings remains an app-level destination opened from the sidebar or Command-,. Add Goal is available in the Today toolbar and with Command-N.

The selected section owns the main workspace. Goal, Chronicle, and world-entity details push within that workspace. Goal editing, story resolution, and Settings use centered resizable sheets rather than phone full-screen covers.

## Window and layout behavior

- Default window: approximately 1120 × 760 points.
- Minimum useful window: 780 × 560 points.
- Sidebar: system-standard width and selection treatment, carrying the three existing SF Symbols.
- Main content: readable width is capped so cards do not stretch edge to edge on wide monitors.
- Today: goal groups occupy the primary column; the dungeon summary sits beside them when space permits.
- Dungeon: the authored scene is prominent but bounded; world cards flow beneath it in a comfortable reading column.
- Chronicle: use a native list, search field, and toolbar filter menu. Selecting a record opens its detail in the same navigation stack.
- Sheets: goal editor about 520 × 620, story result about 620 × 700, and Settings about 620 × 680, while remaining resizable.

When the window narrows, content may stack vertically and scroll. No feature or action may become unreachable.

## Feature parity and Mac adaptation

| iPhone behavior | Mac behavior |
|---|---|
| Bottom tab bar | Persistent source-list sidebar |
| Bottom Add Goal action plus top Add button | Toolbar Add Goal plus Command-N |
| Gear button in Today toolbar | Sidebar Settings plus Command-, |
| Full-screen goal editor | Centered sheet |
| Navigation sheets for story and Settings | Centered resizable sheets |
| Tap targets sized for touch | Standard Mac controls with generous row spacing |
| Haptic completion feedback | Omitted because Mac has no equivalent app haptic contract |
| iPhone Settings deep links | Corresponding macOS System Settings links |
| Foreground/background SpriteKit pausing | Mac app active/inactive lifecycle pausing |

All product features remain: onboarding and naming; compatibility guidance; goal create/edit/complete/archive/delete; optional dates, times, recurrence, category, and effort; local notifications; pending-story retry; generated and validated consequences; Dungeon browsing; Chronicle search/filter/detail; local JSON export; dungeon reset; full local-data deletion; reduced-motion preference; accessible descriptions; selectable generated text.

## Key flows

### First run

1. Check on-device model compatibility.
2. Explain the local goal-to-dungeon loop using the existing authored scene.
3. Accept optional dragon and dungeon names.
4. Enter Today in the main window.

### Create and complete a goal

1. Choose Add Goal or press Command-N.
2. Enter the required title and any optional schedule/context.
3. Save and return to Today.
4. Complete from the row or goal detail.
5. Show the story-resolution sheet while preserving the already-saved event.
6. On commit, show narration and explicit world deltas; on failure, show the retry path with no partial world change.

### Review the world and history

- Select Dungeon to inspect current state and drill into entities.
- Select Chronicle to search or filter records, then open an immutable consequence detail.

## Interaction and accessibility

- Preserve keyboard focus and visible focus rings; Return activates default sheet actions and Escape cancels when safe.
- Use native sidebar, toolbar, menu, form, search, date picker, confirmation, and share controls.
- Keep descriptive labels for completion buttons, dungeon scenes, values, and selection state.
- Respect system Reduce Motion plus the app override.
- Generated prose remains selectable.
- Color never carries state alone; symbols and labels accompany positive/negative cues.
- Destructive reset/delete actions retain explicit confirmation and consequence text.

## Initial-port acceptance criteria

1. The original iPhone target still builds and its unit tests pass.
2. A separate native macOS app target builds on this machine without third-party dependencies.
3. The Mac app launches into deterministic showcase data for local UI verification when the existing debug fixture environment is supplied.
4. Today, Dungeon, Chronicle, goal detail/editor, story result, onboarding, compatibility, and Settings are reachable and legible in a desktop window.
5. Goal and story domain behavior is shared with iPhone; the port does not fork persistence or resolution logic.
6. The authored normal, hazard, and recovery scenes render on Mac.
7. No sync or network behavior is introduced.

## Deferred beyond this port

- iPhone/Mac data sync or migration;
- multiple windows and document-style state restoration;
- menu-bar quick capture, widgets, global shortcuts, and drag and drop;
- Mac-specific notification-action extensions;
- App Store packaging and cross-device release operations.

