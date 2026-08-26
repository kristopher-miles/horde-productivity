import Foundation

enum EventValence: String, Codable, Sendable, CaseIterable { case positive, negative }
enum EventStatus: String, Codable, Sendable { case pending, resolving, resolved, failedRetryable }
enum MutationOperation: String, Codable, Sendable, CaseIterable { case increment, set }

struct StagedMutation: Codable, Equatable, Sendable, Identifiable {
    var id: String { "\(fieldID):\(operation.rawValue):\(value)" }
    let fieldID: String
    let operation: MutationOperation
    let value: Int
}

struct MutationDescriptor: Codable, Equatable, Sendable {
    let fieldID: String
    let operations: Set<MutationOperation>
    let range: ClosedRange<Int>
    let maxDelta: Int
}

enum PatchValidationError: Error, Equatable, LocalizedError {
    case tooManyMutations
    case duplicateField(String)
    case unknownField(String)
    case operationDenied(String)
    case deltaExceeded(String)
    case valueOutOfBounds(String)

    var errorDescription: String? {
        switch self {
        case .tooManyMutations: "Too many mutations were proposed."
        case .duplicateField(let field): "The field \(field) was changed more than once."
        case .unknownField(let field): "The field \(field) is not writable."
        case .operationDenied(let field): "That operation is not allowed for \(field)."
        case .deltaExceeded(let field): "The change to \(field) exceeds its budget."
        case .valueOutOfBounds(let field): "The resulting value for \(field) is outside its bounds."
        }
    }
}

enum PatchValidator {
    static func validate(
        _ mutations: [StagedMutation],
        descriptors: [MutationDescriptor],
        currentValues: [String: Int],
        maximumCount: Int
    ) throws {
        guard mutations.count <= maximumCount else { throw PatchValidationError.tooManyMutations }
        let allowed = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.fieldID, $0) })
        var seen = Set<String>()
        for mutation in mutations {
            guard seen.insert(mutation.fieldID).inserted else { throw PatchValidationError.duplicateField(mutation.fieldID) }
            guard let descriptor = allowed[mutation.fieldID] else { throw PatchValidationError.unknownField(mutation.fieldID) }
            guard descriptor.operations.contains(mutation.operation) else { throw PatchValidationError.operationDenied(mutation.fieldID) }
            let current = currentValues[mutation.fieldID] ?? 0
            let finalValue: Int
            switch mutation.operation {
            case .increment:
                guard abs(mutation.value) <= descriptor.maxDelta else { throw PatchValidationError.deltaExceeded(mutation.fieldID) }
                finalValue = current + mutation.value
            case .set:
                finalValue = mutation.value
                guard abs(finalValue - current) <= descriptor.maxDelta else { throw PatchValidationError.deltaExceeded(mutation.fieldID) }
            }
            guard descriptor.range.contains(finalValue) else { throw PatchValidationError.valueOutOfBounds(mutation.fieldID) }
        }
    }
}

enum CompatibilityState: Equatable, Sendable {
    case checking, available, deviceNotEligible, intelligenceDisabled, modelNotReady, unsupportedLocale, unknown

    var title: String {
        switch self {
        case .checking: "Checking this \(PlatformSupport.deviceName)"
        case .available: "Ready"
        case .deviceNotEligible: "This \(PlatformSupport.deviceName) isn’t supported"
        case .intelligenceDisabled: "Turn on Apple Intelligence"
        case .modelNotReady: "The on-device model isn’t ready"
        case .unsupportedLocale: "This language isn’t supported"
        case .unknown: "The model is unavailable"
        }
    }
}
