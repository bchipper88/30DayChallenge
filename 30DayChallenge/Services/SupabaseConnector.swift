import Foundation

struct SupabaseConnector {
    var configuration: SupabaseConfiguration
    var session: URLSession = .shared

    init(configuration: SupabaseConfiguration) {
        self.configuration = configuration
    }

    func testConnection() async throws {
        let healthURL = configuration.url.appendingPathComponent("rest/v1/")
        var request = URLRequest(url: healthURL)
        request.httpMethod = "GET"
        request.addValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.addValue(configuration.anonKey, forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseConnectorError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw SupabaseConnectorError.unauthorized
        default:
            throw SupabaseConnectorError.unexpectedStatus(httpResponse.statusCode)
        }
    }
}

enum SupabaseConnectorError: LocalizedError {
    case unauthorized
    case invalidResponse
    case unexpectedStatus(Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Supabase rejected the credentials. Double-check the anon key."
        case .invalidResponse:
            return "Unexpected response from Supabase."
        case .unexpectedStatus(let code):
            return "Supabase returned status code \(code)."
        }
    }
}
