import Foundation
import Testing
@testable import TheHorde

@Suite("Interpreted action review")
struct InterpretedActionReviewTests {
    @Test func acceptPersistsOnlyTheValidatedInterpretationWithoutModelOrWorldChange() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "TheHorde-v4.store")
        let logger = ReviewLogCapture()
        let eventID: String
        let originalWorld: WorldReadModel

        do {
            let store = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
            try await store.bootstrapForProof()
            var draft = GoalDraft(title: "Secure the lower vault")
            draft.effort = .medium
            let definitionID = try await store.createGoal(draft)
            let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
            try await store.completeOccurrence(id: occurrence.id)
            eventID = occurrence.id + ":positive"
            originalWorld = try await store.worldReadModel()
            try await stageReview(store: store, eventID: eventID, customAction: "  Hold the lower vault\nwith the guard  ", interpretedAction: "Hold the lower vault")
            let before = try #require(await store.pendingStories().first { $0.id == eventID })
            #expect(StoryResolutionPhase.opening(before) == .interpretedActionReady("Hold the lower vault"))
            #expect(await logger.snapshot().isEmpty)
            #expect(try await store.worldReadModel() == originalWorld)
            #expect(try await store.chronicle().isEmpty)
        }

        do {
            let reopened = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
            try await reopened.bootstrapForProof()
            let review = try #require(await reopened.pendingStories().first { $0.id == eventID })
            #expect(StoryResolutionPhase.opening(review) == .interpretedActionReady("Hold the lower vault"))
            let coordinator = ResolutionCoordinator(
                store: reopened,
                model: FoundationModelClient(attemptLogger: logger, compatibilityOverride: .available)
            )
            #expect(await coordinator.acceptInterpretedAction(eventID: eventID) == .accepted("Hold the lower vault"))
            #expect(await coordinator.acceptInterpretedAction(eventID: eventID) == .accepted("Hold the lower vault"))
            let accepted = try #require(await reopened.pendingStories().first { $0.id == eventID })
            #expect(accepted.resolutionState?.stage == .actionAccepted)
            #expect(accepted.resolutionState?.customAction == "  Hold the lower vault\nwith the guard  ")
            #expect(accepted.resolutionState?.interpretedAction == "Hold the lower vault")
            #expect(accepted.resolutionState?.acceptedAction == "Hold the lower vault")
            #expect(accepted.resolutionState?.finalProse == nil)
            #expect(accepted.resolutionState?.finalResult == nil)
            #expect(StoryResolutionPhase.opening(accepted) == .accepted("Hold the lower vault"))
            #expect(await logger.snapshot().isEmpty)
            #expect(try await reopened.worldReadModel() == originalWorld)
            #expect(try await reopened.chronicle().isEmpty)
        }

        let reopenedAccepted = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
        try await reopenedAccepted.bootstrapForProof()
        let resumed = try #require(await reopenedAccepted.pendingStories().first { $0.id == eventID })
        #expect(StoryResolutionPhase.opening(resumed) == .accepted("Hold the lower vault"))
        #expect(await ResolutionCoordinator(
            store: reopenedAccepted,
            model: FoundationModelClient(attemptLogger: logger, compatibilityOverride: .available)
        ).acceptInterpretedAction(eventID: eventID) == .accepted("Hold the lower vault"))
        #expect(await logger.snapshot().isEmpty)
        #expect(try await reopenedAccepted.worldReadModel() == originalWorld)
        #expect(try await reopenedAccepted.chronicle().isEmpty)
    }

    @Test func reviseRestoresExactDraftAndAllowsEditedReparseWithoutReplayingEarlierStages() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "TheHorde-v4.store")
        let logger = ReviewLogCapture()
        let firstDraft = "  Scout beneath the bridge\nat dawn  "
        let editedDraft = "Circle the bridge with scouts"
        let eventID: String
        let originalWorld: WorldReadModel

        do {
            let store = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
            try await store.bootstrapForProof()
            var draft = GoalDraft(title: "Find the hidden crossing")
            draft.effort = .small
            let definitionID = try await store.createGoal(draft)
            let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
            try await store.completeOccurrence(id: occurrence.id)
            eventID = occurrence.id + ":positive"
            originalWorld = try await store.worldReadModel()
            let coordinator = ResolutionCoordinator(
                store: store,
                model: FoundationModelClient(
                    attemptLogger: logger,
                    suggestionResponseOverride: { _, _ in "Search the hidden crossing" },
                    customActionResponseOverride: { _, _ in
                        CustomActionModelResponse(action: "Scout beneath the bridge", useGoalFallback: false)
                    },
                    compatibilityOverride: .available
                )
            )
            #expect(await coordinator.suggestAction(eventID: eventID) == .suggested("Search the hidden crossing"))
            #expect(await coordinator.interpretCustomAction(eventID: eventID, customAction: firstDraft) == .interpreted("Scout beneath the bridge"))
            #expect(await coordinator.reviseCustomAction(eventID: eventID) == .revised(draft: firstDraft, suggestion: "Search the hidden crossing"))
            #expect(await coordinator.reviseCustomAction(eventID: eventID) == .revised(draft: firstDraft, suggestion: "Search the hidden crossing"))

            let revised = try #require(await store.pendingStories().first { $0.id == eventID })
            #expect(revised.resolutionState?.stage == .customActionEntry)
            #expect(revised.resolutionState?.customAction == firstDraft)
            #expect(revised.resolutionState?.interpretedAction == nil)
            #expect(revised.resolutionState?.promptVersions.interpretation == nil)
            #expect(revised.resolutionState?.acceptedAction == nil)
            #expect(StoryResolutionPhase.opening(revised) == .customActionEntry("Search the hidden crossing"))
            #expect(StoryResolutionPhase.customActionDraft(opening: revised) == firstDraft)
        }

        let reopened = HordeStore(modelContainer: try HordeStore.makeContainer(url: url))
        try await reopened.bootstrapForProof()
        let coordinator = ResolutionCoordinator(
            store: reopened,
            model: FoundationModelClient(
                attemptLogger: logger,
                suggestionResponseOverride: { _, _ in throw ModelClientError.invalidActionSuggestion },
                customActionResponseOverride: { _, _ in
                    CustomActionModelResponse(action: "Circle the bridge with scouts", useGoalFallback: false)
                },
                compatibilityOverride: .available
            )
        )
        #expect(await coordinator.interpretCustomAction(eventID: eventID, customAction: editedDraft) == .interpreted("Circle the bridge with scouts"))
        let reparsed = try #require(await reopened.pendingStories().first { $0.id == eventID })
        #expect(reparsed.resolutionState?.stage == .interpretedActionReview)
        #expect(reparsed.resolutionState?.customAction == editedDraft)
        #expect(reparsed.resolutionState?.interpretedAction == "Circle the bridge with scouts")
        #expect(StoryResolutionPhase.opening(reparsed) == .interpretedActionReady("Circle the bridge with scouts"))
        #expect(await logger.snapshot().map(\.stage) == [.actionSuggestion, .customActionInterpretation, .customActionInterpretation])
        #expect(try await reopened.worldReadModel() == originalWorld)
        #expect(try await reopened.chronicle().isEmpty)
    }

    @Test(arguments: ["Scout bridge", "Scout beneath the ancient broken bridge now", "<tool> Scout beneath bridge"])
    func malformedInterpretationFailsClosed(rawAction: String) async throws {
        let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        try await store.bootstrapForProof()
        var draft = GoalDraft(title: "Guard the lower vault")
        draft.effort = .small
        let definitionID = try await store.createGoal(draft)
        let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        let eventID = occurrence.id + ":positive"
        let effort = ResolutionEffort(rating: .one, source: .userSelected)
        try await store.checkpointEffort(eventID: eventID, result: EffortEvaluationResult(
            effort: effort,
            comparisonHistoryIDs: [],
            promptVersion: nil
        ))
        try await store.checkpointResolution(eventID: eventID, state: StagedResolutionState(
            stage: .interpretedActionReview,
            effort: effort,
            suggestedAction: "Guard the lower vault",
            customAction: "Use the old stone bridge",
            interpretedAction: rawAction,
            promptVersions: ResolutionPromptVersions(
                suggestion: ActionSuggestionModelContract.promptVersion,
                interpretation: CustomActionModelContract.promptVersion
            )
        ))
        let pending = try #require(await store.pendingStories().first { $0.id == eventID })
        #expect(StoryResolutionPhase.opening(pending) == .failed("persistenceFailure"))
        let coordinator = ResolutionCoordinator(store: store, model: FoundationModelClient(compatibilityOverride: .available))
        #expect(await coordinator.acceptInterpretedAction(eventID: eventID) == .failed(code: "persistenceFailure"))
        #expect(await coordinator.reviseCustomAction(eventID: eventID) == .failed(code: "persistenceFailure"))
        #expect(try await store.chronicle().isEmpty)
    }

    @Test func staleInterpretationPromptVersionFailsClosed() async throws {
        let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        try await store.bootstrapForProof()
        var draft = GoalDraft(title: "Guard the lower vault")
        draft.effort = .small
        let definitionID = try await store.createGoal(draft)
        let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        let eventID = occurrence.id + ":positive"
        let effort = ResolutionEffort(rating: .one, source: .userSelected)
        try await store.checkpointEffort(eventID: eventID, result: EffortEvaluationResult(
            effort: effort,
            comparisonHistoryIDs: [],
            promptVersion: nil
        ))
        try await store.checkpointResolution(eventID: eventID, state: StagedResolutionState(
            stage: .interpretedActionReview,
            effort: effort,
            suggestedAction: "Guard the lower vault",
            customAction: "Hold the lower vault",
            interpretedAction: "Hold the lower vault",
            promptVersions: ResolutionPromptVersions(
                suggestion: ActionSuggestionModelContract.promptVersion,
                interpretation: CustomActionModelContract.promptVersion - 1
            )
        ))
        let pending = try #require(await store.pendingStories().first { $0.id == eventID })
        #expect(StoryResolutionPhase.opening(pending) == .failed("persistenceFailure"))
        let coordinator = ResolutionCoordinator(store: store, model: FoundationModelClient(compatibilityOverride: .available))
        #expect(await coordinator.acceptInterpretedAction(eventID: eventID) == .failed(code: "persistenceFailure"))
        #expect(await coordinator.reviseCustomAction(eventID: eventID) == .failed(code: "persistenceFailure"))
        #expect(try await store.chronicle().isEmpty)
    }

    @Test func reviewControlsHaveDistinctAccessibilityIdentifiers() {
        let identifiers = [
            StoryResolutionAccessibility.interpretedActionReady,
            StoryResolutionAccessibility.acceptInterpretedAction,
            StoryResolutionAccessibility.reviseAction,
            StoryResolutionAccessibility.close
        ]
        #expect(Set(identifiers).count == identifiers.count)
        #expect(identifiers.allSatisfy { $0.hasPrefix("StoryResolution.") })
    }

    private func stageReview(
        store: HordeStore,
        eventID: String,
        customAction: String,
        interpretedAction: String
    ) async throws {
        try await store.checkpointEffort(eventID: eventID, result: EffortEvaluationResult(
            effort: ResolutionEffort(rating: .two, source: .userSelected),
            comparisonHistoryIDs: [],
            promptVersion: nil
        ))
        try await store.checkpointSuggestion(eventID: eventID, result: ActionSuggestionResult(
            action: "Secure the lower vault",
            promptVersion: ActionSuggestionModelContract.promptVersion
        ))
        try await store.checkpointCustomActionEntry(eventID: eventID, customAction: customAction)
        try await store.checkpointInterpretation(eventID: eventID, result: CustomActionInterpretationResult(
            action: interpretedAction,
            promptVersion: CustomActionModelContract.promptVersion
        ))
    }
}

private actor ReviewLogCapture: ModelAttemptLogger {
    private var entries: [ModelDevLogEntry] = []
    func record(_ entry: ModelDevLogEntry) { entries.append(entry) }
    func snapshot() -> [ModelDevLogEntry] { entries }
}
