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
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        let subject = "Daily Briefing for \(request.audience.displayName) — \(formatter.string(from: request.date))"

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
        let noon = calendar.date(byAdding: .hour, value: 12, to: startOfToday) ?? request.date
        let evening = calendar.date(byAdding: .hour, value: 17, to: startOfToday) ?? request.date
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? request.date
        let weekOut = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? request.date

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

        let thisMorning = relevant.filter {
            guard let start = $0.startDate else { return false }
            return start >= request.date && start < noon
        }
        if !thisMorning.isEmpty {
            sections.append(makeSection(title: "This Morning", items: thisMorning))
        }

        let today = relevant.filter {
            guard let start = $0.startDate else { return false }
            return start >= startOfToday && start < evening
        }
        if !today.isEmpty {
            sections.append(makeSection(title: "Today", items: today))
        }

        let tonight = relevant.filter {
            guard let start = $0.startDate else { return false }
            return start >= evening && start < tomorrow
        }
        if !tonight.isEmpty {
            sections.append(makeSection(title: "Tonight", items: tonight))
        }

        let comingUp = relevant.filter {
            guard let start = $0.startDate else { return false }
            return start >= tomorrow && start < weekOut
        }
        if !comingUp.isEmpty {
            sections.append(makeSection(title: "Coming Up", items: comingUp))
        }

        if !request.dueSoon.isEmpty {
            sections.append(makeSection(title: "Due Soon", items: request.dueSoon))
        }

        let changed = relevant.filter { $0.changeState != .unchanged }
        if !changed.isEmpty {
            sections.append(makeSection(title: "New or Changed", items: changed))
        }

        if !request.headlines.isEmpty {
            sections.append(
                BriefingSection(
                    id: "world",
                    title: "In The World",
                    body: newsSummary.text,
                    items: []
                )
            )
        }

        let additions = request.mediaItems.filter { $0.kind == .newAddition }
        if !additions.isEmpty {
            let body = additions.map { activity in
                activity.subtitle.map { "\(activity.title) — \($0)" } ?? activity.title
            }.joined(separator: "<br/>")
            sections.append(
                BriefingSection(
                    id: "media",
                    title: "Media",
                    body: body,
                    items: []
                )
            )
        }

        return sections
    }

    private func makeSection(title: String, items: [NormalizedItem]) -> BriefingSection {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        let body = items.map { item -> String in
            let prefix: String
            if item.isAllDay {
                prefix = "All day"
            } else if let start = item.startDate {
                prefix = formatter.string(from: start)
            } else {
                prefix = ""
            }

            let location = item.location.map { " (\($0))" } ?? ""
            return [prefix, item.title + location]
                .filter { !$0.isEmpty }
                .joined(separator: " — ")
        }
        .joined(separator: "<br/>")

        return BriefingSection(
            id: title.lowercased().replacingOccurrences(of: " ", with: "-"),
            title: title,
            body: body,
            items: items
        )
    }

    private func renderHTML(request: BriefingRequest, openingLine: String, newsSummary: String, sections: [BriefingSection]) -> String {
        let weather = request.weather.map {
            "\($0.summary), \(Int($0.currentTemperatureF))F now, high \(Int($0.highF))/low \(Int($0.lowF))"
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
                <header style="margin-bottom: 24px;">
                    <p style="font-size: 14px; margin: 0 0 8px 0; color: #52606d;">\(request.date.formattedMonthDayWeekday())</p>
                    <h1 style="font-size: 22px; margin: 0 0 8px 0;">Good morning, \(request.audience.displayName).</h1>
                    <p style="font-size: 15px; margin: 0 0 8px 0;">\(weather)</p>
                    <p style="font-size: 15px; margin: 0;">\(openingLine)</p>
                </header>
                \(sectionHTML)
                \(fallbackDisclosure)
            </div>
        </body>
        </html>
        """
    }

    private func sourceSummary(request: BriefingRequest) -> [String] {
        var summary: [String] = []
        summary.append("Items: \(request.normalizedItems.count)")
        summary.append("Due soon: \(request.dueSoon.count)")
        summary.append("News headlines: \(request.headlines.count)")
        summary.append("Media additions: \(request.mediaItems.filter { $0.kind == .newAddition }.count)")
        return summary
    }
}

