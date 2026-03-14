import Foundation
import ReadyRoomCore

public struct TemplatedNarrativeGenerator: NarrativeGenerator {
    public let mode: NarrativeGenerationMode = .templated

    public init() {}

    public func generateOpeningLine(for request: BriefingRequest) async throws -> GeneratedNarrative {
        let workCount = request.normalizedItems.filter { $0.lifeArea == .work }.count
        let familyCount = request.normalizedItems.filter { $0.lifeArea != .work }.count
        let dueSoonCount = request.dueSoon.count
        let line = "You have \(familyCount) family item(s), \(workCount) work item(s), and \(dueSoonCount) due-soon reminder(s) on deck."
        return GeneratedNarrative(text: line, preferredMode: request.preferredMode, actualMode: mode, fallbackReason: request.preferredMode == mode ? nil : "Fell back to deterministic template.")
    }

    public func generateNewsSummary(for request: BriefingRequest) async throws -> GeneratedNarrative {
        let selected = request.headlines.prefix(2).map(\.title)
        let line = selected.isEmpty ? "No news items made the cut this morning." : selected.joined(separator: " Also worth noting: ")
        return GeneratedNarrative(text: line, preferredMode: request.preferredMode, actualMode: mode, fallbackReason: request.preferredMode == mode ? nil : "Fell back to deterministic template.")
    }

    public func generateDashboardSummary(for context: DashboardSummaryContext, preferredMode: NarrativeGenerationMode) async throws -> GeneratedNarrative {
        let status = context.sourceStatuses.contains(.stale) ? "Some sources are stale." : "Sources look current."
        let line = "\(context.normalizedItems.count) items in the next week. \(context.dueSoon.count) due-soon reminders. \(status)"
        return GeneratedNarrative(text: line, preferredMode: preferredMode, actualMode: mode, fallbackReason: preferredMode == mode ? nil : "Fell back to deterministic template.")
    }
}

public struct OllamaNarrativeGenerator: NarrativeGenerator {
    public let mode: NarrativeGenerationMode = .ollama
    private let endpoint: URL
    private let session: URLSession

    public init(endpoint: URL = URL(string: "http://127.0.0.1:11434/api/generate")!, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    public func generateOpeningLine(for request: BriefingRequest) async throws -> GeneratedNarrative {
        try await generate(prompt: "Write one concise, friendly morning briefing opening sentence about this day shape: \(request.normalizedItems.map(\.title).joined(separator: ", "))", preferredMode: request.preferredMode)
    }

    public func generateNewsSummary(for request: BriefingRequest) async throws -> GeneratedNarrative {
        try await generate(prompt: "Summarize these headlines in one short paragraph: \(request.headlines.map(\.title).joined(separator: "; "))", preferredMode: request.preferredMode)
    }

    public func generateDashboardSummary(for context: DashboardSummaryContext, preferredMode: NarrativeGenerationMode) async throws -> GeneratedNarrative {
        try await generate(prompt: "Summarize this dashboard in one short sentence: \(context.normalizedItems.map(\.title).joined(separator: ", "))", preferredMode: preferredMode)
    }

    private func generate(prompt: String, preferredMode: NarrativeGenerationMode) async throws -> GeneratedNarrative {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = OllamaRequest(model: "llama3.2", prompt: prompt, stream: false)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return GeneratedNarrative(text: response.response, preferredMode: preferredMode, actualMode: mode)
    }
}

private struct OllamaRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
}

private struct OllamaResponse: Decodable {
    let response: String
}

public struct FoundationModelsNarrativeGenerator: NarrativeGenerator {
    public let mode: NarrativeGenerationMode = .foundationModels
    private let fallback = TemplatedNarrativeGenerator()

    public init() {}

    public func generateOpeningLine(for request: BriefingRequest) async throws -> GeneratedNarrative {
        try await fallback.generateOpeningLine(for: request)
    }

    public func generateNewsSummary(for request: BriefingRequest) async throws -> GeneratedNarrative {
        try await fallback.generateNewsSummary(for: request)
    }

    public func generateDashboardSummary(for context: DashboardSummaryContext, preferredMode: NarrativeGenerationMode) async throws -> GeneratedNarrative {
        try await fallback.generateDashboardSummary(for: context, preferredMode: preferredMode)
    }
}

public struct NarrativeGenerationPipeline: Sendable {
    private let preferred: NarrativeGenerator
    private let fallback: NarrativeGenerator

    public init(preferred: NarrativeGenerator, fallback: NarrativeGenerator = TemplatedNarrativeGenerator()) {
        self.preferred = preferred
        self.fallback = fallback
    }

    public func openingLine(for request: BriefingRequest) async -> GeneratedNarrative {
        do {
            return try await preferred.generateOpeningLine(for: request)
        } catch {
            return (try? await fallback.generateOpeningLine(for: request)) ?? GeneratedNarrative(
                text: "Your briefing is ready.",
                preferredMode: request.preferredMode,
                actualMode: .templated,
                fallbackReason: error.localizedDescription
            )
        }
    }

    public func newsSummary(for request: BriefingRequest) async -> GeneratedNarrative {
        do {
            return try await preferred.generateNewsSummary(for: request)
        } catch {
            return (try? await fallback.generateNewsSummary(for: request)) ?? GeneratedNarrative(
                text: "News summary unavailable.",
                preferredMode: request.preferredMode,
                actualMode: .templated,
                fallbackReason: error.localizedDescription
            )
        }
    }

    public func dashboardSummary(for context: DashboardSummaryContext, preferredMode: NarrativeGenerationMode) async -> GeneratedNarrative {
        do {
            return try await preferred.generateDashboardSummary(for: context, preferredMode: preferredMode)
        } catch {
            return (try? await fallback.generateDashboardSummary(for: context, preferredMode: preferredMode)) ?? GeneratedNarrative(
                text: "Dashboard summary unavailable.",
                preferredMode: preferredMode,
                actualMode: .templated,
                fallbackReason: error.localizedDescription
            )
        }
    }
}

