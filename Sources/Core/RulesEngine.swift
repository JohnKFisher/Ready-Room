import Foundation

public struct ReadyRoomRulesEngine: Sendable {
    public var configuration: ReadyRoomRulesConfiguration

    private struct OwnerDecision {
        let owner: PersonID
        let traceEntry: DecisionTraceEntry
    }

    private struct AudienceDecision {
        let audiences: Set<BriefingAudience>
        let traceEntry: DecisionTraceEntry
    }

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
            normalizeCalendarEvent(
                event,
                source: source,
                configuration: configurations[event.calendarIdentifier],
                health: health,
                previousItems: previousItems
            )
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
        let calendar = Calendar.readyRoomGregorian
        let visibleDayStart = ReadyRoomTimePolicy.displayedDayStart(for: referenceDate, calendar: calendar)

        let items: [NormalizedItem] = obligations.compactMap { obligation -> NormalizedItem? in
            guard let nextOccurrence = nextOccurrence(for: obligation, after: visibleDayStart) else {
                return nil
            }
            let dueInDays = calendar.dateComponents([.day], from: visibleDayStart, to: nextOccurrence.startOfDay(in: calendar)).day ?? Int.max
            let earliestLead = max(7, obligation.reminderLeadDays.max() ?? 0)
            guard dueInDays <= earliestLead else {
                return nil
            }

            let visibleNow = dueInDays <= earliestLead
            let previouslyVisible = previousVisibleIDs.contains(obligation.id)
            let changeState: ChangeState = visibleNow && !previouslyVisible ? .enteredReminderWindow : .unchanged
            let owner = obligation.owner ?? .family
            let relevantAudiences = owner.defaultRelevantAudiences
            let trace = DecisionTrace(
                sourceFacts: ["Obligation schedule kind: \(obligation.schedule.kind.rawValue)"],
                appliedRules: [
                    DecisionTraceEntry(
                        ruleID: "obligation.owner",
                        summary: "Owner resolved",
                        detail: "Obligation owner resolved as \(owner.displayName)"
                    ),
                    DecisionTraceEntry(
                        ruleID: "obligation.relevance",
                        summary: "Briefing relevance resolved",
                        detail: "Relevant to \(audienceSummary(relevantAudiences))."
                    ),
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
                owner: owner,
                relevantAudiences: relevantAudiences,
                calendarRole: .sharedFamily,
                lifeArea: .home,
                confidence: 0.98,
                inclusion: InclusionFlags(
                    dashboard: true,
                    johnBriefing: relevantAudiences.contains(.john),
                    amyBriefing: relevantAudiences.contains(.amy)
                ),
                changeState: changeState,
                sourceHealth: health,
                trace: trace,
                metadata: ["kind": obligation.schedule.kind.rawValue]
            )
        }
        return items.sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
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
            guard let dueDate = obligation.schedule.dueDate, dueDate.startOfDay(in: calendar) >= referenceDate.startOfDay(in: calendar) else {
                return nil
            }
            return dueDate
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
            guard let dueDate = obligation.schedule.dueDate, dueDate.startOfDay(in: calendar) >= referenceDate.startOfDay(in: calendar) else {
                return nil
            }
            return dueDate
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
        let ownerDecision = resolveOwner(event: event, configuration: configuration, markers: markers, role: role)
        let audienceDecision = resolveRelevantAudiences(
            event: event,
            configuration: configuration,
            markers: markers,
            owner: ownerDecision.owner,
            role: role
        )
        let inclusion = InclusionFlags(
            dashboard: configuration?.includeOnDashboard ?? (role != .inactiveUnclassified),
            johnBriefing: audienceDecision.audiences.contains(.john),
            amyBriefing: audienceDecision.audiences.contains(.amy)
        )

        let markerSummary = markers.isEmpty ? "none" : markers.map(\.displayName).sorted().joined(separator: ", ")
        let trace = DecisionTrace(
            sourceFacts: [
                "Calendar: \(event.calendarTitle)",
                "Detected people: \(markerSummary)",
                "Calendar defaults: \(configuration.map(defaultSummary(for:)) ?? "inferred")"
            ],
            appliedRules: traceEntries(
                for: event,
                role: role,
                markers: markers,
                ownerDecision: ownerDecision,
                audienceDecision: audienceDecision
            )
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
            owner: ownerDecision.owner,
            relevantAudiences: audienceDecision.audiences,
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
    ) -> OwnerDecision {
        let kids = kidMarkers(in: markers)
        let adults = adultMarkers(in: markers)

        if kids.count > 1 {
            return OwnerDecision(
                owner: .family,
                traceEntry: DecisionTraceEntry(
                    ruleID: "calendar.owner.multi-kid",
                    summary: "Owner resolved from multiple kid markers",
                    detail: "Multiple kid names appear in the event text, so owner resolves to Family."
                )
            )
        }

        if let kid = kids.first {
            return OwnerDecision(
                owner: kid,
                traceEntry: DecisionTraceEntry(
                    ruleID: "calendar.owner.kid",
                    summary: "Owner resolved from kid marker",
                    detail: "\(kid.displayName) appears in the event text, so owner resolves to \(kid.displayName)."
                )
            )
        }

        if adults.count == 2 {
            return OwnerDecision(
                owner: .family,
                traceEntry: DecisionTraceEntry(
                    ruleID: "calendar.owner.shared-adult",
                    summary: "Owner resolved as shared adult item",
                    detail: "Both Amy and John appear in the event text, so owner resolves to Family."
                )
            )
        }

        if let adult = adults.first {
            return OwnerDecision(
                owner: adult.person,
                traceEntry: DecisionTraceEntry(
                    ruleID: "calendar.owner.adult",
                    summary: "Owner resolved from adult marker",
                    detail: "\(adult.displayName) appears in the event text, so owner resolves to \(adult.displayName)."
                )
            )
        }

        if let override = matchedKeywordOwnerOverride(for: event, configuration: configuration) {
            return OwnerDecision(
                owner: override.owner,
                traceEntry: DecisionTraceEntry(
                    ruleID: "calendar.owner.keyword-override",
                    summary: "Owner resolved from keyword rule",
                    detail: "Matched keyword '\(override.keyword)' and resolved owner to \(override.owner.displayName)."
                )
            )
        }

        if familyRelevant(event) && role != .work {
            return OwnerDecision(
                owner: .family,
                traceEntry: DecisionTraceEntry(
                    ruleID: "calendar.owner.family-ops",
                    summary: "Owner resolved as family logistics",
                    detail: "The event looks like shared family logistics, so owner resolves to Family."
                )
            )
        }

        if let explicit = configuration?.owner {
            return OwnerDecision(
                owner: explicit,
                traceEntry: DecisionTraceEntry(
                    ruleID: "calendar.owner.calendar-default",
                    summary: "Owner resolved from calendar default",
                    detail: "No stronger event clue was found, so owner uses the calendar default \(explicit.displayName)."
                )
            )
        }

        if let sourceOwnerHint = event.sourceOwnerHint {
            return OwnerDecision(
                owner: sourceOwnerHint,
                traceEntry: DecisionTraceEntry(
                    ruleID: "calendar.owner.source-hint",
                    summary: "Owner resolved from source hint",
                    detail: "No stronger event clue was found, so owner uses the source hint \(sourceOwnerHint.displayName)."
                )
            )
        }

        return OwnerDecision(
            owner: .family,
            traceEntry: DecisionTraceEntry(
                ruleID: "calendar.owner.family-fallback",
                summary: "Owner fell back to Family",
                detail: "No stronger owner clue was found, so owner falls back to Family."
            )
        )
    }

    private func resolveRelevantAudiences(
        event: RawCalendarEvent,
        configuration: CalendarConfiguration?,
        markers: Set<PersonID>,
        owner: PersonID,
        role: CalendarRole
    ) -> AudienceDecision {
        let explicitAdults = adultAudienceSet(from: markers)

        if owner == .family {
            return AudienceDecision(
                audiences: Set(BriefingAudience.allCases),
                traceEntry: DecisionTraceEntry(
                    ruleID: "calendar.relevance.owner-family",
                    summary: "Relevant adults resolved from shared owner",
                    detail: "Family-owned events are relevant to both Amy and John."
                )
            )
        }

        if owner == .ellie || owner == .mia {
            return AudienceDecision(
                audiences: Set(BriefingAudience.allCases),
                traceEntry: DecisionTraceEntry(
                    ruleID: "calendar.relevance.owner-kid",
                    summary: "Relevant adults resolved from kid owner",
                    detail: "\(owner.displayName)-owned events are relevant to both Amy and John."
                )
            )
        }

        if explicitAdults.count == 2 {
            return AudienceDecision(
                audiences: explicitAdults,
                traceEntry: DecisionTraceEntry(
                    ruleID: "calendar.relevance.both-adults",
                    summary: "Relevant adults resolved from shared-adult clues",
                    detail: "Both Amy and John appear in the event text, so the item is relevant to both briefings."
                )
            )
        }

        if workStatusRelevantToBothAdults(event) {
            return AudienceDecision(
                audiences: Set(BriefingAudience.allCases),
                traceEntry: DecisionTraceEntry(
                    ruleID: "calendar.relevance.presence-status",
                    summary: "Relevant adults resolved from work status",
                    detail: "Explicit home, office, or PTO work status makes this relevant to both Amy and John."
                )
            )
        }

        if familyRelevant(event) && role != .work {
            return AudienceDecision(
                audiences: Set(BriefingAudience.allCases),
                traceEntry: DecisionTraceEntry(
                    ruleID: "calendar.relevance.family-ops",
                    summary: "Relevant adults resolved from family logistics",
                    detail: "This event looks like family logistics, so it is relevant to both Amy and John."
                )
            )
        }

        if explicitAdults.count == 1 {
            return AudienceDecision(
                audiences: explicitAdults,
                traceEntry: DecisionTraceEntry(
                    ruleID: "calendar.relevance.explicit-adult",
                    summary: "Relevant adults resolved from explicit adult clue",
                    detail: "A single adult is named in the event text, so briefing relevance stays with that adult."
                )
            )
        }

        if let configuration {
            return AudienceDecision(
                audiences: configuration.defaultRelevantAudiences,
                traceEntry: DecisionTraceEntry(
                    ruleID: "calendar.relevance.calendar-default",
                    summary: "Relevant adults resolved from calendar defaults",
                    detail: "No stronger event clue was found, so briefing relevance uses the calendar defaults \(audienceSummary(configuration.defaultRelevantAudiences))."
                )
            )
        }

        let fallbackAudiences = heuristicRelevantAudiences(for: owner, role: role)
        return AudienceDecision(
            audiences: fallbackAudiences,
            traceEntry: DecisionTraceEntry(
                ruleID: "calendar.relevance.heuristic",
                summary: "Relevant adults resolved from inferred defaults",
                detail: "No stronger event clue was found, so briefing relevance falls back to \(audienceSummary(fallbackAudiences))."
            )
        )
    }

    private func heuristicRelevantAudiences(for owner: PersonID, role: CalendarRole) -> Set<BriefingAudience> {
        switch role {
        case .work:
            guard let audience = owner.briefingAudience else {
                return []
            }
            return [audience]
        case .sharedFamily, .kidRelated:
            return Set(BriefingAudience.allCases)
        case .other, .inactiveUnclassified:
            return owner.defaultRelevantAudiences
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
        markers: Set<PersonID>,
        ownerDecision: OwnerDecision,
        audienceDecision: AudienceDecision
    ) -> [DecisionTraceEntry] {
        var entries = [
            DecisionTraceEntry(
                ruleID: "calendar.role",
                summary: "Calendar role resolved",
                detail: "\(event.calendarTitle) resolved as \(role.rawValue)"
            ),
            ownerDecision.traceEntry
        ]

        if !markers.isEmpty {
            entries.append(
                DecisionTraceEntry(
                    ruleID: "title.markers",
                    summary: "Person markers found",
                    detail: markers.map(\.displayName).sorted().joined(separator: ", ")
                )
            )
        }

        entries.append(audienceDecision.traceEntry)
        return entries
    }

    private func familyRelevant(_ event: RawCalendarEvent) -> Bool {
        let text = [event.title, event.notes].compactMap { $0 }.joined(separator: " ").lowercased()
        let keywords = [
            "family",
            "pickup",
            "pick-up",
            "dropoff",
            "drop-off",
            "school",
            "soccer",
            "dance",
            "kid",
            "kids",
            "daycare",
            "camp",
            "recital",
            "practice",
            "parent teacher",
            "parent-teacher"
        ]
        return keywords.contains(where: text.contains)
    }

    private func workStatusRelevantToBothAdults(_ event: RawCalendarEvent) -> Bool {
        let text = [event.title, event.notes].compactMap { $0 }.joined(separator: " ").lowercased()
        let phrases = [
            "work from home",
            "wfh",
            "at home",
            "home today",
            "home office",
            "in office",
            "in the office",
            "office today",
            "back in office",
            "onsite",
            "pto",
            "paid time off",
            "vacation",
            "out of office"
        ]
        return phrases.contains(where: text.contains)
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

    private func adultMarkers(in markers: Set<PersonID>) -> [BriefingAudience] {
        BriefingAudience.allCases.filter { markers.contains($0.person) }
    }

    private func kidMarkers(in markers: Set<PersonID>) -> [PersonID] {
        [.ellie, .mia].filter { markers.contains($0) }
    }

    private func adultAudienceSet(from markers: Set<PersonID>) -> Set<BriefingAudience> {
        Set(adultMarkers(in: markers))
    }

    private func matchedKeywordOwnerOverride(
        for event: RawCalendarEvent,
        configuration: CalendarConfiguration?
    ) -> (keyword: String, owner: PersonID)? {
        guard let overrides = configuration?.keywordOwnerOverrides else {
            return nil
        }
        return overrides.first { pair in
            let key = pair.key
            return event.title.localizedCaseInsensitiveContains(key) ||
            (event.notes?.localizedCaseInsensitiveContains(key) ?? false)
        }.map { pair in
            (keyword: pair.key, owner: pair.value)
        }
    }

    private func defaultSummary(for configuration: CalendarConfiguration) -> String {
        let roleSummary = configuration.role?.rawValue ?? "inferred role"
        let ownerSummary = configuration.owner?.displayName ?? "automatic owner"
        return "\(roleSummary), \(ownerSummary), \(audienceSummary(configuration.defaultRelevantAudiences))"
    }

    private static func audienceSummary(_ audiences: Set<BriefingAudience>) -> String {
        if audiences.isEmpty {
            return "no briefings"
        }
        return BriefingAudience.allCases
            .filter { audiences.contains($0) }
            .map(\.displayName)
            .joined(separator: ", ")
    }

    private func audienceSummary(_ audiences: Set<BriefingAudience>) -> String {
        Self.audienceSummary(audiences)
    }

    private func shouldMarkConflict(for item: NormalizedItem) -> Bool {
        guard item.sourceType == .calendar else {
            return false
        }
        if item.calendarRole == .kidRelated || item.calendarRole == .sharedFamily {
            return true
        }
        return item.lifeArea != .work && !item.relevantAudiences.isEmpty
    }
}
