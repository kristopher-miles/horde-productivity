import Foundation

enum GoalCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case personal = "Personal", work = "Work", study = "Study", health = "Health", home = "Home"
    var id: Self { self }
}

enum GoalEffort: String, Codable, CaseIterable, Sendable, Identifiable {
    case small = "Small", medium = "Medium", large = "Large"
    var id: Self { self }
}

enum RecurrenceRule: Codable, Equatable, Sendable {
    case never
    case daily
    case weekdays(Set<Int>)

    var label: String {
        switch self {
        case .never: "Never"
        case .daily: "Daily"
        case .weekdays(let days): days.isEmpty ? "Selected weekdays" : days.sorted().map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
        }
    }
}

enum GoalOccurrenceState: String, Codable, Sendable { case pending, completed, expired, cancelled }

struct GoalDraft: Codable, Equatable, Sendable {
    var title = ""
    var notes = ""
    var dueDate: Date?
    var includesTime = false
    var recurrence: RecurrenceRule = .never
    var category: GoalCategory?
    var effort: GoalEffort?

    var isValid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    mutating func setDateEnabled(_ enabled: Bool, defaultDate: Date = .now) {
        if enabled {
            dueDate = dueDate ?? defaultDate
        } else {
            dueDate = nil
            includesTime = false
        }
    }
}

struct GoalSnapshot: Codable, Equatable, Sendable {
    let title: String
    let notes: String
    let category: GoalCategory?
    let effort: GoalEffort?
    let recurrence: RecurrenceRule
    let definitionVersion: Int
}

struct GoalOccurrenceSummary: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let definitionID: String
    let snapshot: GoalSnapshot
    let dueDate: Date?
    let includesTime: Bool
    var timeZoneID: String = TimeZone.current.identifier
    let state: GoalOccurrenceState
    let resolvedAt: Date?
    let hasPendingStory: Bool

    var dueLabel: String {
        guard let dueDate else { return "Any time" }
        if includesTime { return dueDate.formatted(date: .abbreviated, time: .shortened) }
        return dueDate.formatted(date: .abbreviated, time: .omitted)
    }
}

struct GoalDefinitionSummary: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let draft: GoalDraft
    let version: Int
    let archived: Bool
    let history: [GoalOccurrenceSummary]
}

enum GoalSection: Int, CaseIterable, Sendable { case overdue, today, upcoming }

enum GoalValidationError: Error, Equatable { case blankTitle, emptyWeekdays }

enum ScheduleCalculator {
    static func validated(_ draft: GoalDraft) throws {
        guard draft.isValid else { throw GoalValidationError.blankTitle }
        if case .weekdays(let days) = draft.recurrence, days.isEmpty { throw GoalValidationError.emptyWeekdays }
    }

    static func firstDue(for draft: GoalDraft, now: Date, calendar: Calendar = .current) -> Date? {
        guard let selected = draft.dueDate else { return nil }
        let anchor = boundary(for: selected, includesTime: draft.includesTime, calendar: calendar)
        switch draft.recurrence {
        case .never: return anchor
        case .daily:
            var candidate = anchor
            while candidate < now { candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate }
            return candidate
        case .weekdays(let weekdays):
            return nextMatching(onOrAfter: max(calendar.startOfDay(for: selected), calendar.startOfDay(for: now)), anchor: selected, includesTime: draft.includesTime, weekdays: weekdays, calendar: calendar)
        }
    }

    static func nextDue(after due: Date?, draft: GoalDraft, now: Date = .now, calendar: Calendar = .current) -> Date? {
        let anchor = due ?? now
        switch draft.recurrence {
        case .never: return nil
        case .daily:
            guard let next = calendar.date(byAdding: .day, value: 1, to: anchor) else { return nil }
            return draft.includesTime ? next : boundary(for: next, includesTime: false, calendar: calendar)
        case .weekdays(let weekdays):
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: anchor)) else { return nil }
            return nextMatching(onOrAfter: nextDay, anchor: draft.dueDate ?? anchor, includesTime: draft.includesTime, weekdays: weekdays, calendar: calendar)
        }
    }

    static func section(for occurrence: GoalOccurrenceSummary, now: Date, calendar: Calendar = .current) -> GoalSection {
        guard let due = occurrence.dueDate else { return .today }
        if due < now { return .overdue }
        return calendar.isDate(due, inSameDayAs: now) ? .today : .upcoming
    }

    private static func boundary(for date: Date, includesTime: Bool, calendar: Calendar) -> Date {
        guard !includesTime else { return date }
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }

    private static func nextMatching(onOrAfter start: Date, anchor: Date, includesTime: Bool, weekdays: Set<Int>, calendar: Calendar) -> Date? {
        let time = calendar.dateComponents([.hour, .minute, .second], from: anchor)
        for offset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: start)) else { continue }
            guard weekdays.contains(calendar.component(.weekday, from: day)) else { continue }
            if includesTime {
                return calendar.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: time.second ?? 0, of: day)
            }
            return boundary(for: day, includesTime: false, calendar: calendar)
        }
        return nil
    }
}
