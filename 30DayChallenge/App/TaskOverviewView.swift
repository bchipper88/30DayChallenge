import SwiftUI

struct TaskOverviewView: View {
    @Environment(ChallengeStore.self) private var store
    @State private var weekStart: Date = Calendar.current.startOfWeek(for: Date())
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private let calendar = Calendar.current

    private var plans: [ChallengePlan] { store.plans }

    private var weekDates: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var taskGroups: [PlanTaskGroup] {
        let selectedStart = calendar.startOfDay(for: selectedDate)
        return plans.compactMap { plan -> PlanTaskGroup? in
            let tasks = plan.days.flatMap { day -> [ScheduledTask] in
                let dueDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: day.dayNumber - 1, to: plan.createdAt) ?? plan.createdAt)
                guard dueDate <= selectedStart else { return [] }

                return day.tasks.compactMap { task in
                    guard !task.isComplete else { return nil }
                    let overdueDays = max(0, calendar.dateComponents([.day], from: dueDate, to: selectedStart).day ?? 0)
                    if overdueDays > 0 || dueDate == selectedStart {
                        return ScheduledTask(plan: plan, day: day, task: task, dueDate: dueDate, overdueDays: overdueDays)
                    }
                    return nil
                }
            }
            .sorted { lhs, rhs in
                if lhs.dueDate == rhs.dueDate {
                    return lhs.task.title < rhs.task.title
                }
                return lhs.dueDate < rhs.dueDate
            }

            return tasks.isEmpty ? nil : PlanTaskGroup(plan: plan, tasks: tasks)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    calendarHeader

                    if taskGroups.isEmpty {
                        emptyState
                    } else {
                        VStack(alignment: .leading, spacing: 28) {
                            ForEach(taskGroups) { group in
                                PlanTaskSection(group: group)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 28)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("My Tasks")
        }
        .onAppear {
            selectedDate = calendar.startOfDay(for: Date())
            weekStart = calendar.startOfWeek(for: selectedDate)
        }
    }

    private var calendarHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button { shiftWeek(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .padding(10)
                        .background(Palette.surfaceMuted, in: Circle())
                }

                Spacer()

                Text(weekRangeDescription)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)

                Spacer()

                Button { shiftWeek(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .padding(10)
                        .background(Palette.surfaceMuted, in: Circle())
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(weekDates, id: \.self) { date in
                        CalendarDayChip(date: date, selectedDate: selectedDate) {
                            selectedDate = calendar.startOfDay(for: date)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var weekRangeDescription: String {
        guard let end = calendar.date(byAdding: .day, value: 6, to: weekStart) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startString = formatter.string(from: weekStart)
        let endString = formatter.string(from: end)
        return "\(startString) – \(endString)"
    }

    private func shiftWeek(by offset: Int) {
        let currentOffset = max(0, min(6, calendar.dateComponents([.day], from: weekStart, to: selectedDate).day ?? 0))
        guard let newStart = calendar.date(byAdding: .day, value: 7 * offset, to: weekStart) else { return }
        weekStart = newStart
        let candidate = calendar.date(byAdding: .day, value: currentOffset, to: newStart) ?? newStart
        selectedDate = calendar.startOfDay(for: candidate)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.largeTitle)
                .foregroundStyle(Palette.accentBlue)
            Text("No tasks due")
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)
            Text("You're all caught up for the selected day. Great work!")
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .softCard(padding: 28, cornerRadius: 32)
    }
}

private struct CalendarDayChip: View {
    var date: Date
    var selectedDate: Date
    var onSelect: () -> Void

    private let calendar = Calendar.current

    private var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private var dayName: String {
        CalendarDayChip.formatterWeekday.string(from: date).uppercased()
    }

    private var dayNumber: String {
        CalendarDayChip.formatterDay.string(from: date)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Text(dayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Palette.textSecondary)
                Text(dayNumber)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isSelected ? Color.white : Palette.textPrimary)
            }
            .padding(.vertical, 10)
            .frame(width: 58)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Palette.accentBlue : Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Palette.accentBlue : Palette.border, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ScheduledTask: Identifiable {
    var plan: ChallengePlan
    var day: DailyEntry
    var task: TaskItem
    var dueDate: Date
    var overdueDays: Int

    var id: UUID { task.id }
}

private struct PlanTaskGroup: Identifiable {
    var plan: ChallengePlan
    var tasks: [ScheduledTask]

    var id: UUID { plan.id }
}

private struct PlanTaskSection: View {
    var group: PlanTaskGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerCard

            VStack(spacing: 12) {
                ForEach(displayedTasks) { scheduled in
                    TaskDueCard(task: scheduled)
                        .frame(maxWidth: .infinity)
                }
            }

            if let remaining = remainingCount, remaining > 0 {
                Button("Show more") { /* future expansion */ }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.accentBlue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 18)
    }

    private var displayedTasks: Array<ScheduledTask>.SubSequence {
        group.tasks.prefix(5)
    }

    private var remainingCount: Int? {
        let count = group.tasks.count - displayedTasks.count
        return count > 0 ? count : nil
    }

    private var headerCard: some View {
        NavigationLink {
            ChallengeDashboardView(plan: group.plan)
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.plan.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(group.plan.primaryGoal)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(10)
                    .background(Color.white.opacity(0.2), in: Circle())
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: group.plan.cardPalette.colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            )
        }
        .buttonStyle(.plain)
    }

}

private struct TaskDueCard: View {
    @Environment(ChallengeStore.self) private var store
    var task: ScheduledTask
    @State private var isExpanded = false

    private static let dueFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var dueDateText: String {
        TaskDueCard.dueFormatter.string(from: task.dueDate)
    }

    private var overdueLabel: String? {
        guard task.overdueDays > 0 else { return nil }
        let dayText = task.overdueDays == 1 ? "day" : "days"
        return "\(task.overdueDays) \(dayText) overdue"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                completionButton

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.task.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.textPrimary)

                    HStack(spacing: 12) {
                        Text("\(task.task.expectedMinutes) min")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.accentBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Palette.accentBlue.opacity(0.15), in: Capsule())

                        Text("Day \(task.day.dayNumber)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.textSecondary)

                        Text(dueDateText)
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }

                    if let overdueLabel {
                        Text(overdueLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.12), in: Capsule())
                    }
                }

                Spacer()

                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(6)
                        .background(Palette.surfaceMuted, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { isExpanded.toggle() } }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if !task.task.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        infoRow(title: "Instructions", text: task.task.instructions)
                    }
                    if !task.task.definitionOfDone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        infoRow(title: "Definition of Done", text: task.task.definitionOfDone)
                    }
                    if let metric = task.task.metric {
                        infoRow(title: "Metric", text: "\(metric.name) — target \(metric.target) \(metric.unit)")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
    }

    private var completionButton: some View {
        Button(action: toggleCompletion) {
            Image(systemName: task.task.isComplete ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(task.task.isComplete ? Palette.accentBlue : Palette.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func infoRow(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func toggleCompletion() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            store.toggleTask(planID: task.plan.id, dayNumber: task.day.dayNumber, taskID: task.task.id)
        }
    }
}

private struct TaskDueRow: View {
    @Environment(ChallengeStore.self) private var store
    var task: ScheduledTask
    private static let dueFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    @State private var isExpanded = false

    private var dueDateText: String {
        TaskDueRow.dueFormatter.string(from: task.dueDate)
    }

    private var overdueLabel: String? {
        guard task.overdueDays > 0 else { return nil }
        let dayText = task.overdueDays == 1 ? "day" : "days"
        return "\(task.overdueDays) \(dayText) overdue"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                completionButton

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.task.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.textPrimary)

                    HStack(spacing: 12) {
                        Text("\(task.task.expectedMinutes) min")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.accentBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Palette.accentBlue.opacity(0.15), in: Capsule())

                        Text("Day \(task.day.dayNumber)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.textSecondary)

                        Text(dueDateText)
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)

                    }

                    if let overdueLabel {
                        Text(overdueLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.12), in: Capsule())
                    }
                }

                Spacer()

                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(6)
                        .background(Palette.surfaceMuted, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { isExpanded.toggle() } }

            if isExpanded {
                        VStack(alignment: .leading, spacing: 10) {
                            if !task.task.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                infoRow(title: "Instructions", text: task.task.instructions)
                            }
                            if !task.task.definitionOfDone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                infoRow(title: "Definition of Done", text: task.task.definitionOfDone)
                            }
                            if let metric = task.task.metric {
                                infoRow(title: "Metric", text: "\(metric.name) — target \(metric.target) \(metric.unit)")
                            }
                        }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
    }

    private var completionButton: some View {
        Button(action: toggleCompletion) {
            Image(systemName: task.task.isComplete ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(task.task.isComplete ? Palette.accentBlue : Palette.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func infoRow(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func toggleCompletion() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            store.toggleTask(planID: task.plan.id, dayNumber: task.day.dayNumber, taskID: task.task.id)
        }
    }
}

private extension CalendarDayChip {
    static let formatterWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    static let formatterDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
}

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let startOfDay = self.startOfDay(for: date)
        var components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfDay)
        components.weekday = firstWeekday
        return self.date(from: components) ?? startOfDay
    }
}
