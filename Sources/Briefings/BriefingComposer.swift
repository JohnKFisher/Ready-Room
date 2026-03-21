import Foundation
import ReadyRoomCore

public struct BriefingComposer: Sendable {
    public init() {}

    public func compose(
        request: BriefingRequest,
        recipients: [String],
        openingLine: GeneratedNarrative,
        newsSummary: GeneratedNarrative
    ) -> BriefingArtifact {
        let preferredMode = request.preferredMode
        let actualMode = resolvedActualMode(
            preferredMode: preferredMode,
            openingLine: openingLine,
            newsSummary: newsSummary
        )
        let fallbackReason = openingLine.fallbackReason ?? newsSummary.fallbackReason
        let sections = buildSections(request: request, newsSummary: newsSummary)
        let subject = "Daily Briefing for \(request.audience.displayName) — \(ReadyRoomFormatters.monthDayWeekday.string(from: request.date))"
        let trace = DecisionTrace(
            preferredGenerationMode: preferredMode,
            actualGenerationMode: actualMode,
            fallbackReason: fallbackReason
        )

        return BriefingArtifact(
            audience: request.audience,
            subject: subject,
            recipients: recipients,
            bodyHTML: renderHTML(
                request: request,
                openingLine: openingLine.text,
                sections: sections,
                preferredMode: preferredMode,
                actualMode: actualMode,
                fallbackReason: fallbackReason
            ),
            sections: sections,
            preferredMode: preferredMode,
            actualMode: actualMode,
            sourceSnapshotSummary: sourceSummary(request: request),
            trace: trace
        )
    }

    public func buildSections(request: BriefingRequest, newsSummary: GeneratedNarrative) -> [BriefingSection] {
        let calendar = Calendar.readyRoomGregorian
        let startOfToday = request.date.startOfDay(in: calendar)
        let dayBuckets = ReadyRoomDayBuckets(
            anchorDay: startOfToday,
            effectiveStartDay: startOfToday,
            calendar: calendar
        )

        let relevant = request.normalizedItems
            .filter { item in
                switch request.audience {
                case .john:
                    item.inclusion.johnBriefing
                case .amy:
                    item.inclusion.amyBriefing
                }
            }
            .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }

        var sections: [BriefingSection] = []

        let today = items(on: dayBuckets.today, from: relevant, calendar: calendar)
        if !today.isEmpty {
            sections.append(
                makeDatedSection(
                    id: "today",
                    label: "Today",
                    date: dayBuckets.today,
                    items: today,
                    palette: request.personColorPalette,
                    calendarPlaceholderLabel: request.calendarPlaceholderLabel
                )
            )
        }

        let tomorrow = items(on: dayBuckets.tomorrow, from: relevant, calendar: calendar)
        if !tomorrow.isEmpty {
            sections.append(
                makeDatedSection(
                    id: "tomorrow",
                    label: "Tomorrow",
                    date: dayBuckets.tomorrow,
                    items: tomorrow,
                    palette: request.personColorPalette,
                    calendarPlaceholderLabel: request.calendarPlaceholderLabel
                )
            )
        }

        let upcoming = items(onAnyOf: dayBuckets.upcoming, from: relevant, calendar: calendar)
        if !upcoming.isEmpty {
            sections.append(
                makeUpcomingSection(
                    days: dayBuckets.upcoming,
                    items: upcoming,
                    palette: request.personColorPalette,
                    calendarPlaceholderLabel: request.calendarPlaceholderLabel,
                    calendar: calendar
                )
            )
        }

        if !request.dueSoon.isEmpty {
            sections.append(makeSection(title: "Due Soon", items: request.dueSoon, palette: request.personColorPalette))
        }

        let changed = relevant.filter { $0.changeState != .unchanged }
        if !changed.isEmpty {
            sections.append(makeSection(title: "New or Changed", items: changed, palette: request.personColorPalette, calendarPlaceholderLabel: request.calendarPlaceholderLabel))
        }

        if !request.headlines.isEmpty {
            let body = request.newsPlaceholderLabel.map { placeholderLabel in
                placeholderNotice(label: placeholderLabel) + "<br/><br/>" + newsSummary.text
            } ?? newsSummary.text
            sections.append(
                BriefingSection(
                    id: "world",
                    title: "In The World",
                    body: body,
                    items: []
                )
            )
        }

        let additions = request.mediaItems.filter { $0.kind == .newAddition }
        if !additions.isEmpty {
            let body = additions.map { activity in
                activity.subtitle.map { "\(activity.title) — \($0)" } ?? activity.title
            }.joined(separator: "<br/>")
            let labeledBody = request.mediaPlaceholderLabel.map { placeholderLabel in
                placeholderNotice(label: placeholderLabel) + "<br/><br/>" + body
            } ?? body
            sections.append(
                BriefingSection(
                    id: "media",
                    title: "Media",
                    body: labeledBody,
                    items: []
                )
            )
        }

        return sections
    }

    private func items(on day: Date, from items: [NormalizedItem], calendar: Calendar) -> [NormalizedItem] {
        items.filter { item in
            guard let startDate = item.startDate else {
                return false
            }
            return startDate.startOfDay(in: calendar) == day
        }
    }

    private func resolvedActualMode(
        preferredMode: NarrativeGenerationMode,
        openingLine: GeneratedNarrative,
        newsSummary: GeneratedNarrative
    ) -> NarrativeGenerationMode {
        [openingLine.actualMode, newsSummary.actualMode]
            .first(where: { $0 != preferredMode }) ?? preferredMode
    }

    private func items(onAnyOf days: [Date], from items: [NormalizedItem], calendar: Calendar) -> [NormalizedItem] {
        let includedDays = Set(days)
        return items.filter { item in
            guard let startDate = item.startDate else {
                return false
            }
            return includedDays.contains(startDate.startOfDay(in: calendar))
        }
    }

    private func makeDatedSection(
        id: String,
        label: String,
        date: Date,
        items: [NormalizedItem],
        palette: PersonColorPaletteSettings,
        calendarPlaceholderLabel: String? = nil
    ) -> BriefingSection {
        BriefingSection(
            id: id,
            title: "\(label) - \(ReadyRoomFormatters.briefingSectionDate.string(from: date))",
            body: formattedItemLines(
                for: items,
                palette: palette,
                prefixStyle: .timeOnly,
                calendarPlaceholderLabel: calendarPlaceholderLabel
            ),
            items: items
        )
    }

    private func makeSection(
        title: String,
        items: [NormalizedItem],
        palette: PersonColorPaletteSettings,
        calendarPlaceholderLabel: String? = nil
    ) -> BriefingSection {
        return BriefingSection(
            id: title.lowercased().replacingOccurrences(of: " ", with: "-"),
            title: title,
            body: formattedItemLines(
                for: items,
                palette: palette,
                prefixStyle: .fullDate,
                calendarPlaceholderLabel: calendarPlaceholderLabel
            ),
            items: items
        )
    }

    private func makeUpcomingSection(
        days: [Date],
        items sectionItems: [NormalizedItem],
        palette: PersonColorPaletteSettings,
        calendarPlaceholderLabel: String? = nil,
        calendar: Calendar
    ) -> BriefingSection {
        let groups = days.compactMap { day -> String? in
            let dayItems = items(on: day, from: sectionItems, calendar: calendar)
            guard !dayItems.isEmpty else {
                return nil
            }

            let header = """
            <div style="font-size: 12px; font-weight: 700; color: #52606d; margin: 0 0 6px 0;">\(escapeHTML(ReadyRoomFormatters.briefingSectionDate.string(from: day)))</div>
            """
            let lines = formattedItemLines(
                for: dayItems,
                palette: palette,
                prefixStyle: .timeOnly,
                calendarPlaceholderLabel: calendarPlaceholderLabel
            )
            return header + "<div>\(lines)</div>"
        }

        return BriefingSection(
            id: "upcoming",
            title: "Upcoming",
            body: groups.joined(separator: "<br/><br/>"),
            items: sectionItems
        )
    }

    private func formattedItemLines(
        for items: [NormalizedItem],
        palette: PersonColorPaletteSettings,
        prefixStyle: BriefingItemPrefixStyle,
        calendarPlaceholderLabel: String? = nil
    ) -> String {
        items
            .map { formattedItemLine(for: $0, palette: palette, prefixStyle: prefixStyle, calendarPlaceholderLabel: calendarPlaceholderLabel) }
            .joined(separator: "<br/>")
    }

    private func formattedItemLine(
        for item: NormalizedItem,
        palette: PersonColorPaletteSettings,
        prefixStyle: BriefingItemPrefixStyle,
        calendarPlaceholderLabel: String? = nil
    ) -> String {
        let location = item.displayLocation.map { " (\($0))" } ?? ""
        let placeholderPrefix = item.sourceType == .calendar && calendarPlaceholderLabel != nil ? "[Placeholder] " : ""
        let content = [formattedItemPrefix(for: item, style: prefixStyle), placeholderPrefix + item.title + location]
            .filter { !$0.isEmpty }
            .joined(separator: " — ")
        return escapeHTML(content) + " " + briefingAccentMarkup(for: item, palette: palette)
    }

    private func formattedItemPrefix(for item: NormalizedItem, style: BriefingItemPrefixStyle) -> String {
        guard let start = item.startDate else {
            return item.isAllDay ? "All day" : ""
        }

        switch style {
        case .fullDate:
            if item.isAllDay {
                return "\(ReadyRoomFormatters.abbreviatedWeekdayMonthDay.string(from: start)) — All day"
            }
            return "\(ReadyRoomFormatters.abbreviatedWeekdayMonthDay.string(from: start)) at \(ReadyRoomFormatters.shortClock.string(from: start))"
        case .timeOnly:
            if item.isAllDay {
                return "All day"
            }
            return ReadyRoomFormatters.shortClock.string(from: start)
        }
    }

    private func renderHTML(
        request: BriefingRequest,
        openingLine: String,
        sections: [BriefingSection],
        preferredMode: NarrativeGenerationMode,
        actualMode: NarrativeGenerationMode,
        fallbackReason: String?
    ) -> String {
        let weather = request.weather.map {
            let weatherLine = "\($0.summary), \(Int($0.currentTemperatureF))F now, high \(Int($0.highF))/low \(Int($0.lowF))"
            return request.weatherPlaceholderLabel.map { "\(placeholderNotice(label: $0))<br/>\(weatherLine)" } ?? weatherLine
        } ?? "Weather unavailable"

        let sectionHTML = sections.map { section in
            """
            <section style="margin: 0 0 16px 0; padding: 14px; border: 1px solid #d6dbe1; border-radius: 12px; background: #f7f8fb;">
                <h2 style="font-size: 16px; margin: 0 0 8px 0;">\(section.title)</h2>
                <div style="font-size: 14px; line-height: 1.5;">\(section.body)</div>
            </section>
            """
        }.joined(separator: "\n")

        let fallbackDisclosure: String
        if preferredMode != actualMode {
            let reason = escapeHTML(fallbackReason ?? "Ready Room used deterministic templating for this briefing.")
            fallbackDisclosure = """
            <p style="font-size: 12px; color: #6b7280; margin-top: 24px;">
                Preferred mode: \(preferredMode.rawValue). Actual mode used: \(actualMode.rawValue). Reason: \(reason)
            </p>
            """
        } else {
            fallbackDisclosure = ""
        }

        return """
        <html>
        <body style="font-family: -apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif; margin: 24px; color: #1f2933;">
            <div style="max-width: 760px; margin: 0 auto;">
                <div style="margin-bottom: 16px; padding: 12px 14px; border: 1px solid #f5c778; border-radius: 12px; background: #fff4db; color: #7c4a03; font-size: 13px; font-weight: 600;">
                    Ready Room is in very, very early development. This email may contain placeholder data or incorrect classifications and should not be trusted or relied on.
                </div>
                <header style="margin-bottom: 24px;">
                    <p style="font-size: 14px; margin: 0 0 8px 0; color: #52606d;">\(escapeHTML(request.date.formattedMonthDayWeekday()))</p>
                    <h1 style="font-size: 22px; margin: 0 0 8px 0;">Good morning, \(escapeHTML(request.audience.displayName)).</h1>
                    <p style="font-size: 15px; margin: 0 0 8px 0;">\(weather)</p>
                    <p style="font-size: 15px; margin: 0;">\(escapeHTML(openingLine))</p>
                </header>
                \(sectionHTML)
                \(fallbackDisclosure)
            </div>
        </body>
        </html>
        """
    }

    private func briefingAccentMarkup(for item: NormalizedItem, palette: PersonColorPaletteSettings) -> String {
        let accent = ItemAudienceAccentResolver.resolve(for: item, palette: palette)
        let pills = accent.tokens.map { token in
            """
            <span style="display: inline-block; margin: 0 4px 4px 0; padding: 1px 7px; border-radius: 999px; border: 1px solid \(token.hex)44; background: \(token.hex)22; color: #253041; font-size: 11px; font-weight: 600;">\(escapeHTML(token.shortLabel))</span>
            """
        }.joined(separator: "<span style=\"font-size: 11px; color: #52606d; margin-right: 4px;\">/</span>")
        return "<span style=\"display: inline-block; margin-left: 6px; white-space: nowrap;\"><span style=\"font-size: 11px; color: #52606d; margin-right: 4px;\">[</span>\(pills)<span style=\"font-size: 11px; color: #52606d;\">]</span></span>"
    }

    private func sourceSummary(request: BriefingRequest) -> [String] {
        var summary: [String] = []
        summary.append("Items: \(request.normalizedItems.count)")
        summary.append("Due soon: \(request.dueSoon.count)")
        summary.append("News headlines: \(request.headlines.count)")
        summary.append("Media additions: \(request.mediaItems.filter { $0.kind == .newAddition }.count)")
        if let calendarPlaceholderLabel = request.calendarPlaceholderLabel {
            summary.append("Calendar placeholder: \(calendarPlaceholderLabel)")
        }
        if let weatherPlaceholderLabel = request.weatherPlaceholderLabel {
            summary.append("Weather placeholder: \(weatherPlaceholderLabel)")
        }
        if let newsPlaceholderLabel = request.newsPlaceholderLabel {
            summary.append("News placeholder: \(newsPlaceholderLabel)")
        }
        if let mediaPlaceholderLabel = request.mediaPlaceholderLabel {
            summary.append("Media placeholder: \(mediaPlaceholderLabel)")
        }
        return summary
    }

    private func placeholderNotice(label: String) -> String {
        "<strong>[Placeholder]</strong> \(escapeHTML(label))"
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private enum BriefingItemPrefixStyle {
    case fullDate
    case timeOnly
}
