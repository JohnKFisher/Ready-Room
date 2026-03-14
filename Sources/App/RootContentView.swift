import SwiftUI

struct RootContentView: View {
    @ObservedObject var model: ReadyRoomAppModel

    var body: some View {
        NavigationSplitView {
            List(ReadyRoomAppModel.Screen.allCases, selection: $model.selectedScreen) { screen in
                Label(screen.rawValue.capitalized, systemImage: icon(for: screen))
                    .tag(screen)
            }
            .frame(minWidth: 200)
        } detail: {
            ZStack {
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
                Button("Preview") {
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
