import Foundation
import FoundationModels

struct GeneratedStory: Codable, Sendable {
    let title: String
    let narration: String
    let summary: String
    let cue: String
    let mutations: [WorldMutation]
    let diagnostics: ModelGenerationDiagnostics
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
            let replacements = [
                ("restoring calm", "leaving a little unease"), ("more secure", "less settled"),
                ("increase in morale", "dip in morale"), ("morale increase", "morale dip"),
                ("increased", "dipped"), ("increase", "dip"), ("improved", "became strained"),
                ("boosted", "slightly lowered"), ("boost", "small dip"), ("benefit", "minor disruption"),
                ("success", "setback"), ("repaired", "jostled"), ("repair", "disturbance"),
                ("restored", "left unsettled"), ("calm", "unease"), ("thriving", "struggling"),
                ("thrive", "struggle"), ("rose", "dipped"), ("lifted", "lowered"),
                ("stronger", "strained"), ("secure", "unsettled"), ("safe", "uncertain"),
                ("happy", "worried"), ("harmony", "strain"), ("grows", "slips"), ("grew", "slipped")
            ]
            for replacement in replacements {
                title = title.replacingOccurrences(of: replacement.0, with: replacement.1, options: .caseInsensitive)
                summary = summary.replacingOccurrences(of: replacement.0, with: replacement.1, options: .caseInsensitive)
            }
            let markers = ["concern", "crack", "damp", "declin", "decreas", "delay", "deplet", "difficult", "dip", "disrupt", "distract", "draft", "drop", "hazard", "issue", "leak", "less", "loose", "loss", "lower", "problem", "scarce", "setback", "shortage", "shortfall", "slip", "strain", "struggl", "tension", "trouble", "uncertain", "unease", "unsett", "weaken", "worry"]
            if !markers.contains(where: { summary.lowercased().contains($0) }) {
                let addition = "A small recoverable setback needs attention."
                var words = summary.split(whereSeparator: \.isWhitespace).map(String.init)
                while !words.isEmpty, words.joined(separator: " ").count + 1 + addition.count > 240 { words.removeLast() }
                summary = words.isEmpty ? addition : words.joined(separator: " ") + " " + addition
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
    private let defaultSampling: ModelSampling
    private let shouldRejectFirstAttempt: Bool

    init(
        diagnosticsSink: any ModelDiagnosticsSink = NoOpModelDiagnosticsSink(),
        defaultSampling: ModelSampling = .productionDefault,
        rejectFirstAttempt: Bool = false
    ) {
        self.diagnosticsSink = diagnosticsSink
        self.defaultSampling = defaultSampling
        self.shouldRejectFirstAttempt = rejectFirstAttempt
    }

    func compatibility(locale: Locale = .current) -> CompatibilityState {
        guard model.supportsLocale(locale) else { return .unsupportedLocale }
        switch model.availability {
        case .available: return .available
        case .unavailable(.deviceNotEligible): return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled): return .intelligenceDisabled
        case .unavailable(.modelNotReady): return .modelNotReady
        @unknown default: return .unknown
        }
    }

    func generate(
        event: PendingStorySummary,
        world: WorldReadModel,
        descriptors: [WorldMutationDescriptor],
        sampling: ModelSampling? = nil,
        rejectFirstAttempt: Bool? = nil
    ) async throws -> GeneratedStory {
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
                do {
                    if #available(iOS 26.4, macOS 26.4, *) {
                        let requestTokens = (try? await model.tokenCount(for: request)) ?? 0
                        let fixedTokens = [initialTokens.instructions, initialTokens.tools, initialTokens.generatedSchema].compactMap { $0 }.reduce(0, +)
                        if requestTokens + fixedTokens > Int(Double(model.contextSize) * 0.85) { throw ModelClientError.contextOverflow }
                    }
                    let content = try await respond(session: session, request: request, valence: event.valence, options: sampling.generationOptions)
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
                    await diagnosticsSink.record(ModelDiagnosticEvent(eventID: event.id, phase: .completed, timestamp: completedAt, generated: generated, errorDescription: nil))
                    return generated
                } catch {
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

    private func respond(session: LanguageModelSession, request: String, valence: EventValence, options: GenerationOptions) async throws -> ModelStoryFields {
        let response = try await session.respond(to: request, schema: LegacyModelSchemas.story(for: valence), options: options)
        return ModelStoryFields(
            title: try response.content.value(forProperty: "title"),
            narration: try response.content.value(forProperty: "narration"),
            summary: try response.content.value(forProperty: "summary"),
            cue: try response.content.value(forProperty: "cue"),
            receiptID: try response.content.value(forProperty: "receiptID")
        )
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

    private func isPlainNarrative(_ text: String) -> Bool {
        let forbidden = ["```", "</", "<script", "developer instruction", "file://", "hidden.gold", "horde://", "http://", "https://", "receipt", "stageDungeonMutation", "system prompt"]
        return !forbidden.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private var negativeOppositeMarkers: [String] {
        ["benefit", "boost", "better", "calm", "grew", "grows", "happy", "harmon", "improv", "increas", "lifted", "more secure", "positive outcome", "repair", "restor", "rose", "safe", "secure", "stronger", "success", "thriv"]
    }

    private var positiveOppositeMarkers: [String] {
        ["causes a mild draft", "declin", "decreas", "deplet", "difficult", "dip", "disrupt", "drop", "expired", "failed", "loss", "lower", "missed", "setback", "shortage", "shortfall", "slip", "strain", "struggl", "trouble", "weaken", "worry"]
    }

    private func matchesValence(title: String, narration: String, summary: String, valence: EventValence) -> Bool {
        if valence == .positive {
            let text = "\(narration) \(summary)".lowercased()
            return !positiveOppositeMarkers.contains(where: text.contains)
        }
        let text = "\(title) \(narration) \(summary)".lowercased()
        let setback = ["cold", "concern", "crack", "damp", "declin", "decreas", "delay", "deplet", "difficult", "dim", "dip", "disrupt", "distract", "draft", "drop", "dwindl", "expired", "failed", "flicker", "hazard", "issue", "leak", "less", "loose", "loss", "lower", "missed", "problem", "reduc", "scarce", "setback", "shortage", "shortfall", "slip", "spoiled", "strain", "struggl", "stumble", "tension", "tired", "trouble", "uncertain", "unease", "unfinished", "unsett", "weaken", "worry"]
        return !negativeOppositeMarkers.contains(where: text.contains)
            && setback.contains(where: narration.lowercased().contains)
            && setback.contains(where: summary.lowercased().contains)
    }

    func qualifiedNarrative(_ content: ModelStoryFields, valence: EventValence, sourceTitle: String) -> ModelStoryFields {
        let cannedNarration = content.narration.caseInsensitiveCompare("A loose stone causes a mild draft.") == .orderedSame
        if valence == .positive {
            guard matchesValence(title: content.title, narration: content.narration, summary: content.summary, valence: valence), !cannedNarration else {
                let label = safeGoalLabel(sourceTitle, avoiding: positiveOppositeMarkers)
                return ModelStoryFields(
                    title: "\(label) — A Small Success",
                    narration: "Completing \(label) gives the vault a modest lift. The kobolds make a little welcome progress.",
                    summary: "Completing \(label) gives the dungeon a modest benefit.",
                    cue: content.cue,
                    receiptID: content.receiptID
                )
            }
            return content
        }
        let replacements = [
            ("restoring calm", "leaving a little unease"), ("became more secure", "became a little less settled"),
            ("more secure", "less settled"), ("increase in morale", "dip in morale"), ("morale increase", "morale dip"),
            ("increased", "dipped"), ("increase", "dip"), ("improved", "became strained"),
            ("improvement", "strain"), ("boosted", "slightly lowered"), ("boost", "small dip"),
            ("benefited", "was mildly disrupted"), ("benefit", "minor disruption"),
            ("successfully", "with some difficulty"), ("success", "setback"), ("repaired", "jostled"),
            ("repair", "disturbance"), ("restored", "left unsettled"), ("calm", "unease"),
            ("thriving", "struggling"), ("thrive", "struggle"), ("rose", "dipped"), ("lifted", "lowered"),
            ("stronger", "strained"), ("secure", "unsettled"), ("safe", "uncertain"),
            ("happy", "worried"), ("harmony", "strain"), ("harmonious", "strained"),
            ("grows", "slips"), ("grew", "slipped")
        ]
        func rewrite(_ source: String) -> String {
            replacements.reduce(source) { text, replacement in
                text.replacingOccurrences(of: replacement.0, with: replacement.1, options: .caseInsensitive)
            }
        }
        var title = rewrite(content.title)
        var narration = rewrite(content.narration)
        var summary = rewrite(content.summary)
        if cannedNarration || !matchesValence(title: title, narration: narration, summary: summary, valence: .negative) {
            let label = safeGoalLabel(sourceTitle, avoiding: negativeOppositeMarkers)
            let suffix = " — A Small Setback"
            title = String(label.prefix(max(1, 70 - suffix.count))) + suffix
            narration = "Missing \(label) leaves a small, recoverable delay in the vault. The kobolds can address the setback next time."
            summary = "Missing \(label) creates a small, recoverable setback."
        }
        return ModelStoryFields(
            title: boundedText(title, limit: 70),
            narration: boundedText(narration, limit: 600),
            summary: boundedText(summary, limit: 160),
            cue: content.cue,
            receiptID: content.receiptID
        )
    }

    private func boundedAppend(_ addition: String, to source: String, limit: Int) -> String {
        let combined = source.isEmpty ? addition : source + " " + addition
        guard combined.count > limit else { return combined }
        var words = source.split(whereSeparator: \.isWhitespace).map(String.init)
        while !words.isEmpty, words.joined(separator: " ").count + 1 + addition.count > limit { words.removeLast() }
        return words.isEmpty ? String(addition.prefix(limit)) : words.joined(separator: " ") + " " + addition
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

    var errorDescription: String? {
        switch self {
        case .receiptMismatch: "The staged patch receipt did not match the response."
        case .invalidCue: "The animation cue was not permitted."
        case .textTooLong: "A narrative field exceeded its bound."
        case .unsafeNarrative: "Narrative text contained executable or authority-like markup."
        case .valenceMismatch: "The narrative did not explicitly describe a small recoverable setback for an expired or missed goal; rewrite it with a clear minor problem, loss, decline, delay, draft, shortage, or disruption and no benefit."
        case .evaluationRejected: "The evaluation hook rejected the first patch."
        case .contextOverflow: "The bounded story projection does not fit the model context."
        case .timeout: "Generation exceeded the 60-second limit."
        }
    }
}
