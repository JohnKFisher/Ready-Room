import SwiftUI

@main
struct ReadyRoomApp: App {
    @StateObject private var model = ReadyRoomAppModel()

    var body: some Scene {
        WindowGroup("Ready Room") {
            RootContentView(model: model)
                .frame(minWidth: 1180, minHeight: 760)
        }
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandMenu("Ready Room") {
                Button("Refresh Sources") {
                    Task { await model.refresh() }
                }
                .keyboardShortcut("r", modifiers: [.command])

                Divider()

                Button("Show Dashboard") {
                    model.selectedScreen = .dashboard
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Show Briefing") {
                    model.selectedScreen = .preview
                }
                .keyboardShortcut("2", modifiers: [.command])

                Divider()

                Button("Send Briefing Now...") {
                    model.showSendChooser = true
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}
