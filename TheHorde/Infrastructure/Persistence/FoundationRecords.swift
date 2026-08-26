import Foundation
import SwiftData

enum PersistentJSON {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

@Model final class AppStateRecord {
    @Attribute(.unique) var id: String
    var onboardingComplete: Bool
    init(id: String = "app", onboardingComplete: Bool = false) {
        self.id = id
        self.onboardingComplete = onboardingComplete
    }
}

@Model final class GameSaveRecord {
    @Attribute(.unique) var id: String
    var schemaVersion: Int
    var revision: Int
    var dungeonName: String
    var dragonName: String
    var morale: Int
    var integrity: Int
    var food: Int
    var rollingSummary: String
    var worldData: Data

    init(id: String = "primary", schemaVersion: Int = 3, revision: Int = 0, dungeonName: String = "The Cinder Vault", dragonName: String = "Ember", dragonColor: RGBColor = .ember, morale: Int = 5, integrity: Int = 1, food: Int = 0, rollingSummary: String? = nil) {
        let world = WorldSnapshot.initial(dragonName: dragonName, dungeonName: dungeonName, dragonColor: dragonColor)
        self.id = id; self.schemaVersion = schemaVersion; self.revision = revision
        self.dungeonName = dungeonName; self.dragonName = dragonName
        self.morale = morale; self.integrity = integrity; self.food = food; self.rollingSummary = rollingSummary ?? world.rollingSummary
        self.worldData = (try? PersistentJSON.encode(world)) ?? Data()
    }
}

@Model final class StoryEventRecord {
    @Attribute(.unique) var id: String
    var sourceOccurrenceID: String
    var sourceTitle: String
    var sourceNotes: String
    var sourceCategoryRaw: String?
    var sourceEffortRaw: String?
    var valenceRaw: String
    var statusRaw: String
    var expectedRevision: Int
    var committedRevision: Int?
    var attemptCount: Int
    var failureCode: String?
    var createdAt: Date
    var updatedAt: Date
    var effortValue: Int?
    var effortSourceRaw: String?
    var comparisonHistoryIDs: [String] = []
    var acceptedAction: String?
    var finalProse: String?
    var recordedWorldData: Data?

    init(id: String, sourceOccurrenceID: String, sourceTitle: String, sourceNotes: String = "", sourceCategoryRaw: String? = nil, sourceEffortRaw: String? = nil, valence: EventValence, status: EventStatus = .pending, expectedRevision: Int, createdAt: Date = .now) {
        self.id = id; self.sourceOccurrenceID = sourceOccurrenceID; self.sourceTitle = sourceTitle
        self.sourceNotes = sourceNotes; self.sourceCategoryRaw = sourceCategoryRaw; self.sourceEffortRaw = sourceEffortRaw
        self.valenceRaw = valence.rawValue; self.statusRaw = status.rawValue; self.expectedRevision = expectedRevision
        self.attemptCount = 0; self.createdAt = createdAt; self.updatedAt = createdAt
    }
}

@Model final class GoalDefinitionRecord {
    @Attribute(.unique) var id: String
    var title: String
    var notes: String
    var categoryRaw: String?
    var effortRaw: String?
    var recurrenceRaw: String
    var weekdays: [Int]
    var dueDate: Date?
    var includesTime: Bool
    var timeZoneID: String
    var createdAt: Date
    var updatedAt: Date
    var archived: Bool
    var version: Int

    init(id: String = UUID().uuidString, draft: GoalDraft, now: Date = .now, timeZone: TimeZone = .current) {
        self.id = id; self.title = draft.title; self.notes = draft.notes
        self.categoryRaw = draft.category?.rawValue; self.effortRaw = draft.effort?.rawValue
        switch draft.recurrence {
        case .never: self.recurrenceRaw = "never"; self.weekdays = []
        case .daily: self.recurrenceRaw = "daily"; self.weekdays = []
        case .weekdays(let days): self.recurrenceRaw = "weekdays"; self.weekdays = days.sorted()
        }
        self.dueDate = draft.dueDate; self.includesTime = draft.includesTime; self.timeZoneID = timeZone.identifier
        self.createdAt = now; self.updatedAt = now; self.archived = false; self.version = 1
    }

    var recurrence: RecurrenceRule {
        switch recurrenceRaw { case "daily": .daily; case "weekdays": .weekdays(Set(weekdays)); default: .never }
    }

    var draft: GoalDraft {
        GoalDraft(title: title, notes: notes, dueDate: dueDate, includesTime: includesTime, recurrence: recurrence, category: categoryRaw.flatMap(GoalCategory.init(rawValue:)), effort: effortRaw.flatMap(GoalEffort.init(rawValue:)))
    }

    var snapshot: GoalSnapshot {
        GoalSnapshot(title: title, notes: notes, category: categoryRaw.flatMap(GoalCategory.init(rawValue:)), effort: effortRaw.flatMap(GoalEffort.init(rawValue:)), recurrence: recurrence, definitionVersion: version)
    }

    func update(from draft: GoalDraft, now: Date, timeZone: TimeZone = .current) {
        title = draft.title; notes = draft.notes; categoryRaw = draft.category?.rawValue; effortRaw = draft.effort?.rawValue
        switch draft.recurrence {
        case .never: recurrenceRaw = "never"; weekdays = []
        case .daily: recurrenceRaw = "daily"; weekdays = []
        case .weekdays(let days): recurrenceRaw = "weekdays"; weekdays = days.sorted()
        }
        dueDate = draft.dueDate; includesTime = draft.includesTime; timeZoneID = timeZone.identifier
        updatedAt = now; version += 1
    }
}

@Model final class GoalOccurrenceRecord {
    @Attribute(.unique) var id: String
    var definitionID: String
    var snapshotData: Data
    var dueDate: Date?
    var includesTime: Bool
    var timeZoneID: String
    var stateRaw: String
    var resolvedAt: Date?
    var notificationID: String?
    var createdAt: Date

    init(id: String, definitionID: String, snapshot: GoalSnapshot, dueDate: Date?, includesTime: Bool, timeZoneID: String, now: Date = .now) throws {
        self.id = id; self.definitionID = definitionID; self.snapshotData = try PersistentJSON.encode(snapshot)
        self.dueDate = dueDate; self.includesTime = includesTime; self.timeZoneID = timeZoneID
        self.stateRaw = GoalOccurrenceState.pending.rawValue; self.createdAt = now
    }

    var snapshot: GoalSnapshot { (try? PersistentJSON.decode(GoalSnapshot.self, from: snapshotData)) ?? GoalSnapshot(title: "Unavailable goal", notes: "", category: nil, effort: nil, recurrence: .never, definitionVersion: 0) }
}

@Model final class ChronicleRecord {
    @Attribute(.unique) var id: String
    var eventID: String
    var sourceTitle: String
    var valenceRaw: String
    var generatedTitle: String
    var finalProse: String
    var summary: String
    var patchJSON: Data
    var priorRevision: Int
    var committedRevision: Int
    var committedAt: Date
    var deltasJSON: Data
    var animationCueRaw: String
    var promptVersion: Int
    var effortValue: Int?
    var effortSourceRaw: String?
    var comparisonHistoryIDs: [String]
    var acceptedAction: String?
    var recordedWorldData: Data

    init(eventID: String, sourceTitle: String, valence: EventValence, generatedTitle: String, finalProse: String, summary: String, patchJSON: Data, priorRevision: Int, committedRevision: Int, recordedWorldData: Data, committedAt: Date = .now, deltasJSON: Data = Data(), animationCue: AnimationCue = .idle, promptVersion: Int = HordeModelContract.promptVersion, effort: ResolutionEffort? = nil, comparisonHistoryIDs: [String] = [], acceptedAction: String? = nil) {
        self.id = eventID; self.eventID = eventID; self.sourceTitle = sourceTitle; self.valenceRaw = valence.rawValue
        self.generatedTitle = generatedTitle; self.finalProse = finalProse; self.summary = summary; self.patchJSON = patchJSON
        self.priorRevision = priorRevision; self.committedRevision = committedRevision; self.committedAt = committedAt
        self.deltasJSON = deltasJSON; self.animationCueRaw = animationCue.rawValue; self.promptVersion = promptVersion
        self.effortValue = effort?.value; self.effortSourceRaw = effort?.source.rawValue; self.comparisonHistoryIDs = comparisonHistoryIDs
        self.acceptedAction = acceptedAction; self.recordedWorldData = recordedWorldData
    }
}
