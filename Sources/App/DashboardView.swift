import AppKit
import SwiftUI
import ReadyRoomCore

enum BeaconDashboardSlot: Int, CaseIterable, Sendable, Identifiable {
    case centerTop
    case centerMiddle
    case rightRail
    case centerBottom

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .centerTop: "Center Top"
        case .centerMiddle: "Center Middle"
        case .rightRail: "Right Rail"
        case .centerBottom: "Center Bottom"
        }
    }

    var shortLabel: String {
        switch self {
        case .centerTop: "Top"
        case .centerMiddle: "Mid"
        case .rightRail: "Right"
        case .centerBottom: "Bottom"
        }
    }
}

struct BeaconDashboardSlotAssignment: Equatable, Identifiable {
    let slot: BeaconDashboardSlot
    let kind: DashboardCardKind

    var id: BeaconDashboardSlot { slot }
    var positionDescription: String { "\(slot.rawValue + 1). \(slot.label)" }
}

struct BeaconDashboardSlots: Equatable {
    let orderedKinds: [DashboardCardKind]

    init(cardOrder: [DashboardCardKind]) {
        orderedKinds = Self.normalizedOrder(cardOrder)
    }

    static func normalizedOrder(_ cardOrder: [DashboardCardKind]) -> [DashboardCardKind] {
        var seen: Set<DashboardCardKind> = []
        var normalized: [DashboardCardKind] = []
        normalized.reserveCapacity(DashboardCardKind.allCases.count)

        for kind in cardOrder where seen.contains(kind) == false {
            normalized.append(kind)
            seen.insert(kind)
        }

        for kind in DashboardCardKind.allCases where seen.contains(kind) == false {
            normalized.append(kind)
            seen.insert(kind)
        }

        return Array(normalized.prefix(BeaconDashboardSlot.allCases.count))
    }

    var assignments: [BeaconDashboardSlotAssignment] {
        BeaconDashboardSlot.allCases.enumerated().map { index, slot in
            BeaconDashboardSlotAssignment(slot: slot, kind: orderedKinds[index])
        }
    }

    var centerTop: DashboardCardKind { orderedKinds[0] }
    var centerMiddle: DashboardCardKind { orderedKinds[1] }
    var rightRail: DashboardCardKind { orderedKinds[2] }
    var centerBottom: DashboardCardKind { orderedKinds[3] }

    func index(of kind: DashboardCardKind) -> Int? {
        orderedKinds.firstIndex(of: kind)
    }

    var slotSummaryText: String {
        assignments
            .map { "\($0.slot.shortLabel): \($0.kind.beaconDisplayTitle)" }
            .joined(separator: "  •  ")
    }
}

struct BeaconHeroWeatherDisplay: Equatable {
    let symbolName: String
    let headline: String
    let detail: String
    let locationText: String?
    let noteText: String?
}

struct BeaconHeroDisplayContent: Equatable {
    let summaryText: String
    let weather: BeaconHeroWeatherDisplay

    init(
        summary: GeneratedNarrative?,
        statusMessage: String,
        weather: WeatherSnapshot?,
        weatherHealthStatus: SourceHealthStatus?,
        weatherMessage: String?,
        resolvedLocation: String?
    ) {
        self.summaryText = Self.summaryText(summary: summary, statusMessage: statusMessage)
        self.weather = Self.weatherDisplay(
            weather: weather,
            healthStatus: weatherHealthStatus,
            sourceMessage: weatherMessage,
            resolvedLocation: resolvedLocation
        )
    }

    static func summaryText(summary: GeneratedNarrative?, statusMessage: String) -> String {
        if let text = summary?.text.trimmedNonEmptyValue {
            return text
        }

        let status = statusMessage.trimmedNonEmptyValue ?? "Ready"
        return "Ready Room status: \(status)"
    }

    static func weatherDisplay(
        weather: WeatherSnapshot?,
        healthStatus: SourceHealthStatus?,
        sourceMessage: String?,
        resolvedLocation: String?
    ) -> BeaconHeroWeatherDisplay {
        let normalizedLocation = resolvedLocation?.trimmedNonEmptyValue
        let normalizedSourceMessage = sourceMessage?.trimmedNonEmptyValue

        if let weather {
            return BeaconHeroWeatherDisplay(
                symbolName: weather.symbolName ?? "cloud.fill",
                headline: "\(weather.summary), \(Int(weather.currentTemperatureF))F",
                detail: "High \(Int(weather.highF)) • Low \(Int(weather.lowF))",
                locationText: normalizedLocation,
                noteText: normalizedSourceMessage
            )
        }

        return BeaconHeroWeatherDisplay(
            symbolName: unavailableWeatherSymbolName(for: healthStatus),
            headline: "Weather unavailable",
            detail: unavailableWeatherDetail(status: healthStatus, sourceMessage: normalizedSourceMessage),
            locationText: normalizedLocation,
            noteText: nil
        )
    }

    static func unavailableWeatherSymbolName(for status: SourceHealthStatus?) -> String {
        switch status {
        case .healthy, .stale:
            "cloud.fill"
        case .unavailable, .unconfigured, .unauthorized, .none:
            "cloud.slash.fill"
        }
    }

    private static func unavailableWeatherDetail(status: SourceHealthStatus?, sourceMessage: String?) -> String {
        if let sourceMessage {
            return sourceMessage
        }

        switch status {
        case .unconfigured:
            return "Set weather in Settings."
        case .unauthorized:
            return "Weather access is unavailable."
        case .stale:
            return "The latest weather data is stale."
        case .healthy, .unavailable, .none:
            return "Weather data is not available right now."
        }
    }
}

struct DashboardView: View {
    @ObservedObject var model: ReadyRoomAppModel

    private var timelineItems: [NormalizedItem] {
        let existingIDs = Set(model.normalizedItems.map(\.id))
        let merged = model.normalizedItems + model.dueSoon.filter { obligation in
            existingIDs.contains(obligation.id) == false
        }
        return merged.filter { item in
            DashboardTimelinePolicy.shouldDisplay(item) &&
            DashboardTimelinePolicy.includes(item, now: model.now)
        }
    }

    private var timelineSections: [DashboardTimelineSection] {
        let calendar = Calendar.readyRoomGregorian
        return DashboardTimelinePolicy.groupedSections(for: timelineItems, now: model.now, calendar: calendar)
    }

    private var beaconSlots: BeaconDashboardSlots {
        BeaconDashboardSlots(cardOrder: model.cardLayout.cardOrder)
    }

    private var preferredSummary: GeneratedNarrative? {
        model.dashboardSummaryByMode[model.preferredMode] ?? model.dashboardSummaryByMode[.templated]
    }

    private var heroContent: BeaconHeroDisplayContent {
        BeaconHeroDisplayContent(
            summary: preferredSummary,
            statusMessage: model.statusMessage,
            weather: model.weather,
            weatherHealthStatus: model.snapshot(for: .weather)?.health.resolvedStatus(at: model.now),
            weatherMessage: model.placeholderLabel(for: .weather) ?? model.sourceMessage(for: .weather),
            resolvedLocation: model.weatherSettings.resolvedDisplayName
        )
    }

    var body: some View {
        ZStack {
            beaconBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroBand
                    controlStrip

                    if model.compareDashboardModes {
                        compareModePanel
                    }

                    mainColumns
                }
                .padding(24)
            }
        }
    }

    private var beaconBackground: some View {
        ZStack {
            LinearGradient(
                colors: [ReadyRoomPalette.backgroundTop, ReadyRoomPalette.backgroundMid, ReadyRoomPalette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(ReadyRoomPalette.backgroundGlow.opacity(0.18))
                .frame(width: 440, height: 440)
                .blur(radius: 44)
                .offset(x: -360, y: -220)

            Circle()
                .fill(ReadyRoomPalette.backgroundGlow.opacity(0.16))
                .frame(width: 360, height: 260)
                .blur(radius: 36)
                .offset(x: 420, y: -260)
        }
    }

    private var heroBand: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Ready Room")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(ReadyRoomPalette.primaryText)

                    Text(model.now.formattedMonthDayWeekday())
                        .font(.title3.weight(.medium))
                        .foregroundStyle(ReadyRoomPalette.secondaryText)

                    Text(heroContent.summaryText)
                        .font(.system(size: 27, weight: .semibold, design: .rounded))
                        .foregroundStyle(ReadyRoomPalette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Label(model.statusMessage, systemImage: "waveform.path.ecg")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(ReadyRoomPalette.secondaryText)

                        Text(AppRuntimeMetadata.displayString)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(ReadyRoomPalette.mutedText)
                    }
                }

                Spacer(minLength: 24)

                VStack(alignment: .trailing, spacing: 14) {
                    Text(model.now.formattedClock())
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundStyle(ReadyRoomPalette.primaryText)

                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: heroContent.weather.symbolName)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(ReadyRoomPalette.primaryText)

                            Text(heroContent.weather.headline)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(ReadyRoomPalette.primaryText)

                            if model.placeholderLabel(for: .weather) != nil {
                                PlaceholderBadge(text: "Placeholder")
                            }
                        }

                        Text(heroContent.weather.detail)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(ReadyRoomPalette.secondaryText)

                        if let locationText = heroContent.weather.locationText {
                            Text(locationText)
                                .font(.caption)
                                .foregroundStyle(ReadyRoomPalette.mutedText)
                        }

                        if let noteText = heroContent.weather.noteText {
                            Text(noteText)
                                .font(.caption)
                                .foregroundStyle(ReadyRoomPalette.mutedText)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .frame(maxWidth: 320, alignment: .trailing)
                }
            }

            HStack(spacing: 12) {
                BeaconStatusChip(label: "Sources", value: "\(model.sourceSnapshots.count)", systemImage: "antenna.radiowaves.left.and.right")
                BeaconStatusChip(label: "Conflicts", value: "\(model.conflicts.count)", systemImage: "exclamationmark.triangle")
                BeaconStatusChip(label: "Quiet Hours", value: model.quietHours.isActive(at: model.now) ? "On" : "Off", systemImage: "moon.zzz")
                BeaconStatusChip(label: "Modules", value: "\(DashboardCardKind.allCases.count)", systemImage: "square.grid.3x2")
            }
        }
        .padding(24)
        .beaconPanel(cornerRadius: 30, fill: ReadyRoomPalette.panelSurfaceElevated)
    }

    private var controlStrip: some View {
        HStack(alignment: .center, spacing: 16) {
            Toggle("Compare Modes", isOn: $model.compareDashboardModes)
                .toggleStyle(.switch)
                .tint(ReadyRoomPalette.accent)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(ReadyRoomPalette.secondaryText)

            Spacer(minLength: 12)

            Menu {
                ForEach(beaconSlots.assignments) { assignment in
                    Button("\(assignment.positionDescription): \(assignment.kind.beaconDisplayTitle)") {}
                        .disabled(true)
                }

                Divider()

                ForEach(Array(beaconSlots.orderedKinds.enumerated()), id: \.offset) { index, kind in
                    Button("Move \(kind.beaconDisplayTitle) Earlier") {
                        model.moveCard(kind, direction: -1)
                    }
                    .disabled(index == 0)

                    Button("Move \(kind.beaconDisplayTitle) Later") {
                        model.moveCard(kind, direction: 1)
                    }
                    .disabled(index == beaconSlots.orderedKinds.count - 1)

                    if index != beaconSlots.orderedKinds.count - 1 {
                        Divider()
                    }
                }
            } label: {
                Label("Arrange Modules", systemImage: "rectangle.3.group")
                    .font(.subheadline.weight(.semibold))
            }
            .menuStyle(.borderlessButton)

            Text(beaconSlots.slotSummaryText)
                .font(.caption.weight(.medium))
                .foregroundStyle(ReadyRoomPalette.mutedText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .beaconPanel(cornerRadius: 22, fill: ReadyRoomPalette.controlStripSurface)
    }

    private var compareModePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Dashboard AI Compare")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ReadyRoomPalette.primaryText)

            ForEach(NarrativeGenerationMode.allCases, id: \.self) { mode in
                if let summary = model.dashboardSummaryByMode[mode] {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(mode.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ReadyRoomPalette.secondaryText)

                        Text(summary.text)
                            .foregroundStyle(ReadyRoomPalette.primaryText)

                        Text("Preferred: \(summary.preferredMode.rawValue) • Actual: \(summary.actualMode.rawValue)")
                            .font(.caption)
                            .foregroundStyle(ReadyRoomPalette.mutedText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .beaconPanel(cornerRadius: 18, fill: ReadyRoomPalette.groupSurface)
                }
            }
        }
        .padding(20)
        .beaconPanel(cornerRadius: 24, fill: ReadyRoomPalette.panelSurface)
    }

    private var mainColumns: some View {
        HStack(alignment: .top, spacing: 18) {
            timelineColumn
                .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(spacing: 18) {
                moduleCard(for: beaconSlots.centerTop, minHeight: 188)
                moduleCard(for: beaconSlots.centerMiddle, minHeight: 212)
                moduleCard(for: beaconSlots.centerBottom, minHeight: 250)
            }
            .frame(width: 350)

            moduleCard(for: beaconSlots.rightRail, minHeight: 720)
                .frame(width: 340)
        }
    }

    private var timelineColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("Timeline")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ReadyRoomPalette.primaryText)

                if model.placeholderLabel(for: .calendar) != nil {
                    PlaceholderBadge(text: "Placeholder")
                }
            }

            if let placeholderLabel = model.placeholderLabel(for: .calendar) {
                Text(placeholderLabel)
                    .font(.caption)
                    .foregroundStyle(ReadyRoomPalette.mutedText)
            }

            ForEach(timelineSections) { section in
                VStack(alignment: .leading, spacing: 12) {
                    Text(section.title)
                        .font(.title3.weight(section.highlightsCurrentDay ? .bold : .semibold))
                        .foregroundStyle(ReadyRoomPalette.primaryText)

                    ForEach(section.dayGroups) { dayGroup in
                        VStack(alignment: .leading, spacing: 8) {
                            if section.showsDaySubheaders {
                                Text(dayGroup.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(ReadyRoomPalette.secondaryText)
                            }

                            timelineDayGroupContent(dayGroup)
                        }
                    }
                }
                .padding(18)
                .beaconPanel(cornerRadius: 22, fill: ReadyRoomPalette.groupSurface)
            }
        }
        .padding(20)
        .beaconPanel(cornerRadius: 26, fill: ReadyRoomPalette.panelSurface)
    }

    private func moduleCard(for kind: DashboardCardKind, minHeight: CGFloat) -> some View {
        BeaconModuleCard(
            title: kind.beaconDisplayTitle,
            placeholderText: placeholderText(for: kind),
            statusText: statusText(for: kind)
        ) {
            beaconCardContent(for: kind)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private func beaconCardContent(for kind: DashboardCardKind) -> some View {
        switch kind {
        case .dueSoon:
            if model.dueSoon.isEmpty {
                emptyModuleText("Nothing due soon.")
            } else {
                ForEach(model.dueSoon.prefix(4)) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ReadyRoomPalette.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(dueSoonDetail(for: item))
                            .font(.caption)
                            .foregroundStyle(ReadyRoomPalette.secondaryText)

                        AudiencePillRow(accent: ItemAudienceAccentResolver.resolve(for: item, palette: model.personColorPaletteSettings), compact: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if item.id != model.dueSoon.prefix(4).last?.id {
                        Divider()
                            .overlay(ReadyRoomPalette.cardBorder)
                    }
                }
            }
        case .weather:
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(heroContent.weather.headline, systemImage: heroContent.weather.symbolName)
                            .font(.headline)
                            .foregroundStyle(ReadyRoomPalette.primaryText)

                        Text(heroContent.weather.detail)
                            .foregroundStyle(ReadyRoomPalette.secondaryText)
                    }

                    Spacer(minLength: 12)

                    if let currentTemperature = model.weather?.currentTemperatureF {
                        Text("\(Int(currentTemperature.rounded()))°")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(ReadyRoomPalette.primaryText)
                    }
                }

                HStack(spacing: 10) {
                    WeatherMetricBadge(label: "Rain", value: weatherPrecipitationText)
                    WeatherMetricBadge(label: "Wind", value: weatherWindText)
                    WeatherMetricBadge(label: "Updated", value: weatherUpdatedText)
                }

                if let locationText = heroContent.weather.locationText {
                    Text(locationText)
                        .font(.caption)
                        .foregroundStyle(ReadyRoomPalette.mutedText)
                }

                if let noteText = heroContent.weather.noteText {
                    Text(noteText)
                        .font(.caption)
                        .foregroundStyle(ReadyRoomPalette.mutedText)
                }

                if weatherForecastPeriods.isEmpty == false {
                    Divider()
                        .overlay(ReadyRoomPalette.cardBorder)

                    HStack(alignment: .top, spacing: 10) {
                        ForEach(weatherForecastPeriods) { period in
                            WeatherForecastPeriodView(period: period)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .news:
            Text(model.dashboardNewsSummaryText)
                .foregroundStyle(ReadyRoomPalette.secondaryText)

            if model.headlines.isEmpty {
                emptyModuleText("No news items made the cut this morning.")
            } else {
                ForEach(model.headlines.prefix(3)) { headline in
                    if let url = headline.url {
                        Link(destination: url) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(headline.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(ReadyRoomPalette.primaryText)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(headline.sourceName)
                                    .font(.caption)
                                    .foregroundStyle(ReadyRoomPalette.mutedText)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(headline.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(ReadyRoomPalette.primaryText)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(headline.sourceName)
                                .font(.caption)
                                .foregroundStyle(ReadyRoomPalette.mutedText)
                        }
                    }

                    if headline.id != model.headlines.prefix(3).last?.id {
                        Divider()
                            .overlay(ReadyRoomPalette.cardBorder)
                    }
                }
            }
        case .media:
            if model.mediaItems.isEmpty {
                emptyModuleText(model.sourceMessage(for: .media) ?? "Media source unavailable.")
            } else {
                ForEach(model.mediaItems.prefix(4)) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(ReadyRoomPalette.accent.opacity(0.9))
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .foregroundStyle(ReadyRoomPalette.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let subtitle = item.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(ReadyRoomPalette.secondaryText)
                            }
                        }

                        if let progress = item.progress {
                            Text("\(Int(progress * 100))%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ReadyRoomPalette.secondaryText)
                        }
                    }

                    if item.id != model.mediaItems.prefix(4).last?.id {
                        Divider()
                            .overlay(ReadyRoomPalette.cardBorder)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func emptyModuleText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(ReadyRoomPalette.mutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func placeholderText(for kind: DashboardCardKind) -> String? {
        switch kind {
        case .dueSoon:
            nil
        case .weather:
            model.placeholderLabel(for: .weather)
        case .news:
            model.placeholderLabel(for: .news)
        case .media:
            model.placeholderLabel(for: .media)
        }
    }

    private func statusText(for kind: DashboardCardKind) -> String? {
        switch kind {
        case .dueSoon:
            nil
        case .weather:
            model.placeholderLabel(for: .weather) == nil ? model.sourceMessage(for: .weather) : nil
        case .news:
            model.placeholderLabel(for: .news) == nil ? model.sourceMessage(for: .news) : nil
        case .media:
            model.placeholderLabel(for: .media) == nil ? model.sourceMessage(for: .media) : nil
        }
    }

    private var weatherForecastPeriods: [WeatherForecastPeriod] {
        Array((model.weather?.forecastPeriods ?? []).prefix(3))
    }

    private var weatherPrecipitationText: String {
        guard let chance = model.weather?.precipitationChancePercent else {
            return "--"
        }
        return "\(Int(chance.rounded()))%"
    }

    private var weatherWindText: String {
        guard let wind = model.weather?.windSpeedMPH else {
            return "--"
        }
        return "\(Int(wind.rounded())) mph"
    }

    private var weatherUpdatedText: String {
        guard let fetchedAt = model.weather?.fetchedAt else {
            return "--"
        }
        return fetchedAt.formatted(date: .omitted, time: .shortened)
    }

    @ViewBuilder
    private func timelineDayGroupContent(_ dayGroup: DashboardTimelineDayGroup) -> some View {
        if !dayGroup.allDayItems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("All Day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ReadyRoomPalette.secondaryText)

                ForEach(dayGroup.allDayItems) { item in
                    TimelineItemView(item: item, now: model.now, palette: model.personColorPaletteSettings)
                }
            }
        }

        ForEach(dayGroup.scheduledItems) { item in
            TimelineItemView(item: item, now: model.now, palette: model.personColorPaletteSettings)
        }
    }

    private func dueSoonDetail(for item: NormalizedItem) -> String {
        guard let dueDate = item.startDate else {
            return "Due date unavailable"
        }

        let calendar = Calendar.readyRoomGregorian
        let days = calendar.dateComponents([.day], from: model.now.startOfDay(in: calendar), to: dueDate.startOfDay(in: calendar)).day ?? 0
        let dayLabel: String
        switch days {
        case ..<0:
            dayLabel = "Past due"
        case 0:
            dayLabel = "Due today"
        case 1:
            dayLabel = "Due tomorrow"
        default:
            dayLabel = "Due in \(days) days"
        }

        return "\(dayLabel) • \(dueDate.formattedMonthDayWeekday())"
    }
}

struct DashboardTimelineSection: Identifiable {
    let id: String
    let title: String
    let highlightsCurrentDay: Bool
    let showsDaySubheaders: Bool
    let dayGroups: [DashboardTimelineDayGroup]
}

struct DashboardTimelineDayGroup: Identifiable {
    let date: Date
    let title: String
    let allDayItems: [NormalizedItem]
    let scheduledItems: [NormalizedItem]

    var id: Date { date }
}

struct DashboardTimelinePlacement {
    let date: Date
    let item: NormalizedItem
}

private struct BeaconStatusChip: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(ReadyRoomPalette.secondaryText)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReadyRoomPalette.mutedText)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ReadyRoomPalette.primaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(ReadyRoomPalette.badgeFill, in: Capsule())
        .overlay {
            Capsule()
                .stroke(ReadyRoomPalette.cardBorder, lineWidth: 1)
        }
    }
}

private struct TimelineItemView: View {
    let item: NormalizedItem
    let now: Date
    let palette: PersonColorPaletteSettings
    @State private var showingDetails = false

    var body: some View {
        let accent = ItemAudienceAccentResolver.resolve(for: item, palette: palette)
        let isCompleted = DashboardTimelinePolicy.isCompleted(item, now: now)
        let statusText = timelineStatusText(isCompleted: isCompleted)
        let detailText = item.notes?.trimmedNonEmptyValue

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.isAllDay ? "All Day" : item.startDate?.formattedClock() ?? "TBD")
                    .font(.headline)
                    .foregroundStyle(isCompleted ? ReadyRoomPalette.mutedText : ReadyRoomPalette.primaryText)

                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(isCompleted ? ReadyRoomPalette.mutedText : ReadyRoomPalette.primaryText)

                Spacer()

                if let statusText {
                    TimelineStatusBadge(text: statusText, appearance: badgeAppearance(isCompleted: isCompleted))
                }
            }

            Text(item.metadata["calendarTitle"] ?? item.source.displayName)
                .foregroundStyle(ReadyRoomPalette.secondaryText)

            HStack(alignment: .center, spacing: 10) {
                AudiencePillRow(accent: accent, compact: true)

                if let detailText {
                    Button {
                        showingDetails = true
                    } label: {
                        Label("Details", systemImage: "ellipsis.circle")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(ReadyRoomPalette.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(readyRoomHex: accent.primaryHex, fallback: .secondaryLabelColor).opacity(accent.isNeutralFallback ? 0.12 : 0.16), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color(readyRoomHex: accent.primaryHex, fallback: .secondaryLabelColor).opacity(0.28), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingDetails, arrowEdge: .bottom) {
                        TimelineItemDetailPopover(
                            title: item.title,
                            sourceName: item.metadata["calendarTitle"] ?? item.source.displayName,
                            detailText: detailText,
                            accentHex: accent.primaryHex
                        )
                    }
                    .help("Show more details")
                }
            }

            if let location = item.displayLocation {
                Text(location)
                    .foregroundStyle(ReadyRoomPalette.mutedText)
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 14)
        .padding(.leading, 36)
        .padding(.trailing, 14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ReadyRoomPalette.itemSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(readyRoomHex: accent.primaryHex, fallback: .secondaryLabelColor).opacity(accent.isNeutralFallback ? 0.07 : 0.10))
                }
        }
        .overlay(alignment: .leading) {
            AudienceAccentFillRail(accent: accent)
                .padding(.leading, 12)
                .padding(.vertical, 14)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ReadyRoomPalette.cardBorder, lineWidth: 1)
        }
        .opacity(isCompleted ? 0.84 : 1)
    }

    private func timelineStatusText(isCompleted: Bool) -> String? {
        if item.changeState == .cancelled {
            return "Cancelled"
        }
        if isCompleted {
            return "Complete"
        }
        switch item.changeState {
        case .unchanged:
            return nil
        case .new:
            return "New"
        case .changed:
            return "Changed"
        case .cancelled:
            return "Cancelled"
        case .enteredReminderWindow:
            return "Due Soon"
        }
    }

    private func badgeAppearance(isCompleted: Bool) -> TimelineStatusBadge.Appearance {
        if item.changeState == .cancelled {
            return .cancelled
        }
        if isCompleted {
            return .complete
        }
        return .changed
    }
}

private struct TimelineItemDetailPopover: View {
    let title: String
    let sourceName: String
    let detailText: String
    let accentHex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(Color(readyRoomHex: accentHex, fallback: .secondaryLabelColor))
                    .frame(width: 10, height: 10)

                Text("More Details")
                    .font(.headline)
            }

            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(sourceName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text(detailText)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(width: 300, alignment: .leading)
    }
}

private struct BeaconModuleCard<Content: View>: View {
    let title: String
    let placeholderText: String?
    let statusText: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ReadyRoomPalette.primaryText)

                if placeholderText != nil {
                    PlaceholderBadge(text: "Placeholder")
                }
            }

            if let placeholderText {
                Text(placeholderText)
                    .font(.caption)
                    .foregroundStyle(ReadyRoomPalette.mutedText)
            } else if let statusText {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(ReadyRoomPalette.mutedText)
            }

            content
        }
        .padding(18)
        .beaconPanel(cornerRadius: 24, fill: ReadyRoomPalette.panelSurface)
    }
}

private struct WeatherMetricBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ReadyRoomPalette.mutedText)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ReadyRoomPalette.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(ReadyRoomPalette.badgeFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ReadyRoomPalette.cardBorder, lineWidth: 1)
        }
    }
}

private struct WeatherForecastPeriodView: View {
    let period: WeatherForecastPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let symbolName = period.symbolName {
                    Image(systemName: symbolName)
                        .foregroundStyle(ReadyRoomPalette.primaryText)
                }
                Text(period.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReadyRoomPalette.secondaryText)
            }

            Text(period.summary)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ReadyRoomPalette.primaryText)
                .lineLimit(2)

            Text(temperatureText)
                .font(.caption)
                .foregroundStyle(ReadyRoomPalette.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ReadyRoomPalette.groupSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ReadyRoomPalette.cardBorder, lineWidth: 1)
        }
    }

    private var temperatureText: String {
        switch (period.highF, period.lowF) {
        case let (high?, low?):
            return "High \(Int(high.rounded())) • Low \(Int(low.rounded()))"
        case let (high?, nil):
            return "High \(Int(high.rounded()))"
        case let (nil, low?):
            return "Low \(Int(low.rounded()))"
        case (nil, nil):
            return "Temps unavailable"
        }
    }
}

private struct PlaceholderBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(ReadyRoomPalette.badgeText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ReadyRoomPalette.badgeFill, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(ReadyRoomPalette.cardBorder, lineWidth: 1)
            }
    }
}

private struct TimelineStatusBadge: View {
    enum Appearance {
        case changed
        case cancelled
        case complete
    }

    let text: String
    let appearance: Appearance

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor, in: Capsule())
    }

    private var foregroundColor: Color {
        switch appearance {
        case .changed, .cancelled:
            ReadyRoomPalette.badgeText
        case .complete:
            ReadyRoomPalette.successText
        }
    }

    private var backgroundColor: Color {
        switch appearance {
        case .changed:
            ReadyRoomPalette.badgeFill
        case .cancelled:
            ReadyRoomPalette.cancelBadgeFill
        case .complete:
            ReadyRoomPalette.completeBadgeFill
        }
    }
}

enum DashboardTimelinePolicy {
    static func dayBuckets(for now: Date, calendar: Calendar = .readyRoomGregorian) -> ReadyRoomDayBuckets {
        ReadyRoomDayBuckets(
            anchorDay: now.startOfDay(in: calendar),
            effectiveStartDay: earliestVisibleDay(for: now, calendar: calendar),
            calendar: calendar
        )
    }

    static func shouldDisplay(_ item: NormalizedItem) -> Bool {
        switch item.sourceType {
        case .calendar:
            true
        default:
            item.inclusion.dashboard
        }
    }

    static func earliestVisibleDay(for now: Date, calendar: Calendar = .readyRoomGregorian) -> Date {
        ReadyRoomTimePolicy.displayedDayStart(for: now, calendar: calendar)
    }

    static func includes(_ item: NormalizedItem, now: Date, calendar: Calendar = .readyRoomGregorian) -> Bool {
        !displayDays(item, now: now, calendar: calendar).isEmpty
    }

    static func groupedSections(
        for items: [NormalizedItem],
        now: Date,
        calendar: Calendar = .readyRoomGregorian
    ) -> [DashboardTimelineSection] {
        let dayBuckets = dayBuckets(for: now, calendar: calendar)
        var placements: [DashboardTimelinePlacement] = []
        placements.reserveCapacity(items.count * 2)
        for item in items {
            for day in displayDays(item, now: now, calendar: calendar) {
                placements.append(DashboardTimelinePlacement(date: day, item: item))
            }
        }
        let groupedPlacements = Dictionary(grouping: placements) { placement in
            placement.date
        }

        func makeDayGroup(for date: Date) -> DashboardTimelineDayGroup? {
            let dayPlacements = groupedPlacements[date] ?? []
            guard !dayPlacements.isEmpty else {
                return nil
            }

            let sortedItems = sortItems(dayPlacements.map(\.item))
            var allDayItems: [NormalizedItem] = []
            var scheduledItems: [NormalizedItem] = []
            allDayItems.reserveCapacity(sortedItems.count)
            scheduledItems.reserveCapacity(sortedItems.count)
            for item in sortedItems {
                if item.isAllDay {
                    allDayItems.append(item)
                } else {
                    scheduledItems.append(item)
                }
            }
            return DashboardTimelineDayGroup(
                date: date,
                title: formattedDateTitle(for: date),
                allDayItems: allDayItems,
                scheduledItems: scheduledItems
            )
        }

        var sections: [DashboardTimelineSection] = []

        for carryoverDay in dayBuckets.carryoverDays {
            guard let dayGroup = makeDayGroup(for: carryoverDay) else {
                continue
            }
            sections.append(
                DashboardTimelineSection(
                    id: "carryover-\(carryoverDay.timeIntervalSinceReferenceDate)",
                    title: labeledTitle(label: "Yesterday", date: carryoverDay),
                    highlightsCurrentDay: false,
                    showsDaySubheaders: false,
                    dayGroups: [dayGroup]
                )
            )
        }

        if let todayGroup = makeDayGroup(for: dayBuckets.today) {
            sections.append(
                DashboardTimelineSection(
                    id: "today",
                    title: labeledTitle(label: "Today", date: dayBuckets.today),
                    highlightsCurrentDay: true,
                    showsDaySubheaders: false,
                    dayGroups: [todayGroup]
                )
            )
        }

        if let tomorrowGroup = makeDayGroup(for: dayBuckets.tomorrow) {
            sections.append(
                DashboardTimelineSection(
                    id: "tomorrow",
                    title: labeledTitle(label: "Tomorrow", date: dayBuckets.tomorrow),
                    highlightsCurrentDay: false,
                    showsDaySubheaders: false,
                    dayGroups: [tomorrowGroup]
                )
            )
        }

        let upcomingGroups = dayBuckets.upcoming.compactMap(makeDayGroup)
        if !upcomingGroups.isEmpty {
            sections.append(
                DashboardTimelineSection(
                    id: "upcoming",
                    title: "Upcoming",
                    highlightsCurrentDay: false,
                    showsDaySubheaders: true,
                    dayGroups: upcomingGroups
                )
            )
        }

        return sections
    }

    static func displayDays(_ item: NormalizedItem, now: Date, calendar: Calendar = .readyRoomGregorian) -> [Date] {
        let dayBuckets = dayBuckets(for: now, calendar: calendar)
        let visibleStart = dayBuckets.effectiveStartDay
        let visibleEnd = dayBuckets.visibleEndDay
        guard let startDate = item.startDate else {
            return [visibleStart]
        }

        let startDay = startDate.startOfDay(in: calendar)
        guard item.isAllDay else {
            guard startDay >= visibleStart && startDay <= visibleEnd else {
                return []
            }
            return [startDay]
        }

        let lastDay = lastCoveredDay(for: item, calendar: calendar) ?? startDay
        guard lastDay >= visibleStart else {
            return []
        }

        var days: [Date] = []
        var cursor = max(startDay, visibleStart)
        let finalVisibleDay = min(lastDay, visibleEnd)
        while cursor <= finalVisibleDay {
            days.append(cursor)
            cursor = cursor.adding(days: 1, calendar: calendar)
        }
        return days
    }

    static func isCompleted(_ item: NormalizedItem, now: Date, calendar: Calendar = .readyRoomGregorian) -> Bool {
        guard item.changeState != .cancelled else {
            return false
        }
        if item.isAllDay {
            guard let lastDay = lastCoveredDay(for: item, calendar: calendar) else {
                return false
            }
            return lastDay < now.startOfDay(in: calendar)
        }
        guard let endDate = item.endDate else {
            return false
        }
        return endDate < now
    }

    static func lastCoveredDay(for item: NormalizedItem, calendar: Calendar = .readyRoomGregorian) -> Date? {
        guard let startDate = item.startDate else {
            return nil
        }

        let startDay = startDate.startOfDay(in: calendar)
        guard item.isAllDay, let endDate = item.endDate else {
            return startDay
        }

        let endDay = endDate.startOfDay(in: calendar)
        if endDay > startDay {
            return endDay.adding(days: -1, calendar: calendar)
        }
        return startDay
    }

    private static func sortItems(_ items: [NormalizedItem]) -> [NormalizedItem] {
        items.sorted { lhs, rhs in
            switch (lhs.startDate, rhs.startDate) {
            case let (lhsDate?, rhsDate?):
                return lhsDate < rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.title < rhs.title
            }
        }
    }

    private static func labeledTitle(label: String, date: Date) -> String {
        "\(label) — \(formattedDateTitle(for: date))"
    }

    private static func formattedDateTitle(for date: Date) -> String {
        ReadyRoomFormatters.dashboardSectionTitle.string(from: date)
    }
}

private extension DashboardCardKind {
    var beaconDisplayTitle: String {
        switch self {
        case .dueSoon: "Due Soon"
        case .weather: "Weather"
        case .news: "News"
        case .media: "Media"
        }
    }
}

private extension View {
    func beaconPanel(cornerRadius: CGFloat = 24, fill: Color = ReadyRoomPalette.panelSurface) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ReadyRoomPalette.cardBorder, lineWidth: 1)
            }
            .shadow(color: ReadyRoomPalette.panelShadow, radius: 24, x: 0, y: 12)
    }
}

private extension String {
    var trimmedNonEmptyValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum ReadyRoomPalette {
    static let backgroundTop = Color(red: 0.05, green: 0.18, blue: 0.26)
    static let backgroundMid = Color(red: 0.08, green: 0.35, blue: 0.45)
    static let backgroundBottom = Color(red: 0.10, green: 0.49, blue: 0.58)
    static let backgroundGlow = Color(red: 0.85, green: 0.98, blue: 1.00)

    static let panelSurface = Color.white.opacity(0.10)
    static let panelSurfaceElevated = Color.white.opacity(0.14)
    static let controlStripSurface = Color.black.opacity(0.18)
    static let groupSurface = Color.black.opacity(0.18)
    static let itemSurface = Color.white.opacity(0.08)
    static let cardBorder = Color.white.opacity(0.18)
    static let panelShadow = Color.black.opacity(0.24)

    static let primaryText = Color.white
    static let secondaryText = Color(red: 0.79, green: 0.92, blue: 0.96)
    static let mutedText = Color(red: 0.67, green: 0.83, blue: 0.88)
    static let badgeFill = Color.white.opacity(0.12)
    static let badgeText = Color.white
    static let accent = Color(red: 0.60, green: 0.94, blue: 0.98)
    static let successText = Color(red: 0.63, green: 0.97, blue: 0.78)
    static let completeBadgeFill = Color(red: 0.63, green: 0.97, blue: 0.78).opacity(0.16)
    static let cancelBadgeFill = Color(red: 0.62, green: 0.83, blue: 1.00).opacity(0.16)
}
