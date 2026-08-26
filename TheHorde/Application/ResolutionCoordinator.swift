import Foundation

enum ResolutionOutcome: Sendable, Equatable {
    case committed(ChronicleSummary)
    case failed(code: String)
}

actor ResolutionCoordinator {
    private let store: HordeStore
    private let model: FoundationModelClient

    init(store: HordeStore, model: FoundationModelClient) {
        self.store = store
        self.model = model
    }

    func resolve(eventID: String) async -> ResolutionOutcome {
        for conflictAttempt in 0...1 {
            do {
                let (event, world) = try await store.claimEvent(eventID)
                let compatibility = await model.compatibility()
                guard compatibility == .available else {
                    let code = compatibilityCode(compatibility)
                    try await store.markEventFailed(eventID, code: code)
                    return .failed(code: code)
                }
                let history = event.effort == nil && event.sourceEffort == nil
                    ? try await store.attemptedGoalHistory(for: eventID)
                    : []
                let effort = try await evaluateEffortWithTimeout(event: event, history: history)
                try await store.checkpointEffort(eventID: eventID, result: effort)
                let descriptors = WorldContract.descriptors(for: event.valence, world: world.snapshot)
                let generated = try await generateWithTimeout(event: event, world: world, descriptors: descriptors)
                var (updatedWorld, deltas) = try WorldPatchValidator.applying(generated.mutations, to: world.snapshot, valence: event.valence, descriptors: descriptors)
                updatedWorld.rollingSummary = String((updatedWorld.rollingSummary + " " + generated.summary).suffix(600))
                let result = try await store.commitResolution(eventID: eventID, expectedRevision: world.revision, world: updatedWorld, mutations: generated.mutations, deltas: deltas, generatedTitle: generated.title, narration: generated.narration, summary: generated.summary, cue: AnimationCue(rawValue: generated.cue) ?? .idle, effort: effort.effort, comparisonHistoryIDs: effort.comparisonHistoryIDs)
                return .committed(result)
            } catch StoreError.staleRevision where conflictAttempt == 0 {
                try? await store.returnEventToPending(eventID)
                continue
            } catch is CancellationError {
                try? await store.returnEventToPending(eventID)
                return .failed(code: "interrupted")
            } catch {
                let code = classify(error)
                try? await store.markEventFailed(eventID, code: code)
                return .failed(code: code)
            }
        }
        try? await store.markEventFailed(eventID, code: "revisionConflict")
        return .failed(code: "revisionConflict")
    }

    private func compatibilityCode(_ state: CompatibilityState) -> String {
        switch state {
        case .deviceNotEligible: "deviceNotEligible"
        case .intelligenceDisabled: "intelligenceDisabled"
        case .modelNotReady: "modelNotReady"
        case .unsupportedLocale: "unsupportedLocale"
        default: "modelUnavailable"
        }
    }

    private func classify(_ error: Error) -> String {
        if case ModelClientError.timeout = error { return "modelTimeout" }
        if case ModelClientError.contextOverflow = error { return "contextOverflow" }
        if error is WorldPatchError || error is ModelClientError { return "invalidOutput" }
        if error is StoreError { return "persistenceFailure" }
        let text = String(describing: error).lowercased()
        if text.contains("guardrail") { return "guardrail" }
        if text.contains("context") { return "contextOverflow" }
        return "modelFailure"
    }

    private func generateWithTimeout(event: PendingStorySummary, world: WorldReadModel, descriptors: [WorldMutationDescriptor]) async throws -> GeneratedStory {
        try await withThrowingTaskGroup(of: GeneratedStory.self) { group in
            group.addTask { try await self.model.generate(event: event, world: world, descriptors: descriptors) }
            group.addTask {
                try await Task.sleep(for: .seconds(60))
                throw ModelClientError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func evaluateEffortWithTimeout(event: PendingStorySummary, history: [AttemptedGoalContext]) async throws -> EffortEvaluationResult {
        try await withThrowingTaskGroup(of: EffortEvaluationResult.self) { group in
            group.addTask { try await self.model.evaluateEffort(event: event, history: history) }
            group.addTask {
                try await Task.sleep(for: .seconds(60))
                throw ModelClientError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
