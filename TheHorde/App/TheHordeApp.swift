import SwiftUI

@main struct TheHordeApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            root
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
        WindowGroup { root }
        #endif
    }

    @ViewBuilder private var root: some View {
        #if DEBUG
        if DragonStageFixtureView.isEnabled {
            DragonStageFixtureView()
        } else {
            RootView().environment(app)
        }
        #else
        RootView().environment(app)
        #endif
    }
}
