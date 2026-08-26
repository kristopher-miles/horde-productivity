import SwiftUI

struct CompatibilityView: View {
    @Environment(\.openURL) private var openURL
    let state: CompatibilityState
    let retry: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: icon)
                    .font(.system(size: 54))
                    .foregroundStyle(DesignTokens.ember)
                    .accessibilityHidden(true)
                Text(state.title).font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text(message).font(.body).multilineTextAlignment(.center)
                if state != .checking {
                    if state == .intelligenceDisabled || state == .unsupportedLocale {
                        Button("Open Settings") { openURL(PlatformSupport.settingsURL) }
                            .buttonStyle(.bordered).controlSize(.large).frame(minHeight: 44)
                    }
                    Button("Check Again", action: retry)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(minHeight: 44)
                } else {
                    ProgressView().accessibilityLabel("Checking model availability")
                }
            }
            .padding(32)
            .frame(maxWidth: 560)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.background)
    }

    private var icon: String {
        switch state {
        case .checking: "sparkles"
        case .deviceNotEligible: PlatformSupport.deviceName == "Mac" ? "macbook.slash" : "iphone.slash"
        case .intelligenceDisabled: "apple.intelligence"
        case .modelNotReady: "arrow.down.circle"
        case .unsupportedLocale: "character.bubble"
        default: "exclamationmark.triangle"
        }
    }

    private var message: String {
        switch state {
        case .checking: "The Horde uses Apple’s on-device model to create your private dungeon story."
        case .deviceNotEligible: "The story model requires an Apple Intelligence-capable \(PlatformSupport.deviceName) running version 26 or later. No reduced or cloud story mode is used."
        case .intelligenceDisabled: "Enable Apple Intelligence in Settings, then return here. Your goal and story data remain local to this app."
        case .modelNotReady: "The system is still preparing its on-device model. Keep this device powered and check again later; no percentage is available to the app."
        case .unsupportedLocale: "The current app language is not supported by the on-device model. Change to a supported language and check again."
        case .unknown: "The on-device model could not be reached. Nothing has been created or sent elsewhere."
        case .available: "The on-device model is ready."
        }
    }
}
