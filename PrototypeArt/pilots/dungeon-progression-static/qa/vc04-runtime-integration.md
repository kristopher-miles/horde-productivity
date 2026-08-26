# VC-04 Runtime Integration

Integrated: 2026-08-26

The five approved, creature-free environment frames are installed byte-for-byte as lossless 1x runtime image sets. Their visual inspection and empty-environment source checks remain recorded in [`vc02-creature-audit.md`](vc02-creature-audit.md).

| Saved `backgroundStage` | Runtime asset | Pilot source and runtime filename | SHA-256 |
| --- | --- | --- | --- |
| 1 | `DungeonStage1` | `dungeon-progression-static-01.png` | `528c9cba31339b414ab14a6b05bc7944b491875d5df9abcb473202d20e62ab29` |
| 2 | `DungeonStage2` | `dungeon-progression-static-02.png` | `82232a85ff552e0c291d03f065e539eae99497eea591d6ad030e106630e4d5fc` |
| 3 | `DungeonStage3` | `dungeon-progression-static-03.png` | `a2732bd6e8bb609a09022bbe0f0f7229ff1bba581e16badfa63e6d3a80e7ce91` |
| 4 | `DungeonStage4` | `dungeon-progression-static-04.png` | `c6aa3cdbd10746f871ba6fd5ea8d5be0b4bf0955e0a8e1f1b5e6fb7c770918a0` |
| 5 | `DungeonStage5` | `dungeon-progression-static-05.png` | `4420b950c259e92a173e474ba5a8e8520b37a8dc2aae9a1ad0e567fb1e131b64` |

Each source/runtime pair has identical file bytes, is opaque RGBA `320x180`, and is selected only from the saved world's computed `snapshot.backgroundStage`. `PixelDungeonScene` names the selected node `DungeonEnvironment`, renders it at `320x180`, and applies nearest-neighbor texture filtering. Transient cues animate that node without participating in asset selection or mutating the saved world.

## Consumer audit

| Surface | World supplied to the shared scene |
| --- | --- |
| Onboarding | The initial named `WorldSnapshot` (Stage 1, zero residents) |
| Today | `app.world` |
| Dungeon | `app.world` |
| Staged resolution | `app.world` (the saved world remains uncommitted) |
| Chronicle detail | `entry.recordedWorld`, not current/default world |

No consumer-specific stage mapping exists. Population does not participate in background selection, so the same saved stage renders with zero or many residents.

## Removed legacy bundles

The following obsolete creature-bearing image sets were removed from the runtime catalog:

- `DungeonNormal.imageset` (`dungeon-normal.png`, SHA-256 `11f02096410fa8f873e50d4f4bdfd6387b29e0d3a0b4d106c09937461aa48a6e`)
- `DungeonHazard.imageset` (`dungeon-hazard.png`, SHA-256 `89d68380286f739f09be9075b5866732a43b267ba8e0c492bc4bab8dd18b8a47`)
- `DungeonRecovery.imageset` (`dungeon-recovery.png`, SHA-256 `442e9360903fa212b144fe758d4403524fb151dae9ba73522179ba52729032f6`)

`test_runtime_environment_assets.py` guards exact source equality, hash provenance, opacity, dimensions, lossless catalog metadata, the five-only runtime family, and continued linkage to the VC-02 no-creature audit. Swift scene tests guard runtime loading, nearest filtering, stage/cue independence, zero-resident rendering, population invariance, and recorded Chronicle stage selection.

## Verification run

- Runtime environment asset tests: 3 passed.
- Full `PrototypeArt/scripts/tests` suite: 14 passed.
- Frame validator: pass for dimensions, opacity, anchor, inset, and palette contracts.
- Pixelorama v1.2.1 reopen: `(320, 180)` and `5` frames; only the documented dummy-renderer shader warnings were emitted.
- Focused scene/product tests: 56 passed.
- Full unit suite: 158 tests passed (165 parameterized test runs), zero failures or skips.
- Affected UI flows: clean/populated presentation, transient cue invariance, Chronicle recorded-world replay, and onboarding Stage 1 each passed. The onboarding run was isolated on clean simulator app data after the combined run inherited an already-onboarded fixture.
- iOS Simulator and native macOS app builds: succeeded; the compiled iOS asset catalog reports all five stages as opaque 1x `320x180` renditions.
- `git diff --check`: clean.
