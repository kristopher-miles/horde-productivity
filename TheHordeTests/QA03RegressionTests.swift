import Foundation
import Testing
@testable import TheHorde

enum QA03Contract {
    static let prohibitedPromptCushioning = [
        "gentle", "harmless", "modest", "calm", "recoverable",
        "slight", "minor", "mild", "little", "small"
    ]
}

@Suite("QA-03 product contract tripwires")
struct QA03RegressionTests {
    @Test func newAndResetWorldsUseTheExactEmptyStart() async throws {
        assertEmptyStart(WorldSnapshot.initial())
        assertEmptyStart(try PersistentJSON.decode(WorldSnapshot.self, from: GameSaveRecord().worldData))

        let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        try await store.completeOnboarding(dragonName: "Cinder", dungeonName: "The Cinder Vault")
        let developed = try #require(ProductVerificationFixture.named("populated"))
        try await store.installWorldFixture(developed.world.snapshot, dungeonName: developed.world.dungeonName, revision: developed.world.revision)
        try await store.resetDungeon()
        assertEmptyStart(try await store.worldReadModel().snapshot)
    }

    @Test func verificationFixturesSeparateCleanTransientAndDevelopedWorlds() throws {
        let normal = try #require(ProductVerificationFixture.named("normal"))
        let hazard = try #require(ProductVerificationFixture.named("hazard"))
        let recovery = try #require(ProductVerificationFixture.named("recovery"))
        let showcase = try #require(ProductVerificationFixture.named("showcase"))
        let populated = try #require(ProductVerificationFixture.named("populated"))

        assertEmptyStart(normal.world.snapshot)
        for fixture in [hazard, recovery] {
            let snapshot = fixture.world.snapshot
            let knownIDs = Set([snapshot.dragon.id] + snapshot.residents.map(\.id) + snapshot.locations.map(\.id))
            #expect(snapshot.residents.isEmpty)
            #expect(snapshot.facts.isEmpty)
            #expect([snapshot.morale, snapshot.integrity, snapshot.food].allSatisfy { $0 != 50 })
            #expect(snapshot.activeThreads.allSatisfy { Set($0.involvedEntityIDs).isSubset(of: knownIDs) })
        }
        #expect(hazard.world.snapshot.activeThreads.count == 1)
        #expect(recovery.world.snapshot.activeThreads.isEmpty)

        #expect(showcase.world.snapshot.residents.isEmpty)
        #expect(showcase.chronicle.allSatisfy { $0.effort != nil && !($0.acceptedAction ?? "").isEmpty })
        for obsolete in ["Pip", "Rill", "Moss", "household"] {
            #expect(showcase.chronicle.allSatisfy { !$0.finalProse.localizedCaseInsensitiveContains(obsolete) })
        }

        let developed = populated.world.snapshot
        let knownIDs = Set([developed.dragon.id] + developed.residents.map(\.id) + developed.locations.map(\.id))
        #expect(!developed.residents.isEmpty)
        #expect(developed.residents.allSatisfy { $0.koboldVisual != nil })
        #expect(!developed.facts.isEmpty)
        #expect(!developed.activeThreads.isEmpty)
        #expect(developed.activeThreads.allSatisfy { Set($0.involvedEntityIDs).isSubset(of: knownIDs) })
        #expect([developed.morale, developed.integrity, developed.food].allSatisfy { $0 != 50 })
    }

    @Test func developedFixtureKeepsRoomDragonAndNpcProgressionIndependent() throws {
        let fixture = try #require(ProductVerificationFixture.named("populated"))
        let base = fixture.world.snapshot
        let visual = try #require(base.residents.first?.koboldVisual)
        let world = fixture.world

        #expect(DungeonSceneView.assetName(world: world, cue: .idle) == "DungeonStage4")
        #expect(DungeonSceneView.dragonAtlasName(stage: base.dragonVisual.stage, cue: .idle) == "EmberAdultIdle")
        #expect(DungeonSceneView.koboldIdleAtlasName(age: visual.age) == "KoboldKidIdle")

        var changedRoom = base
        changedRoom.hoard = 100
        let changedRoomNPC = try #require(changedRoom.residents.first?.koboldVisual?.age)
        #expect(changedRoom.backgroundStage == .five)
        #expect(DungeonSceneView.dragonAtlasName(stage: changedRoom.dragonVisual.stage, cue: .idle) == "EmberAdultIdle")
        #expect(DungeonSceneView.koboldIdleAtlasName(age: changedRoomNPC) == "KoboldKidIdle")

        var changedDragon = base
        changedDragon.dragonVisual.stage = .elder
        let changedDragonNPC = try #require(changedDragon.residents.first?.koboldVisual?.age)
        #expect(changedDragon.backgroundStage == .four)
        #expect(DungeonSceneView.dragonAtlasName(stage: changedDragon.dragonVisual.stage, cue: .idle) == "EmberElderIdle")
        #expect(DungeonSceneView.koboldIdleAtlasName(age: changedDragonNPC) == "KoboldKidIdle")

        var changedNPC = base
        changedNPC.residents[0].koboldVisual?.age = .adult
        let changedNPCAge = try #require(changedNPC.residents.first?.koboldVisual?.age)
        #expect(changedNPC.backgroundStage == .four)
        #expect(changedNPC.dragonVisual.stage == .adult)
        #expect(DungeonSceneView.koboldIdleAtlasName(age: changedNPCAge) == "KoboldAdultIdle")
    }

    @Test func registeredPromptsContainNoCushioningVocabulary() {
        for entry in ModelPromptRegistry.editorEntries {
            for term in QA03Contract.prohibitedPromptCushioning {
                #expect(!entry.defaultText.localizedCaseInsensitiveContains(term), Comment(rawValue: "\(entry.id.rawValue) contains \(term)"))
            }
        }
    }

    private func assertEmptyStart(_ world: WorldSnapshot) {
        #expect(world.morale == 5)
        #expect(world.integrity == 1)
        #expect(world.food == 0)
        #expect(world.hoard == 0)
        #expect(world.residents.isEmpty)
        #expect(world.facts.isEmpty)
        #expect(world.activeThreads.isEmpty)
        #expect(world.abilities.isEmpty)
        #expect(world.locations.map(\.id) == ["empty-cavern"])
        #expect(world.dragonVisual.stage == .baby)
    }

}
