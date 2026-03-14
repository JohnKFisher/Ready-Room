import Foundation
import Testing
@testable import ReadyRoomCore
@testable import ReadyRoomPersistence
@testable import ReadyRoomBriefings

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
}
