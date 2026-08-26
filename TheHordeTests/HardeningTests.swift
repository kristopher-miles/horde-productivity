import Foundation
import Testing
@testable import TheHorde

@Suite("Hardening and release")
struct HardeningTests {
    @Test func dungeonArtSelectionIgnoresTransientCuesAndStats() {
        var snapshot = WorldSnapshot.initial()
        let normal = WorldReadModel(dungeonName: "Vault", revision: 0, snapshot: snapshot)
        #expect(AnimationCue.allCases.allSatisfy { DungeonSceneView.assetName(world: normal, cue: $0) == "DungeonStage1" })
        snapshot.activeThreads = [ActiveThreadState(id: "loose-stones", title: "Loose Stones", severity: 2, state: "active", involvedEntityIDs: ["dragon"], summary: "A recoverable concern.")]
        snapshot.morale = 100
        snapshot.integrity = 100
        snapshot.food = 100
        let hazard = WorldReadModel(dungeonName: "Vault", revision: 1, snapshot: snapshot)
        #expect(AnimationCue.allCases.allSatisfy { DungeonSceneView.assetName(world: hazard, cue: $0) == "DungeonStage1" })
    }

    @Test func thousandEntryChronicleRemainsReadableAndOrdered() async throws {
        let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        try await store.insertChronicleFixture(count: 1_000)
        let clock = ContinuousClock()
        let start = clock.now
        let entries = try await store.chronicle()
        let elapsed = start.duration(to: clock.now)
        #expect(entries.count == 1_000)
        #expect(entries.first?.committedRevision == 1_000)
        #expect(entries.last?.committedRevision == 1)
        #expect(elapsed < .seconds(2))
    }

    @Test func maximumCollectionsRemainBounded() throws {
        var world = WorldSnapshot.initial()
        world.residents = (0..<8).map { CharacterState(id: "resident-\($0)", name: "Resident \($0)", role: "Keeper", identity: "A bounded fixture.", vitality: 50, bond: 50, conditions: Array(repeating: "steady", count: 6)) }
        world.locations = (0..<8).map { LocationState(id: "location-\($0)", name: "Location \($0)", status: "Stable", summary: "A bounded place.") }
        world.abilities = (0..<12).map { AbilityState(id: "ability-\($0)", name: "Ability \($0)", summary: "A bounded ability.", rank: 1) }
        world.activeThreads = (0..<4).map { ActiveThreadState(id: "thread-\($0)", title: "Thread \($0)", severity: 1, state: "active", involvedEntityIDs: ["dragon"], summary: "A bounded thread.") }
        world.facts = (0..<24).map { WorldFact(id: "fact-\($0)", title: "Fact \($0)", summary: "A bounded fact.") }
        let record = GeneratedRecord(id: "overflow", title: "Overflow", summary: "Must not be inserted.", severityOrRank: 1, involvedEntityIDs: [])
        #expect(throws: WorldPatchError.collectionFull("world.abilities")) { _ = try WorldPatchValidator.applying([.append("world.abilities", record: record)], to: world, valence: .positive) }
        #expect(world.residents.count == 8)
        #expect(world.facts.count == 24)
    }

    @Test func explicitReleaseSchemaVersionIsFrozenWithoutLegacySchemas() {
        #expect(HordeSchemaV4.dataVersion == 4)
        #expect(HordeSchemaV4.versionIdentifier == .init(4, 0, 0))
    }
}
