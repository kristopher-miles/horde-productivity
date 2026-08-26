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

    @Test func systemInstructionsRejectCushioningAndContractSupportsMeaningfulOutcomes() {
        let prohibitedCushioning = ["gentle", "harmless", "modest", "calm", "recoverable", "slight"]
        let systemInstructions = ModelPromptRegistry.editorEntries.filter { $0.kind == .systemInstructions }
        for component in systemInstructions {
            for term in prohibitedCushioning {
                #expect(!component.defaultText.localizedCaseInsensitiveContains(term))
            }
        }

        let success = ModelPromptRegistry.text(.legacyPositiveOutcomeRule)
        let failure = ModelPromptRegistry.text(.legacyNegativeOutcomeRule)
        let direction = ModelPromptRegistry.text(.legacySystemInstructions)
        for term in prohibitedCushioning {
            #expect(!success.localizedCaseInsensitiveContains(term))
            #expect(!failure.localizedCaseInsensitiveContains(term))
        }

        #expect(HordeModelContract.promptVersion == 42)
        #expect(direction.localizedCaseInsensitiveContains("adult epic-fantasy"))
        #expect(direction.localizedCaseInsensitiveContains("accepted action"))
        #expect(direction.localizedCaseInsensitiveContains("established world"))
        #expect(direction.localizedCaseInsensitiveContains("effort rating"))
        #expect(direction.localizedCaseInsensitiveContains("real, lasting consequences"))
        #expect(success.localizedCaseInsensitiveContains("meaningful success"))
        #expect(failure.localizedCaseInsensitiveContains("meaningful failure"))
        #expect(failure.localizedCaseInsensitiveContains("epic-fantasy threat"))
    }

    private func assertStage(_ stage: ModelRequestStageID, contains ids: Set<ModelPromptComponentID>) {
        #expect(Set(ModelPromptRegistry.components(for: stage).map(\.id)) == ids)
    }
}
