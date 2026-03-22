#!/usr/bin/env swift

import AppKit
import Foundation

enum ConceptTier: String {
    case conservative = "Conservative"
    case medium = "Medium Shift"
    case bigSwing = "Big Swing"
}

enum LayoutKind {
    case morningLedger
    case glassRail
    case quietColumns
    case signalBoard
    case bentoPulse
    case daylineFocus
    case commandTheater
    case editorialDesk
    case beaconWall
}

struct DashboardConcept {
    let slug: String
    let title: String
    let tier: ConceptTier
    let layout: LayoutKind
    let intent: String
    let feasibility: String
    let callout: String
}

struct StatusChip {
    let label: String
    let value: String
}

struct TimelineItemPayload {
    let time: String
    let title: String
    let detail: String
    let location: String?
    let owner: String
    let accent: NSColor
    let status: String?
}

struct TimelineSectionPayload {
    let title: String
    let items: [TimelineItemPayload]
}

struct CardRowPayload {
    let primary: String
    let secondary: String?
    let trailing: String?
    let accent: NSColor?
}

struct DashboardPayload {
    let appName: String
    let dateLabel: String
    let timeLabel: String
    let runtimeLabel: String
    let weatherSummary: String
    let weatherDetail: String
    let locationLabel: String
    let summary: String
    let chips: [StatusChip]
    let timelineSections: [TimelineSectionPayload]
    let dueSoonRows: [CardRowPayload]
    let newsRows: [CardRowPayload]
    let mediaRows: [CardRowPayload]

    static let frozen = DashboardPayload(
        appName: "Ready Room",
        dateLabel: "Saturday, March 21",
        timeLabel: "7:42 AM",
        runtimeLabel: "0.2.11 (31)",
        weatherSummary: "Cloudy, 49F",
        weatherDetail: "High 55 • Low 41 • 10% rain • Wind 7 mph",
        locationLabel: "New Brunswick, NJ",
        summary: "Amy has a client presentation at 11:00, John is working from home, Ellie pickup is covered, and two household tasks need attention before Monday.",
        chips: [
            StatusChip(label: "Sources", value: "4"),
            StatusChip(label: "Conflicts", value: "1"),
            StatusChip(label: "Quiet Hours", value: "Off"),
            StatusChip(label: "Status", value: "Ready")
        ],
        timelineSections: [
            TimelineSectionPayload(
                title: "Today",
                items: [
                    TimelineItemPayload(
                        time: "All Day",
                        title: "Call pediatric dentist",
                        detail: "Insurance follow-up and summer appointment window",
                        location: nil,
                        owner: "Family",
                        accent: NSColor(hex: 0xE67E22),
                        status: "Due Soon"
                    ),
                    TimelineItemPayload(
                        time: "9:00",
                        title: "Team standup",
                        detail: "WFH today; prep the delivery-risk note before the call",
                        location: "Home Office",
                        owner: "John",
                        accent: NSColor(hex: 0x3478F6),
                        status: nil
                    ),
                    TimelineItemPayload(
                        time: "11:00",
                        title: "Client presentation",
                        detail: "Updated review deck and rehearsal notes are in the shared folder",
                        location: "Downtown Office",
                        owner: "Amy",
                        accent: NSColor(hex: 0x39A96B),
                        status: "Changed"
                    ),
                    TimelineItemPayload(
                        time: "15:00",
                        title: "Ellie pickup",
                        detail: "John can cover if traffic runs late",
                        location: "Elementary School",
                        owner: "Family",
                        accent: NSColor(hex: 0x7ECFFF),
                        status: nil
                    )
                ]
            ),
            TimelineSectionPayload(
                title: "Tomorrow",
                items: [
                    TimelineItemPayload(
                        time: "All Day",
                        title: "Upload school permission slip",
                        detail: "Photo is ready; just needs the portal upload",
                        location: nil,
                        owner: "Family",
                        accent: NSColor(hex: 0xE67E22),
                        status: "New"
                    ),
                    TimelineItemPayload(
                        time: "18:30",
                        title: "Soccer practice",
                        detail: "Bring the orange water bottle and shin guards",
                        location: "North Field",
                        owner: "Mia",
                        accent: NSColor(hex: 0xC27CFF),
                        status: nil
                    )
                ]
            ),
            TimelineSectionPayload(
                title: "Upcoming",
                items: [
                    TimelineItemPayload(
                        time: "Mon",
                        title: "Disney card due",
                        detail: "Autopay is off; verify the amount before noon",
                        location: nil,
                        owner: "Family",
                        accent: NSColor(hex: 0xE67E22),
                        status: "Due Soon"
                    ),
                    TimelineItemPayload(
                        time: "Tue",
                        title: "Choir rehearsal",
                        detail: "Black folder and water bottle",
                        location: "Middle School",
                        owner: "Ellie",
                        accent: NSColor(hex: 0xA26FF3),
                        status: nil
                    )
                ]
            )
        ],
        dueSoonRows: [
            CardRowPayload(primary: "Disney card due", secondary: "Due in 2 days • Monday", trailing: nil, accent: NSColor(hex: 0xE67E22)),
            CardRowPayload(primary: "Upload school permission slip", secondary: "Due tomorrow", trailing: nil, accent: NSColor(hex: 0xF1C40F)),
            CardRowPayload(primary: "Call pediatric dentist", secondary: "Past due", trailing: nil, accent: NSColor(hex: 0xE74C3C))
        ],
        newsRows: [
            CardRowPayload(primary: "Egg prices ease as wholesalers rebuild supply", secondary: "AP News", trailing: nil, accent: nil),
            CardRowPayload(primary: "Mets announce opening-day starter", secondary: "MLB.com", trailing: nil, accent: nil),
            CardRowPayload(primary: "Local transit board weighs summer schedule changes", secondary: "NJ Spotlight News", trailing: nil, accent: nil)
        ],
        mediaRows: [
            CardRowPayload(primary: "Bluey", secondary: "Ellie • Living Room TV", trailing: "35%", accent: NSColor(hex: 0x7ECFFF)),
            CardRowPayload(primary: "The Wild Robot", secondary: "Recently added to Plex", trailing: nil, accent: NSColor(hex: 0x39A96B))
        ]
    )
}

let concepts: [DashboardConcept] = [
    DashboardConcept(
        slug: "01-morning-ledger",
        title: "Morning Ledger",
        tier: .conservative,
        layout: .morningLedger,
        intent: "Tighten the current split dashboard with clearer hierarchy, better spacing, and cleaner status surfaces.",
        feasibility: "High. This is mostly a visual refinement of the current dashboard structure.",
        callout: "Safe now"
    ),
    DashboardConcept(
        slug: "02-glass-rail",
        title: "Glass Rail",
        tier: .conservative,
        layout: .glassRail,
        intent: "Keep the familiar split layout but introduce layered glass panels and a stronger left-to-right reading path.",
        feasibility: "High-medium. Styling is richer, but the information architecture stays close to the current app.",
        callout: "Safe now"
    ),
    DashboardConcept(
        slug: "03-quiet-columns",
        title: "Quiet Columns",
        tier: .conservative,
        layout: .quietColumns,
        intent: "Reduce visual noise for all-day viewing with larger whitespace, softer sectioning, and calmer typography.",
        feasibility: "High. This is primarily spacing, typography, and surface-tuning work.",
        callout: "Safe now"
    ),
    DashboardConcept(
        slug: "04-signal-board",
        title: "Signal Board",
        tier: .medium,
        layout: .signalBoard,
        intent: "Promote system state and day-level scanning with a denser operations-console rhythm.",
        feasibility: "Medium. It would need new wrappers and badges but can still use today’s content model.",
        callout: "Safe now"
    ),
    DashboardConcept(
        slug: "05-bento-pulse",
        title: "Bento Pulse",
        tier: .medium,
        layout: .bentoPulse,
        intent: "Break the strict two-column split into a modular board that spotlights what changed first.",
        feasibility: "Medium. It needs span-aware composition but not new product behavior.",
        callout: "Safe now"
    ),
    DashboardConcept(
        slug: "06-dayline-focus",
        title: "Dayline Focus",
        tier: .medium,
        layout: .daylineFocus,
        intent: "Make near-term scheduling easier to scan by turning the day buckets into broad horizontal bands.",
        feasibility: "Medium. This is a timeline presentation shift rather than a data-model change.",
        callout: "Safe now"
    ),
    DashboardConcept(
        slug: "07-command-theater",
        title: "Command Theater",
        tier: .bigSwing,
        layout: .commandTheater,
        intent: "Turn the dashboard into a dark wall-mounted command surface with one strong focal lane.",
        feasibility: "Medium-low. It is still grounded in current content, but it wants a more opinionated visual system.",
        callout: "Safe now"
    ),
    DashboardConcept(
        slug: "08-editorial-desk",
        title: "Editorial Desk",
        tier: .bigSwing,
        layout: .editorialDesk,
        intent: "Recast Ready Room as a calm printed briefing board with strong hierarchy and paper-like structure.",
        feasibility: "Medium-low. Achievable, but it departs furthest from today’s chrome and component language.",
        callout: "Safe now"
    ),
    DashboardConcept(
        slug: "09-beacon-wall",
        title: "Beacon Wall",
        tier: .bigSwing,
        layout: .beaconWall,
        intent: "Optimize for across-the-room glanceability with oversized hero metrics and reduced secondary clutter.",
        feasibility: "Medium. Great for kiosk mode, but some controls would likely move off the main dashboard surface.",
        callout: "Future-only if tied to a dedicated wall-display mode"
    )
]

let canvasSize = CGSize(width: 1600, height: 1000)

@discardableResult
func withGraphicsState<T>(_ body: () -> T) -> T {
    NSGraphicsContext.saveGraphicsState()
    let value = body()
    NSGraphicsContext.restoreGraphicsState()
    return value
}

extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    func tinted(_ alpha: CGFloat) -> NSColor {
        withAlphaComponent(alpha)
    }
}

extension CGRect {
    func splitTop(_ amount: CGFloat) -> (top: CGRect, remainder: CGRect) {
        let top = CGRect(x: minX, y: minY, width: width, height: amount)
        let remainder = CGRect(x: minX, y: minY + amount, width: width, height: height - amount)
        return (top, remainder)
    }

    func splitLeft(_ amount: CGFloat) -> (left: CGRect, remainder: CGRect) {
        let left = CGRect(x: minX, y: minY, width: amount, height: height)
        let remainder = CGRect(x: minX + amount, y: minY, width: width - amount, height: height)
        return (left, remainder)
    }
}

func makeFont(_ preferred: String?, size: CGFloat, weight: NSFont.Weight = .regular, design: NSFontDescriptor.SystemDesign? = nil) -> NSFont {
    if let preferred, let font = NSFont(name: preferred, size: size) {
        return font
    }
    let system = NSFont.systemFont(ofSize: size, weight: weight)
    if let design, let designed = system.fontDescriptor.withDesign(design).flatMap({ NSFont(descriptor: $0, size: size) }) {
        return designed
    }
    return system
}

@discardableResult
func drawText(
    _ text: String,
    in rect: CGRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .left,
    lineHeight: CGFloat? = nil,
    uppercase: Bool = false
) -> CGFloat {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = alignment
    paragraphStyle.lineBreakMode = .byWordWrapping
    if let lineHeight {
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
    }

    let content = uppercase ? text.uppercased() : text
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraphStyle,
        .kern: uppercase ? 1.2 : 0
    ]
    let attributed = NSAttributedString(string: content, attributes: attributes)
    let bounds = attributed.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading])
    attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    return ceil(bounds.height)
}

func drawRoundedRect(_ rect: CGRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, lineWidth: CGFloat = 1) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
}

func drawGradient(in rect: CGRect, radius: CGFloat = 0, colors: [NSColor], angle: CGFloat) {
    guard let gradient = NSGradient(colors: colors) else { return }
    if radius > 0 {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        gradient.draw(in: path, angle: angle)
    } else {
        gradient.draw(in: rect, angle: angle)
    }
}

func drawShadow(color: NSColor, blur: CGFloat, offset: CGSize = .zero, body: () -> Void) {
    withGraphicsState {
        let shadow = NSShadow()
        shadow.shadowBlurRadius = blur
        shadow.shadowOffset = offset
        shadow.shadowColor = color
        shadow.set()
        body()
    }
}

func drawGlow(in rect: CGRect, color: NSColor) {
    withGraphicsState {
        let path = NSBezierPath(ovalIn: rect)
        path.addClip()
        color.setFill()
        path.fill()
    }
}

func drawDivider(at y: CGFloat, in rect: CGRect, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: rect.minX, y: y))
    path.line(to: CGPoint(x: rect.maxX, y: y))
    color.setStroke()
    path.lineWidth = 1
    path.stroke()
}

func drawBadge(text: String, rect: CGRect, fill: NSColor, foreground: NSColor, font: NSFont? = nil) {
    drawRoundedRect(rect, radius: rect.height / 2, fill: fill)
    _ = drawText(
        text,
        in: rect.insetBy(dx: 10, dy: 5),
        font: font ?? makeFont(nil, size: 12, weight: .semibold, design: .rounded),
        color: foreground,
        alignment: .center
    )
}

func drawStatusChips(_ chips: [StatusChip], in rect: CGRect, fill: NSColor, stroke: NSColor, labelColor: NSColor, valueColor: NSColor, compact: Bool = false) {
    let gap: CGFloat = 12
    let chipWidth = (rect.width - CGFloat(max(0, chips.count - 1)) * gap) / CGFloat(max(chips.count, 1))
    for (index, chip) in chips.enumerated() {
        let chipRect = CGRect(x: rect.minX + CGFloat(index) * (chipWidth + gap), y: rect.minY, width: chipWidth, height: rect.height)
        drawRoundedRect(chipRect, radius: 18, fill: fill, stroke: stroke)
        _ = drawText(chip.label, in: CGRect(x: chipRect.minX + 16, y: chipRect.minY + 10, width: chipRect.width - 32, height: 18), font: makeFont(nil, size: compact ? 11 : 12, weight: .semibold, design: .rounded), color: labelColor, uppercase: true)
        _ = drawText(chip.value, in: CGRect(x: chipRect.minX + 16, y: chipRect.minY + (compact ? 26 : 28), width: chipRect.width - 32, height: 24), font: makeFont(nil, size: compact ? 19 : 22, weight: .bold, design: .rounded), color: valueColor)
    }
}

func drawOwnerPill(owner: String, accent: NSColor, rect: CGRect, foreground: NSColor) {
    drawRoundedRect(rect, radius: rect.height / 2, fill: accent.tinted(0.16))
    let dotRect = CGRect(x: rect.minX + 10, y: rect.midY - 4, width: 8, height: 8)
    drawRoundedRect(dotRect, radius: 4, fill: accent)
    _ = drawText(owner, in: CGRect(x: rect.minX + 24, y: rect.minY + 5, width: rect.width - 30, height: rect.height - 10), font: makeFont(nil, size: 11, weight: .semibold, design: .rounded), color: foreground)
}

func drawPanel(_ rect: CGRect, radius: CGFloat, fillColors: [NSColor], stroke: NSColor, shadow: NSColor? = nil) {
    if let shadow {
        drawShadow(color: shadow, blur: 28, offset: CGSize(width: 0, height: 8)) {
            drawGradient(in: rect, radius: radius, colors: fillColors, angle: -90)
        }
    } else {
        drawGradient(in: rect, radius: radius, colors: fillColors, angle: -90)
    }
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    stroke.setStroke()
    path.lineWidth = 1
    path.stroke()
}

func drawSummaryPanel(rect: CGRect, summary: String, fillColors: [NSColor], stroke: NSColor, textColor: NSColor, shadow: NSColor? = nil) {
    drawPanel(rect, radius: 22, fillColors: fillColors, stroke: stroke, shadow: shadow)
    _ = drawText(summary, in: rect.insetBy(dx: 24, dy: 18), font: makeFont(nil, size: 24, weight: .semibold, design: .rounded), color: textColor, lineHeight: 30)
}

func drawWeatherCard(rect: CGRect, payload: DashboardPayload, titleColor: NSColor, primaryColor: NSColor, secondaryColor: NSColor, fillColors: [NSColor], stroke: NSColor, shadow: NSColor? = nil, largeMetric: Bool = true) {
    drawPanel(rect, radius: 22, fillColors: fillColors, stroke: stroke, shadow: shadow)
    _ = drawText("Weather", in: CGRect(x: rect.minX + 20, y: rect.minY + 18, width: rect.width - 40, height: 20), font: makeFont(nil, size: 13, weight: .bold, design: .rounded), color: titleColor, uppercase: true)
    _ = drawText(payload.weatherSummary, in: CGRect(x: rect.minX + 20, y: rect.minY + 48, width: rect.width - 40, height: 40), font: makeFont(nil, size: largeMetric ? 32 : 24, weight: .bold, design: .rounded), color: primaryColor)
    _ = drawText(payload.weatherDetail, in: CGRect(x: rect.minX + 20, y: rect.minY + (largeMetric ? 92 : 84), width: rect.width - 40, height: 28), font: makeFont(nil, size: 15, weight: .medium), color: secondaryColor, lineHeight: 20)
    _ = drawText(payload.locationLabel, in: CGRect(x: rect.minX + 20, y: rect.maxY - 34, width: rect.width - 40, height: 20), font: makeFont(nil, size: 13, weight: .medium), color: secondaryColor)
}

func drawRowsCard(title: String, rows: [CardRowPayload], rect: CGRect, titleColor: NSColor, primaryColor: NSColor, secondaryColor: NSColor, fillColors: [NSColor], stroke: NSColor, shadow: NSColor? = nil, compact: Bool = false) {
    drawPanel(rect, radius: 22, fillColors: fillColors, stroke: stroke, shadow: shadow)
    _ = drawText(title, in: CGRect(x: rect.minX + 20, y: rect.minY + 18, width: rect.width - 40, height: 20), font: makeFont(nil, size: 13, weight: .bold, design: .rounded), color: titleColor, uppercase: true)
    var y = rect.minY + 52
    let rowHeight: CGFloat = compact ? 52 : 64
    for row in rows {
        let rowRect = CGRect(x: rect.minX + 20, y: y, width: rect.width - 40, height: rowHeight)
        if let accent = row.accent {
            drawRoundedRect(CGRect(x: rowRect.minX, y: rowRect.minY + 12, width: 6, height: rowRect.height - 24), radius: 3, fill: accent)
        }
        let textX = rowRect.minX + (row.accent == nil ? 0 : 16)
        _ = drawText(row.primary, in: CGRect(x: textX, y: rowRect.minY, width: rowRect.width - (row.accent == nil ? 0 : 16) - 70, height: 24), font: makeFont(nil, size: compact ? 16 : 17, weight: .semibold), color: primaryColor)
        if let secondary = row.secondary {
            _ = drawText(secondary, in: CGRect(x: textX, y: rowRect.minY + 24, width: rowRect.width - (row.accent == nil ? 0 : 16) - 70, height: 20), font: makeFont(nil, size: 13, weight: .medium), color: secondaryColor)
        }
        if let trailing = row.trailing {
            _ = drawText(trailing, in: CGRect(x: rowRect.maxX - 62, y: rowRect.minY + 6, width: 54, height: 20), font: makeFont(nil, size: 14, weight: .semibold, design: .rounded), color: secondaryColor, alignment: .right)
        }
        y += rowHeight
        if row.primary != rows.last?.primary {
            drawDivider(at: y - 6, in: CGRect(x: rect.minX + 20, y: 0, width: rect.width - 40, height: 0), color: stroke.tinted(0.5))
        }
    }
}

func drawTimelinePanel(
    rect: CGRect,
    sections: [TimelineSectionPayload],
    fillColors: [NSColor],
    stroke: NSColor,
    titleColor: NSColor,
    textColor: NSColor,
    secondaryColor: NSColor,
    shadow: NSColor? = nil,
    compact: Bool = false,
    showSectionBoxes: Bool = true
) {
    drawPanel(rect, radius: 26, fillColors: fillColors, stroke: stroke, shadow: shadow)
    _ = drawText("Timeline", in: CGRect(x: rect.minX + 24, y: rect.minY + 18, width: rect.width - 48, height: 24), font: makeFont(nil, size: 15, weight: .bold, design: .rounded), color: titleColor, uppercase: true)

    var y = rect.minY + 56
    let sectionGap: CGFloat = compact ? 12 : 16
    for section in sections {
        let itemHeights = CGFloat(section.items.count) * (compact ? 74 : 86)
        let headerHeight: CGFloat = 26
        let containerHeight = headerHeight + itemHeights + 18
        let sectionRect = CGRect(x: rect.minX + 20, y: y, width: rect.width - 40, height: containerHeight)
        if showSectionBoxes {
            drawRoundedRect(sectionRect, radius: 20, fill: stroke.tinted(0.08), stroke: stroke.tinted(0.55))
        }
        _ = drawText(section.title, in: CGRect(x: sectionRect.minX + 18, y: sectionRect.minY + 14, width: sectionRect.width - 36, height: 24), font: makeFont(nil, size: compact ? 20 : 22, weight: .bold, design: .rounded), color: textColor)
        var itemY = sectionRect.minY + 48
        for item in section.items {
            let itemRect = CGRect(x: sectionRect.minX + 14, y: itemY, width: sectionRect.width - 28, height: compact ? 68 : 80)
            drawRoundedRect(itemRect, radius: 16, fill: item.accent.tinted(0.10), stroke: item.accent.tinted(0.28))
            drawRoundedRect(CGRect(x: itemRect.minX + 12, y: itemRect.minY + 12, width: 6, height: itemRect.height - 24), radius: 3, fill: item.accent)
            _ = drawText(item.time, in: CGRect(x: itemRect.minX + 28, y: itemRect.minY + 14, width: 70, height: 20), font: makeFont(nil, size: 15, weight: .bold, design: .rounded), color: secondaryColor)
            _ = drawText(item.title, in: CGRect(x: itemRect.minX + 98, y: itemRect.minY + 12, width: itemRect.width - 240, height: 24), font: makeFont(nil, size: compact ? 18 : 19, weight: .semibold), color: textColor)
            _ = drawText(item.detail, in: CGRect(x: itemRect.minX + 98, y: itemRect.minY + 36, width: itemRect.width - 240, height: 20), font: makeFont(nil, size: 13, weight: .medium), color: secondaryColor)
            if let location = item.location {
                _ = drawText(location, in: CGRect(x: itemRect.minX + 98, y: itemRect.minY + 54, width: itemRect.width - 240, height: 18), font: makeFont(nil, size: 12, weight: .medium), color: secondaryColor)
            }
            let ownerRect = CGRect(x: itemRect.maxX - 124, y: itemRect.minY + 12, width: 72, height: 24)
            drawOwnerPill(owner: item.owner, accent: item.accent, rect: ownerRect, foreground: textColor)
            if let status = item.status {
                drawBadge(text: status, rect: CGRect(x: itemRect.maxX - 124, y: itemRect.minY + 44, width: 92, height: 24), fill: textColor.tinted(0.10), foreground: textColor)
            }
            itemY += compact ? 74 : 86
        }
        y += containerHeight + sectionGap
    }
}

func drawHeaderBlock(
    rect: CGRect,
    payload: DashboardPayload,
    fillColors: [NSColor],
    stroke: NSColor,
    titleColor: NSColor,
    primaryColor: NSColor,
    secondaryColor: NSColor,
    shadow: NSColor? = nil,
    dateFont: NSFont? = nil,
    heroFont: NSFont? = nil,
    showRuntime: Bool = true
) {
    drawPanel(rect, radius: 26, fillColors: fillColors, stroke: stroke, shadow: shadow)
    _ = drawText(payload.appName, in: CGRect(x: rect.minX + 24, y: rect.minY + 20, width: 320, height: 38), font: makeFont(nil, size: 32, weight: .bold, design: .rounded), color: titleColor)
    _ = drawText(payload.dateLabel, in: CGRect(x: rect.minX + 24, y: rect.minY + 62, width: 320, height: 26), font: dateFont ?? makeFont(nil, size: 19, weight: .medium), color: secondaryColor)
    _ = drawText(payload.weatherSummary, in: CGRect(x: rect.minX + 24, y: rect.minY + 94, width: 320, height: 24), font: makeFont(nil, size: 18, weight: .semibold), color: titleColor)
    if showRuntime {
        _ = drawText(payload.runtimeLabel, in: CGRect(x: rect.minX + 24, y: rect.maxY - 40, width: 200, height: 20), font: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium), color: secondaryColor)
    }
    _ = drawText(payload.timeLabel, in: CGRect(x: rect.maxX - 260, y: rect.minY + 22, width: 220, height: 54), font: heroFont ?? NSFont.monospacedSystemFont(ofSize: 48, weight: .bold), color: primaryColor, alignment: .right)
    _ = drawText(payload.locationLabel, in: CGRect(x: rect.maxX - 300, y: rect.minY + 82, width: 260, height: 20), font: makeFont(nil, size: 14, weight: .medium), color: secondaryColor, alignment: .right)
}

func renderMorningLedger(_ concept: DashboardConcept, payload: DashboardPayload, in canvas: CGRect) {
    drawGradient(in: canvas, colors: [NSColor(hex: 0xF5F8FC), NSColor(hex: 0xE7EEF8)], angle: -90)
    drawGlow(in: CGRect(x: 1030, y: 40, width: 460, height: 260), color: NSColor(hex: 0xDCE9FF, alpha: 0.55))

    let outer = canvas.insetBy(dx: 48, dy: 44)
    let headerRect = CGRect(x: outer.minX, y: outer.minY, width: outer.width, height: 154)
    let summaryRect = CGRect(x: outer.minX, y: headerRect.maxY + 18, width: outer.width, height: 92)
    let chipsRect = CGRect(x: outer.minX, y: summaryRect.maxY + 18, width: outer.width, height: 72)
    let contentRect = CGRect(x: outer.minX, y: chipsRect.maxY + 18, width: outer.width, height: outer.maxY - (chipsRect.maxY + 18))
    let (timelineRect, sideRect) = contentRect.splitLeft(980)

    drawHeaderBlock(rect: headerRect, payload: payload, fillColors: [NSColor.white, NSColor(hex: 0xF7FAFF)], stroke: NSColor(hex: 0xD7E1EF), titleColor: NSColor(hex: 0x10233C), primaryColor: NSColor(hex: 0x10233C), secondaryColor: NSColor(hex: 0x5E7087), shadow: NSColor.black.tinted(0.10))
    drawSummaryPanel(rect: summaryRect, summary: payload.summary, fillColors: [NSColor(hex: 0xEAF2FF), NSColor(hex: 0xDCEAFE)], stroke: NSColor(hex: 0xC6D8F3), textColor: NSColor(hex: 0x18304D), shadow: NSColor.black.tinted(0.06))
    drawStatusChips(payload.chips, in: chipsRect, fill: NSColor.white, stroke: NSColor(hex: 0xD7E1EF), labelColor: NSColor(hex: 0x6A7B90), valueColor: NSColor(hex: 0x10233C))

    drawTimelinePanel(rect: timelineRect.insetBy(dx: 0, dy: 0), sections: payload.timelineSections, fillColors: [NSColor.white, NSColor(hex: 0xFAFCFF)], stroke: NSColor(hex: 0xD7E1EF), titleColor: NSColor(hex: 0x5D6F87), textColor: NSColor(hex: 0x10233C), secondaryColor: NSColor(hex: 0x5E7087), shadow: NSColor.black.tinted(0.08))

    let cardGap: CGFloat = 16
    let cardHeight = (sideRect.height - cardGap * 3) / 4
    let dueRect = CGRect(x: sideRect.minX + 16, y: sideRect.minY, width: sideRect.width - 16, height: cardHeight)
    let weatherRect = CGRect(x: sideRect.minX + 16, y: dueRect.maxY + cardGap, width: sideRect.width - 16, height: cardHeight)
    let newsRect = CGRect(x: sideRect.minX + 16, y: weatherRect.maxY + cardGap, width: sideRect.width - 16, height: cardHeight)
    let mediaRect = CGRect(x: sideRect.minX + 16, y: newsRect.maxY + cardGap, width: sideRect.width - 16, height: cardHeight)
    drawRowsCard(title: "Due Soon", rows: payload.dueSoonRows, rect: dueRect, titleColor: NSColor(hex: 0x5D6F87), primaryColor: NSColor(hex: 0x10233C), secondaryColor: NSColor(hex: 0x5E7087), fillColors: [NSColor.white, NSColor(hex: 0xFAFCFF)], stroke: NSColor(hex: 0xD7E1EF), shadow: NSColor.black.tinted(0.08), compact: true)
    drawWeatherCard(rect: weatherRect, payload: payload, titleColor: NSColor(hex: 0x5D6F87), primaryColor: NSColor(hex: 0x10233C), secondaryColor: NSColor(hex: 0x5E7087), fillColors: [NSColor.white, NSColor(hex: 0xFAFCFF)], stroke: NSColor(hex: 0xD7E1EF), shadow: NSColor.black.tinted(0.08), largeMetric: false)
    drawRowsCard(title: "News", rows: payload.newsRows, rect: newsRect, titleColor: NSColor(hex: 0x5D6F87), primaryColor: NSColor(hex: 0x10233C), secondaryColor: NSColor(hex: 0x5E7087), fillColors: [NSColor.white, NSColor(hex: 0xFAFCFF)], stroke: NSColor(hex: 0xD7E1EF), shadow: NSColor.black.tinted(0.08), compact: true)
    drawRowsCard(title: "Media", rows: payload.mediaRows, rect: mediaRect, titleColor: NSColor(hex: 0x5D6F87), primaryColor: NSColor(hex: 0x10233C), secondaryColor: NSColor(hex: 0x5E7087), fillColors: [NSColor.white, NSColor(hex: 0xFAFCFF)], stroke: NSColor(hex: 0xD7E1EF), shadow: NSColor.black.tinted(0.08), compact: true)
}

func renderGlassRail(_ concept: DashboardConcept, payload: DashboardPayload, in canvas: CGRect) {
    drawGradient(in: canvas, colors: [NSColor(hex: 0x091B31), NSColor(hex: 0x123359), NSColor(hex: 0x24547D)], angle: -90)
    drawGlow(in: CGRect(x: -100, y: 120, width: 500, height: 500), color: NSColor(hex: 0x4CB7FF, alpha: 0.16))
    drawGlow(in: CGRect(x: 1180, y: 60, width: 360, height: 260), color: NSColor(hex: 0xA7D7FF, alpha: 0.22))

    let outer = canvas.insetBy(dx: 44, dy: 40)
    drawRoundedRect(CGRect(x: outer.minX, y: outer.minY + 8, width: 10, height: outer.height - 16), radius: 5, fill: NSColor(hex: 0x7ED3FF, alpha: 0.85))

    let headerRect = CGRect(x: outer.minX + 28, y: outer.minY, width: outer.width - 28, height: 172)
    let summaryRect = CGRect(x: outer.minX + 28, y: headerRect.maxY + 18, width: outer.width - 28, height: 92)
    let contentRect = CGRect(x: outer.minX + 28, y: summaryRect.maxY + 22, width: outer.width - 28, height: outer.maxY - (summaryRect.maxY + 22))
    let (timelineRect, sideRect) = contentRect.splitLeft(990)

    drawHeaderBlock(rect: headerRect, payload: payload, fillColors: [NSColor(hex: 0xFFFFFF, alpha: 0.14), NSColor(hex: 0xD9ECFF, alpha: 0.07)], stroke: NSColor(hex: 0xDCEEFF, alpha: 0.24), titleColor: NSColor.white, primaryColor: NSColor(hex: 0xEAF6FF), secondaryColor: NSColor(hex: 0xB9D4EA), shadow: NSColor.black.tinted(0.25))
    drawSummaryPanel(rect: summaryRect, summary: payload.summary, fillColors: [NSColor(hex: 0xCDEBFF, alpha: 0.16), NSColor(hex: 0xFFFFFF, alpha: 0.08)], stroke: NSColor(hex: 0xDCEEFF, alpha: 0.20), textColor: NSColor(hex: 0xF1F8FF), shadow: NSColor.black.tinted(0.18))
    drawTimelinePanel(rect: timelineRect, sections: payload.timelineSections, fillColors: [NSColor(hex: 0xFFFFFF, alpha: 0.12), NSColor(hex: 0xE6F2FF, alpha: 0.06)], stroke: NSColor(hex: 0xDCEEFF, alpha: 0.22), titleColor: NSColor(hex: 0xB7D1E8), textColor: NSColor.white, secondaryColor: NSColor(hex: 0xB9D4EA), shadow: NSColor.black.tinted(0.18))

    let topCardsHeight = 150.0
    let dueRect = CGRect(x: sideRect.minX + 16, y: sideRect.minY, width: sideRect.width - 16, height: topCardsHeight)
    let weatherRect = CGRect(x: sideRect.minX + 16, y: dueRect.maxY + 16, width: sideRect.width - 16, height: topCardsHeight)
    let newsRect = CGRect(x: sideRect.minX + 16, y: weatherRect.maxY + 16, width: sideRect.width - 16, height: 170)
    let mediaRect = CGRect(x: sideRect.minX + 16, y: newsRect.maxY + 16, width: sideRect.width - 16, height: sideRect.maxY - (newsRect.maxY + 16))
    drawRowsCard(title: "Due Soon", rows: payload.dueSoonRows, rect: dueRect, titleColor: NSColor(hex: 0xB7D1E8), primaryColor: NSColor.white, secondaryColor: NSColor(hex: 0xB9D4EA), fillColors: [NSColor(hex: 0xFFFFFF, alpha: 0.12), NSColor(hex: 0xE6F2FF, alpha: 0.06)], stroke: NSColor(hex: 0xDCEEFF, alpha: 0.22), shadow: NSColor.black.tinted(0.18), compact: true)
    drawWeatherCard(rect: weatherRect, payload: payload, titleColor: NSColor(hex: 0xB7D1E8), primaryColor: NSColor.white, secondaryColor: NSColor(hex: 0xB9D4EA), fillColors: [NSColor(hex: 0xFFFFFF, alpha: 0.12), NSColor(hex: 0xE6F2FF, alpha: 0.06)], stroke: NSColor(hex: 0xDCEEFF, alpha: 0.22), shadow: NSColor.black.tinted(0.18), largeMetric: false)
    drawRowsCard(title: "News", rows: payload.newsRows, rect: newsRect, titleColor: NSColor(hex: 0xB7D1E8), primaryColor: NSColor.white, secondaryColor: NSColor(hex: 0xB9D4EA), fillColors: [NSColor(hex: 0xFFFFFF, alpha: 0.12), NSColor(hex: 0xE6F2FF, alpha: 0.06)], stroke: NSColor(hex: 0xDCEEFF, alpha: 0.22), shadow: NSColor.black.tinted(0.18), compact: true)
    drawRowsCard(title: "Media", rows: payload.mediaRows, rect: mediaRect, titleColor: NSColor(hex: 0xB7D1E8), primaryColor: NSColor.white, secondaryColor: NSColor(hex: 0xB9D4EA), fillColors: [NSColor(hex: 0xFFFFFF, alpha: 0.12), NSColor(hex: 0xE6F2FF, alpha: 0.06)], stroke: NSColor(hex: 0xDCEEFF, alpha: 0.22), shadow: NSColor.black.tinted(0.18), compact: true)
}

func renderQuietColumns(_ concept: DashboardConcept, payload: DashboardPayload, in canvas: CGRect) {
    drawGradient(in: canvas, colors: [NSColor(hex: 0xFCFBF7), NSColor(hex: 0xF2EFE7)], angle: -90)
    drawGlow(in: CGRect(x: 1080, y: 80, width: 400, height: 200), color: NSColor(hex: 0xEDE4C9, alpha: 0.45))

    let outer = canvas.insetBy(dx: 62, dy: 48)
    let headerRect = CGRect(x: outer.minX, y: outer.minY, width: outer.width, height: 126)
    let summaryRect = CGRect(x: outer.minX, y: headerRect.maxY + 20, width: outer.width, height: 84)
    let chipsRect = CGRect(x: outer.minX, y: summaryRect.maxY + 18, width: outer.width, height: 62)
    let contentRect = CGRect(x: outer.minX, y: chipsRect.maxY + 24, width: outer.width, height: outer.maxY - (chipsRect.maxY + 24))
    let (timelineRect, sideRect) = contentRect.splitLeft(900)

    drawHeaderBlock(rect: headerRect, payload: payload, fillColors: [NSColor(hex: 0xFFFDF7), NSColor(hex: 0xFBF7EC)], stroke: NSColor(hex: 0xE5DDCC), titleColor: NSColor(hex: 0x2D2A25), primaryColor: NSColor(hex: 0x2D2A25), secondaryColor: NSColor(hex: 0x7A7366), shadow: NSColor.black.tinted(0.05), dateFont: makeFont("Avenir Next", size: 18, weight: .medium), heroFont: NSFont.monospacedSystemFont(ofSize: 42, weight: .bold))
    drawSummaryPanel(rect: summaryRect, summary: payload.summary, fillColors: [NSColor(hex: 0xFFFDF7), NSColor(hex: 0xF8F3E6)], stroke: NSColor(hex: 0xE5DDCC), textColor: NSColor(hex: 0x3C372E), shadow: nil)
    drawStatusChips(payload.chips, in: chipsRect, fill: NSColor(hex: 0xFFFDF7), stroke: NSColor(hex: 0xE5DDCC), labelColor: NSColor(hex: 0x857D71), valueColor: NSColor(hex: 0x2D2A25), compact: true)

    drawTimelinePanel(rect: timelineRect, sections: payload.timelineSections, fillColors: [NSColor(hex: 0xFFFDF7), NSColor(hex: 0xFBF7EC)], stroke: NSColor(hex: 0xE5DDCC), titleColor: NSColor(hex: 0x857D71), textColor: NSColor(hex: 0x2D2A25), secondaryColor: NSColor(hex: 0x7A7366), shadow: nil, compact: true)

    let firstTall = CGRect(x: sideRect.minX + 24, y: sideRect.minY, width: sideRect.width - 24, height: 168)
    let secondTall = CGRect(x: sideRect.minX + 24, y: firstTall.maxY + 18, width: sideRect.width - 24, height: 168)
    let third = CGRect(x: sideRect.minX + 24, y: secondTall.maxY + 18, width: sideRect.width - 24, height: 194)
    let fourth = CGRect(x: sideRect.minX + 24, y: third.maxY + 18, width: sideRect.width - 24, height: sideRect.maxY - (third.maxY + 18))
    drawRowsCard(title: "Due Soon", rows: payload.dueSoonRows, rect: firstTall, titleColor: NSColor(hex: 0x857D71), primaryColor: NSColor(hex: 0x2D2A25), secondaryColor: NSColor(hex: 0x7A7366), fillColors: [NSColor(hex: 0xFFFDF7), NSColor(hex: 0xFBF7EC)], stroke: NSColor(hex: 0xE5DDCC), compact: true)
    drawWeatherCard(rect: secondTall, payload: payload, titleColor: NSColor(hex: 0x857D71), primaryColor: NSColor(hex: 0x2D2A25), secondaryColor: NSColor(hex: 0x7A7366), fillColors: [NSColor(hex: 0xFFFDF7), NSColor(hex: 0xFBF7EC)], stroke: NSColor(hex: 0xE5DDCC), largeMetric: false)
    drawRowsCard(title: "News", rows: payload.newsRows, rect: third, titleColor: NSColor(hex: 0x857D71), primaryColor: NSColor(hex: 0x2D2A25), secondaryColor: NSColor(hex: 0x7A7366), fillColors: [NSColor(hex: 0xFFFDF7), NSColor(hex: 0xFBF7EC)], stroke: NSColor(hex: 0xE5DDCC), compact: true)
    drawRowsCard(title: "Media", rows: payload.mediaRows, rect: fourth, titleColor: NSColor(hex: 0x857D71), primaryColor: NSColor(hex: 0x2D2A25), secondaryColor: NSColor(hex: 0x7A7366), fillColors: [NSColor(hex: 0xFFFDF7), NSColor(hex: 0xFBF7EC)], stroke: NSColor(hex: 0xE5DDCC), compact: true)
}

func renderSignalBoard(_ concept: DashboardConcept, payload: DashboardPayload, in canvas: CGRect) {
    drawGradient(in: canvas, colors: [NSColor(hex: 0x081017), NSColor(hex: 0x0F1F2C), NSColor(hex: 0x142D40)], angle: -90)
    for column in stride(from: 40.0, to: canvas.width, by: 56.0) {
        drawRoundedRect(CGRect(x: column, y: 0, width: 1, height: canvas.height), radius: 0, fill: NSColor(hex: 0x6EC6FF, alpha: 0.06))
    }
    for row in stride(from: 36.0, to: canvas.height, by: 56.0) {
        drawRoundedRect(CGRect(x: 0, y: row, width: canvas.width, height: 1), radius: 0, fill: NSColor(hex: 0x6EC6FF, alpha: 0.05))
    }

    let outer = canvas.insetBy(dx: 44, dy: 40)
    let headerRect = CGRect(x: outer.minX, y: outer.minY, width: outer.width, height: 150)
    let chipsRect = CGRect(x: outer.minX, y: headerRect.maxY + 18, width: 560, height: 68)
    let summaryRect = CGRect(x: chipsRect.maxX + 16, y: headerRect.maxY + 18, width: outer.maxX - (chipsRect.maxX + 16), height: 68)
    let mainRect = CGRect(x: outer.minX, y: summaryRect.maxY + 20, width: outer.width, height: outer.maxY - (summaryRect.maxY + 20))
    let (timelineRect, sideRect) = mainRect.splitLeft(980)

    drawHeaderBlock(rect: headerRect, payload: payload, fillColors: [NSColor(hex: 0x0E1A23), NSColor(hex: 0x132633)], stroke: NSColor(hex: 0x335772), titleColor: NSColor(hex: 0xDDF5FF), primaryColor: NSColor(hex: 0xDDF5FF), secondaryColor: NSColor(hex: 0x8FB8D0), shadow: NSColor.black.tinted(0.35))
    drawStatusChips(payload.chips, in: chipsRect, fill: NSColor(hex: 0x0E1A23), stroke: NSColor(hex: 0x335772), labelColor: NSColor(hex: 0x8FB8D0), valueColor: NSColor(hex: 0xDDF5FF))
    drawSummaryPanel(rect: summaryRect, summary: payload.summary, fillColors: [NSColor(hex: 0x152936), NSColor(hex: 0x11212D)], stroke: NSColor(hex: 0x335772), textColor: NSColor(hex: 0xDDF5FF), shadow: NSColor.black.tinted(0.20))

    drawTimelinePanel(rect: timelineRect, sections: payload.timelineSections, fillColors: [NSColor(hex: 0x0E1A23), NSColor(hex: 0x132633)], stroke: NSColor(hex: 0x335772), titleColor: NSColor(hex: 0x8FB8D0), textColor: NSColor(hex: 0xDDF5FF), secondaryColor: NSColor(hex: 0x8FB8D0), shadow: NSColor.black.tinted(0.20), compact: true)

    let duoHeight = 160.0
    let dueRect = CGRect(x: sideRect.minX + 16, y: sideRect.minY, width: sideRect.width - 16, height: duoHeight)
    let weatherRect = CGRect(x: sideRect.minX + 16, y: dueRect.maxY + 16, width: sideRect.width - 16, height: duoHeight)
    let newsRect = CGRect(x: sideRect.minX + 16, y: weatherRect.maxY + 16, width: sideRect.width - 16, height: 214)
    let mediaRect = CGRect(x: sideRect.minX + 16, y: newsRect.maxY + 16, width: sideRect.width - 16, height: sideRect.maxY - (newsRect.maxY + 16))
    drawRowsCard(title: "Due Soon", rows: payload.dueSoonRows, rect: dueRect, titleColor: NSColor(hex: 0x8FB8D0), primaryColor: NSColor(hex: 0xDDF5FF), secondaryColor: NSColor(hex: 0x8FB8D0), fillColors: [NSColor(hex: 0x0E1A23), NSColor(hex: 0x132633)], stroke: NSColor(hex: 0x335772), shadow: NSColor.black.tinted(0.20), compact: true)
    drawWeatherCard(rect: weatherRect, payload: payload, titleColor: NSColor(hex: 0x8FB8D0), primaryColor: NSColor(hex: 0xDDF5FF), secondaryColor: NSColor(hex: 0x8FB8D0), fillColors: [NSColor(hex: 0x0E1A23), NSColor(hex: 0x132633)], stroke: NSColor(hex: 0x335772), shadow: NSColor.black.tinted(0.20), largeMetric: false)
    drawRowsCard(title: "News", rows: payload.newsRows, rect: newsRect, titleColor: NSColor(hex: 0x8FB8D0), primaryColor: NSColor(hex: 0xDDF5FF), secondaryColor: NSColor(hex: 0x8FB8D0), fillColors: [NSColor(hex: 0x0E1A23), NSColor(hex: 0x132633)], stroke: NSColor(hex: 0x335772), shadow: NSColor.black.tinted(0.20), compact: true)
    drawRowsCard(title: "Media", rows: payload.mediaRows, rect: mediaRect, titleColor: NSColor(hex: 0x8FB8D0), primaryColor: NSColor(hex: 0xDDF5FF), secondaryColor: NSColor(hex: 0x8FB8D0), fillColors: [NSColor(hex: 0x0E1A23), NSColor(hex: 0x132633)], stroke: NSColor(hex: 0x335772), shadow: NSColor.black.tinted(0.20), compact: true)
}

func renderBentoPulse(_ concept: DashboardConcept, payload: DashboardPayload, in canvas: CGRect) {
    drawGradient(in: canvas, colors: [NSColor(hex: 0xFBF2E8), NSColor(hex: 0xF0D9C2), NSColor(hex: 0xEBC3A2)], angle: -90)
    drawGlow(in: CGRect(x: 980, y: 80, width: 520, height: 260), color: NSColor(hex: 0xFFDDBA, alpha: 0.45))

    let outer = canvas.insetBy(dx: 46, dy: 42)
    let headerRect = CGRect(x: outer.minX, y: outer.minY, width: outer.width, height: 132)
    let mainRect = CGRect(x: outer.minX, y: headerRect.maxY + 18, width: outer.width, height: outer.maxY - (headerRect.maxY + 18))
    let leftWidth = 900.0
    let heroRect = CGRect(x: mainRect.minX, y: mainRect.minY, width: leftWidth, height: 170)
    let timelineRect = CGRect(x: mainRect.minX, y: heroRect.maxY + 18, width: leftWidth, height: mainRect.height - heroRect.height - 18)
    let rightX = heroRect.maxX + 18
    let rightWidth = mainRect.maxX - rightX
    let summaryRect = CGRect(x: rightX, y: mainRect.minY, width: rightWidth, height: 220)
    let weatherRect = CGRect(x: rightX, y: summaryRect.maxY + 18, width: (rightWidth - 18) / 2, height: 170)
    let dueRect = CGRect(x: weatherRect.maxX + 18, y: summaryRect.maxY + 18, width: (rightWidth - 18) / 2, height: 170)
    let newsRect = CGRect(x: rightX, y: weatherRect.maxY + 18, width: rightWidth, height: 196)
    let mediaRect = CGRect(x: rightX, y: newsRect.maxY + 18, width: rightWidth, height: mainRect.maxY - (newsRect.maxY + 18))

    drawHeaderBlock(rect: headerRect, payload: payload, fillColors: [NSColor(hex: 0xFFF9F2), NSColor(hex: 0xFAEAD6)], stroke: NSColor(hex: 0xE3C9A8), titleColor: NSColor(hex: 0x422E1E), primaryColor: NSColor(hex: 0x422E1E), secondaryColor: NSColor(hex: 0x896D54), shadow: NSColor.black.tinted(0.08))
    drawStatusChips(payload.chips, in: heroRect.insetBy(dx: 0, dy: 0), fill: NSColor(hex: 0xFFF9F2), stroke: NSColor(hex: 0xE3C9A8), labelColor: NSColor(hex: 0x896D54), valueColor: NSColor(hex: 0x422E1E))
    drawTimelinePanel(rect: timelineRect, sections: payload.timelineSections, fillColors: [NSColor(hex: 0xFFF9F2), NSColor(hex: 0xFAEAD6)], stroke: NSColor(hex: 0xE3C9A8), titleColor: NSColor(hex: 0x896D54), textColor: NSColor(hex: 0x422E1E), secondaryColor: NSColor(hex: 0x896D54), shadow: NSColor.black.tinted(0.08), compact: true)
    drawSummaryPanel(rect: summaryRect, summary: payload.summary, fillColors: [NSColor(hex: 0x4E3624), NSColor(hex: 0x69472F)], stroke: NSColor(hex: 0xA77B51), textColor: NSColor(hex: 0xFFF3E8), shadow: NSColor.black.tinted(0.18))
    drawWeatherCard(rect: weatherRect, payload: payload, titleColor: NSColor(hex: 0x896D54), primaryColor: NSColor(hex: 0x422E1E), secondaryColor: NSColor(hex: 0x896D54), fillColors: [NSColor(hex: 0xFFF9F2), NSColor(hex: 0xFAEAD6)], stroke: NSColor(hex: 0xE3C9A8), shadow: NSColor.black.tinted(0.08), largeMetric: false)
    drawRowsCard(title: "Due Soon", rows: payload.dueSoonRows, rect: dueRect, titleColor: NSColor(hex: 0x896D54), primaryColor: NSColor(hex: 0x422E1E), secondaryColor: NSColor(hex: 0x896D54), fillColors: [NSColor(hex: 0xFFF9F2), NSColor(hex: 0xFAEAD6)], stroke: NSColor(hex: 0xE3C9A8), shadow: NSColor.black.tinted(0.08), compact: true)
    drawRowsCard(title: "News", rows: payload.newsRows, rect: newsRect, titleColor: NSColor(hex: 0x896D54), primaryColor: NSColor(hex: 0x422E1E), secondaryColor: NSColor(hex: 0x896D54), fillColors: [NSColor(hex: 0xFFF9F2), NSColor(hex: 0xFAEAD6)], stroke: NSColor(hex: 0xE3C9A8), shadow: NSColor.black.tinted(0.08), compact: true)
    drawRowsCard(title: "Media", rows: payload.mediaRows, rect: mediaRect, titleColor: NSColor(hex: 0x896D54), primaryColor: NSColor(hex: 0x422E1E), secondaryColor: NSColor(hex: 0x896D54), fillColors: [NSColor(hex: 0xFFF9F2), NSColor(hex: 0xFAEAD6)], stroke: NSColor(hex: 0xE3C9A8), shadow: NSColor.black.tinted(0.08), compact: true)
}

func drawDayBand(title: String, items: [TimelineItemPayload], rect: CGRect, background: [NSColor], stroke: NSColor, titleColor: NSColor, textColor: NSColor, secondaryColor: NSColor) {
    drawPanel(rect, radius: 22, fillColors: background, stroke: stroke, shadow: NSColor.black.tinted(0.06))
    _ = drawText(title, in: CGRect(x: rect.minX + 20, y: rect.minY + 16, width: 200, height: 28), font: makeFont(nil, size: 22, weight: .bold, design: .rounded), color: titleColor)
    var itemY = rect.minY + 54
    let height = (rect.height - 70) / CGFloat(max(items.count, 1))
    for item in items {
        let rowRect = CGRect(x: rect.minX + 18, y: itemY, width: rect.width - 36, height: height - 8)
        drawRoundedRect(rowRect, radius: 16, fill: item.accent.tinted(0.10), stroke: item.accent.tinted(0.22))
        _ = drawText(item.time, in: CGRect(x: rowRect.minX + 14, y: rowRect.minY + 12, width: 70, height: 20), font: makeFont(nil, size: 14, weight: .bold, design: .rounded), color: secondaryColor)
        _ = drawText(item.title, in: CGRect(x: rowRect.minX + 86, y: rowRect.minY + 10, width: rowRect.width - 180, height: 22), font: makeFont(nil, size: 17, weight: .semibold), color: textColor)
        _ = drawText(item.detail, in: CGRect(x: rowRect.minX + 86, y: rowRect.minY + 32, width: rowRect.width - 180, height: 18), font: makeFont(nil, size: 12, weight: .medium), color: secondaryColor)
        let pillRect = CGRect(x: rowRect.maxX - 90, y: rowRect.minY + 10, width: 70, height: 22)
        drawOwnerPill(owner: item.owner, accent: item.accent, rect: pillRect, foreground: textColor)
        itemY += height
    }
}

func renderDaylineFocus(_ concept: DashboardConcept, payload: DashboardPayload, in canvas: CGRect) {
    drawGradient(in: canvas, colors: [NSColor(hex: 0xEEF4FA), NSColor(hex: 0xDAE6F3)], angle: -90)

    let outer = canvas.insetBy(dx: 42, dy: 42)
    let headerRect = CGRect(x: outer.minX, y: outer.minY, width: outer.width, height: 132)
    drawHeaderBlock(rect: headerRect, payload: payload, fillColors: [NSColor(hex: 0xFFFFFF), NSColor(hex: 0xF2F7FD)], stroke: NSColor(hex: 0xCBD8E8), titleColor: NSColor(hex: 0x17304A), primaryColor: NSColor(hex: 0x17304A), secondaryColor: NSColor(hex: 0x647990), shadow: NSColor.black.tinted(0.06))

    let chipsRect = CGRect(x: outer.minX, y: headerRect.maxY + 18, width: outer.width, height: 66)
    drawStatusChips(payload.chips, in: chipsRect, fill: NSColor(hex: 0xFFFFFF), stroke: NSColor(hex: 0xCBD8E8), labelColor: NSColor(hex: 0x647990), valueColor: NSColor(hex: 0x17304A), compact: true)

    let bandsY = chipsRect.maxY + 20
    let bandHeight = 180.0
    let todayRect = CGRect(x: outer.minX, y: bandsY, width: outer.width, height: bandHeight)
    let tomorrowRect = CGRect(x: outer.minX, y: todayRect.maxY + 16, width: outer.width, height: bandHeight)
    let upcomingRect = CGRect(x: outer.minX, y: tomorrowRect.maxY + 16, width: outer.width, height: bandHeight)
    drawDayBand(title: payload.timelineSections[0].title, items: payload.timelineSections[0].items, rect: todayRect, background: [NSColor(hex: 0xFFFFFF), NSColor(hex: 0xF6FAFF)], stroke: NSColor(hex: 0xCBD8E8), titleColor: NSColor(hex: 0x17304A), textColor: NSColor(hex: 0x17304A), secondaryColor: NSColor(hex: 0x647990))
    drawDayBand(title: payload.timelineSections[1].title, items: payload.timelineSections[1].items, rect: tomorrowRect, background: [NSColor(hex: 0xFFFFFF), NSColor(hex: 0xF6FAFF)], stroke: NSColor(hex: 0xCBD8E8), titleColor: NSColor(hex: 0x17304A), textColor: NSColor(hex: 0x17304A), secondaryColor: NSColor(hex: 0x647990))
    drawDayBand(title: payload.timelineSections[2].title, items: payload.timelineSections[2].items, rect: upcomingRect, background: [NSColor(hex: 0xFFFFFF), NSColor(hex: 0xF6FAFF)], stroke: NSColor(hex: 0xCBD8E8), titleColor: NSColor(hex: 0x17304A), textColor: NSColor(hex: 0x17304A), secondaryColor: NSColor(hex: 0x647990))

    let bottomY = upcomingRect.maxY + 18
    let bottomHeight = outer.maxY - bottomY
    let columnWidth = (outer.width - 32) / 3
    let weatherRect = CGRect(x: outer.minX, y: bottomY, width: columnWidth, height: bottomHeight)
    let dueRect = CGRect(x: weatherRect.maxX + 16, y: bottomY, width: columnWidth, height: bottomHeight)
    let newsRect = CGRect(x: dueRect.maxX + 16, y: bottomY, width: columnWidth, height: bottomHeight * 0.62)
    let mediaRect = CGRect(x: dueRect.maxX + 16, y: newsRect.maxY + 16, width: columnWidth, height: bottomHeight - newsRect.height - 16)
    drawWeatherCard(rect: weatherRect, payload: payload, titleColor: NSColor(hex: 0x647990), primaryColor: NSColor(hex: 0x17304A), secondaryColor: NSColor(hex: 0x647990), fillColors: [NSColor(hex: 0xFFFFFF), NSColor(hex: 0xF6FAFF)], stroke: NSColor(hex: 0xCBD8E8), shadow: NSColor.black.tinted(0.05))
    drawRowsCard(title: "Due Soon", rows: payload.dueSoonRows, rect: dueRect, titleColor: NSColor(hex: 0x647990), primaryColor: NSColor(hex: 0x17304A), secondaryColor: NSColor(hex: 0x647990), fillColors: [NSColor(hex: 0xFFFFFF), NSColor(hex: 0xF6FAFF)], stroke: NSColor(hex: 0xCBD8E8), shadow: NSColor.black.tinted(0.05))
    drawRowsCard(title: "News", rows: payload.newsRows, rect: newsRect, titleColor: NSColor(hex: 0x647990), primaryColor: NSColor(hex: 0x17304A), secondaryColor: NSColor(hex: 0x647990), fillColors: [NSColor(hex: 0xFFFFFF), NSColor(hex: 0xF6FAFF)], stroke: NSColor(hex: 0xCBD8E8), shadow: NSColor.black.tinted(0.05), compact: true)
    drawRowsCard(title: "Media", rows: payload.mediaRows, rect: mediaRect, titleColor: NSColor(hex: 0x647990), primaryColor: NSColor(hex: 0x17304A), secondaryColor: NSColor(hex: 0x647990), fillColors: [NSColor(hex: 0xFFFFFF), NSColor(hex: 0xF6FAFF)], stroke: NSColor(hex: 0xCBD8E8), shadow: NSColor.black.tinted(0.05), compact: true)
}

func renderCommandTheater(_ concept: DashboardConcept, payload: DashboardPayload, in canvas: CGRect) {
    drawGradient(in: canvas, colors: [NSColor(hex: 0x05080F), NSColor(hex: 0x0A1624), NSColor(hex: 0x10263B)], angle: -90)
    drawGlow(in: CGRect(x: 1020, y: 40, width: 540, height: 300), color: NSColor(hex: 0x4AC5FF, alpha: 0.12))

    let outer = canvas.insetBy(dx: 40, dy: 38)
    let leftStrip = CGRect(x: outer.minX, y: outer.minY, width: 350, height: outer.height)
    let middle = CGRect(x: leftStrip.maxX + 18, y: outer.minY, width: 760, height: outer.height)
    let rightStrip = CGRect(x: middle.maxX + 18, y: outer.minY, width: outer.maxX - (middle.maxX + 18), height: outer.height)

    drawPanel(leftStrip, radius: 28, fillColors: [NSColor(hex: 0x0E1620), NSColor(hex: 0x122233)], stroke: NSColor(hex: 0x2A4E66), shadow: NSColor.black.tinted(0.35))
    _ = drawText(payload.appName, in: CGRect(x: leftStrip.minX + 24, y: leftStrip.minY + 28, width: leftStrip.width - 48, height: 36), font: makeFont(nil, size: 32, weight: .bold, design: .rounded), color: NSColor(hex: 0xE9F8FF))
    _ = drawText(payload.dateLabel, in: CGRect(x: leftStrip.minX + 24, y: leftStrip.minY + 72, width: leftStrip.width - 48, height: 24), font: makeFont(nil, size: 18, weight: .medium), color: NSColor(hex: 0x8CB3C9))
    _ = drawText(payload.timeLabel, in: CGRect(x: leftStrip.minX + 24, y: leftStrip.minY + 128, width: leftStrip.width - 48, height: 72), font: NSFont.monospacedSystemFont(ofSize: 54, weight: .bold), color: NSColor(hex: 0xE9F8FF))
    _ = drawText(payload.weatherSummary, in: CGRect(x: leftStrip.minX + 24, y: leftStrip.minY + 214, width: leftStrip.width - 48, height: 28), font: makeFont(nil, size: 24, weight: .bold, design: .rounded), color: NSColor(hex: 0xCDEEFF))
    _ = drawText(payload.weatherDetail, in: CGRect(x: leftStrip.minX + 24, y: leftStrip.minY + 250, width: leftStrip.width - 48, height: 40), font: makeFont(nil, size: 15, weight: .medium), color: NSColor(hex: 0x8CB3C9), lineHeight: 20)
    drawSummaryPanel(rect: CGRect(x: leftStrip.minX + 18, y: leftStrip.minY + 330, width: leftStrip.width - 36, height: 228), summary: payload.summary, fillColors: [NSColor(hex: 0x163047), NSColor(hex: 0x12273A)], stroke: NSColor(hex: 0x2A4E66), textColor: NSColor(hex: 0xE9F8FF), shadow: nil)
    drawStatusChips(payload.chips, in: CGRect(x: leftStrip.minX + 18, y: leftStrip.maxY - 128, width: leftStrip.width - 36, height: 110), fill: NSColor(hex: 0x102030), stroke: NSColor(hex: 0x2A4E66), labelColor: NSColor(hex: 0x8CB3C9), valueColor: NSColor(hex: 0xE9F8FF), compact: true)

    drawTimelinePanel(rect: middle, sections: payload.timelineSections, fillColors: [NSColor(hex: 0x0E1620), NSColor(hex: 0x122233)], stroke: NSColor(hex: 0x2A4E66), titleColor: NSColor(hex: 0x8CB3C9), textColor: NSColor(hex: 0xE9F8FF), secondaryColor: NSColor(hex: 0x8CB3C9), shadow: NSColor.black.tinted(0.20))

    let topRect = CGRect(x: rightStrip.minX, y: rightStrip.minY, width: rightStrip.width, height: 240)
    let middleRect = CGRect(x: rightStrip.minX, y: topRect.maxY + 16, width: rightStrip.width, height: 220)
    let newsRect = CGRect(x: rightStrip.minX, y: middleRect.maxY + 16, width: rightStrip.width, height: 212)
    let mediaRect = CGRect(x: rightStrip.minX, y: newsRect.maxY + 16, width: rightStrip.width, height: rightStrip.maxY - (newsRect.maxY + 16))
    drawRowsCard(title: "Due Soon", rows: payload.dueSoonRows, rect: topRect, titleColor: NSColor(hex: 0x8CB3C9), primaryColor: NSColor(hex: 0xE9F8FF), secondaryColor: NSColor(hex: 0x8CB3C9), fillColors: [NSColor(hex: 0x0E1620), NSColor(hex: 0x122233)], stroke: NSColor(hex: 0x2A4E66), shadow: NSColor.black.tinted(0.20), compact: true)
    drawWeatherCard(rect: middleRect, payload: payload, titleColor: NSColor(hex: 0x8CB3C9), primaryColor: NSColor(hex: 0xE9F8FF), secondaryColor: NSColor(hex: 0x8CB3C9), fillColors: [NSColor(hex: 0x0E1620), NSColor(hex: 0x122233)], stroke: NSColor(hex: 0x2A4E66), shadow: NSColor.black.tinted(0.20), largeMetric: false)
    drawRowsCard(title: "News", rows: payload.newsRows, rect: newsRect, titleColor: NSColor(hex: 0x8CB3C9), primaryColor: NSColor(hex: 0xE9F8FF), secondaryColor: NSColor(hex: 0x8CB3C9), fillColors: [NSColor(hex: 0x0E1620), NSColor(hex: 0x122233)], stroke: NSColor(hex: 0x2A4E66), shadow: NSColor.black.tinted(0.20), compact: true)
    drawRowsCard(title: "Media", rows: payload.mediaRows, rect: mediaRect, titleColor: NSColor(hex: 0x8CB3C9), primaryColor: NSColor(hex: 0xE9F8FF), secondaryColor: NSColor(hex: 0x8CB3C9), fillColors: [NSColor(hex: 0x0E1620), NSColor(hex: 0x122233)], stroke: NSColor(hex: 0x2A4E66), shadow: NSColor.black.tinted(0.20), compact: true)
}

func renderEditorialDesk(_ concept: DashboardConcept, payload: DashboardPayload, in canvas: CGRect) {
    drawGradient(in: canvas, colors: [NSColor(hex: 0xF6F0E2), NSColor(hex: 0xEADFC8)], angle: -90)
    drawRoundedRect(CGRect(x: 0, y: 140, width: canvas.width, height: 2), radius: 0, fill: NSColor(hex: 0xD8C8A7, alpha: 0.65))

    let outer = canvas.insetBy(dx: 58, dy: 44)
    _ = drawText(payload.appName.uppercased(), in: CGRect(x: outer.minX, y: outer.minY, width: 600, height: 52), font: makeFont("Georgia-Bold", size: 40), color: NSColor(hex: 0x2B241C))
    _ = drawText(payload.dateLabel, in: CGRect(x: outer.minX, y: outer.minY + 54, width: 320, height: 22), font: makeFont("Avenir Next", size: 18, weight: .medium), color: NSColor(hex: 0x6F6557))
    _ = drawText(payload.summary, in: CGRect(x: outer.minX + 420, y: outer.minY + 8, width: 720, height: 72), font: makeFont("Georgia", size: 20), color: NSColor(hex: 0x40382D), lineHeight: 28)
    _ = drawText(payload.timeLabel, in: CGRect(x: outer.maxX - 220, y: outer.minY + 8, width: 200, height: 42), font: NSFont.monospacedSystemFont(ofSize: 34, weight: .bold), color: NSColor(hex: 0x2B241C), alignment: .right)
    _ = drawText(payload.weatherSummary, in: CGRect(x: outer.maxX - 220, y: outer.minY + 52, width: 200, height: 22), font: makeFont("Avenir Next", size: 17, weight: .semibold), color: NSColor(hex: 0x6F6557), alignment: .right)

    let contentTop = outer.minY + 110
    let leftColWidth = 580.0
    let middleColWidth = 430.0
    let gap = 22.0
    let rightColWidth = outer.width - leftColWidth - middleColWidth - gap * 2
    let leftCol = CGRect(x: outer.minX, y: contentTop, width: leftColWidth, height: outer.maxY - contentTop)
    let middleCol = CGRect(x: leftCol.maxX + gap, y: contentTop, width: middleColWidth, height: outer.maxY - contentTop)
    let rightCol = CGRect(x: middleCol.maxX + gap, y: contentTop, width: rightColWidth, height: outer.maxY - contentTop)

    drawTimelinePanel(rect: leftCol, sections: [payload.timelineSections[0]], fillColors: [NSColor(hex: 0xFFF9EE), NSColor(hex: 0xF6EEDC)], stroke: NSColor(hex: 0xD8C8A7), titleColor: NSColor(hex: 0x6F6557), textColor: NSColor(hex: 0x2B241C), secondaryColor: NSColor(hex: 0x6F6557), shadow: nil, compact: true, showSectionBoxes: false)
    drawTimelinePanel(rect: CGRect(x: middleCol.minX, y: middleCol.minY, width: middleCol.width, height: 290), sections: [payload.timelineSections[1]], fillColors: [NSColor(hex: 0xFFF9EE), NSColor(hex: 0xF6EEDC)], stroke: NSColor(hex: 0xD8C8A7), titleColor: NSColor(hex: 0x6F6557), textColor: NSColor(hex: 0x2B241C), secondaryColor: NSColor(hex: 0x6F6557), shadow: nil, compact: true, showSectionBoxes: false)
    drawTimelinePanel(rect: CGRect(x: middleCol.minX, y: middleCol.minY + 308, width: middleCol.width, height: middleCol.height - 308), sections: [payload.timelineSections[2]], fillColors: [NSColor(hex: 0xFFF9EE), NSColor(hex: 0xF6EEDC)], stroke: NSColor(hex: 0xD8C8A7), titleColor: NSColor(hex: 0x6F6557), textColor: NSColor(hex: 0x2B241C), secondaryColor: NSColor(hex: 0x6F6557), shadow: nil, compact: true, showSectionBoxes: false)

    drawWeatherCard(rect: CGRect(x: rightCol.minX, y: rightCol.minY, width: rightCol.width, height: 170), payload: payload, titleColor: NSColor(hex: 0x6F6557), primaryColor: NSColor(hex: 0x2B241C), secondaryColor: NSColor(hex: 0x6F6557), fillColors: [NSColor(hex: 0xFFF9EE), NSColor(hex: 0xF6EEDC)], stroke: NSColor(hex: 0xD8C8A7), largeMetric: false)
    drawRowsCard(title: "Due Soon", rows: payload.dueSoonRows, rect: CGRect(x: rightCol.minX, y: rightCol.minY + 188, width: rightCol.width, height: 190), titleColor: NSColor(hex: 0x6F6557), primaryColor: NSColor(hex: 0x2B241C), secondaryColor: NSColor(hex: 0x6F6557), fillColors: [NSColor(hex: 0xFFF9EE), NSColor(hex: 0xF6EEDC)], stroke: NSColor(hex: 0xD8C8A7), compact: true)
    drawRowsCard(title: "News", rows: payload.newsRows, rect: CGRect(x: rightCol.minX, y: rightCol.minY + 396, width: rightCol.width, height: 214), titleColor: NSColor(hex: 0x6F6557), primaryColor: NSColor(hex: 0x2B241C), secondaryColor: NSColor(hex: 0x6F6557), fillColors: [NSColor(hex: 0xFFF9EE), NSColor(hex: 0xF6EEDC)], stroke: NSColor(hex: 0xD8C8A7), compact: true)
    drawRowsCard(title: "Media", rows: payload.mediaRows, rect: CGRect(x: rightCol.minX, y: rightCol.minY + 628, width: rightCol.width, height: rightCol.height - 628), titleColor: NSColor(hex: 0x6F6557), primaryColor: NSColor(hex: 0x2B241C), secondaryColor: NSColor(hex: 0x6F6557), fillColors: [NSColor(hex: 0xFFF9EE), NSColor(hex: 0xF6EEDC)], stroke: NSColor(hex: 0xD8C8A7), compact: true)
}

func renderBeaconWall(_ concept: DashboardConcept, payload: DashboardPayload, in canvas: CGRect) {
    drawGradient(in: canvas, colors: [NSColor(hex: 0x0E3045), NSColor(hex: 0x145D79), NSColor(hex: 0x1E8094)], angle: -90)
    drawGlow(in: CGRect(x: -80, y: 120, width: 540, height: 540), color: NSColor(hex: 0xB3F2FF, alpha: 0.16))
    drawGlow(in: CGRect(x: 1090, y: 90, width: 420, height: 240), color: NSColor(hex: 0xDDFBFF, alpha: 0.18))

    let outer = canvas.insetBy(dx: 42, dy: 42)
    let heroRect = CGRect(x: outer.minX, y: outer.minY, width: outer.width, height: 250)
    drawPanel(heroRect, radius: 30, fillColors: [NSColor(hex: 0x0E2433, alpha: 0.66), NSColor(hex: 0x163C4F, alpha: 0.56)], stroke: NSColor(hex: 0xD8FBFF, alpha: 0.26), shadow: NSColor.black.tinted(0.30))
    _ = drawText(payload.appName, in: CGRect(x: heroRect.minX + 26, y: heroRect.minY + 26, width: 340, height: 38), font: makeFont(nil, size: 34, weight: .bold, design: .rounded), color: NSColor.white)
    _ = drawText(payload.dateLabel, in: CGRect(x: heroRect.minX + 26, y: heroRect.minY + 72, width: 340, height: 24), font: makeFont(nil, size: 20, weight: .medium), color: NSColor(hex: 0xCBEAF2))
    _ = drawText(payload.summary, in: CGRect(x: heroRect.minX + 26, y: heroRect.minY + 112, width: 690, height: 96), font: makeFont(nil, size: 26, weight: .semibold, design: .rounded), color: NSColor.white, lineHeight: 32)
    _ = drawText(payload.timeLabel, in: CGRect(x: heroRect.maxX - 340, y: heroRect.minY + 26, width: 300, height: 78), font: NSFont.monospacedSystemFont(ofSize: 66, weight: .bold), color: NSColor.white, alignment: .right)
    _ = drawText(payload.weatherSummary, in: CGRect(x: heroRect.maxX - 340, y: heroRect.minY + 114, width: 300, height: 34), font: makeFont(nil, size: 28, weight: .bold, design: .rounded), color: NSColor(hex: 0xDDFBFF), alignment: .right)
    _ = drawText(payload.weatherDetail, in: CGRect(x: heroRect.maxX - 340, y: heroRect.minY + 152, width: 300, height: 46), font: makeFont(nil, size: 16, weight: .medium), color: NSColor(hex: 0xCBEAF2), alignment: .right, lineHeight: 20)
    drawStatusChips(payload.chips, in: CGRect(x: heroRect.minX + 740, y: heroRect.minY + 160, width: 440, height: 64), fill: NSColor(hex: 0xFFFFFF, alpha: 0.10), stroke: NSColor(hex: 0xD8FBFF, alpha: 0.18), labelColor: NSColor(hex: 0xCBEAF2), valueColor: NSColor.white, compact: true)

    let belowHeroY = heroRect.maxY + 20
    let leftWidth = 760.0
    let centerWidth = 350.0
    let gap = 18.0
    let rightWidth = outer.width - leftWidth - centerWidth - gap * 2
    let leftRect = CGRect(x: outer.minX, y: belowHeroY, width: leftWidth, height: outer.maxY - belowHeroY)
    let centerRect = CGRect(x: leftRect.maxX + gap, y: belowHeroY, width: centerWidth, height: outer.maxY - belowHeroY)
    let rightRect = CGRect(x: centerRect.maxX + gap, y: belowHeroY, width: rightWidth, height: outer.maxY - belowHeroY)

    drawTimelinePanel(rect: leftRect, sections: payload.timelineSections, fillColors: [NSColor(hex: 0x0E2433, alpha: 0.66), NSColor(hex: 0x163C4F, alpha: 0.56)], stroke: NSColor(hex: 0xD8FBFF, alpha: 0.22), titleColor: NSColor(hex: 0xCBEAF2), textColor: NSColor.white, secondaryColor: NSColor(hex: 0xCBEAF2), shadow: NSColor.black.tinted(0.20), compact: true)
    drawRowsCard(title: "Due Soon", rows: payload.dueSoonRows, rect: CGRect(x: centerRect.minX, y: centerRect.minY, width: centerRect.width, height: 214), titleColor: NSColor(hex: 0xCBEAF2), primaryColor: NSColor.white, secondaryColor: NSColor(hex: 0xCBEAF2), fillColors: [NSColor(hex: 0x0E2433, alpha: 0.66), NSColor(hex: 0x163C4F, alpha: 0.56)], stroke: NSColor(hex: 0xD8FBFF, alpha: 0.22), shadow: NSColor.black.tinted(0.20), compact: true)
    drawWeatherCard(rect: CGRect(x: centerRect.minX, y: centerRect.minY + 232, width: centerRect.width, height: 210), payload: payload, titleColor: NSColor(hex: 0xCBEAF2), primaryColor: NSColor.white, secondaryColor: NSColor(hex: 0xCBEAF2), fillColors: [NSColor(hex: 0x0E2433, alpha: 0.66), NSColor(hex: 0x163C4F, alpha: 0.56)], stroke: NSColor(hex: 0xD8FBFF, alpha: 0.22), shadow: NSColor.black.tinted(0.20))
    drawRowsCard(title: "Media", rows: payload.mediaRows, rect: CGRect(x: centerRect.minX, y: centerRect.minY + 460, width: centerRect.width, height: centerRect.height - 460), titleColor: NSColor(hex: 0xCBEAF2), primaryColor: NSColor.white, secondaryColor: NSColor(hex: 0xCBEAF2), fillColors: [NSColor(hex: 0x0E2433, alpha: 0.66), NSColor(hex: 0x163C4F, alpha: 0.56)], stroke: NSColor(hex: 0xD8FBFF, alpha: 0.22), shadow: NSColor.black.tinted(0.20), compact: true)
    drawRowsCard(title: "News", rows: payload.newsRows, rect: rightRect, titleColor: NSColor(hex: 0xCBEAF2), primaryColor: NSColor.white, secondaryColor: NSColor(hex: 0xCBEAF2), fillColors: [NSColor(hex: 0x0E2433, alpha: 0.66), NSColor(hex: 0x163C4F, alpha: 0.56)], stroke: NSColor(hex: 0xD8FBFF, alpha: 0.22), shadow: NSColor.black.tinted(0.20))
}

func renderConcept(_ concept: DashboardConcept, payload: DashboardPayload, in canvas: CGRect) {
    switch concept.layout {
    case .morningLedger:
        renderMorningLedger(concept, payload: payload, in: canvas)
    case .glassRail:
        renderGlassRail(concept, payload: payload, in: canvas)
    case .quietColumns:
        renderQuietColumns(concept, payload: payload, in: canvas)
    case .signalBoard:
        renderSignalBoard(concept, payload: payload, in: canvas)
    case .bentoPulse:
        renderBentoPulse(concept, payload: payload, in: canvas)
    case .daylineFocus:
        renderDaylineFocus(concept, payload: payload, in: canvas)
    case .commandTheater:
        renderCommandTheater(concept, payload: payload, in: canvas)
    case .editorialDesk:
        renderEditorialDesk(concept, payload: payload, in: canvas)
    case .beaconWall:
        renderBeaconWall(concept, payload: payload, in: canvas)
    }
}

func renderImage(size: CGSize, concept: DashboardConcept, payload: DashboardPayload) -> NSImage {
    NSImage(size: size, flipped: true) { rect in
        renderConcept(concept, payload: payload, in: rect)
        return true
    }
}

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "DashboardConcepts", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG data."])
    }
    try data.write(to: url)
}

func renderContactSheet(concepts: [DashboardConcept], previewsURL: URL, size: CGSize) -> NSImage {
    let images: [(DashboardConcept, NSImage)] = concepts.compactMap { concept in
        let url = previewsURL.appendingPathComponent("\(concept.slug).png")
        guard let image = NSImage(contentsOf: url) else { return nil }
        return (concept, image)
    }

    return NSImage(size: size, flipped: true) { rect in
        drawGradient(in: rect, colors: [NSColor(hex: 0xF4F7FB), NSColor(hex: 0xE6EEF7)], angle: -90)
        _ = drawText("Dashboard Concept Pack", in: CGRect(x: 42, y: 34, width: 500, height: 38), font: makeFont(nil, size: 32, weight: .bold, design: .rounded), color: NSColor(hex: 0x132B44))
        _ = drawText("Nine directions using the same frozen payload", in: CGRect(x: 42, y: 72, width: 500, height: 24), font: makeFont(nil, size: 18, weight: .medium), color: NSColor(hex: 0x687D94))

        let columns = 3
        let gap: CGFloat = 18
        let top: CGFloat = 118
        let cardWidth = (rect.width - 42 * 2 - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let cardHeight: CGFloat = 390

        for (index, entry) in images.enumerated() {
            let row = index / columns
            let column = index % columns
            let x = 42 + CGFloat(column) * (cardWidth + gap)
            let y = top + CGFloat(row) * (cardHeight + gap)
            let cardRect = CGRect(x: x, y: y, width: cardWidth, height: cardHeight)
            drawRoundedRect(cardRect, radius: 24, fill: NSColor.white, stroke: NSColor(hex: 0xD1DDEA))
            let imageRect = CGRect(x: cardRect.minX + 16, y: cardRect.minY + 16, width: cardRect.width - 32, height: 248)
            entry.1.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)
            _ = drawText(entry.0.tier.rawValue, in: CGRect(x: cardRect.minX + 18, y: cardRect.minY + 278, width: cardRect.width - 36, height: 18), font: makeFont(nil, size: 12, weight: .bold, design: .rounded), color: NSColor(hex: 0x6A7E95), uppercase: true)
            _ = drawText(entry.0.title, in: CGRect(x: cardRect.minX + 18, y: cardRect.minY + 300, width: cardRect.width - 36, height: 26), font: makeFont(nil, size: 22, weight: .bold, design: .rounded), color: NSColor(hex: 0x132B44))
            _ = drawText(entry.0.intent, in: CGRect(x: cardRect.minX + 18, y: cardRect.minY + 332, width: cardRect.width - 36, height: 44), font: makeFont(nil, size: 14, weight: .medium), color: NSColor(hex: 0x52667C), lineHeight: 18)
        }
        return true
    }
}

func main() throws {
    let fileManager = FileManager.default
    let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
    let baseURL = currentDirectory.appendingPathComponent("design/dashboard-concepts", isDirectory: true)
    let previewsURL = baseURL.appendingPathComponent("previews", isDirectory: true)

    try fileManager.createDirectory(at: previewsURL, withIntermediateDirectories: true)

    for concept in concepts {
        let image = renderImage(size: canvasSize, concept: concept, payload: .frozen)
        try savePNG(image, to: previewsURL.appendingPathComponent("\(concept.slug).png"))
    }

    let contactSheet = renderContactSheet(concepts: concepts, previewsURL: previewsURL, size: CGSize(width: 1800, height: 1360))
    try savePNG(contactSheet, to: previewsURL.appendingPathComponent("contact-sheet.png"))
}

do {
    try main()
} catch {
    fputs("dashboard concept render failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
