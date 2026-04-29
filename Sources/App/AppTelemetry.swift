import Foundation
import OSLog

enum ReadyRoomLog {
    static let refresh = Logger(subsystem: ReadyRoomLog.subsystem, category: "Refresh")
    static let calendar = Logger(subsystem: ReadyRoomLog.subsystem, category: "CalendarPermission")
    static let send = Logger(subsystem: ReadyRoomLog.subsystem, category: "Send")
    static let storage = Logger(subsystem: ReadyRoomLog.subsystem, category: "Storage")

    private static var subsystem: String {
        Bundle.main.bundleIdentifier ?? "com.jkfisher.readyroom"
    }
}
