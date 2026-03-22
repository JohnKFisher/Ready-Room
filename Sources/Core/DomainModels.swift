import Foundation

public enum PersonID: String, Codable, CaseIterable, Sendable, Hashable {
    case john
    case amy
    case ellie
    case mia
    case family

    public var displayName: String {
        switch self {
        case .john: "John"
        case .amy: "Amy"
        case .ellie: "Ellie"
        case .mia: "Mia"
        case .family: "Family"
        }
    }

    public var briefingAudience: BriefingAudience? {
        switch self {
        case .john: .john
        case .amy: .amy
        case .ellie, .mia, .family: nil
        }
    }

    public var defaultRelevantAudiences: Set<BriefingAudience> {
        switch self {
        case .john:
            [.john]
        case .amy:
            [.amy]
        case .ellie, .mia, .family:
            Set(BriefingAudience.allCases)
        }
    }
}

public enum BriefingAudience: String, Codable, CaseIterable, Sendable, Hashable {
    case john
    case amy

    public var person: PersonID {
        switch self {
        case .john: .john
        case .amy: .amy
        }
    }

    public var displayName: String {
        person.displayName
    }
}

public enum SourceType: String, Codable, CaseIterable, Sendable {
    case calendar
    case obligation
    case weather
    case news
    case media
    case aiSummary
    case sender
    case system
}

public struct SourceDescriptor: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var displayName: String
    public var type: SourceType

    public init(id: String, displayName: String, type: SourceType) {
        self.id = id
        self.displayName = displayName
        self.type = type
    }
}

public enum SourceHealthStatus: String, Codable, CaseIterable, Sendable {
    case healthy
    case stale
    case unavailable
    case unauthorized
    case unconfigured
}

public struct SourceHealth: Codable, Sendable, Hashable {
    public var status: SourceHealthStatus
    public var message: String?
    public var lastSuccessAt: Date?
    public var freshnessBudget: TimeInterval

    public init(
        status: SourceHealthStatus = .healthy,
        message: String? = nil,
        lastSuccessAt: Date? = nil,
        freshnessBudget: TimeInterval = 3600
    ) {
        self.status = status
        self.message = message
        self.lastSuccessAt = lastSuccessAt
        self.freshnessBudget = freshnessBudget
    }

    public func resolvedStatus(at date: Date = .now) -> SourceHealthStatus {
        guard status == .healthy, let lastSuccessAt else {
            return status
        }
        let age = date.timeIntervalSince(lastSuccessAt)
        return age > freshnessBudget ? .stale : .healthy
    }
}

public struct SourceSnapshot: Codable, Sendable, Hashable {
    public var source: SourceDescriptor
    public var fetchedAt: Date
    public var lastGoodFetchAt: Date?
    public var health: SourceHealth
    public var placeholderLabel: String?
    public var calendarEvents: [RawCalendarEvent]
    public var obligations: [ObligationRecord]
    public var weather: WeatherSnapshot?
    public var headlines: [NewsHeadline]
    public var mediaItems: [MediaActivity]

    public init(
        source: SourceDescriptor,
        fetchedAt: Date = .now,
        lastGoodFetchAt: Date? = nil,
        health: SourceHealth = SourceHealth(),
        placeholderLabel: String? = nil,
        calendarEvents: [RawCalendarEvent] = [],
        obligations: [ObligationRecord] = [],
        weather: WeatherSnapshot? = nil,
        headlines: [NewsHeadline] = [],
        mediaItems: [MediaActivity] = []
    ) {
        self.source = source
        self.fetchedAt = fetchedAt
        self.lastGoodFetchAt = lastGoodFetchAt
        self.health = health
        self.placeholderLabel = placeholderLabel
        self.calendarEvents = calendarEvents
        self.obligations = obligations
        self.weather = weather
        self.headlines = headlines
        self.mediaItems = mediaItems
    }

    public var isPlaceholder: Bool {
        placeholderLabel != nil
    }
}

public enum CalendarRole: String, Codable, CaseIterable, Sendable {
    case work
    case sharedFamily
    case kidRelated
    case other
    case inactiveUnclassified
}

public enum LifeArea: String, Codable, CaseIterable, Sendable {
    case work
    case home
    case mixed
}

public enum ChangeState: String, Codable, CaseIterable, Sendable {
    case unchanged
    case new
    case changed
    case cancelled
    case enteredReminderWindow
}

public struct InclusionFlags: Codable, Sendable, Hashable {
    public var dashboard: Bool
    public var johnBriefing: Bool
    public var amyBriefing: Bool

    public init(dashboard: Bool = true, johnBriefing: Bool = true, amyBriefing: Bool = true) {
        self.dashboard = dashboard
        self.johnBriefing = johnBriefing
        self.amyBriefing = amyBriefing
    }
}

public struct DecisionTraceEntry: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var ruleID: String
    public var summary: String
    public var detail: String

    public init(id: UUID = UUID(), ruleID: String, summary: String, detail: String) {
        self.id = id
        self.ruleID = ruleID
        self.summary = summary
        self.detail = detail
    }
}

public enum NarrativeGenerationMode: String, Codable, CaseIterable, Sendable {
    case foundationModels
    case ollama
    case templated
}

public struct DecisionTrace: Codable, Sendable, Hashable {
    public var sourceFacts: [String]
    public var appliedRules: [DecisionTraceEntry]
    public var overrides: [DecisionTraceEntry]
    public var preferredGenerationMode: NarrativeGenerationMode?
    public var actualGenerationMode: NarrativeGenerationMode?
    public var fallbackReason: String?

    public init(
        sourceFacts: [String] = [],
        appliedRules: [DecisionTraceEntry] = [],
        overrides: [DecisionTraceEntry] = [],
        preferredGenerationMode: NarrativeGenerationMode? = nil,
        actualGenerationMode: NarrativeGenerationMode? = nil,
        fallbackReason: String? = nil
    ) {
        self.sourceFacts = sourceFacts
        self.appliedRules = appliedRules
        self.overrides = overrides
        self.preferredGenerationMode = preferredGenerationMode
        self.actualGenerationMode = actualGenerationMode
        self.fallbackReason = fallbackReason
    }
}

public struct CalendarConfiguration: Codable, Sendable, Hashable, Identifiable {
    public var id: String { calendarIdentifier }
    public var calendarIdentifier: String
    public var displayName: String
    public var role: CalendarRole?
    public var owner: PersonID?
    public var includeOnDashboard: Bool
    public var includeInJohnBriefing: Bool
    public var includeInAmyBriefing: Bool
    public var colorHex: String?
    public var keywordOwnerOverrides: [String: PersonID]

    public init(
        calendarIdentifier: String,
        displayName: String,
        role: CalendarRole? = nil,
        owner: PersonID? = nil,
        includeOnDashboard: Bool = true,
        includeInJohnBriefing: Bool = true,
        includeInAmyBriefing: Bool = true,
        colorHex: String? = nil,
        keywordOwnerOverrides: [String: PersonID] = [:]
    ) {
        self.calendarIdentifier = calendarIdentifier
        self.displayName = displayName
        self.role = role
        self.owner = owner
        self.includeOnDashboard = includeOnDashboard
        self.includeInJohnBriefing = includeInJohnBriefing
        self.includeInAmyBriefing = includeInAmyBriefing
        self.colorHex = colorHex
        self.keywordOwnerOverrides = keywordOwnerOverrides
    }

    public var defaultRelevantAudiences: Set<BriefingAudience> {
        var audiences: Set<BriefingAudience> = []
        if includeInJohnBriefing {
            audiences.insert(.john)
        }
        if includeInAmyBriefing {
            audiences.insert(.amy)
        }
        return audiences
    }
}

public struct RawCalendarEvent: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var calendarIdentifier: String
    public var calendarTitle: String
    public var title: String
    public var notes: String?
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var location: String?
    public var sourceOwnerHint: PersonID?
    public var isCancelled: Bool

    public init(
        id: String,
        calendarIdentifier: String,
        calendarTitle: String,
        title: String,
        notes: String? = nil,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        sourceOwnerHint: PersonID? = nil,
        isCancelled: Bool = false
    ) {
        self.id = id
        self.calendarIdentifier = calendarIdentifier
        self.calendarTitle = calendarTitle
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.sourceOwnerHint = sourceOwnerHint
        self.isCancelled = isCancelled
    }
}

public enum ObligationScheduleKind: String, Codable, CaseIterable, Sendable {
    case oneTime
    case weekly
    case monthly
    case yearly
    case custom
}

public struct ObligationSchedule: Codable, Sendable, Hashable {
    public var kind: ObligationScheduleKind
    public var dueDate: Date?
    public var interval: Int
    public var weekdays: [Int]
    public var dayOfMonth: Int?
    public var monthOfYear: Int?
    public var customRule: String?

    public init(
        kind: ObligationScheduleKind,
        dueDate: Date? = nil,
        interval: Int = 1,
        weekdays: [Int] = [],
        dayOfMonth: Int? = nil,
        monthOfYear: Int? = nil,
        customRule: String? = nil
    ) {
        self.kind = kind
        self.dueDate = dueDate
        self.interval = max(1, interval)
        self.weekdays = weekdays
        self.dayOfMonth = dayOfMonth
        self.monthOfYear = monthOfYear
        self.customRule = customRule
    }
}

public struct ObligationRecord: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var notes: String?
    public var owner: PersonID?
    public var schedule: ObligationSchedule
    public var reminderLeadDays: [Int]
    public var originalEntry: String?
    public var explanation: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        notes: String? = nil,
        owner: PersonID? = nil,
        schedule: ObligationSchedule,
        reminderLeadDays: [Int] = [7, 3],
        originalEntry: String? = nil,
        explanation: String? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.owner = owner
        self.schedule = schedule
        self.reminderLeadDays = reminderLeadDays.sorted(by: >)
        self.originalEntry = originalEntry
        self.explanation = explanation
    }
}

public struct ParsedObligationCandidate: Codable, Sendable, Hashable {
    public var originalText: String
    public var structured: ObligationRecord?
    public var explanation: String
    public var missingFields: [String]
    public var confidence: Double

    public init(
        originalText: String,
        structured: ObligationRecord?,
        explanation: String,
        missingFields: [String] = [],
        confidence: Double
    ) {
        self.originalText = originalText
        self.structured = structured
        self.explanation = explanation
        self.missingFields = missingFields
        self.confidence = confidence
    }
}

public struct WeatherSnapshot: Codable, Sendable, Hashable {
    public var summary: String
    public var symbolName: String?
    public var currentTemperatureF: Double
    public var highF: Double
    public var lowF: Double
    public var fetchedAt: Date

    public init(
        summary: String,
        symbolName: String? = nil,
        currentTemperatureF: Double,
        highF: Double,
        lowF: Double,
        fetchedAt: Date = .now
    ) {
        self.summary = summary
        self.symbolName = symbolName
        self.currentTemperatureF = currentTemperatureF
        self.highF = highF
        self.lowF = lowF
        self.fetchedAt = fetchedAt
    }
}

public struct WeatherSettings: Codable, Sendable, Hashable {
    public var locationQuery: String
    public var resolvedDisplayName: String?
    public var latitude: Double?
    public var longitude: Double?
    public var lastResolvedAt: Date?

    public init(
        locationQuery: String = "08854",
        resolvedDisplayName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        lastResolvedAt: Date? = nil
    ) {
        self.locationQuery = locationQuery
        self.resolvedDisplayName = resolvedDisplayName
        self.latitude = latitude
        self.longitude = longitude
        self.lastResolvedAt = lastResolvedAt
    }

    public var trimmedLocationQuery: String {
        locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var hasResolvedCoordinates: Bool {
        latitude != nil && longitude != nil
    }
}

public enum NewsSurface: String, Codable, CaseIterable, Sendable, Hashable {
    case dashboard
    case john
    case amy

    public var displayName: String {
        switch self {
        case .dashboard:
            "Dashboard"
        case .john:
            "John"
        case .amy:
            "Amy"
        }
    }
}

public enum NewsCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case general
    case world
    case local
    case business
    case technology
    case family
    case entertainment
    case sports

    public var displayName: String {
        rawValue.capitalized
    }
}

public struct ConfiguredNewsFeed: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var label: String
    public var feedURLString: String
    public var category: NewsCategory
    public var sourcePriority: Double
    public var isEnabled: Bool
    public var isUserAdded: Bool

    public init(
        id: String = UUID().uuidString,
        label: String,
        feedURLString: String,
        category: NewsCategory,
        sourcePriority: Double = 1.0,
        isEnabled: Bool = true,
        isUserAdded: Bool = false
    ) {
        self.id = id
        self.label = label
        self.feedURLString = feedURLString
        self.category = category
        self.sourcePriority = sourcePriority
        self.isEnabled = isEnabled
        self.isUserAdded = isUserAdded
    }

    public var trimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var trimmedFeedURLString: String {
        feedURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var resolvedURL: URL? {
        guard let url = URL(string: trimmedFeedURLString),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }
        return url
    }
}

public struct NewsProfile: Codable, Sendable, Hashable {
    public var includedFeedIDs: [String]
    public var feedBoosts: [String: Double]

    public init(includedFeedIDs: [String] = [], feedBoosts: [String: Double] = [:]) {
        self.includedFeedIDs = includedFeedIDs
        self.feedBoosts = feedBoosts
    }

    public static func `default`(for feeds: [ConfiguredNewsFeed]) -> NewsProfile {
        NewsProfile(includedFeedIDs: feeds.filter(\.isEnabled).map(\.id).sorted())
    }

    public func normalized(
        availableFeeds: [ConfiguredNewsFeed],
        includeNewFeedsByDefault: Bool
    ) -> NewsProfile {
        let availableIDs = Set(availableFeeds.map(\.id))
        var normalizedIDs = includedFeedIDs.filter { availableIDs.contains($0) }
        if includeNewFeedsByDefault {
            let enabledIDs = availableFeeds.filter(\.isEnabled).map(\.id)
            for id in enabledIDs where normalizedIDs.contains(id) == false {
                normalizedIDs.append(id)
            }
        }

        let normalizedBoosts = feedBoosts
            .filter { availableIDs.contains($0.key) && $0.value.isFinite && $0.value != 0 }

        return NewsProfile(
            includedFeedIDs: normalizedIDs.sorted(),
            feedBoosts: normalizedBoosts
        )
    }

    public func includes(feedID: String) -> Bool {
        includedFeedIDs.contains(feedID)
    }

    public func boost(for feedID: String) -> Double {
        feedBoosts[feedID] ?? 0
    }
}

public struct NewsSettings: Codable, Sendable, Hashable {
    public var feeds: [ConfiguredNewsFeed]
    public var baseProfile: NewsProfile
    public var dashboardOverride: NewsProfile?
    public var johnOverride: NewsProfile?
    public var amyOverride: NewsProfile?

    public init(
        feeds: [ConfiguredNewsFeed] = NewsSettings.starterFeeds,
        baseProfile: NewsProfile? = nil,
        dashboardOverride: NewsProfile? = nil,
        johnOverride: NewsProfile? = nil,
        amyOverride: NewsProfile? = nil
    ) {
        let normalizedFeeds = feeds
        self.feeds = normalizedFeeds
        let shouldAutoIncludeNewFeeds = baseProfile == nil
        self.baseProfile = (baseProfile ?? NewsProfile.default(for: normalizedFeeds))
            .normalized(availableFeeds: normalizedFeeds, includeNewFeedsByDefault: shouldAutoIncludeNewFeeds)
        self.dashboardOverride = dashboardOverride?.normalized(availableFeeds: normalizedFeeds, includeNewFeedsByDefault: false)
        self.johnOverride = johnOverride?.normalized(availableFeeds: normalizedFeeds, includeNewFeedsByDefault: false)
        self.amyOverride = amyOverride?.normalized(availableFeeds: normalizedFeeds, includeNewFeedsByDefault: false)
    }

    public static let starterFeeds: [ConfiguredNewsFeed] = [
        ConfiguredNewsFeed(
            id: "bbc-top-stories",
            label: "BBC Top Stories",
            feedURLString: "https://feeds.bbci.co.uk/news/rss.xml",
            category: .general,
            sourcePriority: 1.2
        ),
        ConfiguredNewsFeed(
            id: "guardian-world",
            label: "The Guardian World",
            feedURLString: "https://www.theguardian.com/world/rss",
            category: .world,
            sourcePriority: 1.1
        ),
        ConfiguredNewsFeed(
            id: "guardian-us",
            label: "The Guardian US",
            feedURLString: "https://www.theguardian.com/us-news/rss",
            category: .general,
            sourcePriority: 1.0
        ),
        ConfiguredNewsFeed(
            id: "bbc-business",
            label: "BBC Business",
            feedURLString: "https://feeds.bbci.co.uk/news/business/rss.xml",
            category: .business,
            sourcePriority: 0.95
        )
    ]

    public func normalized() -> NewsSettings {
        NewsSettings(
            feeds: feeds,
            baseProfile: baseProfile,
            dashboardOverride: dashboardOverride,
            johnOverride: johnOverride,
            amyOverride: amyOverride
        )
    }

    public func effectiveProfile(for surface: NewsSurface) -> NewsProfile {
        switch surface {
        case .dashboard:
            dashboardOverride?.normalized(availableFeeds: feeds, includeNewFeedsByDefault: false)
            ?? baseProfile.normalized(availableFeeds: feeds, includeNewFeedsByDefault: false)
        case .john:
            johnOverride?.normalized(availableFeeds: feeds, includeNewFeedsByDefault: false)
            ?? baseProfile.normalized(availableFeeds: feeds, includeNewFeedsByDefault: false)
        case .amy:
            amyOverride?.normalized(availableFeeds: feeds, includeNewFeedsByDefault: false)
            ?? baseProfile.normalized(availableFeeds: feeds, includeNewFeedsByDefault: false)
        }
    }

    public func applyingBaseToAllSurfaces() -> NewsSettings {
        NewsSettings(feeds: feeds, baseProfile: baseProfile, dashboardOverride: nil, johnOverride: nil, amyOverride: nil)
    }

    public var hasAnyEnabledFeed: Bool {
        feeds.contains(where: \.isEnabled)
    }
}

public struct LastGoodNewsSnapshot: Codable, Sendable, Hashable {
    public var headlines: [NewsHeadline]
    public var fetchedAt: Date

    public init(headlines: [NewsHeadline], fetchedAt: Date = .now) {
        self.headlines = headlines
        self.fetchedAt = fetchedAt
    }
}

public struct NewsHeadline: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var summary: String?
    public var url: URL?
    public var sourceName: String
    public var publishedAt: Date?
    public var weight: Double
    public var feedIdentifier: String?
    public var category: NewsCategory?
    public var sourcePriority: Double
    public var rankingExplanation: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        summary: String? = nil,
        url: URL? = nil,
        sourceName: String,
        publishedAt: Date? = nil,
        weight: Double = 1.0,
        feedIdentifier: String? = nil,
        category: NewsCategory? = nil,
        sourcePriority: Double = 1.0,
        rankingExplanation: String? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.url = url
        self.sourceName = sourceName
        self.publishedAt = publishedAt
        self.weight = weight
        self.feedIdentifier = feedIdentifier
        self.category = category
        self.sourcePriority = sourcePriority
        self.rankingExplanation = rankingExplanation
    }
}

public enum MediaActivityKind: String, Codable, CaseIterable, Sendable {
    case nowPlaying
    case newAddition
    case airingSoon
}

public struct MediaActivity: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var kind: MediaActivityKind
    public var title: String
    public var subtitle: String?
    public var user: String?
    public var progress: Double?
    public var device: String?
    public var posterURL: URL?
    public var startsAt: Date?

    public init(
        id: String = UUID().uuidString,
        kind: MediaActivityKind,
        title: String,
        subtitle: String? = nil,
        user: String? = nil,
        progress: Double? = nil,
        device: String? = nil,
        posterURL: URL? = nil,
        startsAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.user = user
        self.progress = progress
        self.device = device
        self.posterURL = posterURL
        self.startsAt = startsAt
    }
}

public enum WorkLocation: String, Codable, CaseIterable, Sendable {
    case home
    case office
    case travel
    case unknown
}

public struct WorkLocationRule: Codable, Sendable, Hashable, Identifiable {
    public var id: String {
        "\(person.rawValue)-\(weekdays.sorted().map(String.init).joined(separator: "-"))-\(location.rawValue)"
    }
    public var person: PersonID
    public var weekdays: Set<Int>
    public var location: WorkLocation

    public init(person: PersonID, weekdays: Set<Int>, location: WorkLocation) {
        self.person = person
        self.weekdays = weekdays
        self.location = location
    }
}

public struct ReadyRoomRulesConfiguration: Codable, Sendable, Hashable {
    public var workLocationRules: [WorkLocationRule]

    public init(workLocationRules: [WorkLocationRule] = [
        WorkLocationRule(person: .john, weekdays: [3, 5], location: .home)
    ]) {
        self.workLocationRules = workLocationRules
    }
}

public struct NormalizedItem: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var source: SourceDescriptor
    public var sourceIdentifier: String
    public var sourceType: SourceType
    public var title: String
    public var notes: String?
    public var startDate: Date?
    public var endDate: Date?
    public var isAllDay: Bool
    public var location: String?
    public var owner: PersonID
    public var relevantAudiences: Set<BriefingAudience>
    public var calendarRole: CalendarRole?
    public var lifeArea: LifeArea
    public var confidence: Double
    public var inclusion: InclusionFlags
    public var changeState: ChangeState
    public var sourceHealth: SourceHealthStatus
    public var trace: DecisionTrace
    public var metadata: [String: String]

    public init(
        id: String,
        source: SourceDescriptor,
        sourceIdentifier: String,
        sourceType: SourceType,
        title: String,
        notes: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        location: String? = nil,
        owner: PersonID = .family,
        relevantAudiences: Set<BriefingAudience>? = nil,
        calendarRole: CalendarRole? = nil,
        lifeArea: LifeArea = .home,
        confidence: Double = 1.0,
        inclusion: InclusionFlags = InclusionFlags(),
        changeState: ChangeState = .unchanged,
        sourceHealth: SourceHealthStatus = .healthy,
        trace: DecisionTrace = DecisionTrace(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.source = source
        self.sourceIdentifier = sourceIdentifier
        self.sourceType = sourceType
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.owner = owner
        self.relevantAudiences = relevantAudiences ?? owner.defaultRelevantAudiences
        self.calendarRole = calendarRole
        self.lifeArea = lifeArea
        self.confidence = confidence
        self.inclusion = inclusion
        self.changeState = changeState
        self.sourceHealth = sourceHealth
        self.trace = trace
        self.metadata = metadata
    }

    public var displayLocation: String? {
        MeetingLocationDisplayFormatter.displayText(for: location)
    }

    public var relevantAudiencePeople: Set<PersonID> {
        Set(relevantAudiences.map(\.person))
    }

    public var relevantAudienceDisplayNames: [String] {
        BriefingAudience.allCases
            .filter { relevantAudiences.contains($0) }
            .map(\.displayName)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case sourceIdentifier
        case sourceType
        case title
        case notes
        case startDate
        case endDate
        case isAllDay
        case location
        case owner
        case relevantAudiences
        case relevantPeople
        case calendarRole
        case lifeArea
        case confidence
        case inclusion
        case changeState
        case sourceHealth
        case trace
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        source = try container.decode(SourceDescriptor.self, forKey: .source)
        sourceIdentifier = try container.decode(String.self, forKey: .sourceIdentifier)
        sourceType = try container.decode(SourceType.self, forKey: .sourceType)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        isAllDay = try container.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? false
        location = try container.decodeIfPresent(String.self, forKey: .location)
        owner = try container.decodeIfPresent(PersonID.self, forKey: .owner) ?? .family
        if let decodedAudiences = try container.decodeIfPresent(Set<BriefingAudience>.self, forKey: .relevantAudiences) {
            relevantAudiences = decodedAudiences
        } else {
            let legacyRelevantPeople = try container.decodeIfPresent(Set<PersonID>.self, forKey: .relevantPeople) ?? []
            relevantAudiences = Self.legacyRelevantAudiences(from: legacyRelevantPeople, owner: owner)
        }
        calendarRole = try container.decodeIfPresent(CalendarRole.self, forKey: .calendarRole)
        lifeArea = try container.decodeIfPresent(LifeArea.self, forKey: .lifeArea) ?? .home
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 1.0
        inclusion = try container.decodeIfPresent(InclusionFlags.self, forKey: .inclusion) ?? InclusionFlags()
        changeState = try container.decodeIfPresent(ChangeState.self, forKey: .changeState) ?? .unchanged
        sourceHealth = try container.decodeIfPresent(SourceHealthStatus.self, forKey: .sourceHealth) ?? .healthy
        trace = try container.decodeIfPresent(DecisionTrace.self, forKey: .trace) ?? DecisionTrace()
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
        try container.encode(sourceIdentifier, forKey: .sourceIdentifier)
        try container.encode(sourceType, forKey: .sourceType)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(isAllDay, forKey: .isAllDay)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(owner, forKey: .owner)
        try container.encode(relevantAudiences, forKey: .relevantAudiences)
        try container.encodeIfPresent(calendarRole, forKey: .calendarRole)
        try container.encode(lifeArea, forKey: .lifeArea)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(inclusion, forKey: .inclusion)
        try container.encode(changeState, forKey: .changeState)
        try container.encode(sourceHealth, forKey: .sourceHealth)
        try container.encode(trace, forKey: .trace)
        try container.encode(metadata, forKey: .metadata)
    }

    private static func legacyRelevantAudiences(from people: Set<PersonID>, owner: PersonID) -> Set<BriefingAudience> {
        var audiences: Set<BriefingAudience> = []
        if people.contains(.john) {
            audiences.insert(.john)
        }
        if people.contains(.amy) {
            audiences.insert(.amy)
        }
        if people.contains(.family) || people.contains(.ellie) || people.contains(.mia) {
            audiences.formUnion(BriefingAudience.allCases)
        }
        return audiences.isEmpty ? owner.defaultRelevantAudiences : audiences
    }
}

public enum MeetingLocationDisplayFormatter {
    public static func displayText(for location: String?) -> String? {
        guard let location else {
            return nil
        }

        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        let lowered = trimmed.lowercased()
        if isZoomMeetingLink(lowered) {
            return "Zoom Meeting"
        }
        if isTeamsMeetingLink(lowered) {
            return "Teams Meeting"
        }
        return trimmed
    }

    private static func isZoomMeetingLink(_ lowered: String) -> Bool {
        lowered.contains("zoom.us/") ||
        lowered.contains("zoom.com/") ||
        lowered.contains("zoomgov.com/")
    }

    private static func isTeamsMeetingLink(_ lowered: String) -> Bool {
        lowered.contains("teams.microsoft.") ||
        lowered.contains("teams.live.com/")
    }
}

public struct ConflictMarker: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var itemIDs: [String]
    public var title: String

    public init(itemIDs: [String], title: String) {
        self.id = itemIDs.sorted().joined(separator: "|")
        self.itemIDs = itemIDs
        self.title = title
    }
}

public struct DashboardCardLayout: Codable, Sendable, Hashable {
    public var cardOrder: [DashboardCardKind]

    public init(cardOrder: [DashboardCardKind] = DashboardCardKind.allCases) {
        self.cardOrder = cardOrder
    }
}

public enum DashboardCardKind: String, Codable, CaseIterable, Sendable {
    case dueSoon
    case weather
    case news
    case media
}

public struct QuietHoursSettings: Codable, Sendable, Hashable {
    public var startHour: Int
    public var endHour: Int

    public init(startHour: Int = 23, endHour: Int = 6) {
        self.startHour = startHour
        self.endHour = endHour
    }

    public func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        if startHour <= endHour {
            return hour >= startHour && hour < endHour
        }
        return hour >= startHour || hour < endHour
    }
}

public struct SetupProgress: Codable, Sendable, Hashable {
    public var completedSections: Set<String>
    public var skippedSections: Set<String>

    public init(completedSections: Set<String> = [], skippedSections: Set<String> = []) {
        self.completedSections = completedSections
        self.skippedSections = skippedSections
    }

    public var isComplete: Bool {
        let required = Set(["Calendars", "Sender", "Dashboard"])
        return required.isSubset(of: completedSections)
    }
}

public struct BriefingSection: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var body: String
    public var items: [NormalizedItem]

    public init(id: String, title: String, body: String, items: [NormalizedItem]) {
        self.id = id
        self.title = title
        self.body = body
        self.items = items
    }
}

public struct BriefingRequest: Codable, Sendable, Hashable {
    public var audience: BriefingAudience
    public var date: Date
    public var normalizedItems: [NormalizedItem]
    public var weather: WeatherSnapshot?
    public var headlines: [NewsHeadline]
    public var mediaItems: [MediaActivity]
    public var dueSoon: [NormalizedItem]
    public var preferredMode: NarrativeGenerationMode
    public var personColorPalette: PersonColorPaletteSettings
    public var calendarPlaceholderLabel: String?
    public var weatherPlaceholderLabel: String?
    public var newsPlaceholderLabel: String?
    public var mediaPlaceholderLabel: String?

    public init(
        audience: BriefingAudience,
        date: Date = .now,
        normalizedItems: [NormalizedItem],
        weather: WeatherSnapshot?,
        headlines: [NewsHeadline],
        mediaItems: [MediaActivity],
        dueSoon: [NormalizedItem],
        preferredMode: NarrativeGenerationMode,
        personColorPalette: PersonColorPaletteSettings = .default,
        calendarPlaceholderLabel: String? = nil,
        weatherPlaceholderLabel: String? = nil,
        newsPlaceholderLabel: String? = nil,
        mediaPlaceholderLabel: String? = nil
    ) {
        self.audience = audience
        self.date = date
        self.normalizedItems = normalizedItems
        self.weather = weather
        self.headlines = headlines
        self.mediaItems = mediaItems
        self.dueSoon = dueSoon
        self.preferredMode = preferredMode
        self.personColorPalette = personColorPalette
        self.calendarPlaceholderLabel = calendarPlaceholderLabel
        self.weatherPlaceholderLabel = weatherPlaceholderLabel
        self.newsPlaceholderLabel = newsPlaceholderLabel
        self.mediaPlaceholderLabel = mediaPlaceholderLabel
    }
}

public struct BriefingArtifact: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var audience: BriefingAudience
    public var subject: String
    public var recipients: [String]
    public var bodyHTML: String
    public var sections: [BriefingSection]
    public var generatedAt: Date
    public var preferredMode: NarrativeGenerationMode
    public var actualMode: NarrativeGenerationMode
    public var sourceSnapshotSummary: [String]
    public var trace: DecisionTrace

    public init(
        id: UUID = UUID(),
        audience: BriefingAudience,
        subject: String,
        recipients: [String],
        bodyHTML: String,
        sections: [BriefingSection],
        generatedAt: Date = .now,
        preferredMode: NarrativeGenerationMode,
        actualMode: NarrativeGenerationMode,
        sourceSnapshotSummary: [String],
        trace: DecisionTrace
    ) {
        self.id = id
        self.audience = audience
        self.subject = subject
        self.recipients = recipients
        self.bodyHTML = bodyHTML
        self.sections = sections
        self.generatedAt = generatedAt
        self.preferredMode = preferredMode
        self.actualMode = actualMode
        self.sourceSnapshotSummary = sourceSnapshotSummary
        self.trace = trace
    }
}

public struct DashboardSummaryContext: Codable, Sendable, Hashable {
    public var normalizedItems: [NormalizedItem]
    public var weather: WeatherSnapshot?
    public var dueSoon: [NormalizedItem]
    public var sourceStatuses: [SourceHealthStatus]

    public init(normalizedItems: [NormalizedItem], weather: WeatherSnapshot?, dueSoon: [NormalizedItem], sourceStatuses: [SourceHealthStatus]) {
        self.normalizedItems = normalizedItems
        self.weather = weather
        self.dueSoon = dueSoon
        self.sourceStatuses = sourceStatuses
    }
}

public struct GeneratedNarrative: Codable, Sendable, Hashable {
    public var text: String
    public var preferredMode: NarrativeGenerationMode
    public var actualMode: NarrativeGenerationMode
    public var fallbackReason: String?

    public init(text: String, preferredMode: NarrativeGenerationMode, actualMode: NarrativeGenerationMode, fallbackReason: String? = nil) {
        self.text = text
        self.preferredMode = preferredMode
        self.actualMode = actualMode
        self.fallbackReason = fallbackReason
    }
}

public enum SendMode: String, Codable, CaseIterable, Sendable {
    case scheduled
    case manualTest
    case previewOnly
}

public enum SendStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case sent
    case failed
    case skippedDuplicate
}

public enum SenderTransport: String, Codable, CaseIterable, Sendable {
    case smtp
    case appleMail = "apple-mail"

    public var displayName: String {
        switch self {
        case .smtp:
            return "SMTP"
        case .appleMail:
            return "Apple Mail"
        }
    }
}

public enum SMTPSecurity: String, Codable, CaseIterable, Sendable {
    case implicitTLS
    case startTLS
    case plain

    public var displayName: String {
        switch self {
        case .implicitTLS:
            return "Implicit TLS"
        case .startTLS:
            return "STARTTLS"
        case .plain:
            return "Plain"
        }
    }
}

public enum SMTPAuthenticationMethod: String, Codable, CaseIterable, Sendable {
    case automatic
    case plain
    case login

    public var displayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .plain:
            return "PLAIN"
        case .login:
            return "LOGIN"
        }
    }
}

public struct SMTPSenderConfiguration: Codable, Sendable, Hashable {
    public var isEnabled: Bool
    public var host: String
    public var port: Int
    public var security: SMTPSecurity
    public var username: String
    public var fromAddress: String
    public var fromDisplayName: String
    public var authentication: SMTPAuthenticationMethod
    public var connectionTimeoutSeconds: Int

    public init(
        isEnabled: Bool = false,
        host: String = "",
        port: Int = 465,
        security: SMTPSecurity = .implicitTLS,
        username: String = "",
        fromAddress: String = "",
        fromDisplayName: String = "",
        authentication: SMTPAuthenticationMethod = .automatic,
        connectionTimeoutSeconds: Int = 20
    ) {
        self.isEnabled = isEnabled
        self.host = host
        self.port = port
        self.security = security
        self.username = username
        self.fromAddress = fromAddress
        self.fromDisplayName = fromDisplayName
        self.authentication = authentication
        self.connectionTimeoutSeconds = connectionTimeoutSeconds
    }

    public var isConfigured: Bool {
        isEnabled &&
        host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        fromAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    public var passwordAccountKey: String {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedFromAddress = fromAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "smtp-password:\(normalizedHost):\(normalizedUsername):\(normalizedFromAddress)"
    }
}

public struct SendExecutionRecord: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var briefingDate: Date
    public var audience: BriefingAudience
    public var machineIdentifier: String
    public var senderID: String
    public var sendMode: SendMode?
    public var status: SendStatus
    public var preferredMode: NarrativeGenerationMode
    public var actualMode: NarrativeGenerationMode
    public var createdAt: Date
    public var completedAt: Date?
    public var dedupeKey: String
    public var errorDescription: String?
    public var requestedSenderID: String?
    public var requestedSenderDisplayName: String?
    public var actualSenderDisplayName: String?
    public var fallbackDescription: String?

    public init(
        id: UUID = UUID(),
        briefingDate: Date,
        audience: BriefingAudience,
        machineIdentifier: String,
        senderID: String,
        sendMode: SendMode? = nil,
        status: SendStatus,
        preferredMode: NarrativeGenerationMode,
        actualMode: NarrativeGenerationMode,
        createdAt: Date = .now,
        completedAt: Date? = nil,
        dedupeKey: String,
        errorDescription: String? = nil,
        requestedSenderID: String? = nil,
        requestedSenderDisplayName: String? = nil,
        actualSenderDisplayName: String? = nil,
        fallbackDescription: String? = nil
    ) {
        self.id = id
        self.briefingDate = briefingDate
        self.audience = audience
        self.machineIdentifier = machineIdentifier
        self.senderID = senderID
        self.sendMode = sendMode
        self.status = status
        self.preferredMode = preferredMode
        self.actualMode = actualMode
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.dedupeKey = dedupeKey
        self.errorDescription = errorDescription
        self.requestedSenderID = requestedSenderID
        self.requestedSenderDisplayName = requestedSenderDisplayName
        self.actualSenderDisplayName = actualSenderDisplayName
        self.fallbackDescription = fallbackDescription
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case briefingDate
        case audience
        case machineIdentifier
        case senderID
        case sendMode
        case status
        case preferredMode
        case actualMode
        case createdAt
        case completedAt
        case dedupeKey
        case errorDescription
        case requestedSenderID
        case requestedSenderDisplayName
        case actualSenderDisplayName
        case fallbackDescription
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        briefingDate = try container.decode(Date.self, forKey: .briefingDate)
        audience = try container.decode(BriefingAudience.self, forKey: .audience)
        machineIdentifier = try container.decode(String.self, forKey: .machineIdentifier)
        senderID = try container.decode(String.self, forKey: .senderID)
        sendMode = try container.decodeIfPresent(SendMode.self, forKey: .sendMode)
        status = try container.decode(SendStatus.self, forKey: .status)
        preferredMode = try container.decode(NarrativeGenerationMode.self, forKey: .preferredMode)
        actualMode = try container.decode(NarrativeGenerationMode.self, forKey: .actualMode)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        dedupeKey = try container.decode(String.self, forKey: .dedupeKey)
        errorDescription = try container.decodeIfPresent(String.self, forKey: .errorDescription)
        requestedSenderID = try container.decodeIfPresent(String.self, forKey: .requestedSenderID)
        requestedSenderDisplayName = try container.decodeIfPresent(String.self, forKey: .requestedSenderDisplayName)
        actualSenderDisplayName = try container.decodeIfPresent(String.self, forKey: .actualSenderDisplayName)
        fallbackDescription = try container.decodeIfPresent(String.self, forKey: .fallbackDescription)
    }
}

public struct PrimarySenderConfiguration: Codable, Sendable, Hashable {
    public var machineIdentifier: String
    public var scheduledSendHour: Int
    public var scheduledSendMinute: Int
    public var catchUpDeadlineHour: Int

    public init(machineIdentifier: String, scheduledSendHour: Int = 6, scheduledSendMinute: Int = 30, catchUpDeadlineHour: Int = 12) {
        self.machineIdentifier = machineIdentifier
        self.scheduledSendHour = scheduledSendHour
        self.scheduledSendMinute = scheduledSendMinute
        self.catchUpDeadlineHour = catchUpDeadlineHour
    }
}

public struct SenderSettings: Codable, Sendable, Hashable {
    public var primary: PrimarySenderConfiguration
    public var johnRecipients: [String]
    public var amyRecipients: [String]
    public var preferredTransport: SenderTransport
    public var allowAppleMailFallback: Bool
    public var smtp: SMTPSenderConfiguration

    public init(
        primary: PrimarySenderConfiguration = PrimarySenderConfiguration(machineIdentifier: ""),
        johnRecipients: [String] = [],
        amyRecipients: [String] = [],
        preferredTransport: SenderTransport = .smtp,
        allowAppleMailFallback: Bool = true,
        smtp: SMTPSenderConfiguration = SMTPSenderConfiguration()
    ) {
        self.primary = primary
        self.johnRecipients = johnRecipients
        self.amyRecipients = amyRecipients
        self.preferredTransport = preferredTransport
        self.allowAppleMailFallback = allowAppleMailFallback
        self.smtp = smtp
    }

    private enum CodingKeys: String, CodingKey {
        case primary
        case johnRecipients
        case amyRecipients
        case preferredTransport
        case allowAppleMailFallback
        case smtp
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        primary = try container.decodeIfPresent(PrimarySenderConfiguration.self, forKey: .primary) ?? PrimarySenderConfiguration(machineIdentifier: "")
        johnRecipients = try container.decodeIfPresent([String].self, forKey: .johnRecipients) ?? []
        amyRecipients = try container.decodeIfPresent([String].self, forKey: .amyRecipients) ?? []
        preferredTransport = try container.decodeIfPresent(SenderTransport.self, forKey: .preferredTransport) ?? .smtp
        allowAppleMailFallback = try container.decodeIfPresent(Bool.self, forKey: .allowAppleMailFallback) ?? true
        smtp = try container.decodeIfPresent(SMTPSenderConfiguration.self, forKey: .smtp) ?? SMTPSenderConfiguration()
    }

    public func recipients(for audience: BriefingAudience) -> [String] {
        switch audience {
        case .john:
            johnRecipients
        case .amy:
            amyRecipients
        }
    }
}

public protocol SourceConnector: Sendable {
    var source: SourceDescriptor { get }
    func refresh() async throws -> SourceSnapshot
}

public protocol NarrativeGenerator: Sendable {
    var mode: NarrativeGenerationMode { get }
    func generateOpeningLine(for request: BriefingRequest) async throws -> GeneratedNarrative
    func generateNewsSummary(for request: BriefingRequest) async throws -> GeneratedNarrative
    func generateDashboardSummary(for context: DashboardSummaryContext, preferredMode: NarrativeGenerationMode) async throws -> GeneratedNarrative
}

public struct SendExecutionResult: Codable, Sendable, Hashable {
    public var record: SendExecutionRecord
    public var messageID: String?

    public init(record: SendExecutionRecord, messageID: String? = nil) {
        self.record = record
        self.messageID = messageID
    }
}

public protocol SenderAdapter: Sendable {
    var id: String { get }
    var displayName: String { get }
    func send(artifact: BriefingArtifact, mode: SendMode, machineIdentifier: String) async throws -> SendExecutionResult
}
