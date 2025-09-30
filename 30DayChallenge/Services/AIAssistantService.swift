import Foundation
import Supabase

enum PlanGenerationAgent: String, CaseIterable, Identifiable, Codable {
    case spark
    case mentor
    case oracle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spark: return "Spark"
        case .mentor: return "Mentor"
        case .oracle: return "Oracle"
        }
    }

    var descriptor: String {
        switch self {
        case .spark: return "Fastest"
        case .mentor: return "Balanced"
        case .oracle: return "Thorough"
        }
    }

    var modelIdentifier: String {
        switch self {
        case .spark: return "gpt-5-mini"
        case .mentor: return "gpt-4o"
        case .oracle: return "gpt-5"
        }
    }

    var imageName: String {
        switch self {
        case .spark: return "AgentSpark"
        case .mentor: return "AgentMentor"
        case .oracle: return "AgentOracle"
        }
    }
}

struct AIAssistantService {
    private enum Backend {
        case supabase(SupabaseClient)
        case custom(url: URL, apiKey: String)
    }

    private struct RequestPayload: Encodable {
        var prompt: String
        var purpose: String?
        var familiarity: String?
        var agent: String?
        var model: String?
    }

    struct JobStartResponse: Decodable {
        var jobId: UUID
        var status: JobStatus
        var queuedAt: Date?

        enum CodingKeys: String, CodingKey {
            case jobId
            case status
            case queuedAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            jobId = try container.decode(UUID.self, forKey: .jobId)
            status = try container.decode(JobStatus.self, forKey: .status)
            if let queuedString = try container.decodeIfPresent(String.self, forKey: .queuedAt) {
                queuedAt = ISO8601DateFormatter().date(from: queuedString)
            } else {
                queuedAt = nil
            }
        }
    }

    struct JobStatusRequest: Encodable {
        var jobId: UUID
    }

    struct JobStatusResponse: Decodable {
        var status: JobStatus
        var plan: ChallengePlan?
        var error: String?
    }

    enum JobStatus: String, Decodable {
        case pending
        case inProgress = "in_progress"
        case completed
        case failed
    }

    private enum ServiceError: LocalizedError {
        case missingEndpoint
        case missingAPIKey
        case invalidResponse
        case generationFailed(String)
        case timedOut

        var errorDescription: String? {
            switch self {
            case .missingEndpoint:
                return "AI assistant endpoint not configured."
            case .missingAPIKey:
                return "AI assistant API key missing."
            case .invalidResponse:
                return "AI assistant returned an invalid response."
            case .generationFailed(let message):
                return message
            case .timedOut:
                return "The AI assistant took too long to respond. Please try again."
            }
        }
    }

    private let backend: Backend

    init(configuration: SupabaseConfiguration) throws {
        let environment = ProcessInfo.processInfo.environment

        if let urlString = environment["AI_ASSISTANT_URL"],
           let url = URL(string: urlString),
           let apiKey = environment["AI_ASSISTANT_KEY"] ?? environment["OPENAI_API_KEY"] ?? configuration.openAIKey,
           !apiKey.isEmpty {
            backend = .custom(url: url, apiKey: apiKey)
        } else {
            let client = try SupabaseClientProvider.make(configuration: configuration)
            backend = .supabase(client)
        }
    }

    func generatePlan(
        prompt: String,
        purpose: String = "",
        familiarity: ChallengeFamiliarity = .beginner,
        agent: PlanGenerationAgent = .mentor
    ) async throws -> ChallengePlan {
        switch backend {
        case .custom(let url, let apiKey):
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(
                RequestPayload(
                    prompt: prompt,
                    purpose: purpose,
                    familiarity: familiarity.rawValue,
                    agent: agent.rawValue,
                    model: agent.modelIdentifier
                )
            )

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                throw ServiceError.invalidResponse
            }

            struct ResponsePayload: Decodable { var plan: ChallengePlan }
            return try JSONDecoder().decode(ResponsePayload.self, from: data).plan

        case .supabase(let client):
            let start = try await enqueueJob(
                client: client,
                prompt: prompt,
                purpose: purpose,
                familiarity: familiarity,
                agent: agent
            )
            return try await pollForCompletion(client: client, jobId: start.jobId)
        }
    }

    func enqueuePlan(
        prompt: String,
        purpose: String,
        familiarity: ChallengeFamiliarity,
        agent: PlanGenerationAgent
    ) async throws -> JobStartResponse {
        guard case .supabase(let client) = backend else {
            throw ServiceError.missingEndpoint
        }
        return try await enqueueJob(
            client: client,
            prompt: prompt,
            purpose: purpose,
            familiarity: familiarity,
            agent: agent
        )
    }

    func jobStatus(jobId: UUID) async throws -> JobStatusResponse {
        guard case .supabase(let client) = backend else {
            throw ServiceError.missingEndpoint
        }
        return try await client.functions.invoke(
            "plan-status",
            options: FunctionInvokeOptions(body: JobStatusRequest(jobId: jobId))
        )
    }

    func awaitPlanCompletion(jobId: UUID, timeout: TimeInterval = 180) async throws -> ChallengePlan {
        guard case .supabase(let client) = backend else {
            throw ServiceError.missingEndpoint
        }
        return try await pollForCompletion(client: client, jobId: jobId, timeout: timeout)
    }

    private func enqueueJob(
        client: SupabaseClient,
        prompt: String,
        purpose: String,
        familiarity: ChallengeFamiliarity,
        agent: PlanGenerationAgent
    ) async throws -> JobStartResponse {
        let payload = RequestPayload(
            prompt: prompt,
            purpose: purpose,
            familiarity: familiarity.rawValue,
            agent: agent.rawValue,
            model: agent.modelIdentifier
        )
        return try await client.functions.invoke(
            "generate-plan",
            options: FunctionInvokeOptions(body: payload)
        )
    }

    private func pollForCompletion(client: SupabaseClient, jobId: UUID, timeout: TimeInterval = 180) async throws -> ChallengePlan {
        let pollInterval: UInt64 = 2 * 1_000_000_000 // 2 seconds
        let deadline = Date().addingTimeInterval(timeout)

        while true {
            try Task.checkCancellation()

            let statusResponse: JobStatusResponse = try await client.functions.invoke(
                "plan-status",
                options: FunctionInvokeOptions(body: JobStatusRequest(jobId: jobId))
            )

            switch statusResponse.status {
            case .pending, .inProgress:
                if Date() > deadline {
                    throw ServiceError.timedOut
                }
                try await Task.sleep(nanoseconds: pollInterval)
            case .completed:
                if let plan = statusResponse.plan {
                    return plan
                }
                throw ServiceError.invalidResponse
            case .failed:
                throw ServiceError.generationFailed(statusResponse.error ?? "Plan generation failed. Please try again.")
            }
        }
    }
}
