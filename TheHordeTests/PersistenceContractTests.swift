import Foundation
import Testing
@testable import TheHorde

@Suite("Resolution and visual persistence contracts")
struct PersistenceContractTests {
    @Test func preflightResetReplacesDevelopmentDataWithV4EmptyDefaults() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "TheHorde-v4.store")

        do {
            let store = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
            _ = try await store.prepareAppState()
            try await store.completeOnboarding(dragonName: "Legacy", dungeonName: "Populated Keep")
            var populated = try await store.worldReadModel().snapshot
            populated.residents = [CharacterState(id: "obsolete-kobold", name: "Old Fixture", role: "Keeper", identity: "Must not survive reset.", vitality: 50, bond: 50, conditions: [])]
            try await store.installWorldFixture(populated, dungeonName: "Populated Keep", revision: 9)
            _ = try await store.createGoal(GoalDraft(title: "Obsolete fixture goal"))
        }

        try HordeStore.resetStoreFiles(at: url)

        let reset = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
        #expect(try await reset.prepareAppState() == false)
        try await reset.completeOnboarding(dragonName: "Ember", dungeonName: "The Cinder Vault")
        let world = try await reset.worldReadModel().snapshot
        #expect(world.morale == 5)
        #expect(world.integrity == 1)
        #expect(world.food == 0)
        #expect(world.residents.isEmpty)
        #expect(world.facts.isEmpty)
        #expect(world.activeThreads.isEmpty)
        #expect(try await reset.occurrenceSummaries().isEmpty)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(LocalDataExport.self, from: await reset.exportLocalData())
        #expect(export.dataSchemaVersion == HordeSchemaV4.dataVersion)
    }

    @Test func visualContractsEncodeDeterministicallyAndRoundTrip() throws {
        var world = WorldSnapshot.initial(dragonName: "Cinder", dungeonName: "Deep Vault")
        world.dragonVisual = DragonVisualState(stage: .greatWyrm, color: RGBColor(red: 17, green: 34, blue: 51))
        world.hoard = 100
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
        #expect(world.snapshot.hoard == 100)
        #expect(world.snapshot.dragonVisual == DragonVisualState(stage: .greatWyrm, color: RGBColor(red: 201, green: 45, blue: 88)))
        #expect(world.snapshot.backgroundStage == .five)
        #expect(world.snapshot.residents.map(\.koboldVisual?.age) == [.baby, .kid, .adult])
        #expect(world.snapshot.residents.map(\.koboldVisual?.colors.primary.red) == [11, 21, 31])

        let event = try #require(await reopened.allStoryEvents().first { $0.id == eventID })
        #expect(event.effort == ResolutionEffort(rating: .three, source: .modelEstimated))
        #expect(event.comparisonHistoryIDs == ["history-failure", "history-success"])
        #expect(event.acceptedAction == "Claim the crystal forge")
        #expect(event.finalProse == "Cinder claims the crystal forge and calls its ancient fire back to life.")
        #expect(event.recordedWorld?.revision == 2)
        #expect(event.recordedWorld?.snapshot.hoard == 60)
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

    @Test func diskReopenResumesEveryStagedResolutionValueWithoutWorldCommit() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "TheHorde.store")
        let eventID: String
        let originalWorld: WorldReadModel

        do {
            let store = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
            try await store.bootstrapForProof()
            let definitionID = try await store.createGoal(GoalDraft(title: "Chart the ember roads"))
            let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
            try await store.completeOccurrence(id: occurrence.id)
            eventID = occurrence.id + ":positive"
            (_, originalWorld) = try await store.claimEvent(eventID)
            try await store.checkpointEffort(eventID: eventID, result: EffortEvaluationResult(
                effort: ResolutionEffort(rating: .two, source: .modelEstimated),
                comparisonHistoryIDs: ["attempt-near-1", "attempt-near-2"],
                promptVersion: EffortModelContract.promptVersion
            ))
            try await store.checkpointResolution(eventID: eventID, state: StagedResolutionState(
                stage: .customActionEntry,
                effort: ResolutionEffort(rating: .two, source: .modelEstimated),
                comparisonHistoryIDs: ["attempt-near-1", "attempt-near-2"],
                suggestedAction: "Map ember roads",
                customAction: "  Follow the blue flame exactly  ",
                promptVersions: ResolutionPromptVersions(effort: EffortModelContract.promptVersion, suggestion: 41)
            ))
        }

        do {
            let reopened = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
            try await reopened.bootstrapForProof()
            let resumed = try #require(await reopened.pendingStories().first { $0.id == eventID })
            #expect(resumed.resolutionState?.stage == .customActionEntry)
            #expect(resumed.resolutionState?.effort == ResolutionEffort(rating: .two, source: .modelEstimated))
            #expect(resumed.resolutionState?.comparisonHistoryIDs == ["attempt-near-1", "attempt-near-2"])
            #expect(resumed.resolutionState?.suggestedAction == "Map ember roads")
            #expect(resumed.resolutionState?.customAction == "  Follow the blue flame exactly  ")
            #expect(resumed.resolutionState?.promptVersions == ResolutionPromptVersions(effort: EffortModelContract.promptVersion, suggestion: 41))
            #expect(try await reopened.worldReadModel() == originalWorld)
            #expect(try await reopened.chronicle().isEmpty)

            try await reopened.checkpointResolution(eventID: eventID, state: StagedResolutionState(
                stage: .actionAccepted,
                effort: resumed.resolutionState?.effort,
                comparisonHistoryIDs: resumed.resolutionState?.comparisonHistoryIDs ?? [],
                suggestedAction: resumed.resolutionState?.suggestedAction,
                customAction: resumed.resolutionState?.customAction,
                interpretedAction: "Follow blue flame",
                acceptedAction: "Follow blue flame",
                promptVersions: ResolutionPromptVersions(effort: EffortModelContract.promptVersion, suggestion: 41, interpretation: 42)
            ))
        }

        let reopened = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
        try await reopened.bootstrapForProof()
        let resumed = try #require(await reopened.pendingStories().first { $0.id == eventID })
        #expect(resumed.resolutionState?.stage == .actionAccepted)
        #expect(resumed.resolutionState?.interpretedAction == "Follow blue flame")
        #expect(resumed.resolutionState?.acceptedAction == "Follow blue flame")
        #expect(resumed.resolutionState?.promptVersions.interpretation == 42)
        #expect(try await reopened.worldReadModel() == originalWorld)
        #expect(try await reopened.chronicle().isEmpty)
    }

    @Test func stagedFinalResultRollsBackAndRetriesExactlyOnceAcrossDiskReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "TheHorde.store")
        let eventID: String
        let base: WorldReadModel

        do {
            let store = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
            try await store.bootstrapForProof()
            let definitionID = try await store.createGoal(GoalDraft(title: "Raise the signal fire"))
            let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
            try await store.completeOccurrence(id: occurrence.id)
            eventID = occurrence.id + ":positive"
            (_, base) = try await store.claimEvent(eventID)
            let mutations = [WorldMutation.increment("world.morale", by: 2)]
            var (world, deltas) = try WorldPatchValidator.applying(mutations, to: base.snapshot, valence: .positive, descriptors: WorldContract.descriptors(for: .positive, world: base.snapshot))
            let summary = "The signal fire rallied the empty cavern."
            world.rollingSummary = String((world.rollingSummary + " " + summary).suffix(600))
            try await store.checkpointEffort(eventID: eventID, result: EffortEvaluationResult(
                effort: ResolutionEffort(rating: .three, source: .modelEstimated),
                comparisonHistoryIDs: ["nearby-attempt"],
                promptVersion: EffortModelContract.promptVersion
            ))
            try await store.stageFinalResolution(
                eventID: eventID,
                expectedRevision: base.revision,
                world: world,
                mutations: mutations,
                deltas: deltas,
                generatedTitle: "The Signal Fire",
                narration: "The young dragon kindles a signal fire that throws long shadows across the empty stone.",
                summary: summary,
                cue: .celebrate,
                effort: ResolutionEffort(rating: .three, source: .modelEstimated),
                comparisonHistoryIDs: ["nearby-attempt"],
                suggestedAction: "Raise signal fire",
                acceptedAction: "Raise signal fire",
                promptVersions: ResolutionPromptVersions(effort: EffortModelContract.promptVersion, suggestion: 41, finalProse: 43)
            )
        }

        do {
            let reopened = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
            try await reopened.bootstrapForProof()
            let ready = try #require(await reopened.pendingStories().first { $0.id == eventID })
            #expect(ready.resolutionState?.stage == .finalProse)
            #expect(ready.resolutionState?.finalResult?.expectedRevision == base.revision)
            #expect(ready.resolutionState?.finalResult?.mutations == [WorldMutation.increment("world.morale", by: 2)])
            #expect(ready.resolutionState?.finalResult?.title == "The Signal Fire")
            #expect(ready.resolutionState?.promptVersions.finalProse == 43)
            #expect(try await reopened.worldReadModel() == base)
            #expect(try await reopened.chronicle().isEmpty)
            await #expect(throws: StoreError.injectedFailure) {
                _ = try await reopened.commitStagedResolution(eventID: eventID, failBeforeSave: true)
            }
        }

        let retry = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
        try await retry.bootstrapForProof()
        #expect(try await retry.worldReadModel() == base)
        #expect(try await retry.chronicle().isEmpty)
        #expect(try await retry.pendingStories().first?.resolutionState?.stage == .finalProse)
        let committed = try await retry.commitStagedResolution(eventID: eventID)
        #expect(committed.priorRevision == base.revision)
        #expect(committed.committedRevision == base.revision + 1)
        #expect(try await retry.worldReadModel().revision == base.revision + 1)
        #expect(try await retry.chronicle().count == 1)
        #expect(try await retry.allStoryEvents().first?.resolutionState?.stage == .committed)
        await #expect(throws: StoreError.eventAlreadyResolved) {
            _ = try await retry.commitStagedResolution(eventID: eventID)
        }
        #expect(try await retry.worldReadModel().revision == base.revision + 1)
        #expect(try await retry.chronicle().count == 1)
    }

    @Test func resetAndDeleteRemoveStagedResolutionState() async throws {
        let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        try await store.bootstrapForProof()
        let definitionID = try await store.createGoal(GoalDraft(title: "Temporary staged event"))
        let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        let eventID = occurrence.id + ":positive"
        _ = try await store.claimEvent(eventID)
        try await store.checkpointEffort(eventID: eventID, result: EffortEvaluationResult(effort: ResolutionEffort(rating: .one, source: .userSelected), comparisonHistoryIDs: [], promptVersion: nil))
        try await store.checkpointResolution(eventID: eventID, state: StagedResolutionState(stage: .actionSuggestion, effort: ResolutionEffort(rating: .one, source: .userSelected), suggestedAction: "Light the brazier"))
        #expect(try await store.pendingStories().first?.resolutionState?.suggestedAction == "Light the brazier")
        try await store.resetDungeon()
        #expect(try await store.allStoryEvents().isEmpty)

        let replacementID = try await store.createGoal(GoalDraft(title: "Delete staged event"))
        let replacement = try #require(await store.definitionSummary(id: replacementID)?.history.first)
        try await store.completeOccurrence(id: replacement.id)
        let replacementEventID = replacement.id + ":positive"
        _ = try await store.claimEvent(replacementEventID)
        try await store.checkpointEffort(eventID: replacementEventID, result: EffortEvaluationResult(effort: ResolutionEffort(rating: .one, source: .userSelected), comparisonHistoryIDs: [], promptVersion: nil))
        try await store.checkpointResolution(eventID: replacementEventID, state: StagedResolutionState(stage: .customActionEntry, effort: ResolutionEffort(rating: .one, source: .userSelected), customAction: "Keep this exact draft"))
        try await store.deleteAllLocalData()
        #expect(try await store.allStoryEvents().isEmpty)
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
        committedWorld.hoard = 60
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
        laterWorld.hoard = 100
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
