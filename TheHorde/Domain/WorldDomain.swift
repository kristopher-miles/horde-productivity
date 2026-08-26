import Foundation

enum DragonStage: String, Codable, Equatable, Sendable, CaseIterable {
    case baby, adolescent, adult, elder, greatWyrm
}

enum DungeonBackgroundStage: Int, Codable, Equatable, Sendable, CaseIterable {
    case one = 1, two, three, four, five
}

enum KoboldAgeStage: String, Codable, Equatable, Sendable, CaseIterable {
    case baby, kid, adult
}

struct RGBColor: Codable, Equatable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    static let ember = RGBColor(red: 224, green: 96, blue: 32)
}

struct CharacterPalette: Codable, Equatable, Sendable {
    let primary: RGBColor
    let secondary: RGBColor
}

struct DragonVisualState: Codable, Equatable, Sendable {
    var stage: DragonStage
    var color: RGBColor
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
    var residents: [CharacterState]
    var backgroundStage: DungeonBackgroundStage
    var morale: Int
    var integrity: Int
    var food: Int
    var locations: [LocationState]
    var abilities: [AbilityState]
    var activeThreads: [ActiveThreadState]
    var facts: [WorldFact]
    var rollingSummary: String

    static func initial(dragonName: String = "Ember", dungeonName: String = "The Cinder Vault") -> WorldSnapshot {
        WorldSnapshot(
            dragon: CharacterState(id: "dragon", name: dragonName, role: "Young dragon", identity: "A thoughtful ember-scaled dragon learning to care for a small underground home.", vitality: 50, bond: 50, conditions: []),
            dragonVisual: DragonVisualState(stage: .baby, color: .ember),
            residents: [
                CharacterState(id: "kobold-pip", name: "Pip", role: "Lantern keeper", identity: "Practical, bright-eyed, and fond of careful lists.", vitality: 50, bond: 45, conditions: []),
                CharacterState(id: "kobold-moss", name: "Moss", role: "Mushroom tender", identity: "Patient and quietly inventive.", vitality: 52, bond: 45, conditions: []),
                CharacterState(id: "kobold-rill", name: "Rill", role: "Stone mender", identity: "Steady-handed, curious, and impossible to hurry.", vitality: 55, bond: 45, conditions: [])
            ],
            backgroundStage: .one,
            morale: 50, integrity: 50, food: 50,
            locations: [LocationState(id: "great-room", name: dungeonName, status: "Quiet", summary: "Warm lanterns pool around a broad stone hearth."), LocationState(id: "mushroom-gallery", name: "Mushroom Gallery", status: "Growing", summary: "Pale caps rise from tidy beds.")],
            abilities: [],
            activeThreads: [ActiveThreadState(id: "drafty-passage", title: "A Draft in the West Passage", severity: 1, state: "active", involvedEntityIDs: ["kobold-rill"], summary: "A harmless cold draft hints at a loose stone waiting for attention.")],
            facts: [WorldFact(id: "home-begins", title: "A Small Home", summary: "Ember and the kobolds have chosen the vault as their shared home.")],
            rollingSummary: "Ember and three kobolds are making a calm home in the Cinder Vault. A loose stone causes a mild draft."
        )
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
    case tooManyMutations, tooManyNewRecords, duplicateMutation(String), unknownField(String), deniedOperation(String), wrongValueType(String), outOfBounds(String), deltaExceeded(String), collectionFull(String), duplicateRecord(String), invalidRecord(String), invalidReference(String), catastrophicNegative

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
        case .catastrophicNegative: "Negative events must remain small and recoverable."
        }
    }
}

enum WorldContract {
    static func descriptors(for valence: EventValence) -> [WorldMutationDescriptor] {
        let maxDelta = valence == .positive ? 4 : 2
        var result = ["world.morale", "world.integrity", "world.food"].map {
            WorldMutationDescriptor(fieldID: $0, kind: .integer, operations: [.increment], range: 0...100, maxDelta: maxDelta, collectionCap: nil, description: ModelPromptRegistry.text(.legacyScalarDescriptor))
        }
        if valence == .positive {
            result += [
                WorldMutationDescriptor(fieldID: "world.abilities", kind: .ability, operations: [.append, .replace], range: 1...3, maxDelta: nil, collectionCap: 12, description: ModelPromptRegistry.text(.legacyAbilityDescriptor)),
                WorldMutationDescriptor(fieldID: "world.facts", kind: .fact, operations: [.append], range: nil, maxDelta: nil, collectionCap: 24, description: ModelPromptRegistry.text(.legacyFactDescriptor))
            ]
        }
        result.append(WorldMutationDescriptor(fieldID: "world.activeThreads", kind: .thread, operations: [.append, .replace], range: 1...(valence == .positive ? 4 : 2), maxDelta: nil, collectionCap: 4, description: ModelPromptRegistry.text(.legacyThreadDescriptor)))
        return result
    }

    static func descriptors(for valence: EventValence, world: WorldSnapshot) -> [WorldMutationDescriptor] {
        let values = ["world.morale": world.morale, "world.integrity": world.integrity, "world.food": world.food]
        let counts = ["world.abilities": world.abilities.count, "world.activeThreads": world.activeThreads.count, "world.facts": world.facts.count]
        return descriptors(for: valence).compactMap { descriptor in
            if descriptor.kind == .integer, let current = values[descriptor.fieldID], let range = descriptor.range {
                let available = valence == .positive ? range.upperBound - current : current - range.lowerBound
                let legalDelta = min(descriptor.maxDelta ?? 0, max(0, available))
                let suffix = ModelPromptRegistry.text(legalDelta == 0 ? .legacyDirectionalBoundary : .legacyDirectionalInterval)
                return WorldMutationDescriptor(fieldID: descriptor.fieldID, kind: descriptor.kind, operations: descriptor.operations, range: descriptor.range, maxDelta: legalDelta, collectionCap: nil, description: descriptor.description + suffix)
            }
            guard let cap = descriptor.collectionCap else { return descriptor }
            let count = counts[descriptor.fieldID, default: 0]
            let operations = count >= cap
                ? descriptor.operations.subtracting([.append])
                : count == 0 ? descriptor.operations.subtracting([.replace]) : descriptor.operations
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
        guard mutations.count <= (valence == .positive ? 4 : 2) else { throw WorldPatchError.tooManyMutations }
        guard mutations.filter({ $0.operation == .append }).count <= (valence == .positive ? 2 : 1) else { throw WorldPatchError.tooManyNewRecords }
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
            case .ability: try applyAbility(mutation, descriptor: descriptor, world: &world, deltas: &deltas)
            case .thread: try applyThread(mutation, descriptor: descriptor, world: &world, deltas: &deltas)
            case .fact: try applyFact(mutation, descriptor: descriptor, world: &world, deltas: &deltas)
            }
        }
        if valence == .negative, mutations.contains(where: { $0.operation == .remove || ($0.integerValue ?? 0) < -2 }) { throw WorldPatchError.catastrophicNegative }
        return (world, deltas)
    }

    private static func applyInteger(_ mutation: WorldMutation, descriptor: WorldMutationDescriptor, world: inout WorldSnapshot, deltas: inout [WorldDelta]) throws {
        guard mutation.operation == .increment, let value = mutation.integerValue, mutation.record == nil else { throw WorldPatchError.wrongValueType(mutation.fieldID) }
        guard abs(value) <= descriptor.maxDelta! else { throw WorldPatchError.deltaExceeded(mutation.fieldID) }
        let old: Int
        switch mutation.fieldID { case "world.morale": old = world.morale; case "world.integrity": old = world.integrity; case "world.food": old = world.food; default: throw WorldPatchError.unknownField(mutation.fieldID) }
        let new = old + value
        guard descriptor.range!.contains(new) else { throw WorldPatchError.outOfBounds(mutation.fieldID) }
        switch mutation.fieldID { case "world.morale": world.morale = new; case "world.integrity": world.integrity = new; default: world.food = new }
        deltas.append(WorldDelta(fieldID: mutation.fieldID, description: "\(mutation.fieldID.split(separator: ".").last!.capitalized): \(old) → \(new)"))
    }

    private static func validatedRecord(_ mutation: WorldMutation, descriptor: WorldMutationDescriptor) throws -> GeneratedRecord {
        guard mutation.integerValue == nil, let record = mutation.record, !record.id.isEmpty, record.id.count <= 60, !record.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, record.title.count <= 80, !record.summary.isEmpty, record.summary.count <= 240 else { throw WorldPatchError.invalidRecord(mutation.record?.id ?? mutation.fieldID) }
        if let range = descriptor.range { guard let value = record.severityOrRank, range.contains(value) else { throw WorldPatchError.outOfBounds(record.id) } }
        return record
    }

    private static func applyAbility(_ mutation: WorldMutation, descriptor: WorldMutationDescriptor, world: inout WorldSnapshot, deltas: inout [WorldDelta]) throws {
        let record = try validatedRecord(mutation, descriptor: descriptor)
        if let index = world.abilities.firstIndex(where: { $0.id == record.id }) {
            guard mutation.operation == .replace else { throw WorldPatchError.duplicateRecord(record.id) }
            world.abilities[index] = AbilityState(id: record.id, name: record.title, summary: record.summary, rank: record.severityOrRank!)
            deltas.append(WorldDelta(fieldID: mutation.fieldID, description: "Ability improved: \(record.title)"))
        } else {
            guard mutation.operation == .append else { throw WorldPatchError.invalidRecord(record.id) }
            guard world.abilities.count < descriptor.collectionCap! else { throw WorldPatchError.collectionFull(mutation.fieldID) }
            world.abilities.append(AbilityState(id: record.id, name: record.title, summary: record.summary, rank: record.severityOrRank!))
            deltas.append(WorldDelta(fieldID: mutation.fieldID, description: "Ability gained: \(record.title)"))
        }
    }

    private static func applyThread(_ mutation: WorldMutation, descriptor: WorldMutationDescriptor, world: inout WorldSnapshot, deltas: inout [WorldDelta]) throws {
        let record = try validatedRecord(mutation, descriptor: descriptor)
        let known = Set([world.dragon.id] + world.residents.map(\.id) + world.locations.map(\.id))
        guard Set(record.involvedEntityIDs).isSubset(of: known) else { throw WorldPatchError.invalidReference(record.id) }
        let thread = ActiveThreadState(id: record.id, title: record.title, severity: record.severityOrRank!, state: "active", involvedEntityIDs: record.involvedEntityIDs, summary: record.summary)
        if let index = world.activeThreads.firstIndex(where: { $0.id == record.id }) {
            guard mutation.operation == .replace else { throw WorldPatchError.duplicateRecord(record.id) }
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
                "id": $0.id, "name": $0.name, "role": $0.role
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
            "effort": event.sourceEffort?.rawValue ?? ModelPromptRegistry.text(.legacyMissingValue),
            "due": event.sourceDueDate?.ISO8601Format() ?? ModelPromptRegistry.text(.legacyMissingValue),
            "includesTime": String(event.sourceIncludesTime),
            "timeZone": event.sourceTimeZoneID ?? ModelPromptRegistry.text(.legacyMissingValue),
            "dungeonName": world.dungeonName,
            "dragonName": world.snapshot.dragon.name,
            "morale": String(world.snapshot.morale),
            "integrity": String(world.snapshot.integrity),
            "food": String(world.snapshot.food),
            "residents": residents,
            "referenceIDs": referenceIDs,
            "recordIDs": recordIDs,
            "activeThread": thread.map {
                ModelPromptRegistry.render(compact ? .legacyActiveThreadCompactTemplate : .legacyActiveThreadFullTemplate, [
                    "id": $0.id, "title": $0.title, "severity": String($0.severity), "summary": $0.summary
                ])
            } ?? ModelPromptRegistry.text(.legacyMissingValue),
            "recentSummary": String(world.snapshot.rollingSummary.prefix(compact ? 160 : 400)),
            "maximumMutations": String(event.valence == .positive ? 4 : 2),
            "maximumAppends": String(event.valence == .positive ? 2 : 1),
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
