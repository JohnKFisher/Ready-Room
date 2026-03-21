import Foundation

struct RefreshComponents: OptionSet, Sendable {
    let rawValue: Int

    static let calendar = RefreshComponents(rawValue: 1 << 0)
    static let obligations = RefreshComponents(rawValue: 1 << 1)
    static let weather = RefreshComponents(rawValue: 1 << 2)
    static let news = RefreshComponents(rawValue: 1 << 3)
    static let media = RefreshComponents(rawValue: 1 << 4)

    static let timelineRelated: RefreshComponents = [.calendar, .obligations]
    static let newsAndWeather: RefreshComponents = [.news, .weather]
    static let allSources: RefreshComponents = [.calendar, .obligations, .weather, .news, .media]
}

struct PeriodicRefreshPlanner: Sendable {
    var calendarAndObligationsInterval: TimeInterval = 30 * 60
    var newsAndWeatherInterval: TimeInterval = 60 * 60

    func dueComponents(
        now: Date,
        lastCalendarAndObligationsRefreshAt: Date?,
        lastNewsAndWeatherRefreshAt: Date?
    ) -> RefreshComponents {
        var due: RefreshComponents = []
        if shouldRefresh(now: now, lastRefreshAt: lastCalendarAndObligationsRefreshAt, interval: calendarAndObligationsInterval) {
            due.formUnion(.timelineRelated)
        }
        if shouldRefresh(now: now, lastRefreshAt: lastNewsAndWeatherRefreshAt, interval: newsAndWeatherInterval) {
            due.formUnion(.newsAndWeather)
        }
        return due
    }

    private func shouldRefresh(now: Date, lastRefreshAt: Date?, interval: TimeInterval) -> Bool {
        guard let lastRefreshAt else {
            return true
        }
        return now.timeIntervalSince(lastRefreshAt) >= interval
    }
}

struct RefreshRequestQueue: Sendable {
    private(set) var pending: RefreshComponents = []

    var hasPending: Bool {
        pending.isEmpty == false
    }

    mutating func enqueue(_ components: RefreshComponents) {
        pending.formUnion(components)
    }

    mutating func drain() -> RefreshComponents? {
        guard pending.isEmpty == false else {
            return nil
        }
        let current = pending
        pending = []
        return current
    }
}
