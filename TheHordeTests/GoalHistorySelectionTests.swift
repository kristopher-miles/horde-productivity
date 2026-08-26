import Foundation
import Testing
@testable import TheHorde

@Suite("Attempted goal history selection")
struct GoalHistorySelectionTests {
    @Test func selectsClosestTenAttemptsWithContentAndOutcome() {
        let attempts = (0..<12).map { index in
            occurrence(
                id: "attempt-\(index)",
                title: "Goal content \(index)",
                notes: "Notes \(index)",
                state: index.isMultiple(of: 2) ? .completed : .expired,
                resolvedAt: Date(timeIntervalSince1970: Double(index))
            )
        }
        let excluded = [
            occurrence(id: "current", title: "Current", state: .completed),
            occurrence(id: "pending", title: "Pending", state: .pending),
            occurrence(id: "cancelled", title: "Cancelled", state: .cancelled)
        ]
        let distances = Dictionary(uniqueKeysWithValues: (0..<12).map { ("Goal content \($0)\nNotes \($0)", Double($0 + 100)) })

        let selected = AttemptedGoalHistory.closest(
            to: "Semantically unrelated current goal",
            currentOccurrenceID: "current",
            among: attempts + excluded,
            distance: { _, candidate in distances[candidate] ?? .greatestFiniteMagnitude }
        )

        #expect(selected.map(\.id) == (0..<10).map { "attempt-\($0)" })
        #expect(selected.map(\.content) == (0..<10).map { "Goal content \($0)\nNotes \($0)" })
        #expect(selected.map(\.outcome) == (0..<10).map { $0.isMultiple(of: 2) ? .passed : .failed })
        #expect(!selected.contains { ["current", "pending", "cancelled"].contains($0.id) })
        #expect(AttemptedGoalHistory.closest(
            to: "First attempt",
            currentOccurrenceID: "current",
            among: excluded,
            distance: { _, _ in 0 }
        ).isEmpty)
    }

    @Test func trimsOneLeastSimilarAttemptPerContextCheck() async throws {
        let closest = (0..<10).map {
            AttemptedGoalContext(id: "attempt-\($0)", title: "Goal \($0)", notes: "", outcome: .passed)
        }
        var checkedCounts: [Int] = []

        let untrimmed = try await AttemptedGoalHistory.fitting(closest) { _ in true }
        #expect(untrimmed == closest)

        let fitted = try await AttemptedGoalHistory.fitting(closest) { history in
            checkedCounts.append(history.count)
            return history.count <= 7
        }

        #expect(checkedCounts == [10, 9, 8, 7])
        #expect(fitted.map(\.id) == (0..<7).map { "attempt-\($0)" })
    }

    @Test func storeReturnsOnlyPriorPassedAndFailedAttempts() async throws {
        let store = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        try await store.bootstrapForProof()
        let base = Date(timeIntervalSince1970: 1_800_000_000)

        let passedID = try await store.createGoal(GoalDraft(title: "Repair the eastern bridge", notes: "Replace the cracked stone"), now: base.addingTimeInterval(-20))
        let passed = try #require(await store.definitionSummary(id: passedID)?.history.first)
        try await store.completeOccurrence(id: passed.id, now: base.addingTimeInterval(-19))

        let failedID = try await store.createGoal(GoalDraft(title: "Repair the western bridge", notes: "Replace the broken arch", dueDate: .distantPast, includesTime: true), now: base.addingTimeInterval(-18))
        let failed = try #require(await store.definitionSummary(id: failedID)?.history.first)
        _ = try await store.reconcileDeadlines(now: base.addingTimeInterval(-17))

        let pendingID = try await store.createGoal(GoalDraft(title: "Pending bridge work"), now: base.addingTimeInterval(-16))
        let pending = try #require(await store.definitionSummary(id: pendingID)?.history.first)

        let cancelledID = try await store.createGoal(GoalDraft(title: "Cancelled bridge work"), now: base.addingTimeInterval(-15))
        let cancelled = try #require(await store.definitionSummary(id: cancelledID)?.history.first)
        try await store.archiveGoal(id: cancelledID, now: base.addingTimeInterval(-14))

        let currentID = try await store.createGoal(GoalDraft(title: "Repair the central bridge"), now: base)
        let current = try #require(await store.definitionSummary(id: currentID)?.history.first)
        try await store.completeOccurrence(id: current.id, now: base.addingTimeInterval(1))

        let laterID = try await store.createGoal(GoalDraft(title: "Repair the central bridge again"), now: base.addingTimeInterval(2))
        let later = try #require(await store.definitionSummary(id: laterID)?.history.first)
        try await store.completeOccurrence(id: later.id, now: base.addingTimeInterval(3))
        let history = try await store.attemptedGoalHistory(for: current.id + ":positive")

        #expect(Set(history.map(\.id)) == [passed.id, failed.id])
        #expect(history.first { $0.id == passed.id }?.outcome == .passed)
        #expect(history.first { $0.id == failed.id }?.outcome == .failed)
        #expect(history.first { $0.id == passed.id }?.content == "Repair the eastern bridge\nReplace the cracked stone")
        #expect(!history.map(\.id).contains(pending.id))
        #expect(!history.map(\.id).contains(cancelled.id))
        #expect(!history.map(\.id).contains(current.id))
        #expect(!history.map(\.id).contains(later.id))

        let firstStore = HordeStore(modelContainer: try HordeStore.makeContainer(inMemory: true))
        try await firstStore.bootstrapForProof()
        let firstID = try await firstStore.createGoal(GoalDraft(title: "First-ever attempt"), now: base)
        let first = try #require(await firstStore.definitionSummary(id: firstID)?.history.first)
        try await firstStore.completeOccurrence(id: first.id, now: base.addingTimeInterval(1))
        #expect(try await firstStore.attemptedGoalHistory(for: first.id + ":positive").isEmpty)
    }

    private func occurrence(
        id: String,
        title: String,
        notes: String = "",
        state: GoalOccurrenceState,
        resolvedAt: Date? = nil
    ) -> GoalOccurrenceSummary {
        GoalOccurrenceSummary(
            id: id,
            definitionID: "definition-\(id)",
            snapshot: GoalSnapshot(title: title, notes: notes, category: nil, effort: nil, recurrence: .never, definitionVersion: 1),
            dueDate: nil,
            includesTime: false,
            state: state,
            resolvedAt: resolvedAt,
            hasPendingStory: false
        )
    }
}
