import EventKit
import Foundation
import ReadyRoomCore

public actor EventKitCalendarConnector: SourceConnector {
    public let source = SourceDescriptor(id: "eventkit", displayName: "Calendars", type: .calendar)

    private let store = EKEventStore()
    private let horizonDays: Int

    public init(horizonDays: Int = 7) {
        self.horizonDays = horizonDays
    }

    public static func authorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    public func requestAccess() async throws -> Bool {
        try await requestAccessIfNeeded()
    }

    public func refresh() async throws -> SourceSnapshot {
        guard Self.authorizationStatus().readyRoomAllowsEventAccess else {
            return SourceSnapshot(
                source: source,
                health: SourceHealth(status: Self.authorizationStatus().readyRoomSourceHealthStatus, message: Self.authorizationStatus().readyRoomStatusMessage),
                calendarEvents: []
            )
        }

        let referenceDate = Date()
        let start = fetchStartDate(for: referenceDate)
        let end = start.adding(days: horizonDays + 1)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .map { event in
                RawCalendarEvent(
                    id: stableEventIdentifier(for: event),
                    calendarIdentifier: event.calendar.calendarIdentifier,
                    calendarTitle: event.calendar.title,
                    title: event.title,
                    notes: event.notes,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    location: event.location,
                    sourceOwnerHint: nil,
                    isCancelled: event.status == .canceled
                )
            }

        return SourceSnapshot(
            source: source,
            fetchedAt: .now,
            lastGoodFetchAt: .now,
            health: SourceHealth(status: .healthy, lastSuccessAt: .now, freshnessBudget: 600),
            calendarEvents: events
        )
    }

    private func requestAccessIfNeeded() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            if #available(macOS 14.0, *) {
                store.requestFullAccessToEvents { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                store.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    private func stableEventIdentifier(for event: EKEvent) -> String {
        let calendar = Calendar.readyRoomGregorian
        let dayAnchor = calendar.startOfDay(for: event.startDate)
        let dayToken = Int(dayAnchor.timeIntervalSince1970)
        let base = event.eventIdentifier ?? event.calendarItemIdentifier
        return "\(event.calendar.calendarIdentifier)|\(base)|\(dayToken)"
    }

    private func fetchStartDate(for referenceDate: Date) -> Date {
        let calendar = Calendar.readyRoomGregorian
        let startOfToday = referenceDate.startOfDay(in: calendar)
        let hour = calendar.component(.hour, from: referenceDate)
        return hour < 3 ? startOfToday.adding(days: -1, calendar: calendar) : startOfToday
    }
}

private extension EKAuthorizationStatus {
    var readyRoomAllowsEventAccess: Bool {
        switch self {
        case .authorized, .fullAccess:
            return true
        case .notDetermined, .restricted, .denied, .writeOnly:
            return false
        @unknown default:
            return false
        }
    }

    var readyRoomSourceHealthStatus: SourceHealthStatus {
        switch self {
        case .notDetermined:
            return .unconfigured
        case .restricted, .denied, .writeOnly:
            return .unauthorized
        case .authorized, .fullAccess:
            return .healthy
        @unknown default:
            return .unavailable
        }
    }

    var readyRoomStatusMessage: String {
        switch self {
        case .notDetermined:
            return "Calendar access has not been enabled in Ready Room settings."
        case .restricted:
            return "Calendar access is restricted on this Mac."
        case .denied:
            return "Calendar permission has not been granted."
        case .writeOnly:
            return "Ready Room needs full calendar access to read events."
        case .authorized, .fullAccess:
            return "Calendar access is available."
        @unknown default:
            return "Calendar permission status is unknown."
        }
    }
}
