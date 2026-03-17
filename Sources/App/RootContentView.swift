import AppKit
import SwiftUI

struct RootContentView: View {
    @ObservedObject var model: ReadyRoomAppModel

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(ReadyRoomAppModel.Screen.allCases, selection: $model.selectedScreen) { screen in
                    Label(screen.title, systemImage: icon(for: screen))
                        .tag(screen)
                }
                .frame(minWidth: 200)

                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    Text("Version")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(AppRuntimeMetadata.displayString)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        } detail: {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()
                switch model.selectedScreen {
                case .dashboard:
                    DashboardView(model: model)
                case .preview:
                    PreviewView(model: model)
                case .obligations:
                    ObligationsView(model: model)
                case .settings:
                    SettingsView(model: model)
                case .debug:
                    DebugView(model: model)
                }
            }
            .background(DashboardWindowBridge(enabled: model.dashboardModeEnabled))
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button("Refresh") {
                    Task { await model.refresh() }
                }
                Button("Briefing") {
                    model.selectedScreen = .preview
                }
                Button("Send Now") {
                    model.showSendChooser = true
                }
            }
        }
        .confirmationDialog("Send briefing now", isPresented: $model.showSendChooser) {
            Button("John") { Task { await model.sendNow([.john]) } }
            Button("Amy") { Task { await model.sendNow([.amy]) } }
            Button("Both") { Task { await model.sendNow([.john, .amy]) } }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            await model.runClockLoop()
        }
    }

    private func icon(for screen: ReadyRoomAppModel.Screen) -> String {
        switch screen {
        case .dashboard: "rectangle.grid.2x2"
        case .preview: "envelope.open"
        case .obligations: "checklist"
        case .settings: "slider.horizontal.3"
        case .debug: "ladybug"
        }
    }
}
