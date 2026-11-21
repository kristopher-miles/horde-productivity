import SpriteKit
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct DungeonSceneView: View {
    nonisolated static let emberIdleFrameDuration = 0.18
    nonisolated static let koboldIdleFrameDuration = 0.2
    nonisolated static let emberConcernFrameNames = (1...4).map { "ember-concern-\(String(format: "%02d", $0)).png" }
    nonisolated static let emberConcernFrameDuration = 0.14
    nonisolated static let emberIdleScenePosition = CGPoint(x: 24, y: -50)
    nonisolated static let koboldFrameSize = CGSize(width: 48, height: 64)
    nonisolated static let koboldScenePositions = [
        CGPoint(x: -128, y: 26), CGPoint(x: -88, y: 26),
        CGPoint(x: 96, y: 26), CGPoint(x: 128, y: 26),
        CGPoint(x: -128, y: -88), CGPoint(x: -88, y: -88),
        CGPoint(x: 96, y: -88), CGPoint(x: 128, y: -88)
    ]

    nonisolated static func dragonIdleFrameNames(stage: DragonStage) -> [String] {
        let prefix = switch stage {
        case .baby: "ember-idle"
        case .adolescent: "ember-adolescent-idle"
        case .adult: "ember-adult-idle"
        case .elder: "ember-elder-idle"
        case .greatWyrm: "ember-great-wyrm-idle"
        }
        return (1...4).map { "\(prefix)-\(String(format: "%02d", $0)).png" }
    }

    nonisolated static func dragonFrameSize(stage: DragonStage) -> CGSize {
        switch stage {
        case .baby: CGSize(width: 96, height: 80)
        case .adolescent: CGSize(width: 108, height: 90)
        case .adult: CGSize(width: 120, height: 100)
        case .elder: CGSize(width: 132, height: 110)
        case .greatWyrm: CGSize(width: 144, height: 120)
        }
    }

    let world: WorldReadModel
    var cue: AnimationCue = .idle
    var accessibilityDescription: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("motionPreference") private var motionPreference = "system"

    var body: some View {
        SpriteView(scene: PixelDungeonScene(world: world, cue: cue, reduceMotion: motionPreference == "reduced" || (motionPreference == "system" && reduceMotion)), options: [.allowsTransparency])
            .id(world.snapshot.dragonVisual.color)
            .aspectRatio(16 / 9, contentMode: .fit)
            .background(DesignTokens.dungeon)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radius))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDescription ?? Self.sceneDescription(for: world))
            .accessibilityIdentifier("DungeonScene.\(Self.assetName(world: world, cue: cue))")
    }

    nonisolated static func sceneDescription(for world: WorldReadModel) -> String {
        let thread = world.snapshot.activeThreads.first
        let population = world.snapshot.residents.isEmpty
            ? "\(world.snapshot.dragon.name) is alone"
            : "\(world.snapshot.dragon.name) and \(world.snapshot.residents.count) kobolds are gathered"
        let place = world.snapshot.locations.first.map { "in \($0.name). \($0.status). \($0.summary)" } ?? "in an unmapped cavern."
        return "\(world.dungeonName). \(population). \(world.snapshot.dragon.role). \(world.snapshot.dragon.identity) \(place) Morale \(world.snapshot.morale), integrity \(world.snapshot.integrity), food \(world.snapshot.food). \(thread.map { "Active concern: \($0.title), severity \($0.severity)." } ?? "There is no active concern.")"
    }

    nonisolated static func dragonAtlasName(stage: DragonStage, cue: AnimationCue) -> String {
        if stage == .baby, cue == .concern || cue == .hazardAppears { return "EmberConcern" }
        return switch stage {
        case .baby: "EmberIdle"
        case .adolescent: "EmberAdolescentIdle"
        case .adult: "EmberAdultIdle"
        case .elder: "EmberElderIdle"
        case .greatWyrm: "EmberGreatWyrmIdle"
        }
    }

    nonisolated static func koboldIdleAtlasName(age: KoboldAgeStage) -> String {
        switch age {
        case .baby: "KoboldBabyIdle"
        case .kid: "KoboldKidIdle"
        case .adult: "KoboldAdultIdle"
        }
    }

    nonisolated static func koboldIdleFrameNames(age: KoboldAgeStage) -> [String] {
        (1...4).map { "kobold-\(age.rawValue)-idle-\(String(format: "%02d", $0)).png" }
    }

    nonisolated static func koboldNodeName(residentID: String) -> String {
        "Kobold.\(residentID)"
    }

    nonisolated static func assetName(world: WorldReadModel, cue _: AnimationCue) -> String {
        "DungeonStage\(world.snapshot.backgroundStage.rawValue)"
    }

    nonisolated static func renderedBackgroundAssetName(world: WorldReadModel, cue: AnimationCue) -> String? {
        assetName(world: world, cue: cue)
    }
}

@MainActor final class PixelDungeonScene: SKScene {
    init(world: WorldReadModel, cue: AnimationCue, reduceMotion: Bool) {
        super.init(size: CGSize(width: 320, height: 180))
        scaleMode = .aspectFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        let art = DungeonSceneView.renderedBackgroundAssetName(world: world, cue: cue).map { assetName in
            let texture = SKTexture(imageNamed: assetName)
            texture.filteringMode = .nearest
            let node = SKSpriteNode(texture: texture, size: size)
            node.name = "DungeonEnvironment"
            addChild(node)
            return node
        }
        backgroundColor = art == nil ? .clear : .black
        addEmber(world: world, cue: cue, reduceMotion: reduceMotion)
        addKobolds(world: world, reduceMotion: reduceMotion)
        if !reduceMotion, let art { animate(cue, art: art) }
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(pauseForBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resumeFromBackground), name: UIApplication.willEnterForegroundNotification, object: nil)
        #else
        NotificationCenter.default.addObserver(self, selector: #selector(pauseForBackground), name: NSApplication.didResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resumeFromBackground), name: NSApplication.didBecomeActiveNotification, object: nil)
        #endif
    }

    required init?(coder: NSCoder) { nil }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func pauseForBackground() { isPaused = true }
    @objc private func resumeFromBackground() { isPaused = false }

    private func addEmber(world: WorldReadModel, cue: AnimationCue, reduceMotion: Bool) {
        let stage = world.snapshot.dragonVisual.stage
        let concerned = stage == .baby && (cue == .concern || cue == .hazardAppears)
        let atlasName = DungeonSceneView.dragonAtlasName(stage: stage, cue: cue)
        let atlas = SKTextureAtlas(named: atlasName)
        let names = concerned ? DungeonSceneView.emberConcernFrameNames : DungeonSceneView.dragonIdleFrameNames(stage: stage)
        let frames = names.map { name in
            let texture = DragonTextureRecolorer.texture(
                atlas.textureNamed(name),
                color: world.snapshot.dragonVisual.color
            )
            texture.filteringMode = .nearest
            return texture
        }
        let ember = SKSpriteNode(texture: concerned && reduceMotion ? frames[3] : frames[0], size: DungeonSceneView.dragonFrameSize(stage: stage))
        ember.name = "EmberPrototype"
        ember.anchorPoint = CGPoint(x: 0.5, y: 0)
        ember.position = DungeonSceneView.emberIdleScenePosition
        ember.zPosition = 1
        addChild(ember)
        if !reduceMotion && (!concerned && (stage != .baby || cue == .idle)) {
            ember.run(.repeatForever(.animate(with: frames, timePerFrame: DungeonSceneView.emberIdleFrameDuration, resize: false, restore: false)), withKey: "idle")
        } else if !reduceMotion && concerned {
            ember.run(.animate(with: frames, timePerFrame: DungeonSceneView.emberConcernFrameDuration, resize: false, restore: false), withKey: "concern")
        }
    }

    private func addKobolds(world: WorldReadModel, reduceMotion: Bool) {
        // Resident order is the stable scene-slot contract: additions append and removals pop the tail.
        let residents = world.snapshot.residents.compactMap { resident in
            resident.koboldVisual.map { (resident, $0) }
        }.prefix(DungeonSceneView.koboldScenePositions.count)
        for (index, entry) in residents.enumerated() {
            let (resident, visual) = entry
            let atlas = SKTextureAtlas(named: DungeonSceneView.koboldIdleAtlasName(age: visual.age))
            let frames = DungeonSceneView.koboldIdleFrameNames(age: visual.age).map { name in
                let texture = KoboldTextureRecolorer.texture(atlas.textureNamed(name), palette: visual.colors)
                texture.filteringMode = .nearest
                return texture
            }
            let kobold = SKSpriteNode(texture: frames[0], size: DungeonSceneView.koboldFrameSize)
            kobold.name = DungeonSceneView.koboldNodeName(residentID: resident.id)
            kobold.anchorPoint = CGPoint(x: 0.5, y: 0)
            kobold.position = DungeonSceneView.koboldScenePositions[index]
            kobold.zPosition = index < 4 ? 0.75 : 1.25
            addChild(kobold)
            if !reduceMotion {
                kobold.run(
                    .repeatForever(.animate(with: frames, timePerFrame: DungeonSceneView.koboldIdleFrameDuration)),
                    withKey: "idle"
                )
            }
        }
    }

    private func animate(_ cue: AnimationCue, art: SKNode) {
        switch cue {
        case .celebrate: art.run(.sequence([.scale(to: 1.025, duration: 0.18), .scale(to: 1, duration: 0.24)]))
        case .concern, .hazardAppears: art.run(.sequence([.moveBy(x: -2, y: 0, duration: 0.12), .moveBy(x: 4, y: 0, duration: 0.18), .moveBy(x: -2, y: 0, duration: 0.12)]))
        case .recover, .resourceChanges: art.run(.sequence([.fadeAlpha(to: 0.72, duration: 0.18), .fadeAlpha(to: 1, duration: 0.28)]))
        case .idle: break
        }
    }
}

enum DragonTextureRecolorer {
    nonisolated static func bodyPixel(_ source: RGBColor, color: RGBColor) -> RGBColor {
        guard color != .ember else { return source }
        return switch source {
        case RGBColor(red: 107, green: 25, blue: 10): color.shade(offset: -0.24)
        case RGBColor(red: 163, green: 43, blue: 10): color.shade(offset: -0.12)
        case RGBColor(red: 217, green: 77, blue: 8): color.shade(offset: 0)
        case RGBColor(red: 242, green: 118, blue: 13): color.shade(offset: 0.12)
        case RGBColor(red: 255, green: 158, blue: 37): color.shade(offset: 0.24)
        default: source
        }
    }

    @MainActor static func texture(_ source: SKTexture, color: RGBColor) -> SKTexture {
        guard color != .ember else { return source }
        return TextureRecolorer.texture(source) { bodyPixel($0, color: color) }
    }
}

enum KoboldTextureRecolorer {
    nonisolated static func pixel(_ source: RGBColor, palette: CharacterPalette) -> RGBColor {
        switch source {
        case RGBColor(red: 81, green: 36, blue: 15): palette.primary.shade(offset: -0.18)
        case RGBColor(red: 117, green: 54, blue: 21): palette.primary.shade(offset: -0.06)
        case RGBColor(red: 166, green: 83, blue: 31): palette.primary.shade(offset: 0.08)
        case RGBColor(red: 208, green: 122, blue: 47): palette.primary.shade(offset: 0.22)
        case RGBColor(red: 106, green: 85, blue: 70): palette.secondary.shade(offset: -0.12)
        case RGBColor(red: 154, green: 122, blue: 91): palette.secondary.shade(offset: 0.04)
        case RGBColor(red: 208, green: 181, blue: 138): palette.secondary.shade(offset: 0.20)
        default: source
        }
    }

    @MainActor static func texture(_ source: SKTexture, palette: CharacterPalette) -> SKTexture {
        TextureRecolorer.texture(source) { pixel($0, palette: palette) }
    }
}

private enum TextureRecolorer {
    @MainActor static func texture(_ source: SKTexture, replacement: (RGBColor) -> RGBColor) -> SKTexture {
        let sourceImage = source.cgImage()
        let width = sourceImage.width
        let height = sourceImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let recoloredImage: CGImage? = pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else { return nil }
            context.interpolationQuality = .none
            context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            let channels = bytes.bindMemory(to: UInt8.self)
            for offset in stride(from: 0, to: channels.count, by: 4) where channels[offset + 3] == 255 {
                let color = replacement(RGBColor(red: channels[offset], green: channels[offset + 1], blue: channels[offset + 2]))
                channels[offset] = color.red
                channels[offset + 1] = color.green
                channels[offset + 2] = color.blue
            }
            return context.makeImage()
        }
        return recoloredImage.map(SKTexture.init(cgImage:)) ?? source
    }
}

private extension RGBColor {
    nonisolated func shade(offset: Double) -> RGBColor {
        let components = [Double(red) / 255, Double(green) / 255, Double(blue) / 255]
        let maximum = components.max()!
        let minimum = components.min()!
        let delta = maximum - minimum
        let saturation = maximum == 0 ? 0 : delta / maximum
        let hue: Double
        if delta == 0 {
            hue = 0
        } else if maximum == components[0] {
            hue = ((components[1] - components[2]) / delta).truncatingRemainder(dividingBy: 6) / 6
        } else if maximum == components[1] {
            hue = ((components[2] - components[0]) / delta + 2) / 6
        } else {
            hue = ((components[0] - components[1]) / delta + 4) / 6
        }
        let normalizedHue = hue < 0 ? hue + 1 : hue
        let brightness = 0.35 + maximum * 0.35 + offset
        let sector = normalizedHue * 6
        let chroma = brightness * saturation
        let secondary = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let match = brightness - chroma
        let rgb = switch sector {
        case 0..<1: [chroma, secondary, 0]
        case 1..<2: [secondary, chroma, 0]
        case 2..<3: [0, chroma, secondary]
        case 3..<4: [0, secondary, chroma]
        case 4..<5: [secondary, 0, chroma]
        default: [chroma, 0, secondary]
        }
        return RGBColor(
            red: UInt8(((rgb[0] + match) * 255).rounded()),
            green: UInt8(((rgb[1] + match) * 255).rounded()),
            blue: UInt8(((rgb[2] + match) * 255).rounded())
        )
    }
}
