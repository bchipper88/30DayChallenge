import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ChallengeStore {
    @ObservationIgnored private let repository: any PlanRepository
    @ObservationIgnored private let aiService: AIAssistantService?

    var plans: [ChallengePlan] = []
    var pendingPlans: [PendingPlan] = []
    var selectedPlanID: UUID?
    var isLoading: Bool = false
    var errorMessage: String?
    var showConfetti: Bool = false
    var celebrationMessage: String? = nil
    var streakStates: [UUID: StreakState] = [:]

    struct PendingPlan: Identifiable, Equatable {
        enum Status: Equatable {
            case queued
            case generating
            case failed(String)
        }

        let id: UUID
        var prompt: String
        var createdAt: Date
        var status: Status
        var agent: PlanGenerationAgent
        var purpose: String
        var familiarity: ChallengeFamiliarity

        var promptPreview: String {
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "AI generated plan" }
            let preview = trimmed.prefix(120)
            return preview.count < trimmed.count ? "\(preview)…" : String(preview)
        }
    }

    init(repository: any PlanRepository = ChallengeStore.makeDefaultRepository()) {
        self.repository = repository
        if let configuration = try? SupabaseConfiguration.load(),
           let service = try? AIAssistantService(configuration: configuration) {
            self.aiService = service
        } else {
            self.aiService = nil
        }
        Task {
            await load()
        }
    }

    var selectedPlan: ChallengePlan? {
        guard let id = selectedPlanID else { return plans.first }
        return plans.first(where: { $0.id == id })
    }

    func load() async {
        isLoading = true
        do {
            let fetched = try await repository.fetchPlans()
            let planIDs = fetched.map(\.id)
            let taskStates = try await repository.fetchTaskStates(planIDs: planIDs)

            let mergedPlans = applyTaskStates(plans: fetched, stateMap: taskStates)
            plans = mergedPlans
            selectedPlanID = selectedPlanID ?? mergedPlans.first?.id
            for plan in mergedPlans {
                streakStates[plan.id] = StreakState(current: 3, longest: 6, lastCompletedDay: 4)
            }
            errorMessage = nil
        } catch {
            print("Failed to load plans:", error)
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func select(_ plan: ChallengePlan) {
        selectedPlanID = plan.id
    }

    @discardableResult
    func createPlan(from draft: ChallengeDraft, agent: PlanGenerationAgent) async -> Bool {
        if let aiService, !draft.prompt.isEmpty {
            do {
                let start = try await aiService.enqueuePlan(
                    prompt: draft.prompt,
                    purpose: draft.trimmedPurpose,
                    familiarity: draft.familiarity,
                    agent: agent
                )
                errorMessage = nil
                let pending = PendingPlan(
                    id: start.jobId,
                    prompt: draft.prompt,
                    createdAt: start.queuedAt ?? Date(),
                    status: .queued,
                    agent: agent,
                    purpose: draft.trimmedPurpose,
                    familiarity: draft.familiarity
                )
                pendingPlans.insert(pending, at: 0)
                Task {
                    await self.monitorJob(jobId: start.jobId)
                }
                return true
            } catch {
                errorMessage = Self.humanReadableAIError(from: error)
                return false
            }
        } else {
            let plan = ChallengePlanFactory.makePlan(from: draft)
            await persistAndStore(plan: plan)
            return true
        }
    }

    func day(for dayNumber: Int) -> DailyEntry? {
        guard let plan = selectedPlan else { return nil }
        return plan.day(for: dayNumber)
    }

    func toggleTask(planID: UUID, dayNumber: Int, taskID: UUID) {
        guard let planIndex = plans.firstIndex(where: { $0.id == planID }) else { return }
        var plan = plans[planIndex]
        guard let dayIndex = plan.days.firstIndex(where: { $0.dayNumber == dayNumber }) else { return }
        var day = plan.days[dayIndex]
        guard let taskIndex = day.tasks.firstIndex(where: { $0.id == taskID }) else { return }

        day.tasks[taskIndex].isComplete.toggle()
        let toggledState = day.tasks[taskIndex].isComplete
        plan.days[dayIndex] = day
        plans[planIndex] = plan

        Task {
            do {
                try await repository.setTaskState(planID: planID, taskID: taskID, dayNumber: dayNumber, isComplete: toggledState)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        if day.tasks.allSatisfy({ $0.isComplete }) {
            triggerCelebration(for: plan, day: day)
            updateStreak(for: plan.id, completedDay: dayNumber, incrementMinutes: totalMinutes(for: day))
        }
    }

    func resetDay(planID: UUID, dayNumber: Int) async {
        guard let planIndex = plans.firstIndex(where: { $0.id == planID }) else { return }
        do {
            let original = try await repository.reset(planID: planID)
            guard let resetDay = original.days.first(where: { $0.dayNumber == dayNumber }) else { return }
            plans[planIndex].days = plans[planIndex].days.map { current in
                current.dayNumber == dayNumber ? resetDay : current
            }

            let taskIDs = resetDay.tasks.map(\.id)
            Task {
                do {
                    try await repository.clearTaskStates(planID: planID, taskIDs: taskIDs)
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func retryPendingPlan(_ pending: PendingPlan) {
        guard let aiService else { return }
        Task {
            do {
                let start = try await aiService.enqueuePlan(
                    prompt: pending.prompt,
                    purpose: pending.purpose,
                    familiarity: pending.familiarity,
                    agent: pending.agent
                )
                await MainActor.run {
                    self.pendingPlans.removeAll { $0.id == pending.id }
                    let replacement = PendingPlan(
                        id: start.jobId,
                        prompt: pending.prompt,
                        createdAt: start.queuedAt ?? Date(),
                        status: .queued,
                        agent: pending.agent,
                        purpose: pending.purpose,
                        familiarity: pending.familiarity
                    )
                    self.pendingPlans.insert(replacement, at: 0)
                }
                await self.monitorJob(jobId: start.jobId)
            } catch {
                await MainActor.run {
                    self.updatePending(jobId: pending.id, status: .failed(Self.humanReadableAIError(from: error)))
                }
            }
        }
    }

    func dismissPendingPlan(_ pending: PendingPlan) {
        pendingPlans.removeAll { $0.id == pending.id }
    }

    func deletePlan(_ planID: UUID) async {
        do {
            try await repository.deletePlan(planID: planID)
            plans.removeAll { $0.id == planID }
            pendingPlans.removeAll { $0.id == planID }
            if selectedPlanID == planID {
                selectedPlanID = plans.first?.id
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func triggerCelebration(for plan: ChallengePlan, day: DailyEntry) {
        showConfetti = true
        celebrationMessage = FunFeedback.playfulMessage(for: plan)
        FunFeedback.playSuccessHaptics()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            showConfetti = false
        }
    }

    private func updateStreak(for planID: UUID, completedDay: Int, incrementMinutes: Int) {
        guard let plan = plans.first(where: { $0.id == planID }) else { return }
        let threshold = plan.streakRule.thresholdMinutes
        guard incrementMinutes >= threshold else { return }

        var streak = streakStates[planID] ?? StreakState(current: 0, longest: 0, lastCompletedDay: nil)

        if let last = streak.lastCompletedDay, completedDay - last <= 1 {
            streak.current += 1
        } else {
            streak.current = 1
        }
        streak.longest = max(streak.longest, streak.current)
        streak.lastCompletedDay = completedDay

        streakStates[planID] = streak
    }

    private func totalMinutes(for day: DailyEntry) -> Int {
        day.tasks.reduce(0) { $0 + $1.expectedMinutes }
    }

    private func monitorJob(jobId: UUID) async {
        guard aiService != nil else { return }
        let pollInterval: UInt64 = 2 * 1_000_000_000

        while true {
            do {
                guard let aiService else { return }
                let status = try await aiService.jobStatus(jobId: jobId)

                switch status.status {
                case .pending:
                    updatePending(jobId: jobId, status: .queued)
                case .inProgress:
                    updatePending(jobId: jobId, status: .generating)
                case .completed:
                    guard let plan = status.plan else {
                        updatePending(jobId: jobId, status: .failed("Plan data was unavailable. Please retry."))
                        return
                    }
                    guard pendingPlans.contains(where: { $0.id == jobId }) else {
                        return
                    }
                    pendingPlans.removeAll { $0.id == jobId }
                    await persistAndStore(plan: plan)
                    return
                case .failed:
                    let message = status.error ?? "Plan generation failed. Please try again."
                    updatePending(jobId: jobId, status: .failed(message))
                    return
                }
            } catch {
                updatePending(jobId: jobId, status: .failed(Self.humanReadableAIError(from: error)))
                return
            }

            try? await Task.sleep(nanoseconds: pollInterval)
        }
    }

    private func persistAndStore(plan: ChallengePlan) async {
        do {
            try await repository.persist(plan: plan)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        plans.insert(plan, at: 0)
        selectedPlanID = plan.id
        streakStates[plan.id] = StreakState(current: 0, longest: 0, lastCompletedDay: nil)
    }

    private func updatePending(jobId: UUID, status: PendingPlan.Status) {
        guard let index = pendingPlans.firstIndex(where: { $0.id == jobId }) else { return }
        pendingPlans[index].status = status
    }

    private func applyTaskStates(plans: [ChallengePlan], stateMap: [UUID: [UUID: Bool]]) -> [ChallengePlan] {
        plans.map { plan in
            guard let planStates = stateMap[plan.id] else { return plan }
            var mutablePlan = plan
            mutablePlan.days = plan.days.map { day in
                var mutableDay = day
                mutableDay.tasks = day.tasks.map { task in
                    var mutableTask = task
                    if let isComplete = planStates[task.id] {
                        mutableTask.isComplete = isComplete
                    }
                    return mutableTask
                }
                return mutableDay
            }
            return mutablePlan
        }
    }
}

private extension ChallengeStore {
    nonisolated static func makeDefaultRepository() -> any PlanRepository {
        print("Attempting Supabase repository")
        if let repository = try? SupabasePlanRepository.makeFromSecrets() {
            print("Supabase repository created")
            return repository
        }
        print("Falling back to in-memory repository")
        return InMemoryPlanRepository()
    }

    static func humanReadableAIError(from error: Error) -> String {
        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if description.isEmpty {
            return "The AI assistant had trouble generating your plan. Please try again."
        }
        return description
    }
}
