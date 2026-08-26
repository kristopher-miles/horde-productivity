import SwiftUI

struct ChronicleView: View {
    @Environment(AppModel.self) private var app
    @State private var query = ""
    @State private var filter: Filter = .all
    @State private var usesDateRange = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var endDate = Date.now

    enum Filter: String, CaseIterable, Identifiable { case all = "All", completed = "Completed", expired = "Expired"; var id: Self { self } }

    var body: some View {
        Group {
            if app.chronicle.isEmpty {
                ContentUnavailableView("No tales yet", systemImage: "book.closed", description: Text("Committed dungeon changes will appear here."))
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List {
                    ForEach(grouped, id: \.0) { day, entries in
                        Section(day.formatted(date: .complete, time: .omitted)) {
                            ForEach(entries) { entry in
                                NavigationLink { ChronicleDetailView(entry: entry) } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Label(entry.title, systemImage: entry.valence == .positive ? "checkmark.circle" : "clock.badge.exclamationmark").font(.headline)
                                        Text(entry.summary).lineLimit(2)
                                        Text(entry.sourceTitle).font(.caption).foregroundStyle(.secondary)
                                        if let delta = entry.deltas.first { Text(delta.description).font(.caption2).foregroundStyle(.tertiary) }
                                    }.padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Chronicle")
        .searchable(text: $query, prompt: "Search stories and goals")
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .primaryAction) {
                filterMenu
            }
            #else
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
            #endif
        }
        .task { await app.reload() }
    }

    private var filtered: [ChronicleSummary] {
        app.chronicle.filter { entry in
            let valenceMatches = filter == .all || (filter == .completed && entry.valence == .positive) || (filter == .expired && entry.valence == .negative)
            let queryMatches = query.isEmpty || [entry.sourceTitle, entry.title, entry.summary, entry.finalProse].contains { $0.localizedCaseInsensitiveContains(query) }
            let dateMatches = !usesDateRange || (entry.committedAt >= Calendar.current.startOfDay(for: startDate) && entry.committedAt <= (Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: Calendar.current.startOfDay(for: endDate)) ?? endDate))
            return valenceMatches && queryMatches && dateMatches
        }
    }

    private var grouped: [(Date, [ChronicleSummary])] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.committedAt) }.sorted { $0.key > $1.key }
    }

    private var filterMenu: some View {
        Menu("Filter", systemImage: "line.3.horizontal.decrease.circle") {
            Picker("Event", selection: $filter) { ForEach(Filter.allCases) { Text($0.rawValue).tag($0) } }
            Toggle("Use Date Range", isOn: $usesDateRange)
            if usesDateRange {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                DatePicker("Through", selection: $endDate, displayedComponents: .date)
            }
        }
    }
}

struct ChronicleDetailView: View {
    let entry: ChronicleSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DungeonSceneView(
                    world: entry.recordedWorld,
                    cue: entry.cue,
                    accessibilityDescription: "Authored visual response for \(entry.title). \(entry.valence == .positive ? "A hopeful dungeon moment." : "A small recoverable setback.")"
                )
                Label("Immutable record from save revision \(entry.committedRevision)", systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(entry.valence == .positive ? "Completed goal" : "Expired goal", systemImage: entry.valence == .positive ? "checkmark.circle.fill" : "clock.badge.exclamationmark").foregroundStyle(entry.valence == .positive ? DesignTokens.positive : DesignTokens.negative)
                Text(entry.title).font(.largeTitle.bold())
                Text(entry.finalProse).font(.body).textSelection(.enabled)
                VStack(alignment: .leading, spacing: 8) { Text("What changed").font(.headline); ForEach(entry.deltas) { Label($0.description, systemImage: "arrow.right.circle") } }.hordeCard()
                LabeledContent("Source goal", value: entry.sourceTitle)
                LabeledContent("Save revision", value: "\(entry.priorRevision) → \(entry.committedRevision)")
                LabeledContent("Committed", value: entry.committedAt.formatted())
            }.padding(DesignTokens.margin)
        }.navigationTitle("Story Result").hordeInlineNavigationTitle()
    }
}
