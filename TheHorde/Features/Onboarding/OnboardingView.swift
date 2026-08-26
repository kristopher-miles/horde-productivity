import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct OnboardingView: View {
    nonisolated static let startingCavernAccessibilityLabel = "A young, small, newly independent baby dragon has just claimed an empty cavern that is dirty, cold, unruly, and dangerous, and is not yet powerful or established."
    @Environment(AppModel.self) private var app
    @AppStorage("onboardingStep") private var step = 0
    @State private var dragonName = "Ember"
    @State private var dungeonName = "The Cinder Vault"
    @State private var dragonColor = RGBColor.ember
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
                        dragonColorControls
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
        DungeonSceneView(
            world: WorldReadModel(
                dungeonName: dungeonName,
                revision: 0,
                snapshot: .initial(dragonName: dragonName, dungeonName: dungeonName, dragonColor: dragonColor)
            ),
            accessibilityDescription: Self.startingCavernAccessibilityLabel
        )
    }

    private var dragonColorControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dragon color").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                ForEach(CuratedDragonColor.allCases) { choice in
                    Button {
                        dragonColor = choice.color
                    } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(Color(choice.color))
                                .overlay(Circle().stroke(dragonColor == choice.color ? Color.accentColor : .clear, lineWidth: 3))
                                .frame(width: 36, height: 36)
                            Text(choice.name).font(.caption)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(choice.name) dragon color")
                    .accessibilityValue(dragonColor == choice.color ? "Selected" : "Not selected")
                }
            }
            ColorPicker("Custom dragon color", selection: Binding(
                get: { Color(dragonColor) },
                set: { dragonColor = RGBColor($0) }
            ), supportsOpacity: false)
        }
        .hordeCard()
    }

    private func finish() {
        saving = true
        Task {
            if await app.finishOnboarding(dragonName: dragonName, dungeonName: dungeonName, dragonColor: dragonColor) { step = 0 }
            else { saving = false }
        }
    }
}

private extension Color {
    init(_ color: RGBColor) {
        self.init(
            red: Double(color.red) / 255,
            green: Double(color.green) / 255,
            blue: Double(color.blue) / 255
        )
    }
}

private extension RGBColor {
    init(_ color: Color) {
        #if os(iOS)
        let components = UIColor(color).cgColor.components ?? [0, 0, 0]
        #else
        let components = NSColor(color).usingColorSpace(.sRGB)?.cgColor.components ?? [0, 0, 0]
        #endif
        let red = components[0]
        let green = components.count > 2 ? components[1] : red
        let blue = components.count > 2 ? components[2] : red
        self.init(
            red: UInt8(clamping: Int((red * 255).rounded())),
            green: UInt8(clamping: Int((green * 255).rounded())),
            blue: UInt8(clamping: Int((blue * 255).rounded()))
        )
    }
}
