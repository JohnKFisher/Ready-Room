import Foundation

public struct DeterministicNewsRanker: Sendable {
    public init() {}

    public func rank(
        headlines: [NewsHeadline],
        settings: NewsSettings,
        surface: NewsSurface,
        limit: Int? = nil
    ) -> [NewsHeadline] {
        let profile = settings.effectiveProfile(for: surface)
        let feedMap = Dictionary(uniqueKeysWithValues: settings.feeds.map { ($0.id, $0) })
        let filtered = headlines.filter { headline in
            guard let feedIdentifier = headline.feedIdentifier,
                  let feed = feedMap[feedIdentifier],
                  feed.isEnabled else {
                return false
            }
            return profile.includes(feedID: feedIdentifier)
        }

        guard filtered.isEmpty == false else {
            return []
        }

        let clusters = cluster(filtered)
        let ranked = clusters.map { cluster in
            let representative = cluster.representative(profile: profile)
            let sourceNames = Array(Set(cluster.items.map(\.sourceName))).sorted()
            let clusterSizeBonus = log(Double(cluster.items.count) + 1) * 0.35
            let categoryBonus = Self.categoryBonus(for: representative.category)
            let perSurfaceBoost = cluster.items
                .compactMap(\.feedIdentifier)
                .map { profile.boost(for: $0) }
                .max() ?? 0
            let recencyBonus = Self.recencyBonus(for: cluster.latestPublishedAt)
            let score = representative.sourcePriority + clusterSizeBonus + categoryBonus + perSurfaceBoost + recencyBonus
            let explanation = String(
                format: "priority %.2f + cluster %.2f + category %.2f + surface %.2f + recency %.2f",
                representative.sourcePriority,
                clusterSizeBonus,
                categoryBonus,
                perSurfaceBoost,
                recencyBonus
            )

            return NewsHeadline(
                id: cluster.id,
                title: representative.title,
                summary: representative.summary,
                url: representative.url,
                sourceName: sourceNames.joined(separator: " + "),
                publishedAt: cluster.latestPublishedAt,
                weight: score,
                feedIdentifier: representative.feedIdentifier,
                category: representative.category,
                sourcePriority: representative.sourcePriority,
                rankingExplanation: explanation
            )
        }
        .sorted { lhs, rhs in
            if lhs.weight != rhs.weight {
                return lhs.weight > rhs.weight
            }
            return (lhs.publishedAt ?? .distantPast) > (rhs.publishedAt ?? .distantPast)
        }

        if let limit {
            return Array(ranked.prefix(limit))
        }
        return ranked
    }

    private func cluster(_ headlines: [NewsHeadline]) -> [NewsCluster] {
        let sorted = headlines.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
        var clusters: [NewsCluster] = []

        for headline in sorted {
            let titleTokens = Self.normalizedTokenSet(for: headline.title)
            if let index = clusters.firstIndex(where: { cluster in
                Self.isLikelyDuplicate(titleTokens: titleTokens, clusterTokens: cluster.tokenSet)
            }) {
                clusters[index].items.append(headline)
                clusters[index].tokenSet.formUnion(titleTokens)
            } else {
                clusters.append(
                    NewsCluster(
                        id: headline.id,
                        items: [headline],
                        tokenSet: titleTokens
                    )
                )
            }
        }

        return clusters
    }

    private static func categoryBonus(for category: NewsCategory?) -> Double {
        switch category {
        case .general:
            0.12
        case .world:
            0.14
        case .local:
            0.10
        case .business:
            0.08
        case .technology:
            0.06
        case .family:
            0.07
        case .entertainment:
            0.04
        case .sports:
            0.05
        case .none:
            0
        }
    }

    private static func recencyBonus(for publishedAt: Date?) -> Double {
        guard let publishedAt else {
            return 0.08
        }
        let ageHours = max(0, Date().timeIntervalSince(publishedAt) / 3600)
        switch ageHours {
        case ..<6:
            return 0.42
        case ..<12:
            return 0.30
        case ..<24:
            return 0.18
        case ..<48:
            return 0.08
        default:
            return 0
        }
    }

    private static func normalizedTokenSet(for title: String) -> Set<String> {
        let lowered = title.lowercased()
        let stripped = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        let words = String(stripped)
            .split(separator: " ")
            .map(String.init)
            .filter { word in
                word.count > 2 && Self.stopWords.contains(word) == false
            }
        return Set(words)
    }

    private static func isLikelyDuplicate(titleTokens: Set<String>, clusterTokens: Set<String>) -> Bool {
        guard titleTokens.isEmpty == false, clusterTokens.isEmpty == false else {
            return false
        }
        let intersection = titleTokens.intersection(clusterTokens)
        let denominator = max(titleTokens.count, clusterTokens.count)
        let overlap = Double(intersection.count) / Double(denominator)
        return overlap >= 0.72
    }

    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "from", "that", "this", "into", "over", "after",
        "amid", "about", "your", "have", "has", "had", "are", "was", "were", "will",
        "not", "but", "new"
    ]
}

private struct NewsCluster {
    let id: String
    var items: [NewsHeadline]
    var tokenSet: Set<String>

    var latestPublishedAt: Date? {
        items.compactMap(\.publishedAt).max()
    }

    func representative(profile: NewsProfile) -> NewsHeadline {
        items.max { lhs, rhs in
            let lhsBoost = lhs.feedIdentifier.map { profile.boost(for: $0) } ?? 0
            let rhsBoost = rhs.feedIdentifier.map { profile.boost(for: $0) } ?? 0
            let lhsScore = lhs.sourcePriority + lhsBoost
            let rhsScore = rhs.sourcePriority + rhsBoost
            if lhsScore != rhsScore {
                return lhsScore < rhsScore
            }
            return (lhs.publishedAt ?? .distantPast) < (rhs.publishedAt ?? .distantPast)
        } ?? items[0]
    }
}
