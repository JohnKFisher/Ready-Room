import AppKit
import CoreFoundation
import Foundation
import ReadyRoomCore

struct EmailBodyProjection {
    static func plainTextAlternative(for artifact: BriefingArtifact) -> String {
        plainText(fromHTML: artifact.bodyHTML) ?? fallbackPlainText(from: artifact)
    }

    private static func plainText(fromHTML html: String) -> String? {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let data = html.data(using: .utf8),
              let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        return normalizePlainText(attributed.string)
    }

    private static func fallbackPlainText(from artifact: BriefingArtifact) -> String {
        var lines = [artifact.subject, ""]
        for section in artifact.sections {
            lines.append(section.title)
            lines.append(stripHTML(from: section.body))
            lines.append("")
        }
        return normalizePlainText(lines.joined(separator: "\n"))
    }

    private static func stripHTML(from html: String) -> String {
        html
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "</p>", with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    private static func normalizePlainText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct MultipartEmailMessage: Sendable {
    let data: Data
    let messageID: String
}

struct MultipartEmailMessageBuilder {
    let artifact: BriefingArtifact
    let configuration: SMTPSenderConfiguration

    func build() -> MultipartEmailMessage {
        let boundary = "ReadyRoom-\(UUID().uuidString)"
        let messageID = "<\(UUID().uuidString)@\(normalizedDomainHost())>"
        let fromAddress = configuration.fromAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let fromHeader = Self.formattedAddressHeader(
            displayName: configuration.fromDisplayName.trimmingCharacters(in: .whitespacesAndNewlines),
            emailAddress: fromAddress
        )
        let toHeader = artifact.recipients
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: ", ")
        let plainText = EmailBodyProjection.plainTextAlternative(for: artifact)
        let htmlBody = artifact.bodyHTML.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")

        let headers = [
            "Date: \(Self.rfc2822DateString())",
            "From: \(fromHeader)",
            "To: \(toHeader)",
            "Subject: \(Self.encodedHeaderValue(artifact.subject))",
            "Message-ID: \(messageID)",
            "MIME-Version: 1.0",
            "Content-Type: multipart/alternative; boundary=\"\(boundary)\""
        ]

        let plainPart = Self.part(
            boundary: boundary,
            contentType: "text/plain; charset=\"utf-8\"",
            body: plainText
        )
        let htmlPart = Self.part(
            boundary: boundary,
            contentType: "text/html; charset=\"utf-8\"",
            body: htmlBody
        )

        let message = (headers + ["", plainPart + htmlPart + "--\(boundary)--"]).joined(separator: "\r\n")
        return MultipartEmailMessage(data: Data(message.utf8), messageID: messageID)
    }

    private func normalizedDomainHost() -> String {
        let trimmed = configuration.host.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "readyroom.local" : trimmed
    }

    private static func part(boundary: String, contentType: String, body: String) -> String {
        let encodedBody = wrappedBase64(Data(body.utf8).base64EncodedString())
        return """
        --\(boundary)
        Content-Type: \(contentType)
        Content-Transfer-Encoding: base64

        \(encodedBody)

        """
        .replacingOccurrences(of: "\n", with: "\r\n")
    }

    private static func wrappedBase64(_ string: String, lineLength: Int = 76) -> String {
        guard string.isEmpty == false else {
            return ""
        }

        var lines: [String] = []
        var index = string.startIndex
        while index < string.endIndex {
            let next = string.index(index, offsetBy: lineLength, limitedBy: string.endIndex) ?? string.endIndex
            lines.append(String(string[index..<next]))
            index = next
        }
        return lines.joined(separator: "\r\n")
    }

    private static func encodedHeaderValue(_ value: String) -> String {
        guard value.canBeConverted(to: .ascii) == false else {
            return value
        }
        let encoded = Data(value.utf8).base64EncodedString()
        return "=?utf-8?B?\(encoded)?="
    }

    private static func formattedAddressHeader(displayName: String, emailAddress: String) -> String {
        guard displayName.isEmpty == false else {
            return emailAddress
        }

        if displayName.canBeConverted(to: .ascii) {
            let escaped = displayName.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\" <\(emailAddress)>"
        }

        return "\(encodedHeaderValue(displayName)) <\(emailAddress)>"
    }

    private static func rfc2822DateString(date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.string(from: date)
    }
}

enum SMTPTransportError: LocalizedError {
    case invalidConfiguration(String)
    case connectionFailed(String)
    case timeout(String)
    case unexpectedResponse(expected: [Int], actual: Int, transcript: String)
    case protocolViolation(String)
    case authenticationFailed(String)
    case capabilityMissing(String)

    var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(message),
             let .connectionFailed(message),
             let .timeout(message),
             let .protocolViolation(message),
             let .authenticationFailed(message),
             let .capabilityMissing(message):
            return message
        case let .unexpectedResponse(expected, actual, transcript):
            let expectedText = expected.map(String.init).joined(separator: ", ")
            return "SMTP server replied with \(actual) while waiting for \(expectedText). \(transcript)"
        }
    }
}

private struct SMTPResponse {
    let code: Int
    let lines: [String]
}

private struct SMTPServerCapabilities {
    var supportsStartTLS = false
    var authenticationMechanisms: Set<String> = []

    init(response: SMTPResponse) {
        for line in response.lines {
            let uppercased = line.uppercased()
            if uppercased.contains("STARTTLS") {
                supportsStartTLS = true
            }

            if let range = uppercased.range(of: "AUTH ") {
                let suffix = uppercased[range.upperBound...]
                let mechanisms = suffix
                    .split(separator: " ")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty == false }
                authenticationMechanisms.formUnion(mechanisms)
            }
        }
    }
}

private final class SMTPConnection {
    private let configuration: SMTPSenderConfiguration
    private let password: String
    private let host: String
    private let port: Int
    private let timeoutSeconds: TimeInterval
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private var readBuffer = Data()

    init(configuration: SMTPSenderConfiguration, password: String) {
        self.configuration = configuration
        self.password = password
        host = configuration.host.trimmingCharacters(in: .whitespacesAndNewlines)
        port = configuration.port
        timeoutSeconds = TimeInterval(max(5, configuration.connectionTimeoutSeconds))
    }

    func send(message: MultipartEmailMessage, recipients: [String]) throws -> String {
        try open()
        defer { close() }

        _ = try readResponse(expecting: [220])
        var capabilities = try command("EHLO \(clientIdentity())", expecting: [250]).capabilities

        if configuration.security == .startTLS {
            guard capabilities.supportsStartTLS else {
                throw SMTPTransportError.capabilityMissing("The SMTP server did not advertise STARTTLS support for \(host):\(port).")
            }
            _ = try command("STARTTLS", expecting: [220])
            try enableTLSOnOpenStreams()
            capabilities = try command("EHLO \(clientIdentity())", expecting: [250]).capabilities
        }

        try authenticate(using: capabilities)

        let sender = configuration.fromAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try command("MAIL FROM:<\(sender)>", expecting: [250])

        for recipient in recipients {
            let cleaned = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try command("RCPT TO:<\(cleaned)>", expecting: [250, 251])
        }

        _ = try command("DATA", expecting: [354])
        try writeRaw(dotStuff(message.data))
        try writeRaw(Data("\r\n.\r\n".utf8))

        let finalResponse = try readResponse(expecting: [250])
        _ = try? command("QUIT", expecting: [221])
        return extractedServerMessageID(from: finalResponse) ?? message.messageID
    }

    private func authenticate(using capabilities: SMTPServerCapabilities) throws {
        let username = configuration.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard username.isEmpty == false else {
            return
        }

        let requestedMechanism = selectedAuthenticationMechanism(capabilities: capabilities)
        switch requestedMechanism {
        case "PLAIN":
            let payload = "\u{0}\(username)\u{0}\(password)".data(using: .utf8)?.base64EncodedString() ?? ""
            _ = try command("AUTH PLAIN \(payload)", expecting: [235])
        case "LOGIN":
            _ = try command("AUTH LOGIN", expecting: [334])
            _ = try command(Data(username.utf8).base64EncodedString(), expecting: [334])
            _ = try command(Data(password.utf8).base64EncodedString(), expecting: [235])
        default:
            throw SMTPTransportError.authenticationFailed("Ready Room could not find a supported SMTP authentication method for \(host):\(port).")
        }
    }

    private func selectedAuthenticationMechanism(capabilities: SMTPServerCapabilities) -> String {
        let advertised = capabilities.authenticationMechanisms
        switch configuration.authentication {
        case .automatic:
            if advertised.contains("PLAIN") {
                return "PLAIN"
            }
            if advertised.contains("LOGIN") {
                return "LOGIN"
            }
            return advertised.isEmpty ? "PLAIN" : advertised.sorted().first ?? "PLAIN"
        case .plain:
            return "PLAIN"
        case .login:
            return "LOGIN"
        }
    }

    private func extractedServerMessageID(from response: SMTPResponse) -> String? {
        response.lines.last?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func open() throws {
        guard host.isEmpty == false else {
            throw SMTPTransportError.invalidConfiguration("SMTP host is required before Ready Room can send HTML email.")
        }
        guard port > 0 else {
            throw SMTPTransportError.invalidConfiguration("SMTP port must be greater than zero.")
        }
        guard password.isEmpty == false else {
            throw SMTPTransportError.invalidConfiguration("No SMTP password is stored for this Mac. Save an app password in Settings > Sender.")
        }

        var readRef: Unmanaged<CFReadStream>?
        var writeRef: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocketToHost(nil, host as CFString, UInt32(port), &readRef, &writeRef)
        guard let readRef, let writeRef else {
            throw SMTPTransportError.connectionFailed("Ready Room could not open an SMTP connection to \(host):\(port).")
        }

        let read = readRef.takeRetainedValue() as InputStream
        let write = writeRef.takeRetainedValue() as OutputStream
        inputStream = read
        outputStream = write

        read.schedule(in: .current, forMode: .default)
        write.schedule(in: .current, forMode: .default)

        if configuration.security == .implicitTLS {
            try applyTLSSettings()
        }

        read.open()
        write.open()
        try waitForOpen()
    }

    private func close() {
        inputStream?.close()
        outputStream?.close()
        inputStream?.remove(from: .current, forMode: .default)
        outputStream?.remove(from: .current, forMode: .default)
        inputStream = nil
        outputStream = nil
        readBuffer.removeAll(keepingCapacity: false)
    }

    private func waitForOpen() throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if let error = inputStream?.streamError ?? outputStream?.streamError {
                throw SMTPTransportError.connectionFailed(error.localizedDescription)
            }

            let inputReady = inputStream?.streamStatus == .open || inputStream?.streamStatus == .reading || inputStream?.streamStatus == .writing
            let outputReady = outputStream?.streamStatus == .open || outputStream?.streamStatus == .writing || outputStream?.streamStatus == .reading
            if inputReady == true && outputReady == true {
                return
            }

            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }

        throw SMTPTransportError.timeout("Timed out connecting to SMTP server \(host):\(port).")
    }

    private func applyTLSSettings() throws {
        guard let inputStream, let outputStream else {
            throw SMTPTransportError.connectionFailed("The SMTP streams were not available when TLS was requested.")
        }

        let sslSettings: [NSString: Any] = [
            kCFStreamSSLPeerName: host,
            kCFStreamSSLValidatesCertificateChain: true
        ]

        let securityLevel = StreamSocketSecurityLevel.negotiatedSSL.rawValue
        inputStream.setProperty(securityLevel, forKey: .socketSecurityLevelKey)
        outputStream.setProperty(securityLevel, forKey: .socketSecurityLevelKey)

        let readSet = CFReadStreamSetProperty(
            inputStream as CFReadStream,
            CFStreamPropertyKey(kCFStreamPropertySSLSettings),
            sslSettings as CFDictionary
        )
        let writeSet = CFWriteStreamSetProperty(
            outputStream as CFWriteStream,
            CFStreamPropertyKey(kCFStreamPropertySSLSettings),
            sslSettings as CFDictionary
        )

        guard readSet, writeSet else {
            throw SMTPTransportError.connectionFailed("Ready Room could not enable TLS for SMTP server \(host):\(port).")
        }
    }

    private func enableTLSOnOpenStreams() throws {
        try applyTLSSettings()
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if let error = inputStream?.streamError ?? outputStream?.streamError {
                throw SMTPTransportError.connectionFailed("SMTP STARTTLS failed: \(error.localizedDescription)")
            }
            if inputStream?.streamStatus == .open || inputStream?.streamStatus == .reading || inputStream?.streamStatus == .writing {
                if outputStream?.streamStatus == .open || outputStream?.streamStatus == .reading || outputStream?.streamStatus == .writing {
                    return
                }
            }
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }

        throw SMTPTransportError.timeout("Timed out while upgrading the SMTP connection to TLS.")
    }

    private func command(_ value: String, expecting codes: [Int]) throws -> (response: SMTPResponse, capabilities: SMTPServerCapabilities) {
        try writeLine(value)
        let response = try readResponse(expecting: codes)
        return (response, SMTPServerCapabilities(response: response))
    }

    private func readResponse(expecting codes: [Int]) throws -> SMTPResponse {
        let response = try readResponse()
        guard codes.contains(response.code) else {
            throw SMTPTransportError.unexpectedResponse(
                expected: codes,
                actual: response.code,
                transcript: response.lines.joined(separator: " | ")
            )
        }
        return response
    }

    private func readResponse() throws -> SMTPResponse {
        let firstLine = try readLine()
        guard firstLine.count >= 3, let code = Int(firstLine.prefix(3)) else {
            throw SMTPTransportError.protocolViolation("SMTP server sent an invalid response: \(firstLine)")
        }

        var lines = [firstLine]
        if firstLine.count >= 4 {
            let separator = firstLine[firstLine.index(firstLine.startIndex, offsetBy: 3)]
            if separator == "-" {
                while true {
                    let nextLine = try readLine()
                    lines.append(nextLine)
                    if nextLine.hasPrefix("\(code) ") {
                        break
                    }
                }
            }
        }

        return SMTPResponse(code: code, lines: lines)
    }

    private func readLine() throws -> String {
        let delimiter = Data("\r\n".utf8)
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        while Date() < deadline {
            if let range = readBuffer.range(of: delimiter) {
                let lineData = readBuffer.subdata(in: readBuffer.startIndex..<range.lowerBound)
                readBuffer.removeSubrange(readBuffer.startIndex..<range.upperBound)
                return String(decoding: lineData, as: UTF8.self)
            }

            try waitForReadableData(until: deadline)
            var scratch = [UInt8](repeating: 0, count: 2048)
            guard let inputStream else {
                throw SMTPTransportError.connectionFailed("SMTP input stream disappeared while reading.")
            }
            let count = inputStream.read(&scratch, maxLength: scratch.count)
            if count < 0 {
                throw SMTPTransportError.connectionFailed(inputStream.streamError?.localizedDescription ?? "Unknown SMTP read failure.")
            }
            if count == 0 {
                throw SMTPTransportError.connectionFailed("The SMTP server closed the connection unexpectedly.")
            }
            readBuffer.append(contentsOf: scratch.prefix(count))
        }

        throw SMTPTransportError.timeout("Timed out waiting for an SMTP server response from \(host):\(port).")
    }

    private func writeLine(_ line: String) throws {
        try writeRaw(Data((line + "\r\n").utf8))
    }

    private func writeRaw(_ data: Data) throws {
        let bytes = Array(data)
        var offset = 0
        let deadline = Date().addingTimeInterval(timeoutSeconds)

        try bytes.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return
            }

            while offset < bytes.count {
                try waitForWritableSpace(until: deadline)
                guard let outputStream else {
                    throw SMTPTransportError.connectionFailed("SMTP output stream disappeared while writing.")
                }
                let written = outputStream.write(baseAddress.advanced(by: offset), maxLength: bytes.count - offset)
                if written < 0 {
                    throw SMTPTransportError.connectionFailed(outputStream.streamError?.localizedDescription ?? "Unknown SMTP write failure.")
                }
                if written == 0 {
                    RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
                    continue
                }
                offset += written
            }
        }
    }

    private func waitForReadableData(until deadline: Date) throws {
        while Date() < deadline {
            if let error = inputStream?.streamError {
                throw SMTPTransportError.connectionFailed(error.localizedDescription)
            }
            if inputStream?.hasBytesAvailable == true {
                return
            }
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }

        throw SMTPTransportError.timeout("Timed out waiting for data from SMTP server \(host):\(port).")
    }

    private func waitForWritableSpace(until deadline: Date) throws {
        while Date() < deadline {
            if let error = outputStream?.streamError {
                throw SMTPTransportError.connectionFailed(error.localizedDescription)
            }
            if outputStream?.hasSpaceAvailable == true {
                return
            }
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }

        throw SMTPTransportError.timeout("Timed out waiting to write data to SMTP server \(host):\(port).")
    }

    private func dotStuff(_ data: Data) -> Data {
        let string = String(decoding: data, as: UTF8.self)
        let stuffedLines = string
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let value = String(line)
                return value.hasPrefix(".") ? "." + value : value
            }
        let stuffed = stuffedLines.joined(separator: "\r\n")
        return Data(stuffed.utf8)
    }

    private func clientIdentity() -> String {
        let name = Host.current().localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = (name?.isEmpty == false ? name : "ready-room") ?? "ready-room"
        return candidate
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9.-]", with: "", options: .regularExpression)
    }
}

public struct SMTPSenderAdapter: SenderAdapter {
    public let id = SenderTransport.smtp.rawValue
    public let displayName = SenderTransport.smtp.displayName

    private let configuration: SMTPSenderConfiguration
    private let password: String

    public init(configuration: SMTPSenderConfiguration, password: String) {
        self.configuration = configuration
        self.password = password
    }

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
            return SendExecutionResult(record: record)
        }

        guard configuration.isConfigured else {
            throw SMTPTransportError.invalidConfiguration("SMTP is selected, but the sender settings are incomplete.")
        }

        let message = MultipartEmailMessageBuilder(artifact: artifact, configuration: configuration).build()
        let recipients = artifact.recipients

        let serverMessageID = try await Task.detached(priority: .utility) {
            let connection = SMTPConnection(configuration: configuration, password: password)
            return try connection.send(message: message, recipients: recipients)
        }.value

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
        return SendExecutionResult(record: record, messageID: serverMessageID)
    }
}

public struct SenderDispatchCoordinator: Sendable {
    public init() {}

    public func deliver(
        artifact: BriefingArtifact,
        mode: SendMode,
        machineIdentifier: String,
        requestedSenderID: String,
        requestedSenderDisplayName: String,
        adapters: [SenderAdapter],
        initialFallbackDescription: String? = nil
    ) async throws -> SendExecutionResult {
        guard let primary = adapters.first else {
            throw NSError(domain: "ReadyRoomSend", code: 0, userInfo: [NSLocalizedDescriptionKey: "No sender configured."])
        }

        let primaryAttempts = mode == .scheduled ? 2 : 1
        var primaryError: Error?

        for attempt in 1...primaryAttempts {
            do {
                let result = try await primary.send(artifact: artifact, mode: mode, machineIdentifier: machineIdentifier)
                return decorate(
                    result: result,
                    requestedSenderID: requestedSenderID,
                    requestedSenderDisplayName: requestedSenderDisplayName,
                    actualSenderDisplayName: primary.displayName,
                    fallbackDescription: initialFallbackDescription
                )
            } catch {
                primaryError = error
                guard attempt < primaryAttempts else {
                    break
                }
            }
        }

        for fallback in adapters.dropFirst() {
            do {
                let result = try await fallback.send(artifact: artifact, mode: mode, machineIdentifier: machineIdentifier)
                let details = fallbackDescription(
                    initialDescription: initialFallbackDescription,
                    requestedDisplayName: requestedSenderDisplayName,
                    actualDisplayName: fallback.displayName,
                    error: primaryError
                )
                return decorate(
                    result: result,
                    requestedSenderID: requestedSenderID,
                    requestedSenderDisplayName: requestedSenderDisplayName,
                    actualSenderDisplayName: fallback.displayName,
                    fallbackDescription: details
                )
            } catch {
                primaryError = error
            }
        }

        throw primaryError ?? NSError(domain: "ReadyRoomSend", code: 2, userInfo: [NSLocalizedDescriptionKey: "All sender attempts failed."])
    }

    private func decorate(
        result: SendExecutionResult,
        requestedSenderID: String,
        requestedSenderDisplayName: String,
        actualSenderDisplayName: String,
        fallbackDescription: String?
    ) -> SendExecutionResult {
        var record = result.record
        record.requestedSenderID = requestedSenderID
        record.requestedSenderDisplayName = requestedSenderDisplayName
        record.actualSenderDisplayName = actualSenderDisplayName
        if record.senderID != requestedSenderID || fallbackDescription != nil {
            record.fallbackDescription = fallbackDescription
        }
        return SendExecutionResult(record: record, messageID: result.messageID)
    }

    private func fallbackDescription(
        initialDescription: String?,
        requestedDisplayName: String,
        actualDisplayName: String,
        error: Error?
    ) -> String {
        let prefix = initialDescription.map { [$0] } ?? []
        let failureMessage = error.map {
            "\(requestedDisplayName) failed and Ready Room sent the message via \(actualDisplayName) instead. \($0.localizedDescription)"
        } ?? "\(requestedDisplayName) was not available, so Ready Room sent the message via \(actualDisplayName) instead."
        return (prefix + [failureMessage]).joined(separator: " ")
    }
}
