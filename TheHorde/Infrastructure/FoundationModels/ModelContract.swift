import Foundation
import FoundationModels

enum EffortModelContract {
    static let promptVersion = 40

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
            "<attempt id=\($0.id) outcome=\($0.outcome.rawValue)>\($0.content)</attempt>"
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

enum HordeModelContract {
    static let promptVersion = 39
    static let schemaVersion = 5
    static let projectionVersion = 14

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
