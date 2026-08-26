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
- Stages 2–4 receive the bounded VC-02 cleanup in `cleanup-vc02.py`: only the three dragon-like fireplace-shield emblems are replaced with plain native-pixel metal.

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
| `dungeon-progression-static-02.png` | `320x180` | `255` | 13 | `82232a85ff552e0c291d03f065e539eae99497eea591d6ad030e106630e4d5fc` |
| `dungeon-progression-static-03.png` | `320x180` | `255` | 21 | `a2732bd6e8bb609a09022bbe0f0f7229ff1bba581e16badfa63e6d3a80e7ce91` |
| `dungeon-progression-static-04.png` | `320x180` | `255` | 21 | `c6aa3cdbd10746f871ba6fd5ea8d5be0b4bf0955e0a8e1f1b5e6fb7c770918a0` |
| `dungeon-progression-static-05.png` | `320x180` | `255` | 32 | `4420b950c259e92a173e474ba5a8e8520b37a8dc2aae9a1ad0e567fb1e131b64` |

## Native visual gate

The five normalized frames and unlabeled contact sheet were inspected individually at original/native detail and at 4x and 12x nearest-neighbor zoom. Hard clusters remain crisp after palette mapping, no antialiasing or partial alpha is present, and large environmental forms remain legible. The sequence reads cold/empty → minimally claimed → settled/fortified → rich stronghold → vast golden fortress without labels. Stage 1 has no worked hearth or crest after cleanup; the stage 2–4 shields are plain and no longer contain creature-like heraldry; stage 5's colored clusters read as faceted gemstones and its upper ornament as a vessel. No dragon, kobold, person, animal, monster, face, statue, or other living-character silhouette remains in any frame.

The complete normalize → stage-1 cleanup → VC-02 cleanup → QA render → Pixelorama package sequence was rerun in an isolated temporary directory. All five PNGs, the contact sheet, preview GIF, and `.pxo` compared byte-for-byte with the retained artifacts.

Runtime app resources and scene selection were intentionally not changed.
