import Foundation
import Testing
@testable import TheHorde

@Suite("Action acceptance gate")
struct ActionAcceptanceGateTests {
    enum Path: CaseIterable, Sendable {
        case suggested
        case interpreted
    }

    @Test func openingClosingBackingOutAndEditingDoNotCrossTheGate() async throws {
        let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        let eventID = try await prepareSuggestion(in: store)
        let originalWorld = try await store.worldReadModel()
        let probe = AcceptanceGateProbe()
        let client = FoundationModelClient(
            finalProseResponseOverride: { _, _ in
                await probe.record(stage: nil, acceptedAction: nil)
                return Self.paragraph
            },
            compatibilityOverride: .available
        )
        let pending = try #require(await store.pendingStories().first { $0.id == eventID })
        var phase = StoryResolutionPhase.opening(pending)
        #expect(phase == .suggestion("Guard the ember vault"))

        phase.openCustomActionEntry()
        var editedDraft = "Circle the vault at dawn"
        #expect(phase == .customActionEntry("Guard the ember vault"))
        phase.returnToSuggestion()
        phase.openCustomActionEntry()
        editedDraft += " with scouts"
        #expect(phase.beginInterpreting(customAction: editedDraft) == editedDraft)
        phase = .opening(pending) // Closing and reopening rebuilds only from persisted state.
        #expect(phase == .suggestion("Guard the ember vault"))

        #expect(await ResolutionCoordinator(store: store, model: client).generateFinalProse(eventID: eventID) == .failed(code: "persistenceFailure"))
        let unchanged = try #require(await store.pendingStories().first { $0.id == eventID })
        #expect(unchanged.resolutionState?.stage == .actionSuggestion)
        #expect(unchanged.resolutionState?.acceptedAction == nil)
        #expect(await probe.observations.isEmpty)
        #expect(try await store.worldReadModel() == originalWorld)
        #expect(try await store.chronicle().isEmpty)
    }

    @Test(arguments: Path.allCases)
    func explicitAcceptanceIsAuthoritativeBeforeNarration(path: Path) async throws {
        let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        let eventID = try await prepareSuggestion(in: store)
        let originalWorld = try await store.worldReadModel()
        let acceptedAction: String
        if path == .interpreted {
            try await store.checkpointCustomActionEntry(eventID: eventID, customAction: "Hold the old stone bridge")
            try await store.checkpointInterpretation(eventID: eventID, result: CustomActionInterpretationResult(
                action: "Hold the stone bridge",
                promptVersion: CustomActionModelContract.promptVersion
            ))
            acceptedAction = "Hold the stone bridge"
        } else {
            acceptedAction = "Guard the ember vault"
        }
        let probe = AcceptanceGateProbe()
        let client = FoundationModelClient(
            finalProseResponseOverride: { _, _ in
                let pending = try await store.pendingStories().first { $0.id == eventID }
                await probe.record(
                    stage: pending?.resolutionState?.stage,
                    acceptedAction: pending?.resolutionState?.acceptedAction
                )
                return Self.paragraph
            },
            compatibilityOverride: .available
        )
        let coordinator = ResolutionCoordinator(store: store, model: client)

        let outcome = path == .suggested
            ? await coordinator.acceptSuggestedActionAndGenerateFinalProse(eventID: eventID)
            : await coordinator.acceptInterpretedActionAndGenerateFinalProse(eventID: eventID)
        #expect(outcome == .generated(action: acceptedAction, prose: Self.paragraph))
        #expect(await probe.observations == [
            .init(stage: .actionAccepted, acceptedAction: acceptedAction)
        ])
        let staged = try #require(await store.pendingStories().first { $0.id == eventID })
        #expect(staged.resolutionState?.stage == .finalProse)
        #expect(staged.resolutionState?.acceptedAction == acceptedAction)
        #expect(staged.resolutionState?.finalProse == Self.paragraph)
        #expect(StoryResolutionPhase.opening(staged) == .finalProse(action: acceptedAction, prose: Self.paragraph))
        #expect(try await store.worldReadModel() == originalWorld)
        #expect(try await store.chronicle().isEmpty)
    }

    private func prepareSuggestion(in store: HordeStore) async throws -> String {
        try await store.bootstrapForProof()
        var draft = GoalDraft(title: "Guard the ember vault")
        draft.effort = .medium
        let definitionID = try await store.createGoal(draft)
        let occurrence = try #require(await store.definitionSummary(id: definitionID)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        let eventID = occurrence.id + ":positive"
        try await store.checkpointEffort(eventID: eventID, result: EffortEvaluationResult(
            effort: ResolutionEffort(rating: .two, source: .userSelected),
            comparisonHistoryIDs: [],
            promptVersion: nil
        ))
        try await store.checkpointSuggestion(eventID: eventID, result: ActionSuggestionResult(
            action: "Guard the ember vault",
            promptVersion: ActionSuggestionModelContract.promptVersion
        ))
        return eventID
    }

    private static let paragraph = (["The", "dragon", "guards", "the", "ember", "vault"]
        + Array(repeating: "steadfastly", count: 44)).joined(separator: " ")
}

private actor AcceptanceGateProbe {
    struct Observation: Equatable, Sendable {
        let stage: ResolutionFlowStage?
        let acceptedAction: String?
    }

    private(set) var observations: [Observation] = []

    func record(stage: ResolutionFlowStage?, acceptedAction: String?) {
        observations.append(.init(stage: stage, acceptedAction: acceptedAction))
    }
}
