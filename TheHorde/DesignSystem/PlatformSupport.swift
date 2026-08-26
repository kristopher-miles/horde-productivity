import SwiftUI
import UserNotifications

#if os(iOS)
import UIKit
#endif

enum PlatformSupport {
    #if os(macOS)
    static let deviceName = "Mac"
    static let localDevicePhrase = "on this Mac"
    static let settingsURL = URL(string: "x-apple.systempreferences:")!
    static let notificationSettingsURL = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
    #else
    static let deviceName = "iPhone"
    static let localDevicePhrase = "on your iPhone"
    static let settingsURL = URL(string: UIApplication.openSettingsURLString)!
    static let notificationSettingsURL = URL(string: UIApplication.openNotificationSettingsURLString)!
    #endif

    @MainActor static func completionFeedback() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    @MainActor static func resolutionFeedback(positive: Bool) {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(positive ? .success : .warning)
        #endif
    }
}

extension UNAuthorizationStatus {
    var hordeCanSchedule: Bool {
        switch self {
        case .authorized, .provisional: true
        #if os(iOS)
        case .ephemeral: true
        #endif
        default: false
        }
    }
}

extension View {
    @ViewBuilder func hordeInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder func hordeSentenceAutocapitalization() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.sentences)
        #else
        self
        #endif
    }

    @ViewBuilder func hordeSettingsFormStyle() -> some View {
        #if os(macOS)
        formStyle(.grouped)
        #else
        self
        #endif
    }
}
