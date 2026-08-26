import Foundation
import Testing
@testable import TheHorde

@Suite("Resolution and visual persistence contracts")
struct PersistenceContractTests {
    @Test func visualContractsEncodeDeterministicallyAndRoundTrip() throws {
        var world = WorldSnapshot.initial(dragonName: "Cinder", dungeonName: "Deep Vault")
        world.dragonVisual = DragonVisualState(stage: .greatWyrm, color: RGBColor(red: 17, green: 34, blue: 51))
        world.backgroundStage = .five
        world.residents = KoboldAgeStage.allCases.enumerated().map { index, age in
            CharacterState(
                id: "kobold-\(age.rawValue)",
                name: age.rawValue.capitalized,
                role: "Keeper",
                identity: "A persisted kobold.",
                vitality: 40 + index,
                bond: 30 + index,
                conditions: [],
                koboldVisual: KoboldVisualState(
                    age: age,
                    colors: CharacterPalette(
                        primary: RGBColor(red: UInt8(20 + index), green: UInt8(40 + index), blue: UInt8(60 + index)),
                        secondary: RGBColor(red: UInt8(80 + index), green: UInt8(100 + index), blue: UInt8(120 + index))
                    )
                )
            )
        }

        let first = try PersistentJSON.encode(world)
        let second = try PersistentJSON.encode(world)
        #expect(first == second)
        #expect(try PersistentJSON.decode(WorldSnapshot.self, from: first) == world)

        let selected = ResolutionEffort(rating: .two, source: .userSelected)
        #expect(try PersistentJSON.decode(ResolutionEffort.self, from: PersistentJSON.encode(selected)) == selected)
    }

    @Test func diskReopenAndExportPreserveAuthoritativeResolutionAndEventScene() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "TheHorde.store")
        let eventID = try await writePersistedResolution(to: url)

        let reopened = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
        let world = try await reopened.worldReadModel()
        #expect(world.revision == 2)
        #expect(world.snapshot.dragonVisual == DragonVisualState(stage: .greatWyrm, color: RGBColor(red: 201, green: 45, blue: 88)))
        #expect(world.snapshot.backgroundStage == .five)
        #expect(world.snapshot.residents.map(\.koboldVisual?.age) == [.baby, .kid, .adult])
        #expect(world.snapshot.residents.map(\.koboldVisual?.colors.primary.red) == [11, 21, 31])

        let event = try #require(await reopened.allStoryEvents().first { $0.id == eventID })
        #expect(event.effort == ResolutionEffort(rating: .three, source: .modelEstimated))
        #expect(event.comparisonHistoryIDs == ["history-failure", "history-success"])
        #expect(event.acceptedAction == "Claim the crystal forge")
        #expect(event.finalProse == "Cinder claims the crystal forge and calls its ancient fire back to life.")
        #expect(event.recordedWorld?.revision == 1)
        #expect(event.recordedWorld?.snapshot.dragonVisual == DragonVisualState(stage: .elder, color: RGBColor(red: 12, green: 90, blue: 140)))
        #expect(event.recordedWorld?.snapshot.backgroundStage == .four)
        #expect(event.recordedWorld?.snapshot.residents.map(\.koboldVisual?.age) == [.baby, .kid, .adult])
        #expect(event.recordedWorld?.snapshot.residents.map(\.koboldVisual?.colors.primary.red) == [11, 21, 31])

        let chronicle = try #require(await reopened.chronicle().first)
        #expect(chronicle.effort == event.effort)
        #expect(chronicle.comparisonHistoryIDs == event.comparisonHistoryIDs)
        #expect(chronicle.acceptedAction == event.acceptedAction)
        #expect(chronicle.finalProse == event.finalProse)
        #expect(chronicle.recordedWorld == event.recordedWorld)
        #expect(chronicle.recordedWorld.revision == chronicle.committedRevision)
        #expect(chronicle.recordedWorld != world)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(LocalDataExport.self, from: await reopened.exportLocalData())
        let exportedEvent = try #require(export.storyEvents.first { $0.id == eventID })
        let exportedChronicle = try #require(export.chronicle.first { $0.eventID == eventID })
        #expect(export.world == world)
        #expect(exportedEvent.effort == event.effort)
        #expect(exportedEvent.comparisonHistoryIDs == event.comparisonHistoryIDs)
        #expect(exportedEvent.acceptedAction == event.acceptedAction)
        #expect(exportedEvent.finalProse == event.finalProse)
        #expect(exportedEvent.recordedWorld == event.recordedWorld)
        #expect(exportedEvent.recordedWorld?.snapshot.dragonVisual.color == RGBColor(red: 12, green: 90, blue: 140))
        #expect(exportedEvent.recordedWorld?.snapshot.backgroundStage == .four)
        #expect(exportedEvent.recordedWorld?.snapshot.residents.map(\.koboldVisual?.age) == [.baby, .kid, .adult])
        #expect(exportedEvent.recordedWorld?.snapshot.residents.map(\.koboldVisual?.colors.secondary) == Array(repeating: RGBColor(red: 200, green: 160, blue: 40), count: 3))
        #expect(exportedChronicle.eventID == chronicle.eventID)
        #expect(exportedChronicle.effort == chronicle.effort)
        #expect(exportedChronicle.comparisonHistoryIDs == chronicle.comparisonHistoryIDs)
        #expect(exportedChronicle.acceptedAction == chronicle.acceptedAction)
        #expect(exportedChronicle.finalProse == chronicle.finalProse)
        #expect(exportedChronicle.recordedWorld == chronicle.recordedWorld)
    }

    private func writePersistedResolution(to url: URL) async throws -> String {
        let store = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
        try await store.bootstrapForProof()
        let definitionID = try await store.createGoal(GoalDraft(title: "Restore the crystal forge"))
        let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        let eventID = occurrence.id + ":positive"
        let (_, before) = try await store.claimEvent(eventID)

        var committedWorld = before.snapshot
        committedWorld.dragonVisual = DragonVisualState(stage: .elder, color: RGBColor(red: 12, green: 90, blue: 140))
        committedWorld.backgroundStage = .four
        committedWorld.residents = [
            kobold(id: "baby", age: .baby, red: 11),
            kobold(id: "kid", age: .kid, red: 21),
            kobold(id: "adult", age: .adult, red: 31)
        ]
        let prose = "Cinder claims the crystal forge and calls its ancient fire back to life."
        _ = try await store.commitResolution(
            eventID: eventID,
            expectedRevision: before.revision,
            world: committedWorld,
            mutations: [],
            deltas: [],
            generatedTitle: "The Crystal Forge",
            narration: prose,
            summary: "The forge burns again.",
            cue: .celebrate,
            effort: ResolutionEffort(rating: .three, source: .modelEstimated),
            comparisonHistoryIDs: ["history-failure", "history-success"],
            acceptedAction: "Claim the crystal forge"
        )
        var laterWorld = committedWorld
        laterWorld.dragonVisual = DragonVisualState(stage: .greatWyrm, color: RGBColor(red: 201, green: 45, blue: 88))
        laterWorld.backgroundStage = .five
        try await store.installWorldFixture(laterWorld, dungeonName: before.dungeonName, revision: 2)
        return eventID
    }

    private func kobold(id: String, age: KoboldAgeStage, red: UInt8) -> CharacterState {
        CharacterState(
            id: "kobold-\(id)",
            name: id.capitalized,
            role: "Keeper",
            identity: "A persisted kobold.",
            vitality: 50,
            bond: 50,
            conditions: [],
            koboldVisual: KoboldVisualState(
                age: age,
                colors: CharacterPalette(
                    primary: RGBColor(red: red, green: 80, blue: 120),
                    secondary: RGBColor(red: 200, green: 160, blue: 40)
                )
            )
        )
    }
}
