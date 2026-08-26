import Foundation
import SwiftData

enum StoreError: Error, Equatable { case missingSave, missingEvent, staleRevision, eventAlreadyResolved, injectedFailure }

@ModelActor actor HordeStore {
    static let schema = Schema(HordeSchemaV3.models, version: HordeSchemaV3.versionIdentifier)

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, migrationPlan: HordeMigrationPlan.self, configurations: [configuration])
    }

    static func makeContainer(url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration("TheHorde", schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: HordeMigrationPlan.self, configurations: [configuration])
    }

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

    func completeOnboarding(dragonName: String, dungeonName: String) throws {
        let dragon = dragonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ember" : String(dragonName.prefix(40))
        let dungeon = dungeonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "The Cinder Vault" : String(dungeonName.prefix(60))
        do {
            try modelContext.transaction {
                let existingState = try modelContext.fetch(FetchDescriptor<AppStateRecord>()).first
                let state = existingState ?? AppStateRecord()
                if existingState == nil { modelContext.insert(state) }
                if try modelContext.fetch(FetchDescriptor<GameSaveRecord>()).isEmpty {
                    modelContext.insert(GameSaveRecord(dungeonName: dungeon, dragonName: dragon))
                } else if let save = try modelContext.fetch(FetchDescriptor<GameSaveRecord>()).first, !state.onboardingComplete {
                    let world = WorldSnapshot.initial(dragonName: dragon, dungeonName: dungeon)
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

    func allStoryEvents() throws -> [PendingStorySummary] {
        let occurrences = Dictionary(uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<GoalOccurrenceRecord>()).map { ($0.id, $0) })
        return try modelContext.fetch(FetchDescriptor<StoryEventRecord>(sortBy: [SortDescriptor(\.createdAt)])).map { storySummary($0, occurrence: occurrences[$0.sourceOccurrenceID]) }
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

    func commitResolution(eventID: String, expectedRevision: Int, world: WorldSnapshot, mutations: [WorldMutation], deltas: [WorldDelta], generatedTitle: String, narration: String, summary: String, cue: AnimationCue, effort: ResolutionEffort? = nil, comparisonHistoryIDs: [String] = [], acceptedAction: String? = nil) throws -> ChronicleSummary {
        do {
            var committed: ChronicleSummary?
            try modelContext.transaction {
                let event = try requireEvent(eventID)
                let save = try requireSave()
                guard event.statusRaw != EventStatus.resolved.rawValue else { throw StoreError.eventAlreadyResolved }
                guard save.revision == expectedRevision, event.expectedRevision == expectedRevision else { throw StoreError.staleRevision }
                let prior = save.revision
                save.worldData = try PersistentJSON.encode(world)
                save.morale = world.morale; save.integrity = world.integrity; save.food = world.food; save.rollingSummary = world.rollingSummary
                save.revision += 1
                let patch = try PersistentJSON.encode(mutations)
                let deltaData = try PersistentJSON.encode(deltas)
                let valence = EventValence(rawValue: event.valenceRaw) ?? .positive
                let recordedWorld = WorldReadModel(dungeonName: save.dungeonName, revision: save.revision, snapshot: world)
                let recordedWorldData = try PersistentJSON.encode(recordedWorld)
                let record = ChronicleRecord(eventID: event.id, sourceTitle: event.sourceTitle, valence: valence, generatedTitle: generatedTitle, finalProse: narration, summary: summary, patchJSON: patch, priorRevision: prior, committedRevision: save.revision, recordedWorldData: recordedWorldData, deltasJSON: deltaData, animationCue: cue, effort: effort, comparisonHistoryIDs: comparisonHistoryIDs, acceptedAction: acceptedAction)
                modelContext.insert(record)
                event.statusRaw = EventStatus.resolved.rawValue; event.committedRevision = save.revision; event.failureCode = nil; event.updatedAt = .now
                event.effortValue = effort?.value; event.effortSourceRaw = effort?.source.rawValue; event.comparisonHistoryIDs = comparisonHistoryIDs; event.acceptedAction = acceptedAction
                event.finalProse = narration; event.recordedWorldData = recordedWorldData
                try modelContext.save()
                committed = ChronicleSummary(id: record.id, eventID: event.id, sourceTitle: event.sourceTitle, valence: valence, title: generatedTitle, finalProse: narration, summary: summary, deltas: deltas, cue: cue, priorRevision: prior, committedRevision: save.revision, committedAt: record.committedAt, effort: effort, comparisonHistoryIDs: comparisonHistoryIDs, acceptedAction: acceptedAction, recordedWorld: recordedWorld)
            }
            return committed!
        } catch { modelContext.rollback(); throw error }
    }

    func exportLocalData() throws -> Data {
        let definitions = try modelContext.fetch(FetchDescriptor<GoalDefinitionRecord>()).compactMap { try definitionSummary(id: $0.id) }
        let bundle = LocalDataExport(exportVersion: 1, dataSchemaVersion: 3, promptVersion: HordeModelContract.promptVersion, exportedAt: .now, goals: definitions, occurrences: try occurrenceSummaries(), storyEvents: try allStoryEvents(), world: try worldReadModel(), chronicle: try chronicle())
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
                    let world = WorldSnapshot.initial(dragonName: save.dragonName, dungeonName: save.dungeonName)
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
            valence: EventValence(rawValue: event.valenceRaw) ?? .positive,
            status: status ?? EventStatus(rawValue: event.statusRaw) ?? .pending,
            failureCode: event.failureCode,
            createdAt: event.createdAt,
            effort: resolutionEffort(value: event.effortValue, sourceRaw: event.effortSourceRaw),
            comparisonHistoryIDs: event.comparisonHistoryIDs,
            acceptedAction: event.acceptedAction,
            finalProse: event.finalProse,
            recordedWorld: event.recordedWorldData.flatMap { try? PersistentJSON.decode(WorldReadModel.self, from: $0) }
        )
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

enum HordeSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static let models: [any PersistentModel.Type] = [AppStateRecord.self, GameSaveRecord.self, GoalDefinitionRecord.self, GoalOccurrenceRecord.self, StoryEventRecord.self, ChronicleRecord.self]
}

enum HordeMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [HordeSchemaV3.self]
    static let stages: [MigrationStage] = []
}
