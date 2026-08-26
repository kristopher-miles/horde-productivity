import Foundation
import Testing
@testable import TheHorde

@Suite("Model prompt registry")
struct ModelPromptRegistryTests {
    @Test func targetStagesExposeCompleteStableEditorInventories() {
        #expect(ModelRequestStageID.allCases.map(\.rawValue) == [
            "effort-evaluation", "action-suggestion", "custom-action-interpretation",
            "final-prose", "legacy-consequence"
        ])
        #expect(Set(ModelPromptRegistry.editorEntries.map(\.id)) == Set(ModelPromptComponentID.allCases))
        #expect(ModelPromptRegistry.editorEntries.allSatisfy { !$0.id.rawValue.isEmpty && !$0.defaultText.isEmpty })

        assertStage(.effortEvaluation, contains: [
            .sharedGoalContext, .sharedHistoryContext, .effortSystemInstructions,
            .effortRequestTemplate, .effortOutputGuide, .effortCorrection
        ])
        assertStage(.actionSuggestion, contains: [
            .sharedGoalContext, .sharedWorldContext, .suggestionSystemInstructions,
            .suggestionRequestTemplate, .suggestionOutputGuide, .suggestionCorrection
        ])
        assertStage(.customActionInterpretation, contains: [
            .sharedGoalContext, .sharedWorldContext, .customActionSystemInstructions,
            .customActionRequestTemplate, .customActionOutputGuide, .customActionFallback,
            .customActionCorrection
        ])
        assertStage(.finalProse, contains: [
            .sharedWorldContext, .sharedAcceptedActionContext, .sharedPreviousProseContext,
            .finalProseSystemInstructions, .finalProseRequestTemplate,
            .finalProseOutputGuide, .finalProseCorrection
        ])
        #expect(Set(ModelPromptRegistry.components(for: .legacyConsequence).map(\.id)) == HordeModelContract.requestComponentIDs)
    }

    @Test func productionRequestTextAndSchemasConsumeRegisteredComponents() async throws {
        let event = PendingStorySummary(
            id: "registry-event", sourceTitle: "Map {{outcomeRule}} safely",
            sourceNotes: "Keep {{taskInstructions}} as user data", valence: .positive,
            status: .pending, failureCode: nil, createdAt: .distantPast
        )
        let snapshot = WorldSnapshot.initial()
        let descriptors = WorldContract.descriptors(for: .positive, world: snapshot)
        let projection = ProjectionBuilder.projection(
            event: event,
            world: WorldReadModel(dungeonName: "The Vault", revision: 2, snapshot: snapshot),
            descriptors: descriptors
        )
        let prompt = HordeModelContract.prompt(projection: projection, valence: .positive)
        let corrected = HordeModelContract.correctedPrompt(prompt, rejection: "receipt mismatch")

        #expect(HordeModelContract.instructions == ModelPromptRegistry.text(.legacySystemInstructions))
        #expect(!HordeModelContract.instructions.localizedCaseInsensitiveContains("kobold"))
        #expect(!projection.localizedCaseInsensitiveContains("kobold"))
        #expect(prompt.contains(ModelPromptRegistry.text(.legacyPositiveOutcomeRule)))
        #expect(prompt.contains(ModelPromptRegistry.text(.legacyTaskInstructions)))
        #expect(prompt.contains("<user-title>Map {{outcomeRule}} safely</user-title>"))
        #expect(prompt.contains("<user-notes>Keep {{taskInstructions}} as user data</user-notes>"))
        #expect(corrected.hasSuffix(ModelPromptRegistry.render(.legacyCorrection, ["rejection": "receipt mismatch"])))
        #expect(descriptors.first?.description.hasPrefix(ModelPromptRegistry.text(.legacyScalarDescriptor)) == true)

        let positiveSchema = LegacyModelSchemas.story(for: .positive).debugDescription
        let negativeSchema = LegacyModelSchemas.story(for: .negative).debugDescription
        for id in [ModelPromptComponentID.legacyPositiveTitleGuide, .legacyPositiveNarrationGuide, .legacyPositiveSummaryGuide, .legacyPositiveCueGuide, .legacyPositiveReceiptGuide] {
            #expect(positiveSchema.contains(ModelPromptRegistry.text(id)))
        }
        for id in [ModelPromptComponentID.legacyNegativeTitleGuide, .legacyNegativeNarrationGuide, .legacyNegativeSummaryGuide, .legacyNegativeCueGuide, .legacyNegativeReceiptGuide] {
            #expect(negativeSchema.contains(ModelPromptRegistry.text(id)))
        }

        let tool = StageMutationTool(stager: PatchStager())
        #expect(tool.name == ModelPromptRegistry.text(.legacyToolName))
        #expect(tool.description == ModelPromptRegistry.text(.legacyToolDescription))
        let toolSchema = tool.parameters.debugDescription
        for id in [ModelPromptComponentID.legacyToolFieldIDGuide, .legacyToolOperationGuide, .legacyToolIntegerValueGuide, .legacyToolRecordIDGuide, .legacyToolRecordTitleGuide, .legacyToolRecordSummaryGuide, .legacyToolSeverityGuide, .legacyToolEntityIDsGuide] {
            #expect(toolSchema.contains(ModelPromptRegistry.text(id)))
        }
        #expect(try await tool.call(arguments: StageMutationArguments(fieldID: "world.morale", operation: "increment", integerValue: 1, recordID: "unused", recordTitle: "unused", recordSummary: "unused", severityOrRank: 1, involvedEntityIDs: [])).hasPrefix("Staged in receipt "))
    }

    @Test func renderingDoesNotExpandPlaceholderTextInsideValues() {
        let rendered = ModelPromptRegistry.render(.sharedGoalContext, [
            "goal": "literal {{history}} marker",
            "history": "must not be inserted"
        ])
        #expect(rendered == "GOAL <user-goal>literal {{history}} marker</user-goal>")
    }

    @Test func legacyContractPermitsConsequentialEpicFantasyThreats() {
        let threatComponents: [ModelPromptComponentID] = [
            .legacySystemInstructions, .legacyNegativeOutcomeRule, .legacyThreadDescriptor,
            .legacyNegativeTitleGuide, .legacyNegativeNarrationGuide, .legacyNegativeSummaryGuide
        ]
        let text = threatComponents.map { ModelPromptRegistry.text($0) }.joined(separator: " ")

        #expect(HordeModelContract.promptVersion == 41)
        #expect(text.localizedCaseInsensitiveContains("consequential"))
        #expect(text.localizedCaseInsensitiveContains("epic-fantasy threat"))
        #expect(!text.localizedCaseInsensitiveContains("no threats"))
        #expect(!text.localizedCaseInsensitiveContains("recoverable"))
    }

    private func assertStage(_ stage: ModelRequestStageID, contains ids: Set<ModelPromptComponentID>) {
        #expect(Set(ModelPromptRegistry.components(for: stage).map(\.id)) == ids)
    }
}
