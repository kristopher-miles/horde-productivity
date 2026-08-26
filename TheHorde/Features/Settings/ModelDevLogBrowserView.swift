import SwiftUI

extension ModelRequestStageID {
    var developerTitle: String {
        switch self {
        case .effortEvaluation: "Effort Evaluation"
        case .actionSuggestion: "Action Suggestion"
        case .customActionInterpretation: "Custom Action Interpretation"
        case .finalProse: "Final Prose"
        case .legacyConsequence: "Legacy Consequence"
        }
    }
}

struct ModelDevLogTextSection: Identifiable, Equatable {
    let title: String
    let text: String?
    var id: String { title }
}

enum ModelDevLogBrowserContent {
    static func filtered(_ entries: [ModelDevLogEntry], query: String) -> [ModelDevLogEntry] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return entries }
        return entries.filter { entry in
            [
                entry.eventID,
                entry.goalTitle,
                entry.stage.rawValue,
                entry.stage.developerTitle,
                "Attempt \(entry.attempt)",
                entry.outcome.rawValue
            ].contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    static func textSections(for entry: ModelDevLogEntry) -> [ModelDevLogTextSection] {
        [
            ModelDevLogTextSection(title: "Full Request", text: entry.requestText),
            ModelDevLogTextSection(title: "Raw Response", text: entry.responseText),
            ModelDevLogTextSection(title: "Response Material", text: entry.responseMaterial),
            ModelDevLogTextSection(title: "Instructions", text: entry.instructionsText),
            ModelDevLogTextSection(title: "Prompt", text: entry.promptText),
            ModelDevLogTextSection(title: "Attempt Transcript", text: entry.attemptTranscript),
            ModelDevLogTextSection(title: "Error", text: entry.errorText)
        ]
    }
}

struct ModelDevLogBrowserView: View {
    private let store: ModelDevLogStore
    @State private var entries: [ModelDevLogEntry] = []
    @State private var query = ""
    @State private var isLoading = true

    init(store: ModelDevLogStore = ModelDevLogStore()) {
        self.store = store
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading Model Logs…")
            } else if entries.isEmpty {
                ContentUnavailableView(
                    "No Model Logs",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Model attempts made while Developer Mode is on will appear here.")
                )
            } else if filteredEntries.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(filteredEntries) { entry in
                    NavigationLink {
                        ModelDevLogDetailView(entry: entry)
                    } label: {
                        ModelDevLogEntryRow(entry: entry)
                    }
                }
                .refreshable { await reload() }
            }
        }
        .navigationTitle("Model Logs")
        .searchable(text: $query, prompt: "Search goal, event, stage, or attempt")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await reload() }
                }
                .disabled(isLoading)
            }
        }
        .task { await reload() }
    }

    private var filteredEntries: [ModelDevLogEntry] {
        ModelDevLogBrowserContent.filtered(entries, query: query)
    }

    private func reload() async {
        isLoading = true
        entries = await store.entries()
        isLoading = false
    }
}

private struct ModelDevLogEntryRow: View {
    let entry: ModelDevLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.goalTitle)
                    .font(.headline)
                Spacer()
                Label(entry.outcome == .succeeded ? "Succeeded" : "Failed", systemImage: entry.outcome == .succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption)
            }
            Text("Event \(entry.eventID)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            HStack {
                Text(entry.stage.developerTitle)
                Spacer()
                Text("Attempt \(entry.attempt)")
                Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ModelDevLogDetailView: View {
    let entry: ModelDevLogEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Attempt Metadata") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Time", value: entry.timestamp.formatted(date: .complete, time: .standard))
                        LabeledContent("Goal", value: entry.goalTitle)
                        LabeledContent("Event") {
                            Text(entry.eventID)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                        }
                        LabeledContent("Stage", value: "\(entry.stage.developerTitle) (\(entry.stage.rawValue))")
                        LabeledContent("Attempt", value: "\(entry.attempt)")
                        LabeledContent("Outcome", value: entry.outcome == .succeeded ? "Succeeded" : "Failed")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(ModelDevLogBrowserContent.textSections(for: entry)) { section in
                    GroupBox(section.title) {
                        Group {
                            if let text = section.text {
                                Text(text)
                                    .font(.body.monospaced())
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("Not captured for this attempt.")
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 20, alignment: .topLeading)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("\(entry.stage.developerTitle) · Attempt \(entry.attempt)")
        .hordeInlineNavigationTitle()
    }
}
