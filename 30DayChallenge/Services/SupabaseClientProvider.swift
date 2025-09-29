import Foundation
import Supabase

struct SupabaseClientProvider {
    static func make(configuration: SupabaseConfiguration? = nil) throws -> SupabaseClient {
        let resolvedConfiguration: SupabaseConfiguration
        if let configuration {
            resolvedConfiguration = configuration
        } else {
            resolvedConfiguration = try SupabaseConfiguration.load()
        }

        return SupabaseClient(supabaseURL: resolvedConfiguration.url, supabaseKey: resolvedConfiguration.anonKey)
    }
}
