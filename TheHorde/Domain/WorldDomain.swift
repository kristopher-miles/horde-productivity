import Foundation

enum DragonStage: String, Codable, Equatable, Sendable, CaseIterable {
    case baby, adolescent, adult, elder, greatWyrm

    var regularUseDayThreshold: Int {
        switch self {
        case .baby: 0
        case .adolescent: 7
        case .adult: 14
        case .elder: 30
        case .greatWyrm: 60
        }
    }
}

enum DungeonBackgroundStage: Int, Codable, Equatable, Sendable, CaseIterable {
    case one = 1, two, three, four, five

    init(hoard: Int) {
        self = switch hoard {
        case 100...: .five
        case 60...: .four
        case 30...: .three
        case 10...: .two
        default: .one
        }
    }
}

enum KoboldAgeStage: String, Codable, Equatable, Sendable, CaseIterable {
    case baby, kid, adult
}

struct RGBColor: Codable, Equatable, Hashable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    static let ember = RGBColor(red: 224, green: 96, blue: 32)
}

enum CuratedDragonColor: String, CaseIterable, Identifiable, Sendable {
    case ember, ruby, moss, azure, amethyst, pearl

    var id: Self { self }

    var name: String { rawValue.capitalized }

    var color: RGBColor {
        switch self {
        case .ember: .ember
        case .ruby: RGBColor(red: 190, green: 57, blue: 65)
        case .moss: RGBColor(red: 66, green: 137, blue: 75)
        case .azure: RGBColor(red: 49, green: 111, blue: 190)
        case .amethyst: RGBColor(red: 125, green: 75, blue: 167)
        case .pearl: RGBColor(red: 199, green: 183, blue: 143)
        }
    }
}

struct CharacterPalette: Codable, Equatable, Sendable {
    let primary: RGBColor
    let secondary: RGBColor
}

struct DragonVisualState: Codable, Equatable, Sendable {
    var stage: DragonStage
    var color: RGBColor
}

struct DragonGrowthState: Codable, Equatable, Sendable {
    var consecutiveRegularUseDays: Int
    var lastRegularUseDay: Date?
}

struct KoboldVisualState: Codable, Equatable, Sendable {
    var age: KoboldAgeStage
    var colors: CharacterPalette
}

struct CharacterState: Codable, Equatable, Sendable, Identifiable {
    let id: String
    var name: String
    var role: String
    var identity: String
    var vitality: Int
    var bond: Int
    var conditions: [String]
    var koboldVisual: KoboldVisualState? = nil
}

struct LocationState: Codable, Equatable, Sendable, Identifiable {
    let id: String
    var name: String
    var status: String
    var summary: String
}

struct AbilityState: Codable, Equatable, Sendable, Identifiable {
    let id: String
    var name: String
    var summary: String
    var rank: Int
}

struct ActiveThreadState: Codable, Equatable, Sendable, Identifiable {
    let id: String
    var title: String
    var severity: Int
    var state: String
    var involvedEntityIDs: [String]
    var summary: String
}

struct WorldFact: Codable, Equatable, Sendable, Identifiable {
    let id: String
    var title: String
    var summary: String
}

struct WorldSnapshot: Codable, Equatable, Sendable {
    var dragon: CharacterState
    var dragonVisual: DragonVisualState
    var dragonGrowth: DragonGrowthState
    var residents: [CharacterState]
    var hoard: Int
    var backgroundStage: DungeonBackgroundStage { DungeonBackgroundStage(hoard: hoard) }
    var morale: Int
    var integrity: Int
    var food: Int
    var locations: [LocationState]
    var abilities: [AbilityState]
    var activeThreads: [ActiveThreadState]
    var facts: [WorldFact]
    var rollingSummary: String

    static func originNarrative(dragonName: String) -> String {
        "\(dragonName) has recently left the nest and searched for their own lair. After flying far from home, they arrived at an empty cavern extending deep into the rock. They are small now, but they will grow. They settle onto the cold stone, and plan for what's next."
    }

    static func initial(dragonName: String = "Ember", dungeonName: String = "The Cinder Vault", dragonColor: RGBColor = .ember) -> WorldSnapshot {
        WorldSnapshot(
            dragon: CharacterState(id: "dragon", name: dragonName, role: "Baby dragon", identity: "A young, small, newly independent dragon who has just claimed an empty cavern. Not yet powerful or established, they face the untamed lair alone.", vitality: 50, bond: 50, conditions: []),
            dragonVisual: DragonVisualState(stage: .baby, color: dragonColor),
            dragonGrowth: DragonGrowthState(consecutiveRegularUseDays: 0, lastRegularUseDay: nil),
            residents: [],
            hoard: 0,
            morale: 5, integrity: 1, food: 0,
            locations: [LocationState(id: "empty-cavern", name: "Empty Cavern", status: "Untamed", summary: "A dirty, cold, empty, and unruly cavern where unstable stone and dark passages make every step dangerous.")],
            abilities: [],
            activeThreads: [],
            facts: [],
            rollingSummary: originNarrative(dragonName: dragonName)
        )
    }

    @discardableResult mutating func recordRegularUse(on date: Date, calendar: Calendar) -> Bool {
        let day = Self.canonicalLocalDay(for: date, timeZone: calendar.timeZone)
        guard dragonGrowth.lastRegularUseDay != day else { return false }

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let followsPreviousDay = dragonGrowth.lastRegularUseDay.flatMap {
            utc.dateComponents([.day], from: $0, to: day).day
        } == 1
        dragonGrowth.consecutiveRegularUseDays = followsPreviousDay
            ? dragonGrowth.consecutiveRegularUseDays + 1
            : 1
        dragonGrowth.lastRegularUseDay = day

        if let earned = DragonStage.allCases.last(where: {
            dragonGrowth.consecutiveRegularUseDays >= $0.regularUseDayThreshold
        }), earned.regularUseDayThreshold > dragonVisual.stage.regularUseDayThreshold {
            dragonVisual.stage = earned
        }
        return true
    }

    private static func canonicalLocalDay(for date: Date, timeZone: TimeZone) -> Date {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        let components = local.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        return utc.date(from: components)!
    }
}

enum WorldMutationOperation: String, Codable, CaseIterable, Sendable { case increment, set, append, replace, remove }
enum WorldValueKind: String, Codable, Sendable { case integer, ability, thread, fact }

struct GeneratedRecord: Codable, Equatable, Sendable {
    var id: String
    var title: String
    var summary: String
    var severityOrRank: Int?
    var involvedEntityIDs: [String]
}

struct WorldMutation: Codable, Equatable, Sendable, Identifiable {
    var id: String { "\(fieldID):\(operation.rawValue):\(record?.id ?? String(integerValue ?? 0))" }
    let fieldID: String
    let operation: WorldMutationOperation
    let integerValue: Int?
    let record: GeneratedRecord?

    static func increment(_ field: String, by value: Int) -> Self { .init(fieldID: field, operation: .increment, integerValue: value, record: nil) }
    static func append(_ field: String, record: GeneratedRecord) -> Self { .init(fieldID: field, operation: .append, integerValue: nil, record: record) }
}

struct WorldMutationDescriptor: Codable, Equatable, Sendable {
    let fieldID: String
    let kind: WorldValueKind
    let operations: Set<WorldMutationOperation>
    let range: ClosedRange<Int>?
    let maxDelta: Int?
    let collectionCap: Int?
    let description: String
}

struct WorldDelta: Codable, Equatable, Sendable, Identifiable {
    var id: String { fieldID + description }
    let fieldID: String
    let description: String
}

enum WorldPatchError: Error, Equatable, LocalizedError {
    case tooManyMutations, tooManyNewRecords, duplicateMutation(String), unknownField(String), deniedOperation(String), wrongValueType(String), outOfBounds(String), deltaExceeded(String), collectionFull(String), duplicateRecord(String), invalidRecord(String), invalidReference(String)

    var errorDescription: String? {
        switch self {
        case .tooManyMutations: "Too many changes were staged."
        case .tooManyNewRecords: "Too many new records were staged."
        case .duplicateMutation(let id): "A conflicting change targets \(id)."
        case .unknownField(let id): "\(id) is not writable."
        case .deniedOperation(let id): "The operation is denied for \(id)."
        case .wrongValueType(let id): "The proposed value has the wrong shape for \(id)."
        case .outOfBounds(let id): "The result for \(id) is outside its bounds."
        case .deltaExceeded(let id): "The change to \(id) exceeds its budget."
        case .collectionFull(let id): "The \(id) collection is full."
        case .duplicateRecord(let id): "Record \(id) already exists."
        case .invalidRecord(let id): "Record \(id) is malformed."
        case .invalidReference(let id): "Record \(id) refers to an unknown entity."
        }
    }
}

enum WorldContract {
    static let maximumMutations = 4
    static let maximumAppends = 2

    static func descriptors(for valence: EventValence, effort: ResolutionEffort? = nil) -> [WorldMutationDescriptor] {
        let effortValue = effort?.value ?? EffortRating.one.rawValue
        let maxDelta = effortValue * 4
        var result = ["world.morale", "world.integrity", "world.food", "world.hoard"].map {
            WorldMutationDescriptor(fieldID: $0, kind: .integer, operations: [.increment], range: 0...100, maxDelta: maxDelta, collectionCap: nil, description: ModelPromptRegistry.text(.legacyScalarDescriptor))
        }
        result += [
            WorldMutationDescriptor(fieldID: "world.abilities", kind: .ability, operations: valence == .positive ? [.append, .replace] : [.replace], range: 1...3, maxDelta: nil, collectionCap: 12, description: ModelPromptRegistry.text(.legacyAbilityDescriptor)),
            WorldMutationDescriptor(fieldID: "world.facts", kind: .fact, operations: [.append], range: nil, maxDelta: nil, collectionCap: 24, description: ModelPromptRegistry.text(.legacyFactDescriptor)),
            WorldMutationDescriptor(fieldID: "world.activeThreads", kind: .thread, operations: [.append, .replace], range: 1...min(4, effortValue + 1), maxDelta: nil, collectionCap: 4, description: ModelPromptRegistry.text(.legacyThreadDescriptor))
        ]
        return result
    }

    static func descriptors(for valence: EventValence, effort: ResolutionEffort? = nil, world: WorldSnapshot) -> [WorldMutationDescriptor] {
        let values = ["world.morale": world.morale, "world.integrity": world.integrity, "world.food": world.food, "world.hoard": world.hoard]
        let counts = ["world.abilities": world.abilities.count, "world.activeThreads": world.activeThreads.count, "world.facts": world.facts.count]
        return descriptors(for: valence, effort: effort).compactMap { descriptor in
            if descriptor.kind == .integer, let current = values[descriptor.fieldID], let range = descriptor.range {
                let available = valence == .positive ? range.upperBound - current : current - range.lowerBound
                let legalDelta = min(descriptor.maxDelta ?? 0, max(0, available))
                let suffix = ModelPromptRegistry.text(legalDelta == 0 ? .legacyDirectionalBoundary : .legacyDirectionalInterval)
                return WorldMutationDescriptor(fieldID: descriptor.fieldID, kind: descriptor.kind, operations: descriptor.operations, range: descriptor.range, maxDelta: legalDelta, collectionCap: nil, description: descriptor.description + suffix)
            }
            guard let cap = descriptor.collectionCap else { return descriptor }
            let count = counts[descriptor.fieldID, default: 0]
            var operations = descriptor.operations
            if count >= cap { operations.remove(.append) }
            let canReplace = switch descriptor.kind {
            case .ability:
                world.abilities.contains { valence == .positive ? $0.rank < descriptor.range!.upperBound : $0.rank > descriptor.range!.lowerBound }
            case .thread:
                world.activeThreads.contains { valence == .positive ? $0.severity > descriptor.range!.lowerBound : $0.severity < descriptor.range!.upperBound }
            case .integer, .fact:
                false
            }
            if !canReplace { operations.remove(.replace) }
            guard !operations.isEmpty else { return nil }
            let instruction = operations.contains(.append) && operations.contains(.replace)
                ? ModelPromptRegistry.text(.legacyAppendOrReplace)
                : ModelPromptRegistry.text(operations.contains(.replace) ? .legacyReplaceOnly : .legacyAppendOnly)
            return WorldMutationDescriptor(fieldID: descriptor.fieldID, kind: descriptor.kind, operations: operations, range: descriptor.range, maxDelta: descriptor.maxDelta, collectionCap: descriptor.collectionCap, description: descriptor.description + instruction)
        }
    }
}

enum WorldPatchValidator {
    static func applying(_ mutations: [WorldMutation], to original: WorldSnapshot, valence: EventValence, descriptors: [WorldMutationDescriptor]? = nil) throws -> (WorldSnapshot, [WorldDelta]) {
        let descriptors = descriptors ?? WorldContract.descriptors(for: valence)
        guard mutations.count <= WorldContract.maximumMutations else { throw WorldPatchError.tooManyMutations }
        guard mutations.filter({ $0.operation == .append }).count <= WorldContract.maximumAppends else { throw WorldPatchError.tooManyNewRecords }
        let contract = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.fieldID, $0) })
        var world = original
        var deltas: [WorldDelta] = []
        var targets = Set<String>()
        for mutation in mutations {
            let target = mutation.fieldID + ":" + (mutation.record?.id ?? "scalar")
            guard targets.insert(target).inserted else { throw WorldPatchError.duplicateMutation(target) }
            guard let descriptor = contract[mutation.fieldID] else { throw WorldPatchError.unknownField(mutation.fieldID) }
            guard descriptor.operations.contains(mutation.operation) else { throw WorldPatchError.deniedOperation(mutation.fieldID) }
            if descriptor.kind == .integer, let value = mutation.integerValue {
                guard valence == .positive ? value >= 0 : value <= 0 else { throw WorldPatchError.deltaExceeded(mutation.fieldID) }
            }
            switch descriptor.kind {
            case .integer: try applyInteger(mutation, descriptor: descriptor, world: &world, deltas: &deltas)
            case .ability: try applyAbility(mutation, descriptor: descriptor, valence: valence, world: &world, deltas: &deltas)
            case .thread: try applyThread(mutation, descriptor: descriptor, valence: valence, world: &world, deltas: &deltas)
            case .fact: try applyFact(mutation, descriptor: descriptor, world: &world, deltas: &deltas)
            }
        }
        return (world, deltas)
    }

    private static func applyInteger(_ mutation: WorldMutation, descriptor: WorldMutationDescriptor, world: inout WorldSnapshot, deltas: inout [WorldDelta]) throws {
        guard mutation.operation == .increment, let value = mutation.integerValue, mutation.record == nil else { throw WorldPatchError.wrongValueType(mutation.fieldID) }
        guard abs(value) <= descriptor.maxDelta! else { throw WorldPatchError.deltaExceeded(mutation.fieldID) }
        let old: Int
        switch mutation.fieldID { case "world.morale": old = world.morale; case "world.integrity": old = world.integrity; case "world.food": old = world.food; case "world.hoard": old = world.hoard; default: throw WorldPatchError.unknownField(mutation.fieldID) }
        let new = old + value
        guard descriptor.range!.contains(new) else { throw WorldPatchError.outOfBounds(mutation.fieldID) }
        switch mutation.fieldID { case "world.morale": world.morale = new; case "world.integrity": world.integrity = new; case "world.food": world.food = new; case "world.hoard": world.hoard = new; default: throw WorldPatchError.unknownField(mutation.fieldID) }
        deltas.append(WorldDelta(fieldID: mutation.fieldID, description: "\(mutation.fieldID.split(separator: ".").last!.capitalized): \(old) → \(new)"))
    }

    private static func validatedRecord(_ mutation: WorldMutation, descriptor: WorldMutationDescriptor) throws -> GeneratedRecord {
        guard mutation.integerValue == nil, let record = mutation.record, !record.id.isEmpty, record.id.count <= 60, !record.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, record.title.count <= 80, !record.summary.isEmpty, record.summary.count <= 240 else { throw WorldPatchError.invalidRecord(mutation.record?.id ?? mutation.fieldID) }
        if let range = descriptor.range { guard let value = record.severityOrRank, range.contains(value) else { throw WorldPatchError.outOfBounds(record.id) } }
        return record
    }

    private static func applyAbility(_ mutation: WorldMutation, descriptor: WorldMutationDescriptor, valence: EventValence, world: inout WorldSnapshot, deltas: inout [WorldDelta]) throws {
        let record = try validatedRecord(mutation, descriptor: descriptor)
        if let index = world.abilities.firstIndex(where: { $0.id == record.id }) {
            guard mutation.operation == .replace else { throw WorldPatchError.duplicateRecord(record.id) }
            let oldRank = world.abilities[index].rank
            guard valence == .positive ? record.severityOrRank! > oldRank : record.severityOrRank! < oldRank else { throw WorldPatchError.deltaExceeded(mutation.fieldID) }
            world.abilities[index] = AbilityState(id: record.id, name: record.title, summary: record.summary, rank: record.severityOrRank!)
            deltas.append(WorldDelta(fieldID: mutation.fieldID, description: "Ability changed: \(record.title) (\(oldRank) → \(record.severityOrRank!))"))
        } else {
            guard mutation.operation == .append else { throw WorldPatchError.invalidRecord(record.id) }
            guard world.abilities.count < descriptor.collectionCap! else { throw WorldPatchError.collectionFull(mutation.fieldID) }
            world.abilities.append(AbilityState(id: record.id, name: record.title, summary: record.summary, rank: record.severityOrRank!))
            deltas.append(WorldDelta(fieldID: mutation.fieldID, description: "Ability gained: \(record.title)"))
        }
    }

    private static func applyThread(_ mutation: WorldMutation, descriptor: WorldMutationDescriptor, valence: EventValence, world: inout WorldSnapshot, deltas: inout [WorldDelta]) throws {
        let record = try validatedRecord(mutation, descriptor: descriptor)
        let known = Set([world.dragon.id] + world.residents.map(\.id) + world.locations.map(\.id))
        guard Set(record.involvedEntityIDs).isSubset(of: known) else { throw WorldPatchError.invalidReference(record.id) }
        let thread = ActiveThreadState(id: record.id, title: record.title, severity: record.severityOrRank!, state: "active", involvedEntityIDs: record.involvedEntityIDs, summary: record.summary)
        if let index = world.activeThreads.firstIndex(where: { $0.id == record.id }) {
            guard mutation.operation == .replace else { throw WorldPatchError.duplicateRecord(record.id) }
            let oldSeverity = world.activeThreads[index].severity
            guard valence == .positive ? record.severityOrRank! < oldSeverity : record.severityOrRank! > oldSeverity else { throw WorldPatchError.deltaExceeded(mutation.fieldID) }
            world.activeThreads[index] = thread
            deltas.append(WorldDelta(fieldID: mutation.fieldID, description: "Thread changed: \(record.title)"))
        } else {
            guard mutation.operation == .append else { throw WorldPatchError.invalidRecord(record.id) }
            guard world.activeThreads.count < descriptor.collectionCap! else { throw WorldPatchError.collectionFull(mutation.fieldID) }
            world.activeThreads.append(thread)
            deltas.append(WorldDelta(fieldID: mutation.fieldID, description: "New thread: \(record.title)"))
        }
    }

    private static func applyFact(_ mutation: WorldMutation, descriptor: WorldMutationDescriptor, world: inout WorldSnapshot, deltas: inout [WorldDelta]) throws {
        let record = try validatedRecord(mutation, descriptor: descriptor)
        guard mutation.operation == .append else { throw WorldPatchError.deniedOperation(mutation.fieldID) }
        guard !world.facts.contains(where: { $0.id == record.id }) else { throw WorldPatchError.duplicateRecord(record.id) }
        guard world.facts.count < descriptor.collectionCap! else { throw WorldPatchError.collectionFull(mutation.fieldID) }
        world.facts.append(WorldFact(id: record.id, title: record.title, summary: record.summary))
        deltas.append(WorldDelta(fieldID: mutation.fieldID, description: "New fact: \(record.title)"))
    }
}

enum AnimationCue: String, Codable, CaseIterable, Sendable { case idle, celebrate, concern, recover, hazardAppears, resourceChanges }

enum ResolutionFlowStage: String, Codable, CaseIterable, Sendable {
    case effortSelection
    case actionSuggestion
    case customActionEntry
    case interpretedActionReview
    case actionAccepted
    case finalProse
    case committed
}

struct ResolutionPromptVersions: Codable, Equatable, Sendable {
    var effort: Int? = nil
    var suggestion: Int? = nil
    var interpretation: Int? = nil
    var finalProse: Int? = nil
}

struct StagedFinalResolution: Codable, Equatable, Sendable {
    let expectedRevision: Int
    let world: WorldSnapshot
    let mutations: [WorldMutation]
    let deltas: [WorldDelta]
    let title: String
    let finalProse: String
    let summary: String
    let cue: AnimationCue
}

struct StagedResolutionState: Codable, Equatable, Sendable {
    var stage: ResolutionFlowStage
    var effort: ResolutionEffort? = nil
    var comparisonHistoryIDs: [String] = []
    var suggestedAction: String? = nil
    var customAction: String? = nil
    var interpretedAction: String? = nil
    var acceptedAction: String? = nil
    var promptVersions = ResolutionPromptVersions()
    var finalResult: StagedFinalResolution? = nil
}

struct PendingStorySummary: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let sourceTitle: String
    var sourceNotes: String = ""
    var sourceCategory: GoalCategory? = nil
    var sourceEffort: GoalEffort? = nil
    var sourceDueDate: Date? = nil
    var sourceIncludesTime = false
    var sourceTimeZoneID: String? = nil
    let valence: EventValence
    let status: EventStatus
    let failureCode: String?
    let createdAt: Date
    var effort: ResolutionEffort? = nil
    var comparisonHistoryIDs: [String] = []
    var acceptedAction: String? = nil
    var finalProse: String? = nil
    var recordedWorld: WorldReadModel? = nil
    var resolutionState: StagedResolutionState? = nil
}

struct WorldReadModel: Codable, Equatable, Sendable {
    let dungeonName: String
    let revision: Int
    let snapshot: WorldSnapshot
}

struct ChronicleSummary: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let eventID: String
    let sourceTitle: String
    let valence: EventValence
    let title: String
    let finalProse: String
    let summary: String
    let deltas: [WorldDelta]
    let cue: AnimationCue
    let priorRevision: Int
    let committedRevision: Int
    let committedAt: Date
    let effort: ResolutionEffort?
    let comparisonHistoryIDs: [String]
    let acceptedAction: String?
    let recordedWorld: WorldReadModel
}

enum ProjectionBuilder {
    static func projection(event: PendingStorySummary, world: WorldReadModel, descriptors: [WorldMutationDescriptor], compact: Bool = false) -> String {
        let thread = world.snapshot.activeThreads.sorted { ($0.severity, $0.id) > ($1.severity, $1.id) }.first
        let residents = world.snapshot.residents.prefix(3).map {
            ModelPromptRegistry.render(compact ? .legacyResidentCompactTemplate : .legacyResidentFullTemplate, [
                "id": $0.id,
                "name": $0.name,
                "role": $0.role,
                "age": $0.koboldVisual?.age.rawValue ?? ModelPromptRegistry.text(.legacyMissingValue)
            ])
        }.joined(separator: "; ")
        let locations = world.snapshot.locations.map {
            ModelPromptRegistry.render(.legacyLocationTemplate, [
                "id": $0.id, "name": $0.name, "status": $0.status, "summary": $0.summary
            ])
        }.joined(separator: "; ")
        let sourceTitle = String(event.sourceTitle.prefix(compact ? 160 : 240))
        let sourceNotes = String(event.sourceNotes.prefix(compact ? 160 : 400))
        let referenceIDs = ([world.snapshot.dragon.id] + world.snapshot.residents.map(\.id) + world.snapshot.locations.map(\.id)).joined(separator: ",")
        let recordIDs = ModelPromptRegistry.render(.legacyRecordIDsTemplate, [
            "abilities": world.snapshot.abilities.map(\.id).joined(separator: ","),
            "activeThreads": world.snapshot.activeThreads.map(\.id).joined(separator: ","),
            "facts": world.snapshot.facts.map(\.id).joined(separator: ",")
        ])
        let contract = descriptors.map { descriptor in
            var limits: [String] = []
            if let range = descriptor.range {
                limits.append(ModelPromptRegistry.render(.legacyDescriptorRangeTemplate, [
                    "lowerBound": String(range.lowerBound), "upperBound": String(range.upperBound)
                ]))
            }
            if let maxDelta = descriptor.maxDelta {
                let value = ["maxDelta": String(maxDelta)]
                limits.append(ModelPromptRegistry.render(.legacyDescriptorMaxDeltaTemplate, value))
                limits.append(ModelPromptRegistry.render(.legacyDescriptorLegalStrengthTemplate, value))
            }
            if let cap = descriptor.collectionCap {
                limits.append(ModelPromptRegistry.render(.legacyDescriptorCollectionCapTemplate, ["collectionCap": String(cap)]))
            }
            return ModelPromptRegistry.render(.legacyDescriptorTemplate, [
                "fieldID": descriptor.fieldID,
                "operations": descriptor.operations.map(\.rawValue).sorted().joined(separator: ","),
                "limits": limits.joined(separator: " "),
                "description": descriptor.description
            ])
        }.joined(separator: "\n")
        return ModelPromptRegistry.render(.legacyProjectionTemplate, [
            "eventID": event.id,
            "valence": event.valence.rawValue,
            "revision": String(world.revision),
            "sourceTitle": sourceTitle,
            "sourceNotes": sourceNotes,
            "category": event.sourceCategory?.rawValue ?? ModelPromptRegistry.text(.legacyMissingValue),
            "effort": event.effort.map { String($0.value) } ?? event.sourceEffort.map { String($0.rating.rawValue) } ?? ModelPromptRegistry.text(.legacyMissingValue),
            "acceptedAction": String((event.acceptedAction ?? ModelPromptRegistry.text(.legacyMissingValue)).prefix(compact ? 80 : 160)),
            "due": event.sourceDueDate?.ISO8601Format() ?? ModelPromptRegistry.text(.legacyMissingValue),
            "includesTime": String(event.sourceIncludesTime),
            "timeZone": event.sourceTimeZoneID ?? ModelPromptRegistry.text(.legacyMissingValue),
            "dungeonName": world.dungeonName,
            "dragonName": world.snapshot.dragon.name,
            "dragonRole": world.snapshot.dragon.role,
            "dragonIdentity": world.snapshot.dragon.identity,
            "dragonStage": world.snapshot.dragonVisual.stage.rawValue,
            "morale": String(world.snapshot.morale),
            "integrity": String(world.snapshot.integrity),
            "food": String(world.snapshot.food),
            "hoard": String(world.snapshot.hoard),
            "residents": residents,
            "locations": locations,
            "referenceIDs": referenceIDs,
            "recordIDs": recordIDs,
            "activeThread": thread.map {
                ModelPromptRegistry.render(compact ? .legacyActiveThreadCompactTemplate : .legacyActiveThreadFullTemplate, [
                    "id": $0.id, "title": $0.title, "severity": String($0.severity), "summary": $0.summary
                ])
            } ?? ModelPromptRegistry.text(.legacyMissingValue),
            "recentSummary": String(world.snapshot.rollingSummary.prefix(compact ? 160 : 400)),
            "maximumMutations": String(WorldContract.maximumMutations),
            "maximumAppends": String(WorldContract.maximumAppends),
            "writableContract": contract
        ])
    }
}

struct LocalDataExport: Codable, Sendable {
    let exportVersion: Int
    let dataSchemaVersion: Int
    let promptVersion: Int
    let exportedAt: Date
    let goals: [GoalDefinitionSummary]
    let occurrences: [GoalOccurrenceSummary]
    let storyEvents: [PendingStorySummary]
    let world: WorldReadModel
    let chronicle: [ChronicleSummary]
}
