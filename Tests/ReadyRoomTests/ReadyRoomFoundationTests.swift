import Foundation
import Testing
@testable import ReadyRoomCore
@testable import ReadyRoomPersistence
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
    func sharedObligationSyncGateReloadsWhenSharedFileChanges() {
        let earlier = Calendar.readyRoomGregorian.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 0, minute: 0))!
        let later = earlier.addingTimeInterval(60)

        #expect(SharedObligationSyncGate.shouldReload(lastSeen: earlier, current: later, force: false))
        #expect(SharedObligationSyncGate.shouldReload(lastSeen: earlier, current: earlier, force: false) == false)
        #expect(SharedObligationSyncGate.shouldReload(lastSeen: nil, current: nil, force: true))
    }
}
