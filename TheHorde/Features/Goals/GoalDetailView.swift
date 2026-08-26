import SwiftUI

struct GoalDetailView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let definitionID: String
    @State private var goal: GoalDefinitionSummary?
    @State private var confirmArchive = false
    @State private var confirmDelete = false
    @State private var confirmCancelOrFail = false

    var body: some View {
        Group {
            if let goal {
                #if os(macOS)
                Form { detailSections(goal) }
                    .formStyle(.grouped)
                    .hordeReadableContent(maxWidth: 760)
                #else
                List {
                    detailSections(goal)
                }
                #endif
            } else { ProgressView("Loading goal") }
        }
        .navigationTitle("Goal Detail")
        .task { await load() }
        .confirmationDialog("Archive this goal?", isPresented: $confirmArchive) { Button("Archive Goal", role: .destructive) { Task { if await app.archiveGoal(id: definitionID) { await load() } } }; Button("Cancel", role: .cancel) {} } message: { Text("Future occurrences and reminders will stop. Completed and expired history remains.") }
        .confirmationDialog("Delete this future goal?", isPresented: $confirmDelete) { Button("Delete Goal", role: .destructive) { Task { if await app.deleteGoal(id: definitionID) { dismiss() } } }; Button("Cancel", role: .cancel) {} } message: { Text("The reusable definition and pending occurrence will be removed. Committed story history is preserved.") }
        .confirmationDialog("Stop this goal?", isPresented: $confirmCancelOrFail) {
            Button("Cancel", role: .destructive) { Task { if let current, await app.cancel(current) { await load() } } }
            Button("Fail", role: .destructive) { Task { if let current, await app.fail(current) { await load() } } }
            Button("Keep Goal", role: .cancel) {}
        } message: {
            Text("Cancel stops the goal without an attempt or story. Fail records one failed attempt and opens story resolution.")
        }
    }

    private func load() async { goal = await app.definition(id: definitionID) }

    @ViewBuilder private func detailSections(_ goal: GoalDefinitionSummary) -> some View {
        Section("Goal") {
            LabeledContent("Title", value: goal.draft.title)
            if !goal.draft.notes.isEmpty { Text(goal.draft.notes).textSelection(.enabled) }
            LabeledContent("Repeat", value: goal.draft.recurrence.label)
            if let category = goal.draft.category { LabeledContent("Category", value: category.rawValue) }
            if let effort = goal.draft.effort { LabeledContent("Effort", value: effort.rawValue) }
            if goal.archived { Label("Archived", systemImage: "archivebox") }
        }
        if let current = goal.history.first(where: { $0.state == .pending }) {
            Section("Current occurrence") {
                LabeledContent("Due", value: current.dueLabel)
                Button { Task { await app.complete(current); await load() } } label: {
                    Label("Complete Goal", systemImage: "checkmark.circle")
                }
                Button("Cancel or Fail", systemImage: "xmark.circle") { confirmCancelOrFail = true }
                    .accessibilityIdentifier("Goal.CancelOrFail")
            }
        }
        Section("History") {
            let resolved = goal.history.filter { $0.state != .pending }
            if resolved.isEmpty { Text("No resolved occurrences yet.").foregroundStyle(.secondary) }
            ForEach(resolved) { row in
                if let entry = app.chronicle.first(where: { $0.eventID.hasPrefix(row.id + ":") }) {
                    NavigationLink(value: TodayRoute.chronicle(entry.id)) { historyLabel(row) }
                } else { historyLabel(row) }
            }
        }
        Section("Manage") {
            Button("Edit Future Goal", systemImage: "pencil") { app.presentedEditor = GoalEditorPresentation(definitionID: goal.id, initialDraft: goal.draft) }.disabled(goal.archived)
            Button("Archive", systemImage: "archivebox") { confirmArchive = true }.disabled(goal.archived)
            Button("Delete Future Goal", systemImage: "trash", role: .destructive) { confirmDelete = true }
        }
    }

    private var current: GoalOccurrenceSummary? {
        goal?.history.first { $0.state == .pending }
    }

    private func historyLabel(_ row: GoalOccurrenceSummary) -> some View {
        Label { VStack(alignment: .leading) { Text(row.snapshot.title); Text(row.state.rawValue.capitalized).font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName: row.state == .completed ? "checkmark.circle" : row.state == .expired ? "clock.badge.exclamationmark" : "xmark.circle") }
    }
}
