import SwiftUI
import WebKit
import ReadyRoomCore

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
                ArtifactCard(title: "Final Preview", artifact: artifact)
            } else {
                ContentUnavailableView("No Preview Yet", systemImage: "envelope.badge")
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
            List(ReadyRoomAppModel.PreferencesSection.allCases, selection: $model.selectedPreferencesSection) { section in
                Text(section.rawValue)
            }
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(model.selectedPreferencesSection.rawValue)
                        .font(.largeTitle.weight(.bold))
                    switch model.selectedPreferencesSection {
                    case .general:
                        settingsCard("General", body: "Personal-app-first defaults, setup rerun support, and local-first behavior live here.")
                    case .calendars:
                        settingsCard("Calendars", body: "EventKit-first calendar discovery, role confirmation, and include/exclude controls.")
                    case .briefings:
                        settingsCard("Briefings", body: "Recipient lists, preview-only mode, and section behavior will be configured here.")
                    case .dashboard:
                        settingsCard("Dashboard", body: "Card order is local per Mac. Quiet hours currently default to 11:00 PM to 6:00 AM.")
                    case .obligations:
                        settingsCard("Obligations", body: "YAML-backed obligations and the parse/approve workflow are available from the Obligations screen.")
                    case .ai:
                        settingsCard("AI", body: "Preferred order is Foundation Models, Ollama, then deterministic templates.")
                    case .news:
                        settingsCard("News", body: "RSS/Atom feed sources and recipient weighting will be configured here.")
                    case .media:
                        settingsCard("Media", body: "Plex, Tautulli, Sonarr, and Radarr configuration belongs here.")
                    case .storageSync:
                        settingsCard("Storage/Sync", body: "Shared state uses iCloud Documents when available, with local fallback for machine-only state.")
                    case .sender:
                        settingsCard("Sender", body: "Apple Mail is the default sender path, with a primary-machine-only scheduler.")
                    case .advancedDebug:
                        settingsCard("Advanced/Debug", body: "Use the Debug screen for raw data inspection, source health, and preview traces.")
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
                        Text("\(snapshot.source.displayName): \(snapshot.health.resolvedStatus(at: model.now).rawValue)")
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
