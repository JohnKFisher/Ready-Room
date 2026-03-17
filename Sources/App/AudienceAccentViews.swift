import AppKit
import SwiftUI
import ReadyRoomCore

struct AudienceAccentRail: View {
    let accent: ItemAudienceAccent

    var body: some View {
        VStack(spacing: 1) {
            ForEach(accent.tokens) { token in
                Rectangle()
                    .fill(Color(readyRoomHex: token.hex, fallback: .secondaryLabelColor))
            }
        }
        .frame(width: 6)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accent.tokens.map(\.label).joined(separator: ", "))
    }
}

struct AudiencePillRow: View {
    let accent: ItemAudienceAccent
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            ForEach(accent.tokens) { token in
                AudiencePill(token: token, compact: compact)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AudiencePill: View {
    let token: AudienceAccentToken
    var compact = false

    var body: some View {
        let baseColor = Color(readyRoomHex: token.hex, fallback: .secondaryLabelColor)
        let textColor = Color(nsColor: NSColor.readyRoomAccentTextColor(for: token.hex))

        Text(compact ? token.shortLabel : token.label)
            .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 3 : 4)
            .background(baseColor.opacity(compact ? 0.14 : 0.16), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(baseColor.opacity(0.28), lineWidth: 1)
            }
            .accessibilityLabel(token.label)
    }
}

struct AudienceAccentPreviewCard: View {
    let title: String
    let subtitle: String
    let accent: ItemAudienceAccent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AudienceAccentRail(accent: accent)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AudiencePillRow(accent: accent, compact: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(readyRoomHex: accent.primaryHex, fallback: .secondaryLabelColor).opacity(accent.isNeutralFallback ? 0.05 : 0.08))
                }
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(nsColor: .separatorColor).opacity(0.22), lineWidth: 1)
        }
    }
}

extension Color {
    init(readyRoomHex: String, fallback: NSColor) {
        if let color = NSColor(readyRoomHex: readyRoomHex) {
            self = Color(nsColor: color)
        } else {
            self = Color(nsColor: fallback)
        }
    }
}

extension NSColor {
    convenience init?(readyRoomHex: String) {
        guard let normalized = PersonColorPaletteSettings.normalizedHex(readyRoomHex) else {
            return nil
        }

        let hex = String(normalized.dropFirst())
        guard let value = Int(hex, radix: 16) else {
            return nil
        }

        self.init(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    var readyRoomHexString: String? {
        guard let rgb = usingColorSpace(.deviceRGB) else {
            return nil
        }
        let red = Int(round(rgb.redComponent * 255))
        let green = Int(round(rgb.greenComponent * 255))
        let blue = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    static func readyRoomAccentTextColor(for hex: String) -> NSColor {
        guard let accentColor = NSColor(readyRoomHex: hex)?.usingColorSpace(.deviceRGB) else {
            return NSColor.labelColor
        }

        let brightness = (0.299 * accentColor.redComponent) + (0.587 * accentColor.greenComponent) + (0.114 * accentColor.blueComponent)
        if brightness > 0.72 {
            return NSColor.labelColor.withAlphaComponent(0.78)
        }

        return accentColor.shadow(withLevel: 0.28) ?? accentColor
    }
}
