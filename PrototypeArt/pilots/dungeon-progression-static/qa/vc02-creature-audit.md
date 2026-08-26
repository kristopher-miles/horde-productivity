# VC-02 Empty-Environment Audit

Audited: 2026-08-26

Scope: the five full `320x180` backgrounds, their unlabeled contact sheet and timed preview, and `dungeon-progression-static.pxo`. Review was performed at native size and at 4x and 12x nearest-neighbor zoom. The three fireplace crests in stages 2–4 initially contained readable dragon-like heraldic silhouettes; `cleanup-vc02.py` replaces only their interiors with plain project-palette metal.

## Frame inspection matrix

| Frame | Back wall and upper architecture | Side zones and props | Floor and staging area | Result |
| --- | --- | --- | --- | --- |
| `-01` | Raw rock, cracks, and web strands; no face or body-like silhouette | Loose rock and cave walls; no fauna, figure, statue, or settlement character | Bare damp floor remains empty | Pass: valid empty natural environment |
| `-02` | Fireplace shield interior `(95,4)–(112,27)` is now plain metal; masonry and dark alcoves contain no figure | Bedroll, niche, stool, and tree-like cave supports are inanimate props/rock | Unlit fire ring and open floor contain no creature | Pass: valid empty primitive environment |
| `-03` | Fireplace shield interior `(89,3)–(109,29)` is now plain metal; shelf shapes are vessels and supplies, not faces | Lantern, shelving, bedroll, table, and timber supports contain no figure | Hearth flame and open circular floor contain no creature | Pass: valid empty settled environment |
| `-04` | Fireplace shield interior `(98,3)–(118,29)` is now plain metal; wall hangings are nonfigurative geometry | Braziers, chests, shelves, columns, and vessels contain no figure | Hearth/brazier flames and open rug contain no creature | Pass: valid empty stronghold environment |
| `-05` | Receding arches and upper shelf vessel contain no face or body silhouette | Chests, vessels, coins, ingots, and angular colored gemstones contain no animal or monster silhouette | Open rug and treasure-strewn floor contain no creature | Pass: valid empty fortress environment |

The regenerated unlabeled contact sheet was reviewed end to end at native `1616x180` and nearest-neighbor zoom. It contains the same five clean standalone frames with four-pixel separators and no labels or added character pixels. The preview contains the same five frames in the same order at `1200 ms` each; its GIF loop metadata is `1`, matching the repository renderer for manifest `loop: false`.

## Source and standalone-environment checks

- `dungeon-progression-static.pxo` is `320x180`, contains five frames, and has exactly one visible, fully opaque raster layer named `Environment`.
- The source has no character, dragon, kobold, resident, creature, foreground, or hidden layer. Every frame has one cel, and each stored RGBA payload is byte-identical to its corresponding normalized PNG.
- Each standalone PNG is RGBA `320x180`, alpha is exclusively `255`, uses only the approved project palette, and fills the complete scene. With no runtime character sprites rendered—or with every hypothetical character layer hidden—the PNG itself remains a complete, valid empty environment.
- No runtime/app resource, progression selection, composition, camera, or staging geometry was changed for VC-02.

## Artifact hashes

| Artifact | SHA-256 |
| --- | --- |
| `normalized/dungeon-progression-static-01.png` | `528c9cba31339b414ab14a6b05bc7944b491875d5df9abcb473202d20e62ab29` |
| `normalized/dungeon-progression-static-02.png` | `82232a85ff552e0c291d03f065e539eae99497eea591d6ad030e106630e4d5fc` |
| `normalized/dungeon-progression-static-03.png` | `a2732bd6e8bb609a09022bbe0f0f7229ff1bba581e16badfa63e6d3a80e7ce91` |
| `normalized/dungeon-progression-static-04.png` | `c6aa3cdbd10746f871ba6fd5ea8d5be0b4bf0955e0a8e1f1b5e6fb7c770918a0` |
| `normalized/dungeon-progression-static-05.png` | `4420b950c259e92a173e474ba5a8e8520b37a8dc2aae9a1ad0e567fb1e131b64` |
| `qa/dungeon-progression-static-contact-sheet.png` | `89c68424d6a4272cbc99c0528f20ba501d62fe84a7dca7abdd3d39723914077c` |
| `qa/dungeon-progression-static-preview.gif` | `72b9637d83f11617aef4266dff30ff036fe411d43cd8dfe3380125676b3e5870` |
| `dungeon-progression-static.pxo` | `4a745f2be8df09c16ca5115b5669139ed008b34ae5ee7d0b55c34d7e61c70d06` |
