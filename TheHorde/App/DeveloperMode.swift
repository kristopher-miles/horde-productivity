import Foundation

enum DeveloperSurface: CaseIterable {
    case promptEditor
    case modelLogs

    var title: String {
        switch self {
        case .promptEditor: "Prompt Editor"
        case .modelLogs: "Model Logs"
        }
    }

    var systemImage: String {
        switch self {
        case .promptEditor: "text.badge.star"
        case .modelLogs: "list.bullet.rectangle"
        }
    }
}

enum DeveloperMode {
    static let defaultsKey = "developerModeEnabled"
    static let defaultEnabled = true

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: defaultsKey) as? Bool ?? defaultEnabled
    }

    static func visibleSurfaces(isEnabled: Bool) -> [DeveloperSurface] {
        isEnabled ? DeveloperSurface.allCases : []
    }
}
