import Foundation
import Testing
@testable import TheHorde

@Suite("Cancel and fail actions")
struct CancelFailTests {
    @Test @MainActor func cancelStopsGoalWithoutAttemptStoryModelOrWorldChangeAndSurvivesReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "TheHorde-v4.store")
        let logger = CancelFailLogCapture()
        let definitionID: String
        let occurrenceID: String
        let originalWorld: WorldReadModel

        do {
            let store = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
            try await store.bootstrapForProof()
            definitionID = try await store.createGoal(GoalDraft(title: "Abandon the silent watch"))
            let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
            occurrenceID = occurrence.id
            originalWorld = try await store.worldReadModel()
            let app = AppModel(
                store: store,
                modelClient: FoundationModelClient(attemptLogger: logger, compatibilityOverride: .available)
            )
            await app.reload()

            #expect(await app.cancel(occurrence))
            #expect(await app.cancel(occurrence))
            #expect(app.presentedResolution == nil)
            #expect(await logger.snapshot().isEmpty)
        }

        let reopened = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
        let definition = try #require(await reopened.definitionSummary(id: definitionID))
        let cancelled = try #require(definition.history.first { $0.id == occurrenceID })
        #expect(definition.archived)
        #expect(cancelled.state == .cancelled)
        #expect(AttemptedGoalHistory.closest(
            to: "Another watch",
            currentOccurrenceID: "another-occurrence",
            among: definition.history,
            distance: { _, _ in 0 }
        ).isEmpty)
        #expect(try await reopened.allStoryEvents().isEmpty)
        #expect(try await reopened.pendingStories().isEmpty)
        #expect(try await reopened.chronicle().isEmpty)
        #expect(try await reopened.worldReadModel() == originalWorld)
    }

    @Test @MainActor func failCreatesOneNegativeAttemptOpensStagingAndDoesNotCommit() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "TheHorde-v4.store")
        let logger = CancelFailLogCapture()
        let finalProse = (["The", "failed", "watch", "opens", "a", "dangerous", "breach"]
            + Array(repeating: "embers", count: 53)).joined(separator: " ")
        let eventID: String
        let occurrenceID: String
        let originalWorld: WorldReadModel

        do {
            let store = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
            try await store.bootstrapForProof()
            var draft = GoalDraft(title: "Hold the obsidian watch")
            draft.effort = .medium
            let definitionID = try await store.createGoal(draft)
            let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
            occurrenceID = occurrence.id
            eventID = occurrence.id + ":negative"
            originalWorld = try await store.worldReadModel()
            let client = FoundationModelClient(
                attemptLogger: logger,
                suggestionResponseOverride: { _, _ in "Face the gathering ruin" },
                finalProseResponseOverride: { _, _ in finalProse },
                compatibilityOverride: .available
            )
            let app = AppModel(store: store, modelClient: client)
            await app.reload()

            #expect(await app.fail(occurrence))
            #expect(await app.fail(occurrence))
            #expect(app.presentedResolution?.id == eventID)
            #expect(app.presentedResolution?.valence == .negative)
            #expect(app.presentedResolution?.sourceOutcome == .failed)
            #expect(app.presentedResolution?.resolutionState?.stage == .effortSelection)
            #expect(await logger.snapshot().isEmpty)
            #expect(await app.suggestAction(eventID: eventID) == .suggested("Face the gathering ruin"))
            #expect(await app.acceptSuggestedAction(eventID: eventID) == .generated(action: "Face the gathering ruin", prose: finalProse))
        }

        let reopened = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
        let attempts = try await reopened.occurrenceSummaries()
        let failed = try #require(attempts.first { $0.id == occurrenceID })
        let events = try await reopened.allStoryEvents()
        let event = try #require(events.first { $0.id == eventID })
        #expect(failed.state == .failed)
        #expect(events.count == 1)
        #expect(event.valence == .negative)
        #expect(event.sourceOutcome == .failed)
        #expect(event.resolutionState?.stage == .finalProse)
        #expect(event.resolutionState?.acceptedAction == "Face the gathering ruin")
        #expect(event.resolutionState?.finalProse == finalProse)
        #expect(AttemptedGoalHistory.closest(
            to: "Hold another watch",
            currentOccurrenceID: "future-occurrence",
            among: attempts,
            distance: { _, _ in 0 }
        ).map(\.id).contains(occurrenceID))
        #expect(await logger.snapshot().map(\.stage) == [.actionSuggestion, .finalProse])
        #expect(try await reopened.worldReadModel() == originalWorld)
        #expect(try await reopened.chronicle().isEmpty)
    }
}

private actor CancelFailLogCapture: ModelAttemptLogger {
    private var entries: [ModelDevLogEntry] = []
    func record(_ entry: ModelDevLogEntry) { entries.append(entry) }
    func snapshot() -> [ModelDevLogEntry] { entries }
}
