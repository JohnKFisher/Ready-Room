import Foundation

public extension Calendar {
    static var readyRoomGregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }
}

public extension Date {
    func startOfDay(in calendar: Calendar = .readyRoomGregorian) -> Date {
        calendar.startOfDay(for: self)
    }

    func adding(days: Int, calendar: Calendar = .readyRoomGregorian) -> Date {
        calendar.date(byAdding: .day, value: days, to: self) ?? self
    }

    func formattedMonthDayWeekday() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: self)
    }

    func formattedClock() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: self)
    }
}

public enum ReadyRoomTimePolicy {
    public static func displayedDayStart(
        for now: Date,
        calendar: Calendar = .readyRoomGregorian,
        carryPreviousDayUntilHour hour: Int = 3
    ) -> Date {
        let startOfToday = now.startOfDay(in: calendar)
        return calendar.component(.hour, from: now) < hour
            ? startOfToday.adding(days: -1, calendar: calendar)
            : startOfToday
    }
}
