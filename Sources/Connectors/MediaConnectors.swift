import Foundation
import ReadyRoomCore
import ReadyRoomPersistence

public struct MediaServiceConfiguration: Codable, Sendable, Hashable {
    public var baseURL: URL
    public var tokenAccountKey: String

    public init(baseURL: URL, tokenAccountKey: String) {
        self.baseURL = baseURL
        self.tokenAccountKey = tokenAccountKey
    }
}

public actor PlexFamilyConnectors {
    public let source = SourceDescriptor(id: "media", displayName: "Media", type: .media)

    private let session: URLSession
    private let secretsStore: KeychainSecretStore
    private let plex: MediaServiceConfiguration?
    private let tautulli: MediaServiceConfiguration?
    private let sonarr: MediaServiceConfiguration?
    private let radarr: MediaServiceConfiguration?

    public init(
        session: URLSession = .shared,
        secretsStore: KeychainSecretStore,
        plex: MediaServiceConfiguration? = nil,
        tautulli: MediaServiceConfiguration? = nil,
        sonarr: MediaServiceConfiguration? = nil,
        radarr: MediaServiceConfiguration? = nil
    ) {
        self.session = session
        self.secretsStore = secretsStore
        self.plex = plex
        self.tautulli = tautulli
        self.sonarr = sonarr
        self.radarr = radarr
    }

    public func refresh() async throws -> SourceSnapshot {
        var activities: [MediaActivity] = []
        var message: String? = "No media services configured."
        var status: SourceHealthStatus = .unconfigured

        if let tautulli {
            let token = try await secretsStore.load(account: tautulli.tokenAccountKey)
            if let token {
                activities.append(contentsOf: try await fetchTautulliNowPlaying(configuration: tautulli, token: token))
                status = .healthy
                message = nil
            }
        }

        if let plex {
            let token = try await secretsStore.load(account: plex.tokenAccountKey)
            if let token {
                activities.append(contentsOf: try await fetchPlexRecentAdditions(configuration: plex, token: token))
                status = .healthy
                message = nil
            }
        }

        if let sonarr {
            let token = try await secretsStore.load(account: sonarr.tokenAccountKey)
            if let token {
                activities.append(contentsOf: try await fetchUpcomingTitles(kind: .airingSoon, configuration: sonarr, token: token, path: "api/v3/calendar"))
                status = .healthy
                message = nil
            }
        }

        if let radarr {
            let token = try await secretsStore.load(account: radarr.tokenAccountKey)
            if let token {
                activities.append(contentsOf: try await fetchUpcomingTitles(kind: .airingSoon, configuration: radarr, token: token, path: "api/v3/calendar"))
                status = .healthy
                message = nil
            }
        }

        return SourceSnapshot(
            source: source,
            fetchedAt: .now,
            lastGoodFetchAt: status == .healthy ? .now : nil,
            health: SourceHealth(status: status, message: message, lastSuccessAt: status == .healthy ? .now : nil, freshnessBudget: 1800),
            mediaItems: activities
        )
    }

    private func fetchTautulliNowPlaying(configuration: MediaServiceConfiguration, token: String) async throws -> [MediaActivity] {
        let url = configuration.baseURL.appendingPathComponent("api/v2").appending(queryItems: [
            URLQueryItem(name: "apikey", value: token),
            URLQueryItem(name: "cmd", value: "get_activity")
        ])
        let (data, _) = try await session.data(from: url)
        let payload = try JSONDecoder().decode(TautulliActivityResponse.self, from: data)
        return payload.response.data.sessions.map { session in
            MediaActivity(
                kind: .nowPlaying,
                title: session.fullTitle,
                user: session.user,
                progress: session.progressPercent.map { $0 / 100.0 },
                device: session.player
            )
        }
    }

    private func fetchPlexRecentAdditions(configuration: MediaServiceConfiguration, token: String) async throws -> [MediaActivity] {
        let url = configuration.baseURL.appendingPathComponent("library/recentlyAdded").appending(queryItems: [
            URLQueryItem(name: "X-Plex-Token", value: token)
        ])
        let (data, _) = try await session.data(from: url)
        let parser = PlexRecentParser()
        return parser.parse(data: data)
    }

    private func fetchUpcomingTitles(kind: MediaActivityKind, configuration: MediaServiceConfiguration, token: String, path: String) async throws -> [MediaActivity] {
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.addValue(token, forHTTPHeaderField: "X-Api-Key")
        let (data, _) = try await session.data(for: request)
        let payload = try JSONDecoder().decode([UpcomingTitle].self, from: data)
        return payload.prefix(8).map {
            MediaActivity(kind: kind, title: $0.title, subtitle: $0.seriesTitle, startsAt: ISO8601DateFormatter().date(from: $0.airDateUtc ?? ""))
        }
    }
}

private struct TautulliActivityResponse: Decodable {
    struct Envelope: Decodable {
        struct Session: Decodable {
            let fullTitle: String
            let user: String
            let progressPercent: Double?
            let player: String?

            enum CodingKeys: String, CodingKey {
                case fullTitle = "full_title"
                case user
                case progressPercent = "progress_percent"
                case player
            }
        }

        let sessions: [Session]
    }

    struct Response: Decodable {
        let data: Envelope
    }

    let response: Response
}

private struct UpcomingTitle: Decodable {
    let title: String
    let seriesTitle: String?
    let airDateUtc: String?

    enum CodingKeys: String, CodingKey {
        case title
        case seriesTitle = "seriesTitle"
        case airDateUtc = "airDateUtc"
    }
}

private final class PlexRecentParser: NSObject, XMLParserDelegate {
    private var currentAttributes: [String: String] = [:]
    private var items: [MediaActivity] = []

    func parse(data: Data) -> [MediaActivity] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "Video" || elementName == "Directory" {
            currentAttributes = attributeDict
            let title = attributeDict["title"] ?? attributeDict["grandparentTitle"] ?? "Untitled"
            let thumb = attributeDict["thumb"].flatMap(URL.init(string:))
            items.append(
                MediaActivity(
                    kind: .newAddition,
                    title: title,
                    subtitle: attributeDict["summary"],
                    posterURL: thumb
                )
            )
        }
    }
}

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        components.queryItems = (components.queryItems ?? []) + queryItems
        return components.url ?? self
    }
}
