import AppKit
import SwiftUI
import WebKit
import ReadyRoomCore
import ReadyRoomPersistence

struct PreviewView: View {
    @ObservedObject var model: ReadyRoomAppModel
    @State private var selectedAudience: BriefingAudience = .john

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Picker("Audience", selection: $selectedAudience) {
                    ForEach(BriefingAudience.allCases, id: \.self) { audience in
                        Text(audience.displayName).tag(audience)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Compare Modes", isOn: $model.compareBriefingModes)
                    .toggleStyle(.switch)
            }

            if model.compareBriefingModes {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(NarrativeGenerationMode.allCases, id: \.self) { mode in
                            if let artifact = model.artifact(for: selectedAudience, mode: mode) {
                                ArtifactCard(title: mode.rawValue, artifact: artifact)
                            }
                        }
                    }
                }
            } else if let artifact = model.artifact(for: selectedAudience, mode: model.preferredMode) ?? model.artifact(for: selectedAudience, mode: .templated) {
                ArtifactCard(title: "Briefing", artifact: artifact)
            } else {
                ContentUnavailableView("No Briefing Yet", systemImage: "envelope.badge")
            }
        }
        .padding(24)
    }
}

private struct ArtifactCard: View {
    let title: String
    let artifact: BriefingArtifact

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(artifact.subject)
                .font(.title3.weight(.semibold))
            Text(artifact.recipients.joined(separator: ", "))
                .foregroundStyle(.secondary)
            HTMLPreview(html: artifact.bodyHTML)
                .frame(minHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text("Preferred mode: \(artifact.preferredMode.rawValue) • Actual mode: \(artifact.actualMode.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ObligationsView: View {
    @ObservedObject var model: ReadyRoomAppModel

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Obligations")
                    .font(.largeTitle.weight(.bold))
                TextField("Mortgage due every month on the 15th, remind me 7 and 3 days before", text: $model.obligationDraft)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Parse") { model.parseObligationDraft() }
                    if model.obligationEditor != nil {
                        Button(model.isEditingSavedObligation ? "Save Changes" : "Save Obligation") {
                            Task { await model.saveObligationEditor() }
                        }
                    }
                    if model.obligationEditor != nil {
                        Button("Cancel") { model.cancelObligationEditing() }
                    }
                }

                if let parsed = model.parsedObligationCandidate, let editor = model.obligationEditor {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.isEditingSavedObligation ? "Editing saved obligation" : "I understood this as...")
                            .font(.headline)
                        Text("You can edit this explanation and any of the structured fields before saving.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextEditor(text: binding(\.explanation))
                            .font(.body)
                            .frame(minHeight: 72)
                            .padding(10)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                        if !parsed.missingFields.isEmpty {
                            Text("Missing: \(parsed.missingFields.joined(separator: ", "))")
                                .foregroundStyle(.orange)
                        }

                        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
                            GridRow {
                                Text("Title")
                                TextField("Title", text: binding(\.title))
                            }
                            GridRow {
                                Text("Owner")
                                Picker("Owner", selection: binding(\.owner)) {
                                    Text("Family / Unspecified").tag(PersonID?.none)
                                    Text("John").tag(PersonID?.some(.john))
                                    Text("Amy").tag(PersonID?.some(.amy))
                                    Text("Ellie").tag(PersonID?.some(.ellie))
                                    Text("Mia").tag(PersonID?.some(.mia))
                                }
                                .pickerStyle(.menu)
                            }
                            GridRow {
                                Text("Schedule")
                                Picker("Schedule", selection: binding(\.scheduleKind)) {
                                    ForEach(ObligationScheduleKind.allCases, id: \.self) { kind in
                                        Text(kind.rawValue.capitalized).tag(kind)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            GridRow {
                                Text("Lead Days")
                                TextField("7, 3", text: binding(\.reminderLeadDaysText))
                            }
                            GridRow {
                                Text("Notes")
                                TextField("Optional notes", text: binding(\.notes))
                            }
                            GridRow {
                                Text("Source Text")
                                TextField("Original sentence", text: binding(\.originalEntry))
                            }
                        }

                        scheduleEditor(for: editor)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved Obligations")
                        .font(.headline)
                    Text("Click any saved item to edit it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if model.obligations.isEmpty {
                    ContentUnavailableView("No Saved Obligations", systemImage: "checklist", description: Text("Parse and save an obligation to start building your list."))
                        .frame(minWidth: 320, minHeight: 220)
                } else {
                    List(model.obligations) { obligation in
                        Button {
                            model.beginEditingObligation(obligation)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(obligation.title)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(obligation.explanation ?? obligation.schedule.kind.rawValue.capitalized)
                                    .foregroundStyle(.secondary)
                                if let originalEntry = obligation.originalEntry, !originalEntry.isEmpty {
                                    Text(originalEntry)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(model.selectedObligationID == obligation.id ? Color.accentColor.opacity(0.12) : Color.clear)
                    }
                    .frame(minWidth: 320)
                }
            }
            .frame(width: 360, alignment: .topLeading)
        }
        .padding(24)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<ObligationEditorDraft, Value>) -> Binding<Value> {
        Binding {
            model.obligationEditor?[keyPath: keyPath] ?? fallbackValue(for: keyPath)
        } set: { newValue in
            model.updateObligationEditor { $0[keyPath: keyPath] = newValue }
        }
    }

    private func fallbackValue<Value>(for keyPath: WritableKeyPath<ObligationEditorDraft, Value>) -> Value {
        ObligationEditorDraft(
            record: ObligationRecord(
                title: "",
                schedule: ObligationSchedule(kind: .oneTime)
            )
        )[keyPath: keyPath]
    }

    @ViewBuilder
    private func scheduleEditor(for editor: ObligationEditorDraft) -> some View {
        switch editor.scheduleKind {
        case .oneTime, .custom:
            DatePicker("Due Date", selection: binding(\.dueDate), displayedComponents: .date)
            if editor.scheduleKind == .custom {
                TextField("Custom rule", text: binding(\.customRule))
                    .textFieldStyle(.roundedBorder)
            }
        case .weekly:
            TextField("Weekdays (1=Sun ... 7=Sat)", text: binding(\.weekdaysText))
                .textFieldStyle(.roundedBorder)
        case .monthly:
            Stepper("Day of month: \(editor.dayOfMonth)", value: binding(\.dayOfMonth), in: 1...31)
        case .yearly:
            Stepper("Month: \(editor.monthOfYear)", value: binding(\.monthOfYear), in: 1...12)
            Stepper("Day: \(editor.dayOfMonth)", value: binding(\.dayOfMonth), in: 1...31)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: ReadyRoomAppModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedPreferencesSection) {
                ForEach(ReadyRoomAppModel.PreferencesSection.allCases) { section in
                    Label(section.rawValue, systemImage: icon(for: section))
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(model.selectedPreferencesSection.rawValue)
                        .font(.largeTitle.weight(.bold))
                    switch model.selectedPreferencesSection {
                    case .general:
                        settingsCard("General", body: "Personal-app-first defaults, setup rerun support, and local-first behavior live here.")
                    case .calendars:
                        CalendarsSettingsView(model: model)
                    case .briefings:
                        settingsCard("Briefings", body: "Recipient lists, briefing-only mode, and section behavior will be configured here.")
                    case .dashboard:
                        DashboardSettingsView(model: model)
                    case .obligations:
                        settingsCard("Obligations", body: "YAML-backed obligations and the parse/approve workflow are available from the Obligations screen.")
                    case .ai:
                        settingsCard("AI", body: "Preferred order is Foundation Models, Ollama, then deterministic templates.")
                    case .weather:
                        WeatherSettingsView(model: model)
                    case .news:
                        NewsSettingsView(model: model)
                    case .media:
                        settingsCard("Media", body: "Plex, Tautulli, Sonarr, and Radarr configuration belongs here.")
                    case .storageSync:
                        StorageSyncSettingsView(model: model)
                    case .sender:
                        SenderSettingsView(model: model)
                    case .advancedDebug:
                        settingsCard("Advanced/Debug", body: "Use the Debug screen for raw data inspection, source health, and briefing traces.")
                    }
                }
                .padding(24)
            }
        }
    }

    private func settingsCard(_ title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func icon(for section: ReadyRoomAppModel.PreferencesSection) -> String {
        switch section {
        case .general:
            "gear"
        case .calendars:
            "calendar"
        case .briefings:
            "envelope.open"
        case .dashboard:
            "rectangle.grid.2x2"
        case .obligations:
            "checklist"
        case .ai:
            "sparkles"
        case .weather:
            "cloud.sun"
        case .news:
            "newspaper"
        case .media:
            "play.rectangle"
        case .storageSync:
            "externaldrive"
        case .sender:
            "paperplane"
        case .advancedDebug:
            "ladybug"
        }
    }
}

private struct CalendarsSettingsView: View {
    @ObservedObject var model: ReadyRoomAppModel
    @State private var draftConfigurations: [CalendarConfiguration] = []

    private struct CalendarDiscovery: Identifiable, Hashable {
        let calendarIdentifier: String
        let displayName: String
        let eventCount: Int

        var id: String { calendarIdentifier }
    }

    private var discoveredCalendars: [CalendarDiscovery] {
        let snapshotEvents = model.snapshot(for: .calendar)?.calendarEvents ?? []
        let configurationMap = ReadyRoomCollections.dictionaryLastValueWins(
            from: model.calendarConfigurations.map { ($0.calendarIdentifier, $0) }
        )
        var titles: [String: String] = [:]
        var counts: [String: Int] = [:]

        for event in snapshotEvents {
            titles[event.calendarIdentifier] = event.calendarTitle
            counts[event.calendarIdentifier, default: 0] += 1
        }

        return Set(counts.keys).union(configurationMap.keys)
            .map { identifier in
                CalendarDiscovery(
                    calendarIdentifier: identifier,
                    displayName: titles[identifier] ?? configurationMap[identifier]?.displayName ?? identifier,
                    eventCount: counts[identifier] ?? 0
                )
            }
            .sorted {
                if $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedSame {
                    return $0.calendarIdentifier.localizedCaseInsensitiveCompare($1.calendarIdentifier) == .orderedAscending
                }
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    private var hasUnsavedChanges: Bool {
        normalizedDraftConfigurations != model.calendarConfigurations
    }

    private var normalizedDraftConfigurations: [CalendarConfiguration] {
        draftConfigurations.sorted {
            if $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedSame {
                return $0.calendarIdentifier.localizedCaseInsensitiveCompare($1.calendarIdentifier) == .orderedAscending
            }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Calendars")
                    .font(.headline)
                Text("Set per-calendar role, default owner, dashboard inclusion, and default briefing relevance. These defaults sync across Macs, but strong event clues can still override them on specific items.")
                    .foregroundStyle(.secondary)
                if let placeholder = model.placeholderLabel(for: .calendar) {
                    Text(placeholder)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Save Calendar Settings") {
                        Task { await model.saveCalendarConfigurations(normalizedDraftConfigurations) }
                    }
                    .disabled(hasUnsavedChanges == false)
                    Button("Refresh Calendars") {
                        Task { await model.refresh() }
                    }
                    Spacer()
                    if discoveredCalendars.isEmpty == false {
                        Text("\(discoveredCalendars.count) calendar(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(model.calendarSettingsStatusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let error = model.calendarSettingsError {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            if discoveredCalendars.isEmpty {
                ContentUnavailableView(
                    "No Calendars Yet",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Grant Calendar access or refresh while sample calendar data is active to configure defaults.")
                )
                .frame(maxWidth: .infinity, minHeight: 260)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(discoveredCalendars) { calendar in
                    calendarCard(for: calendar)
                }
            }
        }
        .onAppear {
            syncDraftFromModel()
        }
        .onChange(of: model.calendarConfigurations) { _, _ in
            syncDraftFromModel()
        }
    }

    private func calendarCard(for calendar: CalendarDiscovery) -> some View {
        let previewItems = previewItems(for: calendar)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(calendar.displayName)
                        .font(.headline)
                    Text(calendar.calendarIdentifier)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(calendar.eventCount) visible event(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("Role")
                    Picker("Role", selection: binding(for: calendar, keyPath: \.role)) {
                        Text("Automatic").tag(CalendarRole?.none)
                        ForEach(CalendarRole.allCases, id: \.self) { role in
                            Text(roleLabel(role)).tag(CalendarRole?.some(role))
                        }
                    }
                    .pickerStyle(.menu)
                }
                GridRow {
                    Text("Default Owner")
                    Picker("Default Owner", selection: binding(for: calendar, keyPath: \.owner)) {
                        Text("Automatic").tag(PersonID?.none)
                        Text("Family").tag(PersonID?.some(.family))
                        Text("John").tag(PersonID?.some(.john))
                        Text("Amy").tag(PersonID?.some(.amy))
                        Text("Ellie").tag(PersonID?.some(.ellie))
                        Text("Mia").tag(PersonID?.some(.mia))
                    }
                    .pickerStyle(.menu)
                }
                GridRow {
                    Text("Dashboard")
                    Toggle("Include on Dashboard", isOn: binding(for: calendar, keyPath: \.includeOnDashboard))
                        .toggleStyle(.switch)
                }
                GridRow {
                    Text("Default Relevance")
                    HStack(spacing: 14) {
                        Toggle("John", isOn: binding(for: calendar, keyPath: \.includeInJohnBriefing))
                            .toggleStyle(.switch)
                        Toggle("Amy", isOn: binding(for: calendar, keyPath: \.includeInAmyBriefing))
                            .toggleStyle(.switch)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Preview")
                    .font(.subheadline.weight(.semibold))
                if previewItems.isEmpty {
                    Text("No currently visible events from this calendar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(previewItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(previewTime(for: item))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Text("Owner: \(item.owner.displayName) • Relevant to: \(relevanceSummary(for: item))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(traceSummary(for: item))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func configuration(for calendar: CalendarDiscovery) -> CalendarConfiguration {
        normalizedDraftConfigurations.first(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) ??
        CalendarConfiguration(
            calendarIdentifier: calendar.calendarIdentifier,
            displayName: calendar.displayName
        )
    }

    private func binding<Value>(
        for calendar: CalendarDiscovery,
        keyPath: WritableKeyPath<CalendarConfiguration, Value>
    ) -> Binding<Value> {
        Binding {
            configuration(for: calendar)[keyPath: keyPath]
        } set: { newValue in
            updateConfiguration(for: calendar) { configuration in
                configuration[keyPath: keyPath] = newValue
            }
        }
    }

    private func updateConfiguration(
        for calendar: CalendarDiscovery,
        mutate: (inout CalendarConfiguration) -> Void
    ) {
        var configurations = ReadyRoomCollections.dictionaryLastValueWins(
            from: draftConfigurations.map { ($0.calendarIdentifier, $0) }
        )
        var configuration = configurations[calendar.calendarIdentifier] ??
        CalendarConfiguration(
            calendarIdentifier: calendar.calendarIdentifier,
            displayName: calendar.displayName
        )
        configuration.displayName = calendar.displayName
        mutate(&configuration)
        configurations[calendar.calendarIdentifier] = configuration
        draftConfigurations = configurations.values.sorted {
            if $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedSame {
                return $0.calendarIdentifier.localizedCaseInsensitiveCompare($1.calendarIdentifier) == .orderedAscending
            }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func previewItems(for calendar: CalendarDiscovery) -> [NormalizedItem] {
        model.normalizedItems
            .filter { $0.metadata["calendarIdentifier"] == calendar.calendarIdentifier }
            .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
            .prefix(4)
            .map { $0 }
    }

    private func previewTime(for item: NormalizedItem) -> String {
        guard let start = item.startDate else {
            return item.isAllDay ? "All day" : "TBD"
        }
        if item.isAllDay {
            return start.formattedMonthDayWeekday()
        }
        return start.formattedMonthDayWeekday() + " at " + start.formattedClock()
    }

    private func relevanceSummary(for item: NormalizedItem) -> String {
        let names = item.relevantAudienceDisplayNames
        return names.isEmpty ? "No briefings" : names.joined(separator: ", ")
    }

    private func traceSummary(for item: NormalizedItem) -> String {
        let entries = item.trace.appliedRules.filter {
            $0.ruleID.hasPrefix("calendar.owner") || $0.ruleID.hasPrefix("calendar.relevance")
        }
        let text = entries.map(\.detail).joined(separator: " ")
        return text.isEmpty ? "No owner/relevance trace available." : text
    }

    private func roleLabel(_ role: CalendarRole) -> String {
        switch role {
        case .work:
            "Work"
        case .sharedFamily:
            "Shared Family"
        case .kidRelated:
            "Kid Related"
        case .other:
            "Other"
        case .inactiveUnclassified:
            "Inactive / Unclassified"
        }
    }

    private func syncDraftFromModel() {
        draftConfigurations = model.calendarConfigurations.sorted {
            if $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedSame {
                return $0.calendarIdentifier.localizedCaseInsensitiveCompare($1.calendarIdentifier) == .orderedAscending
            }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
}

private struct DashboardSettingsView: View {
    @ObservedObject var model: ReadyRoomAppModel
    @State private var johnColor = Color(readyRoomHex: PersonColorPaletteSettings.defaultJohnHex, fallback: .systemBlue)
    @State private var amyColor = Color(readyRoomHex: PersonColorPaletteSettings.defaultAmyHex, fallback: .systemGreen)
    @State private var ellieColor = Color(readyRoomHex: PersonColorPaletteSettings.defaultEllieHex, fallback: .systemPurple)
    @State private var miaColor = Color(readyRoomHex: PersonColorPaletteSettings.defaultMiaHex, fallback: .systemTeal)

    private var draftPalette: PersonColorPaletteSettings {
        PersonColorPaletteSettings(
            johnHex: nsColor(from: johnColor)?.readyRoomHexString ?? PersonColorPaletteSettings.defaultJohnHex,
            amyHex: nsColor(from: amyColor)?.readyRoomHexString ?? PersonColorPaletteSettings.defaultAmyHex,
            ellieHex: nsColor(from: ellieColor)?.readyRoomHexString ?? PersonColorPaletteSettings.defaultEllieHex,
            miaHex: nsColor(from: miaColor)?.readyRoomHexString ?? PersonColorPaletteSettings.defaultMiaHex
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dashboard")
                    .font(.headline)
                Text("People colors are shared across Macs and now drive owner-based timeline and briefing accents. Dashboard card order remains local per Mac.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text("People Colors")
                    .font(.headline)

                ColorPicker("John", selection: $johnColor, supportsOpacity: false)
                ColorPicker("Amy", selection: $amyColor, supportsOpacity: false)
                ColorPicker("Ellie", selection: $ellieColor, supportsOpacity: false)
                ColorPicker("Mia", selection: $miaColor, supportsOpacity: false)

                HStack {
                    Button("Save People Colors") {
                        Task { await model.savePersonColorPalette(draftPalette) }
                    }
                    Button("Reset to Defaults") {
                        syncFromPalette(.default)
                        Task { await model.resetPersonColorPaletteToDefaults() }
                    }
                }

                Text(model.personColorPaletteStatusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let paletteError = model.personColorPaletteError {
                    Text(paletteError)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text("Live Preview")
                    .font(.headline)

                AudienceAccentPreviewCard(
                    title: "John work block",
                    subtitle: "Owner: John",
                    accent: ItemAudienceAccentResolver.resolve(owner: .john, palette: draftPalette)
                )
                AudienceAccentPreviewCard(
                    title: "Amy errand",
                    subtitle: "Owner: Amy",
                    accent: ItemAudienceAccentResolver.resolve(owner: .amy, palette: draftPalette)
                )
                AudienceAccentPreviewCard(
                    title: "Ellie recital",
                    subtitle: "Owner: Ellie",
                    accent: ItemAudienceAccentResolver.resolve(owner: .ellie, palette: draftPalette)
                )
                AudienceAccentPreviewCard(
                    title: "Family admin",
                    subtitle: "Owner: Family",
                    accent: ItemAudienceAccentResolver.resolve(owner: .family, palette: draftPalette)
                )
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .onAppear {
            syncFromPalette(model.personColorPaletteSettings)
        }
        .onChange(of: model.personColorPaletteSettings) { _, newValue in
            syncFromPalette(newValue)
        }
    }

    private func syncFromPalette(_ palette: PersonColorPaletteSettings) {
        johnColor = Color(readyRoomHex: palette.johnHex, fallback: .systemBlue)
        amyColor = Color(readyRoomHex: palette.amyHex, fallback: .systemGreen)
        ellieColor = Color(readyRoomHex: palette.ellieHex, fallback: .systemPurple)
        miaColor = Color(readyRoomHex: palette.miaHex, fallback: .systemTeal)
    }

    private func nsColor(from color: Color) -> NSColor? {
        let nsColor = NSColor(color)
        return nsColor.usingColorSpace(.deviceRGB) ?? nsColor
    }
}

private struct WeatherSettingsView: View {
    @ObservedObject var model: ReadyRoomAppModel
    @State private var locationQuery = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Weather")
                    .font(.headline)
                Text("Resolve a ZIP code or city/state with Apple location search, then fetch current conditions from Open-Meteo. The saved location is shared across Macs.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text("Location")
                    .font(.headline)
                TextField("ZIP or city, state", text: $locationQuery)
                    .textFieldStyle(.roundedBorder)
                Text("Default: 08854")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Save Location") {
                        Task { await model.saveWeatherSettings(locationQuery: locationQuery) }
                    }
                    Button("Refresh Weather") {
                        Task { await model.refreshWeatherNow() }
                    }
                }
                if let resolvedDisplayName = model.weatherSettings.resolvedDisplayName {
                    Text("Resolved location: \(resolvedDisplayName)")
                        .foregroundStyle(.secondary)
                }
                if let latitude = model.weatherSettings.latitude, let longitude = model.weatherSettings.longitude {
                    Text(String(format: "Coordinates: %.4f, %.4f", latitude, longitude))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let lastResolvedAt = model.weatherSettings.lastResolvedAt {
                    Text("Last resolved: \(lastResolvedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(model.weatherSettingsStatusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let weatherError = model.weatherSettingsError {
                    Text(weatherError)
                        .foregroundStyle(.red)
                }
                if let sourceMessage = model.sourceMessage(for: .weather), model.placeholderLabel(for: .weather) == nil {
                    Text(sourceMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .onAppear {
            syncFromModel()
        }
        .onChange(of: model.weatherSettings) { _, _ in
            syncFromModel()
        }
    }

    private func syncFromModel() {
        locationQuery = model.weatherSettings.locationQuery
    }
}

private struct NewsSettingsView: View {
    @ObservedObject var model: ReadyRoomAppModel
    @State private var draft = NewsSettings()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("News")
                    .font(.headline)
                Text("Ready Room fetches live headlines from official RSS and Atom feeds. One shared base profile controls the default mix, and Dashboard/John/Amy can optionally override that mix when you need them to diverge.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Feed Library")
                        .font(.headline)
                    Spacer()
                    Button("Add Manual Feed") {
                        draft.feeds.append(
                            ConfiguredNewsFeed(
                                label: "Local feed",
                                feedURLString: "https://",
                                category: .local,
                                sourcePriority: 1.0,
                                isEnabled: true,
                                isUserAdded: true
                            )
                        )
                    }
                }

                Text("Starter feeds seed real news automatically. Manual local feeds are opt-in and stay fully editable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(draft.feeds.indices), id: \.self) { index in
                    NewsFeedEditorRow(
                        feed: bindingForFeed(at: index),
                        remove: {
                            draft.feeds.remove(at: index)
                        }
                    )
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            NewsProfileEditor(
                title: "Shared Base Profile",
                subtitle: "These include/exclude and boost controls apply everywhere unless a surface override is turned on.",
                profile: $draft.baseProfile,
                feeds: draft.feeds
            )

            NewsSurfaceOverrideEditor(
                title: "Dashboard Override",
                surfaceLabel: NewsSurface.dashboard.displayName,
                overrideProfile: Binding(
                    get: { draft.dashboardOverride },
                    set: { draft.dashboardOverride = $0 }
                ),
                baseProfile: draft.baseProfile,
                feeds: draft.feeds
            )

            NewsSurfaceOverrideEditor(
                title: "John Override",
                surfaceLabel: NewsSurface.john.displayName,
                overrideProfile: Binding(
                    get: { draft.johnOverride },
                    set: { draft.johnOverride = $0 }
                ),
                baseProfile: draft.baseProfile,
                feeds: draft.feeds
            )

            NewsSurfaceOverrideEditor(
                title: "Amy Override",
                surfaceLabel: NewsSurface.amy.displayName,
                overrideProfile: Binding(
                    get: { draft.amyOverride },
                    set: { draft.amyOverride = $0 }
                ),
                baseProfile: draft.baseProfile,
                feeds: draft.feeds
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Apply Base To All Surfaces") {
                        draft = draft.applyingBaseToAllSurfaces()
                    }
                    Button("Save News Settings") {
                        Task { await model.saveNewsSettings(draft) }
                    }
                    Button("Refresh News") {
                        Task { await model.refreshNewsNow() }
                    }
                }
                Text(model.newsSettingsStatusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let newsError = model.newsSettingsError {
                    Text(newsError)
                        .foregroundStyle(.red)
                }
                if let sourceMessage = model.sourceMessage(for: .news) {
                    Text(sourceMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .onAppear {
            syncFromModel()
        }
        .onChange(of: model.newsSettings) { _, _ in
            syncFromModel()
        }
    }

    private func bindingForFeed(at index: Int) -> Binding<ConfiguredNewsFeed> {
        Binding(
            get: { draft.feeds[index] },
            set: { draft.feeds[index] = $0 }
        )
    }

    private func syncFromModel() {
        draft = model.newsSettings
    }
}

private struct NewsFeedEditorRow: View {
    @Binding var feed: ConfiguredNewsFeed
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(feed.isUserAdded ? "Manual Feed" : "Starter Feed")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Remove", role: .destructive, action: remove)
            }
            TextField("Feed label", text: $feed.label)
                .textFieldStyle(.roundedBorder)
            TextField("Feed URL", text: $feed.feedURLString)
                .textFieldStyle(.roundedBorder)
            HStack {
                Picker("Category", selection: $feed.category) {
                    ForEach(NewsCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                Toggle("Enabled", isOn: $feed.isEnabled)
            }
            HStack {
                Text("Source Priority")
                    .font(.caption.weight(.semibold))
                Slider(value: $feed.sourcePriority, in: 0.5...2.0, step: 0.05)
                Text(String(format: "%.2f", feed.sourcePriority))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct NewsProfileEditor: View {
    let title: String
    let subtitle: String
    @Binding var profile: NewsProfile
    let feeds: [ConfiguredNewsFeed]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(feeds) { feed in
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(feed.label, isOn: includeBinding(for: feed.id))
                    HStack {
                        Text("Boost")
                            .font(.caption.weight(.semibold))
                        Slider(value: boostBinding(for: feed.id), in: -0.5...0.75, step: 0.05)
                        Text(String(format: "%+.2f", profile.boost(for: feed.id)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(feed.feedURLString)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func includeBinding(for feedID: String) -> Binding<Bool> {
        Binding(
            get: { profile.includes(feedID: feedID) },
            set: { include in
                var included = Set(profile.includedFeedIDs)
                if include {
                    included.insert(feedID)
                } else {
                    included.remove(feedID)
                }
                profile.includedFeedIDs = included.sorted()
            }
        )
    }

    private func boostBinding(for feedID: String) -> Binding<Double> {
        Binding(
            get: { profile.boost(for: feedID) },
            set: { value in
                if abs(value) < 0.001 {
                    profile.feedBoosts.removeValue(forKey: feedID)
                } else {
                    profile.feedBoosts[feedID] = value
                }
            }
        )
    }
}

private struct NewsSurfaceOverrideEditor: View {
    let title: String
    let surfaceLabel: String
    @Binding var overrideProfile: NewsProfile?
    let baseProfile: NewsProfile
    let feeds: [ConfiguredNewsFeed]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            Toggle(
                "Use a custom \(surfaceLabel.lowercased()) override",
                isOn: Binding(
                    get: { overrideProfile != nil },
                    set: { enabled in
                        overrideProfile = enabled ? baseProfile : nil
                    }
                )
            )
            if overrideProfile != nil {
                NewsProfileEditor(
                    title: "\(surfaceLabel) Profile",
                    subtitle: "This surface now diverges from the shared base profile.",
                    profile: Binding(
                        get: { overrideProfile ?? baseProfile },
                        set: { overrideProfile = $0 }
                    ),
                    feeds: feeds
                )
            } else {
                Text("\(surfaceLabel) is using the shared base profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct SenderSettingsView: View {
    @ObservedObject var model: ReadyRoomAppModel
    @State private var johnRecipientsText = ""
    @State private var amyRecipientsText = ""
    @State private var preferredTransport: SenderTransport = .smtp
    @State private var allowAppleMailFallback = true
    @State private var scheduledSendHour = 6
    @State private var scheduledSendMinute = 30
    @State private var catchUpDeadlineHour = 12
    @State private var smtpIsEnabled = false
    @State private var smtpHost = ""
    @State private var smtpPort = 465
    @State private var smtpSecurity: SMTPSecurity = .implicitTLS
    @State private var smtpUsername = ""
    @State private var smtpFromAddress = ""
    @State private var smtpFromDisplayName = ""
    @State private var smtpAuthentication: SMTPAuthenticationMethod = .automatic
    @State private var smtpConnectionTimeoutSeconds = 20
    @State private var smtpPassword = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sender")
                    .font(.headline)
                Text("Ready Room can now send multipart HTML mail over SMTP and fall back to Apple Mail compatibility mode when needed. SMTP server details are shared across Macs, while the SMTP password stays only in this Mac's Keychain.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text("Delivery Path")
                    .font(.headline)
                Picker("Preferred Sender", selection: $preferredTransport) {
                    ForEach(SenderTransport.allCases, id: \.self) { transport in
                        Text(transport.displayName).tag(transport)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Allow Apple Mail fallback if SMTP is unavailable or fails", isOn: $allowAppleMailFallback)
                    .disabled(preferredTransport == .appleMail)

                if preferredTransport == .smtp {
                    if model.smtpPasswordStored {
                        Text("SMTP is preferred. This Mac currently has an SMTP password stored in Keychain.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("SMTP is preferred, but this Mac still needs an SMTP password saved locally before unattended HTML sends can work.")
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text("Apple Mail remains the active sender path. That path sends a readable plain-text compatibility version rather than full HTML.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text("Primary Sender")
                    .font(.headline)
                Text("This Mac ID: \(model.machineIdentifier)")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                if model.primarySenderConfiguration.machineIdentifier.isEmpty {
                    Text("No primary sender is configured yet.")
                        .foregroundStyle(.secondary)
                } else {
                    Text(model.primarySenderConfiguration.machineIdentifier == model.machineIdentifier ? "This Mac is the primary scheduled sender." : "Another Mac is currently set as the primary scheduled sender.")
                        .foregroundStyle(.secondary)
                    Text("Configured primary ID: \(model.primarySenderConfiguration.machineIdentifier)")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                HStack {
                    Button("Make This Mac Primary") {
                        Task { await model.makeThisMacPrimarySender() }
                    }
                    Button("Clear Primary Sender") {
                        Task { await model.clearPrimarySender() }
                    }
                    .disabled(model.primarySenderConfiguration.machineIdentifier.isEmpty)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text("SMTP HTML Sender")
                    .font(.headline)
                Toggle("Enable SMTP HTML delivery", isOn: $smtpIsEnabled)
                Text("Use the mailbox account you want Ready Room to send from. If the account uses MFA, this usually needs an app password rather than your normal sign-in.")
                    .foregroundStyle(.secondary)

                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        Text("Host")
                        TextField("smtp.example.com", text: $smtpHost)
                            .textFieldStyle(.roundedBorder)
                    }
                    GridRow {
                        Text("Port")
                        Stepper("\(smtpPort)", value: $smtpPort, in: 1...65535)
                    }
                    GridRow {
                        Text("Security")
                        Picker("Security", selection: $smtpSecurity) {
                            ForEach(SMTPSecurity.allCases, id: \.self) { security in
                                Text(security.displayName).tag(security)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    GridRow {
                        Text("Auth")
                        Picker("Authentication", selection: $smtpAuthentication) {
                            ForEach(SMTPAuthenticationMethod.allCases, id: \.self) { method in
                                Text(method.displayName).tag(method)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    GridRow {
                        Text("Username")
                        TextField("username@example.com", text: $smtpUsername)
                            .textFieldStyle(.roundedBorder)
                    }
                    GridRow {
                        Text("From Email")
                        TextField("readyroom@example.com", text: $smtpFromAddress)
                            .textFieldStyle(.roundedBorder)
                    }
                    GridRow {
                        Text("From Name")
                        TextField("Ready Room", text: $smtpFromDisplayName)
                            .textFieldStyle(.roundedBorder)
                    }
                    GridRow {
                        Text("Timeout")
                        Stepper("\(smtpConnectionTimeoutSeconds) seconds", value: $smtpConnectionTimeoutSeconds, in: 5...60)
                    }
                }

                SecureField("SMTP app password (leave blank to keep the current stored password)", text: $smtpPassword)
                    .textFieldStyle(.roundedBorder)

                if model.smtpPasswordStored {
                    Text("Stored locally on this Mac: SMTP password is present in Keychain.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("No SMTP password is stored locally on this Mac yet.")
                        .foregroundStyle(.orange)
                }

                HStack {
                    Button("Clear Stored SMTP Password") {
                        Task { await model.clearStoredSMTPPassword() }
                    }
                    .disabled(model.smtpPasswordStored == false)

                    if smtpIsEnabled && preferredTransport == .smtp && (smtpHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || smtpUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || smtpFromAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        Text("Host, username, and from email are required for SMTP.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text("Recipients")
                    .font(.headline)
                Text("Use commas, semicolons, or new lines to separate addresses.")
                    .foregroundStyle(.secondary)
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("John")
                        TextField("john@example.com, another@example.com", text: $johnRecipientsText, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    GridRow {
                        Text("Amy")
                        TextField("amy@example.com", text: $amyRecipientsText, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
                if johnRecipientsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amyRecipientsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Both briefings need at least one real recipient before morning sends will succeed.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text("Schedule")
                    .font(.headline)
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        Text("Send Hour")
                        Stepper("\(scheduledSendHour)", value: $scheduledSendHour, in: 0...23)
                    }
                    GridRow {
                        Text("Send Minute")
                        Stepper("\(scheduledSendMinute)", value: $scheduledSendMinute, in: 0...59)
                    }
                    GridRow {
                        Text("Catch-Up Deadline")
                        Stepper("\(catchUpDeadlineHour):00", value: $catchUpDeadlineHour, in: 1...23)
                    }
                }
                Text("Current schedule: \(String(format: "%02d:%02d", scheduledSendHour, scheduledSendMinute)) with same-day catch-up until \(catchUpDeadlineHour):00.")
                    .foregroundStyle(.secondary)
                Button("Save Sender Settings") {
                    Task {
                        await model.saveSenderSettings(
                            johnRecipientsText: johnRecipientsText,
                            amyRecipientsText: amyRecipientsText,
                            preferredTransport: preferredTransport,
                            allowAppleMailFallback: allowAppleMailFallback,
                            scheduledSendHour: scheduledSendHour,
                            scheduledSendMinute: scheduledSendMinute,
                            catchUpDeadlineHour: catchUpDeadlineHour,
                            smtpIsEnabled: smtpIsEnabled,
                            smtpHost: smtpHost,
                            smtpPort: smtpPort,
                            smtpSecurity: smtpSecurity,
                            smtpUsername: smtpUsername,
                            smtpFromAddress: smtpFromAddress,
                            smtpFromDisplayName: smtpFromDisplayName,
                            smtpAuthentication: smtpAuthentication,
                            smtpConnectionTimeoutSeconds: smtpConnectionTimeoutSeconds,
                            smtpPassword: smtpPassword
                        )
                        smtpPassword = ""
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .onAppear(perform: loadFromModel)
        .onChange(of: model.senderSettings) { _, _ in
            loadFromModel()
        }
    }

    private func loadFromModel() {
        johnRecipientsText = model.senderSettings.johnRecipients.joined(separator: ", ")
        amyRecipientsText = model.senderSettings.amyRecipients.joined(separator: ", ")
        preferredTransport = model.senderSettings.preferredTransport
        allowAppleMailFallback = model.senderSettings.allowAppleMailFallback
        scheduledSendHour = model.senderSettings.primary.scheduledSendHour
        scheduledSendMinute = model.senderSettings.primary.scheduledSendMinute
        catchUpDeadlineHour = model.senderSettings.primary.catchUpDeadlineHour
        smtpIsEnabled = model.senderSettings.smtp.isEnabled
        smtpHost = model.senderSettings.smtp.host
        smtpPort = model.senderSettings.smtp.port
        smtpSecurity = model.senderSettings.smtp.security
        smtpUsername = model.senderSettings.smtp.username
        smtpFromAddress = model.senderSettings.smtp.fromAddress
        smtpFromDisplayName = model.senderSettings.smtp.fromDisplayName
        smtpAuthentication = model.senderSettings.smtp.authentication
        smtpConnectionTimeoutSeconds = model.senderSettings.smtp.connectionTimeoutSeconds
        smtpPassword = ""
    }
}

private struct StorageSyncSettingsView: View {
    @ObservedObject var model: ReadyRoomAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Storage/Sync")
                        .font(.headline)
                    Text("Ready Room can use iCloud Drive, a custom shared folder, or a local fallback folder. Custom folder paths are stored locally on each Mac, so your Mac mini and other Mac can point to different absolute Resilio Sync paths while sharing the same files.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh Status") {
                    Task { await model.refreshStorageStatus() }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Custom Shared Folder")
                    .font(.headline)
                Text("Choose the dedicated Resilio-synced folder Ready Room should use on this Mac. This folder path is local-only and is not synced to your other Mac.")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Choose Shared Folder...") {
                        chooseCustomSharedFolder()
                    }
                    Button("Use Automatic/Local Fallback") {
                        Task { await model.setCustomSharedFolder(nil) }
                    }
                    .disabled(model.storagePreferences.customSharedRoot == nil)
                }
                if let customSharedRoot = model.storagePreferences.customSharedRoot {
                    storagePathRow(title: "Selected on This Mac", url: customSharedRoot)
                    Text("Existing shared files are not automatically moved when you change folders. New reads and writes will use the folder selected on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            if let status = model.storageStatus {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Shared Storage Mode")
                            .font(.subheadline.weight(.semibold))
                        Text(status.roots.sharedMode.rawValue)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(status.roots.syncsAcrossMacs ? Color.green.opacity(0.15) : Color.orange.opacity(0.18), in: Capsule())
                    }
                    Text(status.summary)
                    Text(status.detail)
                        .foregroundStyle(.secondary)

                    storagePathRow(title: "Local Root", url: status.roots.localRoot)
                    storagePathRow(title: "Effective Shared Root", url: status.roots.effectiveSharedRoot)
                    if let sharedRoot = status.roots.sharedRoot {
                        storagePathRow(title: sharedRootTitle(for: status.roots.sharedMode), url: sharedRoot)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                storageFilesCard(
                    title: "Shared Across Macs",
                    subtitle: sharedFilesSubtitle(for: status.roots.sharedMode),
                    files: status.sharedFiles
                )

                storageFilesCard(
                    title: "Local Only",
                    subtitle: "These files intentionally stay on this Mac.",
                    files: status.localFiles
                )
            } else if let error = model.storageStatusError {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Storage Status Error")
                        .font(.headline)
                    Text(error)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                ProgressView("Loading storage status...")
            }
        }
    }

    private func chooseCustomSharedFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Shared Folder"
        panel.message = "Choose the Resilio-synced folder Ready Room should use for shared files on this Mac."
        panel.prompt = "Use Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        Task {
            await model.setCustomSharedFolder(url)
        }
    }

    private func sharedRootTitle(for mode: SharedStorageMode) -> String {
        switch mode {
        case .iCloudDrive:
            "iCloud Shared Root"
        case .customFolder:
            "Custom Shared Root"
        case .localFallback:
            "Effective Shared Root"
        }
    }

    private func sharedFilesSubtitle(for mode: SharedStorageMode) -> String {
        switch mode {
        case .iCloudDrive:
            "These files live in iCloud Drive and should sync across your Macs."
        case .customFolder:
            "These files live in the custom folder selected on this Mac. If your other Macs point Ready Room at synced copies of the same folder, these files should sync without iCloud."
        case .localFallback:
            "These files are using a local fallback folder right now, so changes stay on this Mac until shared storage is configured."
        }
    }

    private func storageFilesCard(title: String, subtitle: String, files: [StorageFileStatus]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .foregroundStyle(.secondary)
            Text("Not Created Yet is normal until that feature saves something for the first time.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(files) { file in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(file.label)
                            .font(.subheadline.weight(.semibold))
                        Text(file.exists ? "Created" : "Not Created Yet")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((file.exists ? Color.green : Color.secondary).opacity(0.15), in: Capsule())
                    }
                    Text(file.url.path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    if let modifiedAt = file.modifiedAt {
                        Text("Last modified: \(modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("This file will appear after Ready Room saves data for this area.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func storagePathRow(title: String, url: URL) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(url.path)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}

struct DebugView: View {
    @ObservedObject var model: ReadyRoomAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Debug")
                    .font(.largeTitle.weight(.bold))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source Health")
                        .font(.headline)
                    ForEach(model.sourceSnapshots, id: \.source.id) { snapshot in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(snapshot.source.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Text(snapshot.health.resolvedStatus(at: model.now).rawValue.capitalized)
                                    .foregroundStyle(.secondary)
                                if snapshot.isPlaceholder {
                                    Text("Placeholder")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                                }
                            }
                            if let placeholderLabel = snapshot.placeholderLabel {
                                Text(placeholderLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let message = snapshot.health.message, !message.isEmpty {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Raw Payload")
                        .font(.headline)
                    Text(model.debugJSON)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(24)
        }
    }
}

private struct HTMLPreview: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: nil)
    }
}
