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
        VStack(alignment: .leading, spacing: 18) {
            Text("Obligations")
                .font(.largeTitle.weight(.bold))
            TextField("Mortgage due every month on the 15th, remind me 7 and 3 days before", text: $model.obligationDraft)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Parse") { model.parseObligationDraft() }
                Button("Save Parsed Item") {
                    Task { await model.saveParsedObligation() }
                }
                .disabled(model.parsedObligationCandidate?.structured == nil)
            }

            if let parsed = model.parsedObligationCandidate {
                VStack(alignment: .leading, spacing: 8) {
                    Text("I understood this as...")
                        .font(.headline)
                    Text(parsed.explanation)
                    if let structured = parsed.structured {
                        Text("Structured title: \(structured.title)")
                        Text("Lead days: \(structured.reminderLeadDays.map(String.init).joined(separator: ", "))")
                        Text("Schedule: \(structured.schedule.kind.rawValue)")
                    }
                    if !parsed.missingFields.isEmpty {
                        Text("Missing: \(parsed.missingFields.joined(separator: ", "))")
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            List(model.obligations) { obligation in
                VStack(alignment: .leading, spacing: 4) {
                    Text(obligation.title)
                    Text(obligation.explanation ?? obligation.schedule.kind.rawValue.capitalized)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
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
