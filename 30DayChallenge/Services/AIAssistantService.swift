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

    private struct ResponsePayload: Decodable {
        var plan: ChallengePlan
    }

    private enum ServiceError: LocalizedError {
        case missingEndpoint
        case missingAPIKey
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .missingEndpoint:
                return "AI assistant endpoint not configured."
            case .missingAPIKey:
                return "AI assistant API key missing."
            case .invalidResponse:
                return "AI assistant returned an invalid response."
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

            return try JSONDecoder().decode(ResponsePayload.self, from: data).plan

        case .supabase(let client):
            let payload = RequestPayload(prompt: prompt)
            let response: ResponsePayload = try await client.functions.invoke(
                "generate-plan",
                options: FunctionInvokeOptions(body: payload)
            )
            return response.plan
        }
    }
}
