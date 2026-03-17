#!/usr/bin/env swift

import AppKit
import Foundation

enum IconConcept: String, CaseIterable {
    case glassDashboardTile = "glass-dashboard-tile"
    case splitPanelConsole = "split-panel-console"
    case beaconConsoleWindow = "beacon-console-window"
    case readyRoomFinal = "ready-room-final"
}

struct Options {
    let concept: IconConcept
    let size: CGFloat
    let outputPath: String
}

enum ArgumentError: Error, CustomStringConvertible {
    case missingValue(String)
    case invalidConcept(String)
    case invalidSize(String)
    case missingRequiredArguments

    var description: String {
        switch self {
        case .missingValue(let flag):
            return "Missing value for \(flag)"
        case .invalidConcept(let value):
            let allowed = IconConcept.allCases.map(\.rawValue).joined(separator: ", ")
            return "Invalid concept '\(value)'. Allowed values: \(allowed)"
        case .invalidSize(let value):
            return "Invalid size '\(value)'. Size must be a positive number."
        case .missingRequiredArguments:
            return "Usage: swift scripts/render_app_icon.swift --concept <concept> --size <pixels> --output <path>"
        }
    }
}

struct Palette {
    let navyTop = NSColor(red: 0.07, green: 0.13, blue: 0.24, alpha: 1)
    let navyBottom = NSColor(red: 0.17, green: 0.25, blue: 0.37, alpha: 1)
    let blueShadow = NSColor(red: 0.02, green: 0.06, blue: 0.14, alpha: 0.42)
    let pearl = NSColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1)
    let softGlass = NSColor(red: 0.93, green: 0.97, blue: 1.0, alpha: 0.16)
    let coolGlass = NSColor(red: 0.76, green: 0.86, blue: 1.0, alpha: 0.10)
    let panelStroke = NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.20)
    let lineBright = NSColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 0.72)
    let lineMuted = NSColor(red: 0.84, green: 0.90, blue: 0.98, alpha: 0.26)

    let john = NSColor(red: 0x34 / 255, green: 0x78 / 255, blue: 0xF6 / 255, alpha: 1)
    let amy = NSColor(red: 0x39 / 255, green: 0xA9 / 255, blue: 0x6B / 255, alpha: 1)
    let ellie = NSColor(red: 0xB5 / 255, green: 0x8A / 255, blue: 0xF7 / 255, alpha: 1)
    let mia = NSColor(red: 0x7E / 255, green: 0xCF / 255, blue: 0xFF / 255, alpha: 1)
}

private let palette = Palette()

func parseArguments() throws -> Options {
    var conceptValue: String?
    var outputPath: String?
    var sizeValue: String?

    var index = 1
    let arguments = CommandLine.arguments
    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--concept":
            index += 1
            guard index < arguments.count else { throw ArgumentError.missingValue(argument) }
            conceptValue = arguments[index]
        case "--output":
            index += 1
            guard index < arguments.count else { throw ArgumentError.missingValue(argument) }
            outputPath = arguments[index]
        case "--size":
            index += 1
            guard index < arguments.count else { throw ArgumentError.missingValue(argument) }
            sizeValue = arguments[index]
        case "--help":
            throw ArgumentError.missingRequiredArguments
        default:
            break
        }
        index += 1
    }

    guard let conceptString = conceptValue,
          let concept = IconConcept(rawValue: conceptString),
          let outputPath,
          let sizeString = sizeValue
    else {
        if let conceptValue, IconConcept(rawValue: conceptValue) == nil {
            throw ArgumentError.invalidConcept(conceptValue)
        }
        throw ArgumentError.missingRequiredArguments
    }

    guard let size = Double(sizeString), size > 0 else {
        throw ArgumentError.invalidSize(sizeString)
    }

    return Options(concept: concept, size: CGFloat(size), outputPath: outputPath)
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

func withGraphicsState(_ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    body()
    NSGraphicsContext.restoreGraphicsState()
}

func drawShadow(color: NSColor, blur: CGFloat, offset: CGSize = .zero, body: () -> Void) {
    withGraphicsState {
        let shadow = NSShadow()
        shadow.shadowColor = color
        shadow.shadowBlurRadius = blur
        shadow.shadowOffset = offset
        shadow.set()
        body()
    }
}

func drawGradient(in rect: CGRect, radius: CGFloat, colors: [NSColor], angle: CGFloat) {
    guard let gradient = NSGradient(colors: colors) else { return }
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    gradient.draw(in: path, angle: angle)
}

func drawRadialGlow(in rect: CGRect, color: NSColor, center: CGPoint) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }

    let cgColorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
    let locations: [CGFloat] = [0, 1]
    guard let gradient = CGGradient(colorsSpace: cgColorSpace, colors: colors, locations: locations) else { return }

    context.saveGState()
    context.addEllipse(in: rect)
    context.clip()
    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: max(rect.width, rect.height) * 0.6,
        options: [.drawsAfterEndLocation]
    )
    context.restoreGState()
}

func drawSurfaceHighlights(in rect: CGRect, radius: CGFloat) {
    withGraphicsState {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        path.addClip()

        drawRadialGlow(
            in: CGRect(x: rect.minX - rect.width * 0.18,
                       y: rect.midY + rect.height * 0.08,
                       width: rect.width * 0.78,
                       height: rect.height * 0.70),
            color: palette.pearl.withAlphaComponent(0.24),
            center: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY - rect.height * 0.15)
        )

        drawRadialGlow(
            in: CGRect(x: rect.maxX - rect.width * 0.44,
                       y: rect.minY - rect.height * 0.08,
                       width: rect.width * 0.55,
                       height: rect.height * 0.40),
            color: palette.mia.withAlphaComponent(0.14),
            center: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.05)
        )

        let sheenRect = CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height * 0.45)
        guard let sheen = NSGradient(colors: [
            palette.pearl.withAlphaComponent(0.19),
            palette.pearl.withAlphaComponent(0.05),
            NSColor.clear
        ]) else { return }
        sheen.draw(in: NSBezierPath(rect: sheenRect), angle: -90)
    }
}

func drawBaseIconSurface(in canvas: CGRect) -> CGRect {
    let inset = canvas.width * 0.08
    let rect = canvas.insetBy(dx: inset, dy: inset)
    let radius = rect.width * 0.24

    drawShadow(color: palette.blueShadow, blur: canvas.width * 0.07, offset: CGSize(width: 0, height: -canvas.width * 0.018)) {
        drawGradient(
            in: rect,
            radius: radius,
            colors: [palette.navyTop, palette.navyBottom],
            angle: -72
        )
    }

    drawSurfaceHighlights(in: rect, radius: radius)

    withGraphicsState {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        path.addClip()

        let topBand = CGRect(x: rect.minX, y: rect.midY + rect.height * 0.06, width: rect.width, height: rect.height * 0.28)
        guard let topGradient = NSGradient(colors: [
            palette.pearl.withAlphaComponent(0.16),
            NSColor.clear
        ]) else { return }
        topGradient.draw(in: NSBezierPath(rect: topBand), angle: -90)
    }

    let border = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    palette.panelStroke.withAlphaComponent(0.28).setStroke()
    border.lineWidth = canvas.width * 0.003
    border.stroke()

    return rect
}

func drawGlassPanel(in rect: CGRect, radius: CGFloat, tint: NSColor? = nil, tilt: CGFloat = -90) {
    drawShadow(color: palette.blueShadow.withAlphaComponent(0.22), blur: rect.width * 0.12, offset: CGSize(width: 0, height: -rect.width * 0.03)) {
        drawGradient(
            in: rect,
            radius: radius,
            colors: [
                palette.softGlass,
                (tint ?? palette.coolGlass).withAlphaComponent(0.16),
                NSColor.white.withAlphaComponent(0.08)
            ],
            angle: tilt
        )
    }

    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    palette.panelStroke.setStroke()
    path.lineWidth = max(rect.width * 0.008, 2)
    path.stroke()

    withGraphicsState {
        path.addClip()
        let sheenRect = CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height * 0.48)
        guard let gradient = NSGradient(colors: [
            palette.pearl.withAlphaComponent(0.21),
            NSColor.clear
        ]) else { return }
        gradient.draw(in: NSBezierPath(rect: sheenRect), angle: -90)
    }
}

func drawAccentRail(in rect: CGRect, colors: [NSColor]) {
    let clipPath = NSBezierPath(roundedRect: rect, xRadius: rect.width / 2, yRadius: rect.width / 2)
    withGraphicsState {
        clipPath.addClip()
        drawRoundedRect(rect, radius: rect.width / 2, fill: NSColor.white.withAlphaComponent(0.06))

        let spacing = rect.height * 0.025
        let segmentHeight = (rect.height - spacing * CGFloat(colors.count - 1)) / CGFloat(colors.count)
        var currentY = rect.minY
        for color in colors {
            let segment = CGRect(x: rect.minX, y: currentY, width: rect.width, height: segmentHeight)
            drawRoundedRect(segment, radius: rect.width / 2, fill: color)
            currentY += segmentHeight + spacing
        }
    }

    clipPath.lineWidth = max(rect.width * 0.06, 1.5)
    palette.panelStroke.withAlphaComponent(0.32).setStroke()
    clipPath.stroke()
}

func drawBars(in rect: CGRect, widths: [CGFloat], color: NSColor, height: CGFloat, spacing: CGFloat) {
    var y = rect.maxY - height
    for widthRatio in widths {
        let lineRect = CGRect(x: rect.minX,
                              y: y,
                              width: rect.width * widthRatio,
                              height: height)
        drawRoundedRect(lineRect, radius: height / 2, fill: color)
        y -= height + spacing
    }
}

func drawStatusDots(center: CGPoint, radius: CGFloat, colors: [NSColor]) {
    let spacing = radius * 2.2
    let totalWidth = CGFloat(colors.count - 1) * spacing
    var x = center.x - totalWidth / 2

    for color in colors {
        let dotRect = CGRect(x: x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        drawShadow(color: color.withAlphaComponent(0.28), blur: radius * 1.2) {
            drawRoundedRect(dotRect, radius: radius, fill: color, stroke: NSColor.white.withAlphaComponent(0.26), lineWidth: max(radius * 0.12, 1))
        }
        x += spacing
    }
}

func drawDashboardModules(in rect: CGRect) {
    let topCard = CGRect(x: rect.minX, y: rect.midY + rect.height * 0.06, width: rect.width * 0.92, height: rect.height * 0.26)
    let lowerLeft = CGRect(x: rect.minX, y: rect.minY + rect.height * 0.18, width: rect.width * 0.42, height: rect.height * 0.22)
    let lowerRight = CGRect(x: lowerLeft.maxX + rect.width * 0.06, y: lowerLeft.minY, width: rect.width * 0.44, height: rect.height * 0.22)

    drawRoundedRect(topCard, radius: topCard.height * 0.32, fill: palette.pearl.withAlphaComponent(0.20))
    drawRoundedRect(lowerLeft, radius: lowerLeft.height * 0.30, fill: palette.pearl.withAlphaComponent(0.15))
    drawRoundedRect(lowerRight, radius: lowerRight.height * 0.30, fill: palette.coolGlass.withAlphaComponent(0.18))

    let topLineRect = topCard.insetBy(dx: topCard.width * 0.08, dy: topCard.height * 0.24)
    drawBars(
        in: CGRect(x: topLineRect.minX,
                   y: topLineRect.minY,
                   width: topLineRect.width,
                   height: topCard.height * 0.52),
        widths: [0.64, 0.84],
        color: palette.lineBright,
        height: topCard.height * 0.12,
        spacing: topCard.height * 0.13
    )

    drawBars(
        in: lowerLeft.insetBy(dx: lowerLeft.width * 0.14, dy: lowerLeft.height * 0.25),
        widths: [0.72, 0.48],
        color: palette.lineMuted,
        height: lowerLeft.height * 0.12,
        spacing: lowerLeft.height * 0.14
    )

    drawBars(
        in: lowerRight.insetBy(dx: lowerRight.width * 0.14, dy: lowerRight.height * 0.25),
        widths: [0.58, 0.78],
        color: palette.lineMuted,
        height: lowerRight.height * 0.12,
        spacing: lowerRight.height * 0.14
    )
}

func drawBriefingSheet(in rect: CGRect, accentDot: NSColor, chipColor: NSColor? = nil) {
    let bodyRect = rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.16)
    drawBars(
        in: CGRect(x: bodyRect.minX,
                   y: bodyRect.midY - bodyRect.height * 0.08,
                   width: bodyRect.width,
                   height: bodyRect.height * 0.70),
        widths: [0.56, 0.84, 0.74, 0.68],
        color: palette.lineBright,
        height: rect.height * 0.032,
        spacing: rect.height * 0.046
    )

    let chipRect = CGRect(x: bodyRect.minX,
                          y: rect.minY + rect.height * 0.16,
                          width: rect.width * 0.30,
                          height: rect.height * 0.10)
    drawRoundedRect(chipRect, radius: chipRect.height / 2, fill: (chipColor ?? accentDot).withAlphaComponent(0.24))

    let dotRect = CGRect(x: rect.maxX - rect.width * 0.22,
                         y: rect.maxY - rect.height * 0.22,
                         width: rect.width * 0.08,
                         height: rect.width * 0.08)
    drawRoundedRect(dotRect, radius: dotRect.width / 2, fill: accentDot)
}

func drawGlassDashboardTile(base: CGRect) {
    let dashboardCard = CGRect(x: base.minX + base.width * 0.15,
                               y: base.minY + base.height * 0.20,
                               width: base.width * 0.41,
                               height: base.height * 0.50)
    let briefingCard = CGRect(x: base.minX + base.width * 0.50,
                              y: base.minY + base.height * 0.30,
                              width: base.width * 0.27,
                              height: base.height * 0.38)

    drawGlassPanel(in: dashboardCard, radius: dashboardCard.width * 0.16, tint: palette.mia.withAlphaComponent(0.18), tilt: -95)
    drawGlassPanel(in: briefingCard, radius: briefingCard.width * 0.22, tint: palette.ellie.withAlphaComponent(0.16), tilt: -85)

    let accentRailRect = CGRect(x: dashboardCard.minX + dashboardCard.width * 0.08,
                                y: dashboardCard.minY + dashboardCard.height * 0.14,
                                width: dashboardCard.width * 0.065,
                                height: dashboardCard.height * 0.72)
    drawAccentRail(in: accentRailRect, colors: [palette.john, palette.amy, palette.ellie, palette.mia])

    let dashboardContentRect = CGRect(x: dashboardCard.minX + dashboardCard.width * 0.22,
                                      y: dashboardCard.minY + dashboardCard.height * 0.16,
                                      width: dashboardCard.width * 0.62,
                                      height: dashboardCard.height * 0.68)
    drawDashboardModules(in: dashboardContentRect)
    drawBriefingSheet(in: briefingCard, accentDot: palette.amy, chipColor: palette.john)

    drawStatusDots(
        center: CGPoint(x: base.maxX - base.width * 0.18, y: base.maxY - base.height * 0.16),
        radius: base.width * 0.015,
        colors: [palette.john.withAlphaComponent(0.92), palette.amy.withAlphaComponent(0.92)]
    )
}

func drawSplitPanelConsole(base: CGRect) {
    let console = CGRect(x: base.minX + base.width * 0.14,
                         y: base.minY + base.height * 0.18,
                         width: base.width * 0.72,
                         height: base.height * 0.58)
    drawGlassPanel(in: console, radius: console.width * 0.18, tint: palette.john.withAlphaComponent(0.14), tilt: -88)

    let railRect = CGRect(x: console.minX + console.width * 0.06,
                          y: console.minY + console.height * 0.16,
                          width: console.width * 0.045,
                          height: console.height * 0.68)
    drawAccentRail(in: railRect, colors: [palette.john, palette.amy, palette.ellie, palette.mia])

    let leftZone = CGRect(x: console.minX + console.width * 0.16,
                          y: console.minY + console.height * 0.18,
                          width: console.width * 0.34,
                          height: console.height * 0.62)
    let rightZone = CGRect(x: console.midX + console.width * 0.02,
                           y: console.minY + console.height * 0.16,
                           width: console.width * 0.28,
                           height: console.height * 0.66)
    let dividerRect = CGRect(x: console.midX - console.width * 0.012,
                             y: console.minY + console.height * 0.16,
                             width: console.width * 0.024,
                             height: console.height * 0.68)
    drawRoundedRect(dividerRect, radius: dividerRect.width / 2, fill: palette.pearl.withAlphaComponent(0.12))

    drawDashboardModules(in: leftZone)
    drawBriefingSheet(in: rightZone, accentDot: palette.ellie, chipColor: palette.amy)

    let topHeader = CGRect(x: console.minX + console.width * 0.18,
                           y: console.maxY - console.height * 0.16,
                           width: console.width * 0.42,
                           height: console.height * 0.05)
    drawRoundedRect(topHeader, radius: topHeader.height / 2, fill: palette.pearl.withAlphaComponent(0.24))

    drawStatusDots(
        center: CGPoint(x: console.midX, y: console.maxY - console.height * 0.10),
        radius: console.width * 0.012,
        colors: [palette.john, palette.amy, palette.ellie]
    )
}

func drawBeaconConsoleWindow(base: CGRect) {
    let console = CGRect(x: base.minX + base.width * 0.18,
                         y: base.minY + base.height * 0.19,
                         width: base.width * 0.64,
                         height: base.height * 0.56)
    drawGlassPanel(in: console, radius: console.width * 0.19, tint: palette.mia.withAlphaComponent(0.12), tilt: -82)

    let content = console.insetBy(dx: console.width * 0.12, dy: console.height * 0.18)
    let heroCard = CGRect(x: content.minX,
                          y: content.midY - content.height * 0.06,
                          width: content.width,
                          height: content.height * 0.42)
    let footerBar = CGRect(x: content.minX,
                           y: content.minY,
                           width: content.width * 0.78,
                           height: content.height * 0.16)
    drawRoundedRect(heroCard, radius: heroCard.height * 0.24, fill: palette.pearl.withAlphaComponent(0.18))
    drawRoundedRect(footerBar, radius: footerBar.height / 2, fill: palette.coolGlass.withAlphaComponent(0.20))

    drawBars(
        in: heroCard.insetBy(dx: heroCard.width * 0.12, dy: heroCard.height * 0.20),
        widths: [0.62, 0.80, 0.48],
        color: palette.lineBright,
        height: heroCard.height * 0.10,
        spacing: heroCard.height * 0.12
    )

    let beaconLeft = CGRect(x: console.minX - console.width * 0.04,
                            y: console.midY - console.height * 0.16,
                            width: console.width * 0.08,
                            height: console.height * 0.32)
    let beaconRight = CGRect(x: console.maxX - console.width * 0.04,
                             y: console.midY - console.height * 0.16,
                             width: console.width * 0.08,
                             height: console.height * 0.32)
    drawAccentRail(in: beaconLeft, colors: [palette.john, palette.amy])
    drawAccentRail(in: beaconRight, colors: [palette.ellie, palette.mia])

    drawStatusDots(
        center: CGPoint(x: console.midX, y: console.maxY - console.height * 0.12),
        radius: console.width * 0.013,
        colors: [palette.john.withAlphaComponent(0.92), palette.amy.withAlphaComponent(0.92), palette.mia.withAlphaComponent(0.92)]
    )
}

func drawReadyRoomFinal(base: CGRect) {
    let dashboardCard = CGRect(x: base.minX + base.width * 0.14,
                               y: base.minY + base.height * 0.18,
                               width: base.width * 0.40,
                               height: base.height * 0.53)
    let bridgeCard = CGRect(x: base.minX + base.width * 0.42,
                            y: base.minY + base.height * 0.43,
                            width: base.width * 0.24,
                            height: base.height * 0.18)
    let briefingCard = CGRect(x: base.minX + base.width * 0.50,
                              y: base.minY + base.height * 0.27,
                              width: base.width * 0.28,
                              height: base.height * 0.39)

    drawGlassPanel(in: dashboardCard, radius: dashboardCard.width * 0.18, tint: palette.mia.withAlphaComponent(0.18), tilt: -95)
    drawGlassPanel(in: bridgeCard, radius: bridgeCard.height * 0.45, tint: palette.john.withAlphaComponent(0.12), tilt: -90)
    drawGlassPanel(in: briefingCard, radius: briefingCard.width * 0.23, tint: palette.ellie.withAlphaComponent(0.18), tilt: -84)

    let accentRailRect = CGRect(x: dashboardCard.minX + dashboardCard.width * 0.08,
                                y: dashboardCard.minY + dashboardCard.height * 0.12,
                                width: dashboardCard.width * 0.068,
                                height: dashboardCard.height * 0.74)
    drawAccentRail(in: accentRailRect, colors: [palette.john, palette.amy, palette.ellie, palette.mia])

    let dashboardContentRect = CGRect(x: dashboardCard.minX + dashboardCard.width * 0.21,
                                      y: dashboardCard.minY + dashboardCard.height * 0.15,
                                      width: dashboardCard.width * 0.64,
                                      height: dashboardCard.height * 0.70)
    drawDashboardModules(in: dashboardContentRect)

    let bridgeLineRect = bridgeCard.insetBy(dx: bridgeCard.width * 0.16, dy: bridgeCard.height * 0.24)
    drawBars(
        in: bridgeLineRect,
        widths: [0.42, 0.72],
        color: palette.lineBright,
        height: bridgeCard.height * 0.12,
        spacing: bridgeCard.height * 0.12
    )

    drawBriefingSheet(in: briefingCard, accentDot: palette.amy, chipColor: palette.ellie)

    let signalBar = CGRect(x: briefingCard.minX + briefingCard.width * 0.14,
                           y: briefingCard.maxY + base.height * 0.03,
                           width: briefingCard.width * 0.42,
                           height: base.height * 0.03)
    drawRoundedRect(signalBar, radius: signalBar.height / 2, fill: palette.pearl.withAlphaComponent(0.14))
    drawStatusDots(
        center: CGPoint(x: base.maxX - base.width * 0.17, y: base.maxY - base.height * 0.15),
        radius: base.width * 0.014,
        colors: [palette.john, palette.amy, palette.ellie]
    )
}

func render(concept: IconConcept, size: CGFloat) -> NSBitmapImageRep? {
    let pixels = Int(size.rounded())
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return nil
    }

    rep.size = NSSize(width: size, height: size)

    withGraphicsState {
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return }
        NSGraphicsContext.current = context
        context.cgContext.interpolationQuality = .high
        context.shouldAntialias = true

        let fullRect = CGRect(x: 0, y: 0, width: size, height: size)
        NSColor.clear.setFill()
        fullRect.fill()

        let base = drawBaseIconSurface(in: fullRect)
        switch concept {
        case .glassDashboardTile:
            drawGlassDashboardTile(base: base)
        case .splitPanelConsole:
            drawSplitPanelConsole(base: base)
        case .beaconConsoleWindow:
            drawBeaconConsoleWindow(base: base)
        case .readyRoomFinal:
            drawReadyRoomFinal(base: base)
        }
    }

    return rep
}

do {
    let options = try parseArguments()
    guard let rep = render(concept: options.concept, size: options.size),
          let data = rep.representation(using: .png, properties: [:]) else {
        fputs("Failed to render icon.\n", stderr)
        exit(1)
    }

    let outputURL = URL(fileURLWithPath: options.outputPath)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true,
        attributes: nil
    )
    try data.write(to: outputURL)
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
