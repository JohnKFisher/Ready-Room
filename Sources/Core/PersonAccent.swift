import Foundation

public struct PersonColorPaletteSettings: Codable, Sendable, Hashable {
    public static let defaultJohnHex = "#3478F6"
    public static let defaultAmyHex = "#39A96B"
    public static let defaultEllieHex = "#B58AF7"
    public static let defaultMiaHex = "#7ECFFF"

    public var johnHex: String
    public var amyHex: String
    public var ellieHex: String
    public var miaHex: String

    public init(
        johnHex: String = PersonColorPaletteSettings.defaultJohnHex,
        amyHex: String = PersonColorPaletteSettings.defaultAmyHex,
        ellieHex: String = PersonColorPaletteSettings.defaultEllieHex,
        miaHex: String = PersonColorPaletteSettings.defaultMiaHex
    ) {
        self.johnHex = PersonColorPaletteSettings.normalizedHex(johnHex) ?? Self.defaultJohnHex
        self.amyHex = PersonColorPaletteSettings.normalizedHex(amyHex) ?? Self.defaultAmyHex
        self.ellieHex = PersonColorPaletteSettings.normalizedHex(ellieHex) ?? Self.defaultEllieHex
        self.miaHex = PersonColorPaletteSettings.normalizedHex(miaHex) ?? Self.defaultMiaHex
    }

    public static var `default`: PersonColorPaletteSettings {
        PersonColorPaletteSettings()
    }

    public func normalized() -> PersonColorPaletteSettings {
        PersonColorPaletteSettings(
            johnHex: johnHex,
            amyHex: amyHex,
            ellieHex: ellieHex,
            miaHex: miaHex
        )
    }

    public mutating func resetToDefaults() {
        self = Self.default
    }

    public func hex(for person: PersonID) -> String {
        switch person {
        case .john:
            normalized().johnHex
        case .amy:
            normalized().amyHex
        case .ellie:
            normalized().ellieHex
        case .mia:
            normalized().miaHex
        case .family:
            ItemAudienceAccentResolver.neutralHex
        }
    }

    public static func normalizedHex(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        let raw = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        let expanded: String
        switch raw.count {
        case 3:
            expanded = raw.map { "\($0)\($0)" }.joined()
        case 6:
            expanded = raw
        default:
            return nil
        }

        let uppercase = expanded.uppercased()
        let valid = uppercase.unicodeScalars.allSatisfy { scalar in
            CharacterSet(charactersIn: "0123456789ABCDEF").contains(scalar)
        }
        return valid ? "#\(uppercase)" : nil
    }
}

public enum AudienceAccentFallbackKind: String, Codable, Sendable, Hashable {
    case family
    case general
}

public struct AudienceAccentToken: Sendable, Hashable, Identifiable {
    public var id: String
    public var label: String
    public var shortLabel: String
    public var hex: String
    public var person: PersonID?
    public var fallbackKind: AudienceAccentFallbackKind?

    public init(
        id: String,
        label: String,
        shortLabel: String,
        hex: String,
        person: PersonID? = nil,
        fallbackKind: AudienceAccentFallbackKind? = nil
    ) {
        self.id = id
        self.label = label
        self.shortLabel = shortLabel
        self.hex = PersonColorPaletteSettings.normalizedHex(hex) ?? ItemAudienceAccentResolver.neutralHex
        self.person = person
        self.fallbackKind = fallbackKind
    }
}

public struct ItemAudienceAccent: Sendable, Hashable {
    public var tokens: [AudienceAccentToken]
    public var primaryHex: String
    public var isNeutralFallback: Bool

    public init(tokens: [AudienceAccentToken], primaryHex: String, isNeutralFallback: Bool) {
        self.tokens = tokens
        self.primaryHex = PersonColorPaletteSettings.normalizedHex(primaryHex) ?? ItemAudienceAccentResolver.neutralHex
        self.isNeutralFallback = isNeutralFallback
    }
}

public enum ItemAudienceAccentResolver {
    public static let neutralHex = "#8A94A6"

    public static func resolve(for item: NormalizedItem, palette: PersonColorPaletteSettings) -> ItemAudienceAccent {
        resolve(owner: item.owner, palette: palette)
    }

    public static func resolve(owner: PersonID, palette: PersonColorPaletteSettings) -> ItemAudienceAccent {
        if owner == .family {
            let token = AudienceAccentToken(
                id: "fallback-family",
                label: "Family",
                shortLabel: "F",
                hex: neutralHex,
                person: .family,
                fallbackKind: .family
            )
            return ItemAudienceAccent(tokens: [token], primaryHex: neutralHex, isNeutralFallback: true)
        }

        let token = AudienceAccentToken(
            id: owner.rawValue,
            label: owner.displayName,
            shortLabel: shortLabel(for: owner),
            hex: palette.hex(for: owner),
            person: owner
        )
        return ItemAudienceAccent(tokens: [token], primaryHex: token.hex, isNeutralFallback: false)
    }

    private static func shortLabel(for person: PersonID) -> String {
        switch person {
        case .john:
            "J"
        case .amy:
            "A"
        case .ellie:
            "E"
        case .mia:
            "M"
        case .family:
            "F"
        }
    }
}
