import Foundation
import MapKit
import ReadyRoomCore

public struct OpenMeteoConfiguration: Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct ResolvedWeatherLocation: Sendable, Hashable {
    public var displayName: String
    public var latitude: Double
    public var longitude: Double

    public init(displayName: String, latitude: Double, longitude: Double) {
        self.displayName = displayName
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct AppleLocationSearchResolver: Sendable {
    public init() {}

    public func resolve(_ query: String) async throws -> ResolvedWeatherLocation {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else {
            throw NSError(
                domain: "ReadyRoomWeatherLocation",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Enter a ZIP code or city/state to resolve weather."]
            )
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = Self.normalizedQuery(for: trimmedQuery)
        request.resultTypes = .address

        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first(where: { CLLocationCoordinate2DIsValid($0.placemark.coordinate) }) else {
            throw NSError(
                domain: "ReadyRoomWeatherLocation",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No location matched \"\(trimmedQuery)\"."]
            )
        }

        let coordinate = item.placemark.coordinate
        return ResolvedWeatherLocation(
            displayName: Self.displayName(for: item.placemark, fallback: trimmedQuery),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    private static func normalizedQuery(for query: String) -> String {
        if query.range(of: #"^\d{5}$"#, options: .regularExpression) != nil {
            return "\(query), USA"
        }
        return query
    }

    private static func displayName(for placemark: MKPlacemark, fallback: String) -> String {
        let locality = placemark.locality ?? placemark.subAdministrativeArea
        let region = placemark.administrativeArea
        let country = placemark.countryCode
        let core: [String] = [locality, region].compactMap { value in
            guard let value, value.isEmpty == false else {
                return nil
            }
            return value
        }
        if core.isEmpty == false {
            if let country, country != "US" {
                return (core + [country]).joined(separator: ", ")
            }
            return core.joined(separator: ", ")
        }
        return placemark.title ?? placemark.name ?? fallback
    }
}

public enum WeatherSourceSnapshotFactory {
    public static let source = SourceDescriptor(id: "open-meteo", displayName: "Weather", type: .weather)

    public static func unconfigured(message: String, fetchedAt: Date = .now) -> SourceSnapshot {
        SourceSnapshot(
            source: source,
            fetchedAt: fetchedAt,
            health: SourceHealth(status: .unconfigured, message: message, freshnessBudget: 3600)
        )
    }

    public static func unavailable(message: String, fetchedAt: Date = .now) -> SourceSnapshot {
        SourceSnapshot(
            source: source,
            fetchedAt: fetchedAt,
            health: SourceHealth(status: .unavailable, message: message, freshnessBudget: 3600)
        )
    }
}

public enum NewsSourceSnapshotFactory {
    public static let source = SourceDescriptor(id: "rss", displayName: "News", type: .news)

    public static func unconfigured(message: String, fetchedAt: Date = .now) -> SourceSnapshot {
        SourceSnapshot(
            source: source,
            fetchedAt: fetchedAt,
            health: SourceHealth(status: .unconfigured, message: message, freshnessBudget: 7200)
        )
    }

    public static func unavailable(message: String, fetchedAt: Date = .now) -> SourceSnapshot {
        SourceSnapshot(
            source: source,
            fetchedAt: fetchedAt,
            health: SourceHealth(status: .unavailable, message: message, freshnessBudget: 7200)
        )
    }

    public static func stale(
        headlines: [NewsHeadline],
        message: String,
        fetchedAt: Date = .now,
        lastGoodFetchAt: Date?
    ) -> SourceSnapshot {
        SourceSnapshot(
            source: source,
            fetchedAt: fetchedAt,
            lastGoodFetchAt: lastGoodFetchAt,
            health: SourceHealth(status: .stale, message: message, lastSuccessAt: lastGoodFetchAt, freshnessBudget: 7200),
            headlines: headlines
        )
    }
}

public enum OpenMeteoWeatherCodeMapper {
    public static func summary(for weatherCode: Int) -> String {
        switch weatherCode {
        case 0:
            "Clear"
        case 1:
            "Mostly clear"
        case 2:
            "Partly cloudy"
        case 3:
            "Overcast"
        case 45, 48:
            "Foggy"
        case 51...57:
            "Drizzle"
        case 61...67, 80...82:
            "Rainy"
        case 71...77, 85, 86:
            "Snow"
        case 95...99:
            "Stormy"
        default:
            "Variable"
        }
    }

    public static func symbolName(for weatherCode: Int) -> String {
        switch weatherCode {
        case 0:
            "sun.max.fill"
        case 1:
            "sun.max.fill"
        case 2:
            "cloud.sun.fill"
        case 3:
            "cloud.fill"
        case 45, 48:
            "cloud.fog.fill"
        case 51...57:
            "cloud.drizzle.fill"
        case 61...67, 80...82:
            "cloud.rain.fill"
        case 71...77, 85, 86:
            "cloud.snow.fill"
        case 95...99:
            "cloud.bolt.rain.fill"
        default:
            "cloud.fill"
        }
    }
}

public actor OpenMeteoWeatherConnector: SourceConnector {
    public let source = WeatherSourceSnapshotFactory.source
    private let configuration: OpenMeteoConfiguration
    private let session: URLSession

    public init(configuration: OpenMeteoConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func refresh() async throws -> SourceSnapshot {
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(configuration.latitude)&longitude=\(configuration.longitude)&current=temperature_2m,weather_code,wind_speed_10m,precipitation_probability&hourly=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=auto&forecast_days=3")!
        let (data, _) = try await session.data(from: url)
        let payload = try JSONDecoder().decode(OpenMeteoPayload.self, from: data)
        let forecastPeriods = OpenMeteoForecastBuilder.forecastPeriods(from: payload, now: .now)
        let weather = WeatherSnapshot(
            summary: payload.current.summary,
            symbolName: payload.current.symbolName,
            currentTemperatureF: payload.current.temperature2M,
            highF: payload.daily.temperature2MMax.first ?? payload.current.temperature2M,
            lowF: payload.daily.temperature2MMin.first ?? payload.current.temperature2M
            ,
            precipitationChancePercent: payload.daily.precipitationProbabilityMax.first ?? payload.current.precipitationProbability,
            windSpeedMPH: payload.current.windSpeed10M ?? payload.daily.windSpeed10MMax.first,
            forecastPeriods: forecastPeriods
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
        let time: String
        let temperature2M: Double
        let weatherCode: Int
        let windSpeed10M: Double?
        let precipitationProbability: Double?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2M = "temperature_2m"
            case weatherCode = "weather_code"
            case windSpeed10M = "wind_speed_10m"
            case precipitationProbability = "precipitation_probability"
        }

        var summary: String {
            OpenMeteoWeatherCodeMapper.summary(for: weatherCode)
        }

        var symbolName: String {
            OpenMeteoWeatherCodeMapper.symbolName(for: weatherCode)
        }
    }

    struct Daily: Decodable {
        let time: [String]
        let weatherCode: [Int]
        let temperature2MMax: [Double]
        let temperature2MMin: [Double]
        let precipitationProbabilityMax: [Double]
        let windSpeed10MMax: [Double]

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case temperature2MMax = "temperature_2m_max"
            case temperature2MMin = "temperature_2m_min"
            case precipitationProbabilityMax = "precipitation_probability_max"
            case windSpeed10MMax = "wind_speed_10m_max"
        }
    }

    struct Hourly: Decodable {
        let time: [String]
        let temperature2M: [Double]
        let weatherCode: [Int]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2M = "temperature_2m"
            case weatherCode = "weather_code"
        }
    }

    let current: Current
    let hourly: Hourly
    let daily: Daily
}

private enum OpenMeteoForecastBuilder {
    private struct HourlySample {
        let date: Date
        let temperatureF: Double
        let weatherCode: Int
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }()

    static func forecastPeriods(from payload: OpenMeteoPayload, now: Date) -> [WeatherForecastPeriod] {
        let calendar = Calendar.readyRoomGregorian
        var periods: [WeatherForecastPeriod] = []

        if let today = dailyPeriod(label: "Today", index: 0, payload: payload) {
            periods.append(today)
        }

        if let tonight = tonightPeriod(from: payload, now: now, calendar: calendar) {
            periods.append(tonight)
        }

        if let tomorrow = dailyPeriod(label: "Tomorrow", index: 1, payload: payload) {
            periods.append(tomorrow)
        }

        return periods
    }

    private static func dailyPeriod(label: String, index: Int, payload: OpenMeteoPayload) -> WeatherForecastPeriod? {
        guard payload.daily.temperature2MMax.indices.contains(index),
              payload.daily.temperature2MMin.indices.contains(index),
              payload.daily.weatherCode.indices.contains(index) else {
            return nil
        }

        let weatherCode = payload.daily.weatherCode[index]
        return WeatherForecastPeriod(
            id: label.lowercased(),
            label: label,
            summary: OpenMeteoWeatherCodeMapper.summary(for: weatherCode),
            symbolName: OpenMeteoWeatherCodeMapper.symbolName(for: weatherCode),
            highF: payload.daily.temperature2MMax[index],
            lowF: payload.daily.temperature2MMin[index]
        )
    }

    private static func tonightPeriod(from payload: OpenMeteoPayload, now: Date, calendar: Calendar) -> WeatherForecastPeriod? {
        let samples = zip(payload.hourly.time.indices, payload.hourly.time).compactMap { index, value -> HourlySample? in
            guard payload.hourly.temperature2M.indices.contains(index),
                  payload.hourly.weatherCode.indices.contains(index),
                  let date = dateFormatter.date(from: value) else {
                return nil
            }

            return HourlySample(
                date: date,
                temperatureF: payload.hourly.temperature2M[index],
                weatherCode: payload.hourly.weatherCode[index]
            )
        }

        guard samples.isEmpty == false else {
            return nil
        }

        let currentHour = calendar.component(.hour, from: now)
        let startOfToday = now.startOfDay(in: calendar)
        let todayAtSixPM = calendar.date(byAdding: .hour, value: 18, to: startOfToday) ?? now
        let tomorrowAtSixAM = calendar.date(byAdding: .hour, value: 30, to: startOfToday) ?? todayAtSixPM.addingTimeInterval(12 * 3600)
        let tomorrowAtSixPM = calendar.date(byAdding: .hour, value: 42, to: startOfToday) ?? tomorrowAtSixAM.addingTimeInterval(12 * 3600)

        let tonightStartBase: Date
        let tonightEnd: Date
        if currentHour >= 18 {
            tonightStartBase = now
            tonightEnd = tomorrowAtSixAM
        } else if currentHour < 6 {
            tonightStartBase = todayAtSixPM
            tonightEnd = tomorrowAtSixAM
        } else {
            tonightStartBase = todayAtSixPM
            tonightEnd = tomorrowAtSixAM
        }
        let tonightSamples = samples.filter { $0.date >= tonightStartBase && $0.date < tonightEnd }

        let fallbackSamples = samples.filter { $0.date >= todayAtSixPM && $0.date < tomorrowAtSixPM }
        let effectiveSamples = tonightSamples.isEmpty ? fallbackSamples : tonightSamples

        guard let representative = effectiveSamples.first ?? samples.first else {
            return nil
        }

        let temperatureRangeSamples = effectiveSamples.isEmpty ? [representative] : effectiveSamples
        let highF = temperatureRangeSamples.map(\.temperatureF).max()
        let lowF = temperatureRangeSamples.map(\.temperatureF).min()
        return WeatherForecastPeriod(
            id: "tonight",
            label: "Tonight",
            summary: OpenMeteoWeatherCodeMapper.summary(for: representative.weatherCode),
            symbolName: OpenMeteoWeatherCodeMapper.symbolName(for: representative.weatherCode),
            highF: highF,
            lowF: lowF
        )
    }
}

public actor RSSNewsConnector: SourceConnector {
    public let source = NewsSourceSnapshotFactory.source
    private let feeds: [ConfiguredNewsFeed]
    private let session: URLSession

    public init(feeds: [ConfiguredNewsFeed], session: URLSession = .shared) {
        self.feeds = feeds
        self.session = session
    }

    public func refresh() async throws -> SourceSnapshot {
        let enabledFeeds = feeds.filter(\.isEnabled)
        guard enabledFeeds.isEmpty == false else {
            throw RSSNewsConnectorError.noEnabledFeeds
        }
        let session = self.session

        var headlines: [NewsHeadline] = []
        var failedFeeds: [String] = []

        await withTaskGroup(of: RSSFeedRefreshResult.self) { group in
            for feed in enabledFeeds {
                group.addTask {
                    guard let url = feed.resolvedURL else {
                        return RSSFeedRefreshResult(feedLabel: feed.label, headlines: [], errorMessage: "invalid URL")
                    }
                    do {
                        let (data, _) = try await session.data(from: url)
                        let parser = RSSFeedParser(sourceName: feed.label)
                        let parsedHeadlines = parser.parse(data: data).map { headline in
                            NewsHeadline(
                                title: headline.title,
                                summary: headline.summary,
                                url: headline.url,
                                sourceName: feed.label,
                                publishedAt: headline.publishedAt,
                                weight: headline.weight,
                                feedIdentifier: feed.id,
                                category: feed.category,
                                storyLane: feed.storyLane,
                                sourcePriority: feed.sourcePriority
                            )
                        }
                        return RSSFeedRefreshResult(feedLabel: feed.label, headlines: parsedHeadlines, errorMessage: nil)
                    } catch {
                        return RSSFeedRefreshResult(feedLabel: feed.label, headlines: [], errorMessage: error.localizedDescription)
                    }
                }
            }

            for await result in group {
                if let errorMessage = result.errorMessage {
                    failedFeeds.append("\(result.feedLabel): \(errorMessage)")
                }
                headlines.append(contentsOf: result.headlines)
            }
        }

        guard headlines.isEmpty == false else {
            if failedFeeds.isEmpty {
                throw RSSNewsConnectorError.noHeadlines
            }
            throw RSSNewsConnectorError.fetchFailed(failedFeeds.joined(separator: " "))
        }

        let healthMessage: String?
        if failedFeeds.isEmpty {
            healthMessage = nil
        } else {
            healthMessage = "Fetched \(headlines.count) headline(s). Some feeds failed: \(failedFeeds.joined(separator: " | "))"
        }

        return SourceSnapshot(
            source: source,
            fetchedAt: .now,
            lastGoodFetchAt: .now,
            health: SourceHealth(status: .healthy, message: healthMessage, lastSuccessAt: .now, freshnessBudget: 7200),
            headlines: headlines.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
        )
    }
}

private struct RSSFeedRefreshResult {
    let feedLabel: String
    let headlines: [NewsHeadline]
    let errorMessage: String?
}

private enum RSSNewsConnectorError: LocalizedError {
    case noEnabledFeeds
    case noHeadlines
    case fetchFailed(String)

    var errorDescription: String? {
        switch self {
        case .noEnabledFeeds:
            "No enabled RSS or Atom feeds are configured."
        case .noHeadlines:
            "Configured feeds returned no headlines."
        case .fetchFailed(let detail):
            "News feeds could not be fetched. \(detail)"
        }
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
        case "description", "summary", "content", "content:encoded":
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
