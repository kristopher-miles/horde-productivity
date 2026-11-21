import Foundation
import FoundationModels
import Testing
@testable import TheHorde

@Suite("Production model completeness")
struct ModelProductionCompletenessTests {
    private let productionStages: [String: ModelRequestStageID] = [
        "evaluateEffort": .effortEvaluation,
        "suggestAction": .actionSuggestion,
        "interpretCustomAction": .customActionInterpretation,
        "generateFinalProse": .finalProse,
        "generate": .legacyConsequence
    ]

    @Test func everyProductionResponseCallAndPromptReferenceIsRegistered() throws {
        let audit = try ProductionModelSourceAudit.current()
        let calls = audit.responseCalls()
        let bridgeCalls = calls.filter { !["respond", "streamResponse"].contains($0.callee) }
        let stagedCalls = calls.filter { ["respond", "streamResponse"].contains($0.callee) }

        #expect(bridgeCalls == [
            .init(file: "TheHorde/Infrastructure/FoundationModels/FoundationModelClient.swift", function: "respond", callee: "session.respond")
        ])
        #expect(stagedCalls.count == productionStages.count)
        #expect(Set(stagedCalls.map(\.function)) == Set(productionStages.keys))
        for call in stagedCalls {
            let stage = try #require(productionStages[call.function])
            let block = try #require(audit.functionBlock(for: call))
            #expect(block.contains("stage: .\(stage.swiftCaseName)"))
        }

        let editorIDs = Set(ModelPromptRegistry.editorEntries.map { String(describing: $0.id) })
        let referencedIDs = audit.promptComponentReferences()
        #expect(referencedIDs.isSubset(of: editorIDs))
        for stage in ModelRequestStageID.allCases {
            let components = ModelPromptRegistry.components(for: stage)
            #expect(!components.isEmpty)
            #expect(components.allSatisfy { editorIDs.contains(String(describing: $0.id)) })
        }
    }

    @Test func syntheticUnregisteredCallAndComponentFailTheAudit() throws {
        let audit = try ProductionModelSourceAudit.current()
        let mutated = audit.adding(file: "TheHorde/FutureModel.swift", source: """
            func futureProductionCall() async throws {
                _ = try await respond(session: session, request: prompt, schema: schema, options: options)
                _ = session.streamResponse(to: prompt)
                _ = ModelPromptRegistry.text(.futureSystemInstructions)
            }
            """)

        let unknownFunctions = Set(mutated.responseCalls().filter {
            !($0.function == "respond" && $0.callee == "session.respond")
        }.map(\.function)).subtracting(productionStages.keys)
        let editorIDs = Set(ModelPromptRegistry.editorEntries.map { String(describing: $0.id) })
        let unknownComponents = mutated.promptComponentReferences().subtracting(editorIDs)

        #expect(unknownFunctions == ["futureProductionCall"])
        #expect(unknownComponents == ["futureSystemInstructions"])
    }

    @Test func everyProductionAttemptForwardsExactMaterialWithoutNormalization() throws {
        let audit = try ProductionModelSourceAudit.current()
        for (function, stage) in productionStages {
            let call = try #require(audit.responseCalls().first { $0.function == function && $0.callee == "respond" })
            let block = try #require(audit.functionBlock(for: call)).removingWhitespace
            #expect(block.occurrences(of: "ModelDevLogEntry(") == 2)
            #expect(block.occurrences(of: "stage:.\(stage.swiftCaseName)") == 2)
            #expect(block.occurrences(of: "outcome:.succeeded") == 1)
            #expect(block.occurrences(of: "outcome:.failed") == 1)
            #expect(block.occurrences(of: "instructionsText:instructions") == 2)
            #expect(block.occurrences(of: "requestText:requestText") == 2)
            #expect(block.occurrences(of: "responseMaterial:responseMaterial") == 2)
            #expect(block.occurrences(of: "errorText:String(reflecting:error)") == 1)

            if stage == .legacyConsequence {
                #expect(block.occurrences(of: "attempt:attempt+1") == 2)
                #expect(block.occurrences(of: "promptText:request") == 2)
                #expect(block.occurrences(of: "responseText:rawResponseText") == 2)
                #expect(block.occurrences(of: "attemptTranscript:transcriptText(session.transcript)") == 2)
                #expect(block.contains("rawResponseText=response.rawContent.jsonString"))
                #expect(block.contains("responseMaterial=transcriptText(Transcript(entries:response.transcriptEntries))"))
                #expect(block.contains("Transcript(entries:session.transcript.dropFirst(transcriptStartIndex))"))
                #expect(block.contains("forattemptin0...1"))
                #expect(block.contains("request=HordeModelContract.correctedPrompt"))
            } else {
                #expect(block.occurrences(of: "attempt:1") == 2)
                #expect(block.occurrences(of: "promptText:prompt") == 2)
                #expect(block.occurrences(of: "responseText:responseText") == 2)
                #expect(block.occurrences(of: "attemptTranscript:attemptTranscript") == 2)
                let response = stage == .customActionInterpretation ? "generated" : "response"
                #expect(block.contains("responseText=\(response).rawContent.jsonString"))
                #expect(block.contains("responseMaterial=transcriptText(Transcript(entries:\(response).transcriptEntries))"))
                #expect(block.contains("attemptTranscript=transcriptText(session.transcript)"))
            }
        }
    }

    @Test func injectableProductionPathsLogSuccessAndFailureByteExactly() async throws {
        for stage in [
            ModelRequestStageID.effortEvaluation,
            .actionSuggestion,
            .customActionInterpretation,
            .finalProse
        ] {
            for shouldFail in [false, true] {
                let logger = FidelityLogger()
                let fixture = FidelityFixture(stage: stage)
                let client = fixture.client(logger: logger, shouldFail: shouldFail)

                do {
                    try await fixture.invoke(client)
                    #expect(!shouldFail)
                } catch {
                    #expect(shouldFail)
                    #expect(String(reflecting: error) == String(reflecting: FidelityFailure.expected))
                }

                let entry = try #require(await logger.entries().only)
                #expect(entry.stage == stage)
                #expect(entry.attempt == 1)
                #expect(entry.outcome == (shouldFail ? .failed : .succeeded))
                #expect(Data(entry.instructionsText.utf8) == Data(fixture.instructions.utf8))
                #expect(Data(entry.promptText.utf8) == Data(fixture.prompt.utf8))
                let loggedRequest = try #require(entry.requestText)
                let envelope = try JSONDecoder().decode(Transcript.self, from: Data(loggedRequest.utf8))
                #expect(envelope.contains { item in
                    guard case .instructions(let value) = item else { return false }
                    return value.toolDefinitions.isEmpty && value.segments.contains { segment in
                        guard case .text(let text) = segment else { return false }
                        return Data(text.content.utf8) == Data(fixture.instructions.utf8)
                    }
                })
                #expect(envelope.contains { item in
                    guard case .prompt(let value) = item else { return false }
                    return value.responseFormat != nil && value.segments.contains { segment in
                        guard case .text(let text) = segment else { return false }
                        return Data(text.content.utf8) == Data(fixture.prompt.utf8)
                    }
                })
                #expect(entry.responseText.map { Data($0.utf8) } == (shouldFail ? nil : fixture.responseText.map { Data($0.utf8) }))
                #expect(entry.responseMaterial == nil)
                #expect(entry.attemptTranscript == nil)
                #expect(entry.errorText == (shouldFail ? String(reflecting: FidelityFailure.expected) : nil))
            }
        }
    }

}

private struct FidelityFixture {
    let stage: ModelRequestStageID
    let event: PendingStorySummary
    let world = WorldReadModel(dungeonName: "Café Vault 🐉", revision: 7, snapshot: .initial())
    let finalProse = (1...50).map { "ember\($0)" }.joined(separator: " ")

    init(stage: ModelRequestStageID) {
        self.stage = stage
        var event = PendingStorySummary(
            id: "fidelity-\(stage.rawValue)",
            sourceTitle: "Forge café 🐉\nGate",
            sourceNotes: "Keep trailing space ",
            valence: .positive,
            status: .pending,
            failureCode: nil,
            createdAt: .distantPast
        )
        if stage != .effortEvaluation {
            event.effort = ResolutionEffort(rating: .two, source: .modelEstimated)
        }
        self.event = event
    }

    var instructions: String {
        switch stage {
        case .effortEvaluation: EffortModelContract.instructions
        case .actionSuggestion: ActionSuggestionModelContract.instructions
        case .customActionInterpretation: CustomActionModelContract.instructions
        case .finalProse: FinalProseModelContract.instructions
        case .legacyConsequence: HordeModelContract.instructions
        }
    }

    var prompt: String {
        switch stage {
        case .effortEvaluation:
            EffortModelContract.prompt(event: event, history: [])
        case .actionSuggestion:
            ActionSuggestionModelContract.prompt(event: event, world: world)
        case .customActionInterpretation:
            CustomActionModelContract.prompt(event: event, world: world, customAction: "Scout café beyond walls ")
        case .finalProse:
            FinalProseModelContract.prompt(event: event, world: world, acceptedAction: "Raise the iron gate", previousProse: "Prior prose\r\nexact ")
        case .legacyConsequence:
            ""
        }
    }

    var responseText: String? {
        switch stage {
        case .effortEvaluation: "{\"rating\":2}"
        case .actionSuggestion: "{\"action\":\"Raise the iron gate\"}"
        case .customActionInterpretation: "{\"action\":\"Scout the obsidian road\"}"
        case .finalProse: "{\"prose\":\"\(finalProse)\"}"
        case .legacyConsequence: nil
        }
    }

    func client(logger: FidelityLogger, shouldFail: Bool) -> FoundationModelClient {
        FoundationModelClient(
            attemptLogger: logger,
            defaultSampling: .productionDefault,
            effortResponseOverride: { _, _ in
                if shouldFail { throw FidelityFailure.expected }
                return 2
            },
            suggestionResponseOverride: { _, _ in
                if shouldFail { throw FidelityFailure.expected }
                return "Raise the iron gate"
            },
            customActionResponseOverride: { _, _ in
                if shouldFail { throw FidelityFailure.expected }
                return CustomActionModelResponse(action: "Scout the obsidian road")
            },
            finalProseResponseOverride: { _, _ in
                if shouldFail { throw FidelityFailure.expected }
                return finalProse
            }
        )
    }

    func invoke(_ client: FoundationModelClient) async throws {
        switch stage {
        case .effortEvaluation:
            _ = try await client.evaluateEffort(event: event, history: [])
        case .actionSuggestion:
            _ = try await client.suggestAction(event: event, world: world)
        case .customActionInterpretation:
            _ = try await client.interpretCustomAction(
                event: event,
                world: world,
                customAction: "Scout café beyond walls "
            )
        case .finalProse:
            _ = try await client.generateFinalProse(
                event: event,
                world: world,
                acceptedAction: "Raise the iron gate",
                previousProse: "Prior prose\r\nexact "
            )
        case .legacyConsequence:
            Issue.record("Legacy uses the source-audited FoundationModels path")
        }
    }
}

private enum FidelityFailure: Error {
    case expected
}

private actor FidelityLogger: ModelAttemptLogger {
    private var captured: [ModelDevLogEntry] = []
    func record(_ entry: ModelDevLogEntry) { captured.append(entry) }
    func entries() -> [ModelDevLogEntry] { captured }
}

private struct ProductionModelSourceAudit {
    struct ResponseCall: Equatable, Hashable {
        let file: String
        let function: String
        let callee: String
    }

    let sources: [String: String]

    static func current() throws -> Self {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let sourceRoot = root.appending(path: "TheHorde", directoryHint: .isDirectory)
        let enumerator = try #require(FileManager.default.enumerator(at: sourceRoot, includingPropertiesForKeys: nil))
        var sources: [String: String] = [:]
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
            sources[relative] = try String(contentsOf: url, encoding: .utf8)
        }
        return Self(sources: sources)
    }

    func adding(file: String, source: String) -> Self {
        var copy = sources
        copy[file] = source
        return Self(sources: copy)
    }

    func responseCalls() -> [ResponseCall] {
        let pattern = #"\b((?:[A-Za-z_][A-Za-z0-9_]*\s*\.\s*)?(?:respond|streamResponse))\s*\("#
        let regex = try! NSRegularExpression(pattern: pattern)
        return sources.flatMap { file, source in
            let range = NSRange(source.startIndex..., in: source)
            return regex.matches(in: source, range: range).compactMap { match -> ResponseCall? in
                guard let callRange = Range(match.range(at: 1), in: source),
                      source[..<callRange.lowerBound].split(whereSeparator: { !$0.isLetter }).last != "func",
                      let function = enclosingFunction(at: match.range.location, in: source) else { return nil }
                let callee = source[callRange].filter { !$0.isWhitespace }
                return ResponseCall(file: file, function: function, callee: String(callee))
            }
        }.sorted { ($0.file, $0.function, $0.callee) < ($1.file, $1.function, $1.callee) }
    }

    func promptComponentReferences() -> Set<String> {
        let pattern = #"ModelPromptRegistry\s*\.\s*(?:text|render)\s*\(\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        return Set(sources.values.flatMap { source in
            regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).compactMap { match in
                Range(match.range(at: 1), in: source).map { String(source[$0]) }
            }
        })
    }

    func functionBlock(for call: ResponseCall) -> String? {
        guard let source = sources[call.file] else { return nil }
        let pattern = #"(?m)^[ \t]{4}(?:(?:private|nonisolated|static|final)\s+)*func\s+([A-Za-z_][A-Za-z0-9_]*)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
        guard let index = matches.firstIndex(where: { match in
            Range(match.range(at: 1), in: source).map { source[$0] == call.function[...] } == true
        }), let start = Range(matches[index].range, in: source)?.lowerBound else { return nil }
        let end = index + 1 < matches.count
            ? Range(matches[index + 1].range, in: source)!.lowerBound
            : source.endIndex
        return String(source[start..<end])
    }

    private func enclosingFunction(at location: Int, in source: String) -> String? {
        let prefix = NSRange(location: 0, length: location)
        let regex = try! NSRegularExpression(pattern: #"\bfunc\s+([A-Za-z_][A-Za-z0-9_]*)"#)
        guard let match = regex.matches(in: source, range: prefix).last,
              let range = Range(match.range(at: 1), in: source) else { return nil }
        return String(source[range])
    }
}

private extension ModelRequestStageID {
    var swiftCaseName: String {
        switch self {
        case .effortEvaluation: "effortEvaluation"
        case .actionSuggestion: "actionSuggestion"
        case .customActionInterpretation: "customActionInterpretation"
        case .finalProse: "finalProse"
        case .legacyConsequence: "legacyConsequence"
        }
    }
}

private extension String {
    var removingWhitespace: String { filter { !$0.isWhitespace } }

    func occurrences(of needle: String) -> Int {
        components(separatedBy: needle).count - 1
    }
}

private extension Collection {
    var only: Element? { count == 1 ? first : nil }
}
