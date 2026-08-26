import Foundation
import SwiftData

enum StoreError: Error, Equatable { case missingSave, missingEvent, staleRevision, eventAlreadyResolved, invalidResolutionState, injectedFailure }

@ModelActor actor HordeStore {
    static let schema = Schema(HordeSchemaV4.models, version: HordeSchemaV4.versionIdentifier)

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [configuration])
        }
        let url = try defaultStoreURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return try makeContainer(url: url)
    }

    static func makeContainer(url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration("TheHorde", schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func defaultStoreURL(fileManager: FileManager = .default) throws -> URL {
        guard let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return applicationSupport
            .appending(path: "TheHorde", directoryHint: .isDirectory)
            .appending(path: "TheHorde-v4.store")
    }

    #if DEBUG
    static func resetStoreFiles(at url: URL, fileManager: FileManager = .default) throws {
        for suffix in ["", "-shm", "-wal"] {
            let fileURL = URL(filePath: url.path() + suffix)
            if fileManager.fileExists(atPath: fileURL.path()) {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }

    static func resetDefaultStore(fileManager: FileManager = .default) throws {
        try resetStoreFiles(at: defaultStoreURL(fileManager: fileManager), fileManager: fileManager)
    }
    #endif

    #if DEBUG
    func insertChronicleFixture(count: Int) throws {
        try bootstrapForProof()
        let save = try requireSave()
        let recordedWorld = try PersistentJSON.encode(WorldReadModel(dungeonName: save.dungeonName, revision: save.revision, snapshot: decodeWorld(save)))
        for index in 0..<count {
            let id = "fixture-event-\(index)"
            let patch = try PersistentJSON.encode([WorldMutation.increment("world.morale", by: 1)])
            let deltas = try PersistentJSON.encode([WorldDelta(fieldID: "world.morale", description: "Morale fixture \(index)")])
            modelContext.insert(ChronicleRecord(eventID: id, sourceTitle: "Fixture goal \(index)", valence: index.isMultiple(of: 2) ? .positive : .negative, generatedTitle: "Fixture Tale \(index)", finalProse: "A bounded local fixture used to measure Chronicle reads.", summary: "Fixture \(index)", patchJSON: patch, priorRevision: index, committedRevision: index + 1, recordedWorldData: recordedWorld, committedAt: Date(timeIntervalSince1970: Double(index)), deltasJSON: deltas, animationCue: .idle))
        }
        try modelContext.save()
    }

    func installWorldFixture(_ world: WorldSnapshot, dungeonName: String, revision: Int) throws {
        let save = try requireSave()
        save.dungeonName = dungeonName
        save.dragonName = world.dragon.name
        save.morale = world.morale
        save.integrity = world.integrity
        save.food = world.food
        save.rollingSummary = world.rollingSummary
        save.worldData = try PersistentJSON.encode(world)
        save.revision = revision
        try modelContext.save()
    }
    #endif

    func prepareAppState() throws -> Bool {
        modelContext.autosaveEnabled = false
        if let state = try modelContext.fetch(FetchDescriptor<AppStateRecord>()).first { return state.onboardingComplete }
        modelContext.insert(AppStateRecord())
        try modelContext.save()
        return false
    }

    func completeOnboarding(dragonName: String, dungeonName: String, dragonColor: RGBColor = .ember) throws {
        let dragon = dragonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ember" : String(dragonName.prefix(40))
        let dungeon = dungeonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "The Cinder Vault" : String(dungeonName.prefix(60))
        do {
            try modelContext.transaction {
                let existingState = try modelContext.fetch(FetchDescriptor<AppStateRecord>()).first
                let state = existingState ?? AppStateRecord()
                if existingState == nil { modelContext.insert(state) }
                if try modelContext.fetch(FetchDescriptor<GameSaveRecord>()).isEmpty {
                    modelContext.insert(GameSaveRecord(dungeonName: dungeon, dragonName: dragon, dragonColor: dragonColor))
                } else if let save = try modelContext.fetch(FetchDescriptor<GameSaveRecord>()).first, !state.onboardingComplete {
                    let world = WorldSnapshot.initial(dragonName: dragon, dungeonName: dungeon, dragonColor: dragonColor)
                    save.dungeonName = dungeon; save.dragonName = dragon; save.rollingSummary = world.rollingSummary; save.worldData = try PersistentJSON.encode(world)
                }
                state.onboardingComplete = true
                try modelContext.save()
            }
        } catch { modelContext.rollback(); throw error }
    }

    func bootstrapForProof() throws {
        modelContext.autosaveEnabled = false
        if try modelContext.fetch(FetchDescriptor<GameSaveRecord>()).isEmpty {
            modelContext.insert(GameSaveRecord())
            try modelContext.save()
        }
        let resolving = try modelContext.fetch(FetchDescriptor<StoryEventRecord>(predicate: #Predicate { $0.statusRaw == "resolving" }))
        if !resolving.isEmpty {
            resolving.forEach { $0.statusRaw = EventStatus.pending.rawValue; $0.updatedAt = .now }
            try modelContext.save()
        }
    }

    func insertProofEvent(id: String = "proof-event", occurrenceID: String = "proof-occurrence", title: String = "Finish the platform proof", valence: EventValence = .positive) throws {
        try bootstrapForProof()
        guard try modelContext.fetch(FetchDescriptor<StoryEventRecord>(predicate: #Predicate { $0.id == id })).isEmpty else { return }
        let save = try requireSave()
        modelContext.insert(StoryEventRecord(id: id, sourceOccurrenceID: occurrenceID, sourceTitle: title, valence: valence, expectedRevision: save.revision))
        try modelContext.save()
    }

    func commitProof(eventID: String, mutations: [StagedMutation], title: String, narration: String, summary: String, failBeforeSave: Bool = false) throws {
        modelContext.autosaveEnabled = false
        do {
            try modelContext.transaction {
                let event = try requireEvent(eventID)
                let save = try requireSave()
                guard event.statusRaw != EventStatus.resolved.rawValue else { throw StoreError.eventAlreadyResolved }
                guard event.expectedRevision == save.revision else { throw StoreError.staleRevision }
                let descriptors = Self.proofDescriptors
                try PatchValidator.validate(mutations, descriptors: descriptors, currentValues: ["world.morale": save.morale, "world.integrity": save.integrity, "world.food": save.food], maximumCount: event.valenceRaw == EventValence.positive.rawValue ? 4 : 2)
                let prior = save.revision
                for mutation in mutations { apply(mutation, to: save) }
                save.revision += 1
                var world = decodeWorld(save)
                world.morale = save.morale; world.integrity = save.integrity; world.food = save.food
                save.worldData = try PersistentJSON.encode(world)
                let patch = try PersistentJSON.encode(mutations)
                let recordedWorld = try PersistentJSON.encode(WorldReadModel(dungeonName: save.dungeonName, revision: save.revision, snapshot: world))
                modelContext.insert(ChronicleRecord(eventID: event.id, sourceTitle: event.sourceTitle, valence: EventValence(rawValue: event.valenceRaw) ?? .positive, generatedTitle: title, finalProse: narration, summary: summary, patchJSON: patch, priorRevision: prior, committedRevision: save.revision, recordedWorldData: recordedWorld))
                event.statusRaw = EventStatus.resolved.rawValue
                event.committedRevision = save.revision
                event.updatedAt = .now
                if failBeforeSave { throw StoreError.injectedFailure }
                try modelContext.save()
            }
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func proofSnapshot(eventID: String) throws -> (revision: Int, status: String, chronicleCount: Int) {
        let save = try requireSave()
        let event = try requireEvent(eventID)
        let count = try modelContext.fetchCount(FetchDescriptor<ChronicleRecord>())
        return (save.revision, event.statusRaw, count)
    }

    static let proofDescriptors = [
        MutationDescriptor(fieldID: "world.morale", operations: [.increment], range: 0...100, maxDelta: 4),
        MutationDescriptor(fieldID: "world.integrity", operations: [.increment], range: 0...100, maxDelta: 4),
        MutationDescriptor(fieldID: "world.food", operations: [.increment], range: 0...100, maxDelta: 4)
    ]

    func createGoal(_ draft: GoalDraft, now: Date = .now, calendar: Calendar = .current) throws -> String {
        try ScheduleCalculator.validated(draft)
        modelContext.autosaveEnabled = false
        let id = UUID().uuidString
        let definition = GoalDefinitionRecord(id: id, draft: draft, now: now, timeZone: calendar.timeZone)
        do {
            try modelContext.transaction {
                modelContext.insert(definition)
                try materializeOccurrence(for: definition, due: ScheduleCalculator.firstDue(for: draft, now: now, calendar: calendar), now: now)
                try modelContext.save()
            }
            return id
        } catch { modelContext.rollback(); throw error }
    }

    func updateGoal(id: String, draft: GoalDraft, now: Date = .now, calendar: Calendar = .current) throws {
        try ScheduleCalculator.validated(draft)
        do {
            try modelContext.transaction {
                guard let definition = try definition(id) else { throw GoalStoreError.missingDefinition }
                let pending = try modelContext.fetch(FetchDescriptor<GoalOccurrenceRecord>(predicate: #Predicate { $0.definitionID == id && $0.stateRaw == "pending" }))
                pending.forEach { $0.stateRaw = GoalOccurrenceState.cancelled.rawValue; $0.resolvedAt = now }
                definition.update(from: draft, now: now, timeZone: calendar.timeZone)
                try materializeOccurrence(for: definition, due: ScheduleCalculator.firstDue(for: draft, now: now, calendar: calendar), now: now)
                try modelContext.save()
            }
        } catch { modelContext.rollback(); throw error }
    }

    @discardableResult func completeOccurrence(id: String, now: Date = .now, calendar: Calendar = .current) throws -> String? {
        try transitionOccurrence(id: id, state: .completed, valence: .positive, now: now, calendar: calendar)
    }

    @discardableResult func failOccurrence(id: String, now: Date = .now, calendar: Calendar = .current) throws -> String? {
        try transitionOccurrence(id: id, state: .failed, valence: .negative, now: now, calendar: calendar)
    }

    func reconcileDeadlines(now: Date = .now, calendar: Calendar = .current) throws -> Int {
        let descriptor = FetchDescriptor<GoalOccurrenceRecord>(predicate: #Predicate { $0.stateRaw == "pending" }, sortBy: [SortDescriptor(\.dueDate)])
        var count = 0
        while let occurrence = try modelContext.fetch(descriptor).first(where: { ($0.dueDate ?? .distantFuture) < now }) {
            _ = try transitionOccurrence(id: occurrence.id, state: .expired, valence: .negative, now: now, calendar: calendar)
            count += 1
        }
        return count
    }

    func archiveGoal(id: String, now: Date = .now) throws {
        do {
            try modelContext.transaction {
                guard let definition = try definition(id) else { throw GoalStoreError.missingDefinition }
                definition.archived = true; definition.updatedAt = now
                let pending = try modelContext.fetch(FetchDescriptor<GoalOccurrenceRecord>(predicate: #Predicate { $0.definitionID == id && $0.stateRaw == "pending" }))
                pending.forEach { $0.stateRaw = GoalOccurrenceState.cancelled.rawValue; $0.resolvedAt = now }
                try modelContext.save()
            }
        } catch { modelContext.rollback(); throw error }
    }

    func deleteGoal(id: String, now: Date = .now) throws {
        do {
            try modelContext.transaction {
                guard let definition = try definition(id) else { return }
                let occurrences = try modelContext.fetch(FetchDescriptor<GoalOccurrenceRecord>(predicate: #Predicate { $0.definitionID == id }))
                for occurrence in occurrences where occurrence.stateRaw == GoalOccurrenceState.pending.rawValue { modelContext.delete(occurrence) }
                modelContext.delete(definition)
                try modelContext.save()
            }
        } catch { modelContext.rollback(); throw error }
    }

    func occurrenceSummaries() throws -> [GoalOccurrenceSummary] {
        let events = try modelContext.fetch(FetchDescriptor<StoryEventRecord>())
        let pendingEventOccurrences = Set(events.filter { $0.statusRaw != EventStatus.resolved.rawValue }.map(\.sourceOccurrenceID))
        return try modelContext.fetch(FetchDescriptor<GoalOccurrenceRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])).map {
            GoalOccurrenceSummary(id: $0.id, definitionID: $0.definitionID, snapshot: $0.snapshot, dueDate: $0.dueDate, includesTime: $0.includesTime, timeZoneID: $0.timeZoneID, state: GoalOccurrenceState(rawValue: $0.stateRaw) ?? .cancelled, resolvedAt: $0.resolvedAt, hasPendingStory: pendingEventOccurrences.contains($0.id))
        }
    }

    func definitionSummary(id: String) throws -> GoalDefinitionSummary? {
        guard let definition = try definition(id) else { return nil }
        let history = try occurrenceSummaries().filter { $0.definitionID == id }
        return GoalDefinitionSummary(id: id, draft: definition.draft, version: definition.version, archived: definition.archived, history: history)
    }

    func pendingStoryCount() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<StoryEventRecord>(predicate: #Predicate { $0.statusRaw != "resolved" }))
    }

    func pendingStories() throws -> [PendingStorySummary] {
        let occurrences = Dictionary(uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<GoalOccurrenceRecord>()).map { ($0.id, $0) })
        return try modelContext.fetch(FetchDescriptor<StoryEventRecord>(predicate: #Predicate { $0.statusRaw != "resolved" }, sortBy: [SortDescriptor(\.createdAt)])).map { storySummary($0, occurrence: occurrences[$0.sourceOccurrenceID]) }
    }

    func persistedActionSuggestion(eventID: String) throws -> String? {
        let event = try requireEvent(eventID)
        guard let state = resolutionState(event),
              state.stage == .actionSuggestion,
              state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
              let action = state.suggestedAction else { return nil }
        return try? ActionSuggestionModelContract.validatedAction(action)
    }

    func persistedActionInterpretation(eventID: String, customAction: String) throws -> String? {
        let event = try requireEvent(eventID)
        guard let state = resolutionState(event),
              state.stage == .interpretedActionReview,
              state.effort != nil,
              state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
              state.customAction == customAction,
              state.promptVersions.interpretation == CustomActionModelContract.promptVersion,
              let action = state.interpretedAction else { return nil }
        return try? CustomActionModelContract.validatedAction(action)
    }

    func persistedFinalProse(eventID: String) throws -> String? {
        let event = try requireEvent(eventID)
        guard let state = resolutionState(event),
              state.stage == .finalProse,
              state.promptVersions.finalProse == FinalProseModelContract.promptVersion,
              let prose = state.finalProse else { return nil }
        return try? FinalProseModelContract.validatedProse(prose)
    }

    func mostRecentFinalProse() throws -> String {
        try modelContext.fetch(FetchDescriptor<ChronicleRecord>(
            sortBy: [SortDescriptor(\.committedAt, order: .reverse)]
        )).first?.finalProse ?? "none"
    }

    func allStoryEvents() throws -> [PendingStorySummary] {
        let occurrences = Dictionary(uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<GoalOccurrenceRecord>()).map { ($0.id, $0) })
        return try modelContext.fetch(FetchDescriptor<StoryEventRecord>(sortBy: [SortDescriptor(\.createdAt)])).map { storySummary($0, occurrence: occurrences[$0.sourceOccurrenceID]) }
    }

    func attemptedGoalHistory(for eventID: String) throws -> [AttemptedGoalContext] {
        let event = try requireEvent(eventID)
        return AttemptedGoalHistory.closest(
            to: [event.sourceTitle, event.sourceNotes].filter { !$0.isEmpty }.joined(separator: "\n"),
            currentOccurrenceID: event.sourceOccurrenceID,
            among: try occurrenceSummaries().filter { ($0.resolvedAt ?? .distantFuture) <= event.createdAt }
        )
    }

    func worldReadModel() throws -> WorldReadModel {
        let save = try requireSave()
        return WorldReadModel(dungeonName: save.dungeonName, revision: save.revision, snapshot: decodeWorld(save))
    }

    func chronicle() throws -> [ChronicleSummary] {
        try modelContext.fetch(FetchDescriptor<ChronicleRecord>(sortBy: [SortDescriptor(\.committedAt, order: .reverse)])).map { record in
            ChronicleSummary(id: record.id, eventID: record.eventID, sourceTitle: record.sourceTitle, valence: EventValence(rawValue: record.valenceRaw) ?? .positive, title: record.generatedTitle, finalProse: record.finalProse, summary: record.summary, deltas: try PersistentJSON.decode([WorldDelta].self, from: record.deltasJSON), cue: AnimationCue(rawValue: record.animationCueRaw) ?? .idle, priorRevision: record.priorRevision, committedRevision: record.committedRevision, committedAt: record.committedAt, effort: resolutionEffort(value: record.effortValue, sourceRaw: record.effortSourceRaw), comparisonHistoryIDs: record.comparisonHistoryIDs, acceptedAction: record.acceptedAction, recordedWorld: try PersistentJSON.decode(WorldReadModel.self, from: record.recordedWorldData))
        }
    }

    func claimEvent(_ id: String) throws -> (PendingStorySummary, WorldReadModel) {
        do {
            var result: (PendingStorySummary, WorldReadModel)?
            try modelContext.transaction {
                let event = try requireEvent(id)
                guard event.statusRaw != EventStatus.resolved.rawValue else { throw StoreError.eventAlreadyResolved }
                let save = try requireSave()
                event.statusRaw = EventStatus.resolving.rawValue; event.failureCode = nil; event.attemptCount += 1; event.expectedRevision = save.revision; event.updatedAt = .now
                try modelContext.save()
                let sourceOccurrenceID = event.sourceOccurrenceID
                let occurrence = try modelContext.fetch(FetchDescriptor<GoalOccurrenceRecord>(predicate: #Predicate { $0.id == sourceOccurrenceID })).first
                result = (storySummary(event, occurrence: occurrence, status: .resolving), WorldReadModel(dungeonName: save.dungeonName, revision: save.revision, snapshot: decodeWorld(save)))
            }
            return result!
        } catch { modelContext.rollback(); throw error }
    }

    func markEventFailed(_ id: String, code: String) throws {
        let event = try requireEvent(id)
        guard event.statusRaw != EventStatus.resolved.rawValue else { return }
        event.statusRaw = EventStatus.failedRetryable.rawValue; event.failureCode = code; event.updatedAt = .now
        try modelContext.save()
    }

    func returnEventToPending(_ id: String) throws {
        let event = try requireEvent(id)
        guard event.statusRaw != EventStatus.resolved.rawValue else { return }
        event.statusRaw = EventStatus.pending.rawValue; event.failureCode = nil; event.updatedAt = .now
        try modelContext.save()
    }

    func checkpointResolution(eventID: String, state: StagedResolutionState) throws {
        do {
            try modelContext.transaction {
                let event = try requireEvent(eventID)
                guard event.statusRaw != EventStatus.resolved.rawValue else { throw StoreError.eventAlreadyResolved }
                try validateCheckpoint(state)
                let existing = resolutionState(event) ?? StagedResolutionState(stage: .effortSelection)
                if state.stage == .effortSelection {
                    guard existing.effort == nil, state.effort == nil else { throw StoreError.invalidResolutionState }
                } else {
                    try validatePersistedEffort(in: state, matches: existing)
                }
                try persist(state, on: event)
                try modelContext.save()
            }
        } catch { modelContext.rollback(); throw error }
    }

    func checkpointEffort(eventID: String, result: EffortEvaluationResult) throws {
        guard Set(result.comparisonHistoryIDs).count == result.comparisonHistoryIDs.count,
              result.comparisonHistoryIDs.count <= AttemptedGoalHistory.maximumCount else {
            throw StoreError.invalidResolutionState
        }
        switch result.effort.source {
        case .userSelected:
            guard result.comparisonHistoryIDs.isEmpty, result.promptVersion == nil else {
                throw StoreError.invalidResolutionState
            }
        case .modelEstimated:
            guard result.promptVersion == EffortModelContract.promptVersion else {
                throw StoreError.invalidResolutionState
            }
        }
        do {
            try modelContext.transaction {
                let event = try requireEvent(eventID)
                guard event.statusRaw != EventStatus.resolved.rawValue else { throw StoreError.eventAlreadyResolved }
                var state = resolutionState(event) ?? StagedResolutionState(stage: .effortSelection)
                guard state.stage == .effortSelection else { throw StoreError.invalidResolutionState }
                if let existing = state.effort {
                    guard existing == result.effort,
                          state.comparisonHistoryIDs == result.comparisonHistoryIDs,
                          state.promptVersions.effort == result.promptVersion else {
                        throw StoreError.invalidResolutionState
                    }
                    return
                }
                state.effort = result.effort
                state.comparisonHistoryIDs = result.comparisonHistoryIDs
                state.promptVersions.effort = result.promptVersion
                try persist(state, on: event)
                try modelContext.save()
            }
        } catch { modelContext.rollback(); throw error }
    }

    func checkpointSuggestion(eventID: String, result: ActionSuggestionResult) throws {
        guard let action = try? ActionSuggestionModelContract.validatedAction(result.action),
              result.promptVersion == ActionSuggestionModelContract.promptVersion else {
            throw StoreError.invalidResolutionState
        }
        do {
            try modelContext.transaction {
                let event = try requireEvent(eventID)
                guard event.statusRaw != EventStatus.resolved.rawValue else { throw StoreError.eventAlreadyResolved }
                var state = resolutionState(event) ?? StagedResolutionState(stage: .effortSelection)
                guard state.stage == .effortSelection, state.effort != nil, state.suggestedAction == nil else {
                    throw StoreError.invalidResolutionState
                }
                state.stage = .actionSuggestion
                state.suggestedAction = action
                state.promptVersions.suggestion = result.promptVersion
                try persist(state, on: event)
                try modelContext.save()
            }
        } catch { modelContext.rollback(); throw error }
    }

    func acceptSuggestedAction(eventID: String) throws -> String {
        do {
            var acceptedAction: String?
            try modelContext.transaction {
                let event = try requireEvent(eventID)
                guard event.statusRaw != EventStatus.resolved.rawValue,
                      var state = resolutionState(event),
                      state.stage == .actionSuggestion || state.stage == .actionAccepted,
                      let effort = state.effort,
                      (effort.source == .userSelected && state.promptVersions.effort == nil)
                        || (effort.source == .modelEstimated && state.promptVersions.effort == EffortModelContract.promptVersion),
                      state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
                      let suggestion = state.suggestedAction,
                      let action = try? ActionSuggestionModelContract.validatedAction(suggestion),
                      state.customAction == nil,
                      state.interpretedAction == nil,
                      state.promptVersions.interpretation == nil,
                      state.promptVersions.finalProse == nil,
                      state.finalProse == nil,
                      state.finalResult == nil else { throw StoreError.invalidResolutionState }
                if state.stage == .actionAccepted {
                    guard state.acceptedAction == action else { throw StoreError.invalidResolutionState }
                    acceptedAction = action
                    return
                }
                guard state.acceptedAction == nil else { throw StoreError.invalidResolutionState }
                state.stage = .actionAccepted
                state.acceptedAction = action
                try persist(state, on: event)
                try modelContext.save()
                acceptedAction = action
            }
            guard let acceptedAction else { throw StoreError.invalidResolutionState }
            return acceptedAction
        } catch { modelContext.rollback(); throw error }
    }

    func acceptInterpretedAction(eventID: String) throws -> String {
        do {
            var acceptedAction: String?
            try modelContext.transaction {
                let event = try requireEvent(eventID)
                guard event.statusRaw != EventStatus.resolved.rawValue,
                      var state = resolutionState(event),
                      state.stage == .interpretedActionReview || state.stage == .actionAccepted,
                      hasCurrentEffort(state),
                      state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
                      let suggestion = state.suggestedAction,
                      (try? ActionSuggestionModelContract.validatedAction(suggestion)) == suggestion,
                      let customAction = state.customAction,
                      !customAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      state.promptVersions.interpretation == CustomActionModelContract.promptVersion,
                      let interpretation = state.interpretedAction,
                      (try? CustomActionModelContract.validatedAction(interpretation)) == interpretation,
                      state.promptVersions.finalProse == nil,
                      state.finalProse == nil,
                      state.finalResult == nil else { throw StoreError.invalidResolutionState }
                if state.stage == .actionAccepted {
                    guard state.acceptedAction == interpretation else { throw StoreError.invalidResolutionState }
                    acceptedAction = interpretation
                    return
                }
                guard state.acceptedAction == nil else { throw StoreError.invalidResolutionState }
                state.stage = .actionAccepted
                state.acceptedAction = interpretation
                try persist(state, on: event)
                try modelContext.save()
                acceptedAction = interpretation
            }
            guard let acceptedAction else { throw StoreError.invalidResolutionState }
            return acceptedAction
        } catch { modelContext.rollback(); throw error }
    }

    func reviseInterpretedAction(eventID: String) throws -> (customAction: String, suggestedAction: String) {
        do {
            var result: (customAction: String, suggestedAction: String)?
            try modelContext.transaction {
                let event = try requireEvent(eventID)
                guard event.statusRaw != EventStatus.resolved.rawValue,
                      var state = resolutionState(event),
                      state.stage == .interpretedActionReview || state.stage == .customActionEntry,
                      hasCurrentEffort(state),
                      state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
                      let suggestion = state.suggestedAction,
                      (try? ActionSuggestionModelContract.validatedAction(suggestion)) == suggestion,
                      let customAction = state.customAction,
                      !customAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      state.acceptedAction == nil,
                      state.promptVersions.finalProse == nil,
                      state.finalProse == nil,
                      state.finalResult == nil else { throw StoreError.invalidResolutionState }
                if state.stage == .customActionEntry {
                    guard state.interpretedAction == nil,
                          state.promptVersions.interpretation == nil else { throw StoreError.invalidResolutionState }
                    result = (customAction, suggestion)
                    return
                }
                guard state.promptVersions.interpretation == CustomActionModelContract.promptVersion,
                      let interpretation = state.interpretedAction,
                      (try? CustomActionModelContract.validatedAction(interpretation)) == interpretation else {
                    throw StoreError.invalidResolutionState
                }
                state.stage = .customActionEntry
                state.interpretedAction = nil
                state.promptVersions.interpretation = nil
                try persist(state, on: event)
                try modelContext.save()
                result = (customAction, suggestion)
            }
            guard let result else { throw StoreError.invalidResolutionState }
            return result
        } catch { modelContext.rollback(); throw error }
    }

    func checkpointCustomActionEntry(eventID: String, customAction: String) throws {
        guard !customAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StoreError.invalidResolutionState
        }
        do {
            try modelContext.transaction {
                let event = try requireEvent(eventID)
                guard event.statusRaw != EventStatus.resolved.rawValue else { throw StoreError.eventAlreadyResolved }
                var state = resolutionState(event) ?? StagedResolutionState(stage: .effortSelection)
                if state.stage == .customActionEntry {
                    guard hasCurrentEffort(state),
                          state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
                          let suggestion = state.suggestedAction,
                          (try? ActionSuggestionModelContract.validatedAction(suggestion)) == suggestion,
                          state.customAction != nil,
                          state.interpretedAction == nil,
                          state.acceptedAction == nil,
                          state.promptVersions.interpretation == nil,
                          state.promptVersions.finalProse == nil,
                          state.finalProse == nil,
                          state.finalResult == nil else { throw StoreError.invalidResolutionState }
                    state.customAction = customAction
                    try persist(state, on: event)
                    try modelContext.save()
                    return
                }
                guard state.stage == .actionSuggestion,
                      state.effort != nil,
                      state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
                      let suggestion = state.suggestedAction,
                      (try? ActionSuggestionModelContract.validatedAction(suggestion)) != nil,
                      state.customAction == nil,
                      state.interpretedAction == nil else { throw StoreError.invalidResolutionState }
                state.stage = .customActionEntry
                state.customAction = customAction
                try persist(state, on: event)
                try modelContext.save()
            }
        } catch { modelContext.rollback(); throw error }
    }

    func checkpointInterpretation(eventID: String, result: CustomActionInterpretationResult) throws {
        guard let action = try? CustomActionModelContract.validatedAction(result.action),
              result.promptVersion == CustomActionModelContract.promptVersion else {
            throw StoreError.invalidResolutionState
        }
        do {
            try modelContext.transaction {
                let event = try requireEvent(eventID)
                guard event.statusRaw != EventStatus.resolved.rawValue else { throw StoreError.eventAlreadyResolved }
                var state = resolutionState(event) ?? StagedResolutionState(stage: .effortSelection)
                guard state.stage == .customActionEntry,
                      state.effort != nil,
                      state.promptVersions.suggestion == ActionSuggestionModelContract.promptVersion,
                      let suggestion = state.suggestedAction,
                      (try? ActionSuggestionModelContract.validatedAction(suggestion)) != nil,
                      state.customAction != nil,
                      state.interpretedAction == nil else { throw StoreError.invalidResolutionState }
                state.stage = .interpretedActionReview
                state.interpretedAction = action
                state.promptVersions.interpretation = result.promptVersion
                try persist(state, on: event)
                try modelContext.save()
            }
        } catch { modelContext.rollback(); throw error }
    }

    func checkpointFinalProse(eventID: String, result: FinalProseResult) throws {
        guard let prose = try? FinalProseModelContract.validatedProse(result.prose),
              result.promptVersion == FinalProseModelContract.promptVersion else {
            throw StoreError.invalidResolutionState
        }
        do {
            try modelContext.transaction {
                let event = try requireEvent(eventID)
                guard event.statusRaw != EventStatus.resolved.rawValue else { throw StoreError.eventAlreadyResolved }
                var state = resolutionState(event) ?? StagedResolutionState(stage: .effortSelection)
                guard state.stage == .actionAccepted,
                      state.effort != nil,
                      state.acceptedAction?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                      state.promptVersions.finalProse == nil,
                      state.finalProse == nil,
                      state.finalResult == nil else { throw StoreError.invalidResolutionState }
                state.stage = .finalProse
                state.finalProse = prose
                state.promptVersions.finalProse = result.promptVersion
                try persist(state, on: event)
                try modelContext.save()
            }
        } catch { modelContext.rollback(); throw error }
    }

    func stageFinalResolution(
        eventID: String,
        expectedRevision: Int,
        world: WorldSnapshot,
        mutations: [WorldMutation],
        deltas: [WorldDelta],
        generatedTitle: String,
        narration: String,
        summary: String,
        cue: AnimationCue,
        effort: ResolutionEffort? = nil,
        comparisonHistoryIDs: [String] = [],
        suggestedAction: String? = nil,
        customAction: String? = nil,
        interpretedAction: String? = nil,
        acceptedAction: String,
        promptVersions: ResolutionPromptVersions
    ) throws {
        let accepted = acceptedAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard effort != nil,
              !accepted.isEmpty,
              !generatedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !narration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StoreError.invalidResolutionState }
        do {
            try modelContext.transaction {
                let event = try requireEvent(eventID)
                let save = try requireSave()
                guard event.statusRaw != EventStatus.resolved.rawValue else { throw StoreError.eventAlreadyResolved }
                guard save.revision == expectedRevision, event.expectedRevision == expectedRevision else { throw StoreError.staleRevision }
                let existing = resolutionState(event) ?? StagedResolutionState(stage: .effortSelection)
                if let generatedProse = existing.finalProse {
                    guard existing.stage == .finalProse,
                          generatedProse == narration,
                          existing.acceptedAction == acceptedAction,
                          existing.promptVersions.finalProse == FinalProseModelContract.promptVersion,
                          promptVersions.finalProse == FinalProseModelContract.promptVersion else {
                        throw StoreError.invalidResolutionState
                    }
                }
                let valence = EventValence(rawValue: event.valenceRaw) ?? .positive
                try validateStagedWorld(world, mutations: mutations, deltas: deltas, summary: summary, current: decodeWorld(save), valence: valence, effort: effort)
                let result = StagedFinalResolution(expectedRevision: expectedRevision, world: world, mutations: mutations, deltas: deltas, title: generatedTitle, finalProse: narration, summary: summary, cue: cue)
                let state = StagedResolutionState(stage: .finalProse, effort: effort, comparisonHistoryIDs: comparisonHistoryIDs, suggestedAction: suggestedAction, customAction: customAction, interpretedAction: interpretedAction, acceptedAction: accepted, promptVersions: promptVersions, finalProse: narration, finalResult: result)
                try validatePersistedEffort(in: state, matches: existing)
                try persist(state, on: event)
                try modelContext.save()
            }
        } catch { modelContext.rollback(); throw error }
    }

    func commitStagedResolution(eventID: String, failBeforeSave: Bool = false) throws -> ChronicleSummary {
        let event = try requireEvent(eventID)
        guard event.statusRaw != EventStatus.resolved.rawValue else { throw StoreError.eventAlreadyResolved }
        guard let state = resolutionState(event), state.stage == .finalProse,
              state.effort != nil,
              state.acceptedAction?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              let result = state.finalResult,
              state.finalProse == result.finalProse else { throw StoreError.invalidResolutionState }
        return try commitResolution(
            eventID: eventID,
            expectedRevision: result.expectedRevision,
            world: result.world,
            mutations: result.mutations,
            deltas: result.deltas,
            generatedTitle: result.title,
            narration: result.finalProse,
            summary: result.summary,
            cue: result.cue,
            effort: state.effort,
            comparisonHistoryIDs: state.comparisonHistoryIDs,
            acceptedAction: state.acceptedAction,
            stagedState: state,
            failBeforeSave: failBeforeSave
        )
    }

    func commitResolution(eventID: String, expectedRevision: Int, world: WorldSnapshot, mutations: [WorldMutation], deltas: [WorldDelta], generatedTitle: String, narration: String, summary: String, cue: AnimationCue, effort: ResolutionEffort? = nil, comparisonHistoryIDs: [String] = [], acceptedAction: String? = nil, stagedState: StagedResolutionState? = nil, failBeforeSave: Bool = false) throws -> ChronicleSummary {
        do {
            var committed: ChronicleSummary?
            try modelContext.transaction {
                let event = try requireEvent(eventID)
                let save = try requireSave()
                guard event.statusRaw != EventStatus.resolved.rawValue else { throw StoreError.eventAlreadyResolved }
                guard save.revision == expectedRevision, event.expectedRevision == expectedRevision else { throw StoreError.staleRevision }
                if let checkpoint = resolutionState(event), let checkpointEffort = checkpoint.effort {
                    guard effort == checkpointEffort,
                          comparisonHistoryIDs == checkpoint.comparisonHistoryIDs else {
                        throw StoreError.invalidResolutionState
                    }
                }
                let valence = EventValence(rawValue: event.valenceRaw) ?? .positive
                if stagedState != nil {
                    try validateStagedWorld(world, mutations: mutations, deltas: deltas, summary: summary, current: decodeWorld(save), valence: valence, effort: stagedState?.effort)
                }
                let prior = save.revision
                save.worldData = try PersistentJSON.encode(world)
                save.morale = world.morale; save.integrity = world.integrity; save.food = world.food; save.rollingSummary = world.rollingSummary
                save.revision += 1
                let patch = try PersistentJSON.encode(mutations)
                let deltaData = try PersistentJSON.encode(deltas)
                let recordedWorld = WorldReadModel(dungeonName: save.dungeonName, revision: save.revision, snapshot: world)
                let recordedWorldData = try PersistentJSON.encode(recordedWorld)
                let record = ChronicleRecord(eventID: event.id, sourceTitle: event.sourceTitle, valence: valence, generatedTitle: generatedTitle, finalProse: narration, summary: summary, patchJSON: patch, priorRevision: prior, committedRevision: save.revision, recordedWorldData: recordedWorldData, deltasJSON: deltaData, animationCue: cue, effort: effort, comparisonHistoryIDs: comparisonHistoryIDs, acceptedAction: acceptedAction)
                modelContext.insert(record)
                event.statusRaw = EventStatus.resolved.rawValue; event.committedRevision = save.revision; event.failureCode = nil; event.updatedAt = .now
                event.effortValue = effort?.value; event.effortSourceRaw = effort?.source.rawValue; event.comparisonHistoryIDs = comparisonHistoryIDs; event.acceptedAction = acceptedAction
                event.finalProse = narration; event.recordedWorldData = recordedWorldData
                var finalState = stagedState ?? resolutionState(event) ?? StagedResolutionState(stage: .finalProse)
                finalState.stage = .committed
                finalState.effort = effort; finalState.comparisonHistoryIDs = comparisonHistoryIDs; finalState.acceptedAction = acceptedAction
                finalState.finalProse = narration
                finalState.finalResult = StagedFinalResolution(expectedRevision: expectedRevision, world: world, mutations: mutations, deltas: deltas, title: generatedTitle, finalProse: narration, summary: summary, cue: cue)
                event.resolutionStateData = try PersistentJSON.encode(finalState)
                if failBeforeSave { throw StoreError.injectedFailure }
                try modelContext.save()
                committed = ChronicleSummary(id: record.id, eventID: event.id, sourceTitle: event.sourceTitle, valence: valence, title: generatedTitle, finalProse: narration, summary: summary, deltas: deltas, cue: cue, priorRevision: prior, committedRevision: save.revision, committedAt: record.committedAt, effort: effort, comparisonHistoryIDs: comparisonHistoryIDs, acceptedAction: acceptedAction, recordedWorld: recordedWorld)
            }
            return committed!
        } catch { modelContext.rollback(); throw error }
    }

    func exportLocalData() throws -> Data {
        let definitions = try modelContext.fetch(FetchDescriptor<GoalDefinitionRecord>()).compactMap { try definitionSummary(id: $0.id) }
        let bundle = LocalDataExport(exportVersion: 1, dataSchemaVersion: HordeSchemaV4.dataVersion, promptVersion: HordeModelContract.promptVersion, exportedAt: .now, goals: definitions, occurrences: try occurrenceSummaries(), storyEvents: try allStoryEvents(), world: try worldReadModel(), chronicle: try chronicle())
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(bundle)
    }

    func resetDungeon() throws {
        do {
            try modelContext.transaction {
                let events = try modelContext.fetch(FetchDescriptor<StoryEventRecord>())
                let entries = try modelContext.fetch(FetchDescriptor<ChronicleRecord>())
                events.forEach(modelContext.delete); entries.forEach(modelContext.delete)
                if let save = try modelContext.fetch(FetchDescriptor<GameSaveRecord>()).first {
                    let dragonColor = decodeWorld(save).dragonVisual.color
                    let world = WorldSnapshot.initial(dragonName: save.dragonName, dungeonName: save.dungeonName, dragonColor: dragonColor)
                    save.worldData = try PersistentJSON.encode(world); save.morale = world.morale; save.integrity = world.integrity; save.food = world.food; save.rollingSummary = world.rollingSummary; save.revision += 1
                }
                try modelContext.save()
            }
        } catch { modelContext.rollback(); throw error }
    }

    func deleteAllLocalData() throws {
        do {
            try modelContext.transaction {
                try modelContext.fetch(FetchDescriptor<ChronicleRecord>()).forEach(modelContext.delete)
                try modelContext.fetch(FetchDescriptor<StoryEventRecord>()).forEach(modelContext.delete)
                try modelContext.fetch(FetchDescriptor<GoalOccurrenceRecord>()).forEach(modelContext.delete)
                try modelContext.fetch(FetchDescriptor<GoalDefinitionRecord>()).forEach(modelContext.delete)
                try modelContext.fetch(FetchDescriptor<GameSaveRecord>()).forEach(modelContext.delete)
                try modelContext.fetch(FetchDescriptor<AppStateRecord>()).forEach(modelContext.delete)
                modelContext.insert(AppStateRecord())
                try modelContext.save()
            }
        } catch { modelContext.rollback(); throw error }
    }

    private func transitionOccurrence(id: String, state: GoalOccurrenceState, valence: EventValence, now: Date, calendar: Calendar) throws -> String? {
        var successorID: String?
        do {
            try modelContext.transaction {
                guard let occurrence = try modelContext.fetch(FetchDescriptor<GoalOccurrenceRecord>(predicate: #Predicate { $0.id == id })).first else { throw GoalStoreError.missingOccurrence }
                if occurrence.stateRaw != GoalOccurrenceState.pending.rawValue { return }
                let save = try requireSave()
                occurrence.stateRaw = state.rawValue; occurrence.resolvedAt = now
                if state == .completed {
                    var world = decodeWorld(save)
                    if world.recordRegularUse(on: now, calendar: calendar) {
                        save.worldData = try PersistentJSON.encode(world)
                        save.revision += 1
                    }
                }
                let eventID = "\(occurrence.id):\(valence.rawValue)"
                if try modelContext.fetch(FetchDescriptor<StoryEventRecord>(predicate: #Predicate { $0.id == eventID })).isEmpty {
                    let source = occurrence.snapshot
                    modelContext.insert(StoryEventRecord(id: eventID, sourceOccurrenceID: occurrence.id, sourceTitle: source.title, sourceNotes: source.notes, sourceCategoryRaw: source.category?.rawValue, sourceEffortRaw: source.effort?.rawValue, valence: valence, expectedRevision: save.revision, createdAt: now))
                }
                if let definition = try definition(occurrence.definitionID), !definition.archived,
                   let next = ScheduleCalculator.nextDue(after: occurrence.dueDate, draft: definition.draft, now: now, calendar: calendar) {
                    successorID = try materializeOccurrence(for: definition, due: next, now: now, timeZoneID: calendar.timeZone.identifier)
                }
                try modelContext.save()
            }
            return successorID
        } catch { modelContext.rollback(); throw error }
    }

    @discardableResult private func materializeOccurrence(for definition: GoalDefinitionRecord, due: Date?, now: Date, timeZoneID: String? = nil) throws -> String {
        let key = due.map { String(Int($0.timeIntervalSince1970)) } ?? "unscheduled-v\(definition.version)"
        let id = "\(definition.id):\(key)"
        guard try modelContext.fetch(FetchDescriptor<GoalOccurrenceRecord>(predicate: #Predicate { $0.id == id })).isEmpty else { return id }
        modelContext.insert(try GoalOccurrenceRecord(id: id, definitionID: definition.id, snapshot: definition.snapshot, dueDate: due, includesTime: definition.includesTime, timeZoneID: timeZoneID ?? definition.timeZoneID, now: now))
        return id
    }

    private func definition(_ id: String) throws -> GoalDefinitionRecord? {
        try modelContext.fetch(FetchDescriptor<GoalDefinitionRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private func decodeWorld(_ save: GameSaveRecord) -> WorldSnapshot {
        (try? PersistentJSON.decode(WorldSnapshot.self, from: save.worldData)) ?? .initial(dragonName: save.dragonName, dungeonName: save.dungeonName)
    }

    private func storySummary(_ event: StoryEventRecord, occurrence: GoalOccurrenceRecord?, status: EventStatus? = nil) -> PendingStorySummary {
        PendingStorySummary(
            id: event.id,
            sourceTitle: event.sourceTitle,
            sourceNotes: event.sourceNotes,
            sourceCategory: event.sourceCategoryRaw.flatMap(GoalCategory.init(rawValue:)),
            sourceEffort: event.sourceEffortRaw.flatMap(GoalEffort.init(rawValue:)),
            sourceDueDate: occurrence?.dueDate,
            sourceIncludesTime: occurrence?.includesTime ?? false,
            sourceTimeZoneID: occurrence?.timeZoneID,
            sourceOutcome: occurrence.flatMap { GoalOccurrenceState(rawValue: $0.stateRaw) },
            valence: EventValence(rawValue: event.valenceRaw) ?? .positive,
            status: status ?? EventStatus(rawValue: event.statusRaw) ?? .pending,
            failureCode: event.failureCode,
            createdAt: event.createdAt,
            effort: resolutionEffort(value: event.effortValue, sourceRaw: event.effortSourceRaw),
            comparisonHistoryIDs: event.comparisonHistoryIDs,
            acceptedAction: event.acceptedAction,
            finalProse: event.finalProse,
            recordedWorld: event.recordedWorldData.flatMap { try? PersistentJSON.decode(WorldReadModel.self, from: $0) },
            resolutionState: resolutionState(event)
        )
    }

    private func resolutionState(_ event: StoryEventRecord) -> StagedResolutionState? {
        event.resolutionStateData.flatMap { try? PersistentJSON.decode(StagedResolutionState.self, from: $0) }
    }

    private func persist(_ state: StagedResolutionState, on event: StoryEventRecord) throws {
        event.resolutionStateData = try PersistentJSON.encode(state)
        event.effortValue = state.effort?.value
        event.effortSourceRaw = state.effort?.source.rawValue
        event.comparisonHistoryIDs = state.comparisonHistoryIDs
        event.acceptedAction = state.acceptedAction
        event.updatedAt = .now
    }

    private func validateCheckpoint(_ state: StagedResolutionState) throws {
        guard state.finalProse == nil, state.finalResult == nil else { throw StoreError.invalidResolutionState }
        let suggested = state.suggestedAction?.trimmingCharacters(in: .whitespacesAndNewlines)
        let interpreted = state.interpretedAction?.trimmingCharacters(in: .whitespacesAndNewlines)
        let accepted = state.acceptedAction?.trimmingCharacters(in: .whitespacesAndNewlines)
        if state.stage != .effortSelection, state.effort == nil {
            throw StoreError.invalidResolutionState
        }
        switch state.stage {
        case .effortSelection:
            guard suggested == nil, state.customAction == nil, interpreted == nil, accepted == nil else { throw StoreError.invalidResolutionState }
        case .actionSuggestion:
            guard suggested?.isEmpty == false, state.customAction == nil, interpreted == nil, accepted == nil else { throw StoreError.invalidResolutionState }
        case .customActionEntry:
            guard interpreted == nil, accepted == nil else { throw StoreError.invalidResolutionState }
        case .interpretedActionReview:
            guard interpreted?.isEmpty == false, accepted == nil else { throw StoreError.invalidResolutionState }
        case .actionAccepted:
            guard accepted?.isEmpty == false else { throw StoreError.invalidResolutionState }
        case .finalProse, .committed:
            throw StoreError.invalidResolutionState
        }
    }

    private func validatePersistedEffort(in state: StagedResolutionState, matches existing: StagedResolutionState) throws {
        guard let effort = existing.effort,
              state.effort == effort,
              state.comparisonHistoryIDs == existing.comparisonHistoryIDs,
              state.promptVersions.effort == existing.promptVersions.effort else {
            throw StoreError.invalidResolutionState
        }
    }

    private func hasCurrentEffort(_ state: StagedResolutionState) -> Bool {
        guard let effort = state.effort,
              Set(state.comparisonHistoryIDs).count == state.comparisonHistoryIDs.count,
              state.comparisonHistoryIDs.count <= AttemptedGoalHistory.maximumCount else { return false }
        switch effort.source {
        case .userSelected:
            return state.promptVersions.effort == nil && state.comparisonHistoryIDs.isEmpty
        case .modelEstimated:
            return state.promptVersions.effort == EffortModelContract.promptVersion
        }
    }

    private func validateStagedWorld(_ world: WorldSnapshot, mutations: [WorldMutation], deltas: [WorldDelta], summary: String, current: WorldSnapshot, valence: EventValence, effort: ResolutionEffort?) throws {
        guard !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StoreError.invalidResolutionState }
        var (authorized, validatedDeltas) = try WorldPatchValidator.applying(mutations, to: current, valence: valence, descriptors: WorldContract.descriptors(for: valence, effort: effort, world: current))
        authorized.rollingSummary = String((authorized.rollingSummary + " " + summary).suffix(600))
        guard authorized == world, validatedDeltas == deltas else { throw StoreError.invalidResolutionState }
    }

    private func resolutionEffort(value: Int?, sourceRaw: String?) -> ResolutionEffort? {
        guard let value, let rating = EffortRating(rawValue: value), let sourceRaw, let source = EffortSource(rawValue: sourceRaw) else { return nil }
        return ResolutionEffort(rating: rating, source: source)
    }

    private func requireSave() throws -> GameSaveRecord {
        guard let save = try modelContext.fetch(FetchDescriptor<GameSaveRecord>()).first else { throw StoreError.missingSave }
        return save
    }

    private func requireEvent(_ id: String) throws -> StoryEventRecord {
        guard let event = try modelContext.fetch(FetchDescriptor<StoryEventRecord>(predicate: #Predicate { $0.id == id })).first else { throw StoreError.missingEvent }
        return event
    }

    private func apply(_ mutation: StagedMutation, to save: GameSaveRecord) {
        guard mutation.operation == .increment else { return }
        switch mutation.fieldID {
        case "world.morale": save.morale += mutation.value
        case "world.integrity": save.integrity += mutation.value
        case "world.food": save.food += mutation.value
        default: break
        }
    }
}

enum GoalStoreError: Error { case missingDefinition, missingOccurrence }

enum HordeSchemaV4: VersionedSchema {
    static let dataVersion = 4
    static let versionIdentifier = Schema.Version(4, 0, 0)
    static let models: [any PersistentModel.Type] = [AppStateRecord.self, GameSaveRecord.self, GoalDefinitionRecord.self, GoalOccurrenceRecord.self, StoryEventRecord.self, ChronicleRecord.self]
}
