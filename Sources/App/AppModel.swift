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

        var title: String {
            switch self {
            case .dashboard: "Dashboard"
            case .preview: "Briefing"
            case .obligations: "Obligations"
            case .settings: "Settings"
            case .debug: "Debug"
            }
        }
    }

    enum PreferencesSection: String, CaseIterable, Identifiable {
        case general = "General"
        case calendars = "Calendars"
        case briefings = "Briefings"
        case dashboard = "Dashboard"
        case obligations = "Obligations"
        case ai = "AI"
        case weather = "Weather"
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
    @Published var weatherSettings = WeatherSettings()
    @Published var weatherSettingsStatusMessage = "Weather uses Apple location lookup and Open-Meteo forecasts."
    @Published var weatherSettingsError: String?
    @Published var newsSettings = NewsSettings()
    @Published var newsSettingsStatusMessage = "Ready Room uses official RSS and Atom feeds for live news."
    @Published var newsSettingsError: String?
    @Published var personColorPaletteSettings = PersonColorPaletteSettings.default
    @Published var personColorPaletteStatusMessage = "Audience colors are shared across Macs and used in the dashboard and briefings."
    @Published var personColorPaletteError: String?
    @Published var storagePreferences = StoragePreferences()
    @Published var storageStatus: StorageStatus?
    @Published var storageStatusError: String?
    @Published var debugJSON = ""
    @Published var quietHours = QuietHoursSettings()
    @Published var lastGeneratedPreviewAudience: BriefingAudience = .john
    @Published var sendRecords: [SendExecutionRecord] = []
    @Published var smtpPasswordStored = false
    @Published var dashboardNewsSummaryText = "No news items made the cut this morning."

    private let storageCoordinator = ReadyRoomStorageCoordinator()
    private lazy var layoutStore = DashboardLayoutStore(coordinator: storageCoordinator)
    private lazy var calendarBaselineStore = CalendarBaselineStore(coordinator: storageCoordinator)
    private lazy var setupStore = SetupProgressStore(coordinator: storageCoordinator)
    private lazy var calendarStore = CalendarConfigurationStore(coordinator: storageCoordinator)
    private lazy var archiveStore = ArchiveStore(coordinator: storageCoordinator)
    private lazy var obligationsStore = ObligationsYAMLStore(coordinator: storageCoordinator)
    private lazy var sendRegistryStore = SendRegistryStore(coordinator: storageCoordinator)
    private lazy var senderSettingsStore = SenderSettingsStore(coordinator: storageCoordinator)
    private lazy var weatherSettingsStore = WeatherSettingsStore(coordinator: storageCoordinator)
    private lazy var newsSettingsStore = NewsSettingsStore(coordinator: storageCoordinator)
    private lazy var lastGoodNewsSnapshotStore = LastGoodNewsSnapshotStore(coordinator: storageCoordinator)
    private lazy var personColorPaletteStore = PersonColorPaletteSettingsStore(coordinator: storageCoordinator)
    private lazy var machineIdentityStore = MachineIdentityStore(coordinator: storageCoordinator)
    private let rulesEngine = ReadyRoomRulesEngine()
    private let newsRanker = DeterministicNewsRanker()
    private let periodicRefreshPlanner = PeriodicRefreshPlanner()
    private let parser = PlainEnglishObligationParser()
    private let sendCoordinator = ScheduledSendCoordinator()
    private let senderDispatchCoordinator = SenderDispatchCoordinator()
    private let mailSender = AppleMailSenderAdapter()
    private let keychainSecretStore = KeychainSecretStore()
    private let weatherLocationResolver = AppleLocationSearchResolver()
    private var lastKnownObligationsModifiedAt: Date?
    private var attemptedScheduledSendKeys: Set<String> = []
    private let narrativePipelines: [NarrativeGenerationMode: NarrativeGenerationPipeline] = [
        .foundationModels: NarrativeGenerationPipeline(preferred: FoundationModelsNarrativeGenerator()),
        .ollama: NarrativeGenerationPipeline(preferred: OllamaNarrativeGenerator()),
        .templated: NarrativeGenerationPipeline(preferred: TemplatedNarrativeGenerator())
    ]
    private var lastSeenCalendarItems: [String: NormalizedItem] = [:]
    private var refreshWarning: String?
    private var rankedHeadlinesByAudience: [BriefingAudience: [NewsHeadline]] = [:]
    private var lastGoodNewsSnapshot: LastGoodNewsSnapshot?
    private var refreshRequestQueue = RefreshRequestQueue()
    private var refreshInFlight = false
    private var lastCalendarAndObligationsRefreshAt: Date?
    private var lastNewsAndWeatherRefreshAt: Date?

    init() {
        Task {
            await bootstrap()
        }
    }

    func bootstrap() async {
        do {
            cardLayout = try await layoutStore.load()
            let storedCalendarBaseline = try await calendarBaselineStore.load()
            lastSeenCalendarItems = ReadyRoomCollections.dictionaryLastValueWins(
                from: storedCalendarBaseline.map { ($0.id, $0) }
            )
            setupProgress = try await setupStore.load()
            machineIdentifier = try await machineIdentityStore.loadOrCreate()
            senderSettings = try await senderSettingsStore.load()
            primarySenderConfiguration = senderSettings.primary
            sendRecords = try await sendRegistryStore.load()
            await refreshSMTPPasswordStored(for: senderSettings.smtp)
            weatherSettings = try await weatherSettingsStore.load()
            newsSettings = try await newsSettingsStore.load()
            personColorPaletteSettings = try await personColorPaletteStore.load()
            lastGoodNewsSnapshot = try await lastGoodNewsSnapshotStore.load()
            await ensureWeatherSettingsResolvedIfNeeded()
            obligations = try await obligationsStore.load()
            lastKnownObligationsModifiedAt = try await obligationsStore.modificationDate()
            await refreshStorageStatus()
            await enqueueRefresh(.allSources)
            await evaluateScheduledSendsIfNeeded()
        } catch {
            statusMessage = "Bootstrap failed: \(error.localizedDescription)"
        }
    }

    func refresh() async {
        now = Date()
        await enqueueRefresh(.allSources)
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

    func sourceMessage(for type: SourceType) -> String? {
        let snapshot = snapshot(for: type)
        return snapshot?.health.message ?? snapshot?.placeholderLabel
    }

    func rankedHeadlines(for surface: NewsSurface) -> [NewsHeadline] {
        switch surface {
        case .dashboard:
            headlines
        case .john:
            rankedHeadlinesByAudience[.john] ?? []
        case .amy:
            rankedHeadlinesByAudience[.amy] ?? []
        }
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

    func saveWeatherSettings(locationQuery: String) async {
        let trimmedQuery = locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else {
            weatherSettingsError = "Enter a ZIP code or city/state before saving weather."
            weatherSettingsStatusMessage = "Weather location was not changed."
            return
        }

        weatherSettingsStatusMessage = "Resolving weather location..."
        weatherSettingsError = nil

        do {
            let resolved = try await weatherLocationResolver.resolve(trimmedQuery)
            let updatedSettings = WeatherSettings(
                locationQuery: trimmedQuery,
                resolvedDisplayName: resolved.displayName,
                latitude: resolved.latitude,
                longitude: resolved.longitude,
                lastResolvedAt: .now
            )
            try await weatherSettingsStore.save(updatedSettings)
            weatherSettings = updatedSettings
            await refresh()
            weatherSettingsStatusMessage = "Saved weather location for \(updatedSettings.resolvedDisplayName ?? trimmedQuery)."
        } catch {
            weatherSettingsError = error.localizedDescription
            weatherSettingsStatusMessage = "Weather location was not changed."
        }
    }

    func refreshWeatherNow() async {
        weatherSettingsError = nil
        weatherSettingsStatusMessage = "Refreshing weather..."
        await enqueueRefresh(.newsAndWeather)
        if let message = sourceMessage(for: .weather) {
            weatherSettingsStatusMessage = message
        } else if let resolvedDisplayName = weatherSettings.resolvedDisplayName {
            weatherSettingsStatusMessage = "Weather refreshed for \(resolvedDisplayName)."
        } else {
            weatherSettingsStatusMessage = "Weather refreshed."
        }
    }

    func saveNewsSettings(_ settings: NewsSettings) async {
        let normalized = settings.normalized()
        let validationProblems = validateNewsFeeds(normalized.feeds)
        guard validationProblems.isEmpty else {
            newsSettingsError = validationProblems.joined(separator: " ")
            newsSettingsStatusMessage = "News settings were not changed."
            return
        }

        do {
            try await newsSettingsStore.save(normalized)
            newsSettings = normalized
            newsSettingsError = nil
            newsSettingsStatusMessage = "Saved news settings. Live headlines now come from your configured RSS and Atom feeds."
            await enqueueRefresh(.news)
            statusMessage = "Saved news settings."
        } catch {
            newsSettingsError = error.localizedDescription
            newsSettingsStatusMessage = "News settings were not changed."
            statusMessage = "Could not save news settings: \(error.localizedDescription)"
        }
    }

    func applyBaseNewsProfileToAllSurfaces() async {
        await saveNewsSettings(newsSettings.applyingBaseToAllSurfaces())
        if newsSettingsError == nil {
            newsSettingsStatusMessage = "Cleared custom news overrides. Dashboard, John, and Amy now use the shared base profile."
            statusMessage = "Applied the base news profile to every surface."
        }
    }

    func refreshNewsNow() async {
        newsSettingsError = nil
        newsSettingsStatusMessage = "Refreshing news..."
        await enqueueRefresh(.news)
        if let message = sourceMessage(for: .news) {
            newsSettingsStatusMessage = message
        } else if headlines.isEmpty {
            newsSettingsStatusMessage = "No news items made the cut this refresh."
        } else {
            newsSettingsStatusMessage = "News refreshed."
        }
    }

    func savePersonColorPalette(_ settings: PersonColorPaletteSettings) async {
        let normalized = settings.normalized()
        do {
            try await personColorPaletteStore.save(normalized)
            personColorPaletteSettings = normalized
            personColorPaletteError = nil
            personColorPaletteStatusMessage = "Saved audience colors. These colors sync across Macs and update briefings too."
            await refreshStorageStatus()
            await generateNarrativesAndPreviews()
            updateDebugJSON()
            statusMessage = "Saved dashboard audience colors."
        } catch {
            personColorPaletteError = error.localizedDescription
            personColorPaletteStatusMessage = "Audience colors were not changed."
            statusMessage = "Could not save audience colors: \(error.localizedDescription)"
        }
    }

    func resetPersonColorPaletteToDefaults() async {
        await savePersonColorPalette(.default)
        if personColorPaletteError == nil {
            personColorPaletteStatusMessage = "Reset audience colors to the default palette."
            statusMessage = "Reset audience colors to defaults."
        }
    }

    func saveSenderSettings(
        johnRecipientsText: String,
        amyRecipientsText: String,
        preferredTransport: SenderTransport,
        allowAppleMailFallback: Bool,
        scheduledSendHour: Int,
        scheduledSendMinute: Int,
        catchUpDeadlineHour: Int,
        smtpIsEnabled: Bool,
        smtpHost: String,
        smtpPort: Int,
        smtpSecurity: SMTPSecurity,
        smtpUsername: String,
        smtpFromAddress: String,
        smtpFromDisplayName: String,
        smtpAuthentication: SMTPAuthenticationMethod,
        smtpConnectionTimeoutSeconds: Int,
        smtpPassword: String
    ) async {
        var settings = senderSettings
        settings.primary.scheduledSendHour = scheduledSendHour
        settings.primary.scheduledSendMinute = scheduledSendMinute
        settings.primary.catchUpDeadlineHour = catchUpDeadlineHour
        settings.johnRecipients = parseRecipients(from: johnRecipientsText)
        settings.amyRecipients = parseRecipients(from: amyRecipientsText)
        settings.preferredTransport = preferredTransport
        settings.allowAppleMailFallback = allowAppleMailFallback
        settings.smtp = SMTPSenderConfiguration(
            isEnabled: smtpIsEnabled,
            host: smtpHost.trimmingCharacters(in: .whitespacesAndNewlines),
            port: smtpPort,
            security: smtpSecurity,
            username: smtpUsername.trimmingCharacters(in: .whitespacesAndNewlines),
            fromAddress: smtpFromAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            fromDisplayName: smtpFromDisplayName.trimmingCharacters(in: .whitespacesAndNewlines),
            authentication: smtpAuthentication,
            connectionTimeoutSeconds: smtpConnectionTimeoutSeconds
        )

        do {
            let trimmedPassword = smtpPassword.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedPassword.isEmpty == false {
                try await keychainSecretStore.save(secret: trimmedPassword, account: settings.smtp.passwordAccountKey)
            }
            await persistSenderSettings(settings, status: "Saved sender settings.")
        } catch {
            statusMessage = "Could not save SMTP credentials: \(error.localizedDescription)"
        }
    }

    func clearStoredSMTPPassword() async {
        do {
            try await keychainSecretStore.delete(account: senderSettings.smtp.passwordAccountKey)
            await refreshSMTPPasswordStored(for: senderSettings.smtp)
            statusMessage = "Cleared the stored SMTP password for this Mac."
        } catch {
            statusMessage = "Could not clear the stored SMTP password: \(error.localizedDescription)"
        }
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

    private func syncWeatherSettingsFromStore() async {
        do {
            let latestSettings = try await weatherSettingsStore.load()
            if latestSettings != weatherSettings {
                weatherSettings = latestSettings
            }
            await ensureWeatherSettingsResolvedIfNeeded()
        } catch {
            weatherSettingsError = "Could not load weather settings: \(error.localizedDescription)"
            weatherSettingsStatusMessage = "Weather settings need attention."
        }
    }

    private func syncNewsSettingsFromStore() async {
        do {
            let latestSettings = try await newsSettingsStore.load()
            if latestSettings != newsSettings {
                newsSettings = latestSettings
            }
            newsSettingsError = nil
            newsSettingsStatusMessage = "Ready Room uses official RSS and Atom feeds for live news."
        } catch {
            newsSettingsError = error.localizedDescription
            newsSettingsStatusMessage = "News settings need attention."
        }
    }

    private func syncPersonColorPaletteFromStore() async {
        do {
            let latestSettings = try await personColorPaletteStore.load()
            if latestSettings != personColorPaletteSettings {
                personColorPaletteSettings = latestSettings
            }
            personColorPaletteError = nil
            personColorPaletteStatusMessage = "Audience colors are shared across Macs and used in the dashboard and briefings."
        } catch {
            personColorPaletteError = error.localizedDescription
            personColorPaletteStatusMessage = "Audience colors need attention."
        }
    }

    private func ensureWeatherSettingsResolvedIfNeeded() async {
        let trimmedQuery = weatherSettings.trimmedLocationQuery
        guard trimmedQuery.isEmpty == false else {
            weatherSettingsError = "Weather location is empty."
            weatherSettingsStatusMessage = "Enter a ZIP code or city/state to enable live weather."
            return
        }

        guard weatherSettings.hasResolvedCoordinates == false else {
            weatherSettingsError = nil
            weatherSettingsStatusMessage = "Using \(weatherSettings.resolvedDisplayName ?? trimmedQuery) for weather."
            return
        }

        do {
            let resolved = try await weatherLocationResolver.resolve(trimmedQuery)
            let updatedSettings = WeatherSettings(
                locationQuery: trimmedQuery,
                resolvedDisplayName: resolved.displayName,
                latitude: resolved.latitude,
                longitude: resolved.longitude,
                lastResolvedAt: .now
            )
            try await weatherSettingsStore.save(updatedSettings)
            weatherSettings = updatedSettings
            weatherSettingsError = nil
            weatherSettingsStatusMessage = "Resolved weather location to \(updatedSettings.resolvedDisplayName ?? trimmedQuery)."
        } catch {
            weatherSettingsError = error.localizedDescription
            weatherSettingsStatusMessage = "Weather location could not be resolved."
        }
    }

    private func weatherSnapshot() async -> SourceSnapshot {
        let trimmedQuery = weatherSettings.trimmedLocationQuery
        guard trimmedQuery.isEmpty == false else {
            return WeatherSourceSnapshotFactory.unconfigured(
                message: "Set a ZIP code or city/state in Settings to enable live weather.",
                fetchedAt: now
            )
        }

        guard let latitude = weatherSettings.latitude, let longitude = weatherSettings.longitude else {
            return WeatherSourceSnapshotFactory.unconfigured(
                message: "Weather location \"\(trimmedQuery)\" is saved but not resolved yet.",
                fetchedAt: now
            )
        }

        let connector = OpenMeteoWeatherConnector(
            configuration: OpenMeteoConfiguration(latitude: latitude, longitude: longitude)
        )

        do {
            return try await connector.refresh()
        } catch {
            return WeatherSourceSnapshotFactory.unavailable(
                message: "Weather refresh failed for \(weatherSettings.resolvedDisplayName ?? trimmedQuery): \(error.localizedDescription)",
                fetchedAt: now
            )
        }
    }

    private func newsSnapshot() async -> SourceSnapshot {
        let normalizedSettings = newsSettings.normalized()
        guard normalizedSettings.hasAnyEnabledFeed else {
            return NewsSourceSnapshotFactory.unconfigured(
                message: "Enable at least one RSS or Atom feed in Settings to show live news.",
                fetchedAt: now
            )
        }

        let connector = RSSNewsConnector(feeds: normalizedSettings.feeds)
        do {
            let snapshot = try await connector.refresh()
            let lastGood = LastGoodNewsSnapshot(headlines: snapshot.headlines, fetchedAt: snapshot.fetchedAt)
            lastGoodNewsSnapshot = lastGood
            try? await lastGoodNewsSnapshotStore.save(lastGood)
            return snapshot
        } catch {
            if let lastGoodNewsSnapshot, lastGoodNewsSnapshot.headlines.isEmpty == false {
                return NewsSourceSnapshotFactory.stale(
                    headlines: lastGoodNewsSnapshot.headlines,
                    message: "News refresh failed: \(error.localizedDescription) Showing cached headlines from \(lastGoodNewsSnapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened)).",
                    fetchedAt: now,
                    lastGoodFetchAt: lastGoodNewsSnapshot.fetchedAt
                )
            }

            return NewsSourceSnapshotFactory.unavailable(
                message: "News refresh failed: \(error.localizedDescription)",
                fetchedAt: now
            )
        }
    }

    private func validateNewsFeeds(_ feeds: [ConfiguredNewsFeed]) -> [String] {
        var problems: [String] = []

        for feed in feeds {
            if feed.trimmedLabel.isEmpty {
                problems.append("Every news feed needs a label.")
                break
            }
            if feed.resolvedURL == nil {
                problems.append("Every news feed needs a valid http or https URL.")
                break
            }
        }

        return problems
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
                let result = try await performSend(artifact: artifact, mode: .manualTest)
                try await recordSendResult(result)
                statusMessage = successStatusMessage(for: result, audience: artifact.audience, action: "Sent")
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
                await enqueueRefresh(.timelineRelated)
                continue
            }
            let dueComponents = periodicRefreshPlanner.dueComponents(
                now: now,
                lastCalendarAndObligationsRefreshAt: lastCalendarAndObligationsRefreshAt,
                lastNewsAndWeatherRefreshAt: lastNewsAndWeatherRefreshAt
            )
            if dueComponents.isEmpty == false {
                await enqueueRefresh(dueComponents)
            }
            await evaluateScheduledSendsIfNeeded()
        }
    }

    private func enqueueRefresh(_ components: RefreshComponents) async {
        refreshRequestQueue.enqueue(components)

        guard refreshInFlight == false else {
            return
        }

        while let nextComponents = refreshRequestQueue.drain() {
            refreshInFlight = true
            await performRefresh(components: nextComponents)
            refreshInFlight = false
        }
    }

    private func performRefresh(components: RefreshComponents) async {
        statusMessage = statusMessage(for: components)
        await syncWeatherSettingsFromStore()
        await syncNewsSettingsFromStore()
        await syncPersonColorPaletteFromStore()
        _ = await syncSharedObligations(force: components.contains(.obligations))
        let snapshots = await collectSnapshots(refreshing: components)
        sourceSnapshots = snapshots
        await applySnapshots(snapshots)
        await generateNarrativesAndPreviews()
        updateDebugJSON()

        if components.contains(.calendar) || components.contains(.obligations) {
            lastCalendarAndObligationsRefreshAt = now
        }
        if components.contains(.news) || components.contains(.weather) {
            lastNewsAndWeatherRefreshAt = now
        }

        statusMessage = refreshWarning ?? "Ready"
    }

    private func collectSnapshots(refreshing components: RefreshComponents) async -> [SourceSnapshot] {
        var snapshots = sourceSnapshots
        if snapshots.isEmpty {
            snapshots = DevelopmentData.sampleSnapshots(referenceDate: now)
        }

        if components.contains(.weather) || snapshot(for: .weather) == nil {
            replaceSnapshot(await weatherSnapshot(), in: &snapshots, type: .weather)
        }

        if components.contains(.news) || snapshot(for: .news) == nil {
            replaceSnapshot(await newsSnapshot(), in: &snapshots, type: .news)
        }

        if components.contains(.calendar) || snapshot(for: .calendar) == nil {
            let calendarConnector = EventKitCalendarConnector()
            if let liveCalendar = try? await calendarConnector.refresh(),
               liveCalendar.health.status != .unauthorized,
               liveCalendar.calendarEvents.isEmpty == false {
                replaceSnapshot(liveCalendar, in: &snapshots, type: .calendar)
            } else if snapshots.contains(where: { $0.source.type == .calendar }) == false,
                      let sampleCalendar = DevelopmentData.sampleSnapshots(referenceDate: now).first(where: { $0.source.type == .calendar }) {
                snapshots.append(sampleCalendar)
            }
        }

        if components.contains(.media), snapshots.contains(where: { $0.source.type == .media }) == false,
           let sampleMedia = DevelopmentData.sampleSnapshots(referenceDate: now).first(where: { $0.source.type == .media }) {
            snapshots.append(sampleMedia)
        }

        return snapshots
    }

    private func applySnapshots(_ snapshots: [SourceSnapshot]) async {
        refreshWarning = nil
        let calendarSnapshot = snapshots.first(where: { $0.source.type == .calendar })
        let weatherSnapshot = snapshots.first(where: { $0.source.type == .weather })
        let newsSnapshot = snapshots.first(where: { $0.source.type == .news })
        let mediaSnapshot = snapshots.first(where: { $0.source.type == .media })

        weather = weatherSnapshot?.weather
        let rawNewsHeadlines = newsSnapshot?.headlines ?? []
        headlines = newsRanker.rank(
            headlines: rawNewsHeadlines,
            settings: newsSettings,
            surface: .dashboard
        )
        rankedHeadlinesByAudience = [
            .john: newsRanker.rank(headlines: rawNewsHeadlines, settings: newsSettings, surface: .john),
            .amy: newsRanker.rank(headlines: rawNewsHeadlines, settings: newsSettings, surface: .amy)
        ]
        dashboardNewsSummaryText = dashboardNewsSummary(from: headlines)
        mediaItems = mediaSnapshot?.mediaItems ?? []

        let configurations = (try? await calendarStore.load()) ?? []
        let configMap = ReadyRoomCollections.dictionaryLastValueWins(
            from: configurations.map { ($0.calendarIdentifier, $0) }
        )
        let calendarItems = rulesEngine.normalizeCalendarEvents(
            calendarSnapshot?.calendarEvents ?? [],
            source: calendarSnapshot?.source ?? SourceDescriptor(id: "sample-calendar", displayName: "Sample Calendar", type: .calendar),
            configurations: configMap,
            health: calendarSnapshot?.health.resolvedStatus(at: now) ?? .healthy,
            previousItems: lastSeenCalendarItems
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
        lastSeenCalendarItems = ReadyRoomCollections.dictionaryLastValueWins(
            from: calendarItems.map { ($0.id, $0) }
        )
        do {
            try await calendarBaselineStore.save(calendarItems)
        } catch {
            refreshWarning = "Could not save calendar baseline: \(error.localizedDescription)"
        }
    }

    private func generateNarrativesAndPreviews() async {
        dashboardSummaryByMode = [:]
        previewArtifacts = [:]

        let sourceStatuses = sourceSnapshots.map { $0.health.resolvedStatus(at: now) }
        let rankedNewsByAudience = rankedHeadlinesByAudience
        let dueSoonByAudience: [BriefingAudience: [NormalizedItem]] = [
            .john: dueSoon.filter(\.inclusion.johnBriefing),
            .amy: dueSoon.filter(\.inclusion.amyBriefing)
        ]
        let recipientsByAudience: [BriefingAudience: [String]] = [
            .john: defaultRecipients(for: .john),
            .amy: defaultRecipients(for: .amy)
        ]
        let calendarPlaceholderLabel = placeholderLabel(for: .calendar)
        let weatherPlaceholderLabel = placeholderLabel(for: .weather)
        let newsPlaceholderLabel = placeholderLabel(for: .news)
        let mediaPlaceholderLabel = placeholderLabel(for: .media)

        for mode in NarrativeGenerationMode.allCases {
            guard let pipeline = narrativePipelines[mode] else {
                continue
            }
            let context = DashboardSummaryContext(
                normalizedItems: normalizedItems,
                weather: weather,
                dueSoon: dueSoon,
                sourceStatuses: sourceStatuses
            )
            let summary = await pipeline.dashboardSummary(for: context, preferredMode: mode)
            dashboardSummaryByMode[mode] = summary

            for audience in BriefingAudience.allCases {
                let request = BriefingRequest(
                    audience: audience,
                    date: now,
                    normalizedItems: normalizedItems,
                    weather: weather,
                    headlines: rankedNewsByAudience[audience] ?? [],
                    mediaItems: mediaItems,
                    dueSoon: dueSoonByAudience[audience] ?? [],
                    preferredMode: mode,
                    personColorPalette: personColorPaletteSettings,
                    calendarPlaceholderLabel: calendarPlaceholderLabel,
                    weatherPlaceholderLabel: weatherPlaceholderLabel,
                    newsPlaceholderLabel: newsPlaceholderLabel,
                    mediaPlaceholderLabel: mediaPlaceholderLabel
                )
                let artifact = BriefingComposer().compose(
                    request: request,
                    recipients: recipientsByAudience[audience] ?? [],
                    openingLine: await pipeline.openingLine(for: request),
                    newsSummary: await pipeline.newsSummary(for: request)
                )
                var byMode = previewArtifacts[audience] ?? [:]
                byMode[mode] = artifact
                previewArtifacts[audience] = byMode
            }
        }
    }

    private func weightedHeadlines(for audience: BriefingAudience) -> [NewsHeadline] {
        rankedHeadlinesByAudience[audience] ?? []
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
            conflicts: conflicts,
            newsSettings: newsSettings,
            dashboardHeadlines: headlines,
            rankedHeadlinesByAudience: rankedHeadlinesByAudience,
            personColorPalette: personColorPaletteSettings,
            senderSettings: senderSettings,
            sendRecords: sendRecords
        )
        if let data = try? encoder.encode(payload), let json = String(data: data, encoding: .utf8) {
            debugJSON = json
        }
    }

    private func replaceSnapshot(_ snapshot: SourceSnapshot, in snapshots: inout [SourceSnapshot], type: SourceType) {
        snapshots.removeAll(where: { $0.source.type == type })
        snapshots.append(snapshot)
    }

    private func dashboardNewsSummary(from headlines: [NewsHeadline]) -> String {
        let selected = headlines.prefix(2).map(\.title)
        if selected.isEmpty {
            return "No news items made the cut this morning."
        }
        return selected.joined(separator: " Also worth noting: ")
    }

    private func statusMessage(for components: RefreshComponents) -> String {
        if quietHours.isActive(at: now) {
            return "Quiet hours active."
        }
        if components == .allSources {
            return "Refreshing sources..."
        }
        if components == .timelineRelated {
            return "Refreshing calendars and obligations..."
        }
        if components == .newsAndWeather {
            return "Refreshing news and weather..."
        }
        return "Refreshing selected sources..."
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
                let result = try await performSend(artifact: artifact, mode: .scheduled)
                try await recordSendResult(result)
                statusMessage = successStatusMessage(for: result, audience: audience, action: "Scheduled send completed")
            } catch {
                statusMessage = "Scheduled send failed for \(audience.displayName): \(error.localizedDescription)"
            }
        }
    }

    private func performSend(artifact: BriefingArtifact, mode: SendMode) async throws -> SendExecutionResult {
        guard artifact.recipients.isEmpty == false else {
            throw NSError(domain: "ReadyRoomSend", code: 1, userInfo: [NSLocalizedDescriptionKey: "No recipients are configured for \(artifact.audience.displayName)."])
        }
        let plan = try await sendPlan()
        return try await senderDispatchCoordinator.deliver(
            artifact: artifact,
            mode: mode,
            machineIdentifier: machineIdentifier,
            requestedSenderID: plan.requestedSenderID,
            requestedSenderDisplayName: plan.requestedSenderDisplayName,
            adapters: plan.adapters,
            initialFallbackDescription: plan.initialFallbackDescription
        )
    }

    private func refreshBriefingsForScheduledSend() async {
        now = Date()
        await enqueueRefresh(.allSources)
    }

    private func persistSenderSettings(_ settings: SenderSettings, status: String) async {
        do {
            try await senderSettingsStore.save(settings)
            senderSettings = settings
            primarySenderConfiguration = settings.primary
            attemptedScheduledSendKeys.removeAll()
            await refreshSMTPPasswordStored(for: settings.smtp)
            await generateNarrativesAndPreviews()
            updateDebugJSON()
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

    private func sendPlan() async throws -> SendPlan {
        switch senderSettings.preferredTransport {
        case .appleMail:
            return SendPlan(
                requestedSenderID: SenderTransport.appleMail.rawValue,
                requestedSenderDisplayName: SenderTransport.appleMail.displayName,
                adapters: [mailSender],
                initialFallbackDescription: nil
            )
        case .smtp:
            let config = senderSettings.smtp
            let password = try await keychainSecretStore.load(account: config.passwordAccountKey)
            if config.isConfigured, let password, password.isEmpty == false {
                var adapters: [SenderAdapter] = [SMTPSenderAdapter(configuration: config, password: password)]
                if senderSettings.allowAppleMailFallback {
                    adapters.append(mailSender)
                }
                return SendPlan(
                    requestedSenderID: SenderTransport.smtp.rawValue,
                    requestedSenderDisplayName: SenderTransport.smtp.displayName,
                    adapters: adapters,
                    initialFallbackDescription: nil
                )
            }

            let reason = unavailableSMTPReason(configuration: config, password: password)
            guard senderSettings.allowAppleMailFallback else {
                throw NSError(domain: "ReadyRoomSend", code: 4, userInfo: [NSLocalizedDescriptionKey: reason])
            }

            return SendPlan(
                requestedSenderID: SenderTransport.smtp.rawValue,
                requestedSenderDisplayName: SenderTransport.smtp.displayName,
                adapters: [mailSender],
                initialFallbackDescription: reason
            )
        }
    }

    private func unavailableSMTPReason(configuration: SMTPSenderConfiguration, password: String?) -> String {
        var problems: [String] = []
        if configuration.isEnabled == false {
            problems.append("SMTP is turned off in Sender settings.")
        }
        if configuration.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            problems.append("SMTP host is missing.")
        }
        if configuration.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            problems.append("SMTP username is missing.")
        }
        if configuration.fromAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            problems.append("SMTP from address is missing.")
        }
        if password?.isEmpty != false {
            problems.append("No SMTP password is stored on this Mac.")
        }

        let joined = problems.isEmpty ? "SMTP is not ready on this Mac." : problems.joined(separator: " ")
        return "\(joined) Ready Room used Apple Mail compatibility mode instead."
    }

    private func refreshSMTPPasswordStored(for configuration: SMTPSenderConfiguration) async {
        let hasKeyMaterial = configuration.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        configuration.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        configuration.fromAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        guard hasKeyMaterial else {
            smtpPasswordStored = false
            return
        }

        do {
            let secret = try await keychainSecretStore.load(account: configuration.passwordAccountKey)
            smtpPasswordStored = secret?.isEmpty == false
        } catch {
            smtpPasswordStored = false
        }
    }

    private func recordSendResult(_ result: SendExecutionResult) async throws {
        try await sendRegistryStore.append(result.record)
        sendRecords = try await sendRegistryStore.load()
        updateDebugJSON()
    }

    private func successStatusMessage(for result: SendExecutionResult, audience: BriefingAudience, action: String) -> String {
        let actualSender = result.record.actualSenderDisplayName ?? result.record.senderID
        if let fallbackDescription = result.record.fallbackDescription, fallbackDescription.isEmpty == false {
            return "\(action) for \(audience.displayName) via \(actualSender). \(fallbackDescription)"
        }
        return "\(action) for \(audience.displayName) via \(actualSender)."
    }
}

private struct DebugPayload: Encodable {
    let now: Date
    let snapshots: [SourceSnapshot]
    let normalizedItems: [NormalizedItem]
    let dueSoon: [NormalizedItem]
    let conflicts: [ConflictMarker]
    let newsSettings: NewsSettings
    let dashboardHeadlines: [NewsHeadline]
    let rankedHeadlinesByAudience: [BriefingAudience: [NewsHeadline]]
    let personColorPalette: PersonColorPaletteSettings
    let senderSettings: SenderSettings
    let sendRecords: [SendExecutionRecord]
}

private struct SendPlan {
    let requestedSenderID: String
    let requestedSenderDisplayName: String
    let adapters: [SenderAdapter]
    let initialFallbackDescription: String?
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

        return [calendarSnapshot, mediaSnapshot]
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
