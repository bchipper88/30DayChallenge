import SwiftUI

struct DailyFocusView: View {
    @Environment(ChallengeStore.self) private var store
    var planID: UUID
    @State private var selectedDay: Int = 1

    private var plan: ChallengePlan? {
        store.plans.first(where: { $0.id == planID })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if let plan {
                        header(plan: plan)
                        daySelector(plan: plan)
                        if let day = plan.day(for: selectedDay) {
                            DailySummaryCard(day: day, plan: plan)
                            taskList(plan: plan, day: day)
                            reflectionCard(day: day)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Focus")
        }
        .onAppear {
            selectedDay = plan?.days.first?.dayNumber ?? 1
        }
    }

    private func daySelector(plan: ChallengePlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select a day")
                .font(.headline)
                .foregroundStyle(Palette.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(plan.days, id: \.dayNumber) { day in
                        DayChip(day: day, isSelected: day.dayNumber == selectedDay)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    selectedDay = day.dayNumber
                                }
                            }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func taskList(plan: ChallengePlan, day: DailyEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's commitments")
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)
            VStack(spacing: 16) {
                ForEach(day.tasks) { task in
                    DailyTaskRow(planID: plan.id, dayNumber: day.dayNumber, task: task)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reflectionCard(day: DailyEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Check-in prompt", systemImage: "sparkle")
                .font(.headline)
                .foregroundStyle(Palette.textSecondary)
            Text(day.checkInPrompt)
                .font(.body)
                .foregroundStyle(Palette.textPrimary)
            Text(day.celebrationMessage)
                .font(.callout)
                .foregroundStyle(Palette.textSecondary)
        }
        .softCard(padding: 24, cornerRadius: 30)
    }

    private func header(plan: ChallengePlan) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's focus")
                    .font(.title.bold())
                    .foregroundStyle(Palette.textPrimary)
                Text(plan.shortSummary)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                HStack(spacing: 16) {
                    MetricChip(title: "Milestone", value: nextMilestoneTitle(plan: plan), accent: Palette.accentLavender)
                    MetricChip(title: "Reminder", value: formattedReminder(plan), accent: Palette.accentBlue)
                }
            }
            Spacer()
        }
        .softCard(padding: 24, cornerRadius: 32)
    }

    private func nextMilestoneTitle(plan: ChallengePlan) -> String {
        let milestone = plan.milestone(forDay: selectedDay) ?? plan.phases.first?.milestones.first
        return milestone?.title ?? "TBD"
    }

    private func formattedReminder(_ plan: ChallengePlan) -> String {
        guard let hour = plan.reminderRule.timeOfDay.hour, let minute = plan.reminderRule.timeOfDay.minute else { return "--" }
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

struct DailySummaryCard: View {
    var day: DailyEntry
    var plan: ChallengePlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(day.displayTitle)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.textPrimary)
            Text("Momentum theme: \(day.theme)")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 16) {
                MetricChip(title: "Tasks", value: "\(day.tasks.filter { !$0.isComplete }.count)/\(day.tasks.count)", accent: Palette.accentBlue)
                MetricChip(title: "Reminder", value: formattedReminder(plan), accent: Palette.accentLavender)
            }
        }
        .softCard(padding: 24, cornerRadius: 30)
    }

    private func formattedReminder(_ plan: ChallengePlan) -> String {
        guard let hour = plan.reminderRule.timeOfDay.hour, let minute = plan.reminderRule.timeOfDay.minute else { return "--" }
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

struct DayChip: View {
    var day: DailyEntry
    var isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text("Day \(day.dayNumber)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Palette.textPrimary)
            Text(day.theme)
                .font(.footnote)
                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Palette.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isSelected ? Palette.accentBlue : Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? Palette.accentBlue.opacity(0.6) : Palette.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isSelected ? 0.1 : 0.04), radius: 12, x: 0, y: 8)
    }
}

struct DailyTaskRow: View {
    @Environment(ChallengeStore.self) private var store
    var planID: UUID
    var dayNumber: Int
    var task: TaskItem
    var showHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showHeader {
                header
            }
            TaskDetailContent(task: task, showTypeTag: !showHeader)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(alignment: .topTrailing) {
            if task.isComplete {
                Text("Completed")
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2), in: Capsule())
                    .padding(10)
            }
        }
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    store.toggleTask(planID: planID, dayNumber: dayNumber, taskID: task.id)
                }
            } label: {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isComplete ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(task.type.icon)
                        .font(.caption2.uppercaseSmallCaps())
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                    Text(task.title)
                        .font(.headline)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct TaskDetailContent: View {
    var task: TaskItem
    var showTypeTag: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showTypeTag {
                Text(task.type.icon)
                    .font(.caption2.uppercaseSmallCaps())
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
            }
            Text(task.instructions)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label("\(task.expectedMinutes) min", systemImage: "clock")
                    .font(.caption)
                    .labelStyle(.titleAndIcon)
                if let metric = task.metric {
                    Label("\(metric.name) • \(Int(metric.target)) \(metric.unit)", systemImage: "chart.bar")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
            Text("Done when: \(task.definitionOfDone)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
