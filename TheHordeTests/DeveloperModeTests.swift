import Foundation
import Testing
@testable import TheHorde

@Suite("Developer mode")
struct DeveloperModeTests {
    @Test func defaultsOnAndHonorsPersistedOffConfiguration() throws {
        let suiteName = "DeveloperModeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(DeveloperMode.isEnabled(in: defaults))
        defaults.set(false, forKey: DeveloperMode.defaultsKey)
        #expect(!DeveloperMode.isEnabled(in: defaults))
    }

    @Test func promptAndLogEntryPointsFollowTheSingleGate() {
        #expect(DeveloperMode.visibleSurfaces(isEnabled: true).map(\.title) == ["Prompt Editor", "Model Logs"])
        #expect(DeveloperMode.visibleSurfaces(isEnabled: false).isEmpty)
    }
}
