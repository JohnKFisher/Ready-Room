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

public enum ReadyRoomDayBucket: String, Sendable, Codable, Hashable {
    case carryover
    case today
    case tomorrow
    case upcoming
}

public struct ReadyRoomDayBuckets: Sendable, Equatable {
    public let anchorDay: Date
    public let effectiveStartDay: Date
    public let visibleDays: [Date]
    public let carryoverDays: [Date]
    public let today: Date
    public let tomorrow: Date
    public let upcoming: [Date]

    public init(
        anchorDay: Date,
        effectiveStartDay: Date,
        totalVisibleDays: Int = 5,
        calendar: Calendar = .readyRoomGregorian
    ) {
        let normalizedAnchorDay = anchorDay.startOfDay(in: calendar)
        let normalizedStartDay = min(
            effectiveStartDay.startOfDay(in: calendar),
            normalizedAnchorDay
        )
        let visibleDayCount = max(totalVisibleDays, 1)

        var resolvedVisibleDays: [Date] = []
        resolvedVisibleDays.reserveCapacity(visibleDayCount)

        var cursor = normalizedStartDay
        while resolvedVisibleDays.count < visibleDayCount {
            resolvedVisibleDays.append(cursor)
            cursor = cursor.adding(days: 1, calendar: calendar)
        }

        let normalizedTomorrow = normalizedAnchorDay.adding(days: 1, calendar: calendar)

        self.anchorDay = normalizedAnchorDay
        self.effectiveStartDay = normalizedStartDay
        self.visibleDays = resolvedVisibleDays
        self.carryoverDays = resolvedVisibleDays.filter { $0 < normalizedAnchorDay }
        self.today = normalizedAnchorDay
        self.tomorrow = normalizedTomorrow
        self.upcoming = resolvedVisibleDays.filter { $0 > normalizedTomorrow }
    }

    public var visibleEndDay: Date {
        visibleDays.last ?? today
    }

    public func contains(_ day: Date, calendar: Calendar = .readyRoomGregorian) -> Bool {
        let normalizedDay = day.startOfDay(in: calendar)
        return visibleDays.contains(normalizedDay)
    }

    public func bucket(for day: Date, calendar: Calendar = .readyRoomGregorian) -> ReadyRoomDayBucket? {
        let normalizedDay = day.startOfDay(in: calendar)
        guard contains(normalizedDay, calendar: calendar) else {
            return nil
        }
        if normalizedDay < today {
            return .carryover
        }
        if normalizedDay == today {
            return .today
        }
        if normalizedDay == tomorrow {
            return .tomorrow
        }
        return .upcoming
    }
}
