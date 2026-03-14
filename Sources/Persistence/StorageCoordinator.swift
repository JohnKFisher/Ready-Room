import Foundation
import ReadyRoomCore

public enum StorageScope: String, Codable, Sendable {
    case local
    case shared
}

public enum SharedStorageMode: String, Sendable {
    case iCloudDrive = "iCloud Drive"
    case localFallback = "Local Fallback"
}

public struct StorageRoots: Sendable {
    public var localRoot: URL
    public var sharedRoot: URL?

    public init(localRoot: URL, sharedRoot: URL?) {
        self.localRoot = localRoot
        self.sharedRoot = sharedRoot
    }

    public var effectiveSharedRoot: URL {
        sharedRoot ?? localRoot.appendingPathComponent("SharedFallback", isDirectory: true)
    }

    public var sharedMode: SharedStorageMode {
        sharedRoot == nil ? .localFallback : .iCloudDrive
    }

    public var syncsAcrossMacs: Bool {
        sharedRoot != nil
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
        if roots.syncsAcrossMacs {
            return "Shared files are using iCloud Drive and should sync across Macs signed into the same iCloud account."
        }
        return "Shared files are currently falling back to a local folder on this Mac, so they will not sync across computers yet."
    }

    public var detail: String {
        switch roots.sharedMode {
        case .iCloudDrive:
            "Shared app data is stored in iCloud Drive."
        case .localFallback:
            "iCloud Drive storage is unavailable to this app right now, so shared files are being stored locally instead."
        }
    }
}

public actor ReadyRoomStorageCoordinator {
    public static let bundleIdentifier = "com.jkfisher.readyroom"

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func resolveRoots() throws -> StorageRoots {
        let localBase = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let localRoot = localBase.appendingPathComponent("ReadyRoom", isDirectory: true)
        try fileManager.createDirectory(at: localRoot, withIntermediateDirectories: true)

        let sharedRoot = fileManager
            .url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("ReadyRoom", isDirectory: true)

        if let sharedRoot {
            try? fileManager.createDirectory(at: sharedRoot, withIntermediateDirectories: true)
        }

        return StorageRoots(localRoot: localRoot, sharedRoot: sharedRoot)
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
            fileStatus(label: "Send Records", relativePath: "Shared/send-records.json", scope: .shared)
        ]

        let localFiles = try [
            fileStatus(label: "Dashboard Layout", relativePath: "Local/dashboard-layout.json", scope: .local),
            fileStatus(label: "Setup Progress", relativePath: "Local/setup-progress.json", scope: .local),
            fileStatus(label: "Machine Identity", relativePath: "Local/machine-identity.json", scope: .local)
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

    private func fileStatus(label: String, relativePath: String, scope: StorageScope) throws -> StorageFileStatus {
        let url = try url(for: relativePath, scope: scope)
        let exists = fileManager.fileExists(atPath: url.path)
        let modifiedAt: Date?
        if exists {
            modifiedAt = try fileManager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        } else {
            modifiedAt = nil
        }
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
