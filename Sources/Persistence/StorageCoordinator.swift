import Foundation
import ReadyRoomCore

public enum StorageScope: String, Codable, Sendable {
    case local
    case shared
}

public enum SharedStorageMode: String, Sendable {
    case iCloudDrive = "iCloud Drive"
    case customFolder = "Custom Folder"
    case localFallback = "Local Fallback"
}

public struct StoragePreferences: Codable, Sendable, Hashable {
    public var customSharedRootPath: String?

    public init(customSharedRootPath: String? = nil) {
        self.customSharedRootPath = customSharedRootPath
    }

    public var customSharedRoot: URL? {
        guard let customSharedRootPath, !customSharedRootPath.isEmpty else {
            return nil
        }
        return URL(filePath: customSharedRootPath, directoryHint: .isDirectory)
    }
}

public struct StorageRoots: Sendable {
    public var localRoot: URL
    public var sharedRoot: URL?
    public var sharedMode: SharedStorageMode

    public init(localRoot: URL, sharedRoot: URL?, sharedMode: SharedStorageMode) {
        self.localRoot = localRoot
        self.sharedRoot = sharedRoot
        self.sharedMode = sharedMode
    }

    public var effectiveSharedRoot: URL {
        switch sharedMode {
        case .localFallback:
            localRoot.appendingPathComponent("SharedFallback", isDirectory: true)
        case .iCloudDrive, .customFolder:
            sharedRoot ?? localRoot.appendingPathComponent("SharedFallback", isDirectory: true)
        }
    }

    public var syncsAcrossMacs: Bool {
        sharedMode != .localFallback
    }
}

public struct StorageFileStatus: Sendable, Identifiable {
    public var label: String
    public var relativePath: String
    public var scope: StorageScope
    public var url: URL
    public var exists: Bool
    public var modifiedAt: Date?

    public var id: String {
        "\(scope.rawValue):\(relativePath)"
    }

    public init(label: String, relativePath: String, scope: StorageScope, url: URL, exists: Bool, modifiedAt: Date?) {
        self.label = label
        self.relativePath = relativePath
        self.scope = scope
        self.url = url
        self.exists = exists
        self.modifiedAt = modifiedAt
    }
}

public struct StorageStatus: Sendable {
    public var roots: StorageRoots
    public var sharedFiles: [StorageFileStatus]
    public var localFiles: [StorageFileStatus]

    public init(roots: StorageRoots, sharedFiles: [StorageFileStatus], localFiles: [StorageFileStatus]) {
        self.roots = roots
        self.sharedFiles = sharedFiles
        self.localFiles = localFiles
    }

    public var summary: String {
        switch roots.sharedMode {
        case .iCloudDrive:
            return "Shared files are using iCloud Drive and should sync across Macs signed into the same iCloud account."
        case .customFolder:
            return "Shared files are using a custom shared folder selected on this Mac."
        case .localFallback:
            return "Shared files are currently stored in a local fallback folder on this Mac, so they are not syncing across computers yet."
        }
    }

    public var detail: String {
        switch roots.sharedMode {
        case .iCloudDrive:
            "Shared app data is stored in Ready Room's iCloud Drive documents folder."
        case .customFolder:
            "The custom shared-folder path is stored locally on this Mac, so each Mac can point to a different absolute Resilio Sync path. If both Macs point to synced copies of the same folder, Ready Room's shared files will sync without iCloud."
        case .localFallback:
            "iCloud Drive is not active for Ready Room on this Mac right now. That usually means this build is not signed with iCloud entitlements yet, or iCloud Drive is unavailable for the current macOS account."
        }
    }
}

public actor ReadyRoomStorageCoordinator {
    public static let bundleIdentifier = "com.jkfisher.readyroom"

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storagePreferencesPath = "Local/storage-preferences.json"

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func resolveRoots() throws -> StorageRoots {
        let localRoot = try resolveLocalRoot()
        let preferences = try loadStoragePreferences()

        if let customSharedRoot = preferences.customSharedRoot?.standardizedFileURL {
            try? fileManager.createDirectory(at: customSharedRoot, withIntermediateDirectories: true)
            return StorageRoots(localRoot: localRoot, sharedRoot: customSharedRoot, sharedMode: .customFolder)
        }

        let iCloudSharedRoot = fileManager
            .url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("ReadyRoom", isDirectory: true)

        if let iCloudSharedRoot {
            try? fileManager.createDirectory(at: iCloudSharedRoot, withIntermediateDirectories: true)
            return StorageRoots(localRoot: localRoot, sharedRoot: iCloudSharedRoot, sharedMode: .iCloudDrive)
        }

        return StorageRoots(localRoot: localRoot, sharedRoot: nil, sharedMode: .localFallback)
    }

    public func loadStoragePreferences() throws -> StoragePreferences {
        let url = try resolveLocalRoot().appendingPathComponent(storagePreferencesPath)
        guard fileManager.fileExists(atPath: url.path) else {
            return StoragePreferences()
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(StoragePreferences.self, from: data)
    }

    public func setCustomSharedRoot(_ url: URL?) throws {
        var preferences = try loadStoragePreferences()
        preferences.customSharedRootPath = url?.standardizedFileURL.path
        try saveStoragePreferences(preferences)
    }

    private func saveStoragePreferences(_ preferences: StoragePreferences) throws {
        let url = try resolveLocalRoot().appendingPathComponent(storagePreferencesPath)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(preferences)
        try data.write(to: url, options: .atomic)
    }

    private func resolveLocalRoot() throws -> URL {
        let localBase = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let localRoot = localBase.appendingPathComponent("ReadyRoom", isDirectory: true)
        try fileManager.createDirectory(at: localRoot, withIntermediateDirectories: true)
        return localRoot
    }

    public func url(for relativePath: String, scope: StorageScope) throws -> URL {
        let roots = try resolveRoots()
        switch scope {
        case .local:
            return roots.localRoot.appendingPathComponent(relativePath)
        case .shared:
            return roots.effectiveSharedRoot.appendingPathComponent(relativePath)
        }
    }

    public func describeStorageStatus() throws -> StorageStatus {
        let roots = try resolveRoots()
        try fileManager.createDirectory(at: roots.effectiveSharedRoot, withIntermediateDirectories: true)

        let sharedFiles = try [
            fileStatus(label: "Obligations", relativePath: "Shared/obligations.yaml", scope: .shared),
            fileStatus(label: "Calendar Configurations", relativePath: "Shared/calendar-configurations.json", scope: .shared),
            fileStatus(label: "Briefing Archive", relativePath: "Shared/briefing-archive.json", scope: .shared),
            fileStatus(label: "Send Records", relativePath: "Shared/send-records.json", scope: .shared),
            fileStatus(label: "Sender Settings", relativePath: "Shared/sender-settings.json", scope: .shared)
        ]

        let localFiles = try [
            fileStatus(label: "Dashboard Layout", relativePath: "Local/dashboard-layout.json", scope: .local),
            fileStatus(label: "Setup Progress", relativePath: "Local/setup-progress.json", scope: .local),
            fileStatus(label: "Machine Identity", relativePath: "Local/machine-identity.json", scope: .local),
            fileStatus(label: "Storage Preferences", relativePath: storagePreferencesPath, scope: .local)
        ]

        return StorageStatus(roots: roots, sharedFiles: sharedFiles, localFiles: localFiles)
    }

    public func saveJSON<T: Encodable>(_ value: T, relativePath: String, scope: StorageScope) throws {
        let url = try url(for: relativePath, scope: scope)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    public func loadJSON<T: Decodable>(_ type: T.Type, relativePath: String, scope: StorageScope) throws -> T? {
        let url = try url(for: relativePath, scope: scope)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }

    public func saveText(_ value: String, relativePath: String, scope: StorageScope) throws {
        let url = try url(for: relativePath, scope: scope)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try value.write(to: url, atomically: true, encoding: .utf8)
    }

    public func loadText(relativePath: String, scope: StorageScope) throws -> String? {
        let url = try url(for: relativePath, scope: scope)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    public func modificationDate(relativePath: String, scope: StorageScope) throws -> Date? {
        let url = try url(for: relativePath, scope: scope)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return try fileManager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    private func fileStatus(label: String, relativePath: String, scope: StorageScope) throws -> StorageFileStatus {
        let url = try url(for: relativePath, scope: scope)
        let exists = fileManager.fileExists(atPath: url.path)
        let modifiedAt = try modificationDate(relativePath: relativePath, scope: scope)
        return StorageFileStatus(
            label: label,
            relativePath: relativePath,
            scope: scope,
            url: url,
            exists: exists,
            modifiedAt: modifiedAt
        )
    }
}
