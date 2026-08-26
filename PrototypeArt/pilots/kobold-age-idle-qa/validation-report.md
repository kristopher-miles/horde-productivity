# NPC-03 Kobold Age Idle Validation

Validated: 2026-08-26

## Contract gates

- Baby, Kid, and Adult each provide a reusable frame-01 model plus exactly four ordered idle frames on a shared transparent RGBA `48x64` canvas.
- Every frame has binary alpha `{0, 255}`, a single connected sprite component, approved palette membership, at least a two-pixel inset, bottom-center anchor `(0.5, 0)`, and planted baseline y `62`.
- Occupied frame-01 heights are strictly increasing: Baby `39`, Kid `49`, Adult `60` pixels. Baby uses a larger relative head and shorter limbs; Kid proportions are intermediate; Adult is the approved canonical master.
- All twelve frames contain the four authored brown/orange body tones and the three separate gray/cream clothing tones reserved for later NPC-04 recoloring. No runtime recoloring was added here.
- Each manifest identifies frame 01 as its Reduce Motion still. Each preview contains four `200 ms` frames and loops.

## Source and runtime gates

- Pixelorama v1.2.1 reports `(48, 64)` and `4` frames for all three `.pxo` sources. Known dummy-renderer shader warnings occurred, but every requested value printed and every process exited successfully.
- Each source contains one visible raster layer named exactly `Baby`, `Kid`, or `Adult`, an `idle` tag spanning frames 1–4, `fps=5.0`, one cel per frame, the 32-color project palette, and stored RGBA payloads byte-identical to normalized PNGs.
- `KoboldBabyIdle.atlas`, `KoboldKidIdle.atlas`, and `KoboldAdultIdle.atlas` each contain four runtime PNGs byte-identical to their normalized source frames.
- The focused SpriteKit qualification loads every age through `DungeonSceneView.koboldIdleAtlasName`, verifies deterministic frame names and `48x64` size, assigns nearest filtering, constructs a bottom-center node at integer coordinates, runs a keyed repeating idle action, and constructs a frame-01 Reduce Motion still with no action.
- No kobold node, placement, color transform, room background, or renderer selection was added to `PixelDungeonScene`.

## Native visual and five-room gate

The three model frames and every four-frame contact/preview were inspected at native scene scale and nearest-neighbor zoom. All ages retain the same species identity, right-facing posture, attached curled tail, readable cream eye/blink, neutral tunic, grounded baseline, and restrained loop. There is no translation, scale pop, detached effect, clipping, or role-specific accessory.

`kobold-age-idle-3x5-matrix.png` independently composites frame 01 for each exact visible label—Baby, Kid, Adult—at integer bottom-center point `(160, 40)` over all five committed character-free dungeon progression backgrounds. All fifteen cells remain readable and unclipped without installing those backgrounds into normal runtime selection.

## Automated verification

- Full PrototypeArt tooling suite: `11` tests passed.
- All three manifest validators: passed.
- Focused iPhone 17 Pro SpriteKit qualification: `1` test passed.
- Full iOS unit target: `149` tests passed, `0` failed, `0` skipped (`156` parameterized invocations reported by the device configuration).
- iOS Simulator `TheHorde` build: passed, including all three compiled texture atlases.
- Native arm64 `TheHordeMac` build: passed, including all three compiled texture atlases.
- `git diff --check`: passed.

## Artifact hashes

| Artifact | SHA-256 |
| --- | --- |
| `kobold-baby-idle/normalized/kobold-baby-idle-01.png` | `8496b7a0b3467f6814419623a9786acf2645a7207b5a50b8fb60e09bad42745f` |
| `kobold-baby-idle/normalized/kobold-baby-idle-02.png` | `828529cb9495fc65bf0488544b7d3dd2b40772095b55807ed63c046d99b62523` |
| `kobold-baby-idle/normalized/kobold-baby-idle-03.png` | `2b9277ee1ba37a83dbe4c5a33599077d34b36a407642732f6a86477db137a0b4` |
| `kobold-baby-idle/normalized/kobold-baby-idle-04.png` | `79790c362c86bc3fa5953d38792dcbb720a76456c51e4cd25b9741dc7a74d92a` |
| `kobold-baby-idle/kobold-baby-idle.pxo` | `71571c1ce337cf4dea1caec727023775029f7df99d7b87b44da6caf2caf342e0` |
| `kobold-kid-idle/normalized/kobold-kid-idle-01.png` | `21377b029b15e3f740a2fe0c86477b7862cb595694c41cdc3fc7992149a3b6b9` |
| `kobold-kid-idle/normalized/kobold-kid-idle-02.png` | `7b43cc672acaa1093330a13b5ee9df1569c84d1155b4ae08728c29273dd8f3d5` |
| `kobold-kid-idle/normalized/kobold-kid-idle-03.png` | `b4eb145d262c368b1f04848831667ab2ec939bbba978d24463970af459a0a376` |
| `kobold-kid-idle/normalized/kobold-kid-idle-04.png` | `a466ddd78cda746bc203a25630da67a4b89df998a87a504a29eb57707e7c024c` |
| `kobold-kid-idle/kobold-kid-idle.pxo` | `e668a93d39cebf572883310937c300e668a86e2517922397e5d6eefceb55570e` |
| `kobold-adult-idle/normalized/kobold-adult-idle-01.png` | `cdb375cd8f4662b80202f416303d40987f6ba6e6488d495a54db462bcd9c7a0b` |
| `kobold-adult-idle/normalized/kobold-adult-idle-02.png` | `48b541c7eb2c73f9f9da9df05a1b96c98cb4185859e4f67d2dbdea2011011167` |
| `kobold-adult-idle/normalized/kobold-adult-idle-03.png` | `2d2a978f2f5dfdebf806c355f2ede6ea2f34e2dbfc942a4eb65ad509b9aee7c7` |
| `kobold-adult-idle/normalized/kobold-adult-idle-04.png` | `9a1a024149f0ba3c64f5faa677f2a72cff01c7fcab0ac96551e75befbd7d7be8` |
| `kobold-adult-idle/kobold-adult-idle.pxo` | `9100e2713126978d151f242a10b913bd05a48d60b0a2bcc0198d87c274325686` |
| `kobold-age-idle-qa/kobold-age-idle-3x5-matrix.png` | `55a0e6b8375a854c14b3866d9742b63748683f053ef786bcf481d2104af29ccd` |
