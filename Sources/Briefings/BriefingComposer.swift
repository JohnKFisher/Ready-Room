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
        let sections = buildSections(request: request, newsSummary: newsSummary)
        let subject = "Daily Briefing for \(request.audience.displayName) — \(ReadyRoomFormatters.monthDayWeekday.string(from: request.date))"

        let preferredMode = request.preferredMode
        let actualMode = [openingLine.actualMode, newsSummary.actualMode].contains { $0 != preferredMode } ? openingLine.actualMode : preferredMode
        let trace = DecisionTrace(
            preferredGenerationMode: preferredMode,
            actualGenerationMode: actualMode,
            fallbackReason: openingLine.fallbackReason ?? newsSummary.fallbackReason
        )

        return BriefingArtifact(
            audience: request.audience,
            subject: subject,
            recipients: recipients,
            bodyHTML: renderHTML(
                request: request,
                openingLine: openingLine.text,
                newsSummary: newsSummary.text,
                sections: sections
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
            sections.append(makeSection(title: "Today", items: today, palette: request.personColorPalette, calendarPlaceholderLabel: request.calendarPlaceholderLabel))
        }

        let tomorrow = items(on: dayBuckets.tomorrow, from: relevant, calendar: calendar)
        if !tomorrow.isEmpty {
            sections.append(makeSection(title: "Tomorrow", items: tomorrow, palette: request.personColorPalette, calendarPlaceholderLabel: request.calendarPlaceholderLabel))
        }

        let upcoming = items(onAnyOf: dayBuckets.upcoming, from: relevant, calendar: calendar)
        if !upcoming.isEmpty {
            sections.append(makeSection(title: "Upcoming", items: upcoming, palette: request.personColorPalette, calendarPlaceholderLabel: request.calendarPlaceholderLabel))
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

    private func items(onAnyOf days: [Date], from items: [NormalizedItem], calendar: Calendar) -> [NormalizedItem] {
        let includedDays = Set(days)
        return items.filter { item in
            guard let startDate = item.startDate else {
                return false
            }
            return includedDays.contains(startDate.startOfDay(in: calendar))
        }
    }

    private func makeSection(
        title: String,
        items: [NormalizedItem],
        palette: PersonColorPaletteSettings,
        calendarPlaceholderLabel: String? = nil
    ) -> BriefingSection {
        let body = items.map { item -> String in
            let location = item.location.map { " (\($0))" } ?? ""
            let placeholderPrefix = item.sourceType == .calendar && calendarPlaceholderLabel != nil ? "[Placeholder] " : ""
            let content = [formattedItemPrefix(for: item), placeholderPrefix + item.title + location]
                .filter { !$0.isEmpty }
                .joined(separator: " — ")
            return briefingAccentMarkup(for: item, palette: palette) + escapeHTML(content)
        }
        .joined(separator: "<br/>")

        return BriefingSection(
            id: title.lowercased().replacingOccurrences(of: " ", with: "-"),
            title: title,
            body: body,
            items: items
        )
    }

    private func formattedItemPrefix(for item: NormalizedItem) -> String {
        guard let start = item.startDate else {
            return item.isAllDay ? "All day" : ""
        }

        if item.isAllDay {
            return "\(ReadyRoomFormatters.abbreviatedWeekdayMonthDay.string(from: start)) — All day"
        }

        return "\(ReadyRoomFormatters.abbreviatedWeekdayMonthDay.string(from: start)) at \(ReadyRoomFormatters.shortClock.string(from: start))"
    }

    private func renderHTML(request: BriefingRequest, openingLine: String, newsSummary: String, sections: [BriefingSection]) -> String {
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

        let fallbackDisclosure = request.preferredMode == .templated ? "" : """
        <p style="font-size: 12px; color: #6b7280; margin-top: 24px;">
            Preferred mode: \(request.preferredMode.rawValue). Actual mode used: \(sections.contains(where: { $0.title == "In The World" }) ? newsSummary.isEmpty ? request.preferredMode.rawValue : request.preferredMode.rawValue : request.preferredMode.rawValue).
        </p>
        """

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
        }.joined()
        return "<span style=\"display: inline-block; margin-right: 4px; white-space: nowrap;\">\(pills)</span>"
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
