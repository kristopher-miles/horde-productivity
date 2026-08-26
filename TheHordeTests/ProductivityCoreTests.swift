import Foundation
import Testing
@testable import TheHorde

@Suite("Local productivity core")
struct ProductivityCoreTests {
    @Test func enablingAndDisablingDateMutatesTheSavedDraftImmediately() {
        let defaultDate = Date(timeIntervalSince1970: 1_700_000_000)
        var draft = GoalDraft(title: "Dated")
        draft.setDateEnabled(true, defaultDate: defaultDate)
        #expect(draft.dueDate == defaultDate)
        draft.includesTime = true
        draft.setDateEnabled(false)
        #expect(draft.dueDate == nil)
        #expect(draft.includesTime == false)
    }

    @Test func blankTitleFailsButAcceptedTextIsPreservedExactly() async throws {
        let store = try await makeStore()
        await #expect(throws: GoalValidationError.blankTitle) { _ = try await store.createGoal(GoalDraft(title: "  \n  ")) }

        let exact = "  Read 📚  Chapter\nTwo  "
        let id = try await store.createGoal(GoalDraft(title: exact, notes: "Don’t normalize me"))
        let saved = try #require(await store.definitionSummary(id: id))
        #expect(saved.draft.title == exact)
        #expect(saved.history.first?.snapshot.title == exact)
    }

    @Test func completionIsExactlyOnceAndCreatesOnePendingEvent() async throws {
        let store = try await makeStore()
        let id = try await store.createGoal(GoalDraft(title: "Finish the report"))
        let occurrence = try #require(await store.definitionSummary(id: id)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        try await store.completeOccurrence(id: occurrence.id)
        let result = try #require(await store.definitionSummary(id: id))
        #expect(result.history.filter { $0.state == .completed }.count == 1)
        #expect(try await store.pendingStoryCount() == 1)
    }

    @Test func deadlineReconciliationExpiresOnce() async throws {
        let store = try await makeStore()
        let now = Date(timeIntervalSince1970: 2_000_000)
        var draft = GoalDraft(title: "Past due")
        draft.dueDate = now.addingTimeInterval(-60)
        draft.includesTime = true
        _ = try await store.createGoal(draft, now: now)
        #expect(try await store.reconcileDeadlines(now: now) == 1)
        #expect(try await store.reconcileDeadlines(now: now) == 0)
        #expect(try await store.pendingStoryCount() == 1)
    }

    @Test func selectedWeekdaysCrossWeekBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Denver"))
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 9)))
        var draft = GoalDraft(title: "Weekdays", dueDate: monday, includesTime: true, recurrence: .weekdays([2, 4]))
        let first = try #require(ScheduleCalculator.firstDue(for: draft, now: monday, calendar: calendar))
        let wednesday = try #require(ScheduleCalculator.nextDue(after: first, draft: draft, calendar: calendar))
        let nextMonday = try #require(ScheduleCalculator.nextDue(after: wednesday, draft: draft, calendar: calendar))
        #expect(calendar.component(.weekday, from: first) == 2)
        #expect(calendar.component(.weekday, from: wednesday) == 4)
        #expect(calendar.component(.weekday, from: nextMonday) == 2)
        draft.recurrence = .weekdays([])
        #expect(throws: GoalValidationError.emptyWeekdays) { try ScheduleCalculator.validated(draft) }
    }

    @Test func recurringGoalsWithoutAnInitialDateCreateAllDaySuccessors() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Denver"))
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 10)))

        for recurrence in [RecurrenceRule.daily, .weekdays([4])] {
            let store = try await makeStore()
            let id = try await store.createGoal(GoalDraft(title: "Repeat", recurrence: recurrence), now: monday, calendar: calendar)
            let first = try #require(await store.definitionSummary(id: id)?.history.first { $0.state == .pending })
            #expect(first.dueDate == nil)
            let successorID = try #require(try await store.completeOccurrence(id: first.id, now: monday, calendar: calendar))
            let successor = try #require(await store.definitionSummary(id: id)?.history.first { $0.id == successorID })
            #expect(successor.includesTime == false)
            #expect(successor.dueDate != nil)
            #expect(successor.dueDate! > monday)
            if case .weekdays = recurrence { #expect(calendar.component(.weekday, from: successor.dueDate!) == 4) }
        }
    }

    @Test func everyNonemptyWeekdaySelectionMaterializesOnlySelectedDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 9)))
        for mask in 1..<128 {
            let days = Set((1...7).filter { mask & (1 << ($0 - 1)) != 0 })
            let draft = GoalDraft(title: "Weekday mask", dueDate: monday, includesTime: true, recurrence: .weekdays(days))
            let first = try #require(ScheduleCalculator.firstDue(for: draft, now: monday, calendar: calendar))
            #expect(days.contains(calendar.component(.weekday, from: first)))
            let next = try #require(ScheduleCalculator.nextDue(after: first, draft: draft, calendar: calendar))
            #expect(days.contains(calendar.component(.weekday, from: next)))
            #expect(next > first)
        }
    }

    @Test func allDayBoundariesSurviveDSTLeapYearAndRepresentativeOffsets() throws {
        for identifier in ["America/Denver", "UTC", "Asia/Kathmandu", "Australia/Eucla", "America/St_Johns"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(identifier: identifier))
            for components in [
                DateComponents(year: 2024, month: 2, day: 29, hour: 12),
                DateComponents(year: 2026, month: 3, day: 8, hour: 12),
                DateComponents(year: 2026, month: 11, day: 1, hour: 12),
                DateComponents(year: 2026, month: 12, day: 31, hour: 12)
            ] {
                let selected = try #require(calendar.date(from: components))
                let due = try #require(ScheduleCalculator.firstDue(for: GoalDraft(title: "Boundary", dueDate: selected), now: calendar.startOfDay(for: selected), calendar: calendar))
                let dueComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: due)
                #expect(dueComponents.year == components.year)
                #expect(dueComponents.month == components.month)
                #expect(dueComponents.day == components.day)
                #expect(dueComponents.hour == 23)
                #expect(dueComponents.minute == 59)
                #expect(dueComponents.second == 59)
            }
        }
    }

    @Test func reconciliationHonorsExactBoundaryAndBuildsFiniteBacklog() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let firstDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12)))
        let firstDue = try #require(ScheduleCalculator.firstDue(for: GoalDraft(title: "Daily", dueDate: firstDay, recurrence: .daily), now: firstDay, calendar: calendar))
        let store = try await makeStore()
        _ = try await store.createGoal(GoalDraft(title: "Daily", dueDate: firstDay, recurrence: .daily), now: firstDay, calendar: calendar)
        #expect(try await store.reconcileDeadlines(now: firstDue, calendar: calendar) == 0)
        #expect(try await store.reconcileDeadlines(now: firstDue.addingTimeInterval(1), calendar: calendar) == 1)
        let januaryFifthNoon = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 12)))
        #expect(try await store.reconcileDeadlines(now: januaryFifthNoon, calendar: calendar) == 3)
        #expect(try await store.pendingStoryCount() == 4)
        #expect(try await store.occurrenceSummaries().filter { $0.state == .pending }.count == 1)
    }

    @Test func travelUsesCurrentZoneForFutureOccurrenceAndPreservesHistoryZone() async throws {
        var denver = Calendar(identifier: .gregorian)
        denver.timeZone = try #require(TimeZone(identifier: "America/Denver"))
        var kathmandu = Calendar(identifier: .gregorian)
        kathmandu.timeZone = try #require(TimeZone(identifier: "Asia/Kathmandu"))
        let now = try #require(denver.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 9)))
        let store = try await makeStore()
        let id = try await store.createGoal(GoalDraft(title: "Travel", recurrence: .daily), now: now, calendar: denver)
        let original = try #require(await store.definitionSummary(id: id)?.history.first)
        let successorID = try #require(try await store.completeOccurrence(id: original.id, now: now, calendar: kathmandu))
        let history = try #require(await store.definitionSummary(id: id)?.history)
        #expect(history.first { $0.id == original.id }?.timeZoneID == "America/Denver")
        #expect(history.first { $0.id == successorID }?.timeZoneID == "Asia/Kathmandu")
    }

    @Test func editingFutureGoalDoesNotRewriteResolvedSnapshot() async throws {
        let store = try await makeStore()
        let id = try await store.createGoal(GoalDraft(title: "Original title"))
        let occurrence = try #require(await store.definitionSummary(id: id)?.history.first)
        try await store.completeOccurrence(id: occurrence.id)
        try await store.updateGoal(id: id, draft: GoalDraft(title: "Future title"))
        let result = try #require(await store.definitionSummary(id: id))
        #expect(result.draft.title == "Future title")
        #expect(result.history.contains { $0.state == .completed && $0.snapshot.title == "Original title" })
        #expect(result.history.contains { $0.state == .pending && $0.snapshot.title == "Future title" })
    }

    private func makeStore() async throws -> HordeStore {
        let container = try HordeStore.makeContainer(inMemory: true)
        let store = HordeStore(modelContainer: container)
        try await store.bootstrapForProof()
        return store
    }
}
