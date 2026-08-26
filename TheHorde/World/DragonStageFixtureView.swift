#if DEBUG
import SwiftUI

struct DragonStageFixtureView: View {
    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["HORDE_DRAGON_STAGE_FIXTURE"] == "1"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Dragon Stages").font(.largeTitle.bold())
                Text("Five rooms × five stages").font(.title2.bold())
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(DragonStage.allCases, id: \.rawValue) { stage in
                            VStack(spacing: 8) {
                                Text(stage.displayName).font(.headline)
                                ForEach(Self.rooms, id: \.stage.rawValue) { room in
                                    VStack(spacing: 3) {
                                        Text("Room \(room.stage.rawValue)").font(.caption)
                                        DungeonSceneView(world: world(stage: stage, hoard: room.hoard))
                                            .frame(width: 160, height: 90)
                                    }
                                    .accessibilityElement(children: .contain)
                                    .accessibilityIdentifier("RoomDragonFixture.\(room.stage.rawValue).\(stage.rawValue)")
                                }
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("DragonStageFixture.\(stage.rawValue)")
                        }
                    }
                }
                Text("Dragon Recolors").font(.title2.bold())
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(CuratedDragonColor.allCases) { color in
                            VStack(spacing: 4) {
                                DungeonSceneView(world: world(stage: .greatWyrm, color: color.color))
                                    .frame(width: 160, height: 90)
                                Text(color.name).font(.caption)
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("DragonColorFixture.\(color.rawValue)")
                        }
                    }
                }
            }
            .padding()
        }
        .accessibilityIdentifier("DragonStageFixture")
    }

    nonisolated private static let rooms: [(stage: DungeonBackgroundStage, hoard: Int)] = [
        (.one, 0), (.two, 10), (.three, 30), (.four, 60), (.five, 100)
    ]

    private func world(stage: DragonStage, hoard: Int = 0, color: RGBColor = .ember) -> WorldReadModel {
        var snapshot = WorldSnapshot.initial()
        snapshot.dragonVisual.stage = stage
        snapshot.dragonVisual.color = color
        snapshot.hoard = hoard
        snapshot.residents = []
        return WorldReadModel(dungeonName: "The Cinder Vault", revision: 0, snapshot: snapshot)
    }
}
#endif
