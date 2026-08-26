import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    private var pending: [GoalOccurrenceSummary] { app.occurrences.filter { $0.state == .pending } }

    var body: some View {
        #if os(macOS)
        ScrollView {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: DesignTokens.desktopSpacing) {
                    LazyVStack(alignment: .leading, spacing: 16) { goalsContent }
                        .frame(minWidth: 440, maxWidth: .infinity, alignment: .leading)
                    worldSummary.frame(width: 340)
                }
                LazyVStack(alignment: .leading, spacing: DesignTokens.desktopSpacing) {
                    goalsContent
                    worldSummary.frame(maxWidth: 520)
                }
            }
            .padding(DesignTokens.desktopMargin)
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Goal", systemImage: "plus") { app.presentedEditor = .new }
            }
        }
        .task { await app.reload() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { try? await app.reconcileAndReload() } } }
        #else
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                goalsContent
                worldSummary
            }
            .padding(DesignTokens.margin)
        }
        .safeAreaInset(edge: .bottom) {
            Button { app.presentedEditor = .new } label: {
                Label("Add Goal", systemImage: "plus.circle.fill").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, DesignTokens.margin)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Add", systemImage: "plus") { app.presentedEditor = .new } }
            ToolbarItem(placement: .topBarLeading) { Button("Settings", systemImage: "gearshape") { app.settingsPresented = true } }
        }
        .task { await app.reload() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { try? await app.reconcileAndReload() } } }
        #endif
    }

    @ViewBuilder private var goalsContent: some View {
        if app.pendingStoryCount > 0 { pendingStoryBanner }
        if pending.isEmpty {
            ContentUnavailableView(app.occurrences.isEmpty ? "No goals yet" : "No active goals", systemImage: app.occurrences.isEmpty ? "checkmark.circle" : "checkmark.seal.fill", description: Text(app.occurrences.isEmpty ? "Add a goal to begin changing your dungeon." : "Your current goals are resolved. Their stories await your decision."))
        } else {
            section(.overdue, title: "Overdue")
            section(.today, title: "Due Today")
            section(.upcoming, title: "Upcoming")
        }
    }

    @ViewBuilder private func section(_ section: GoalSection, title: String) -> some View {
        let rows = pending.filter { ScheduleCalculator.section(for: $0, now: .now) == section }
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: section == .overdue ? "exclamationmark.circle" : section == .today ? "sun.max" : "calendar")
                    .font(.headline)
                ForEach(rows) { GoalRow(occurrence: $0) }
            }
        }
    }

    private var pendingStoryBanner: some View {
        Button { app.openNextPendingStory() } label: { Label {
            VStack(alignment: .leading) {
                Text("Story pending").font(.headline)
                Text("\(app.pendingStoryCount) saved goal \(app.pendingStoryCount == 1 ? "event is" : "events are") waiting to change the dungeon.").font(.subheadline)
            }
        } icon: { Image(systemName: "sparkles") } }
        .buttonStyle(.plain)
        .hordeCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var worldSummary: some View {
        if let world = app.world {
            let presentation = WorldPresentationState(snapshot: world.snapshot)
            VStack(alignment: .leading, spacing: 12) {
                DungeonSceneView(world: world, cue: .idle)
                Label(world.dungeonName, systemImage: "castle").font(.headline)
                Text(presentation.populationSummary)
                    .font(.subheadline)
                    .accessibilityIdentifier("Today.WorldPopulation")
                if let thread = world.snapshot.activeThreads.first {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(thread.title).font(.subheadline.bold())
                        Text(thread.summary).font(.caption)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("Today.ActiveThread")
                }
                Button("Open Dungeon") { app.selectedTab = .dungeon }
                    .buttonStyle(.borderedProminent)
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(DesignTokens.dungeon, in: RoundedRectangle(cornerRadius: DesignTokens.radius))
        }
    }
}

private struct GoalRow: View {
    @Environment(AppModel.self) private var app
    let occurrence: GoalOccurrenceSummary
    @State private var isCompleting = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        HStack(spacing: 12) {
            Button {
                guard !isCompleting else { return }
                isCompleting = true
                if hapticsEnabled { PlatformSupport.completionFeedback() }
                Task { await app.complete(occurrence); isCompleting = false }
            } label: {
                Image(systemName: isCompleting ? "checkmark.circle.fill" : "circle")
                    .font(.title2).frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isCompleting)
            .accessibilityLabel("Complete \(occurrence.snapshot.title)")

            NavigationLink(value: TodayRoute.goal(occurrence.definitionID)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(occurrence.snapshot.title).font(.headline).multilineTextAlignment(.leading)
                    Text(metadata).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Details for \(occurrence.snapshot.title), \(metadata)")
            Image(systemName: "chevron.right").foregroundStyle(.tertiary).accessibilityHidden(true)
        }
        .hordeCard()
    }

    private var metadata: String {
        [occurrence.dueLabel, occurrence.snapshot.recurrence.label, occurrence.snapshot.category?.rawValue, occurrence.snapshot.effort?.rawValue].compactMap { $0 }.joined(separator: " • ")
    }
}
