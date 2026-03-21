import Foundation
import ReadyRoomCore

public actor CalendarConfigurationStore {
    private let coordinator: ReadyRoomStorageCoordinator
    private let path = "Shared/calendar-configurations.json"

    public init(coordinator: ReadyRoomStorageCoordinator) {
        self.coordinator = coordinator
    }

    public func load() async throws -> [CalendarConfiguration] {
        try await coordinator.loadJSON([CalendarConfiguration].self, relativePath: path, scope: .shared) ?? []
    }

    public func save(_ configurations: [CalendarConfiguration]) async throws {
        try await coordinator.saveJSON(configurations, relativePath: path, scope: .shared)
    }
}

public actor ArchiveStore {
    private let coordinator: ReadyRoomStorageCoordinator
    private let path = "Shared/briefing-archive.json"

    public init(coordinator: ReadyRoomStorageCoordinator) {
        self.coordinator = coordinator
    }

    public func load() async throws -> [BriefingArtifact] {
        try await coordinator.loadJSON([BriefingArtifact].self, relativePath: path, scope: .shared) ?? []
    }

    public func append(_ artifact: BriefingArtifact, maxCount: Int = 28) async throws {
        var artifacts = try await load()
        artifacts.append(artifact)
        artifacts = artifacts.sorted { $0.generatedAt > $1.generatedAt }.prefix(maxCount).map { $0 }
        try await coordinator.saveJSON(artifacts, relativePath: path, scope: .shared)
    }
}

public actor SendRegistryStore {
    private let coordinator: ReadyRoomStorageCoordinator
    private let path = "Shared/send-records.json"

    public init(coordinator: ReadyRoomStorageCoordinator) {
        self.coordinator = coordinator
    }

    public func load() async throws -> [SendExecutionRecord] {
        try await coordinator.loadJSON([SendExecutionRecord].self, relativePath: path, scope: .shared) ?? []
    }

    public func append(_ record: SendExecutionRecord) async throws {
        var records = try await load()
        records.append(record)
        records = records.sorted { $0.createdAt > $1.createdAt }.prefix(200).map { $0 }
        try await coordinator.saveJSON(records, relativePath: path, scope: .shared)
    }
}

public actor DashboardLayoutStore {
    private let coordinator: ReadyRoomStorageCoordinator
    private let path = "Local/dashboard-layout.json"

    public init(coordinator: ReadyRoomStorageCoordinator) {
        self.coordinator = coordinator
    }

    public func load() async throws -> DashboardCardLayout {
        try await coordinator.loadJSON(DashboardCardLayout.self, relativePath: path, scope: .local) ?? DashboardCardLayout()
    }

    public func save(_ layout: DashboardCardLayout) async throws {
        try await coordinator.saveJSON(layout, relativePath: path, scope: .local)
    }
}

public actor CalendarBaselineStore {
    private let coordinator: ReadyRoomStorageCoordinator
    private let path = "Local/calendar-baseline.json"

    public init(coordinator: ReadyRoomStorageCoordinator) {
        self.coordinator = coordinator
    }

    public func load() async throws -> [NormalizedItem] {
        try await coordinator.loadJSON([NormalizedItem].self, relativePath: path, scope: .local) ?? []
    }

    public func save(_ items: [NormalizedItem]) async throws {
        try await coordinator.saveJSON(items, relativePath: path, scope: .local)
    }
}

public actor SenderSettingsStore {
    private let coordinator: ReadyRoomStorageCoordinator
    private let path = "Shared/sender-settings.json"

    public init(coordinator: ReadyRoomStorageCoordinator) {
        self.coordinator = coordinator
    }

    public func load() async throws -> SenderSettings {
        try await coordinator.loadJSON(SenderSettings.self, relativePath: path, scope: .shared) ?? SenderSettings()
    }

    public func save(_ settings: SenderSettings) async throws {
        try await coordinator.saveJSON(settings, relativePath: path, scope: .shared)
    }
}

public actor WeatherSettingsStore {
    private let coordinator: ReadyRoomStorageCoordinator
    private let path = "Shared/weather-settings.json"

    public init(coordinator: ReadyRoomStorageCoordinator) {
        self.coordinator = coordinator
    }

    public func load() async throws -> WeatherSettings {
        try await coordinator.loadJSON(WeatherSettings.self, relativePath: path, scope: .shared) ?? WeatherSettings()
    }

    public func save(_ settings: WeatherSettings) async throws {
        try await coordinator.saveJSON(settings, relativePath: path, scope: .shared)
    }
}

public actor NewsSettingsStore {
    private let coordinator: ReadyRoomStorageCoordinator
    private let path = "Shared/news-settings.json"

    public init(coordinator: ReadyRoomStorageCoordinator) {
        self.coordinator = coordinator
    }

    public func load() async throws -> NewsSettings {
        (try await coordinator.loadJSON(NewsSettings.self, relativePath: path, scope: .shared) ?? NewsSettings()).normalized()
    }

    public func save(_ settings: NewsSettings) async throws {
        try await coordinator.saveJSON(settings.normalized(), relativePath: path, scope: .shared)
    }
}

public actor LastGoodNewsSnapshotStore {
    private let coordinator: ReadyRoomStorageCoordinator
    private let path = "Local/last-good-news.json"

    public init(coordinator: ReadyRoomStorageCoordinator) {
        self.coordinator = coordinator
    }

    public func load() async throws -> LastGoodNewsSnapshot? {
        try await coordinator.loadJSON(LastGoodNewsSnapshot.self, relativePath: path, scope: .local)
    }

    public func save(_ snapshot: LastGoodNewsSnapshot) async throws {
        try await coordinator.saveJSON(snapshot, relativePath: path, scope: .local)
    }
}

public actor PersonColorPaletteSettingsStore {
    private let coordinator: ReadyRoomStorageCoordinator
    private let path = "Shared/person-color-palette.json"

    public init(coordinator: ReadyRoomStorageCoordinator) {
        self.coordinator = coordinator
    }

    public func load() async throws -> PersonColorPaletteSettings {
        let stored = try await coordinator.loadJSON(PersonColorPaletteSettings.self, relativePath: path, scope: .shared) ?? PersonColorPaletteSettings.default
        return stored.normalized()
    }

    public func save(_ settings: PersonColorPaletteSettings) async throws {
        try await coordinator.saveJSON(settings.normalized(), relativePath: path, scope: .shared)
    }
}

public actor SetupProgressStore {
    private let coordinator: ReadyRoomStorageCoordinator
    private let path = "Local/setup-progress.json"

    public init(coordinator: ReadyRoomStorageCoordinator) {
        self.coordinator = coordinator
    }

    public func load() async throws -> SetupProgress {
        try await coordinator.loadJSON(SetupProgress.self, relativePath: path, scope: .local) ?? SetupProgress()
    }

    public func save(_ progress: SetupProgress) async throws {
        try await coordinator.saveJSON(progress, relativePath: path, scope: .local)
    }
}

public actor MachineIdentityStore {
    private let coordinator: ReadyRoomStorageCoordinator
    private let path = "Local/machine-identity.json"

    public init(coordinator: ReadyRoomStorageCoordinator) {
        self.coordinator = coordinator
    }

    public func loadOrCreate() async throws -> String {
        if let identity = try await coordinator.loadJSON(String.self, relativePath: path, scope: .local) {
            return identity
        }
        let identifier = UUID().uuidString
        try await coordinator.saveJSON(identifier, relativePath: path, scope: .local)
        return identifier
    }
}
