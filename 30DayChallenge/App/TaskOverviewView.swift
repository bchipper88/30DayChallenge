import SwiftUI

struct TaskOverviewView: View {
    @Environment(ChallengeStore.self) private var store
    @State private var expandedPlans: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    ForEach(store.plans) { plan in
                        TaskPlanSection(
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
                    if store.plans.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Milestones")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Milestone tracker")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Image(systemName: "calendar")
                    .foregroundStyle(Palette.textPrimary)
                    .elevatedIconButton()
            }
            Text("Review each project roadmap and glide into the next milestone with clarity.")
                .font(.callout)
                .foregroundStyle(Palette.textSecondary)
        }
        .softCard(padding: 24, cornerRadius: 32)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(Palette.accentBlue)
            Text("No projects yet")
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)
            Text("Create a challenge from Home to see tasks roll up here.")
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .softCard(padding: 24, cornerRadius: 28)
    }
}

struct TaskPlanSection: View {
    var plan: ChallengePlan
    @Binding var isExpanded: Bool

    var body: some View {
        let groups = plan.milestoneTaskGroups()
        return VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $isExpanded) {
                if groups.isEmpty {
                    Text("No milestone tasks available yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(groups) { group in
                            MilestoneTaskSection(planID: plan.id, group: group)
                        }
                    }
                    .padding(.top, 8)
                }

                NavigationLink {
                    ProjectTaskListView(planID: plan.id)
                } label: {
                    Label("View full task list", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.title)
                            .font(.headline)
                        Text("Milestones: \(plan.phases.flatMap { $0.milestones }.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label("\(openTaskCount)/\(totalTaskCount) left", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .animation(.easeInOut, value: isExpanded)
        }
        .softCard(padding: 24, cornerRadius: 32)
    }

    private var openTaskCount: Int {
        plan.days.flatMap { $0.tasks }.filter { !$0.isComplete }.count
    }

    private var totalTaskCount: Int {
        plan.days.reduce(0) { $0 + $1.tasks.count }
    }
}

struct CollapsibleTaskRow: View {
    @Environment(ChallengeStore.self) private var store
    var planID: UUID
    var dayNumber: Int
    var task: TaskItem
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            DailyTaskRow(planID: planID, dayNumber: dayNumber, task: task, showHeader: false)
                .padding(.top, 8)
        } label: {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        store.toggleTask(planID: planID, dayNumber: dayNumber, taskID: task.id)
                    }
                } label: {
                    Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.headline)
                        .foregroundStyle(task.isComplete ? .green : .secondary)
                }
                .buttonStyle(.plain)

                Text(task.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Text("Day \(dayNumber)")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .contentShape(Rectangle())
        }
        .disclosureGroupStyle(.automatic)
    }
}

struct MilestoneTaskSection: View {
    var planID: UUID
    var group: MilestoneTaskGroup
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(group.days) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day.displayTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(day.tasks) { task in
                            CollapsibleTaskRow(planID: planID, dayNumber: day.dayNumber, task: task)
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.milestone.title)
                        .font(.headline)
                    Text("Target Day \(group.milestone.targetDay)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("\(openCount)/\(totalCount) left", systemImage: "checklist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disclosureGroupStyle(.automatic)
        .softCard(padding: 22, cornerRadius: 30)
    }

    private var openCount: Int {
        group.days.flatMap { $0.tasks }.filter { !$0.isComplete }.count
    }

    private var totalCount: Int {
        group.days.reduce(0) { $0 + $1.tasks.count }
    }
}

struct ProjectTaskListView: View {
    @Environment(ChallengeStore.self) private var store
    var planID: UUID

    private var plan: ChallengePlan? {
        store.plans.first(where: { $0.id == planID })
    }

    var body: some View {
        Group {
            if let plan {
                List {
                    ForEach(plan.days) { day in
                        Section {
                            ForEach(day.tasks) { task in
                                DailyTaskRow(planID: plan.id, dayNumber: day.dayNumber, task: task)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                    .listRowSeparator(.hidden)
                            }
                        } header: {
                            dayHeader(for: day)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle(plan.title)
                .onAppear {
                    store.select(plan)
                }
            } else {
                ProgressView()
            }
        }
    }

    private func dayHeader(for day: DailyEntry) -> some View {
        HStack {
            Text(day.displayTitle)
                .font(.headline)
            Spacer()
            if day.tasks.allSatisfy({ $0.isComplete }) {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Text("\(day.tasks.filter { !$0.isComplete }.count) open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
