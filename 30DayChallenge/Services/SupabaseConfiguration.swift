import Foundation

struct SupabaseConfiguration {
    var url: URL
    var anonKey: String
    var fallbackUserID: UUID?
    var openAIKey: String?

    init(url: URL, anonKey: String, fallbackUserID: UUID? = nil, openAIKey: String? = nil) {
        self.url = url
        self.anonKey = anonKey
        self.fallbackUserID = fallbackUserID
        self.openAIKey = openAIKey
    }

    static func load(from bundle: Bundle = .main) throws -> SupabaseConfiguration {
        let environment = ProcessInfo.processInfo.environment
        if let envURL = environment["SUPABASE_URL"],
           let envKey = environment["SUPABASE_ANON_KEY"],
           let url = URL(string: envURL),
           !envKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let fallback = environment["SUPABASE_FALLBACK_USER_ID"].flatMap { UUID(uuidString: $0) }
            let openAIKey = environment["SUPABASE_OPENAI_KEY"] ?? environment["OPENAI_API_KEY"]
            return SupabaseConfiguration(url: url, anonKey: envKey, fallbackUserID: fallback, openAIKey: openAIKey)
        }

        guard let secretsURL = bundle.url(forResource: "Secrets", withExtension: "plist") else {
            throw SupabaseConfigurationError.missingSecretsFile
        }

        guard let data = try? Data(contentsOf: secretsURL) else {
            throw SupabaseConfigurationError.unreadableSecretsFile
        }

        let rawSecrets = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dictionary = rawSecrets as? [String: Any] else {
            throw SupabaseConfigurationError.invalidSecretsFormat
        }

        guard let urlString = dictionary[SecretsKey.supabaseURL.rawValue] as? String,
              let anonKey = dictionary[SecretsKey.supabaseAnonKey.rawValue] as? String,
              let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SupabaseConfigurationError.missingRequiredValues
        }

        let fallbackString = (dictionary[SecretsKey.supabaseFallbackUserID.rawValue] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackUserID = fallbackString.flatMap { UUID(uuidString: $0) }
        let openAIKey = (dictionary[SecretsKey.openAIKey.rawValue] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        return SupabaseConfiguration(url: url, anonKey: anonKey, fallbackUserID: fallbackUserID, openAIKey: openAIKey)
    }

    static func templateContents() -> [String: Any] {
        [
            SecretsKey.supabaseURL.rawValue: "https://YOUR-PROJECT.supabase.co",
            SecretsKey.supabaseAnonKey.rawValue: "YOUR-ANON-KEY",
            SecretsKey.supabaseServiceKey.rawValue: "(optional) SERVICE-ROLE-KEY",
            SecretsKey.openAIKey.rawValue: "(optional) OPENAI-KEY",
            SecretsKey.supabaseFallbackUserID.rawValue: "(optional) FALLBACK-USER-UUID"
        ]
    }

    enum SecretsKey: String {
        case supabaseURL = "SupabaseURL"
        case supabaseAnonKey = "SupabaseAnonKey"
        case supabaseServiceKey = "SupabaseServiceKey"
        case openAIKey = "OpenAIAPIKey"
        case supabaseFallbackUserID = "SupabaseFallbackUserID"
    }
}

enum SupabaseConfigurationError: LocalizedError {
    case missingSecretsFile
    case unreadableSecretsFile
    case invalidSecretsFormat
    case missingRequiredValues

    var errorDescription: String? {
        switch self {
        case .missingSecretsFile:
            return "Secrets.plist was not found. Add one based on Secrets.template.plist."
        case .unreadableSecretsFile:
            return "Secrets.plist exists but could not be read. Check file permissions."
        case .invalidSecretsFormat:
            return "Secrets.plist is not a valid property list."
        case .missingRequiredValues:
            return "Supabase URL and anon key are required in Secrets.plist or environment variables."
        }
    }
}
