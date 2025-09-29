import SwiftUI

struct SettingsView: View {
    var plan: ChallengePlan
    @State private var notificationsEnabled: Bool = true
    @State private var supabaseURL: String = ""
    @State private var supabaseKey: String = ""
    @State private var connectionState: SupabaseConnectionState = .idle
    @State private var isTestingConnection: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications") {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Daily reminders", systemImage: "alarm")
                    }
                    .toggleStyle(.switch)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        Task {
                            if enabled {
                                await NotificationScheduler.shared.requestAuthorization()
                                await NotificationScheduler.shared.scheduleDailyReminder(for: plan.reminderRule, identifier: plan.id.uuidString)
                            }
                        }
                    }
                }

                Section("Supabase") {
                    TextField("Project URL", text: $supabaseURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                    SecureField("Anon key", text: $supabaseKey)
                        .textContentType(.password)
                    Button {
                        Task { await testSupabaseConnection() }
                    }
                    label: {
                        if isTestingConnection {
                            ProgressView()
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .disabled(isTestingConnection)
                    if case .failure(let message) = connectionState {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    if connectionState == .success {
                        Label("Connected", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.footnote.weight(.semibold))
                    }
                }

                Section("Data") {
                    Button(role: .destructive) {
                        // Future: reset
                    } label: {
                        Label("Reset Local Data", systemImage: "trash")
                    }
                    Button {
                        // Future: export JSON
                    } label: {
                        Label("Export Plan JSON", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        // Future: import JSON
                    } label: {
                        Label("Import Plan JSON", systemImage: "square.and.arrow.down")
                    }
                }

                Section("About") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("30DayChallenge v0.1")
                            .font(.headline)
                        Text("Mock data, SwiftUI magic, Supabase-ready architecture.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .task {
                await loadSupabaseDefaults()
            }
        }
    }

    private func loadSupabaseDefaults() async {
        do {
            let configuration = try SupabaseConfiguration.load()
            await MainActor.run {
                supabaseURL = configuration.url.absoluteString
                supabaseKey = configuration.anonKey
            }
        } catch {
            // No stored secrets yet. Leave fields empty.
        }
    }

    private func testSupabaseConnection() async {
        guard !isTestingConnection else { return }
        isTestingConnection = true
        connectionState = .idle
        defer { isTestingConnection = false }

        do {
            let configuration = try buildSupabaseConfiguration()
            let connector = SupabaseConnector(configuration: configuration)
            try await connector.testConnection()
            connectionState = .success
        } catch {
            connectionState = .failure(error.localizedDescription)
        }
    }

    private func buildSupabaseConfiguration() throws -> SupabaseConfiguration {
        let trimmedURL = supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = supabaseKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: trimmedURL), !trimmedKey.isEmpty {
            return SupabaseConfiguration(url: url, anonKey: trimmedKey)
        }

        return try SupabaseConfiguration.load()
    }
}

enum SupabaseConnectionState: Equatable {
    case idle
    case success
    case failure(String)
}
