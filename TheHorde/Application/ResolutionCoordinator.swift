import Foundation

enum ResolutionOutcome: Sendable, Equatable {
    case committed(ChronicleSummary)
    case failed(code: String)
}

enum ActionSuggestionOutcome: Sendable, Equatable {
    case suggested(String)
    case failed(code: String)
}

enum ActionAcceptanceOutcome: Sendable, Equatable {
    case accepted(String)
    case failed(code: String)
}

enum AcceptedActionFinalProseOutcome: Sendable, Equatable {
    case generated(action: String, prose: String)
    case failed(code: String)
}

enum CustomActionInterpretationOutcome: Sendable, Equatable {
    case interpreted(String)
    case failed(code: String)
}

enum CustomActionRevisionOutcome: Sendable, Equatable {
    case revised(draft: String, suggestion: String)
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

    func acceptSuggestedAction(eventID: String) async -> ActionAcceptanceOutcome {
        do {
            return .accepted(try await store.acceptSuggestedAction(eventID: eventID))
        } catch {
            return .failed(code: classify(error))
        }
    }

    func acceptInterpretedAction(eventID: String) async -> ActionAcceptanceOutcome {
        do {
            return .accepted(try await store.acceptInterpretedAction(eventID: eventID))
        } catch {
            return .failed(code: classify(error))
        }
    }

    func acceptSuggestedActionAndGenerateFinalProse(eventID: String) async -> AcceptedActionFinalProseOutcome {
        let acceptance = await acceptSuggestedAction(eventID: eventID)
        return await generateFinalProse(after: acceptance, eventID: eventID)
    }

    func acceptInterpretedActionAndGenerateFinalProse(eventID: String) async -> AcceptedActionFinalProseOutcome {
        let acceptance = await acceptInterpretedAction(eventID: eventID)
        return await generateFinalProse(after: acceptance, eventID: eventID)
    }

    func reviseCustomAction(eventID: String) async -> CustomActionRevisionOutcome {
        do {
            let state = try await store.reviseInterpretedAction(eventID: eventID)
            return .revised(draft: state.customAction, suggestion: state.suggestedAction)
        } catch {
            return .failed(code: classify(error))
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
                  state.suggestedAction != nil else {
                throw StoreError.invalidResolutionState
            }
            try await store.checkpointCustomActionEntry(eventID: eventID, customAction: customAction)
            var ratedEvent = event
            ratedEvent.effort = effort
            let result = try await interpretCustomActionWithTimeout(
                event: ratedEvent,
                world: world,
                customAction: customAction
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
                  let acceptedAction = authoritativeAcceptedAction(in: state) else {
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

    func resolve(eventID: String, failBeforeCommitSave: Bool = false) async -> ResolutionOutcome {
        if let committed = try? await store.committedResolution(eventID: eventID) {
            return .committed(committed)
        }
        for conflictAttempt in 0...1 {
            do {
                let (event, world) = try await store.claimEvent(eventID)
                guard let state = event.resolutionState,
                      state.stage == .finalProse,
                      let acceptedAction = authoritativeAcceptedAction(in: state),
                      state.promptVersions.finalProse == FinalProseModelContract.promptVersion,
                      let finalProse = state.finalProse,
                      (try? FinalProseModelContract.validatedProse(finalProse)) == finalProse else {
                    throw StoreError.invalidResolutionState
                }
                if let staged = state.finalResult {
                    if staged.expectedRevision == world.revision {
                        return .committed(try await store.commitStagedResolution(
                            eventID: eventID,
                            failBeforeSave: failBeforeCommitSave
                        ))
                    }
                    try await store.discardStaleFinalResult(eventID: eventID)
                }
                let compatibility = await model.compatibility()
                guard compatibility == .available else {
                    let code = compatibilityCode(compatibility)
                    try await store.markEventFailed(eventID, code: code)
                    return .failed(code: code)
                }
                var consequenceEvent = event
                consequenceEvent.effort = state.effort
                consequenceEvent.comparisonHistoryIDs = state.comparisonHistoryIDs
                consequenceEvent.acceptedAction = acceptedAction
                consequenceEvent.finalProse = finalProse
                let descriptors = WorldContract.descriptors(for: event.valence, effort: state.effort, world: world.snapshot)
                let generated = try await generateWithTimeout(event: consequenceEvent, world: world, descriptors: descriptors)
                var (updatedWorld, deltas) = try WorldPatchValidator.applying(generated.mutations, to: world.snapshot, valence: event.valence, descriptors: descriptors)
                updatedWorld.rollingSummary = String((updatedWorld.rollingSummary + " " + generated.summary).suffix(600))
                try await store.stageFinalResolution(
                    eventID: eventID,
                    expectedRevision: world.revision,
                    world: updatedWorld,
                    mutations: generated.mutations,
                    deltas: deltas,
                    generatedTitle: generated.title,
                    narration: finalProse,
                    summary: generated.summary,
                    cue: AnimationCue(rawValue: generated.cue) ?? .idle,
                    effort: state.effort,
                    comparisonHistoryIDs: state.comparisonHistoryIDs,
                    suggestedAction: state.suggestedAction,
                    customAction: state.customAction,
                    interpretedAction: state.interpretedAction,
                    acceptedAction: acceptedAction,
                    promptVersions: state.promptVersions
                )
                return .committed(try await store.commitStagedResolution(
                    eventID: eventID,
                    failBeforeSave: failBeforeCommitSave
                ))
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

    private func authoritativeAcceptedAction(in state: StagedResolutionState) -> String? {
        guard let effort = state.effort,
              (effort.source == .userSelected
                ? state.promptVersions.effort == nil && state.comparisonHistoryIDs.isEmpty
                : state.promptVersions.effort == EffortModelContract.promptVersion),
              state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
              let suggestion = state.suggestedAction,
              (try? ActionSuggestionModelContract.validatedAction(suggestion)) == suggestion,
              let acceptedAction = state.acceptedAction else { return nil }
        if let customAction = state.customAction {
            guard !customAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  state.promptVersions.interpretation == CustomActionModelContract.promptVersion,
                  let interpretation = state.interpretedAction,
                  (try? CustomActionModelContract.validatedAction(interpretation)) == interpretation,
                  acceptedAction == interpretation else { return nil }
            return acceptedAction
        }
        guard state.interpretedAction == nil,
              state.promptVersions.interpretation == nil,
              acceptedAction == suggestion else { return nil }
        return acceptedAction
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
        customAction: String
    ) async throws -> CustomActionInterpretationResult {
        try await withThrowingTaskGroup(of: CustomActionInterpretationResult.self) { group in
            group.addTask {
                try await self.model.interpretCustomAction(
                    event: event,
                    world: world,
                    customAction: customAction
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

    private func generateFinalProse(
        after acceptance: ActionAcceptanceOutcome,
        eventID: String
    ) async -> AcceptedActionFinalProseOutcome {
        switch acceptance {
        case .failed(let code):
            return .failed(code: code)
        case .accepted(let action):
            switch await generateFinalProse(eventID: eventID) {
            case .generated(let prose): return .generated(action: action, prose: prose)
            case .failed(let code): return .failed(code: code)
            }
        }
    }
}
