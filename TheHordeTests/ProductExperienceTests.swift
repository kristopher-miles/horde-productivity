import Foundation
import Testing
@testable import TheHorde

@Suite("Complete product experience")
struct ProductExperienceTests {
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
        #expect(try await store.worldReadModel().snapshot.morale == 50)
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
        #expect(GameSaveRecord().schemaVersion == 3)
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
}
