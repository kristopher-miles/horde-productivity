import SwiftUI

#if os(iOS)
struct MainTabView: View {
    @Environment(AppModel.self) private var app
    @State private var dungeonPath = NavigationPath()
    @State private var chroniclePath = NavigationPath()

    var body: some View {
        TabView(selection: Bindable(app).selectedTab) {
            Tab("Today", systemImage: "checklist", value: .today) {
                NavigationStack(path: Bindable(app).todayPath) {
                    TodayView()
                        .navigationDestination(for: TodayRoute.self, destination: todayDestination)
                }
            }
            Tab("Dungeon", systemImage: "castle", value: .dungeon) {
                NavigationStack(path: $dungeonPath) {
                    DungeonView()
                }
            }
            Tab("Chronicle", systemImage: "book.pages", value: .chronicle) {
                NavigationStack(path: $chroniclePath) {
                    ChronicleView()
                }
            }
        }
        .tint(DesignTokens.ember)
        .fullScreenCover(item: Bindable(app).presentedEditor) { presentation in
            GoalEditorView(presentation: presentation)
        }
        .sheet(item: Bindable(app).presentedResolution) { event in
            StoryResolutionView(event: event)
        }
        .sheet(isPresented: Bindable(app).settingsPresented) { SettingsView() }
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

    @ViewBuilder private func todayDestination(_ route: TodayRoute) -> some View {
        switch route {
        case .goal(let id): GoalDetailView(definitionID: id)
        case .chronicle(let id):
            if let entry = app.chronicle.first(where: { $0.id == id }) { ChronicleDetailView(entry: entry) }
            else { ContentUnavailableView("Story unavailable", systemImage: "book.closed") }
        }
    }
}
#endif
