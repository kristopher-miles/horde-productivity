import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()
            Group {
                if app.compatibility == .available {
                if let message = app.initialLoadError {
                    ContentUnavailableView {
                        Label("Local data unavailable", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") { Task { await app.retryInitialLoad() } }
                    }
                } else if !app.rootReady {
                    ProgressView("Loading local data")
                } else if app.onboardingComplete {
                    #if os(macOS)
                    MacMainView()
                    #else
                    MainTabView()
                    #endif
                } else {
                    OnboardingView()
                }
                } else {
                    CompatibilityView(state: app.compatibility) { Task { await app.recheckCompatibility() } }
                }
            }
        }
        .foregroundStyle(DesignTokens.ink)
        .task { await app.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await app.recheckCompatibility() } }
        }
    }
}
