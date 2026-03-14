import Foundation

public struct ReadyRoomRulesEngine: Sendable {
    public var configuration: ReadyRoomRulesConfiguration

    public init(configuration: ReadyRoomRulesConfiguration = ReadyRoomRulesConfiguration()) {
        self.configuration = configuration
    }

    public func inferCalendarRole(for title: String) -> CalendarRole {
        let lowered = title.lowercased()
        if lowered.contains("work") || lowered.contains("office") || lowered.contains("outlook") {
            return .work
        }
        if lowered.contains("family") || lowered.contains("home") || lowered.contains("shared") {
            return .sharedFamily
        }
        if lowered.contains("school") || lowered.contains("soccer") || lowered.contains("dance") || lowered.contains("kid") {
            return .kidRelated
        }
        return .inactiveUnclassified
    }

    public func normalizeCalendarEvents(
        _ events: [RawCalendarEvent],
        source: SourceDescriptor,
        configurations: [String: CalendarConfiguration],
        health: SourceHealthStatus,
        previousItems: [String: NormalizedItem] = [:]
    ) -> [NormalizedItem] {
        events.map { event in
            normalizeCalendarEvent(event, source: source, configuration: configurations[event.calendarIdentifier], health: health, previousItems: previousItems)
        }
        .sorted {
            ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture)
        }
    }

    public func dueSoonObligations(
        _ obligations: [ObligationRecord],
        source: SourceDescriptor,
        health: SourceHealthStatus,
        referenceDate: Date = .now,
        previousVisibleIDs: Set<String> = []
    ) -> [NormalizedItem] {
        obligations.compactMap { obligation in
            guard let nextOccurrence = nextOccurrence(for: obligation, after: referenceDate) else {
                return nil
            }
            let dueInDays = Calendar.readyRoomGregorian.dateComponents([.day], from: referenceDate.startOfDay(), to: nextOccurrence.startOfDay()).day ?? Int.max
            let earliestLead = max(7, obligation.reminderLeadDays.max() ?? 0)
            guard dueInDays <= earliestLead else {
                return nil
            }

            let visibleNow = dueInDays <= earliestLead
            let previouslyVisible = previousVisibleIDs.contains(obligation.id)
            let changeState: ChangeState = visibleNow && !previouslyVisible ? .enteredReminderWindow : .unchanged
            let owner = obligation.owner ?? .family
            let relevant: Set<PersonID> = owner == .family ? [.john, .amy, .family] : [owner]
            let trace = DecisionTrace(
                sourceFacts: ["Obligation schedule kind: \(obligation.schedule.kind.rawValue)"],
                appliedRules: [
                    DecisionTraceEntry(
                        ruleID: "obligation.reminder-window",
                        summary: "Obligation falls within visible reminder window",
                        detail: "\(obligation.title) is due in \(dueInDays) day(s)"
                    )
                ]
            )

            return NormalizedItem(
                id: "obligation:\(obligation.id)",
                source: source,
                sourceIdentifier: obligation.id,
                sourceType: .obligation,
                title: obligation.title,
                notes: obligation.notes,
                startDate: nextOccurrence,
                endDate: nextOccurrence,
                isAllDay: true,
                owner: owner == .family ? nil : owner,
                relevantPeople: relevant,
                calendarRole: .sharedFamily,
                lifeArea: .home,
                confidence: 0.98,
                inclusion: InclusionFlags(
                    dashboard: true,
                    johnBriefing: relevant.contains(.john),
                    amyBriefing: relevant.contains(.amy)
                ),
                changeState: changeState,
                sourceHealth: health,
                trace: trace,
                metadata: ["kind": obligation.schedule.kind.rawValue]
            )
        }
        .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
    }

    public func detectConflicts(in items: [NormalizedItem]) -> [ConflictMarker] {
        let sorted = items
            .filter { $0.startDate != nil && $0.endDate != nil }
            .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }

        var conflicts: [ConflictMarker] = []
        for index in sorted.indices {
            let first = sorted[index]
            guard shouldMarkConflict(for: first) else {
                continue
            }

            for other in sorted[(index + 1)...] {
                guard let firstEnd = first.endDate, let otherStart = other.startDate else {
                    continue
                }
                if otherStart >= firstEnd {
                    break
                }
                guard shouldMarkConflict(for: other) else {
                    continue
                }
                conflicts.append(
                    ConflictMarker(
                        itemIDs: [first.id, other.id],
                        title: "Overlap: \(first.title) and \(other.title)"
                    )
                )
            }
        }
        return conflicts
    }

    public func workLocation(for person: PersonID, on date: Date, calendar: Calendar = .readyRoomGregorian) -> WorkLocation {
        let weekday = calendar.component(.weekday, from: date)
        for rule in configuration.workLocationRules where rule.person == person && rule.weekdays.contains(weekday) {
            return rule.location
        }
        return .office
    }

    public func nextOccurrence(for obligation: ObligationRecord, after referenceDate: Date) -> Date? {
        let calendar = Calendar.readyRoomGregorian
        switch obligation.schedule.kind {
        case .oneTime:
            return obligation.schedule.dueDate
        case .weekly:
            let weekdays = obligation.schedule.weekdays.isEmpty ? [calendar.component(.weekday, from: referenceDate)] : obligation.schedule.weekdays
            for dayOffset in 0...28 {
                guard let candidate = calendar.date(byAdding: .day, value: dayOffset, to: referenceDate.startOfDay()) else {
                    continue
                }
                if weekdays.contains(calendar.component(.weekday, from: candidate)) {
                    return candidate
                }
            }
            return nil
        case .monthly:
            guard let day = obligation.schedule.dayOfMonth else { return nil }
            for monthOffset in 0...12 {
                guard
                    let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: referenceDate),
                    let range = calendar.range(of: .day, in: .month, for: monthDate)
                else {
                    continue
                }
                let clampedDay = min(day, range.count)
                var components = calendar.dateComponents([.year, .month], from: monthDate)
                components.day = clampedDay
                if let candidate = calendar.date(from: components), candidate >= referenceDate.startOfDay() {
                    return candidate
                }
            }
            return nil
        case .yearly:
            guard let month = obligation.schedule.monthOfYear, let day = obligation.schedule.dayOfMonth else {
                return nil
            }
            for yearOffset in 0...3 {
                var components = calendar.dateComponents([.year], from: referenceDate)
                components.year = (components.year ?? 0) + yearOffset
                components.month = month
                components.day = day
                if let candidate = calendar.date(from: components), candidate >= referenceDate.startOfDay() {
                    return candidate
                }
            }
            return nil
        case .custom:
            return obligation.schedule.dueDate
        }
    }

    private func normalizeCalendarEvent(
        _ event: RawCalendarEvent,
        source: SourceDescriptor,
        configuration: CalendarConfiguration?,
        health: SourceHealthStatus,
        previousItems: [String: NormalizedItem]
    ) -> NormalizedItem {
        let role = configuration?.role ?? inferCalendarRole(for: event.calendarTitle)
        let markers = detectedPeople(in: [event.title, event.notes].compactMap { $0 }.joined(separator: " "))
        let owner = resolveOwner(event: event, configuration: configuration, markers: markers, role: role)
        let relevance = resolveRelevantPeople(event: event, markers: markers, owner: owner, role: role)
        let inclusion = InclusionFlags(
            dashboard: configuration?.includeOnDashboard ?? (role != .inactiveUnclassified),
            johnBriefing: (configuration?.includeInJohnBriefing ?? true) && relevance.contains(.john),
            amyBriefing: (configuration?.includeInAmyBriefing ?? true) && relevance.contains(.amy)
        )

        let trace = DecisionTrace(
            sourceFacts: [
                "Calendar: \(event.calendarTitle)",
                "Markers: \(markers.map(\.rawValue).sorted().joined(separator: ", "))"
            ],
            appliedRules: traceEntries(for: event, role: role, owner: owner, markers: markers, relevance: relevance)
        )

        let previous = previousItems["calendar:\(event.id)"]
        let changeState = resolveChangeState(for: event, previous: previous)
        let confidence = configuration?.role != nil ? 0.95 : markers.isEmpty ? 0.72 : 0.84

        return NormalizedItem(
            id: "calendar:\(event.id)",
            source: source,
            sourceIdentifier: event.id,
            sourceType: .calendar,
            title: event.title,
            notes: event.notes,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            location: event.location,
            owner: owner,
            relevantPeople: relevance,
            calendarRole: role,
            lifeArea: resolveLifeArea(for: role),
            confidence: confidence,
            inclusion: inclusion,
            changeState: changeState,
            sourceHealth: health,
            trace: trace,
            metadata: [
                "calendarTitle": event.calendarTitle,
                "calendarIdentifier": event.calendarIdentifier
            ]
        )
    }

    private func resolveChangeState(for event: RawCalendarEvent, previous: NormalizedItem?) -> ChangeState {
        if event.isCancelled {
            return .cancelled
        }
        guard let previous else {
            return .new
        }
        let titleChanged = previous.title != event.title
        let startChanged = previous.startDate != event.startDate
        let endChanged = previous.endDate != event.endDate
        return (titleChanged || startChanged || endChanged) ? .changed : .unchanged
    }

    private func resolveOwner(
        event: RawCalendarEvent,
        configuration: CalendarConfiguration?,
        markers: Set<PersonID>,
        role: CalendarRole
    ) -> PersonID? {
        if let explicit = configuration?.owner {
            return explicit
        }
        if let override = configuration?.keywordOwnerOverrides.first(where: { key, _ in event.title.localizedCaseInsensitiveContains(key) || (event.notes?.localizedCaseInsensitiveContains(key) ?? false) })?.value {
            return override
        }
        if markers.contains(.john) { return .john }
        if markers.contains(.amy) { return .amy }
        if role == .work { return event.sourceOwnerHint }
        return event.sourceOwnerHint
    }

    private func resolveRelevantPeople(
        event: RawCalendarEvent,
        markers: Set<PersonID>,
        owner: PersonID?,
        role: CalendarRole
    ) -> Set<PersonID> {
        if markers.contains(.ellie) || markers.contains(.mia) {
            return Set([PersonID.john, .amy, .ellie, .mia]).intersection(markers.union(Set([.john, .amy])))
        }

        switch role {
        case .work:
            if let owner {
                return [owner]
            }
            return markers.intersection([.john, .amy])
        case .sharedFamily, .kidRelated:
            if markers.contains(.john) && !markers.contains(.amy) {
                return familyRelevant(event) ? [.john, .amy] : [.john]
            }
            if markers.contains(.amy) && !markers.contains(.john) {
                return familyRelevant(event) ? [.john, .amy] : [.amy]
            }
            return Set([PersonID.john, .amy]).union(markers)
        case .other:
            return owner.map { Set([$0]) } ?? Set([.john, .amy])
        case .inactiveUnclassified:
            return markers.isEmpty ? [] : markers
        }
    }

    private func resolveLifeArea(for role: CalendarRole) -> LifeArea {
        switch role {
        case .work:
            return .work
        case .sharedFamily, .kidRelated:
            return .home
        case .other:
            return .mixed
        case .inactiveUnclassified:
            return .home
        }
    }

    private func traceEntries(
        for event: RawCalendarEvent,
        role: CalendarRole,
        owner: PersonID?,
        markers: Set<PersonID>,
        relevance: Set<PersonID>
    ) -> [DecisionTraceEntry] {
        var entries = [
            DecisionTraceEntry(
                ruleID: "calendar.role",
                summary: "Calendar role resolved",
                detail: "\(event.calendarTitle) resolved as \(role.rawValue)"
            )
        ]

        if let owner {
            entries.append(
                DecisionTraceEntry(
                    ruleID: "calendar.owner",
                    summary: "Owner inferred",
                    detail: "Owner resolved as \(owner.displayName)"
                )
            )
        }

        if !markers.isEmpty {
            entries.append(
                DecisionTraceEntry(
                    ruleID: "title.markers",
                    summary: "Person markers found",
                    detail: markers.map(\.displayName).sorted().joined(separator: ", ")
                )
            )
        }

        entries.append(
            DecisionTraceEntry(
                ruleID: "relevance.apply",
                summary: "Relevant people resolved",
                detail: relevance.map(\.displayName).sorted().joined(separator: ", ")
            )
        )
        return entries
    }

    private func familyRelevant(_ event: RawCalendarEvent) -> Bool {
        let text = [event.title, event.notes].compactMap { $0 }.joined(separator: " ").lowercased()
        return text.contains("family") || text.contains("pickup") || text.contains("dropoff") || text.contains("school")
    }

    private func detectedPeople(in text: String) -> Set<PersonID> {
        let lowered = text.lowercased()
        var detected: Set<PersonID> = []
        if lowered.contains("john") { detected.insert(.john) }
        if lowered.contains("amy") { detected.insert(.amy) }
        if lowered.contains("ellie") { detected.insert(.ellie) }
        if lowered.contains("mia") { detected.insert(.mia) }
        return detected
    }

    private func shouldMarkConflict(for item: NormalizedItem) -> Bool {
        guard item.sourceType == .calendar else {
            return false
        }
        if item.calendarRole == .kidRelated || item.calendarRole == .sharedFamily {
            return true
        }
        let relevantAdults = item.relevantPeople.intersection([.john, .amy])
        return item.lifeArea != .work && !relevantAdults.isEmpty
    }
}
