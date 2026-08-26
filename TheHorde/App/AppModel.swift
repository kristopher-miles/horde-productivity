import Foundation
import Observation
import SwiftData
import UserNotifications

enum AppTab: Hashable { case today, dungeon, chronicle }
enum TodayRoute: Hashable { case goal(String), chronicle(String) }

@MainActor @Observable final class AppModel {
    private(set) var compatibility: CompatibilityState = .checking
    private(set) var modelContainer: ModelContainer?
    private(set) var rootReady = false
    private(set) var initialLoadError: String?
    private(set) var onboardingComplete = false
    private(set) var occurrences: [GoalOccurrenceSummary] = []
    private(set) var pendingStoryCount = 0
    private(set) var pendingStories: [PendingStorySummary] = []
    private(set) var world: WorldReadModel?
    private(set) var chronicle: [ChronicleSummary] = []
    var presentedEditor: GoalEditorPresentation?
    var presentedResolution: PendingStorySummary?
    var settingsPresented = false
    var selectedTab: AppTab = .today
    var todayPath: [TodayRoute] = []
    var exportURL: URL?
    var errorMessage: String?
    var notificationPermissionOccurrence: GoalOccurrenceSummary?
    private let modelClient = FoundationModelClient()
    private var store: HordeStore?
    private var coordinator: ResolutionCoordinator?
    private var started = false
    func start() async {
        guard !started else { return }
        started = true
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        NotificationRouter.shared.onTarget = { [weak self] occurrenceID, eventID in
            Task { await self?.routeNotification(occurrenceID: occurrenceID, eventID: eventID) }
        }
        do {
            #if DEBUG
            if ProcessInfo.processInfo.environment["HORDE_RESET_UI_STATE"] == "1" {
                try HordeStore.resetDefaultStore()
                UserDefaults.standard.removeObject(forKey: "onboardingStep")
            }
            #endif
            let container = try HordeStore.makeContainer()
            modelContainer = container
            store = HordeStore(modelContainer: container)
            coordinator = store.map { ResolutionCoordinator(store: $0, model: modelClient) }
        } catch {
            compatibility = .unknown
            return
        }
        await recheckCompatibility()
    }

    func recheckCompatibility() async {
        if !rootReady { compatibility = .checking }
        #if DEBUG
        if let forced = Self.forcedCompatibilityState {
            compatibility = forced
        } else if ProcessInfo.processInfo.environment["HORDE_BYPASS_COMPATIBILITY"] == "1" {
            compatibility = .available
        } else {
            compatibility = await modelClient.compatibility()
        }
        #else
        compatibility = await modelClient.compatibility()
        #endif
        if compatibility == .available, !rootReady {
            do {
                initialLoadError = nil
                #if DEBUG
                if ProcessInfo.processInfo.environment["HORDE_FORCE_LOAD_FAILURE"] == "1" {
                    initialLoadError = "Your local data could not be loaded."
                    rootReady = true
                    return
                }
                #endif
                onboardingComplete = try await store?.prepareAppState() ?? false
                #if DEBUG
                if !onboardingComplete, ProcessInfo.processInfo.environment["HORDE_AUTOMATE_ONBOARDING"] == "1" {
                    try await store?.completeOnboarding(dragonName: "Ember", dungeonName: "The Cinder Vault")
                    onboardingComplete = true
                }
                #endif
                if onboardingComplete {
                    try await store?.bootstrapForProof()
                    try await reconcileAndReload()
                }
                rootReady = true
            } catch {
                initialLoadError = "Your local data could not be loaded."
                rootReady = true
            }
        }
    }

    func retryInitialLoad() async {
        initialLoadError = nil
        rootReady = false
        await recheckCompatibility()
    }

    func reload() async {
        #if DEBUG
        if let fixture = Self.productVerificationFixture {
            occurrences = fixture.occurrences
            pendingStories = fixture.pendingStories
            pendingStoryCount = fixture.pendingStories.count
            world = fixture.world
            chronicle = fixture.chronicle
            return
        }
        #endif
        do {
            occurrences = try await store?.occurrenceSummaries() ?? []
            pendingStories = try await store?.pendingStories() ?? []
            pendingStoryCount = pendingStories.count
            world = try await store?.worldReadModel()
            chronicle = try await store?.chronicle() ?? []
        } catch { errorMessage = "Your goals could not be refreshed." }
    }

    func reconcileAndReload() async throws {
        _ = try await store?.reconcileDeadlines()
        await reload()
        await scheduleAuthorizedPendingNotifications()
    }

    func createGoal(_ draft: GoalDraft) async -> Bool {
        do {
            let definitionID = try await store?.createGoal(draft)
            await reload()
            if let definitionID, let occurrence = occurrences.first(where: { $0.definitionID == definitionID && $0.state == .pending && $0.dueDate != nil }) { await configureNotification(for: occurrence) }
            return true
        } catch {
            errorMessage = "The goal could not be saved. Your existing data is unchanged."
            return false
        }
    }

    func updateGoal(id: String, draft: GoalDraft) async -> Bool {
        do {
            let oldIDs = occurrences.filter { $0.definitionID == id && $0.state == .pending }.map(\.id)
            try await store?.updateGoal(id: id, draft: draft)
            await NotificationScheduler.shared.cancel(occurrenceIDs: oldIDs)
            await reload()
            if let occurrence = occurrences.first(where: { $0.definitionID == id && $0.state == .pending && $0.dueDate != nil }) { await configureNotification(for: occurrence) }
            return true
        } catch {
            errorMessage = "Changes could not be saved. The previous goal is intact."
            return false
        }
    }

    func complete(_ occurrence: GoalOccurrenceSummary) async {
        guard occurrence.state == .pending else { return }
        do {
            let successorID = try await store?.completeOccurrence(id: occurrence.id)
            await NotificationScheduler.shared.cancel(occurrenceIDs: [occurrence.id])
            await reload()
            if let successorID, let successor = occurrences.first(where: { $0.id == successorID }) { await configureNotification(for: successor) }
            presentedResolution = pendingStories.first { $0.id.hasPrefix(occurrence.id + ":") }
        } catch { errorMessage = "Completion could not be saved. Please try again." }
    }

    func definition(id: String) async -> GoalDefinitionSummary? {
        #if DEBUG
        if let definition = Self.productVerificationFixture?.definitions.first(where: { $0.id == id }) { return definition }
        #endif
        return try? await store?.definitionSummary(id: id)
    }

    func archiveGoal(id: String) async -> Bool {
        do {
            let ids = occurrences.filter { $0.definitionID == id && $0.state == .pending }.map(\.id)
            try await store?.archiveGoal(id: id)
            await NotificationScheduler.shared.cancel(occurrenceIDs: ids)
            await reload()
            return true
        }
        catch { errorMessage = "The goal could not be archived."; return false }
    }

    func deleteGoal(id: String) async -> Bool {
        do {
            let ids = occurrences.filter { $0.definitionID == id }.map(\.id)
            try await store?.deleteGoal(id: id)
            await NotificationScheduler.shared.cancel(occurrenceIDs: ids)
            await reload(); return true
        } catch { errorMessage = "The goal could not be deleted."; return false }
    }

    func openNextPendingStory() { presentedResolution = pendingStories.first }

    func resolve(eventID: String) async -> ResolutionOutcome {
        guard let coordinator else { return .failed(code: "persistenceFailure") }
        let outcome = await coordinator.resolve(eventID: eventID)
        await reload()
        return outcome
    }

    func suggestAction(eventID: String) async -> ActionSuggestionOutcome {
        guard let coordinator else { return .failed(code: "persistenceFailure") }
        let outcome = await coordinator.suggestAction(eventID: eventID)
        await reload()
        presentedResolution = pendingStories.first { $0.id == eventID }
        return outcome
    }

    func interpretCustomAction(eventID: String, customAction: String) async -> CustomActionInterpretationOutcome {
        guard let coordinator else { return .failed(code: "persistenceFailure") }
        let outcome = await coordinator.interpretCustomAction(eventID: eventID, customAction: customAction)
        await reload()
        presentedResolution = pendingStories.first { $0.id == eventID }
        return outcome
    }

    private func configureNotification(for occurrence: GoalOccurrenceSummary) async {
        do {
            let scheduler = NotificationScheduler.shared
            let status = await scheduler.authorizationStatus()
            if status == .notDetermined { notificationPermissionOccurrence = occurrence; return }
            if status.hordeCanSchedule { try await scheduler.schedule(occurrence: occurrence) }
        } catch { /* Goal persistence succeeds even when notifications do not. */ }
    }

    func confirmNotificationPermission() async {
        guard let occurrence = notificationPermissionOccurrence else { return }
        notificationPermissionOccurrence = nil
        do {
            if try await NotificationScheduler.shared.requestAuthorization() { try await NotificationScheduler.shared.schedule(occurrence: occurrence) }
        } catch { /* Goal persistence succeeds even when notifications do not. */ }
    }

    private func scheduleAuthorizedPendingNotifications() async {
        let status = await NotificationScheduler.shared.authorizationStatus()
        guard status.hordeCanSchedule else { return }
        for occurrence in occurrences where occurrence.state == .pending && occurrence.dueDate != nil { try? await NotificationScheduler.shared.schedule(occurrence: occurrence) }
    }

    func finishOnboarding(dragonName: String, dungeonName: String, dragonColor: RGBColor = .ember) async -> Bool {
        do {
            try await store?.completeOnboarding(dragonName: dragonName, dungeonName: dungeonName, dragonColor: dragonColor)
            onboardingComplete = true
            try await reconcileAndReload()
            return true
        } catch { errorMessage = "Your dungeon could not be created. Nothing partial was saved."; return false }
    }

    func createExport() async {
        do {
            let data = try await store?.exportLocalData() ?? Data()
            let url = Self.exportFileURL()
            try Self.removeOwnedExport()
            try data.write(to: url, options: .atomic)
            exportURL = url
        } catch { errorMessage = "The export could not be created. Your data is unchanged." }
    }

    func resetDungeon() async -> Bool {
        do { try await store?.resetDungeon(); await reload(); return true }
        catch { errorMessage = "The dungeon could not be reset. Existing data is unchanged."; return false }
    }

    func deleteAllData() async -> Bool {
        do {
            try Self.removeOwnedExport()
            try await store?.deleteAllLocalData()
            await NotificationScheduler.shared.cancelAll()
            exportURL = nil; occurrences = []; pendingStories = []; pendingStoryCount = 0; world = nil; chronicle = []; todayPath = []; presentedResolution = nil; settingsPresented = false; onboardingComplete = false; rootReady = true
            return true
        } catch { errorMessage = "Local data could not be deleted. Existing data is unchanged."; return false }
    }

    nonisolated static func exportFileURL(in directory: URL = FileManager.default.temporaryDirectory) -> URL {
        directory.appending(path: "The-Horde-Export.json")
    }

    nonisolated static func removeOwnedExport(in directory: URL = FileManager.default.temporaryDirectory) throws {
        let url = exportFileURL(in: directory)
        if FileManager.default.fileExists(atPath: url.path()) { try FileManager.default.removeItem(at: url) }
    }

    #if DEBUG
    private nonisolated static var productVerificationFixture: ProductVerificationFixture? {
        ProcessInfo.processInfo.environment["HORDE_PRODUCT_SCENARIO"].flatMap(ProductVerificationFixture.named)
    }

    private nonisolated static var forcedCompatibilityState: CompatibilityState? {
        switch ProcessInfo.processInfo.environment["HORDE_FORCE_COMPATIBILITY"] {
        case "checking": .checking
        case "deviceNotEligible": .deviceNotEligible
        case "intelligenceDisabled": .intelligenceDisabled
        case "modelNotReady": .modelNotReady
        case "unsupportedLocale": .unsupportedLocale
        case "unknown": .unknown
        default: nil
        }
    }
    #endif

    func routeNotification(occurrenceID: String?, eventID: String? = nil) async {
        selectedTab = .today
        do { try await reconcileAndReload() } catch { errorMessage = "The notification destination could not be refreshed." }
        switch NotificationDestination.resolve(occurrenceID: occurrenceID, eventID: eventID, occurrences: occurrences, pendingStories: pendingStories, chronicle: chronicle) {
        case .resolution(let id): presentedResolution = pendingStories.first { $0.id == id }
        case .chronicle(let id): todayPath = [.chronicle(id)]
        case .goal(let id): todayPath = [.goal(id)]
        case .stale: todayPath = []; errorMessage = "That notification refers to a goal that is no longer available."
        }
    }
}

struct GoalEditorPresentation: Identifiable {
    let id = UUID()
    let definitionID: String?
    let initialDraft: GoalDraft

    static let new = GoalEditorPresentation(definitionID: nil, initialDraft: GoalDraft())
}
