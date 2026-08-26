import Foundation

enum HordeModelContract {
    static let promptVersion = 35
    static let schemaVersion = 5
    static let projectionVersion = 12

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
