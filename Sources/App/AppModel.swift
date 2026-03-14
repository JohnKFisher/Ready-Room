import Foundation
import ReadyRoomBriefings
import ReadyRoomConnectors
import ReadyRoomCore
import ReadyRoomPersistence

@MainActor
final class ReadyRoomAppModel: ObservableObject {
    enum Screen: String, CaseIterable, Identifiable {
        case dashboard
        case preview
        case obligations
        case settings
        case debug

        var id: String { rawValue }
    }

    enum PreferencesSection: String, CaseIterable, Identifiable {
        case general = "General"
        case calendars = "Calendars"
        case briefings = "Briefings"
        case dashboard = "Dashboard"
        case obligations = "Obligations"
        case ai = "AI"
        case news = "News"
        case media = "Media"
        case storageSync = "Storage/Sync"
        case sender = "Sender"
        case advancedDebug = "Advanced/Debug"

        var id: String { rawValue }
    }

    @Published var selectedScreen: Screen = .dashboard
    @Published var selectedPreferencesSection: PreferencesSection = .general
    @Published var now = Date()
    @Published var normalizedItems: [NormalizedItem] = []
    @Published var dueSoon: [NormalizedItem] = []
    @Published var conflicts: [ConflictMarker] = []
    @Published var weather: WeatherSnapshot?
    @Published var headlines: [NewsHeadline] = []
    @Published var mediaItems: [MediaActivity] = []
    @Published var dashboardSummaryByMode: [NarrativeGenerationMode: GeneratedNarrative] = [:]
    @Published var previewArtifacts: [BriefingAudience: [NarrativeGenerationMode: BriefingArtifact]] = [:]
    @Published var sourceSnapshots: [SourceSnapshot] = []
    @Published var cardLayout = DashboardCardLayout()
    @Published var setupProgress = SetupProgress()
    @Published var obligations: [ObligationRecord] = []
    @Published var obligationDraft = ""
    @Published var parsedObligationCandidate: ParsedObligationCandidate?
    @Published var obligationEditor: ObligationEditorDraft?
    @Published var selectedObligationID: String?
    @Published var statusMessage = "Loading Ready Room..."
    @Published var showSendChooser = false
    @Published var compareBriefingModes = false
    @Published var compareDashboardModes = false
    @Published var dashboardModeEnabled = false
    @Published var preferredMode: NarrativeGenerationMode = .foundationModels
    @Published var machineIdentifier = ""
    @Published var senderSettings = SenderSettings()
    @Published var primarySenderConfiguration = PrimarySenderConfiguration(machineIdentifier: "")
    @Published var storagePreferences = StoragePreferences()
    @Published var storageStatus: StorageStatus?
    @Published var storageStatusError: String?
    @Published var debugJSON = ""
    @Published var quietHours = QuietHoursSettings()
    @Published var lastGeneratedPreviewAudience: BriefingAudience = .john

    private let storageCoordinator = ReadyRoomStorageCoordinator()
    private lazy var layoutStore = DashboardLayoutStore(coordinator: storageCoordinator)
    private lazy var setupStore = SetupProgressStore(coordinator: storageCoordinator)
    private lazy var calendarStore = CalendarConfigurationStore(coordinator: storageCoordinator)
    private lazy var archiveStore = ArchiveStore(coordinator: storageCoordinator)
    private lazy var obligationsStore = ObligationsYAMLStore(coordinator: storageCoordinator)
    private lazy var sendRegistryStore = SendRegistryStore(coordinator: storageCoordinator)
    private lazy var senderSettingsStore = SenderSettingsStore(coordinator: storageCoordinator)
    private lazy var machineIdentityStore = MachineIdentityStore(coordinator: storageCoordinator)
    private let rulesEngine = ReadyRoomRulesEngine()
    private let parser = PlainEnglishObligationParser()
    private let sendCoordinator = ScheduledSendCoordinator()
    private let mailSender = AppleMailSenderAdapter()
    private var lastKnownObligationsModifiedAt: Date?
    private var attemptedScheduledSendKeys: Set<String> = []

    init() {
        Task {
            await bootstrap()
        }
    }

    func bootstrap() async {
        do {
            cardLayout = try await layoutStore.load()
            setupProgress = try await setupStore.load()
            machineIdentifier = try await machineIdentityStore.loadOrCreate()
            senderSettings = try await senderSettingsStore.load()
            primarySenderConfiguration = senderSettings.primary
            obligations = try await obligationsStore.load()
            lastKnownObligationsModifiedAt = try await obligationsStore.modificationDate()
            await refreshStorageStatus()
            await refresh()
        } catch {
            statusMessage = "Bootstrap failed: \(error.localizedDescription)"
        }
    }

    func refresh() async {
        statusMessage = quietHours.isActive(at: now) ? "Quiet hours active." : "Refreshing sources..."
        _ = await syncSharedObligations(force: true)
        let snapshots = await collectSnapshots()
        sourceSnapshots = snapshots
        await applySnapshots(snapshots)
        await generateNarrativesAndPreviews()
        updateDebugJSON()
        statusMessage = "Ready"
        await evaluateScheduledSendsIfNeeded()
    }

    func parseObligationDraft() {
        let parsed = parser.parse(obligationDraft, now: now)
        parsedObligationCandidate = parsed
        obligationEditor = parsed.structured.map(ObligationEditorDraft.init(record:))
        selectedObligationID = nil
    }

    func updateObligationEditor(_ mutate: (inout ObligationEditorDraft) -> Void) {
        guard var editor = obligationEditor else {
            return
        }
        mutate(&editor)
        obligationEditor = editor
        if var candidate = parsedObligationCandidate {
            candidate.structured = editor.materializedRecord()
            candidate.explanation = editor.explanation.isEmpty ? candidate.explanation : editor.explanation
            parsedObligationCandidate = candidate
        }
    }

    func beginEditingObligation(_ obligation: ObligationRecord) {
        selectedObligationID = obligation.id
        obligationDraft = obligation.originalEntry ?? obligation.title
        let explanation = obligation.explanation ?? "Editing saved obligation."
        parsedObligationCandidate = ParsedObligationCandidate(
            originalText: obligation.originalEntry ?? obligation.title,
            structured: obligation,
            explanation: explanation,
            confidence: 1.0
        )
        obligationEditor = ObligationEditorDraft(record: obligation)
    }

    func cancelObligationEditing() {
        selectedObligationID = nil
        obligationEditor = nil
        parsedObligationCandidate = nil
    }

    func saveObligationEditor() async {
        guard let editor = obligationEditor else {
            return
        }
        let record = editor.materializedRecord()
        let existingIndex = obligations.firstIndex(where: { $0.id == record.id })
        if let existingIndex {
            obligations[existingIndex] = record
        } else {
            obligations.append(record)
        }
        do {
            try await obligationsStore.save(obligations)
            await refreshStorageStatus()
            obligationDraft = ""
            cancelObligationEditing()
            statusMessage = existingIndex == nil ? "Saved obligation." : "Updated obligation."
            await refresh()
        } catch {
            statusMessage = "Could not save obligation: \(error.localizedDescription)"
        }
    }

    var isEditingSavedObligation: Bool {
        guard let editor = obligationEditor else {
            return false
        }
        return obligations.contains(where: { $0.id == editor.id })
    }

    func snapshot(for type: SourceType) -> SourceSnapshot? {
        sourceSnapshots.first(where: { $0.source.type == type })
    }

    func placeholderLabel(for type: SourceType) -> String? {
        snapshot(for: type)?.placeholderLabel
    }

    func refreshStorageStatus() async {
        do {
            storagePreferences = try await storageCoordinator.loadStoragePreferences()
            storageStatus = try await storageCoordinator.describeStorageStatus()
            storageStatusError = nil
        } catch {
            storageStatus = nil
            storageStatusError = error.localizedDescription
        }
    }

    func setCustomSharedFolder(_ url: URL?) async {
        do {
            try await storageCoordinator.setCustomSharedRoot(url)
            lastKnownObligationsModifiedAt = nil
            senderSettings = try await senderSettingsStore.load()
            primarySenderConfiguration = senderSettings.primary
            await refreshStorageStatus()
            await refresh()
            statusMessage = url == nil ? "Using local fallback shared storage." : "Updated the shared folder for this Mac."
        } catch {
            storageStatusError = error.localizedDescription
            statusMessage = "Could not update shared folder: \(error.localizedDescription)"
        }
    }

    func saveSenderSettings(
        johnRecipientsText: String,
        amyRecipientsText: String,
        scheduledSendHour: Int,
        scheduledSendMinute: Int,
        catchUpDeadlineHour: Int
    ) async {
        var settings = senderSettings
        settings.primary.scheduledSendHour = scheduledSendHour
        settings.primary.scheduledSendMinute = scheduledSendMinute
        settings.primary.catchUpDeadlineHour = catchUpDeadlineHour
        settings.johnRecipients = parseRecipients(from: johnRecipientsText)
        settings.amyRecipients = parseRecipients(from: amyRecipientsText)
        await persistSenderSettings(settings, status: "Saved sender settings.")
    }

    func makeThisMacPrimarySender() async {
        var settings = senderSettings
        settings.primary.machineIdentifier = machineIdentifier
        await persistSenderSettings(settings, status: "This Mac is now the primary scheduled sender.")
    }

    func clearPrimarySender() async {
        var settings = senderSettings
        settings.primary.machineIdentifier = ""
        await persistSenderSettings(settings, status: "Cleared the primary scheduled sender.")
    }

    private func syncSharedObligations(force: Bool) async -> Bool {
        do {
            let modificationDate = try await obligationsStore.modificationDate()
            guard SharedObligationSyncGate.shouldReload(
                lastSeen: lastKnownObligationsModifiedAt,
                current: modificationDate,
                force: force
            ) else {
                return false
            }

            let latestObligations = try await obligationsStore.load()
            let changed = latestObligations != obligations || modificationDate != lastKnownObligationsModifiedAt
            obligations = latestObligations
            lastKnownObligationsModifiedAt = modificationDate
            await refreshStorageStatus()
            return changed
        } catch {
            storageStatusError = error.localizedDescription
            return false
        }
    }

    func moveCard(_ kind: DashboardCardKind, direction: Int) {
        guard let index = cardLayout.cardOrder.firstIndex(of: kind) else {
            return
        }
        let newIndex = max(0, min(cardLayout.cardOrder.count - 1, index + direction))
        guard newIndex != index else {
            return
        }
        let moved = cardLayout.cardOrder.remove(at: index)
        cardLayout.cardOrder.insert(moved, at: newIndex)
        Task {
            try? await layoutStore.save(cardLayout)
        }
    }

    func artifact(for audience: BriefingAudience, mode: NarrativeGenerationMode) -> BriefingArtifact? {
        previewArtifacts[audience]?[mode]
    }

    func sendNow(_ audiences: [BriefingAudience]) async {
        let artifacts = audiences.compactMap { artifact(for: $0, mode: preferredMode) ?? artifact(for: $0, mode: .templated) }
        for artifact in artifacts {
            do {
                let result = try await performSend(artifact: artifact, mode: .manualTest, adapters: [mailSender])
                try await sendRegistryStore.append(result.record)
                statusMessage = "Sent \(artifact.audience.displayName) briefing."
            } catch {
                statusMessage = "Send failed for \(artifact.audience.displayName): \(error.localizedDescription)"
            }
        }
    }

    func runClockLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            now = Date()
            if await syncSharedObligations(force: false) {
                statusMessage = "Shared obligations updated."
                await refresh()
                continue
            }
            await evaluateScheduledSendsIfNeeded()
        }
    }

    private func collectSnapshots() async -> [SourceSnapshot] {
        var snapshots = DevelopmentData.sampleSnapshots(referenceDate: now)

        let calendarConnector = EventKitCalendarConnector()
        if let liveCalendar = try? await calendarConnector.refresh(),
           liveCalendar.health.status != .unauthorized,
           !liveCalendar.calendarEvents.isEmpty {
            snapshots.removeAll(where: { $0.source.id == "sample-calendar" })
            snapshots.append(liveCalendar)
        }

        return snapshots
    }

    private func applySnapshots(_ snapshots: [SourceSnapshot]) async {
        let calendarSnapshot = snapshots.first(where: { $0.source.type == .calendar })
        let weatherSnapshot = snapshots.first(where: { $0.source.type == .weather })
        let newsSnapshot = snapshots.first(where: { $0.source.type == .news })
        let mediaSnapshot = snapshots.first(where: { $0.source.type == .media })

        weather = weatherSnapshot?.weather
        headlines = newsSnapshot?.headlines ?? []
        mediaItems = mediaSnapshot?.mediaItems ?? []

        let configurations = (try? await calendarStore.load()) ?? []
        let configMap = ReadyRoomCollections.dictionaryLastValueWins(
            from: configurations.map { ($0.calendarIdentifier, $0) }
        )
        let previous = ReadyRoomCollections.dictionaryLastValueWins(
            from: normalizedItems.map { ($0.id, $0) }
        )
        let calendarItems = rulesEngine.normalizeCalendarEvents(
            calendarSnapshot?.calendarEvents ?? [],
            source: calendarSnapshot?.source ?? SourceDescriptor(id: "sample-calendar", displayName: "Sample Calendar", type: .calendar),
            configurations: configMap,
            health: calendarSnapshot?.health.resolvedStatus(at: now) ?? .healthy,
            previousItems: previous
        )
        let previousDueSoon = Set(dueSoon.map(\.sourceIdentifier))
        let dueSoonItems = rulesEngine.dueSoonObligations(
            obligations,
            source: SourceDescriptor(id: "obligations", displayName: "Obligations", type: .obligation),
            health: .healthy,
            referenceDate: now,
            previousVisibleIDs: previousDueSoon
        )
        normalizedItems = calendarItems
        dueSoon = dueSoonItems
        conflicts = rulesEngine.detectConflicts(in: calendarItems)
    }

    private func generateNarrativesAndPreviews() async {
        dashboardSummaryByMode = [:]
        previewArtifacts = [:]

        let pipelines: [NarrativeGenerationMode: NarrativeGenerationPipeline] = [
            .foundationModels: NarrativeGenerationPipeline(preferred: FoundationModelsNarrativeGenerator()),
            .ollama: NarrativeGenerationPipeline(preferred: OllamaNarrativeGenerator()),
            .templated: NarrativeGenerationPipeline(preferred: TemplatedNarrativeGenerator())
        ]

        for mode in NarrativeGenerationMode.allCases {
            let context = DashboardSummaryContext(
                normalizedItems: normalizedItems,
                weather: weather,
                dueSoon: dueSoon,
                sourceStatuses: sourceSnapshots.map { $0.health.resolvedStatus(at: now) }
            )
            let summary = await pipelines[mode]!.dashboardSummary(for: context, preferredMode: mode)
            dashboardSummaryByMode[mode] = summary

            for audience in BriefingAudience.allCases {
                let request = BriefingRequest(
                    audience: audience,
                    date: now,
                    normalizedItems: normalizedItems,
                    weather: weather,
                    headlines: weightedHeadlines(for: audience),
                    mediaItems: mediaItems,
                    dueSoon: dueSoon.filter { audience == .john ? $0.inclusion.johnBriefing : $0.inclusion.amyBriefing },
                    preferredMode: mode,
                    calendarPlaceholderLabel: placeholderLabel(for: .calendar),
                    weatherPlaceholderLabel: placeholderLabel(for: .weather),
                    newsPlaceholderLabel: placeholderLabel(for: .news),
                    mediaPlaceholderLabel: placeholderLabel(for: .media)
                )
                let artifact = BriefingComposer().compose(
                    request: request,
                    recipients: defaultRecipients(for: audience),
                    openingLine: await pipelines[mode]!.openingLine(for: request),
                    newsSummary: await pipelines[mode]!.newsSummary(for: request)
                )
                var byMode = previewArtifacts[audience] ?? [:]
                byMode[mode] = artifact
                previewArtifacts[audience] = byMode
            }
        }
    }

    private func weightedHeadlines(for audience: BriefingAudience) -> [NewsHeadline] {
        switch audience {
        case .john:
            return headlines.sorted { ($0.weight + ($0.sourceName.lowercased().contains("sports") ? 0.2 : 0.0)) > $1.weight }
        case .amy:
            return headlines.sorted { ($0.weight + ($0.sourceName.lowercased().contains("news") ? 0.2 : 0.0)) > $1.weight }
        }
    }

    private func defaultRecipients(for audience: BriefingAudience) -> [String] {
        senderSettings.recipients(for: audience)
    }

    private func updateDebugJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let payload = DebugPayload(
            now: now,
            snapshots: sourceSnapshots,
            normalizedItems: normalizedItems,
            dueSoon: dueSoon,
            conflicts: conflicts
        )
        if let data = try? encoder.encode(payload), let json = String(data: data, encoding: .utf8) {
            debugJSON = json
        }
    }

    private func evaluateScheduledSendsIfNeeded() async {
        let existing = (try? await sendRegistryStore.load()) ?? []
        let dueAudiences = BriefingAudience.allCases.filter { audience in
            let key = sendCoordinator.dedupeKey(for: now, audience: audience)
            return attemptedScheduledSendKeys.contains(key) == false &&
            sendCoordinator.shouldSendToday(
                now: now,
                audience: audience,
                machineIdentifier: machineIdentifier,
                primary: primarySenderConfiguration,
                existingRecords: existing
            )
        }

        guard dueAudiences.isEmpty == false else {
            return
        }

        statusMessage = "Preparing morning briefing send..."
        await refreshBriefingsForScheduledSend()

        for audience in dueAudiences {
            let key = sendCoordinator.dedupeKey(for: now, audience: audience)
            attemptedScheduledSendKeys.insert(key)
            guard let artifact = artifact(for: audience, mode: preferredMode) ?? artifact(for: audience, mode: .templated) else {
                continue
            }

            do {
                let result = try await performSend(artifact: artifact, mode: .scheduled, adapters: [mailSender])
                try await sendRegistryStore.append(result.record)
                statusMessage = "Scheduled send completed for \(audience.displayName)."
            } catch {
                statusMessage = "Scheduled send failed for \(audience.displayName): \(error.localizedDescription)"
            }
        }
    }

    private func performSend(artifact: BriefingArtifact, mode: SendMode, adapters: [SenderAdapter]) async throws -> SendExecutionResult {
        guard artifact.recipients.isEmpty == false else {
            throw NSError(domain: "ReadyRoomSend", code: 1, userInfo: [NSLocalizedDescriptionKey: "No recipients are configured for \(artifact.audience.displayName)."])
        }
        guard let primary = adapters.first else {
            throw NSError(domain: "ReadyRoomSend", code: 0, userInfo: [NSLocalizedDescriptionKey: "No sender configured."])
        }

        do {
            return try await primary.send(artifact: artifact, mode: mode, machineIdentifier: machineIdentifier)
        } catch {
            if mode == .scheduled {
                do {
                    return try await primary.send(artifact: artifact, mode: mode, machineIdentifier: machineIdentifier)
                } catch {
                    for fallback in adapters.dropFirst() {
                        return try await fallback.send(artifact: artifact, mode: mode, machineIdentifier: machineIdentifier)
                    }
                }
            }
            throw error
        }
    }

    private func refreshBriefingsForScheduledSend() async {
        _ = await syncSharedObligations(force: true)
        let snapshots = await collectSnapshots()
        sourceSnapshots = snapshots
        await applySnapshots(snapshots)
        await generateNarrativesAndPreviews()
        updateDebugJSON()
    }

    private func persistSenderSettings(_ settings: SenderSettings, status: String) async {
        do {
            try await senderSettingsStore.save(settings)
            senderSettings = settings
            primarySenderConfiguration = settings.primary
            attemptedScheduledSendKeys.removeAll()
            await generateNarrativesAndPreviews()
            statusMessage = status
        } catch {
            statusMessage = "Could not save sender settings: \(error.localizedDescription)"
        }
    }

    private func parseRecipients(from text: String) -> [String] {
        text
            .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}

private struct DebugPayload: Encodable {
    let now: Date
    let snapshots: [SourceSnapshot]
    let normalizedItems: [NormalizedItem]
    let dueSoon: [NormalizedItem]
    let conflicts: [ConflictMarker]
}

private enum DevelopmentData {
    static func sampleSnapshots(referenceDate: Date) -> [SourceSnapshot] {
        let calendar = Calendar.readyRoomGregorian
        let startOfDay = referenceDate.startOfDay(in: calendar)
        let schoolPickup = RawCalendarEvent(
            id: "pickup",
            calendarIdentifier: "shared-family",
            calendarTitle: "Family Shared",
            title: "Ellie pickup",
            notes: "John can cover if Amy is late.",
            startDate: calendar.date(byAdding: .hour, value: 15, to: startOfDay)!,
            endDate: calendar.date(byAdding: .hour, value: 16, to: startOfDay)!,
            location: "Elementary School"
        )
        let johnWork = RawCalendarEvent(
            id: "john-standup",
            calendarIdentifier: "john-work",
            calendarTitle: "John Work",
            title: "Team standup",
            notes: "WFH today.",
            startDate: calendar.date(byAdding: .hour, value: 9, to: startOfDay)!,
            endDate: calendar.date(byAdding: .hour, value: 10, to: startOfDay)!,
            location: "Home Office",
            sourceOwnerHint: .john
        )
        let amyMeeting = RawCalendarEvent(
            id: "amy-client",
            calendarIdentifier: "amy-work",
            calendarTitle: "Amy Work",
            title: "Client presentation",
            notes: "Big review meeting.",
            startDate: calendar.date(byAdding: .hour, value: 11, to: startOfDay)!,
            endDate: calendar.date(byAdding: .hour, value: 12, to: startOfDay)!,
            location: "Downtown Office",
            sourceOwnerHint: .amy
        )

        let calendarSnapshot = SourceSnapshot(
            source: SourceDescriptor(id: "sample-calendar", displayName: "Sample Calendar", type: .calendar),
            fetchedAt: referenceDate,
            lastGoodFetchAt: referenceDate,
            health: SourceHealth(status: .healthy, lastSuccessAt: referenceDate, freshnessBudget: 900),
            placeholderLabel: "Sample calendar data",
            calendarEvents: [johnWork, amyMeeting, schoolPickup]
        )

        let weatherSnapshot = SourceSnapshot(
            source: SourceDescriptor(id: "sample-weather", displayName: "Weather", type: .weather),
            fetchedAt: referenceDate,
            lastGoodFetchAt: referenceDate,
            health: SourceHealth(status: .healthy, lastSuccessAt: referenceDate, freshnessBudget: 3600),
            placeholderLabel: "Sample weather data",
            weather: WeatherSnapshot(summary: "Sunny", currentTemperatureF: 48, highF: 61, lowF: 42)
        )

        let newsSnapshot = SourceSnapshot(
            source: SourceDescriptor(id: "sample-news", displayName: "News", type: .news),
            fetchedAt: referenceDate,
            lastGoodFetchAt: referenceDate,
            health: SourceHealth(status: .healthy, lastSuccessAt: referenceDate, freshnessBudget: 7200),
            placeholderLabel: "Sample news headlines",
            headlines: [
                NewsHeadline(title: "Markets open mixed as investors watch inflation data", sourceName: "AP", publishedAt: referenceDate, weight: 1.0),
                NewsHeadline(title: "New family movie lands on streaming this weekend", sourceName: "Entertainment Weekly", publishedAt: referenceDate, weight: 0.8)
            ]
        )

        let mediaSnapshot = SourceSnapshot(
            source: SourceDescriptor(id: "sample-media", displayName: "Media", type: .media),
            fetchedAt: referenceDate,
            lastGoodFetchAt: referenceDate,
            health: SourceHealth(status: .healthy, lastSuccessAt: referenceDate, freshnessBudget: 1800),
            placeholderLabel: "Sample Plex/media activity",
            mediaItems: [
                MediaActivity(kind: .nowPlaying, title: "Bluey", user: "Ellie", progress: 0.35, device: "Living Room TV"),
                MediaActivity(kind: .newAddition, title: "The Wild Robot", subtitle: "Recently added to Plex")
            ]
        )

        return [calendarSnapshot, weatherSnapshot, newsSnapshot, mediaSnapshot]
    }
}

enum SharedObligationSyncGate {
    static func shouldReload(lastSeen: Date?, current: Date?, force: Bool) -> Bool {
        guard force == false else {
            return true
        }
        return lastSeen != current
    }
}
