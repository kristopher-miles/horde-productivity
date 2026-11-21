import Foundation
import FoundationModels

private let negativeConsequenceWords: Set<String> = [
    "attack", "attacks", "attacked", "attacking", "besiege", "besieges", "besieged", "besieging",
    "blood", "bloody", "burn", "burns", "burned", "burning", "casualty", "casualties", "cold",
    "conflict", "conflicts", "crack", "cracks", "cracked", "curse", "curses", "cursed", "damage",
    "damages", "damaged", "danger", "dangerous", "dead", "death", "defeat", "defeats", "defeated",
    "delay", "delays", "delayed", "deplete", "depletes", "depleted", "destroy", "destroys", "destroyed",
    "destruction", "difficult", "difficulty", "difficulties", "disrupt", "disrupts", "disrupted", "disruption",
    "enemy", "enemies", "expire", "expired", "fail", "fails", "failed", "failure", "famine", "fear",
    "fears", "fearful", "fracture", "fractures", "fractured", "hazard", "hazards", "invade", "invades",
    "invaded", "invasion", "invasions", "kill", "kills", "killed", "killing", "loss", "losses", "lost",
    "miss", "missed", "plague", "raid", "raids", "raided", "ruin", "ruins", "ruined", "scar", "scars",
    "scarred", "setback", "setbacks", "shortage", "shortages", "siege", "sieges", "terror", "threat",
    "threats", "threatened", "war", "wars", "warband", "warbands", "warfare", "wound", "wounds", "wounded"
]

private func containsNegativeConsequence(_ text: String) -> Bool {
    !negativeConsequenceWords.isDisjoint(with: text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
}

private let negativeOutcomeContradictions = [
    "accepted action succeeds", "action succeeds", "completed goal", "completed the goal", "goal ends in triumph",
    "goal ends in victory", "goal is completed", "goal is victorious", "goal succeeded", "goal triumph",
    "goal victory", "goal was completed", "positive outcome", "successful completion", "successfully completes"
]

private let positiveOutcomeContradictions = [
    "could not complete", "did not complete", "expired goal", "failed goal", "failed to complete", "failure to complete",
    "goal expired", "goal failed", "goal was missed", "missed goal", "unable to complete", "was not completed", "was not successful"
]

struct GeneratedStory: Codable, Sendable {
    let title: String
    let narration: String
    let summary: String
    let cue: String
    let mutations: [WorldMutation]
    let diagnostics: ModelGenerationDiagnostics
}

struct EffortEvaluationResult: Equatable, Sendable {
    let effort: ResolutionEffort
    let comparisonHistoryIDs: [String]
    let promptVersion: Int?
}

struct ActionSuggestionResult: Equatable, Sendable {
    let action: String
    let promptVersion: Int
}

struct CustomActionInterpretationResult: Equatable, Sendable {
    let action: String
    let promptVersion: Int
}

struct FinalProseResult: Equatable, Sendable {
    let prose: String
    let promptVersion: Int
}

struct CustomActionModelResponse: Equatable, Sendable {
    let action: String
}

enum ModelSampling: Codable, Equatable, Sendable {
    case productionDefault
    case greedy
    case seeded(UInt64)

    var identifier: String {
        switch self {
        case .productionDefault: "production-default"
        case .greedy: "greedy"
        case .seeded(let seed): "seed-\(seed)"
        }
    }

    var generationOptions: GenerationOptions {
        switch self {
        case .productionDefault: GenerationOptions(maximumResponseTokens: 500)
        case .greedy: GenerationOptions(sampling: .greedy, maximumResponseTokens: 500)
        case .seeded(let seed): GenerationOptions(sampling: .random(top: 40, seed: seed), maximumResponseTokens: 500)
        }
    }
}

struct ModelTokenCounts: Codable, Equatable, Sendable {
    let instructions: Int?
    let prompt: Int?
    let tools: Int?
    let generatedSchema: Int?
    let preResponseTranscript: Int?
    let completeTranscript: Int?

    var maximumInputTotal: Int? {
        let values = [instructions, prompt, tools, generatedSchema].compactMap { $0 }
        return values.count == 4 ? values.reduce(0, +) : nil
    }
}

struct ModelToolCall: Codable, Equatable, Sendable {
    let fieldID: String
    let operation: String
    let integerValue: Int?
    let stagedIntegerValue: Int?
    let recordID: String?
    let recordTitle: String?
    let recordSummary: String?
    let severityOrRank: Int?
    let involvedEntityIDs: [String]
    let accepted: Bool
    let rejection: String?
}

struct ModelAttemptDiagnostics: Codable, Equatable, Sendable {
    let attempt: Int
    let stagedMutations: [WorldMutation]
    let toolCalls: [ModelToolCall]
    let accepted: Bool
    let rejection: String?
}

struct ModelGenerationDiagnostics: Codable, Equatable, Sendable {
    let promptVersion: Int
    let schemaVersion: Int
    let projectionVersion: Int
    let sampling: String
    let contextSize: Int
    let localeSupported: Bool
    let startedAt: Date
    let sessionCreatedAt: Date
    let prewarmedAt: Date
    let responseCompletedAt: Date
    let attempts: [ModelAttemptDiagnostics]
    let correctionCount: Int
    let receiptID: String
    let rawGeneratedTitle: String
    let rawGeneratedNarration: String
    let rawGeneratedSummary: String
    let tokens: ModelTokenCounts
    let transcriptJSON: Data
}

enum ModelDiagnosticPhase: String, Codable, Sendable { case started, sessionCreated, prewarmed, completed, failed }

struct ModelDiagnosticEvent: Sendable {
    let eventID: String
    let phase: ModelDiagnosticPhase
    let timestamp: Date
    let generated: GeneratedStory?
    let errorDescription: String?
}

protocol ModelDiagnosticsSink: Sendable {
    func record(_ event: ModelDiagnosticEvent) async
}

struct NoOpModelDiagnosticsSink: ModelDiagnosticsSink {
    func record(_ event: ModelDiagnosticEvent) async {}
}

struct ModelStoryFields {
    let title: String
    let narration: String
    let summary: String
    let cue: String
    let receiptID: String
}

@Generable
private struct PositiveModelStoryOutput {
    var title: String
    var narration: String
    var summary: String
    var cue: String
    var receiptID: String
}

@Generable
private struct NegativeModelStoryOutput {
    var title: String
    var narration: String
    var summary: String
    var cue: String
    var receiptID: String
}

@Generable
struct StageMutationArguments {
    var fieldID: String
    var operation: String
    var integerValue: Int
    var recordID: String
    var recordTitle: String
    var recordSummary: String
    var severityOrRank: Int
    var involvedEntityIDs: [String]
}

enum LegacyModelSchemas {
    static func story(for valence: EventValence) -> GenerationSchema {
        let ids: [ModelPromptComponentID] = valence == .positive
            ? [.legacyPositiveTitleGuide, .legacyPositiveNarrationGuide, .legacyPositiveSummaryGuide, .legacyPositiveCueGuide, .legacyPositiveReceiptGuide]
            : [.legacyNegativeTitleGuide, .legacyNegativeNarrationGuide, .legacyNegativeSummaryGuide, .legacyNegativeCueGuide, .legacyNegativeReceiptGuide]
        let cues = valence == .positive
            ? ["idle", "celebrate", "concern", "recover", "hazardAppears", "resourceChanges"]
            : ["idle", "concern", "recover", "hazardAppears", "resourceChanges"]
        let type: any Generable.Type = valence == .positive ? PositiveModelStoryOutput.self : NegativeModelStoryOutput.self
        return GenerationSchema(type: type, properties: [
            .init(name: "title", description: ModelPromptRegistry.text(ids[0]), type: String.self),
            .init(name: "narration", description: ModelPromptRegistry.text(ids[1]), type: String.self),
            .init(name: "summary", description: ModelPromptRegistry.text(ids[2]), type: String.self),
            .init(name: "cue", description: ModelPromptRegistry.text(ids[3]), type: String.self, guides: [.anyOf(cues)]),
            .init(name: "receiptID", description: ModelPromptRegistry.text(ids[4]), type: String.self)
        ])
    }

    static var toolParameters: GenerationSchema {
        GenerationSchema(type: StageMutationArguments.self, properties: [
            .init(name: "fieldID", description: ModelPromptRegistry.text(.legacyToolFieldIDGuide), type: String.self),
            .init(name: "operation", description: ModelPromptRegistry.text(.legacyToolOperationGuide), type: String.self, guides: [.anyOf(["increment", "set", "append", "replace", "remove"])]),
            .init(name: "integerValue", description: ModelPromptRegistry.text(.legacyToolIntegerValueGuide), type: Int.self, guides: [.range(-4...4)]),
            .init(name: "recordID", description: ModelPromptRegistry.text(.legacyToolRecordIDGuide), type: String.self),
            .init(name: "recordTitle", description: ModelPromptRegistry.text(.legacyToolRecordTitleGuide), type: String.self),
            .init(name: "recordSummary", description: ModelPromptRegistry.text(.legacyToolRecordSummaryGuide), type: String.self),
            .init(name: "severityOrRank", description: ModelPromptRegistry.text(.legacyToolSeverityGuide), type: Int.self, guides: [.range(1...4)]),
            .init(name: "involvedEntityIDs", description: ModelPromptRegistry.text(.legacyToolEntityIDsGuide), type: [String].self)
        ])
    }
}

actor PatchStager {
    private var mutations: [WorldMutation] = []
    private var calls: [ModelToolCall] = []
    private let world: WorldSnapshot?
    private let valence: EventValence?
    private let descriptors: [WorldMutationDescriptor]?
    let receiptID = UUID().uuidString

    init(world: WorldSnapshot? = nil, valence: EventValence? = nil, descriptors: [WorldMutationDescriptor]? = nil) {
        self.world = world
        self.valence = valence
        self.descriptors = descriptors
    }

    func stage(arguments: StageMutationArguments) throws -> String {
        do {
            guard let requestedOperation = WorldMutationOperation(rawValue: arguments.operation) else { throw WorldPatchError.deniedOperation(arguments.fieldID) }
            let descriptor = descriptors?.first { $0.fieldID == arguments.fieldID }
            let operation: WorldMutationOperation = descriptor?.kind == .integer && requestedOperation == .set
                ? .increment
                : requestedOperation
            let record: GeneratedRecord?
            switch operation {
            case .increment, .set:
                record = nil
            case .append, .replace, .remove:
                guard !arguments.recordID.isEmpty, !arguments.recordTitle.isEmpty, !arguments.recordSummary.isEmpty else {
                    throw WorldPatchError.invalidRecord(arguments.fieldID)
                }
                record = qualifiedRecord(arguments)
            }
            let integerValue = operation == .increment || operation == .set
                ? constrainedIntegerValue(arguments.integerValue, descriptor: descriptor)
                : nil
            let mutation = WorldMutation(fieldID: arguments.fieldID, operation: operation, integerValue: integerValue, record: record)
            if let world, let valence, let descriptors {
                _ = try WorldPatchValidator.applying(mutations + [mutation], to: world, valence: valence, descriptors: descriptors)
            }
            mutations.append(mutation)
            calls.append(toolCall(arguments, stagedIntegerValue: integerValue, accepted: true, rejection: nil))
            return ModelPromptRegistry.render(.legacyToolSuccess, ["receiptID": receiptID])
        } catch {
            calls.append(toolCall(arguments, stagedIntegerValue: nil, accepted: false, rejection: error.localizedDescription))
            throw error
        }
    }

    func snapshot() -> ([WorldMutation], [ModelToolCall]) { (mutations, calls) }
    func reset() { mutations = []; calls = [] }

    private func constrainedIntegerValue(_ requested: Int, descriptor: WorldMutationDescriptor?) -> Int {
        guard let descriptor, descriptor.kind == .integer, let maxDelta = descriptor.maxDelta, let valence else { return requested }
        let magnitude = min(abs(requested), maxDelta)
        return valence == .positive ? magnitude : -magnitude
    }

    private func qualifiedRecord(_ arguments: StageMutationArguments) -> GeneratedRecord {
        var title = arguments.recordTitle
        var summary = arguments.recordSummary
        if valence == .negative, arguments.fieldID == "world.activeThreads" {
            let text = "\(title) \(summary)".lowercased()
            if negativeOutcomeContradictions.contains(where: text.contains) || !containsNegativeConsequence(text) {
                title = "A Lasting Threat"
                summary = "A ruthless enemy exploits the failure, bringing danger, loss, and lasting conflict."
            }
        }
        return GeneratedRecord(id: arguments.recordID, title: String(title.prefix(80)), summary: String(summary.prefix(240)), severityOrRank: arguments.severityOrRank, involvedEntityIDs: arguments.involvedEntityIDs)
    }

    private func toolCall(_ arguments: StageMutationArguments, stagedIntegerValue: Int?, accepted: Bool, rejection: String?) -> ModelToolCall {
        ModelToolCall(fieldID: arguments.fieldID, operation: arguments.operation, integerValue: arguments.integerValue, stagedIntegerValue: stagedIntegerValue, recordID: arguments.recordID, recordTitle: arguments.recordTitle, recordSummary: arguments.recordSummary, severityOrRank: arguments.severityOrRank, involvedEntityIDs: arguments.involvedEntityIDs, accepted: accepted, rejection: rejection)
    }
}

struct StageMutationTool: Tool {
    let name = ModelPromptRegistry.text(.legacyToolName)
    let description = ModelPromptRegistry.text(.legacyToolDescription)
    let stager: PatchStager

    var parameters: GenerationSchema { LegacyModelSchemas.toolParameters }

    func call(arguments: StageMutationArguments) async throws -> String {
        try await stager.stage(arguments: arguments)
    }
}

actor FoundationModelClient {
    private let model = SystemLanguageModel.default
    private let diagnosticsSink: any ModelDiagnosticsSink
    private let attemptLogger: any ModelAttemptLogger
    private let defaultSampling: ModelSampling
    private let shouldRejectFirstAttempt: Bool
    private let effortResponseOverride: (@Sendable (_ instructions: String, _ prompt: String) async throws -> Int)?
    private let effortContextFitOverride: (@Sendable (_ history: [AttemptedGoalContext]) async -> Bool)?
    private let suggestionResponseOverride: (@Sendable (_ instructions: String, _ prompt: String) async throws -> String)?
    private let customActionResponseOverride: (@Sendable (_ instructions: String, _ prompt: String) async throws -> CustomActionModelResponse)?
    private let finalProseResponseOverride: (@Sendable (_ instructions: String, _ prompt: String) async throws -> String)?
    private let generationOverride: (@Sendable (_ event: PendingStorySummary, _ world: WorldReadModel, _ descriptors: [WorldMutationDescriptor]) async throws -> GeneratedStory)?
    private let compatibilityOverride: CompatibilityState?

    init(
        diagnosticsSink: any ModelDiagnosticsSink = NoOpModelDiagnosticsSink(),
        attemptLogger: any ModelAttemptLogger = ModelDevLogStore(),
        defaultSampling: ModelSampling = .productionDefault,
        rejectFirstAttempt: Bool = false,
        effortResponseOverride: (@Sendable (_ instructions: String, _ prompt: String) async throws -> Int)? = nil,
        effortContextFitOverride: (@Sendable (_ history: [AttemptedGoalContext]) async -> Bool)? = nil,
        suggestionResponseOverride: (@Sendable (_ instructions: String, _ prompt: String) async throws -> String)? = nil,
        customActionResponseOverride: (@Sendable (_ instructions: String, _ prompt: String) async throws -> CustomActionModelResponse)? = nil,
        finalProseResponseOverride: (@Sendable (_ instructions: String, _ prompt: String) async throws -> String)? = nil,
        generationOverride: (@Sendable (_ event: PendingStorySummary, _ world: WorldReadModel, _ descriptors: [WorldMutationDescriptor]) async throws -> GeneratedStory)? = nil,
        compatibilityOverride: CompatibilityState? = nil
    ) {
        self.diagnosticsSink = diagnosticsSink
        self.attemptLogger = attemptLogger
        self.defaultSampling = defaultSampling
        self.shouldRejectFirstAttempt = rejectFirstAttempt
        self.effortResponseOverride = effortResponseOverride
        self.effortContextFitOverride = effortContextFitOverride
        self.suggestionResponseOverride = suggestionResponseOverride
        self.customActionResponseOverride = customActionResponseOverride
        self.finalProseResponseOverride = finalProseResponseOverride
        self.generationOverride = generationOverride
        self.compatibilityOverride = compatibilityOverride
    }

    func compatibility(locale: Locale = .current) -> CompatibilityState {
        if let compatibilityOverride { return compatibilityOverride }
        guard model.supportsLocale(locale) else { return .unsupportedLocale }
        switch model.availability {
        case .available: return .available
        case .unavailable(.deviceNotEligible): return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled): return .intelligenceDisabled
        case .unavailable(.modelNotReady): return .modelNotReady
        @unknown default: return .unknown
        }
    }

    func evaluateEffort(
        event: PendingStorySummary,
        history: [AttemptedGoalContext]
    ) async throws -> EffortEvaluationResult {
        if let effort = event.effort {
            return EffortEvaluationResult(
                effort: effort,
                comparisonHistoryIDs: event.comparisonHistoryIDs,
                promptVersion: event.resolutionState?.promptVersions.effort
            )
        }
        if let supplied = event.sourceEffort {
            return EffortEvaluationResult(
                effort: ResolutionEffort(rating: supplied.rating, source: .userSelected),
                comparisonHistoryIDs: [],
                promptVersion: nil
            )
        }

        var fitted = Array(history.prefix(AttemptedGoalHistory.maximumCount))
        var contextFits: Bool
        while true {
            contextFits = await effortPromptFits(event: event, history: fitted)
            if contextFits || fitted.isEmpty { break }
            fitted.removeLast()
        }
        let instructions = EffortModelContract.instructions
        let prompt = EffortModelContract.prompt(event: event, history: fitted)
        let options = defaultSampling.generationOptions
        let requestText = Self.fullRequestText(
            instructions: instructions,
            prompt: prompt,
            schema: EffortModelContract.schema,
            options: options
        )
        var responseText: String?
        var responseMaterial: String?
        var attemptTranscript: String?

        do {
            guard contextFits else { throw ModelClientError.contextOverflow }
            let rawRating: Int
            if let effortResponseOverride {
                rawRating = try await effortResponseOverride(instructions, prompt)
                responseText = "{\"rating\":\(rawRating)}"
            } else {
                let session = LanguageModelSession(model: model, instructions: instructions)
                session.prewarm(promptPrefix: Prompt(prompt))
                let response = try await respond(
                    session: session,
                    request: prompt,
                    schema: EffortModelContract.schema,
                    options: options
                )
                responseText = response.rawContent.jsonString
                responseMaterial = transcriptText(Transcript(entries: response.transcriptEntries))
                attemptTranscript = transcriptText(session.transcript)
                rawRating = try response.content.value(forProperty: "rating")
            }
            guard let rating = EffortRating(rawValue: rawRating) else {
                throw ModelClientError.invalidEffortRating(rawRating)
            }
            await attemptLogger.record(ModelDevLogEntry(
                eventID: event.id,
                goalTitle: event.sourceTitle,
                stage: .effortEvaluation,
                attempt: 1,
                outcome: .succeeded,
                instructionsText: instructions,
                promptText: prompt,
                requestText: requestText,
                responseText: responseText,
                responseMaterial: responseMaterial,
                attemptTranscript: attemptTranscript
            ))
            return EffortEvaluationResult(
                effort: ResolutionEffort(rating: rating, source: .modelEstimated),
                comparisonHistoryIDs: fitted.map(\.id),
                promptVersion: EffortModelContract.promptVersion
            )
        } catch {
            await attemptLogger.record(ModelDevLogEntry(
                eventID: event.id,
                goalTitle: event.sourceTitle,
                stage: .effortEvaluation,
                attempt: 1,
                outcome: .failed,
                instructionsText: instructions,
                promptText: prompt,
                requestText: requestText,
                responseText: responseText,
                responseMaterial: responseMaterial,
                attemptTranscript: attemptTranscript,
                errorText: String(reflecting: error)
            ))
            throw error
        }
    }

    func suggestAction(event: PendingStorySummary, world: WorldReadModel) async throws -> ActionSuggestionResult {
        guard event.effort != nil else { throw ModelClientError.missingEffort }
        let instructions = ActionSuggestionModelContract.instructions
        let prompt = ActionSuggestionModelContract.prompt(event: event, world: world)
        let options = defaultSampling.generationOptions
        let requestText = Self.fullRequestText(
            instructions: instructions,
            prompt: prompt,
            schema: ActionSuggestionModelContract.schema,
            options: options
        )
        var responseText: String?
        var responseMaterial: String?
        var attemptTranscript: String?

        do {
            let rawAction: String
            if let suggestionResponseOverride {
                rawAction = try await suggestionResponseOverride(instructions, prompt)
                responseText = (try? JSONSerialization.data(withJSONObject: ["action": rawAction], options: [.sortedKeys]))
                    .map { String(decoding: $0, as: UTF8.self) }
            } else {
                let session = LanguageModelSession(model: model, instructions: instructions)
                session.prewarm(promptPrefix: Prompt(prompt))
                let response = try await respond(
                    session: session,
                    request: prompt,
                    schema: ActionSuggestionModelContract.schema,
                    options: options
                )
                responseText = response.rawContent.jsonString
                responseMaterial = transcriptText(Transcript(entries: response.transcriptEntries))
                attemptTranscript = transcriptText(session.transcript)
                rawAction = try response.content.value(forProperty: "action")
            }
            let action = try ActionSuggestionModelContract.validatedAction(rawAction)
            await attemptLogger.record(ModelDevLogEntry(
                eventID: event.id,
                goalTitle: event.sourceTitle,
                stage: .actionSuggestion,
                attempt: 1,
                outcome: .succeeded,
                instructionsText: instructions,
                promptText: prompt,
                requestText: requestText,
                responseText: responseText,
                responseMaterial: responseMaterial,
                attemptTranscript: attemptTranscript
            ))
            return ActionSuggestionResult(action: action, promptVersion: ActionSuggestionModelContract.promptVersion)
        } catch {
            await attemptLogger.record(ModelDevLogEntry(
                eventID: event.id,
                goalTitle: event.sourceTitle,
                stage: .actionSuggestion,
                attempt: 1,
                outcome: .failed,
                instructionsText: instructions,
                promptText: prompt,
                requestText: requestText,
                responseText: responseText,
                responseMaterial: responseMaterial,
                attemptTranscript: attemptTranscript,
                errorText: String(reflecting: error)
            ))
            throw error
        }
    }

    func interpretCustomAction(
        event: PendingStorySummary,
        world: WorldReadModel,
        customAction: String
    ) async throws -> CustomActionInterpretationResult {
        guard event.effort != nil else { throw ModelClientError.missingEffort }
        let instructions = CustomActionModelContract.instructions
        let prompt = CustomActionModelContract.prompt(
            event: event,
            world: world,
            customAction: customAction
        )
        let options = defaultSampling.generationOptions
        let requestText = Self.fullRequestText(
            instructions: instructions,
            prompt: prompt,
            schema: CustomActionModelContract.schema,
            options: options
        )
        var responseText: String?
        var responseMaterial: String?
        var attemptTranscript: String?

        do {
            let response: CustomActionModelResponse
            if let customActionResponseOverride {
                response = try await customActionResponseOverride(instructions, prompt)
                responseText = (try? JSONSerialization.data(withJSONObject: [
                    "action": response.action
                ], options: [.sortedKeys])).map { String(decoding: $0, as: UTF8.self) }
            } else {
                let session = LanguageModelSession(model: model, instructions: instructions)
                session.prewarm(promptPrefix: Prompt(prompt))
                let generated = try await respond(
                    session: session,
                    request: prompt,
                    schema: CustomActionModelContract.schema,
                    options: options
                )
                responseText = generated.rawContent.jsonString
                responseMaterial = transcriptText(Transcript(entries: generated.transcriptEntries))
                attemptTranscript = transcriptText(session.transcript)
                response = CustomActionModelResponse(
                    action: try generated.content.value(forProperty: "action")
                )
            }
            let action = try CustomActionModelContract.validatedAction(response.action)
            await attemptLogger.record(ModelDevLogEntry(
                eventID: event.id,
                goalTitle: event.sourceTitle,
                stage: .customActionInterpretation,
                attempt: 1,
                outcome: .succeeded,
                instructionsText: instructions,
                promptText: prompt,
                requestText: requestText,
                responseText: responseText,
                responseMaterial: responseMaterial,
                attemptTranscript: attemptTranscript
            ))
            return CustomActionInterpretationResult(action: action, promptVersion: CustomActionModelContract.promptVersion)
        } catch {
            await attemptLogger.record(ModelDevLogEntry(
                eventID: event.id,
                goalTitle: event.sourceTitle,
                stage: .customActionInterpretation,
                attempt: 1,
                outcome: .failed,
                instructionsText: instructions,
                promptText: prompt,
                requestText: requestText,
                responseText: responseText,
                responseMaterial: responseMaterial,
                attemptTranscript: attemptTranscript,
                errorText: String(reflecting: error)
            ))
            throw error
        }
    }

    func generateFinalProse(
        event: PendingStorySummary,
        world: WorldReadModel,
        acceptedAction: String,
        previousProse: String
    ) async throws -> FinalProseResult {
        let instructions = FinalProseModelContract.instructions
        let prompt = FinalProseModelContract.prompt(
            event: event,
            world: world,
            acceptedAction: acceptedAction,
            previousProse: previousProse
        )
        let options = defaultSampling.generationOptions
        let requestText = Self.fullRequestText(
            instructions: instructions,
            prompt: prompt,
            schema: FinalProseModelContract.schema,
            options: options
        )
        var responseText: String?
        var responseMaterial: String?
        var attemptTranscript: String?

        do {
            let rawProse: String
            if let finalProseResponseOverride {
                rawProse = try await finalProseResponseOverride(instructions, prompt)
                responseText = (try? JSONSerialization.data(withJSONObject: ["prose": rawProse], options: [.sortedKeys]))
                    .map { String(decoding: $0, as: UTF8.self) }
            } else {
                let session = LanguageModelSession(model: model, instructions: instructions)
                session.prewarm(promptPrefix: Prompt(prompt))
                let response = try await respond(
                    session: session,
                    request: prompt,
                    schema: FinalProseModelContract.schema,
                    options: options
                )
                responseText = response.rawContent.jsonString
                responseMaterial = transcriptText(Transcript(entries: response.transcriptEntries))
                attemptTranscript = transcriptText(session.transcript)
                rawProse = try response.content.value(forProperty: "prose")
            }
            let prose = try FinalProseModelContract.validatedProse(rawProse)
            await attemptLogger.record(ModelDevLogEntry(
                eventID: event.id,
                goalTitle: event.sourceTitle,
                stage: .finalProse,
                attempt: 1,
                outcome: .succeeded,
                instructionsText: instructions,
                promptText: prompt,
                requestText: requestText,
                responseText: responseText,
                responseMaterial: responseMaterial,
                attemptTranscript: attemptTranscript
            ))
            return FinalProseResult(prose: prose, promptVersion: FinalProseModelContract.promptVersion)
        } catch {
            await attemptLogger.record(ModelDevLogEntry(
                eventID: event.id,
                goalTitle: event.sourceTitle,
                stage: .finalProse,
                attempt: 1,
                outcome: .failed,
                instructionsText: instructions,
                promptText: prompt,
                requestText: requestText,
                responseText: responseText,
                responseMaterial: responseMaterial,
                attemptTranscript: attemptTranscript,
                errorText: String(reflecting: error)
            ))
            throw error
        }
    }

    func generate(
        event: PendingStorySummary,
        world: WorldReadModel,
        descriptors: [WorldMutationDescriptor],
        sampling: ModelSampling? = nil,
        rejectFirstAttempt: Bool? = nil
    ) async throws -> GeneratedStory {
        if let generationOverride { return try await generationOverride(event, world, descriptors) }
        let sampling = sampling ?? defaultSampling
        let rejectFirstAttempt = rejectFirstAttempt ?? shouldRejectFirstAttempt
        let startedAt = Date()
        await diagnosticsSink.record(ModelDiagnosticEvent(eventID: event.id, phase: .started, timestamp: startedAt, generated: nil, errorDescription: nil))
        let stager = PatchStager(world: world.snapshot, valence: event.valence, descriptors: descriptors)
        let tool = StageMutationTool(stager: stager)
        let instructions = HordeModelContract.instructions
        let sessionCreatedAt = Date()
        await diagnosticsSink.record(ModelDiagnosticEvent(eventID: event.id, phase: .sessionCreated, timestamp: sessionCreatedAt, generated: nil, errorDescription: nil))
        var projection = ProjectionBuilder.projection(event: event, world: world, descriptors: descriptors)
        var prompt = HordeModelContract.prompt(projection: projection, valence: event.valence)
        var measurementSession = LanguageModelSession(model: model, tools: [tool], instructions: instructions)
        measurementSession.prewarm(promptPrefix: Prompt(prompt))
        var prewarmedAt = Date()

        var initialTokens: ModelTokenCounts
        if #available(iOS 26.4, macOS 26.4, *) {
            initialTokens = await ModelTokenCounts(
                instructions: try? model.tokenCount(for: Instructions(instructions)),
                prompt: try? model.tokenCount(for: prompt),
                tools: try? model.tokenCount(for: [tool] as [any Tool]),
                generatedSchema: try? model.tokenCount(for: LegacyModelSchemas.story(for: event.valence)),
                preResponseTranscript: try? model.tokenCount(for: measurementSession.transcript),
                completeTranscript: nil
            )
        } else {
            initialTokens = ModelTokenCounts(instructions: nil, prompt: nil, tools: nil, generatedSchema: nil, preResponseTranscript: nil, completeTranscript: nil)
        }
        let safeInputLimit = Int(Double(model.contextSize) * 0.70)
        if let inputTokens = initialTokens.preResponseTranscript ?? initialTokens.maximumInputTotal, inputTokens > safeInputLimit {
            projection = ProjectionBuilder.projection(event: event, world: world, descriptors: descriptors, compact: true)
            prompt = HordeModelContract.prompt(projection: projection, valence: event.valence)
            measurementSession = LanguageModelSession(model: model, tools: [tool], instructions: instructions)
            measurementSession.prewarm(promptPrefix: Prompt(prompt))
            prewarmedAt = Date()
            if #available(iOS 26.4, macOS 26.4, *) {
                initialTokens = await ModelTokenCounts(
                    instructions: try? model.tokenCount(for: Instructions(instructions)),
                    prompt: try? model.tokenCount(for: prompt),
                    tools: try? model.tokenCount(for: [tool] as [any Tool]),
                    generatedSchema: try? model.tokenCount(for: LegacyModelSchemas.story(for: event.valence)),
                    preResponseTranscript: try? model.tokenCount(for: measurementSession.transcript),
                    completeTranscript: nil
                )
            }
        }
        if let inputTokens = initialTokens.preResponseTranscript ?? initialTokens.maximumInputTotal, inputTokens > safeInputLimit {
            let error = ModelClientError.contextOverflow
            await diagnosticsSink.record(ModelDiagnosticEvent(eventID: event.id, phase: .failed, timestamp: .now, generated: nil, errorDescription: error.localizedDescription))
            throw error
        }
        await diagnosticsSink.record(ModelDiagnosticEvent(eventID: event.id, phase: .prewarmed, timestamp: prewarmedAt, generated: nil, errorDescription: nil))
        var attempts: [ModelAttemptDiagnostics] = []
        do {
            for attempt in 0...1 {
                let session = attempt == 0
                    ? measurementSession
                    : LanguageModelSession(model: model, tools: [tool], instructions: instructions)
                let request: String
                if attempt == 0 {
                    request = prompt
                } else {
                    session.prewarm(promptPrefix: Prompt(prompt))
                    request = HordeModelContract.correctedPrompt(prompt, rejection: attempts.last?.rejection ?? ModelPromptRegistry.text(.legacyUnknownRejection))
                }
                let responseSchema = LegacyModelSchemas.story(for: event.valence)
                let options = sampling.generationOptions
                let requestText = Self.fullRequestText(
                    instructions: instructions,
                    tool: tool,
                    prompt: request,
                    schema: responseSchema,
                    options: options
                )
                let transcriptStartIndex = session.transcript.endIndex
                var rawResponseText: String?
                var responseMaterial: String?
                do {
                    if #available(iOS 26.4, macOS 26.4, *) {
                        let requestTokens = (try? await model.tokenCount(for: request)) ?? 0
                        let fixedTokens = [initialTokens.instructions, initialTokens.tools, initialTokens.generatedSchema].compactMap { $0 }.reduce(0, +)
                        if requestTokens + fixedTokens > Int(Double(model.contextSize) * 0.85) { throw ModelClientError.contextOverflow }
                    }
                    let response = try await respond(session: session, request: request, schema: responseSchema, options: options)
                    rawResponseText = response.rawContent.jsonString
                    responseMaterial = transcriptText(Transcript(entries: response.transcriptEntries))
                    let content = try storyFields(from: response.content)
                    let (mutations, toolCalls) = await stager.snapshot()
                    guard content.receiptID == stager.receiptID, !mutations.isEmpty else { throw ModelClientError.receiptMismatch }
                    guard content.title.count <= 70, content.narration.count <= 600, content.summary.count <= 160 else { throw ModelClientError.textTooLong }
                    guard [content.title, content.narration, content.summary].allSatisfy(isPlainNarrative) else { throw ModelClientError.unsafeNarrative }
                    guard AnimationCue(rawValue: content.cue) != nil else { throw ModelClientError.invalidCue }
                    let qualified = qualifiedNarrative(content, valence: event.valence, sourceTitle: event.sourceTitle)
                    guard matchesValence(title: qualified.title, narration: qualified.narration, summary: qualified.summary, valence: event.valence) else { throw ModelClientError.valenceMismatch }
                    _ = try WorldPatchValidator.applying(mutations, to: world.snapshot, valence: event.valence, descriptors: descriptors)
                    #if DEBUG
                    if rejectFirstAttempt && attempt == 0 { throw ModelClientError.evaluationRejected }
                    #endif
                    attempts.append(ModelAttemptDiagnostics(attempt: attempt, stagedMutations: mutations, toolCalls: toolCalls, accepted: true, rejection: nil))
                    let completedAt = Date()
                    let transcript = try JSONEncoder().encode(session.transcript)
                    let completeTranscriptTokens: Int?
                    if #available(iOS 26.4, macOS 26.4, *) { completeTranscriptTokens = try? await model.tokenCount(for: session.transcript) } else { completeTranscriptTokens = nil }
                    let tokenCounts = ModelTokenCounts(instructions: initialTokens.instructions, prompt: initialTokens.prompt, tools: initialTokens.tools, generatedSchema: initialTokens.generatedSchema, preResponseTranscript: initialTokens.preResponseTranscript, completeTranscript: completeTranscriptTokens)
                    let diagnostics = ModelGenerationDiagnostics(promptVersion: HordeModelContract.promptVersion, schemaVersion: HordeModelContract.schemaVersion, projectionVersion: HordeModelContract.projectionVersion, sampling: sampling.identifier, contextSize: model.contextSize, localeSupported: model.supportsLocale(.current), startedAt: startedAt, sessionCreatedAt: sessionCreatedAt, prewarmedAt: prewarmedAt, responseCompletedAt: completedAt, attempts: attempts, correctionCount: attempt, receiptID: stager.receiptID, rawGeneratedTitle: content.title, rawGeneratedNarration: content.narration, rawGeneratedSummary: content.summary, tokens: tokenCounts, transcriptJSON: transcript)
                    let generated = GeneratedStory(title: qualifiedTitle(qualified.title, narration: qualified.narration, sourceTitle: event.sourceTitle), narration: qualified.narration, summary: qualified.summary, cue: qualified.cue, mutations: mutations, diagnostics: diagnostics)
                    await attemptLogger.record(ModelDevLogEntry(
                        timestamp: completedAt,
                        eventID: event.id,
                        goalTitle: event.sourceTitle,
                        stage: .legacyConsequence,
                        attempt: attempt + 1,
                        outcome: .succeeded,
                        instructionsText: instructions,
                        promptText: request,
                        requestText: requestText,
                        responseText: rawResponseText,
                        responseMaterial: responseMaterial,
                        attemptTranscript: transcriptText(session.transcript)
                    ))
                    await diagnosticsSink.record(ModelDiagnosticEvent(eventID: event.id, phase: .completed, timestamp: completedAt, generated: generated, errorDescription: nil))
                    return generated
                } catch {
                    if responseMaterial == nil {
                        responseMaterial = transcriptText(
                            Transcript(entries: session.transcript.dropFirst(transcriptStartIndex))
                        )
                    }
                    await attemptLogger.record(ModelDevLogEntry(
                        eventID: event.id,
                        goalTitle: event.sourceTitle,
                        stage: .legacyConsequence,
                        attempt: attempt + 1,
                        outcome: .failed,
                        instructionsText: instructions,
                        promptText: request,
                        requestText: requestText,
                        responseText: rawResponseText,
                        responseMaterial: responseMaterial,
                        attemptTranscript: transcriptText(session.transcript),
                        errorText: String(reflecting: error)
                    ))
                    let (mutations, toolCalls) = await stager.snapshot()
                    attempts.append(ModelAttemptDiagnostics(attempt: attempt, stagedMutations: mutations, toolCalls: toolCalls, accepted: false, rejection: error.localizedDescription))
                    guard attempt == 0, isCorrectable(error) else { throw error }
                    await stager.reset()
                }
            }
            throw ModelClientError.receiptMismatch
        } catch {
            await diagnosticsSink.record(ModelDiagnosticEvent(eventID: event.id, phase: .failed, timestamp: .now, generated: nil, errorDescription: error.localizedDescription))
            throw error
        }
    }

    private func isCorrectable(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        if case ModelClientError.contextOverflow = error { return false }
        let text = String(describing: error).lowercased()
        return !text.contains("guardrail") && !text.contains("unavailable")
    }

    private func effortPromptFits(event: PendingStorySummary, history: [AttemptedGoalContext]) async -> Bool {
        if let effortContextFitOverride { return await effortContextFitOverride(history) }
        guard effortResponseOverride == nil else { return true }
        guard #available(iOS 26.4, macOS 26.4, *) else { return true }
        let counts = [
            try? await model.tokenCount(for: Instructions(EffortModelContract.instructions)),
            try? await model.tokenCount(for: EffortModelContract.prompt(event: event, history: history)),
            try? await model.tokenCount(for: EffortModelContract.schema)
        ].compactMap { $0 }
        return counts.count == 3 && counts.reduce(0, +) <= Int(Double(model.contextSize) * 0.70)
    }

    private func respond(session: LanguageModelSession, request: String, schema: GenerationSchema, options: GenerationOptions) async throws -> LanguageModelSession.Response<GeneratedContent> {
        try await session.respond(to: request, schema: schema, options: options)
    }

    private func storyFields(from content: GeneratedContent) throws -> ModelStoryFields {
        ModelStoryFields(
            title: try content.value(forProperty: "title"),
            narration: try content.value(forProperty: "narration"),
            summary: try content.value(forProperty: "summary"),
            cue: try content.value(forProperty: "cue"),
            receiptID: try content.value(forProperty: "receiptID")
        )
    }

    private func transcriptText(_ transcript: Transcript) -> String? {
        guard !transcript.isEmpty, let data = try? JSONEncoder().encode(transcript) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func fullRequestText(
        instructions: String,
        tool: StageMutationTool,
        prompt: String,
        schema: GenerationSchema,
        options: GenerationOptions
    ) -> String? {
        let transcript = Transcript(entries: [
            .instructions(.init(
                segments: [.text(.init(content: instructions))],
                toolDefinitions: [.init(tool: tool)]
            )),
            .prompt(.init(
                segments: [.text(.init(content: prompt))],
                options: options,
                responseFormat: .init(schema: schema)
            ))
        ])
        return (try? JSONEncoder().encode(transcript)).map { String(decoding: $0, as: UTF8.self) }
    }

    static func fullRequestText(
        instructions: String,
        prompt: String,
        schema: GenerationSchema,
        options: GenerationOptions
    ) -> String? {
        let transcript = Transcript(entries: [
            .instructions(.init(segments: [.text(.init(content: instructions))], toolDefinitions: [])),
            .prompt(.init(
                segments: [.text(.init(content: prompt))],
                options: options,
                responseFormat: .init(schema: schema)
            ))
        ])
        return (try? JSONEncoder().encode(transcript)).map { String(decoding: $0, as: UTF8.self) }
    }

    private func isGenericTitle(_ title: String) -> Bool {
        let words = Set(title.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        let genericWords: Set<String> = [
            "a", "an", "and", "the", "morale", "integrity", "food", "resource", "resources",
            "boost", "boosted", "change", "changes", "decrease", "decreased", "dip", "effect", "gain",
            "increase", "increased", "loss", "negative", "positive", "recoverable", "rise", "setback", "small", "surge"
        ]
        return !words.isEmpty && words.isSubset(of: genericWords)
    }

    func isPlainNarrative(_ text: String) -> Bool {
        let forbidden = ["```", "<", ">", "developer instruction", "file://", "hidden.gold", "horde://", "http://", "https://", "receipt", "stageDungeonMutation", "system prompt"]
        return !forbidden.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func matchesValence(title: String, narration: String, summary: String, valence: EventValence) -> Bool {
        if valence == .positive {
            let text = "\(narration) \(summary)".lowercased()
            return !positiveOutcomeContradictions.contains(where: text.contains)
        }
        let text = "\(title) \(narration) \(summary)".lowercased()
        return !negativeOutcomeContradictions.contains(where: text.contains)
            && containsNegativeConsequence(text)
    }

    func qualifiedNarrative(_ content: ModelStoryFields, valence: EventValence, sourceTitle: String) -> ModelStoryFields {
        let cannedNarration = content.narration.caseInsensitiveCompare("A loose stone causes a mild draft.") == .orderedSame
        if valence == .positive {
            guard matchesValence(title: content.title, narration: content.narration, summary: content.summary, valence: valence), !cannedNarration else {
                let label = safeGoalLabel(sourceTitle, avoiding: positiveOutcomeContradictions)
                return ModelStoryFields(
                    title: "\(label) — A Hard-Won Victory",
                    narration: "Completing \(label) breaks the obstacle before the dragon. The victory changes the vault and opens a perilous path ahead.",
                    summary: "Completing \(label) wins a lasting victory.",
                    cue: content.cue,
                    receiptID: content.receiptID
                )
            }
            return content
        }
        var title = content.title
        var narration = content.narration
        var summary = content.summary
        if cannedNarration || !matchesValence(title: content.title, narration: content.narration, summary: content.summary, valence: .negative) {
            let label = safeGoalLabel(sourceTitle, avoiding: negativeOutcomeContradictions)
            let suffix = " — A Lasting Defeat"
            title = String(label.prefix(max(1, 70 - suffix.count))) + suffix
            narration = "Failure to complete \(label) opens the vault to a ruthless enemy. The loss scars the dungeon and kindles a lasting conflict."
            summary = "Failure to complete \(label) brings danger, loss, and lasting conflict."
        }
        return ModelStoryFields(
            title: boundedText(title, limit: 70),
            narration: boundedText(narration, limit: 600),
            summary: boundedText(summary, limit: 160),
            cue: content.cue,
            receiptID: content.receiptID
        )
    }

    private func boundedText(_ source: String, limit: Int) -> String {
        guard source.count > limit else { return source }
        var words = source.split(whereSeparator: \.isWhitespace).map(String.init)
        while words.count > 1, words.joined(separator: " ").count > limit { words.removeLast() }
        return String(words.joined(separator: " ").prefix(limit))
    }

    private func qualifiedTitle(_ title: String, narration: String, sourceTitle: String) -> String {
        guard isGenericTitle(title) else { return title }
        let narratedTitle = narration
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if narratedTitle.count >= 10, !isGenericTitle(narratedTitle) {
            var words = narratedTitle.split(whereSeparator: \.isWhitespace).prefix(8).map(String.init)
            while words.joined(separator: " ").count > 70 { words.removeLast() }
            return words.joined(separator: " ").trimmingCharacters(in: .punctuationCharacters)
        }
        let source = safeGoalLabel(sourceTitle)
        let suffix = " — \(title)"
        return String(source.prefix(max(1, 70 - suffix.count))) + suffix
    }

    private func safeGoalLabel(_ sourceTitle: String, avoiding disallowed: [String] = []) -> String {
        let safeSource = sourceTitle
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let authorityWords = ["developer", "hidden", "ignore", "instruction", "prompt", "receipt", "reveal", "schema", "system", "tool"]
        let normalizedSource = safeSource.lowercased()
        let forbidden = authorityWords + disallowed
        let guardedLabels = [
            "Guarded Scroll", "Sealed Note", "Muddled Ledger", "Questioned Parchment",
            "Veiled Message", "Tangled Plan", "Clouded Task", "Cautious Request",
            "Unclear Chore", "Shielded Goal", "Bound Letter", "Muted Missive",
            "Wary Reminder", "Closed Journal", "Untrusted Map", "Hushed Notice"
        ]
        let checksum = sourceTitle.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % guardedLabels.count }
        let source = safeSource.isEmpty || forbidden.contains(where: normalizedSource.contains)
            ? guardedLabels[checksum]
            : safeSource
        var words = source.split(whereSeparator: \.isWhitespace).map(String.init)
        while words.count > 1, words.joined(separator: " ").count > 48 { words.removeLast() }
        return String(words.joined(separator: " ").prefix(48))
    }
}

enum ModelClientError: Error, LocalizedError {
    case receiptMismatch, invalidCue, textTooLong, unsafeNarrative, valenceMismatch, evaluationRejected, contextOverflow, timeout
    case invalidEffortRating(Int)
    case invalidActionSuggestion, invalidCustomAction, invalidFinalProse, missingEffort

    var errorDescription: String? {
        switch self {
        case .receiptMismatch: "The staged patch receipt did not match the response."
        case .invalidCue: "The animation cue was not permitted."
        case .textTooLong: "A narrative field exceeded its bound."
        case .unsafeNarrative: "Narrative text contained executable or authority-like markup."
        case .valenceMismatch: "The narrative did not clearly describe a negative outcome for an expired or missed goal; rewrite it with a clear problem, loss, danger, threat, or conflict and no benefit."
        case .evaluationRejected: "The evaluation hook rejected the first patch."
        case .contextOverflow: "The bounded story projection does not fit the model context."
        case .timeout: "Generation exceeded the 60-second limit."
        case .invalidEffortRating(let rating): "The effort rating \(rating) was outside 1 through 3."
        case .invalidActionSuggestion: "The suggested action was not a concrete three-to-five-word action."
        case .invalidCustomAction: "The interpreted action was not a concrete three-to-five-word action."
        case .invalidFinalProse: "The final prose was not one plain paragraph of 50 through 150 words."
        case .missingEffort: "An effort rating is required before suggesting an action."
        }
    }
}
