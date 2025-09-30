import SwiftUI

struct TaskOverviewView: View {
    @Environment(ChallengeStore.self) private var store
    @State private var expandedPlans: Set<UUID> = []

    private var plans: [ChallengePlan] { store.plans }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    assignedProjects
                    ForEach(plans) { plan in
                        TaskSummaryCard(
                            plan: plan,
                            isExpanded: Binding(
                                get: { expandedPlans.contains(plan.id) },
                                set: { newValue in
                                    if newValue {
                                        expandedPlans.insert(plan.id)
                                    } else {
                                        expandedPlans.remove(plan.id)
                                    }
                                }
                            )
                        )
                    }
                    if plans.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("My Tasks")
        }
    }

    private var assignedProjects: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Assigned Projects")
                    .font(.title3.bold())
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text("\(plans.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(plans) { plan in
                        ProjectAssignmentCard(plan: plan)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.largeTitle)
                .foregroundStyle(Palette.accentBlue)
            Text("No active projects")
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)
            Text("Kick off a challenge to see your daily tasks roll in here.")
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .softCard(padding: 28, cornerRadius: 32)
    }
}

// MARK: - Assigned project card

private struct ProjectAssignmentCard: View {
    var plan: ChallengePlan

    private var completion: (complete: Int, total: Int) {
        let tasks = plan.days.flatMap { $0.tasks }
        let completed = tasks.filter { $0.isComplete }.count
        return (completed, tasks.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "rectangle.stack.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(12)
                    .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Spacer()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(plan.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(plan.primaryGoal)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Text("\(completion.complete)/\(completion.total) finished")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(20)
        .frame(width: 210, height: 170)
        .background(
            LinearGradient(colors: plan.accentColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        )
    }
}

// MARK: - Task summary card

private struct TaskSummaryCard: View {
    @Environment(ChallengeStore.self) private var store
    var plan: ChallengePlan
    @Binding var isExpanded: Bool

    private var openTasks: [DailyTaskSummary] {
        let entries = plan.days
            .sorted { $0.dayNumber < $1.dayNumber }
            .flatMap { day in
                day.tasks.map { DailyTaskSummary(dayNumber: day.dayNumber, task: $0) }
            }
            .filter { !$0.task.isComplete }
        return Array(entries.prefix(isExpanded ? entries.count : 4))
    }

    private var remainingCount: Int {
        let totalOpen = plan.days.flatMap { $0.tasks }.filter { !$0.isComplete }.count
        return max(0, totalOpen - openTasks.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Palette.accentBlue)
                        .padding(10)
                        .background(Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.title)
                            .font(.headline)
                        Text("Tasks • \(totalTasks)")
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer()
                NavigationLink {
                    ProjectTaskListView(planID: plan.id)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(8)
                        .background(Palette.surfaceMuted, in: Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 12) {
                ForEach(openTasks) { summary in
                    TaskPreviewRow(planID: plan.id, summary: summary)
                }
            }

            if remainingCount > 0 {
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(isExpanded ? "Show less" : "Show more")
                        Spacer()
                        Text("\(remainingCount) more")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.accentBlue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Palette.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 10)
        )
    }

    private var totalTasks: Int {
        plan.days.reduce(0) { $0 + $1.tasks.count }
    }
}

private struct DailyTaskSummary: Identifiable {
    let dayNumber: Int
    let task: TaskItem

    var id: UUID { task.id }
}

private struct TaskPreviewRow: View {
    @Environment(ChallengeStore.self) private var store
    var planID: UUID
    var summary: DailyTaskSummary

    private var task: TaskItem { summary.task }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    store.toggleTask(planID: planID, dayNumber: summary.dayNumber, taskID: task.id)
                }
            } label: {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isComplete ? Palette.accentBlue : Palette.textSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
                Text(task.tags.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("Day \(summary.dayNumber)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Full task list

private struct ProjectTaskListView: View {
    @Environment(ChallengeStore.self) private var store
    var planID: UUID

    private var plan: ChallengePlan? {
        store.plans.first(where: { $0.id == planID })
    }

    var body: some View {
        Group {
            if let plan {
                List {
                    Section(header: Text(plan.title).font(.headline)) {
                        ForEach(plan.days.sorted(by: { $0.dayNumber < $1.dayNumber })) { day in
                            Section(header: Text(day.displayTitle).font(.subheadline)) {
                                ForEach(day.tasks) { task in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(task.isComplete ? Palette.accentBlue : Palette.textSecondary)
                                            .padding(.top, 4)
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(task.title)
                                                .font(.body.weight(.semibold))
                                            Text(task.instructions)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                Text("Plan not found")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("All Tasks")
    }
}
