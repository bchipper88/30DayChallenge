import Foundation
import Supabase

protocol PlanRepository {
    func fetchPlans() async throws -> [ChallengePlan]
    func persist(plan: ChallengePlan) async throws
    func reset(planID: UUID) async throws -> ChallengePlan
    func fetchTaskStates(planIDs: [UUID]) async throws -> [UUID: [UUID: Bool]]
    func setTaskState(planID: UUID, taskID: UUID, dayNumber: Int, isComplete: Bool) async throws
    func clearTaskStates(planID: UUID, taskIDs: [UUID]) async throws
}

extension PlanRepository {
    func fetchTaskStates(planIDs: [UUID]) async throws -> [UUID: [UUID: Bool]] { [:] }
    func setTaskState(planID: UUID, taskID: UUID, dayNumber: Int, isComplete: Bool) async throws {}
    func clearTaskStates(planID: UUID, taskIDs: [UUID]) async throws {}
}

struct InMemoryPlanRepository: PlanRepository {
    private var storage: [UUID: ChallengePlan] = [SampleData.plan.id: SampleData.plan]

    func fetchPlans() async throws -> [ChallengePlan] {
        Array(storage.values)
    }

    func persist(plan: ChallengePlan) async throws {
        // No-op for now. Later this will push deltas to Supabase.
        _ = plan
    }

    func reset(planID: UUID) async throws -> ChallengePlan {
        guard let plan = storage[planID] else {
            throw RepositoryError.planNotFound
        }
        return plan
    }
}

struct SupabasePlanRepository: PlanRepository {
    private let client: SupabaseClient
    private let fallbackUserID: UUID?

    private enum Table {
        static let challengePlans = "challenge_plans"
        static let taskStates = "plan_task_states"
    }

    private struct ChallengePlanRow: Codable {
        var id: UUID
        var user_id: UUID
        var payload: ChallengePlan
    }

    private struct ChallengePlanUpsert: Codable {
        var id: UUID
        var user_id: UUID
        var payload: ChallengePlan
    }

    private struct TaskStateRow: Codable {
        var plan_id: UUID
        var task_id: UUID
        var day_number: Int
        var is_complete: Bool
    }

    private struct TaskStateUpsert: Codable {
        var plan_id: UUID
        var task_id: UUID
        var day_number: Int
        var is_complete: Bool
    }

    private static func hasActiveSession(client: SupabaseClient?) -> Bool {
        guard let client else { return false }
        return client.auth.currentSession?.user.id != nil
    }

    init(client: SupabaseClient, fallbackUserID: UUID? = nil) {
        self.client = client
        self.fallbackUserID = fallbackUserID
    }

    init(configuration: SupabaseConfiguration) throws {
        let client = try SupabaseClientProvider.make(configuration: configuration)
        self.client = client
        self.fallbackUserID = configuration.fallbackUserID
    }

    init(url: URL, anonKey: String, fallbackUserID: UUID? = nil) throws {
        let configuration = SupabaseConfiguration(url: url, anonKey: anonKey, fallbackUserID: fallbackUserID)
        try self.init(configuration: configuration)
    }

    static func makeFromSecrets() throws -> SupabasePlanRepository {
        let configuration = try SupabaseConfiguration.load()
        let client = try SupabaseClientProvider.make(configuration: configuration)
        guard configuration.fallbackUserID != nil || SupabasePlanRepository.hasActiveSession(client: client) else {
            throw RepositoryError.missingUser
        }
        return SupabasePlanRepository(client: client, fallbackUserID: configuration.fallbackUserID)
    }

    private func currentUserID() throws -> UUID {
        if let sessionUser = client.auth.currentSession?.user.id {
            return sessionUser
        }
        if let fallbackUserID {
            return fallbackUserID
        }
        throw RepositoryError.missingUser
    }

    func fetchPlans() async throws -> [ChallengePlan] {
        let userID = try currentUserID()
        let response: PostgrestResponse<[ChallengePlanRow]> = try await client
            .from(Table.challengePlans)
            .select()
            .eq("user_id", value: userID)
            .execute()

        return response.value.map(\.payload)
    }

    func persist(plan: ChallengePlan) async throws {
        let userID = try currentUserID()
        let upsert = ChallengePlanUpsert(id: plan.id, user_id: userID, payload: plan)
        _ = try await client
            .from(Table.challengePlans)
            .upsert(upsert, returning: .minimal)
            .execute()
    }

    func reset(planID: UUID) async throws -> ChallengePlan {
        let userID = try currentUserID()
        let response: PostgrestResponse<ChallengePlanRow> = try await client
            .from(Table.challengePlans)
            .select()
            .eq("user_id", value: userID)
            .eq("id", value: planID)
            .single()
            .execute()

        return response.value.payload
    }

    func fetchTaskStates(planIDs: [UUID]) async throws -> [UUID: [UUID: Bool]] {
        guard !planIDs.isEmpty else { return [:] }

        let response: PostgrestResponse<[TaskStateRow]> = try await client
            .from(Table.taskStates)
            .select()
            .in("plan_id", values: planIDs)
            .execute()

        var mapping: [UUID: [UUID: Bool]] = [:]
        for row in response.value {
            mapping[row.plan_id, default: [:]][row.task_id] = row.is_complete
        }
        return mapping
    }

    func setTaskState(planID: UUID, taskID: UUID, dayNumber: Int, isComplete: Bool) async throws {
        let record = TaskStateUpsert(plan_id: planID, task_id: taskID, day_number: dayNumber, is_complete: isComplete)
        _ = try await client
            .from(Table.taskStates)
            .upsert(record, onConflict: "plan_id,task_id", returning: .minimal)
            .execute()
    }

    func clearTaskStates(planID: UUID, taskIDs: [UUID]) async throws {
        guard !taskIDs.isEmpty else { return }
        _ = try await client
            .from(Table.taskStates)
            .delete()
            .eq("plan_id", value: planID)
            .`in`("task_id", values: taskIDs)
            .execute()
    }
}

enum RepositoryError: Error {
    case planNotFound
    case notImplemented
    case missingUser
}
