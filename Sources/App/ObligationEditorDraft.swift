import Foundation
import ReadyRoomCore

struct ObligationEditorDraft: Equatable {
    var id: String
    var title: String
    var notes: String
    var owner: PersonID?
    var scheduleKind: ObligationScheduleKind
    var dueDate: Date
    var interval: Int
    var weekdaysText: String
    var dayOfMonth: Int
    var monthOfYear: Int
    var customRule: String
    var reminderLeadDaysText: String
    var originalEntry: String
    var explanation: String

    init(record: ObligationRecord) {
        self.id = record.id
        self.title = record.title
        self.notes = record.notes ?? ""
        self.owner = record.owner
        self.scheduleKind = record.schedule.kind
        self.dueDate = record.schedule.dueDate ?? .now
        self.interval = record.schedule.interval
        self.weekdaysText = record.schedule.weekdays.map(String.init).joined(separator: ", ")
        self.dayOfMonth = record.schedule.dayOfMonth ?? 1
        self.monthOfYear = record.schedule.monthOfYear ?? 1
        self.customRule = record.schedule.customRule ?? ""
        self.reminderLeadDaysText = record.reminderLeadDays.map(String.init).joined(separator: ", ")
        self.originalEntry = record.originalEntry ?? ""
        self.explanation = record.explanation ?? ""
    }

    func materializedRecord() -> ObligationRecord {
        ObligationRecord(
            id: id,
            title: title.isEmpty ? "Untitled obligation" : title,
            notes: notes.nilIfEmpty,
            owner: owner,
            schedule: ObligationSchedule(
                kind: scheduleKind,
                dueDate: scheduleKind == .oneTime || scheduleKind == .custom ? dueDate : nil,
                interval: max(1, interval),
                weekdays: parsedWeekdays,
                dayOfMonth: scheduleKind == .monthly || scheduleKind == .yearly ? min(max(dayOfMonth, 1), 31) : nil,
                monthOfYear: scheduleKind == .yearly ? min(max(monthOfYear, 1), 12) : nil,
                customRule: scheduleKind == .custom ? customRule.nilIfEmpty : nil
            ),
            reminderLeadDays: parsedLeadDays,
            originalEntry: originalEntry.nilIfEmpty,
            explanation: explanation.nilIfEmpty
        )
    }

    private var parsedLeadDays: [Int] {
        let values = reminderLeadDaysText
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0 >= 0 && $0 <= 365 }
        return values.isEmpty ? [7, 3] : values.sorted(by: >)
    }

    private var parsedWeekdays: [Int] {
        weekdaysText
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { (1...7).contains($0) }
            .sorted()
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
