import Foundation
import ReadyRoomCore
import Yams

public actor ObligationsYAMLStore {
    private let coordinator: ReadyRoomStorageCoordinator
    private let path = "Shared/obligations.yaml"

    public init(coordinator: ReadyRoomStorageCoordinator) {
        self.coordinator = coordinator
    }

    public func load() async throws -> [ObligationRecord] {
        guard let text = try await coordinator.loadText(relativePath: path, scope: .shared), !text.isEmpty else {
            return []
        }
        return try YAMLDecoder().decode([ObligationRecord].self, from: text)
    }

    public func save(_ obligations: [ObligationRecord]) async throws {
        let yaml = try YAMLEncoder().encode(obligations)
        try await coordinator.saveText(yaml, relativePath: path, scope: .shared)
    }
}

public struct PlainEnglishObligationParser: Sendable {
    public init() {}

    public func parse(_ input: String, now: Date = .now) -> ParsedObligationCandidate {
        let lowered = input.lowercased()
        let title = input.split(separator: ",").first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? input
        let leadDays = parseLeadDays(from: lowered)
        let owner: PersonID? = lowered.contains("john") ? .john : lowered.contains("amy") ? .amy : nil

        if lowered.contains("every month"), let day = extractOrdinalDay(from: lowered) {
            let record = ObligationRecord(
                title: cleanedTitle(from: title),
                owner: owner,
                schedule: ObligationSchedule(kind: .monthly, dayOfMonth: day),
                reminderLeadDays: leadDays.isEmpty ? [7, 3] : leadDays,
                originalEntry: input,
                explanation: "Monthly obligation due on day \(day) with reminder lead time \(leadDays.isEmpty ? [7, 3] : leadDays)."
            )
            return ParsedObligationCandidate(
                originalText: input,
                structured: record,
                explanation: "I understood this as a monthly obligation due on day \(day).",
                confidence: 0.87
            )
        }

        if lowered.contains("every week") {
            let weekdays = weekdayMatches(in: lowered)
            let record = ObligationRecord(
                title: cleanedTitle(from: title),
                owner: owner,
                schedule: ObligationSchedule(kind: .weekly, weekdays: weekdays.isEmpty ? [Calendar.readyRoomGregorian.component(.weekday, from: now)] : weekdays),
                reminderLeadDays: leadDays.isEmpty ? [3] : leadDays,
                originalEntry: input,
                explanation: "Weekly obligation with weekday values \(weekdays)."
            )
            return ParsedObligationCandidate(
                originalText: input,
                structured: record,
                explanation: "I understood this as a weekly obligation.",
                missingFields: weekdays.isEmpty ? ["weekday"] : [],
                confidence: weekdays.isEmpty ? 0.62 : 0.8
            )
        }

        return ParsedObligationCandidate(
            originalText: input,
            structured: nil,
            explanation: "I could not confidently turn that into a structured obligation yet.",
            missingFields: ["schedule"],
            confidence: 0.2
        )
    }

    private func cleanedTitle(from title: String) -> String {
        title.replacingOccurrences(of: " due", with: "", options: .caseInsensitive)
    }

    private func parseLeadDays(from text: String) -> [Int] {
        guard let remindRange = text.range(of: "remind") else {
            return []
        }
        let reminderText = text[remindRange.lowerBound...]
        let numbers = reminderText.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        return numbers.filter { $0 > 0 && $0 <= 90 }
    }

    private func extractOrdinalDay(from text: String) -> Int? {
        let numbers = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        return numbers.first { (1...31).contains($0) }
    }

    private func weekdayMatches(in text: String) -> [Int] {
        let mapping = [
            "sunday": 1,
            "monday": 2,
            "tuesday": 3,
            "wednesday": 4,
            "thursday": 5,
            "friday": 6,
            "saturday": 7
        ]
        return mapping.compactMap { key, value in
            text.contains(key) ? value : nil
        }
        .sorted()
    }
}
