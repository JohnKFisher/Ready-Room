import AppKit
import SwiftUI
import WebKit
import ReadyRoomCore

struct DashboardView: View {
    @ObservedObject var model: ReadyRoomAppModel

    private var groupedTimeline: [(String, [NormalizedItem])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let grouped = Dictionary(grouping: model.normalizedItems) { item in
            formatter.string(from: item.startDate ?? model.now)
        }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                HStack(alignment: .top, spacing: 20) {
                    timelineColumn
                    sideCards
                        .frame(maxWidth: 360)
                }

                if model.compareDashboardModes {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dashboard AI Compare")
                            .font(.headline)
                        ForEach(NarrativeGenerationMode.allCases, id: \.self) { mode in
                            if let summary = model.dashboardSummaryByMode[mode] {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                    Text(summary.text)
                                    Text("Preferred: \(summary.preferredMode.rawValue) • Actual: \(summary.actualMode.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(ReadyRoomPalette.windowBackground.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ready Room")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(model.now.formattedMonthDayWeekday())
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(model.weather.map { "\($0.summary), \(Int($0.currentTemperatureF))F" } ?? "Weather unavailable")
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(model.now.formattedClock())
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                    Text(model.statusMessage)
                        .foregroundStyle(.secondary)
                    Toggle("Dashboard Mode", isOn: $model.dashboardModeEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }

            if let summary = model.dashboardSummaryByMode[model.preferredMode] ?? model.dashboardSummaryByMode[.templated] {
                Text(summary.text)
                    .font(.body)
                    .foregroundStyle(ReadyRoomPalette.primaryText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ReadyRoomPalette.bannerSurface, in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ReadyRoomPalette.cardBorder, lineWidth: 1)
                    }
            }

            HStack(spacing: 18) {
                Label("Sources: \(model.sourceSnapshots.count)", systemImage: "antenna.radiowaves.left.and.right")
                Label("Conflicts: \(model.conflicts.count)", systemImage: "exclamationmark.triangle")
                Label("Quiet Hours: \(model.quietHours.isActive(at: model.now) ? "On" : "Off")", systemImage: "moon.zzz")
                Spacer()
                Toggle("Compare Modes", isOn: $model.compareDashboardModes)
                    .toggleStyle(.switch)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var timelineColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !model.normalizedItems.filter(\.isAllDay).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("All Day")
                        .font(.headline)
                    ForEach(model.normalizedItems.filter(\.isAllDay)) { item in
                        TimelineItemView(item: item)
                    }
                }
                .padding()
                .background(ReadyRoomPalette.groupSurface, in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ReadyRoomPalette.cardBorder, lineWidth: 1)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Timeline")
                    .font(.headline)
                ForEach(groupedTimeline, id: \.0) { day, items in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day)
                            .font(.title3.weight(day.contains("Today") ? .bold : .semibold))
                        ForEach(items.filter { !$0.isAllDay }) { item in
                            TimelineItemView(item: item)
                        }
                    }
                    .padding()
                    .background(ReadyRoomPalette.groupSurface, in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ReadyRoomPalette.cardBorder, lineWidth: 1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sideCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(model.cardLayout.cardOrder, id: \.self) { card in
                SideCard(
                    title: cardTitle(card),
                    moveUp: { model.moveCard(card, direction: -1) },
                    moveDown: { model.moveCard(card, direction: 1) }
                ) {
                    switch card {
                    case .dueSoon:
                        ForEach(model.dueSoon) { item in
                            Text(item.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    case .weather:
                        if let weather = model.weather {
                            Text("\(weather.summary)")
                            Text("Now \(Int(weather.currentTemperatureF))F • High \(Int(weather.highF)) • Low \(Int(weather.lowF))")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Weather source unavailable.")
                        }
                    case .news:
                        Text(model.previewArtifacts[.john]?[model.preferredMode]?.sections.first(where: { $0.title == "In The World" })?.body ?? "No news summary yet.")
                        ForEach(model.headlines.prefix(2)) { headline in
                            Text(headline.title)
                                .font(.subheadline.weight(.medium))
                        }
                    case .media:
                        ForEach(model.mediaItems.prefix(4)) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                    if let subtitle = item.subtitle {
                                        Text(subtitle).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if let progress = item.progress {
                                    Text("\(Int(progress * 100))%")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func cardTitle(_ kind: DashboardCardKind) -> String {
        switch kind {
        case .dueSoon: "Due Soon"
        case .weather: "Weather"
        case .news: "News"
        case .media: "Media"
        }
    }
}

private struct TimelineItemView: View {
    let item: NormalizedItem
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.isAllDay ? "All Day" : item.startDate?.formattedClock() ?? "TBD")
                    .font(.headline)
                Text(item.title)
                    .font(.headline)
                Spacer()
                if item.changeState != .unchanged {
                    Text(item.changeState.rawValue.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ReadyRoomPalette.badgeText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ReadyRoomPalette.badgeFill, in: Capsule())
                }
            }
            Text(item.metadata["calendarTitle"] ?? item.source.displayName)
                .foregroundStyle(.secondary)
            if let location = item.location {
                Text(location)
                    .foregroundStyle(.secondary)
            }
            if hovering, let notes = item.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(ReadyRoomPalette.itemSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(ReadyRoomPalette.cardBorder, lineWidth: 1)
        }
        .onHover { hovering = $0 }
    }
}

private struct SideCard<Content: View>: View {
    let title: String
    let moveUp: () -> Void
    let moveDown: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(action: moveUp) { Image(systemName: "arrow.up") }
                    .buttonStyle(.borderless)
                Button(action: moveDown) { Image(systemName: "arrow.down") }
                    .buttonStyle(.borderless)
            }
            content
        }
        .padding()
        .background(ReadyRoomPalette.panelSurface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(ReadyRoomPalette.cardBorder, lineWidth: 1)
        }
    }
}

private enum ReadyRoomPalette {
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let panelSurface = Color(nsColor: .controlBackgroundColor)
    static let groupSurface = Color(nsColor: .underPageBackgroundColor)
    static let itemSurface = Color(nsColor: .textBackgroundColor)
    static let bannerSurface = Color(nsColor: .controlBackgroundColor)
    static let cardBorder = Color(nsColor: .separatorColor).opacity(0.35)
    static let primaryText = Color(nsColor: .labelColor)
    static let badgeFill = Color(nsColor: .controlAccentColor).opacity(0.16)
    static let badgeText = Color(nsColor: .labelColor)
}

struct DashboardWindowBridge: NSViewRepresentable {
    let enabled: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            apply(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            apply(to: nsView.window)
        }
    }

    private func apply(to window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = enabled ? .hidden : .visible
        window.titlebarAppearsTransparent = enabled
        window.isMovableByWindowBackground = enabled
    }
}
