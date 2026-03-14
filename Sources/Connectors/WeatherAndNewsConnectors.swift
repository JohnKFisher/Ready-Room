import Foundation
import ReadyRoomCore

public struct OpenMeteoConfiguration: Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public actor OpenMeteoWeatherConnector: SourceConnector {
    public let source = SourceDescriptor(id: "open-meteo", displayName: "Weather", type: .weather)
    private let configuration: OpenMeteoConfiguration
    private let session: URLSession

    public init(configuration: OpenMeteoConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func refresh() async throws -> SourceSnapshot {
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(configuration.latitude)&longitude=\(configuration.longitude)&current=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&temperature_unit=fahrenheit&timezone=auto")!
        let (data, _) = try await session.data(from: url)
        let payload = try JSONDecoder().decode(OpenMeteoPayload.self, from: data)
        let weather = WeatherSnapshot(
            summary: payload.current.summary,
            currentTemperatureF: payload.current.temperature2M,
            highF: payload.daily.temperature2MMax.first ?? payload.current.temperature2M,
            lowF: payload.daily.temperature2MMin.first ?? payload.current.temperature2M
        )
        return SourceSnapshot(
            source: source,
            fetchedAt: .now,
            lastGoodFetchAt: .now,
            health: SourceHealth(status: .healthy, lastSuccessAt: .now, freshnessBudget: 3600),
            weather: weather
        )
    }
}

private struct OpenMeteoPayload: Decodable {
    struct Current: Decodable {
        let temperature2M: Double
        let weatherCode: Int

        enum CodingKeys: String, CodingKey {
            case temperature2M = "temperature_2m"
            case weatherCode = "weather_code"
        }

        var summary: String {
            switch weatherCode {
            case 0: "Clear"
            case 1...3: "Partly cloudy"
            case 45, 48: "Foggy"
            case 51...67: "Rainy"
            case 71...77: "Snow"
            case 80...99: "Stormy"
            default: "Variable"
            }
        }
    }

    struct Daily: Decodable {
        let temperature2MMax: [Double]
        let temperature2MMin: [Double]

        enum CodingKeys: String, CodingKey {
            case temperature2MMax = "temperature_2m_max"
            case temperature2MMin = "temperature_2m_min"
        }
    }

    let current: Current
    let daily: Daily
}

public actor RSSNewsConnector: SourceConnector {
    public let source = SourceDescriptor(id: "rss", displayName: "News", type: .news)
    private let feedURLs: [URL]
    private let session: URLSession

    public init(feedURLs: [URL], session: URLSession = .shared) {
        self.feedURLs = feedURLs
        self.session = session
    }

    public func refresh() async throws -> SourceSnapshot {
        var headlines: [NewsHeadline] = []
        for url in feedURLs {
            let (data, _) = try await session.data(from: url)
            let parser = RSSFeedParser(sourceName: url.host ?? "Feed")
            headlines.append(contentsOf: parser.parse(data: data))
        }
        return SourceSnapshot(
            source: source,
            fetchedAt: .now,
            lastGoodFetchAt: .now,
            health: SourceHealth(status: .healthy, lastSuccessAt: .now, freshnessBudget: 7200),
            headlines: headlines.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
        )
    }
}

private final class RSSFeedParser: NSObject, XMLParserDelegate {
    private let sourceName: String
    private var headlines: [NewsHeadline] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentSummary = ""
    private var currentLink = ""
    private var currentDate = ""
    private var insideItem = false

    init(sourceName: String) {
        self.sourceName = sourceName
    }

    func parse(data: Data) -> [NewsHeadline] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return headlines
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "item" || elementName == "entry" {
            insideItem = true
            currentTitle = ""
            currentSummary = ""
            currentLink = attributeDict["href"] ?? ""
            currentDate = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }
        switch currentElement {
        case "title":
            currentTitle += string
        case "description", "summary", "content":
            currentSummary += string
        case "link":
            currentLink += string
        case "pubDate", "updated", "published":
            currentDate += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard insideItem else { return }
        if elementName == "item" || elementName == "entry" {
            let trimmedTitle = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTitle.isEmpty {
                headlines.append(
                    NewsHeadline(
                        title: trimmedTitle,
                        summary: currentSummary.trimmingCharacters(in: .whitespacesAndNewlines),
                        url: URL(string: currentLink.trimmingCharacters(in: .whitespacesAndNewlines)),
                        sourceName: sourceName,
                        publishedAt: Self.date(from: currentDate)
                    )
                )
            }
            insideItem = false
        }
    }

    private static func date(from value: String) -> Date? {
        let formatters = [
            ISO8601DateFormatter(),
            {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
                return formatter
            }()
        ]

        for formatter in formatters {
            if let formatter = formatter as? ISO8601DateFormatter, let date = formatter.date(from: value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return date
            }
            if let formatter = formatter as? DateFormatter, let date = formatter.date(from: value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return date
            }
        }
        return nil
    }
}

