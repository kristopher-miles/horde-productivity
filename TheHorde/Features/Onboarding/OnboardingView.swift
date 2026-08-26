import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @AppStorage("onboardingStep") private var step = 0
    @State private var dragonName = "Ember"
    @State private var dungeonName = "The Cinder Vault"
    @State private var saving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    onboardingArt
                    if step == 0 {
                        Text("Real goals shape a small local dungeon story.").font(.largeTitle.bold()).multilineTextAlignment(.center)
                        Text("Complete what matters to you. Apple’s on-device model invents a gentle consequence, while the app independently validates every lasting change.").multilineTextAlignment(.center)
                        Label("Your goals and dungeon stay in this app \(PlatformSupport.localDevicePhrase).", systemImage: PlatformSupport.deviceName == "Mac" ? "macbook" : "iphone.and.arrow.forward.inward").font(.subheadline).hordeCard()
                        Button("Continue") { withAnimation { step = 1 } }.buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        Text("Name your little world").font(.largeTitle.bold()).multilineTextAlignment(.center)
                        Text("These names are optional. You can keep the defaults.").foregroundStyle(.secondary)
                        VStack(spacing: 14) {
                            TextField("Dragon name", text: $dragonName).textFieldStyle(.roundedBorder).accessibilityLabel("Dragon name, optional")
                            TextField("Dungeon name", text: $dungeonName).textFieldStyle(.roundedBorder).accessibilityLabel("Dungeon name, optional")
                        }.hordeCard()
                        Button("Enter the Dungeon") { finish() }.buttonStyle(.borderedProminent).controlSize(.large).disabled(saving).frame(maxWidth: .infinity, minHeight: 44)
                        Button("Back") { withAnimation { step = 0 } }.frame(minHeight: 44)
                    }
                }
                .padding(24)
                .frame(maxWidth: 560)
            }.frame(maxWidth: .infinity)
        }
    }

    private var onboardingArt: some View {
        Image("DungeonNormal")
            .resizable()
            .interpolation(.none)
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ember, a small dragon, rests alone in an empty cavern.")
    }

    private func finish() {
        saving = true
        Task {
            if await app.finishOnboarding(dragonName: dragonName, dungeonName: dungeonName) { step = 0 }
            else { saving = false }
        }
    }
}
