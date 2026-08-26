#if DEBUG
import SpriteKit
import SwiftUI

struct KoboldPaletteFixtureView: View {
    struct FixturePalette: Identifiable, Sendable {
        let name: String
        let colors: CharacterPalette
        var id: String { name }
    }

    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["HORDE_KOBOLD_PALETTE_FIXTURE"] == "1"
    }

    nonisolated static let palettes = [
        FixturePalette(
            name: "Cinder & Iron",
            colors: CharacterPalette(
                primary: RGBColor(red: 193, green: 67, blue: 36),
                secondary: RGBColor(red: 68, green: 91, blue: 128)
            )
        ),
        FixturePalette(
            name: "Moss & Gold",
            colors: CharacterPalette(
                primary: RGBColor(red: 57, green: 134, blue: 82),
                secondary: RGBColor(red: 196, green: 149, blue: 42)
            )
        ),
        FixturePalette(
            name: "Moon & Plum",
            colors: CharacterPalette(
                primary: RGBColor(red: 58, green: 107, blue: 190),
                secondary: RGBColor(red: 145, green: 69, blue: 160)
            )
        )
    ]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("motionPreference") private var motionPreference = "system"

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Kobold Palettes").font(.largeTitle.bold())
                ForEach(KoboldAgeStage.allCases, id: \.rawValue) { age in
                    Text(age.rawValue.capitalized).font(.title2.bold())
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(Self.palettes) { palette in
                            VStack(spacing: 4) {
                                SpriteView(
                                    scene: KoboldPaletteScene(
                                        age: age,
                                        palette: palette.colors,
                                        reduceMotion: motionPreference == "reduced" || (motionPreference == "system" && reduceMotion)
                                    ),
                                    options: [.allowsTransparency]
                                )
                                .frame(width: 48, height: 64)
                                Text(palette.name).font(.caption)
                            }
                            .accessibilityIdentifier("KoboldPaletteFixture.\(age.rawValue).\(palette.id)")
                        }
                    }
                }
            }
            .padding()
        }
        .accessibilityIdentifier("KoboldPaletteFixture")
    }
}

@MainActor final class KoboldPaletteScene: SKScene {
    init(age: KoboldAgeStage, palette: CharacterPalette, reduceMotion: Bool) {
        super.init(size: CGSize(width: 48, height: 64))
        scaleMode = .aspectFit
        backgroundColor = .clear

        let atlas = SKTextureAtlas(named: DungeonSceneView.koboldIdleAtlasName(age: age))
        let frames = DungeonSceneView.koboldIdleFrameNames(age: age).map { name in
            let texture = KoboldTextureRecolorer.texture(atlas.textureNamed(name), palette: palette)
            texture.filteringMode = .nearest
            return texture
        }
        let kobold = SKSpriteNode(texture: frames[0], size: size)
        kobold.name = "KoboldPalettePrototype"
        kobold.anchorPoint = CGPoint(x: 0.5, y: 0)
        kobold.position = CGPoint(x: 24, y: 0)
        addChild(kobold)
        if !reduceMotion {
            kobold.run(
                .repeatForever(.animate(with: frames, timePerFrame: DungeonSceneView.koboldIdleFrameDuration)),
                withKey: "idle"
            )
        }
    }

    required init?(coder: NSCoder) { nil }
}
#endif
