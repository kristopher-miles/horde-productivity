import SwiftUI
#if os(macOS)
import AppKit
#endif

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

    static func requestText(for entry: ModelDevLogEntry) -> String {
        entry.requestText ?? "Instructions:\n\(entry.instructionsText)\n\nPrompt:\n\(entry.promptText)"
    }

    static func responseText(for entry: ModelDevLogEntry) -> String {
        var sections: [String] = []
        if let text = entry.responseText {
            sections.append("Raw Response\n\(text)")
        }
        if let material = entry.responseMaterial {
            sections.append("Response Material\n\(material)")
        } else if let transcript = entry.attemptTranscript {
            sections.append("Attempt Transcript\n\(transcript)")
        }
        if let error = entry.errorText {
            sections.append("Error\n\(error)")
        }
        return sections.isEmpty ? "No response was captured." : sections.joined(separator: "\n\n---\n\n")
    }

    static func bothText(for entry: ModelDevLogEntry) -> String {
        "REQUEST\n\(requestText(for: entry))\n\nRESPONSE\n\(responseText(for: entry))"
    }
}

struct ModelDevLogBrowserView: View {
    private let store: ModelDevLogStore
    @State private var entries: [ModelDevLogEntry] = []
    @State private var query = ""
    @State private var isLoading = true
#if os(macOS)
    @State private var selectedEntry: ModelDevLogEntry?
#endif

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
#if os(macOS)
                    Button {
                        selectedEntry = entry
                    } label: {
                        ModelDevLogEntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
#else
                    NavigationLink {
                        ModelDevLogDetailView(entry: entry)
                    } label: {
                        ModelDevLogEntryRow(entry: entry)
                    }
#endif
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
#if os(macOS)
        .sheet(item: $selectedEntry) { entry in
            MacModelDevLogInspectorView(entry: entry)
        }
#endif
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

#if os(macOS)
private struct MacModelDevLogInspectorView: View {
    @Environment(\.dismiss) private var dismiss
    let entry: ModelDevLogEntry

    private var requestText: String { ModelDevLogBrowserContent.requestText(for: entry) }
    private var responseText: String { ModelDevLogBrowserContent.responseText(for: entry) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Copy Request") { copy(requestText) }
                Button("Copy Response") { copy(responseText) }
                Button("Copy Both") { copy(ModelDevLogBrowserContent.bothText(for: entry)) }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            HSplitView {
                textPane(title: "Request", text: requestText)
                textPane(title: "Response", text: responseText)
            }
        }
        .frame(minWidth: 960, idealWidth: 1100, minHeight: 600, idealHeight: 720)
    }

    private func textPane(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ScrollView(.vertical) {
                Text(verbatim: text)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding()
        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
#endif

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
