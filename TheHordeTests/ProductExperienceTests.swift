import Foundation
import Testing
@testable import TheHorde

@Suite("Complete product experience")
struct ProductExperienceTests {
    private static let cinderOrigin = "Cinder has recently left the nest and searched for their own lair. After flying far from home, they arrived at an empty cavern extending deep into the rock. They are small now, but they will grow. They settle onto the cold stone, and plan for what's next."

    @Test func notificationRoutingTargetsPendingResolvedAndStaleStatesExactly() {
        let occurrence = GoalOccurrenceSummary(id: "occurrence", definitionID: "definition", snapshot: GoalSnapshot(title: "Goal", notes: "", category: nil, effort: nil, recurrence: .never, definitionVersion: 1), dueDate: .distantFuture, includesTime: true, state: .pending, resolvedAt: nil, hasPendingStory: false)
        let pending = PendingStorySummary(id: "occurrence:positive", sourceTitle: "Goal", valence: .positive, status: .pending, failureCode: nil, createdAt: .distantPast)
        let entry = ChronicleSummary(id: "entry", eventID: pending.id, sourceTitle: "Goal", valence: .positive, title: "Story", finalProse: "Narration", summary: "Summary", deltas: [], cue: .idle, priorRevision: 0, committedRevision: 1, committedAt: .distantPast, effort: nil, comparisonHistoryIDs: [], acceptedAction: nil, recordedWorld: WorldReadModel(dungeonName: "Recorded", revision: 1, snapshot: .initial()))

        #expect(NotificationDestination.resolve(occurrenceID: occurrence.id, eventID: nil, occurrences: [occurrence], pendingStories: [pending], chronicle: []) == .resolution(pending.id))
        #expect(NotificationDestination.resolve(occurrenceID: occurrence.id, eventID: pending.id, occurrences: [occurrence], pendingStories: [], chronicle: [entry]) == .chronicle(entry.id))
        #expect(NotificationDestination.resolve(occurrenceID: occurrence.id, eventID: nil, occurrences: [occurrence], pendingStories: [], chronicle: []) == .goal(occurrence.definitionID))
        #expect(NotificationDestination.resolve(occurrenceID: "deleted", eventID: nil, occurrences: [], pendingStories: [], chronicle: []) == .stale)
    }

    @Test func onboardingCreatesNamedWorldExactlyOnce() async throws {
        let store = try makeStore()
        #expect(try await store.prepareAppState() == false)
        try await store.completeOnboarding(dragonName: "Cinder", dungeonName: "Quiet Keep")
        #expect(try await store.prepareAppState() == true)
        let first = try await store.worldReadModel()
        #expect(first.snapshot.dragon.name == "Cinder")
        #expect(first.dungeonName == "Quiet Keep")
        #expect(first.snapshot.rollingSummary == Self.cinderOrigin)
        #expect(first.snapshot.morale == 5)
        #expect(first.snapshot.integrity == 1)
        #expect(first.snapshot.food == 0)
        assertEmptyStartingWorld(first.snapshot)
        try await store.completeOnboarding(dragonName: "Overwrite", dungeonName: "Overwrite")
        let second = try await store.worldReadModel()
        #expect(second.snapshot.dragon.name == "Cinder")
        #expect(second.dungeonName == "Quiet Keep")
    }

    @Test func exportIsVersionedReadableAndExcludesTransientSessions() async throws {
        let store = try await onboardedStore()
        let id = try await store.createGoal(GoalDraft(title: "Export this", notes: "Local only"))
        let occurrence = try #require(await store.definitionSummary(id: id)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        let data = try await store.exportLocalData()
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(LocalDataExport.self, from: data)
        #expect(export.exportVersion == 1)
        #expect(export.dataSchemaVersion == 3)
        #expect(export.goals.first?.draft.title == "Export this")
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(!text.localizedCaseInsensitiveContains("transcript"))
        #expect(!text.localizedCaseInsensitiveContains("remoteIdentifier"))
    }

    @Test func resetPreservesGoalsButRemovesStoryState() async throws {
        let store = try await onboardedStore()
        let id = try await store.createGoal(GoalDraft(title: "Keep my goal"))
        let occurrence = try #require(await store.definitionSummary(id: id)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        #expect(try await store.pendingStoryCount() == 1)
        try await store.resetDungeon()
        #expect(try await store.definitionSummary(id: id) != nil)
        #expect(try await store.pendingStoryCount() == 0)
        #expect(try await store.chronicle().isEmpty)
        let world = try await store.worldReadModel().snapshot
        #expect(world.morale == 5)
        #expect(world.integrity == 1)
        #expect(world.food == 0)
        assertEmptyStartingWorld(world)
    }

    @Test func deleteAllReturnsToFirstRunWithNoDomainRecords() async throws {
        let store = try await onboardedStore()
        _ = try await store.createGoal(GoalDraft(title: "Delete me"))
        try await store.deleteAllLocalData()
        #expect(try await store.prepareAppState() == false)
        #expect(try await store.occurrenceSummaries().isEmpty)
        #expect(try await store.pendingStoryCount() == 0)
        await #expect(throws: StoreError.missingSave) { _ = try await store.worldReadModel() }
    }

    @Test func newGameSaveUsesTheReleaseSchemaVersion() {
        let save = GameSaveRecord(dragonName: "Cinder")
        #expect(save.schemaVersion == 3)
        #expect(save.morale == 5)
        #expect(save.integrity == 1)
        #expect(save.food == 0)
        #expect(save.rollingSummary == Self.cinderOrigin)
        let world = try? PersistentJSON.decode(WorldSnapshot.self, from: save.worldData)
        #expect(world != nil)
        if let world {
            #expect(world.rollingSummary == Self.cinderOrigin)
            assertEmptyStartingWorld(world)
        }
    }

    @Test func resetRestoresTheExactNamedOriginNarrative() async throws {
        let store = try makeStore()
        _ = try await store.prepareAppState()
        try await store.completeOnboarding(dragonName: "Cinder", dungeonName: "Quiet Keep")
        var changed = try await store.worldReadModel().snapshot
        changed.rollingSummary = "A later story."
        try await store.installWorldFixture(changed, dungeonName: "Quiet Keep", revision: 4)

        try await store.resetDungeon()

        #expect(try await store.worldReadModel().snapshot.rollingSummary == Self.cinderOrigin)
    }

    @Test func initialStatsRetainTheirFullUpwardProgressionRange() throws {
        let world = WorldSnapshot.initial()
        let descriptors = WorldContract.descriptors(for: .positive)
        let upperBound = { (fieldID: String) throws -> Int in
            try #require(descriptors.first { $0.fieldID == fieldID }?.range?.upperBound)
        }

        #expect(try upperBound("world.morale") - world.morale == 95)
        #expect(try upperBound("world.integrity") - world.integrity == 99)
        #expect(try upperBound("world.food") - world.food == 100)
    }

    @Test func cleanWorldContainsNoSeededTutorialThreat() throws {
        let save = GameSaveRecord(dragonName: "Ember")
        let text = String(decoding: save.worldData, as: UTF8.self)
        let world = try PersistentJSON.decode(WorldSnapshot.self, from: save.worldData)

        #expect(!text.localizedCaseInsensitiveContains("A Draft in the West " + "Passage"))
        #expect(!text.localizedCaseInsensitiveContains("harmless"))
        #expect(world.activeThreads.isEmpty)
    }

    @Test func startingLairIsUntamedInPersistenceModelContextAndAccessibility() throws {
        let world = WorldSnapshot.initial(dragonName: "Cinder")
        let location = try #require(world.locations.first)
        let event = PendingStorySummary(id: "starting-lair", sourceTitle: "Survey the cavern", valence: .positive, status: .pending, failureCode: nil, createdAt: .distantPast)
        let readModel = WorldReadModel(dungeonName: "The Cinder Vault", revision: 0, snapshot: world)
        let projection = ProjectionBuilder.projection(event: event, world: readModel, descriptors: WorldContract.descriptors(for: .positive, world: world))
        let sceneDescription = DungeonSceneView.sceneDescription(for: readModel)
        let presentations = [location.summary, projection, sceneDescription, OnboardingView.startingCavernAccessibilityLabel]

        #expect(location.status == "Untamed")
        #expect(world.rollingSummary == Self.cinderOrigin)
        for trait in ["dirty", "cold", "empty", "unruly", "dangerous"] {
            #expect(presentations.allSatisfy { $0.localizedCaseInsensitiveContains(trait) })
        }
        for contradiction in ["tidy", "calm", "warm", "comfortable", "safe", "cared for"] {
            #expect(presentations.allSatisfy { !$0.localizedCaseInsensitiveContains(contradiction) })
        }
    }

    @Test func exportCleanupDoesNotDependOnLiveViewState() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = AppModel.exportFileURL(in: directory)
        try Data("private local export".utf8).write(to: url)
        #expect(FileManager.default.fileExists(atPath: url.path()))
        try AppModel.removeOwnedExport(in: directory)
        #expect(!FileManager.default.fileExists(atPath: url.path()))
    }

    private func makeStore() throws -> HordeStore {
        HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
    }

    private func onboardedStore() async throws -> HordeStore {
        let store = try makeStore()
        _ = try await store.prepareAppState()
        try await store.completeOnboarding(dragonName: "Ember", dungeonName: "The Cinder Vault")
        return store
    }

    private func assertEmptyStartingWorld(_ world: WorldSnapshot, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(world.locations.count == 1, sourceLocation: sourceLocation)
        #expect(world.locations.first?.id == "empty-cavern", sourceLocation: sourceLocation)
        #expect(world.locations.first?.name == "Empty Cavern", sourceLocation: sourceLocation)
        #expect(world.residents.isEmpty, sourceLocation: sourceLocation)
        #expect(world.abilities.isEmpty, sourceLocation: sourceLocation)
        #expect(world.facts.isEmpty, sourceLocation: sourceLocation)
        #expect(world.activeThreads.isEmpty, sourceLocation: sourceLocation)
        #expect(!world.rollingSummary.localizedCaseInsensitiveContains("kobold"), sourceLocation: sourceLocation)
    }
}
