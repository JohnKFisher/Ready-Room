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
    }
}

