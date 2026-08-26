import Foundation
import Testing
@testable import TheHorde

@Suite("Model prompt overrides")
struct ModelPromptOverrideTests {
    @Test func overridesPreserveExactTextAcrossStoreRecreationAndStayIndependent() throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ModelPromptOverrideStore(defaults: defaults)
        let override = "  exact first line\n{{goal}} 🐉\n"
        let independentOverride = "separate component"

        store.save(independentOverride, for: .suggestionSystemInstructions)
        store.save(override, for: .effortSystemInstructions)

        let reloadedDefaults = try #require(UserDefaults(suiteName: suiteName))
        #expect(ModelPromptOverrideStore(defaults: reloadedDefaults).text(for: .effortSystemInstructions) == override)
        #expect(store.text(for: .suggestionSystemInstructions) == independentOverride)
    }

    @Test @MainActor func editorShowsTheFullInventoryAndOnlySavedDraftsBecomeEffective() throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ModelPromptOverrideStore(defaults: defaults)
        let model = ModelPromptEditorModel(store: store)
        let editedID = ModelPromptComponentID.sharedGoalContext
        let untouchedID = ModelPromptComponentID.sharedWorldContext
        let override = "OVERRIDE {{goal}}"

        #expect(model.entries.map(\.id) == ModelPromptRegistry.editorEntries.map(\.id))
        #expect(Set(model.entries.map(\.id)) == Set(ModelPromptComponentID.allCases))
        #expect(model.entries.allSatisfy { !$0.id.rawValue.isEmpty && !$0.stages.isEmpty })

        model.setDraft(override, for: editedID)
        #expect(model.isModified(editedID))
        #expect(ModelPromptRegistry.text(editedID, store: store) != override)
        #expect(ModelPromptRegistry.text(untouchedID, store: store) == ModelPromptRegistry.component(untouchedID).defaultText)

        model.save(editedID)
        #expect(!model.isModified(editedID))
        #expect(ModelPromptRegistry.text(editedID, store: store) == override)
        #expect(ModelPromptEditorModel(store: store).draft(for: editedID) == override)
        #expect(ModelPromptRegistry.text(untouchedID, store: store) == ModelPromptRegistry.component(untouchedID).defaultText)
    }

    @Test func savedOverridesFeedProductionTextAndTemplateRendering() throws {
        let (suiteName, defaults) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ModelPromptOverrideStore(defaults: defaults)
        store.save("SYSTEM OVERRIDE", for: .legacySystemInstructions)
        store.save("Request: {{taskInstructions}}", for: .legacyRequestTemplate)
        store.save("TOOL OVERRIDE", for: .legacyToolDescription)
        store.save("SCHEMA OVERRIDE", for: .legacyPositiveTitleGuide)
        store.save("Context: {{goal}}", for: .sharedGoalContext)

        #expect(ModelPromptRegistry.text(.legacySystemInstructions, store: store) == "SYSTEM OVERRIDE")
        #expect(ModelPromptRegistry.render(.legacyRequestTemplate, ["taskInstructions": "TASK"], store: store) == "Request: TASK")
        #expect(ModelPromptRegistry.text(.legacyToolDescription, store: store) == "TOOL OVERRIDE")
        #expect(ModelPromptRegistry.text(.legacyPositiveTitleGuide, store: store) == "SCHEMA OVERRIDE")
        #expect(ModelPromptRegistry.render(.sharedGoalContext, ["goal": "GOAL"], store: store) == "Context: GOAL")
    }

    private func isolatedDefaults() throws -> (String, UserDefaults) {
        let suite = "ModelPromptOverrideTests.\(UUID().uuidString)"
        return (suite, try #require(UserDefaults(suiteName: suite)))
    }
}
