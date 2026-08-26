import Foundation
import NaturalLanguage

enum AttemptedGoalOutcome: String, Codable, Equatable, Sendable {
    case passed
    case failed
}

struct AttemptedGoalContext: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let notes: String
    let outcome: AttemptedGoalOutcome

    var content: String {
        [title, notes].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

enum AttemptedGoalHistory {
    static let maximumCount = 10

    static func closest(
        to currentContent: String,
        currentOccurrenceID: String,
        among occurrences: [GoalOccurrenceSummary]
    ) -> [AttemptedGoalContext] {
        closest(to: currentContent, currentOccurrenceID: currentOccurrenceID, among: occurrences, distance: semanticDistance)
    }

    static func closest(
        to currentContent: String,
        currentOccurrenceID: String,
        among occurrences: [GoalOccurrenceSummary],
        distance: (String, String) -> Double
    ) -> [AttemptedGoalContext] {
        occurrences.compactMap { occurrence -> (AttemptedGoalContext, Double, Date)? in
            guard occurrence.id != currentOccurrenceID else { return nil }
            let outcome: AttemptedGoalOutcome
            switch occurrence.state {
            case .completed: outcome = .passed
            case .expired: outcome = .failed
            case .pending, .cancelled: return nil
            }
            let context = AttemptedGoalContext(
                id: occurrence.id,
                title: occurrence.snapshot.title,
                notes: occurrence.snapshot.notes,
                outcome: outcome
            )
            return (context, distance(currentContent, context.content), occurrence.resolvedAt ?? .distantPast)
        }
        .sorted {
            if $0.1 != $1.1 { return $0.1 < $1.1 }
            if $0.2 != $1.2 { return $0.2 > $1.2 }
            return $0.0.id < $1.0.id
        }
        .prefix(maximumCount)
        .map(\.0)
    }

    static func fitting(
        _ closest: [AttemptedGoalContext],
        fits: ([AttemptedGoalContext]) async throws -> Bool
    ) async rethrows -> [AttemptedGoalContext] {
        var result = Array(closest.prefix(maximumCount))
        while !(try await fits(result)), !result.isEmpty {
            result.removeLast()
        }
        return result
    }

    private static func semanticDistance(_ first: String, _ second: String) -> Double {
        if let embedding = NLEmbedding.sentenceEmbedding(for: .english) {
            let distance = embedding.distance(between: first, and: second)
            if distance.isFinite { return distance }
        }
        let firstWords = words(in: first)
        let secondWords = words(in: second)
        guard !firstWords.isEmpty, !secondWords.isEmpty else { return 1 }
        return 1 - Double(firstWords.intersection(secondWords).count) / Double(firstWords.union(secondWords).count)
    }

    private static func words(in text: String) -> Set<String> {
        Set(text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
    }
}
