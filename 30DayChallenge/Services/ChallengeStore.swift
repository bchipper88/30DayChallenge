import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ChallengeStore {
    @ObservationIgnored private let repository: any PlanRepository
    @ObservationIgnored private let aiService: AIAssistantService?

    var plans: [ChallengePlan] = []
    var selectedPlanID: UUID?
    var isLoading: Bool = false
    var errorMessage: String?
    var showConfetti: Bool = false
    var celebrationMessage: String? = nil
    var streakStates: [UUID: StreakState] = [:]

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
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func select(_ plan: ChallengePlan) {
        selectedPlanID = plan.id
    }

    @discardableResult
    func createPlan(from draft: ChallengeDraft) async throws -> ChallengePlan {
        let plan: ChallengePlan
        if let aiService, !draft.prompt.isEmpty {
            do {
                plan = try await aiService.generatePlan(prompt: draft.prompt)
            } catch {
                errorMessage = Self.humanReadableAIError(from: error)
                throw error
            }
        } else {
            plan = ChallengePlanFactory.makePlan(from: draft)
        }
        do {
            try await repository.persist(plan: plan)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }

        plans.insert(plan, at: 0)
        selectedPlanID = plan.id
        streakStates[plan.id] = StreakState(current: 0, longest: 0, lastCompletedDay: nil)

        return plan
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
        if let repository = try? SupabasePlanRepository.makeFromSecrets() {
            return repository
        }
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
