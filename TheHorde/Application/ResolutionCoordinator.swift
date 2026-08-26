import Foundation

enum ResolutionOutcome: Sendable, Equatable {
    case committed(ChronicleSummary)
    case failed(code: String)
}

enum ActionSuggestionOutcome: Sendable, Equatable {
    case suggested(String)
    case failed(code: String)
}

enum CustomActionInterpretationOutcome: Sendable, Equatable {
    case interpreted(String)
    case failed(code: String)
}

enum FinalProseOutcome: Sendable, Equatable {
    case generated(String)
    case failed(code: String)
}

actor ResolutionCoordinator {
    private let store: HordeStore
    private let model: FoundationModelClient

    init(store: HordeStore, model: FoundationModelClient) {
        self.store = store
        self.model = model
    }

    func suggestAction(eventID: String) async -> ActionSuggestionOutcome {
        do {
            if let action = try await store.persistedActionSuggestion(eventID: eventID) {
                return .suggested(action)
            }
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
            var ratedEvent = event
            ratedEvent.effort = effort.effort
            ratedEvent.comparisonHistoryIDs = effort.comparisonHistoryIDs
            let suggestion = try await suggestActionWithTimeout(event: ratedEvent, world: world)
            try await store.checkpointSuggestion(eventID: eventID, result: suggestion)
            return .suggested(suggestion.action)
        } catch is CancellationError {
            try? await store.returnEventToPending(eventID)
            return .failed(code: "interrupted")
        } catch {
            let code = classify(error)
            try? await store.markEventFailed(eventID, code: code)
            return .failed(code: code)
        }
    }

    func interpretCustomAction(eventID: String, customAction: String) async -> CustomActionInterpretationOutcome {
        do {
            if let action = try await store.persistedActionInterpretation(eventID: eventID, customAction: customAction) {
                return .interpreted(action)
            }
            let (event, world) = try await store.claimEvent(eventID)
            let compatibility = await model.compatibility()
            guard compatibility == .available else {
                let code = compatibilityCode(compatibility)
                try await store.markEventFailed(eventID, code: code)
                return .failed(code: code)
            }
            guard let state = event.resolutionState,
                  state.stage == .actionSuggestion || state.stage == .customActionEntry,
                  let effort = state.effort,
                  let fallbackAction = state.suggestedAction,
                  state.customAction == nil || state.customAction == customAction else {
                throw StoreError.invalidResolutionState
            }
            try await store.checkpointCustomActionEntry(eventID: eventID, customAction: customAction)
            var ratedEvent = event
            ratedEvent.effort = effort
            let result = try await interpretCustomActionWithTimeout(
                event: ratedEvent,
                world: world,
                customAction: customAction,
                fallbackAction: fallbackAction
            )
            try await store.checkpointInterpretation(eventID: eventID, result: result)
            return .interpreted(result.action)
        } catch is CancellationError {
            try? await store.returnEventToPending(eventID)
            return .failed(code: "interrupted")
        } catch {
            let code = classify(error)
            try? await store.markEventFailed(eventID, code: code)
            return .failed(code: code)
        }
    }

    func generateFinalProse(eventID: String) async -> FinalProseOutcome {
        do {
            if let prose = try await store.persistedFinalProse(eventID: eventID) {
                return .generated(prose)
            }
            let (event, world) = try await store.claimEvent(eventID)
            let compatibility = await model.compatibility()
            guard compatibility == .available else {
                let code = compatibilityCode(compatibility)
                try await store.markEventFailed(eventID, code: code)
                return .failed(code: code)
            }
            guard let state = event.resolutionState,
                  state.stage == .actionAccepted,
                  let acceptedAction = state.acceptedAction,
                  !acceptedAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw StoreError.invalidResolutionState
            }
            let previousProse = try await store.mostRecentFinalProse()
            let result = try await generateFinalProseWithTimeout(
                event: event,
                world: world,
                acceptedAction: acceptedAction,
                previousProse: previousProse
            )
            try await store.checkpointFinalProse(eventID: eventID, result: result)
            return .generated(result.prose)
        } catch is CancellationError {
            try? await store.returnEventToPending(eventID)
            return .failed(code: "interrupted")
        } catch {
            let code = classify(error)
            try? await store.markEventFailed(eventID, code: code)
            return .failed(code: code)
        }
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
                var consequenceEvent = event
                consequenceEvent.effort = effort.effort
                let descriptors = WorldContract.descriptors(for: event.valence, effort: effort.effort, world: world.snapshot)
                let generated = try await generateWithTimeout(event: consequenceEvent, world: world, descriptors: descriptors)
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

    private func suggestActionWithTimeout(event: PendingStorySummary, world: WorldReadModel) async throws -> ActionSuggestionResult {
        try await withThrowingTaskGroup(of: ActionSuggestionResult.self) { group in
            group.addTask { try await self.model.suggestAction(event: event, world: world) }
            group.addTask {
                try await Task.sleep(for: .seconds(60))
                throw ModelClientError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func interpretCustomActionWithTimeout(
        event: PendingStorySummary,
        world: WorldReadModel,
        customAction: String,
        fallbackAction: String
    ) async throws -> CustomActionInterpretationResult {
        try await withThrowingTaskGroup(of: CustomActionInterpretationResult.self) { group in
            group.addTask {
                try await self.model.interpretCustomAction(
                    event: event,
                    world: world,
                    customAction: customAction,
                    fallbackAction: fallbackAction
                )
            }
            group.addTask {
                try await Task.sleep(for: .seconds(60))
                throw ModelClientError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func generateFinalProseWithTimeout(
        event: PendingStorySummary,
        world: WorldReadModel,
        acceptedAction: String,
        previousProse: String
    ) async throws -> FinalProseResult {
        try await withThrowingTaskGroup(of: FinalProseResult.self) { group in
            group.addTask {
                try await self.model.generateFinalProse(
                    event: event,
                    world: world,
                    acceptedAction: acceptedAction,
                    previousProse: previousProse
                )
            }
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
