import SwiftUI

@main struct TheHordeApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            RootView()
                .environment(app)
                .frame(minWidth: 780, minHeight: 560)
        }
        .defaultSize(width: 1120, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Goal") { app.presentedEditor = .new }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(!app.onboardingComplete)
            }
        }
        #else
        WindowGroup { RootView().environment(app) }
        #endif
    }
}
