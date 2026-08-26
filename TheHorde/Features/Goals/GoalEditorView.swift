import SwiftUI

struct GoalEditorView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let presentation: GoalEditorPresentation
    @State private var draft: GoalDraft
    @State private var hasDate: Bool
    @State private var saving = false
    @State private var showDiscard = false
    @State private var advancedExpanded = false
    @FocusState private var focusedField: Field?

    private enum Field { case title }

    init(presentation: GoalEditorPresentation) {
        self.presentation = presentation
        _draft = State(initialValue: presentation.initialDraft)
        _hasDate = State(initialValue: presentation.initialDraft.dueDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("What do you want to do?", text: $draft.title, axis: .vertical)
                        .hordeSentenceAutocapitalization()
                        .accessibilityLabel("Goal title, required")
                        .focused($focusedField, equals: .title)
                    TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                }
                Section("Schedule") {
                    Toggle("Add a date", isOn: dateEnabled)
                    if hasDate {
                        DatePicker("Date", selection: dueBinding, displayedComponents: .date)
                        Toggle("Include a time", isOn: $draft.includesTime)
                        if draft.includesTime { DatePicker("Time", selection: dueBinding, displayedComponents: .hourAndMinute) }
                    }
                    DisclosureGroup("Repeat & context", isExpanded: $advancedExpanded) {
                        Picker("Repeat", selection: recurrenceKind) {
                            Text("Never").tag("never"); Text("Daily").tag("daily"); Text("Selected Weekdays").tag("weekdays")
                        }
                        if case .weekdays(let selected) = draft.recurrence { weekdayPicker(selected: selected) }
                        Picker("Category", selection: $draft.category) { Text("None").tag(GoalCategory?.none); ForEach(GoalCategory.allCases) { Text($0.rawValue).tag(Optional($0)) } }
                        Picker("Effort", selection: $draft.effort) { Text("None").tag(GoalEffort?.none); ForEach(GoalEffort.allCases) { Text($0.rawValue).tag(Optional($0)) } }
                    }
                }
            }
            .navigationTitle(presentation.definitionID == nil ? "Add Goal" : "Edit Goal")
            .hordeInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel() } }
                ToolbarItem(placement: .confirmationAction) { Button(presentation.definitionID == nil ? "Add" : "Save") { save() }.disabled(!draft.isValid || saving) }
            }
            .confirmationDialog("Discard changes?", isPresented: $showDiscard) { Button("Discard Changes", role: .destructive) { dismiss() }; Button("Keep Editing", role: .cancel) {} }
        }
        .interactiveDismissDisabled(draft != presentation.initialDraft)
        .task { if presentation.definitionID == nil { focusedField = .title } }
    }

    private var dueBinding: Binding<Date> { Binding(get: { draft.dueDate ?? .now }, set: { draft.dueDate = $0 }) }
    private var dateEnabled: Binding<Bool> { Binding(get: { hasDate }, set: { hasDate = $0; draft.setDateEnabled($0) }) }
    private var recurrenceKind: Binding<String> { Binding(get: { switch draft.recurrence { case .never: "never"; case .daily: "daily"; case .weekdays: "weekdays" } }, set: { draft.recurrence = $0 == "daily" ? .daily : $0 == "weekdays" ? .weekdays([2,3,4,5,6]) : .never }) }

    private func weekdayPicker(selected: Set<Int>) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
            ForEach(1...7, id: \.self) { day in
                Button(Calendar.current.veryShortWeekdaySymbols[day - 1]) {
                    var days = selected; if !days.insert(day).inserted { days.remove(day) }; draft.recurrence = .weekdays(days)
                }
                .buttonStyle(.bordered)
                .tint(selected.contains(day) ? DesignTokens.ember : .secondary)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                .accessibilityValue(selected.contains(day) ? "Selected" : "Not selected")
            }
        }
    }

    private func cancel() { if draft == presentation.initialDraft || (!draft.isValid && presentation.definitionID == nil) { dismiss() } else { showDiscard = true } }
    private func save() {
        draft.setDateEnabled(hasDate)
        saving = true
        Task {
            let success = if let id = presentation.definitionID { await app.updateGoal(id: id, draft: draft) } else { await app.createGoal(draft) }
            saving = false
            if success { dismiss() }
        }
    }
}
