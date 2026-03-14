import AppKit
import Foundation
import OSAKit
import ReadyRoomCore
import ReadyRoomPersistence
import ScriptingBridge

public struct ScheduledSendCoordinator: Sendable {
    public init() {}

    public func shouldSendToday(
        now: Date,
        audience: BriefingAudience,
        machineIdentifier: String,
        primary: PrimarySenderConfiguration,
        existingRecords: [SendExecutionRecord],
        calendar: Calendar = .readyRoomGregorian
    ) -> Bool {
        guard primary.machineIdentifier == machineIdentifier else {
            return false
        }

        let startOfDay = calendar.startOfDay(for: now)
        let scheduled = calendar.date(bySettingHour: primary.scheduledSendHour, minute: primary.scheduledSendMinute, second: 0, of: startOfDay) ?? now
        let catchUpDeadline = calendar.date(bySettingHour: primary.catchUpDeadlineHour, minute: 0, second: 0, of: startOfDay) ?? now

        guard now >= scheduled, now <= catchUpDeadline else {
            return false
        }

        return existingRecords.contains {
            calendar.isDate($0.briefingDate, inSameDayAs: now) &&
            $0.audience == audience &&
            $0.status == .sent &&
            blocksScheduledSend($0, scheduled: scheduled, catchUpDeadline: catchUpDeadline)
        } == false
    }

    public func dedupeKey(for date: Date, audience: BriefingAudience, calendar: Calendar = .readyRoomGregorian) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: date)):\(audience.rawValue)"
    }

    private func blocksScheduledSend(
        _ record: SendExecutionRecord,
        scheduled: Date,
        catchUpDeadline: Date
    ) -> Bool {
        switch record.sendMode {
        case .scheduled?:
            return true
        case .manualTest?, .previewOnly?:
            return false
        case nil:
            let completionDate = record.completedAt ?? record.createdAt
            return completionDate >= scheduled && completionDate <= catchUpDeadline
        }
    }
}

public struct AppleMailSenderAdapter: SenderAdapter {
    public let id = "apple-mail"
    public let displayName = "Apple Mail"

    public init() {}

    public func send(artifact: BriefingArtifact, mode: SendMode, machineIdentifier: String) async throws -> SendExecutionResult {
        if mode == .previewOnly {
            let record = SendExecutionRecord(
                briefingDate: artifact.generatedAt,
                audience: artifact.audience,
                machineIdentifier: machineIdentifier,
                senderID: id,
                sendMode: mode,
                status: .pending,
                preferredMode: artifact.preferredMode,
                actualMode: artifact.actualMode,
                dedupeKey: "\(artifact.generatedAt.formattedMonthDayWeekday()):\(artifact.audience.rawValue)"
            )
            return SendExecutionResult(record: record, messageID: nil)
        }

        let bodyText = mailCompatibleBodyText(for: artifact)
        let script = """
        use AppleScript version "2.7"
        use scripting additions
        tell application "Mail"
            set newMessage to make new outgoing message with properties {subject:"\(escape(artifact.subject))", content:"\(escape(bodyText))", visible:false}
            tell newMessage
        \(artifact.recipients.map { "make new to recipient at end of to recipients with properties {address:\"\(escape($0))\"}" }.joined(separator: "\n"))
                send
            end tell
        end tell
        """

        var errorDictionary: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&errorDictionary)
        if let errorDictionary {
            throw NSError(domain: "ReadyRoomMail", code: 1, userInfo: errorDictionary as? [String: Any])
        }

        let record = SendExecutionRecord(
            briefingDate: artifact.generatedAt,
            audience: artifact.audience,
            machineIdentifier: machineIdentifier,
            senderID: id,
            sendMode: mode,
            status: .sent,
            preferredMode: artifact.preferredMode,
            actualMode: artifact.actualMode,
            completedAt: .now,
            dedupeKey: "\(artifact.generatedAt.formattedMonthDayWeekday()):\(artifact.audience.rawValue)"
        )
        return SendExecutionResult(record: record, messageID: result?.stringValue)
    }

    private func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    func mailCompatibleBodyText(for artifact: BriefingArtifact) -> String {
        let compatibilityNote = """
        [Apple Mail compatibility mode]
        This briefing was sent as plain text for reliable rendering in Apple Mail automation.

        """
        let convertedBody = plainText(fromHTML: artifact.bodyHTML) ?? fallbackPlainText(from: artifact)
        return compatibilityNote + normalizePlainText(convertedBody)
    }

    private func plainText(fromHTML html: String) -> String? {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let data = html.data(using: .utf8),
              let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        return attributed.string
    }

    private func fallbackPlainText(from artifact: BriefingArtifact) -> String {
        var lines = [artifact.subject, ""]
        for section in artifact.sections {
            lines.append(section.title)
            lines.append(stripHTML(from: section.body))
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func stripHTML(from html: String) -> String {
        html
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "</p>", with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    private func normalizePlainText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public actor BriefingOrchestrator {
    private let composer: BriefingComposer
    private let archiveStore: ArchiveStore

    public init(composer: BriefingComposer, archiveStore: ArchiveStore) {
        self.composer = composer
        self.archiveStore = archiveStore
    }

    public func generateArtifact(
        request: BriefingRequest,
        recipients: [String],
        pipeline: NarrativeGenerationPipeline
    ) async -> BriefingArtifact {
        let opening = await pipeline.openingLine(for: request)
        let newsSummary = await pipeline.newsSummary(for: request)
        let artifact = composer.compose(
            request: request,
            recipients: recipients,
            openingLine: opening,
            newsSummary: newsSummary
        )
        try? await archiveStore.append(artifact)
        return artifact
    }
}
