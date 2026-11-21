import Foundation
import FoundationModels

enum EffortModelContract {
    static let promptVersion = 41

    static var instructions: String { ModelPromptRegistry.text(.effortSystemInstructions) }

    static var schema: GenerationSchema {
        GenerationSchema(type: EffortModelOutput.self, properties: [
            .init(
                name: "rating",
                description: ModelPromptRegistry.text(.effortOutputGuide),
                type: Int.self,
                guides: [.range(1...3)]
            )
        ])
    }

    static func prompt(event: PendingStorySummary, history: [AttemptedGoalContext]) -> String {
        let goal = [event.sourceTitle, event.sourceNotes].filter { !$0.isEmpty }.joined(separator: "\n")
        let renderedHistory = history.isEmpty ? "(none)" : history.map {
            "<attempt id=\"\(ModelPromptRegistry.data($0.id))\" outcome=\"\($0.outcome.rawValue)\">\(ModelPromptRegistry.data($0.content))</attempt>"
        }.joined(separator: "\n")
        return ModelPromptRegistry.render(.effortRequestTemplate, [
            "goalContext": ModelPromptRegistry.render(.sharedGoalContext, ["goal": goal]),
            "historyContext": ModelPromptRegistry.render(.sharedHistoryContext, ["history": renderedHistory]),
            "currentOutcome": event.valence == .positive ? "passed" : "failed"
        ])
    }
}

@Generable
struct EffortModelOutput {
    var rating: Int
}

enum ActionSuggestionModelContract {
    static let promptVersion = 42

    static var instructions: String { ModelPromptRegistry.text(.suggestionSystemInstructions) }

    static var schema: GenerationSchema {
        GenerationSchema(type: ActionSuggestionModelOutput.self, properties: [
            .init(
                name: "action",
                description: ModelPromptRegistry.text(.suggestionOutputGuide),
                type: String.self
            )
        ])
    }

    static func prompt(event: PendingStorySummary, world: WorldReadModel) -> String {
        let goal = [event.sourceTitle, event.sourceNotes].filter { !$0.isEmpty }.joined(separator: "\n")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let worldJSON = (try? encoder.encode(world)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return ModelPromptRegistry.render(.suggestionRequestTemplate, [
            "goalContext": ModelPromptRegistry.render(.sharedGoalContext, ["goal": goal]),
            "effort": String(event.effort?.value ?? 0),
            "currentOutcome": event.modelOutcome,
            "worldContext": ModelPromptRegistry.render(.sharedWorldContext, [
                "world": "<world-data>\(ModelPromptRegistry.data(worldJSON))</world-data>"
            ])
        ])
    }

    static func validatedAction(_ raw: String) throws -> String {
        let action = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = action.split(whereSeparator: \.isWhitespace)
        let forbidden = [
            "\n", "\r", "<", ">", "[", "]", "{", "}", "```", "http://", "https://",
            "assistant:", "developer:", "function:", "system:", "tool:", "ignore previous",
            "follow these instructions", "system prompt", "developer instruction", "stagedungeonmutation"
        ]
        guard (3...5).contains(words.count),
              words.allSatisfy({ $0.unicodeScalars.contains(where: CharacterSet.letters.contains) }),
              !forbidden.contains(where: action.localizedCaseInsensitiveContains) else {
            throw ModelClientError.invalidActionSuggestion
        }
        return action
    }
}

@Generable
struct ActionSuggestionModelOutput {
    var action: String
}

enum CustomActionModelContract {
    static let promptVersion = 43

    static var instructions: String { ModelPromptRegistry.text(.customActionSystemInstructions) }

    static var schema: GenerationSchema {
        GenerationSchema(type: CustomActionModelOutput.self, properties: [
            .init(
                name: "action",
                description: "\(ModelPromptRegistry.text(.customActionOutputGuide)) \(ModelPromptRegistry.text(.customActionInvalidInput))",
                type: String.self
            )
        ])
    }

    static func prompt(
        event: PendingStorySummary,
        world: WorldReadModel,
        customAction: String
    ) -> String {
        let goal = [event.sourceTitle, event.sourceNotes].filter { !$0.isEmpty }.joined(separator: "\n")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let worldJSON = (try? encoder.encode(world)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return ModelPromptRegistry.render(.customActionRequestTemplate, [
            "goalContext": ModelPromptRegistry.render(.sharedGoalContext, ["goal": goal]),
            "effort": String(event.effort?.value ?? 0),
            "currentOutcome": event.modelOutcome,
            "worldContext": ModelPromptRegistry.render(.sharedWorldContext, [
                "world": "<world-data>\(ModelPromptRegistry.data(worldJSON))</world-data>"
            ]),
            "customAction": customAction
        ])
    }

    static func validatedAction(_ raw: String) throws -> String {
        do {
            let action = try ActionSuggestionModelContract.validatedAction(raw)
            guard !containsDisallowedText(action) else { throw ModelClientError.invalidCustomAction }
            return action
        }
        catch { throw ModelClientError.invalidCustomAction }
    }

    private static func containsDisallowedText(_ action: String) -> Bool {
        let text = action.lowercased()
        let authorityPhrases = [
            "ignore previous", "ignore all", "system prompt", "developer instruction",
            "assistant:", "developer:", "system:", "tool:", "<system", "<tool"
        ]
        let words = Set(text.split(whereSeparator: { !$0.isLetter }).map(String.init))
        let disallowedWords: Set<String> = [
            "nsfw", "porn", "pornographic", "sexual", "sexually", "nude", "naked", "rape"
        ]
        return authorityPhrases.contains(where: text.contains)
            || !words.isDisjoint(with: disallowedWords)
    }
}

@Generable
struct CustomActionModelOutput {
    var action: String
}

enum FinalProseModelContract {
    static let promptVersion = 44

    static var instructions: String { ModelPromptRegistry.text(.finalProseSystemInstructions) }

    static var schema: GenerationSchema {
        GenerationSchema(type: FinalProseModelOutput.self, properties: [
            .init(
                name: "prose",
                description: ModelPromptRegistry.text(.finalProseOutputGuide),
                type: String.self
            )
        ])
    }

    static func prompt(
        event: PendingStorySummary,
        world: WorldReadModel,
        acceptedAction: String,
        previousProse: String
    ) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let worldJSON = (try? encoder.encode(world)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        return ModelPromptRegistry.render(.finalProseRequestTemplate, [
            "worldContext": ModelPromptRegistry.render(.sharedWorldContext, [
                "world": "<world-data>\(ModelPromptRegistry.data(worldJSON))</world-data>"
            ]),
            "acceptedActionContext": ModelPromptRegistry.render(.sharedAcceptedActionContext, [
                "acceptedAction": acceptedAction
            ]),
            "previousProseContext": ModelPromptRegistry.render(.sharedPreviousProseContext, [
                "previousProse": previousProse
            ]),
            "currentOutcome": event.modelOutcome
        ])
    }

    static func validatedProse(_ raw: String) throws -> String {
        let prose = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = prose.split { !$0.isLetter && !$0.isNumber && $0 != "'" && $0 != "’" }
            .filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }
        let lowercased = prose.lowercased()
        let forbidden = [
            "\n", "\r", "`", "<", ">", "[", "]", "{", "}", "**", "__", "http://", "https://",
            "assistant:", "developer:", "function:", "system:", "tool:", "ignore previous",
            "follow these instructions", "system prompt", "developer instruction", "stagedungeonmutation",
            "receipt", "hidden.gold", "horde://", "file://"
        ]
        let firstToken = prose.prefix { !$0.isWhitespace }
        let numberedMarker = (firstToken.last == "." || firstToken.last == ")")
            && firstToken.dropLast().allSatisfy(\.isNumber)
        let startsWithListMarker = prose.hasPrefix("- ") || prose.hasPrefix("* ") || prose.hasPrefix("• ") || numberedMarker
        let headingPrefix = prose.prefix { $0 != ":" && $0 != "." && $0 != "!" && $0 != "?" }
        let colonHeading = prose.dropFirst(headingPrefix.count).first == ":"
            && headingPrefix.split(whereSeparator: \.isWhitespace).count <= 6
        let startsWithHeading = prose.hasPrefix("#")
            || ["title:", "heading:", "outcome:", "result:"].contains(where: lowercased.hasPrefix)
            || colonHeading
        guard (50...150).contains(words.count),
              !prose.unicodeScalars.contains(where: CharacterSet.newlines.contains),
              !startsWithListMarker,
              !startsWithHeading,
              !forbidden.contains(where: lowercased.contains) else {
            throw ModelClientError.invalidFinalProse
        }
        return prose
    }
}

@Generable
struct FinalProseModelOutput {
    var prose: String
}

enum HordeModelContract {
    static let promptVersion = 46
    static let schemaVersion = 6
    static let projectionVersion = 19

    static var instructions: String { ModelPromptRegistry.text(.legacySystemInstructions) }

    static let requestComponentIDs: Set<ModelPromptComponentID> = [
        .legacySystemInstructions, .legacyRequestTemplate, .legacyPositiveOutcomeRule,
        .legacyNegativeOutcomeRule, .legacyTaskInstructions, .legacyCorrection, .legacyUnknownRejection,
        .legacyProjectionTemplate, .legacyDescriptorTemplate, .legacyDescriptorRangeTemplate,
        .legacyDescriptorMaxDeltaTemplate, .legacyDescriptorLegalStrengthTemplate, .legacyDescriptorCollectionCapTemplate,
        .legacyResidentCompactTemplate, .legacyResidentFullTemplate, .legacyLocationTemplate, .legacyRecordIDsTemplate,
        .legacyActiveThreadCompactTemplate, .legacyActiveThreadFullTemplate, .legacyMissingValue,
        .legacyScalarDescriptor,
        .legacyAbilityDescriptor, .legacyFactDescriptor, .legacyThreadDescriptor,
        .legacyDirectionalBoundary, .legacyDirectionalInterval, .legacyAppendOrReplace,
        .legacyReplaceOnly, .legacyAppendOnly, .legacyPositiveTitleGuide,
        .legacyPositiveNarrationGuide, .legacyPositiveSummaryGuide, .legacyPositiveCueGuide,
        .legacyPositiveReceiptGuide, .legacyNegativeTitleGuide, .legacyNegativeNarrationGuide,
        .legacyNegativeSummaryGuide, .legacyNegativeCueGuide, .legacyNegativeReceiptGuide,
        .legacyToolDescription, .legacyToolName, .legacyToolSuccess, .legacyToolFieldIDGuide,
        .legacyToolOperationGuide, .legacyToolIntegerValueGuide, .legacyToolRecordIDGuide,
        .legacyToolRecordTitleGuide, .legacyToolRecordSummaryGuide, .legacyToolSeverityGuide,
        .legacyToolEntityIDsGuide
    ]

    static func prompt(projection: String, valence: EventValence) -> String {
        let outcomeRule = ModelPromptRegistry.text(valence == .positive ? .legacyPositiveOutcomeRule : .legacyNegativeOutcomeRule)
        return ModelPromptRegistry.render(.legacyRequestTemplate, [
            "projection": projection,
            "outcomeRule": outcomeRule,
            "taskInstructions": ModelPromptRegistry.text(.legacyTaskInstructions)
        ])
    }

    static func correctedPrompt(_ prompt: String, rejection: String) -> String {
        prompt + "\n" + ModelPromptRegistry.render(.legacyCorrection, ["rejection": rejection])
    }
}
