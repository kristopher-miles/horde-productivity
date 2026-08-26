import Foundation
import Testing
@testable import TheHorde

@Suite("Suggestion acceptance")
struct SuggestionAcceptanceTests {
    @Test func acceptancePersistsExactlyTheSuggestionAcrossReopenWithoutModelOrWorldChange() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "TheHorde-v4.store")
        let eventID: String
        let originalWorld: WorldReadModel
        let logger = AcceptanceLogCapture()

        do {
            let store = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
            try await store.bootstrapForProof()
            var draft = GoalDraft(title: "Fortify the obsidian gate")
            draft.effort = .large
            let definitionID = try await store.createGoal(draft)
            let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
            try await store.completeOccurrence(id: occurrence.id)
            eventID = occurrence.id + ":positive"
            originalWorld = try await store.worldReadModel()
            _ = try await store.claimEvent(eventID)
            try await store.checkpointEffort(eventID: eventID, result: EffortEvaluationResult(
                effort: ResolutionEffort(rating: .three, source: .userSelected),
                comparisonHistoryIDs: [],
                promptVersion: nil
            ))
            try await store.checkpointSuggestion(eventID: eventID, result: ActionSuggestionResult(
                action: "Raise the obsidian gate",
                promptVersion: ActionSuggestionModelContract.promptVersion
            ))
            let client = FoundationModelClient(attemptLogger: logger, compatibilityOverride: .available)
            let coordinator = ResolutionCoordinator(store: store, model: client)

            #expect(await coordinator.acceptSuggestedAction(eventID: eventID) == .accepted("Raise the obsidian gate"))
            #expect(await coordinator.acceptSuggestedAction(eventID: eventID) == .accepted("Raise the obsidian gate"))
            let pending = try #require(await store.pendingStories().first { $0.id == eventID })
            #expect(pending.resolutionState?.stage == .actionAccepted)
            #expect(pending.resolutionState?.suggestedAction == "Raise the obsidian gate")
            #expect(pending.resolutionState?.acceptedAction == "Raise the obsidian gate")
            #expect(pending.acceptedAction == "Raise the obsidian gate")
            #expect(pending.resolutionState?.finalProse == nil)
            #expect(pending.resolutionState?.finalResult == nil)
            #expect(await logger.snapshot().isEmpty)
            #expect(try await store.worldReadModel() == originalWorld)
            #expect(try await store.chronicle().isEmpty)
        }

        let reopened = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
        try await reopened.bootstrapForProof()
        let resumed = try #require(await reopened.pendingStories().first { $0.id == eventID })
        #expect(resumed.resolutionState?.stage == .actionAccepted)
        #expect(resumed.resolutionState?.acceptedAction == resumed.resolutionState?.suggestedAction)
        #expect(await ResolutionCoordinator(
            store: reopened,
            model: FoundationModelClient(attemptLogger: logger, compatibilityOverride: .available)
        ).acceptSuggestedAction(eventID: eventID) == .accepted("Raise the obsidian gate"))
        #expect(await logger.snapshot().isEmpty)
        #expect(try await reopened.worldReadModel() == originalWorld)
        #expect(try await reopened.chronicle().isEmpty)
    }

    @Test func stalePromptVersionCannotBeAccepted() async throws {
        let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        try await store.bootstrapForProof()
        let definitionID = try await store.createGoal(GoalDraft(title: "Guard the lower vault"))
        let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        let eventID = occurrence.id + ":positive"
        let effort = ResolutionEffort(rating: .two, source: .modelEstimated)
        try await store.checkpointEffort(eventID: eventID, result: EffortEvaluationResult(
            effort: effort,
            comparisonHistoryIDs: [],
            promptVersion: EffortModelContract.promptVersion
        ))
        try await store.checkpointResolution(eventID: eventID, state: StagedResolutionState(
            stage: .actionSuggestion,
            effort: effort,
            suggestedAction: "Guard the lower vault",
            promptVersions: ResolutionPromptVersions(
                effort: EffortModelContract.promptVersion,
                suggestion: ActionSuggestionModelContract.promptVersion - 1
            )
        ))

        #expect(await ResolutionCoordinator(
            store: store,
            model: FoundationModelClient(compatibilityOverride: .available)
        ).acceptSuggestedAction(eventID: eventID) == .failed(code: "persistenceFailure"))
        let pending = try #require(await store.pendingStories().first { $0.id == eventID })
        #expect(pending.resolutionState?.stage == .actionSuggestion)
        #expect(pending.resolutionState?.acceptedAction == nil)
        #expect(try await store.chronicle().isEmpty)
    }

    @Test func mismatchedAcceptedActionIsNeitherAcceptedByStoreNorShownByTheSheet() async throws {
        let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        try await store.bootstrapForProof()
        let definitionID = try await store.createGoal(GoalDraft(title: "Guard the lower vault"))
        let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        let eventID = occurrence.id + ":positive"
        let effort = ResolutionEffort(rating: .two, source: .modelEstimated)
        try await store.checkpointEffort(eventID: eventID, result: EffortEvaluationResult(
            effort: effort,
            comparisonHistoryIDs: [],
            promptVersion: EffortModelContract.promptVersion
        ))
        try await store.checkpointResolution(eventID: eventID, state: StagedResolutionState(
            stage: .actionAccepted,
            effort: effort,
            suggestedAction: "Guard the lower vault",
            acceptedAction: "Open the lower vault",
            promptVersions: ResolutionPromptVersions(
                effort: EffortModelContract.promptVersion,
                suggestion: ActionSuggestionModelContract.promptVersion
            )
        ))

        #expect(await ResolutionCoordinator(
            store: store,
            model: FoundationModelClient(compatibilityOverride: .available)
        ).acceptSuggestedAction(eventID: eventID) == .failed(code: "persistenceFailure"))
        let pending = try #require(await store.pendingStories().first { $0.id == eventID })
        #expect(StoryResolutionPhase.opening(pending) == .failed("persistenceFailure"))
        #expect(pending.resolutionState?.acceptedAction == "Open the lower vault")
        #expect(try await store.chronicle().isEmpty)
    }

    @Test func openingAndCustomBranchKeepSuggestionUnaccepted() async throws {
        let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        try await store.bootstrapForProof()
        let definitionID = try await store.createGoal(GoalDraft(title: "Map the ember tunnels"))
        let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        let eventID = occurrence.id + ":positive"
        let originalWorld = try await store.worldReadModel()
        try await store.checkpointEffort(eventID: eventID, result: EffortEvaluationResult(
            effort: ResolutionEffort(rating: .one, source: .modelEstimated),
            comparisonHistoryIDs: [],
            promptVersion: EffortModelContract.promptVersion
        ))
        try await store.checkpointSuggestion(eventID: eventID, result: ActionSuggestionResult(
            action: "Map the ember tunnels",
            promptVersion: ActionSuggestionModelContract.promptVersion
        ))
        let pending = try #require(await store.pendingStories().first { $0.id == eventID })
        var phase = StoryResolutionPhase.opening(pending)

        #expect(phase == .suggestion("Map the ember tunnels"))
        phase.openCustomActionEntry()
        #expect(phase == .customActionEntry("Map the ember tunnels"))
        phase.returnToSuggestion()
        #expect(phase == .suggestion("Map the ember tunnels"))
        phase.openCustomActionEntry()
        let exactAction = "  Circle the lower vault\nby torchlight  "
        #expect(phase.beginInterpreting(customAction: exactAction) == exactAction)
        #expect(phase == .interpretingCustomAction("Map the ember tunnels"))
        let unchanged = try #require(await store.pendingStories().first { $0.id == eventID })
        #expect(unchanged.resolutionState?.stage == .actionSuggestion)
        #expect(unchanged.resolutionState?.acceptedAction == nil)
        #expect(try await store.worldReadModel() == originalWorld)
        #expect(try await store.chronicle().isEmpty)

        let identifiers = [
            StoryResolutionAccessibility.suggestion,
            StoryResolutionAccessibility.acceptSuggestion,
            StoryResolutionAccessibility.customAction,
            StoryResolutionAccessibility.customActionEntry,
            StoryResolutionAccessibility.interpretCustomAction,
            StoryResolutionAccessibility.interpretingCustomAction,
            StoryResolutionAccessibility.interpretedActionReady,
            StoryResolutionAccessibility.backToSuggestion,
            StoryResolutionAccessibility.retrySuggestion,
            StoryResolutionAccessibility.close
        ]
        #expect(Set(identifiers).count == identifiers.count)
        #expect(identifiers.allSatisfy { $0.hasPrefix("StoryResolution.") })
    }

    @Test func customActionPhaseRejectsOnlyWhitespaceAndRestoresPersistedStages() async throws {
        var phase = StoryResolutionPhase.customActionEntry("Map the ember tunnels")
        #expect(phase.beginInterpreting(customAction: " \n\t ") == nil)
        #expect(phase == .customActionEntry("Map the ember tunnels"))

        let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        try await store.bootstrapForProof()
        var draft = GoalDraft(title: "Map the ember tunnels")
        draft.effort = .small
        let definitionID = try await store.createGoal(draft)
        let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        let eventID = occurrence.id + ":positive"
        try await store.checkpointEffort(eventID: eventID, result: EffortEvaluationResult(
            effort: ResolutionEffort(rating: .one, source: .userSelected),
            comparisonHistoryIDs: [],
            promptVersion: nil
        ))
        try await store.checkpointSuggestion(eventID: eventID, result: ActionSuggestionResult(
            action: "Map the ember tunnels",
            promptVersion: ActionSuggestionModelContract.promptVersion
        ))
        let exactAction = "  Circle the lower vault\nby torchlight  "
        try await store.checkpointCustomActionEntry(eventID: eventID, customAction: exactAction)
        let savedDraft = try #require(await store.pendingStories().first { $0.id == eventID })
        #expect(savedDraft.resolutionState?.customAction == exactAction)
        #expect(StoryResolutionPhase.opening(savedDraft) == .customActionEntry("Map the ember tunnels"))
        #expect(StoryResolutionPhase.customActionDraft(opening: savedDraft) == exactAction)

        try await store.checkpointInterpretation(eventID: eventID, result: CustomActionInterpretationResult(
            action: "Circle the lower vault",
            promptVersion: CustomActionModelContract.promptVersion
        ))
        let interpreted = try #require(await store.pendingStories().first { $0.id == eventID })
        #expect(StoryResolutionPhase.opening(interpreted) == .interpretedActionReady)
        #expect(interpreted.resolutionState?.acceptedAction == nil)
        #expect(try await store.chronicle().isEmpty)
    }
}

private actor AcceptanceLogCapture: ModelAttemptLogger {
    private var entries: [ModelDevLogEntry] = []
    func record(_ entry: ModelDevLogEntry) { entries.append(entry) }
    func snapshot() -> [ModelDevLogEntry] { entries }
}
