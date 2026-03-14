import Foundation
import ReadyRoomCore

public enum StorageScope: String, Codable, Sendable {
    case local
    case shared
}

public struct StorageRoots: Sendable {
    public var localRoot: URL
    public var sharedRoot: URL?

    public init(localRoot: URL, sharedRoot: URL?) {
        self.localRoot = localRoot
        self.sharedRoot = sharedRoot
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
            if let sharedRoot = roots.sharedRoot {
                return sharedRoot.appendingPathComponent(relativePath)
            }
            return roots.localRoot.appendingPathComponent("SharedFallback").appendingPathComponent(relativePath)
        }
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
}

