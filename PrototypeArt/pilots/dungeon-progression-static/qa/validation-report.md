# Dungeon Progression Static Validation

Validated: 2026-08-26

## Source and extraction

- Selected raw source: `generated/dungeon-progression-static-family-attempt-02.png`, RGB `1672x941`.
- Generation grid: 3 columns × 2 rows, row-major.
- Rounded source x bounds: `0, 557, 1115, 1672`.
- Rounded source y bounds: `0, 470, 941`.
- Retained cells: 1–5. The solid-magenta sixth cell is ignored and has no output filename.
- Every cell is center-cropped to 16:9, resized once with nearest-neighbor sampling to `320x180`, and mapped to the project palette.
- Stage 1 then receives the bounded natural-wall/web donor cleanup documented in `decision.md` and `cleanup-stage1.py`.

## Deterministic gates

- Manifest parses as JSON and names exactly five unique ordered files.
- Project tooling tests: 11 passed, including five-cell scaffold construction, unmistakable magenta unused-cell marking, row-major extraction, ignored-cell exclusion, opaque-background validation, maximum-visible-color rejection, and Pixelorama environment-layer naming.
- Frame validator: pass for exact filename order/count, RGBA dimensions, opaque alpha, full-frame bounds, common origin, project-palette membership, and maximum visible colors.
- Pixelorama source: reports `(320, 180)` and `5` frames. Known dummy-renderer shader warnings were ignored only because both requested values printed and both commands exited successfully.
- Contact sheet: unlabeled RGBA `1616x180` at native 1x with four-pixel gaps.
- Timed preview: `320x180` GIF, 1200 ms per stage, non-looping family presentation.

| Frame | Dimensions | Alpha values | Visible colors | SHA-256 |
| --- | --- | --- | ---: | --- |
| `dungeon-progression-static-01.png` | `320x180` | `255` | 6 | `528c9cba31339b414ab14a6b05bc7944b491875d5df9abcb473202d20e62ab29` |
| `dungeon-progression-static-02.png` | `320x180` | `255` | 14 | `10cffade50f3176a929b0915d244ae7a9a872fd87455bf5a9b309addbb966714` |
| `dungeon-progression-static-03.png` | `320x180` | `255` | 21 | `3b52992ea51985b3a9f8e2b6f025f0e10dbdfd8dd98d6c3b35f84d6edae45ca2` |
| `dungeon-progression-static-04.png` | `320x180` | `255` | 21 | `b78136060c30c869a8eb552fb8874085cf6269dde4eb3ec772a64e12c95c52a3` |
| `dungeon-progression-static-05.png` | `320x180` | `255` | 32 | `4420b950c259e92a173e474ba5a8e8520b37a8dc2aae9a1ad0e567fb1e131b64` |

## Native visual gate

The five normalized frames and unlabeled contact sheet were inspected at original/native detail. Hard clusters remain crisp after palette mapping, no antialiasing or partial alpha is present, and large environmental forms remain legible. The sequence reads cold/empty → minimally claimed → settled/fortified → rich stronghold → vast golden fortress without labels. Stage 1 has no worked hearth or crest after cleanup; stage 5 has visible receding depth, side treasure overflow, and emerald/ruby/sapphire accents while retaining the central staging floor.

Runtime app resources and scene selection were intentionally not changed.
