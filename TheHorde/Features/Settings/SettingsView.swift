import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("motionPreference") private var motionPreference = "system"
    @AppStorage(DeveloperMode.defaultsKey) private var developerModeEnabled = DeveloperMode.defaultEnabled
    @State private var notificationStatus = "Checking…"
    @State private var confirmReset = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Experience") {
                    LabeledContent("Notifications", value: notificationStatus)
                    Button("Open Notification Settings", systemImage: "gear") { openURL(PlatformSupport.notificationSettingsURL) }
                    #if os(iOS)
                    Toggle("Haptics", isOn: $hapticsEnabled)
                    #endif
                    Picker("Motion", selection: $motionPreference) { Text("System").tag("system"); Text("Reduced").tag("reduced"); Text("Full").tag("full") }
                }
                Section("Model & Privacy") {
                    LabeledContent("On-device model", value: app.compatibility.title)
                    Text("The core experience performs no app networking. Goal text, story context, generated prose, and dungeon state are processed and stored locally by this build using Apple’s on-device system model.")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("This statement describes The Horde, not every network activity the operating system may perform.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Section("Local Data") {
                    Button("Prepare Export", systemImage: "square.and.arrow.up") { Task { await app.createExport() } }
                    if let url = app.exportURL { ShareLink(item: url) { Label("Share Local Data JSON", systemImage: "doc.text") } }
                    Button("Reset Dungeon", systemImage: "arrow.counterclockwise") { confirmReset = true }
                    Button("Delete All Local Data", systemImage: "trash", role: .destructive) { confirmDelete = true }
                }
                Section("Developer") {
                    Toggle("Developer Mode", isOn: $developerModeEnabled)
                    ForEach(DeveloperMode.visibleSurfaces(isEnabled: developerModeEnabled), id: \.title) { surface in
                        NavigationLink {
                            DeveloperSurfaceView(surface: surface)
                        } label: {
                            Label(surface.title, systemImage: surface.systemImage)
                        }
                    }
                }
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    Text("A local productivity companion for \(PlatformSupport.deviceName). No account, cloud sync, analytics, purchases, or social features are included.")
                }
            }
            .hordeSettingsFormStyle()
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await loadNotificationStatus() }
            .confirmationDialog("Reset the dungeon?", isPresented: $confirmReset) {
                Button("Reset Dungeon", role: .destructive) { Task { _ = await app.resetDungeon() } }
                Button("Cancel", role: .cancel) {}
            } message: { Text("The world returns to its initial state. Story events and Chronicle entries, including pending stories, are removed. Goals and future schedules are preserved.") }
            .confirmationDialog("Delete all local data?", isPresented: $confirmDelete) {
                Button("Delete Everything", role: .destructive) { Task { if await app.deleteAllData() { dismiss() } } }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Goals, occurrences, dungeon state, pending stories, Chronicle history, cached export, and pending notifications are permanently removed from this app. You will return to first run.") }
        }
    }

    private func loadNotificationStatus() async {
        switch await NotificationScheduler.shared.authorizationStatus() {
        case .authorized, .provisional: notificationStatus = "Allowed"
        #if os(iOS)
        case .ephemeral: notificationStatus = "Allowed"
        #endif
        case .denied: notificationStatus = "Denied"
        case .notDetermined: notificationStatus = "Not requested"
        @unknown default: notificationStatus = "Unknown"
        }
    }
}

private struct DeveloperSurfaceView: View {
    let surface: DeveloperSurface
    @AppStorage(DeveloperMode.defaultsKey) private var developerModeEnabled = DeveloperMode.defaultEnabled

    var body: some View {
        if developerModeEnabled {
            switch surface {
            case .promptEditor:
                ModelPromptEditorView()
            case .modelLogs:
                ModelDevLogBrowserView()
            }
        } else {
            ContentUnavailableView("Developer Mode Off", systemImage: "lock")
        }
    }
}
