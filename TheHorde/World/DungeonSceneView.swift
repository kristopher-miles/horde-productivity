import SpriteKit
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct DungeonSceneView: View {
    nonisolated static let emberIdleFrameNames = (1...4).map { "ember-idle-\(String(format: "%02d", $0)).png" }
    nonisolated static let emberIdleFrameDuration = 0.18
    nonisolated static let emberConcernFrameNames = (1...4).map { "ember-concern-\(String(format: "%02d", $0)).png" }
    nonisolated static let emberConcernFrameDuration = 0.14
    nonisolated static let emberIdleFrameSize = CGSize(width: 96, height: 80)
    nonisolated static let emberIdleScenePosition = CGPoint(x: 24, y: -50)

    let world: WorldReadModel
    var cue: AnimationCue = .idle
    var accessibilityDescription: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("motionPreference") private var motionPreference = "system"

    var body: some View {
        SpriteView(scene: PixelDungeonScene(world: world, cue: cue, reduceMotion: motionPreference == "reduced" || (motionPreference == "system" && reduceMotion)), options: [.allowsTransparency])
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
        return "\(world.dungeonName). \(population) \(place) Morale \(world.snapshot.morale), integrity \(world.snapshot.integrity), food \(world.snapshot.food). \(thread.map { "Active concern: \($0.title), severity \($0.severity)." } ?? "There is no active concern.")"
    }

    nonisolated static func assetName(world: WorldReadModel, cue: AnimationCue) -> String {
        switch cue {
        case .celebrate, .recover, .resourceChanges: "DungeonRecovery"
        case .concern, .hazardAppears: "DungeonHazard"
        case .idle:
            if world.snapshot.activeThreads.contains(where: { $0.severity >= 2 }) { "DungeonHazard" }
            else if max(world.snapshot.morale, world.snapshot.integrity, world.snapshot.food) >= 55 { "DungeonRecovery" }
            else { "DungeonNormal" }
        }
    }
}

@MainActor final class PixelDungeonScene: SKScene {
    init(world: WorldReadModel, cue: AnimationCue, reduceMotion: Bool) {
        super.init(size: CGSize(width: 320, height: 180))
        scaleMode = .aspectFill
        backgroundColor = .black
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        let texture = SKTexture(imageNamed: DungeonSceneView.assetName(world: world, cue: cue))
        texture.filteringMode = .nearest
        let art = SKSpriteNode(texture: texture, size: size)
        addChild(art)
        addEmber(cue: cue, reduceMotion: reduceMotion)
        if !reduceMotion { animate(cue, art: art) }
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

    private func addEmber(cue: AnimationCue, reduceMotion: Bool) {
        let concerned = cue == .concern || cue == .hazardAppears
        let atlas = SKTextureAtlas(named: concerned ? "EmberConcern" : "EmberIdle")
        let names = concerned ? DungeonSceneView.emberConcernFrameNames : DungeonSceneView.emberIdleFrameNames
        let frames = names.map { name in
            let texture = atlas.textureNamed(name)
            texture.filteringMode = .nearest
            return texture
        }
        let ember = SKSpriteNode(texture: concerned && reduceMotion ? frames[3] : frames[0], size: DungeonSceneView.emberIdleFrameSize)
        ember.name = "EmberPrototype"
        ember.anchorPoint = CGPoint(x: 0.5, y: 0)
        ember.position = DungeonSceneView.emberIdleScenePosition
        ember.zPosition = 1
        addChild(ember)
        if !reduceMotion && cue == .idle {
            ember.run(.repeatForever(.animate(with: frames, timePerFrame: DungeonSceneView.emberIdleFrameDuration, resize: false, restore: false)), withKey: "idle")
        } else if !reduceMotion && concerned {
            ember.run(.animate(with: frames, timePerFrame: DungeonSceneView.emberConcernFrameDuration, resize: false, restore: false), withKey: "concern")
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
