#if DEBUG
import SwiftUI

struct DragonStageFixtureView: View {
    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["HORDE_DRAGON_STAGE_FIXTURE"] == "1"
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                Text("Dragon Stages").font(.largeTitle.bold())
                ForEach(DragonStage.allCases, id: \.rawValue) { stage in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(stage.displayName).font(.title2.bold())
                        DungeonSceneView(world: world(stage))
                    }
                    .accessibilityIdentifier("DragonStageFixture.\(stage.rawValue)")
                }
            }
            .padding()
        }
        .accessibilityIdentifier("DragonStageFixture")
    }

    private func world(_ stage: DragonStage) -> WorldReadModel {
        var snapshot = WorldSnapshot.initial()
        snapshot.dragonVisual.stage = stage
        return WorldReadModel(dungeonName: "The Cinder Vault", revision: 0, snapshot: snapshot)
    }
}
#endif
