import Observation
import SwiftUI

@MainActor @Observable final class ModelPromptEditorModel {
    let entries = ModelPromptRegistry.editorEntries
    private let store: ModelPromptOverrideStore
    private(set) var savedTexts: [ModelPromptComponentID: String]
    var drafts: [ModelPromptComponentID: String]

    init(store: ModelPromptOverrideStore = ModelPromptOverrideStore()) {
        self.store = store
        let texts = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, store.text(for: $0.id)) })
        savedTexts = texts
        drafts = texts
    }

    func draft(for id: ModelPromptComponentID) -> String {
        drafts[id, default: store.text(for: id)]
    }

    func setDraft(_ text: String, for id: ModelPromptComponentID) {
        drafts[id] = text
    }

    func isModified(_ id: ModelPromptComponentID) -> Bool {
        draft(for: id) != savedTexts[id]
    }

    func save(_ id: ModelPromptComponentID) {
        let text = draft(for: id)
        store.save(text, for: id)
        savedTexts[id] = text
    }
}

struct ModelPromptEditorView: View {
    @State private var model = ModelPromptEditorModel()

    var body: some View {
        List(model.entries) { entry in
            Section {
                LabeledContent("Identity", value: entry.id.rawValue)
                LabeledContent("Stage", value: entry.stages.map(\.rawValue).joined(separator: ", "))
                LabeledContent("Kind", value: entry.kind.rawValue)
                TextEditor(text: Binding(
                    get: { model.draft(for: entry.id) },
                    set: { model.setDraft($0, for: entry.id) }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 160)
                .accessibilityLabel("Prompt text for \(entry.id.rawValue)")
                HStack {
                    if model.isModified(entry.id) {
                        Text("Unsaved changes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Save") { model.save(entry.id) }
                        .disabled(!model.isModified(entry.id))
                }
            } header: {
                Text(entry.id.rawValue)
            }
        }
        .navigationTitle("Prompt Editor")
    }
}
