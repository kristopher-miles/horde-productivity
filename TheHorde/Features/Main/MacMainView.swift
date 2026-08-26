#if os(macOS)
import SwiftUI

struct MacMainView: View {
    @Environment(AppModel.self) private var app
    @State private var dungeonPath = NavigationPath()
    @State private var chroniclePath = NavigationPath()

    var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                Label("Today", systemImage: "checklist").tag(AppTab.today)
                Label("Dungeon", systemImage: "castle").tag(AppTab.dungeon)
                Label("Chronicle", systemImage: "book.pages").tag(AppTab.chronicle)
            }
            .navigationTitle("The Horde")
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .safeAreaInset(edge: .bottom) {
                Button { app.settingsPresented = true } label: {
                    Label("Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(12)
                .keyboardShortcut(",", modifiers: .command)
            }
        } detail: {
            detail
                .background(DesignTokens.background)
                .foregroundStyle(DesignTokens.ink)
        }
        .tint(DesignTokens.ember)
        .sheet(item: Bindable(app).presentedEditor) { presentation in
            GoalEditorView(presentation: presentation)
                .frame(width: 620, height: 560)
        }
        .sheet(item: Bindable(app).presentedResolution) { event in
            StoryResolutionView(event: event)
                .frame(width: 720, height: 640)
        }
        .sheet(isPresented: Bindable(app).settingsPresented) {
            SettingsView()
                .frame(width: 660, height: 700)
        }
        .alert("Something went wrong", isPresented: Binding(get: { app.errorMessage != nil }, set: { if !$0 { app.errorMessage = nil } })) {
            Button("OK") { app.errorMessage = nil }
        } message: { Text(app.errorMessage ?? "") }
        .alert("Allow goal reminders?", isPresented: Binding(get: { app.notificationPermissionOccurrence != nil }, set: { if !$0 { app.notificationPermissionOccurrence = nil } })) {
            Button("Not Now", role: .cancel) { app.notificationPermissionOccurrence = nil }
            Button("Continue") { Task { await app.confirmNotificationPermission() } }
        } message: {
            Text("The Horde can notify you when dated goals are due. Your goals still work if you decline.")
        }
    }

    private var selection: Binding<AppTab?> {
        Binding(get: { app.selectedTab }, set: { if let tab = $0 { app.selectedTab = tab } })
    }

    @ViewBuilder private var detail: some View {
        switch app.selectedTab {
        case .today:
            NavigationStack(path: Bindable(app).todayPath) {
                TodayView()
                    .navigationDestination(for: TodayRoute.self, destination: todayDestination)
            }
        case .dungeon:
            NavigationStack(path: $dungeonPath) { DungeonView() }
        case .chronicle:
            NavigationStack(path: $chroniclePath) { ChronicleView() }
        }
    }

    @ViewBuilder private func todayDestination(_ route: TodayRoute) -> some View {
        switch route {
        case .goal(let id): GoalDetailView(definitionID: id)
        case .chronicle(let id):
            if let entry = app.chronicle.first(where: { $0.id == id }) {
                ChronicleDetailView(entry: entry)
            } else {
                ContentUnavailableView("Story unavailable", systemImage: "book.closed")
            }
        }
    }
}
#endif
