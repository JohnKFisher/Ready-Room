import Foundation
import Testing
@testable import ReadyRoomCore
@testable import ReadyRoomPersistence
@testable import ReadyRoomConnectors
@testable import ReadyRoomBriefings
@testable import ReadyRoomApp

struct ReadyRoomFoundationTests {
    @Test
    func sharedKidEventMarksBothParentsRelevant() {
        let engine = ReadyRoomRulesEngine()
        let source = SourceDescriptor(id: "calendar", displayName: "Calendars", type: .calendar)
        let event = RawCalendarEvent(
            id: "kid-1",
            calendarIdentifier: "shared",
            calendarTitle: "Family Shared",
            title: "Ellie soccer practice",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600)
        )

        let items = engine.normalizeCalendarEvents([event], source: source, configurations: [:], health: .healthy)
        #expect(items.count == 1)
        #expect(items[0].relevantPeople.contains(.john))
        #expect(items[0].relevantPeople.contains(.amy))
        #expect(items[0].inclusion.johnBriefing)
        #expect(items[0].inclusion.amyBriefing)
    }

    @Test
    func spouseWorkMeetingDoesNotLeakAcrossBriefings() {
        let engine = ReadyRoomRulesEngine()
        let source = SourceDescriptor(id: "calendar", displayName: "Calendars", type: .calendar)
        let event = RawCalendarEvent(
            id: "amy-work",
            calendarIdentifier: "amy-work",
            calendarTitle: "Amy Work",
            title: "Client review",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            sourceOwnerHint: .amy
        )

        let items = engine.normalizeCalendarEvents([event], source: source, configurations: [:], health: .healthy)
        #expect(items[0].inclusion.amyBriefing)
        #expect(items[0].inclusion.johnBriefing == false)
    }

    @Test
    func dueSoonObligationEntersReminderWindow() {
        let engine = ReadyRoomRulesEngine()
        let dueDate = Calendar.readyRoomGregorian.date(byAdding: .day, value: 2, to: Date())!
        let obligation = ObligationRecord(
            title: "Mortgage",
            schedule: ObligationSchedule(kind: .oneTime, dueDate: dueDate),
            reminderLeadDays: [7, 3]
        )

        let items = engine.dueSoonObligations([obligation], source: SourceDescriptor(id: "obligations", displayName: "Obligations", type: .obligation), health: .healthy)
        #expect(items.count == 1)
        #expect(items[0].changeState == .enteredReminderWindow)
    }

    @Test
    func recurringObligationDueYesterdayStillShowsBeforeThreeAM() {
        let engine = ReadyRoomRulesEngine()
        let referenceDate = Calendar.readyRoomGregorian.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 1, minute: 15))!
        let obligation = ObligationRecord(
            title: "Disney card due",
            schedule: ObligationSchedule(kind: .monthly, dayOfMonth: 13),
            reminderLeadDays: [7, 3]
        )

        let items = engine.dueSoonObligations(
            [obligation],
            source: SourceDescriptor(id: "obligations", displayName: "Obligations", type: .obligation),
            health: .healthy,
            referenceDate: referenceDate
        )

        #expect(items.count == 1)
        #expect(items[0].startDate == Calendar.readyRoomGregorian.date(from: DateComponents(year: 2026, month: 3, day: 13)))
    }

    @Test
    func recurringObligationDueYesterdayRollsOutAfterThreeAM() {
        let engine = ReadyRoomRulesEngine()
        let referenceDate = Calendar.readyRoomGregorian.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 3, minute: 5))!
        let obligation = ObligationRecord(
            title: "Disney card due",
            schedule: ObligationSchedule(kind: .monthly, dayOfMonth: 13),
            reminderLeadDays: [7, 3]
        )

        let items = engine.dueSoonObligations(
            [obligation],
            source: SourceDescriptor(id: "obligations", displayName: "Obligations", type: .obligation),
            health: .healthy,
            referenceDate: referenceDate
        )

        #expect(items.isEmpty)
    }

    @Test
    func obligationParserHandlesMonthlySentence() {
        let parser = PlainEnglishObligationParser()
        let parsed = parser.parse("Mortgage due every month on the 15th, remind me 7 and 3 days before")

        #expect(parsed.structured != nil)
        #expect(parsed.structured?.schedule.kind == .monthly)
        #expect(parsed.structured?.schedule.dayOfMonth == 15)
        #expect(parsed.structured?.reminderLeadDays == [7, 3])
    }

    @Test
    func briefingComposerIncludesModeDisclosure() async {
        let request = BriefingRequest(
            audience: .john,
            normalizedItems: [],
            weather: WeatherSnapshot(summary: "Sunny", currentTemperatureF: 60, highF: 70, lowF: 48),
            headlines: [NewsHeadline(title: "Headline", sourceName: "AP")],
            mediaItems: [],
            dueSoon: [],
            preferredMode: .foundationModels
        )
        let opening = GeneratedNarrative(text: "Busy but manageable.", preferredMode: .foundationModels, actualMode: .templated, fallbackReason: "Fallback.")
        let news = GeneratedNarrative(text: "Headline", preferredMode: .foundationModels, actualMode: .templated, fallbackReason: "Fallback.")
        let artifact = BriefingComposer().compose(request: request, recipients: ["john@example.com"], openingLine: opening, newsSummary: news)

        #expect(artifact.bodyHTML.contains("Preferred mode"))
        #expect(artifact.actualMode == .templated)
    }

    @Test
    func briefingComposerLabelsPlaceholderContentAndShowsDevelopmentWarning() {
        let calendar = Calendar.readyRoomGregorian
        let item = NormalizedItem(
            id: "calendar:sample",
            source: SourceDescriptor(id: "sample-calendar", displayName: "Sample Calendar", type: .calendar),
            sourceIdentifier: "sample",
            sourceType: .calendar,
            title: "Amy - Chicago",
            startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 9))!,
            endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 10))!
        )
        let request = BriefingRequest(
            audience: .john,
            normalizedItems: [item],
            weather: WeatherSnapshot(summary: "Sunny", currentTemperatureF: 60, highF: 70, lowF: 48),
            headlines: [NewsHeadline(title: "Headline", sourceName: "AP")],
            mediaItems: [MediaActivity(kind: .newAddition, title: "The Wild Robot")],
            dueSoon: [],
            preferredMode: .templated,
            calendarPlaceholderLabel: "Sample calendar data",
            weatherPlaceholderLabel: "Sample weather data",
            newsPlaceholderLabel: "Sample news headlines",
            mediaPlaceholderLabel: "Sample Plex/media activity"
        )
        let opening = GeneratedNarrative(text: "Busy but manageable.", preferredMode: .templated, actualMode: .templated)
        let news = GeneratedNarrative(text: "Headline", preferredMode: .templated, actualMode: .templated)

        let artifact = BriefingComposer().compose(request: request, recipients: ["john@example.com"], openingLine: opening, newsSummary: news)

        #expect(artifact.bodyHTML.contains("very, very early development"))
        #expect(artifact.bodyHTML.contains("should not be trusted or relied on"))
        #expect(artifact.bodyHTML.contains("[Placeholder]"))
        #expect(artifact.bodyHTML.contains("Sample weather data"))
        #expect(artifact.bodyHTML.contains("Sample news headlines"))
        #expect(artifact.bodyHTML.contains("Sample Plex/media activity"))
    }

    @Test
    func briefingComposerIncludesDatesInEventLines() {
        let calendar = Calendar.readyRoomGregorian
        let item = NormalizedItem(
            id: "calendar:dated",
            source: SourceDescriptor(id: "calendar", displayName: "Calendar", type: .calendar),
            sourceIdentifier: "dated",
            sourceType: .calendar,
            title: "Amy - Flight Home",
            startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 21, minute: 25))!,
            endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 22, minute: 25))!
        )
        let request = BriefingRequest(
            audience: .john,
            date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 6, minute: 30))!,
            normalizedItems: [item],
            weather: nil,
            headlines: [],
            mediaItems: [],
            dueSoon: [],
            preferredMode: .templated
        )
        let opening = GeneratedNarrative(text: "Today looks busy.", preferredMode: .templated, actualMode: .templated)
        let news = GeneratedNarrative(text: "", preferredMode: .templated, actualMode: .templated)

        let artifact = BriefingComposer().compose(request: request, recipients: ["john@example.com"], openingLine: opening, newsSummary: news)

        #expect(artifact.bodyHTML.contains("Sun, Mar 15 at 9:25"))
    }

    @Test
    func briefingComposerIncludesAudienceChipsInMarkup() {
        let calendar = Calendar.readyRoomGregorian
        let source = SourceDescriptor(id: "calendar", displayName: "Calendar", type: .calendar)
        let item = NormalizedItem(
            id: "calendar:pickup",
            source: source,
            sourceIdentifier: "pickup",
            sourceType: .calendar,
            title: "School pickup",
            startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 15, minute: 0))!,
            endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 16, minute: 0))!,
            relevantPeople: [.john, .amy]
        )
        let request = BriefingRequest(
            audience: .john,
            date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 6, minute: 30))!,
            normalizedItems: [item],
            weather: nil,
            headlines: [],
            mediaItems: [],
            dueSoon: [],
            preferredMode: .templated
        )
        let opening = GeneratedNarrative(text: "Today looks busy.", preferredMode: .templated, actualMode: .templated)
        let news = GeneratedNarrative(text: "", preferredMode: .templated, actualMode: .templated)

        let artifact = BriefingComposer().compose(request: request, recipients: ["john@example.com"], openingLine: opening, newsSummary: news)
        let plainText = EmailBodyProjection.plainTextAlternative(for: artifact)

        #expect(artifact.bodyHTML.contains(">J<"))
        #expect(artifact.bodyHTML.contains(">A<"))
        #expect(artifact.bodyHTML.contains("#3478F6"))
        #expect(artifact.bodyHTML.contains("#39A96B"))
        #expect(plainText.contains("School pickup"))
    }

    @Test
    func briefingComposerUsesTodayTomorrowAndUpcomingDaySections() {
        let calendar = Calendar.readyRoomGregorian
        let source = SourceDescriptor(id: "calendar", displayName: "Calendar", type: .calendar)
        let requestDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 6, minute: 30))!
        let items = [
            NormalizedItem(
                id: "calendar:today",
                source: source,
                sourceIdentifier: "today",
                sourceType: .calendar,
                title: "School pickup",
                startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 15, minute: 0))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 16, minute: 0))!
            ),
            NormalizedItem(
                id: "calendar:tomorrow",
                source: source,
                sourceIdentifier: "tomorrow",
                sourceType: .calendar,
                title: "Dentist",
                startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 9, minute: 0))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 10, minute: 0))!
            ),
            NormalizedItem(
                id: "calendar:upcoming-1",
                source: source,
                sourceIdentifier: "upcoming-1",
                sourceType: .calendar,
                title: "Project review",
                startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 16, hour: 11, minute: 0))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 16, hour: 12, minute: 0))!
            ),
            NormalizedItem(
                id: "calendar:upcoming-2",
                source: source,
                sourceIdentifier: "upcoming-2",
                sourceType: .calendar,
                title: "Band concert",
                startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 18, hour: 19, minute: 0))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 18, hour: 20, minute: 0))!
            ),
            NormalizedItem(
                id: "calendar:excluded",
                source: source,
                sourceIdentifier: "excluded",
                sourceType: .calendar,
                title: "Too far out",
                startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 19, hour: 8, minute: 0))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 19, hour: 9, minute: 0))!
            )
        ]
        let request = BriefingRequest(
            audience: .john,
            date: requestDate,
            normalizedItems: items,
            weather: nil,
            headlines: [],
            mediaItems: [],
            dueSoon: [],
            preferredMode: .templated
        )
        let opening = GeneratedNarrative(text: "Today looks busy.", preferredMode: .templated, actualMode: .templated)
        let news = GeneratedNarrative(text: "", preferredMode: .templated, actualMode: .templated)

        let artifact = BriefingComposer().compose(request: request, recipients: ["john@example.com"], openingLine: opening, newsSummary: news)

        #expect(artifact.sections.map(\.title) == ["Today", "Tomorrow", "Upcoming"])
        #expect(artifact.sections.contains(where: { $0.title == "This Morning" }) == false)
        #expect(artifact.sections.contains(where: { $0.title == "Tonight" }) == false)
        #expect(artifact.sections.contains(where: { $0.title == "Coming Up" }) == false)
        #expect(artifact.sections.first(where: { $0.title == "Today" })?.items.map(\.id) == ["calendar:today"])
        #expect(artifact.sections.first(where: { $0.title == "Tomorrow" })?.items.map(\.id) == ["calendar:tomorrow"])
        #expect(artifact.sections.first(where: { $0.title == "Upcoming" })?.items.map(\.id) == ["calendar:upcoming-1", "calendar:upcoming-2"])
        #expect(artifact.bodyHTML.contains("Too far out") == false)
    }

    @Test
    func scheduledSendCoordinatorPreventsDuplicateSends() {
        let coordinator = ScheduledSendCoordinator()
        let calendar = Calendar.readyRoomGregorian
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 13, hour: 7, minute: 0))!
        let primary = PrimarySenderConfiguration(machineIdentifier: "primary-machine")
        let sentRecord = SendExecutionRecord(
            briefingDate: now,
            audience: .john,
            machineIdentifier: "primary-machine",
            senderID: "mail",
            sendMode: .scheduled,
            status: .sent,
            preferredMode: .templated,
            actualMode: .templated,
            completedAt: now,
            dedupeKey: coordinator.dedupeKey(for: now, audience: .john)
        )

        let shouldSend = coordinator.shouldSendToday(
            now: now,
            audience: .john,
            machineIdentifier: "primary-machine",
            primary: primary,
            existingRecords: [sentRecord]
        )

        #expect(shouldSend == false)
    }

    @Test
    func scheduledSendCoordinatorIgnoresEarlierManualTestSends() {
        let coordinator = ScheduledSendCoordinator()
        let calendar = Calendar.readyRoomGregorian
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 6, minute: 30))!
        let earlierManualTest = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 2, minute: 42))!

        let shouldSend = coordinator.shouldSendToday(
            now: now,
            audience: .john,
            machineIdentifier: "primary-machine",
            primary: PrimarySenderConfiguration(machineIdentifier: "primary-machine"),
            existingRecords: [
                SendExecutionRecord(
                    briefingDate: earlierManualTest,
                    audience: .john,
                    machineIdentifier: "primary-machine",
                    senderID: "mail",
                    sendMode: .manualTest,
                    status: .sent,
                    preferredMode: .templated,
                    actualMode: .templated,
                    createdAt: earlierManualTest,
                    completedAt: earlierManualTest,
                    dedupeKey: coordinator.dedupeKey(for: earlierManualTest, audience: .john)
                )
            ]
        )

        #expect(shouldSend)
    }

    @Test
    func scheduledSendCoordinatorTreatsLegacyScheduledWindowSendAsDuplicate() {
        let coordinator = ScheduledSendCoordinator()
        let calendar = Calendar.readyRoomGregorian
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 7, minute: 0))!
        let legacyScheduledTime = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 6, minute: 31))!

        let shouldSend = coordinator.shouldSendToday(
            now: now,
            audience: .amy,
            machineIdentifier: "primary-machine",
            primary: PrimarySenderConfiguration(machineIdentifier: "primary-machine"),
            existingRecords: [
                SendExecutionRecord(
                    briefingDate: legacyScheduledTime,
                    audience: .amy,
                    machineIdentifier: "primary-machine",
                    senderID: "mail",
                    status: .sent,
                    preferredMode: .templated,
                    actualMode: .templated,
                    createdAt: legacyScheduledTime,
                    completedAt: legacyScheduledTime,
                    dedupeKey: coordinator.dedupeKey(for: legacyScheduledTime, audience: .amy)
                )
            ]
        )

        #expect(shouldSend == false)
    }

    @Test
    func scheduledSendCoordinatorDoesNotSendWhenNoPrimaryMachineIsConfigured() {
        let coordinator = ScheduledSendCoordinator()
        let calendar = Calendar.readyRoomGregorian
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 13, hour: 7, minute: 0))!

        let shouldSend = coordinator.shouldSendToday(
            now: now,
            audience: .john,
            machineIdentifier: "mac-mini",
            primary: PrimarySenderConfiguration(machineIdentifier: ""),
            existingRecords: []
        )

        #expect(shouldSend == false)
    }

    @Test
    func appleMailSenderProjectsHTMLToReadablePlainText() {
        let composer = BriefingComposer()
        let request = BriefingRequest(
            audience: .john,
            normalizedItems: [],
            weather: WeatherSnapshot(summary: "Sunny", currentTemperatureF: 60, highF: 70, lowF: 48),
            headlines: [],
            mediaItems: [],
            dueSoon: [],
            preferredMode: .templated
        )
        let opening = GeneratedNarrative(text: "Today looks busy.", preferredMode: .templated, actualMode: .templated)
        let news = GeneratedNarrative(text: "", preferredMode: .templated, actualMode: .templated)
        let artifact = composer.compose(
            request: request,
            recipients: ["john@example.com"],
            openingLine: opening,
            newsSummary: news
        )
        let sender = AppleMailSenderAdapter()

        let bodyText = sender.mailCompatibleBodyText(for: artifact)

        #expect(bodyText.contains("Apple Mail compatibility mode"))
        #expect(bodyText.contains("Ready Room is in very, very early development."))
        #expect(bodyText.contains("Good morning, John."))
        #expect(bodyText.contains("<html>") == false)
        #expect(bodyText.contains("<body") == false)
    }

    @Test
    func smtpMessageBuilderCreatesMultipartAlternativeEmail() {
        let composer = BriefingComposer()
        let request = BriefingRequest(
            audience: .john,
            normalizedItems: [],
            weather: WeatherSnapshot(summary: "Sunny", currentTemperatureF: 60, highF: 70, lowF: 48),
            headlines: [NewsHeadline(title: "Markets mixed", sourceName: "AP")],
            mediaItems: [],
            dueSoon: [],
            preferredMode: .templated
        )
        let opening = GeneratedNarrative(text: "Today looks busy.", preferredMode: .templated, actualMode: .templated)
        let news = GeneratedNarrative(text: "Markets mixed", preferredMode: .templated, actualMode: .templated)
        let artifact = composer.compose(
            request: request,
            recipients: ["john@example.com"],
            openingLine: opening,
            newsSummary: news
        )
        let config = SMTPSenderConfiguration(
            isEnabled: true,
            host: "smtp.example.com",
            port: 465,
            security: .implicitTLS,
            username: "readyroom@example.com",
            fromAddress: "readyroom@example.com",
            fromDisplayName: "Ready Room"
        )

        let message = MultipartEmailMessageBuilder(artifact: artifact, configuration: config).build()
        let wire = String(decoding: message.data, as: UTF8.self)
        let htmlEncoded = Data(artifact.bodyHTML.utf8).base64EncodedString()
        let plainEncoded = Data(EmailBodyProjection.plainTextAlternative(for: artifact).utf8).base64EncodedString()

        #expect(wire.contains("multipart/alternative"))
        #expect(wire.contains("Content-Type: text/plain; charset=\"utf-8\""))
        #expect(wire.contains("Content-Type: text/html; charset=\"utf-8\""))
        #expect(wire.contains(String(htmlEncoded.prefix(24))))
        #expect(wire.contains(String(plainEncoded.prefix(24))))
        #expect(message.messageID.contains("@smtp.example.com>"))
    }

    @Test
    func senderDispatchCoordinatorFallsBackToSecondaryAdapterAndRecordsRequestedVsActualSender() async throws {
        let coordinator = SenderDispatchCoordinator()
        let artifact = BriefingArtifact(
            audience: .john,
            subject: "Test HTML",
            recipients: ["john@example.com"],
            bodyHTML: "<html><body><p>Hello</p></body></html>",
            sections: [],
            preferredMode: .templated,
            actualMode: .templated,
            sourceSnapshotSummary: [],
            trace: DecisionTrace(preferredGenerationMode: .templated, actualGenerationMode: .templated)
        )

        let result = try await coordinator.deliver(
            artifact: artifact,
            mode: .scheduled,
            machineIdentifier: "mac-mini",
            requestedSenderID: SenderTransport.smtp.rawValue,
            requestedSenderDisplayName: SenderTransport.smtp.displayName,
            adapters: [
                StubSenderAdapter(id: SenderTransport.smtp.rawValue, displayName: SenderTransport.smtp.displayName, failure: NSError(domain: "SMTP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bad auth."])),
                StubSenderAdapter(id: SenderTransport.appleMail.rawValue, displayName: SenderTransport.appleMail.displayName)
            ]
        )

        #expect(result.record.senderID == SenderTransport.appleMail.rawValue)
        #expect(result.record.requestedSenderID == SenderTransport.smtp.rawValue)
        #expect(result.record.requestedSenderDisplayName == SenderTransport.smtp.displayName)
        #expect(result.record.actualSenderDisplayName == SenderTransport.appleMail.displayName)
        #expect(result.record.fallbackDescription?.contains("Bad auth.") == true)
    }

    @Test
    func dictionaryBuilderKeepsLastDuplicateValueInsteadOfCrashing() {
        let dictionary = ReadyRoomCollections.dictionaryLastValueWins(
            from: [
                ("shared", 1),
                ("shared", 2),
                ("other", 3)
            ]
        )

        #expect(dictionary["shared"] == 2)
        #expect(dictionary["other"] == 3)
    }

    @Test
    func obligationEditorDraftPersistsEditableExplanationAndOriginalEntry() {
        let dueDate = Calendar.readyRoomGregorian.date(from: DateComponents(year: 2026, month: 3, day: 20))!
        let record = ObligationRecord(
            id: "mortgage",
            title: "Mortgage",
            notes: "Autopay check",
            owner: .john,
            schedule: ObligationSchedule(kind: .monthly, dueDate: dueDate, dayOfMonth: 15),
            reminderLeadDays: [7, 3],
            originalEntry: "Mortgage due every month on the 15th",
            explanation: "Monthly household bill."
        )

        var draft = ObligationEditorDraft(record: record)
        draft.title = "Mortgage Payment"
        draft.originalEntry = "Mortgage due on the 15th, remind me ahead of time"
        draft.explanation = "I understood this as a monthly payment reminder."
        draft.reminderLeadDaysText = "10, 3"

        let updated = draft.materializedRecord()

        #expect(updated.id == "mortgage")
        #expect(updated.title == "Mortgage Payment")
        #expect(updated.originalEntry == "Mortgage due on the 15th, remind me ahead of time")
        #expect(updated.explanation == "I understood this as a monthly payment reminder.")
        #expect(updated.reminderLeadDays == [10, 3])
    }

    @Test
    func sourceSnapshotTracksPlaceholderState() {
        let placeholderSnapshot = SourceSnapshot(
            source: SourceDescriptor(id: "sample-weather", displayName: "Weather", type: .weather),
            placeholderLabel: "Sample weather data"
        )
        let liveSnapshot = SourceSnapshot(
            source: SourceDescriptor(id: "open-meteo", displayName: "Weather", type: .weather)
        )

        #expect(placeholderSnapshot.isPlaceholder)
        #expect(placeholderSnapshot.placeholderLabel == "Sample weather data")
        #expect(liveSnapshot.isPlaceholder == false)
    }

    @Test
    func calendarEventDisappearanceIsNotTreatedAsCancellation() {
        let engine = ReadyRoomRulesEngine()
        let source = SourceDescriptor(id: "calendar", displayName: "Calendars", type: .calendar)
        let previous = NormalizedItem(
            id: "calendar:missing",
            source: source,
            sourceIdentifier: "missing",
            sourceType: .calendar,
            title: "Previously seen",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800)
        )

        let items = engine.normalizeCalendarEvents([], source: source, configurations: [:], health: .healthy, previousItems: [previous.id: previous])

        #expect(items.isEmpty)
    }

    @Test
    func explicitCancelledCalendarEventRemainsCancelled() {
        let engine = ReadyRoomRulesEngine()
        let source = SourceDescriptor(id: "calendar", displayName: "Calendars", type: .calendar)
        let event = RawCalendarEvent(
            id: "cancelled",
            calendarIdentifier: "shared",
            calendarTitle: "Family Shared",
            title: "Soccer practice",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isCancelled: true
        )

        let items = engine.normalizeCalendarEvents([event], source: source, configurations: [:], health: .healthy)

        #expect(items.count == 1)
        #expect(items[0].changeState == .cancelled)
    }

    @Test
    func dashboardTimelinePolicyShowsYesterdayUntilThreeAM() {
        let calendar = Calendar.readyRoomGregorian
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 2, minute: 15))!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 13, hour: 18, minute: 0))!
        let yesterdayItem = NormalizedItem(
            id: "calendar:yesterday",
            source: SourceDescriptor(id: "calendar", displayName: "Calendars", type: .calendar),
            sourceIdentifier: "yesterday",
            sourceType: .calendar,
            title: "Dinner",
            startDate: yesterday,
            endDate: yesterday.addingTimeInterval(3600)
        )

        #expect(DashboardTimelinePolicy.includes(yesterdayItem, now: now))
        #expect(DashboardTimelinePolicy.isCompleted(yesterdayItem, now: now))
    }

    @Test
    func dashboardTimelinePolicyHidesYesterdayAfterThreeAM() {
        let calendar = Calendar.readyRoomGregorian
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 3, minute: 1))!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 13, hour: 18, minute: 0))!
        let yesterdayItem = NormalizedItem(
            id: "calendar:yesterday",
            source: SourceDescriptor(id: "calendar", displayName: "Calendars", type: .calendar),
            sourceIdentifier: "yesterday",
            sourceType: .calendar,
            title: "Dinner",
            startDate: yesterday,
            endDate: yesterday.addingTimeInterval(3600)
        )

        #expect(DashboardTimelinePolicy.includes(yesterdayItem, now: now) == false)
    }

    @Test
    func dashboardTimelinePolicyStillShowsCalendarItemsWhenDashboardFlagIsFalse() {
        let item = NormalizedItem(
            id: "calendar:hidden-flag",
            source: SourceDescriptor(id: "calendar", displayName: "Calendars", type: .calendar),
            sourceIdentifier: "hidden-flag",
            sourceType: .calendar,
            title: "Work meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            inclusion: InclusionFlags(dashboard: false, johnBriefing: true, amyBriefing: false)
        )

        #expect(DashboardTimelinePolicy.shouldDisplay(item))
    }

    @Test
    func dashboardTimelinePolicyCapsVisibleWindowAtFiveDaysAfterThreeAM() {
        let calendar = Calendar.readyRoomGregorian
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 10, minute: 0))!
        let item = NormalizedItem(
            id: "calendar:week-long",
            source: SourceDescriptor(id: "calendar", displayName: "Calendars", type: .calendar),
            sourceIdentifier: "week-long",
            sourceType: .calendar,
            title: "Spring break",
            startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 14))!,
            endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 21))!,
            isAllDay: true
        )

        let buckets = DashboardTimelinePolicy.dayBuckets(for: now, calendar: calendar)
        let days = DashboardTimelinePolicy.displayDays(item, now: now, calendar: calendar)

        #expect(buckets.visibleDays == [
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 14))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 16))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 17))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 18))!
        ])
        #expect(buckets.upcoming == [
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 16))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 17))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 18))!
        ])
        #expect(days == buckets.visibleDays)
    }

    @Test
    func dashboardTimelinePolicyKeepsYesterdayButStillCapsTotalDaysBeforeThreeAM() {
        let calendar = Calendar.readyRoomGregorian
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 1, minute: 30))!
        let item = NormalizedItem(
            id: "calendar:week-long-carry",
            source: SourceDescriptor(id: "calendar", displayName: "Calendars", type: .calendar),
            sourceIdentifier: "week-long-carry",
            sourceType: .calendar,
            title: "Spring break",
            startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 13))!,
            endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 21))!,
            isAllDay: true
        )

        let buckets = DashboardTimelinePolicy.dayBuckets(for: now, calendar: calendar)
        let days = DashboardTimelinePolicy.displayDays(item, now: now, calendar: calendar)

        #expect(buckets.visibleDays == [
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 13))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 14))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 16))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 17))!
        ])
        #expect(buckets.carryoverDays == [
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 13))!
        ])
        #expect(buckets.upcoming == [
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 16))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 17))!
        ])
        #expect(days == buckets.visibleDays)
    }

    @Test
    func dashboardTimelinePolicyGroupsPostTomorrowDaysIntoUpcomingSection() {
        let calendar = Calendar.readyRoomGregorian
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 10, minute: 0))!
        let source = SourceDescriptor(id: "calendar", displayName: "Calendars", type: .calendar)
        let sections = DashboardTimelinePolicy.groupedSections(
            for: [
                NormalizedItem(
                    id: "calendar:today",
                    source: source,
                    sourceIdentifier: "today",
                    sourceType: .calendar,
                    title: "School dropoff",
                    startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 8, minute: 0))!,
                    endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 8, minute: 30))!
                ),
                NormalizedItem(
                    id: "calendar:tomorrow",
                    source: source,
                    sourceIdentifier: "tomorrow",
                    sourceType: .calendar,
                    title: "Piano lesson",
                    startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 16, minute: 0))!,
                    endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 17, minute: 0))!
                ),
                NormalizedItem(
                    id: "calendar:upcoming-1",
                    source: source,
                    sourceIdentifier: "upcoming-1",
                    sourceType: .calendar,
                    title: "Team sync",
                    startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 16, hour: 10, minute: 0))!,
                    endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 16, hour: 10, minute: 30))!
                ),
                NormalizedItem(
                    id: "calendar:upcoming-2",
                    source: source,
                    sourceIdentifier: "upcoming-2",
                    sourceType: .calendar,
                    title: "Band concert",
                    startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 18, hour: 19, minute: 0))!,
                    endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 18, hour: 20, minute: 0))!
                ),
                NormalizedItem(
                    id: "calendar:excluded",
                    source: source,
                    sourceIdentifier: "excluded",
                    sourceType: .calendar,
                    title: "Outside window",
                    startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 19, hour: 9, minute: 0))!,
                    endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 19, hour: 10, minute: 0))!
                )
            ],
            now: now,
            calendar: calendar
        )

        #expect(sections.map(\.title) == [
            "Today — Saturday, Mar 14",
            "Tomorrow — Sunday, Mar 15",
            "Upcoming"
        ])
        #expect(sections[0].dayGroups[0].scheduledItems.map(\.id) == ["calendar:today"])
        #expect(sections[1].dayGroups[0].scheduledItems.map(\.id) == ["calendar:tomorrow"])
        #expect(sections[2].dayGroups.map(\.title) == [
            "Monday, Mar 16",
            "Wednesday, Mar 18"
        ])
        #expect(sections[2].dayGroups.flatMap { $0.scheduledItems.map(\.id) } == [
            "calendar:upcoming-1",
            "calendar:upcoming-2"
        ])
    }

    @Test
    func personColorPaletteDefaultsMatchDesignPalette() {
        let palette = PersonColorPaletteSettings.default

        #expect(palette.johnHex == "#3478F6")
        #expect(palette.amyHex == "#39A96B")
        #expect(palette.ellieHex == "#B58AF7")
        #expect(palette.miaHex == "#7ECFFF")
    }

    @Test
    func personColorPaletteResetReturnsToDefaults() {
        var palette = PersonColorPaletteSettings(
            johnHex: "#000000",
            amyHex: "#111111",
            ellieHex: "#222222",
            miaHex: "#333333"
        )

        palette.resetToDefaults()

        #expect(palette == .default)
    }

    @Test
    func personColorPaletteStoreRoundTripsSettings() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let coordinator = ReadyRoomStorageCoordinator(
            localRootOverride: root.appendingPathComponent("LocalRoot", isDirectory: true),
            sharedRootOverride: root.appendingPathComponent("SharedRoot", isDirectory: true)
        )
        let store = PersonColorPaletteSettingsStore(coordinator: coordinator)
        let saved = PersonColorPaletteSettings(
            johnHex: "#112233",
            amyHex: "#445566",
            ellieHex: "#778899",
            miaHex: "#AABBCC"
        )

        try await store.save(saved)
        let loaded = try await store.load()

        #expect(loaded == saved)
    }

    @Test
    func audienceAccentResolverReturnsSingleNamedPerson() {
        let accent = ItemAudienceAccentResolver.resolve(
            owner: .john,
            relevantPeople: [.john],
            palette: .default
        )

        #expect(accent.tokens.map(\.label) == ["John"])
        #expect(accent.primaryHex == "#3478F6")
        #expect(accent.isNeutralFallback == false)
    }

    @Test
    func audienceAccentResolverKeepsTwoPeopleInStableOrder() {
        let accent = ItemAudienceAccentResolver.resolve(
            owner: nil,
            relevantPeople: [.amy, .john],
            palette: .default
        )

        #expect(accent.tokens.map(\.label) == ["John", "Amy"])
        #expect(accent.tokens.map(\.hex) == ["#3478F6", "#39A96B"])
    }

    @Test
    func audienceAccentResolverPlacesOwnerFirstForThreeOrMorePeople() {
        let accent = ItemAudienceAccentResolver.resolve(
            owner: .amy,
            relevantPeople: [.john, .amy, .ellie],
            palette: .default
        )

        #expect(accent.tokens.map(\.label) == ["Amy", "John", "Ellie"])
        #expect(accent.primaryHex == "#39A96B")
    }

    @Test
    func audienceAccentResolverIgnoresFamilyWhenNamedPeopleExist() {
        let accent = ItemAudienceAccentResolver.resolve(
            owner: nil,
            relevantPeople: [.family, .john, .mia],
            palette: .default
        )

        #expect(accent.tokens.map(\.label) == ["John", "Mia"])
        #expect(accent.tokens.contains(where: { $0.label == "Family" }) == false)
        #expect(accent.isNeutralFallback == false)
    }

    @Test
    func audienceAccentResolverUsesNeutralFallbackForFamilyOrUnresolved() {
        let familyAccent = ItemAudienceAccentResolver.resolve(
            owner: nil,
            relevantPeople: [.family],
            palette: .default
        )
        let generalAccent = ItemAudienceAccentResolver.resolve(
            owner: nil,
            relevantPeople: [],
            palette: .default
        )

        #expect(familyAccent.tokens.map(\.label) == ["Family"])
        #expect(familyAccent.primaryHex == ItemAudienceAccentResolver.neutralHex)
        #expect(familyAccent.isNeutralFallback)
        #expect(generalAccent.tokens.map(\.label) == ["General"])
        #expect(generalAccent.primaryHex == ItemAudienceAccentResolver.neutralHex)
        #expect(generalAccent.isNeutralFallback)
    }

    @Test
    func multiDayAllDayEventShowsOnEachCoveredVisibleDay() {
        let calendar = Calendar.readyRoomGregorian
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 10, minute: 0))!
        let item = NormalizedItem(
            id: "calendar:trip",
            source: SourceDescriptor(id: "calendar", displayName: "Calendars", type: .calendar),
            sourceIdentifier: "trip",
            sourceType: .calendar,
            title: "Amy - Chicago",
            startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 13))!,
            endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 16))!,
            isAllDay: true
        )

        let days = DashboardTimelinePolicy.displayDays(item, now: now, calendar: calendar)

        #expect(days == [
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 14))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!
        ])
        #expect(DashboardTimelinePolicy.includes(item, now: now, calendar: calendar))
        #expect(DashboardTimelinePolicy.isCompleted(item, now: now, calendar: calendar) == false)
    }

    @Test
    func multiDayAllDayEventIncludesStartDayDuringCarryWindow() {
        let calendar = Calendar.readyRoomGregorian
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 1, minute: 30))!
        let item = NormalizedItem(
            id: "calendar:trip-carry",
            source: SourceDescriptor(id: "calendar", displayName: "Calendars", type: .calendar),
            sourceIdentifier: "trip-carry",
            sourceType: .calendar,
            title: "Amy - Chicago",
            startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 13))!,
            endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 16))!,
            isAllDay: true
        )

        let days = DashboardTimelinePolicy.displayDays(item, now: now, calendar: calendar)

        #expect(days == [
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 13))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 14))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!
        ])
    }

    @Test
    func storageRootsUseLocalFallbackWhenICloudRootIsUnavailable() {
        let roots = StorageRoots(
            localRoot: URL(filePath: "/tmp/ReadyRoom"),
            sharedRoot: nil,
            sharedMode: .localFallback
        )

        #expect(roots.sharedMode == .localFallback)
        #expect(roots.syncsAcrossMacs == false)
        #expect(roots.effectiveSharedRoot.path == "/tmp/ReadyRoom/SharedFallback")
    }

    @Test
    func storageRootsUseCustomFolderWithoutNeedingMatchingAbsolutePathsAcrossMacs() {
        let roots = StorageRoots(
            localRoot: URL(filePath: "/tmp/ReadyRoom"),
            sharedRoot: URL(filePath: "/Users/example/Resilio Sync/Ready Room Shared"),
            sharedMode: .customFolder
        )

        #expect(roots.sharedMode == .customFolder)
        #expect(roots.syncsAcrossMacs)
        #expect(roots.effectiveSharedRoot.path == "/Users/example/Resilio Sync/Ready Room Shared")
    }

    @Test
    func storageStatusFallbackMessagingExplainsLocalFallbackWithoutCallingFilesMissing() {
        let status = StorageStatus(
            roots: StorageRoots(
                localRoot: URL(filePath: "/tmp/ReadyRoom"),
                sharedRoot: nil,
                sharedMode: .localFallback
            ),
            sharedFiles: [],
            localFiles: []
        )

        #expect(status.summary.contains("local fallback folder"))
        #expect(status.summary.contains("not syncing across computers yet"))
        #expect(status.detail.contains("not signed with iCloud entitlements yet"))
    }

    @Test
    func storageStatusCustomFolderMessagingExplainsLocalPerMacPath() {
        let status = StorageStatus(
            roots: StorageRoots(
                localRoot: URL(filePath: "/tmp/ReadyRoom"),
                sharedRoot: URL(filePath: "/Users/example/Resilio Sync/Ready Room Shared"),
                sharedMode: .customFolder
            ),
            sharedFiles: [],
            localFiles: []
        )

        #expect(status.summary.contains("custom shared folder"))
        #expect(status.detail.contains("stored locally on this Mac"))
        #expect(status.detail.contains("different absolute Resilio Sync path"))
    }

    @Test
    func senderSettingsReturnAudienceSpecificRecipients() {
        let settings = SenderSettings(
            primary: PrimarySenderConfiguration(machineIdentifier: "mac-mini"),
            johnRecipients: ["john@example.com", "family@example.com"],
            amyRecipients: ["amy@example.com"]
        )

        #expect(settings.recipients(for: .john) == ["john@example.com", "family@example.com"])
        #expect(settings.recipients(for: .amy) == ["amy@example.com"])
    }

    @Test
    func senderSettingsDecodeLegacySharedConfigWithoutSMTPFields() throws {
        let json = """
        {
          "primary": {
            "machineIdentifier": "mac-mini",
            "scheduledSendHour": 6,
            "scheduledSendMinute": 30,
            "catchUpDeadlineHour": 12
          },
          "johnRecipients": ["john@example.com"],
          "amyRecipients": ["amy@example.com"]
        }
        """
        let decoded = try JSONDecoder().decode(SenderSettings.self, from: Data(json.utf8))

        #expect(decoded.preferredTransport == .smtp)
        #expect(decoded.allowAppleMailFallback == true)
        #expect(decoded.smtp == SMTPSenderConfiguration())
    }

    @Test
    func senderSettingsStoreRoundTripsSMTPConfiguration() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let coordinator = ReadyRoomStorageCoordinator(
            localRootOverride: root.appendingPathComponent("LocalRoot", isDirectory: true),
            sharedRootOverride: root.appendingPathComponent("SharedRoot", isDirectory: true)
        )
        let store = SenderSettingsStore(coordinator: coordinator)
        let saved = SenderSettings(
            primary: PrimarySenderConfiguration(machineIdentifier: "mac-mini"),
            johnRecipients: ["john@example.com"],
            amyRecipients: ["amy@example.com"],
            preferredTransport: .smtp,
            allowAppleMailFallback: true,
            smtp: SMTPSenderConfiguration(
                isEnabled: true,
                host: "smtp.example.com",
                port: 587,
                security: .startTLS,
                username: "readyroom@example.com",
                fromAddress: "readyroom@example.com",
                fromDisplayName: "Ready Room",
                authentication: .login,
                connectionTimeoutSeconds: 25
            )
        )

        try await store.save(saved)
        let loaded = try await store.load()

        #expect(loaded == saved)
    }

    @Test
    func keychainSecretStoreSavesLoadsAndDeletesSMTPPassword() async throws {
        let store = KeychainSecretStore(service: "com.jkfisher.readyroom.tests.\(UUID().uuidString)")
        let account = "smtp-password:test"

        try await store.save(secret: "app-password-123", account: account)
        #expect(try await store.load(account: account) == "app-password-123")

        try await store.delete(account: account)
        #expect(try await store.load(account: account) == nil)
    }

    @Test
    func weatherSettingsDefaultToPiscatawayZipCode() {
        let settings = WeatherSettings()

        #expect(settings.locationQuery == "08854")
        #expect(settings.hasResolvedCoordinates == false)
    }

    @Test
    func weatherSettingsStoreRoundTripsResolvedLocation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let coordinator = ReadyRoomStorageCoordinator(
            localRootOverride: root.appendingPathComponent("LocalRoot", isDirectory: true),
            sharedRootOverride: root.appendingPathComponent("SharedRoot", isDirectory: true)
        )
        let store = WeatherSettingsStore(coordinator: coordinator)
        let saved = WeatherSettings(
            locationQuery: "Piscataway, NJ",
            resolvedDisplayName: "Piscataway, NJ",
            latitude: 40.5541,
            longitude: -74.4643,
            lastResolvedAt: Date(timeIntervalSince1970: 1_710_000_000)
        )

        try await store.save(saved)
        let loaded = try await store.load()

        #expect(loaded == saved)
    }

    @Test
    func openMeteoWeatherCodeMapperProvidesReadableSummariesAndSymbols() {
        #expect(OpenMeteoWeatherCodeMapper.summary(for: 0) == "Clear")
        #expect(OpenMeteoWeatherCodeMapper.symbolName(for: 0) == "sun.max.fill")
        #expect(OpenMeteoWeatherCodeMapper.summary(for: 63) == "Rainy")
        #expect(OpenMeteoWeatherCodeMapper.symbolName(for: 95) == "cloud.bolt.rain.fill")
    }

    @Test
    func weatherSourceSnapshotFactoryExposesUnconfiguredAndUnavailableStates() {
        let unconfigured = WeatherSourceSnapshotFactory.unconfigured(message: "Set weather in Settings.")
        let unavailable = WeatherSourceSnapshotFactory.unavailable(message: "Weather request failed.")

        #expect(unconfigured.source.type == .weather)
        #expect(unconfigured.health.status == .unconfigured)
        #expect(unconfigured.health.message == "Set weather in Settings.")
        #expect(unconfigured.placeholderLabel == nil)
        #expect(unavailable.health.status == .unavailable)
        #expect(unavailable.health.message == "Weather request failed.")
    }

    @Test
    func sharedObligationSyncGateReloadsWhenSharedFileChanges() {
        let earlier = Calendar.readyRoomGregorian.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 0, minute: 0))!
        let later = earlier.addingTimeInterval(60)

        #expect(SharedObligationSyncGate.shouldReload(lastSeen: earlier, current: later, force: false))
        #expect(SharedObligationSyncGate.shouldReload(lastSeen: earlier, current: earlier, force: false) == false)
        #expect(SharedObligationSyncGate.shouldReload(lastSeen: nil, current: nil, force: true))
    }
}

private struct StubSenderAdapter: SenderAdapter {
    let id: String
    let displayName: String
    var failure: Error?

    init(id: String, displayName: String, failure: Error? = nil) {
        self.id = id
        self.displayName = displayName
        self.failure = failure
    }

    func send(artifact: BriefingArtifact, mode: SendMode, machineIdentifier: String) async throws -> SendExecutionResult {
        if let failure {
            throw failure
        }

        let record = SendExecutionRecord(
            briefingDate: artifact.generatedAt,
            audience: artifact.audience,
            machineIdentifier: machineIdentifier,
            senderID: id,
            sendMode: mode,
            status: mode == .previewOnly ? .pending : .sent,
            preferredMode: artifact.preferredMode,
            actualMode: artifact.actualMode,
            completedAt: mode == .previewOnly ? nil : .now,
            dedupeKey: "\(artifact.generatedAt.formattedMonthDayWeekday()):\(artifact.audience.rawValue)"
        )
        return SendExecutionResult(record: record, messageID: "\(id)-message")
    }
}
