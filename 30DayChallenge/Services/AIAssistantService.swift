import Foundation
import Supabase

struct AIAssistantService {
    private enum Backend {
        case supabase(SupabaseClient)
        case custom(url: URL, apiKey: String)
    }

    private struct RequestPayload: Encodable {
        var prompt: String
    }

    private struct JobStartResponse: Decodable {
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

    private struct JobStatusRequest: Encodable {
        var jobId: UUID
    }

    private struct JobStatusResponse: Decodable {
        var status: JobStatus
        var plan: ChallengePlan?
        var error: String?
    }

    private enum JobStatus: String, Decodable {
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

    func generatePlan(prompt: String) async throws -> ChallengePlan {
        switch backend {
        case .custom(let url, let apiKey):
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(RequestPayload(prompt: prompt))

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                throw ServiceError.invalidResponse
            }

            struct ResponsePayload: Decodable { var plan: ChallengePlan }
            return try JSONDecoder().decode(ResponsePayload.self, from: data).plan

        case .supabase(let client):
            let start = try await enqueueJob(client: client, prompt: prompt)
            return try await pollForCompletion(client: client, jobId: start.jobId)
        }
    }

    private func enqueueJob(client: SupabaseClient, prompt: String) async throws -> JobStartResponse {
        let payload = RequestPayload(prompt: prompt)
        return try await client.functions.invoke(
            "generate-plan",
            options: FunctionInvokeOptions(body: payload)
        )
    }

    private func pollForCompletion(client: SupabaseClient, jobId: UUID) async throws -> ChallengePlan {
        let pollInterval: UInt64 = 2 * 1_000_000_000 // 2 seconds
        let deadline = Date().addingTimeInterval(180)

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
