import SwiftUI

struct ChallengeListView: View {
    @Environment(ChallengeStore.self) private var store
    @State private var path: [ChallengePlan] = []
    @State private var showCreate = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 28) {
                    heroHeader
                    segmentRow
                    LazyVStack(spacing: 20) {
                        ForEach(store.pendingPlans) { pending in
                            PendingPlanCard(pending: pending)
                        }
                        ForEach(store.plans) { plan in
                            NavigationLink(value: plan) {
                                PlanCardView(plan: plan)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                store.select(plan)
                            })
                        }
                        NewPlanCard {
                            showCreate = true
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .background(Palette.background)
            .navigationDestination(for: ChallengePlan.self) { plan in
                ChallengeDashboardView(plan: plan)
                    .onAppear { store.select(plan) }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateChallengeView()
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                    Text("challenge workspace")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Palette.textPrimary)
                        .elevatedIconButton()
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(Palette.textPrimary)
                        .elevatedIconButton()
                }
            }
            Text("Review projects, track momentum, and spin up new 30-day quests.")
                .font(.callout)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var segmentRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Text("All")
                    .font(.subheadline.weight(.semibold))
                    .pillStyle(isSelected: true)
                Text("Active")
                    .font(.subheadline.weight(.semibold))
                    .pillStyle()
                Text("Awaiting start")
                    .font(.subheadline.weight(.semibold))
                    .pillStyle()
                Text("Completed")
                    .font(.subheadline.weight(.semibold))
                    .pillStyle()
            }
        }
    }
}

struct PlanCardView: View {
    var plan: ChallengePlan

    private var progress: Int {
        let ratio = plan.phases.flatMap { $0.milestones }.map { $0.progress }.average
        return max(0, min(100, Int(ratio * 100)))
    }

    private var currentDay: Int {
        plan.days.first(where: { !$0.tasks.allSatisfy { $0.isComplete } })?.dayNumber ?? plan.days.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.domain.displayName.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                    Text(plan.title)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                    Text(plan.primaryGoal)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                VStack(spacing: 10) {
                    Text("Day \(currentDay)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Palette.accentLavender, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text("\(progress)%")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Palette.accentBlue)
                }
            }

            HStack(spacing: 16) {
                MetricChip(title: "Milestones", value: "\(plan.phases.flatMap { $0.milestones }.count)")
                MetricChip(title: "Weekly reviews", value: "\(plan.weeklyReviews.count)", accent: Palette.accentLavender)
                MetricChip(title: "Reminder", value: formattedReminder(plan.reminderRule), accent: Palette.accentCoral)
            }

            LinearGradient(colors: plan.accentColors, startPoint: .leading, endPoint: .trailing)
                .frame(height: 6)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .softCard(padding: 24, cornerRadius: 32)
    }

    private func formattedReminder(_ rule: ReminderRule) -> String {
        guard let hour = rule.timeOfDay.hour, let minute = rule.timeOfDay.minute else { return "Daily" }
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

struct NewPlanCard: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.accentBlue)
                    .padding(14)
                    .background(Palette.accentLavender.opacity(0.4), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Text("Create a new 30-day challenge")
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text("Kick off another sprint with a single tap and we’ll draft the roadmap.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .softCard(padding: 24, cornerRadius: 32)
        }
        .buttonStyle(.plain)
    }
}

struct PendingPlanCard: View {
    @Environment(ChallengeStore.self) private var store
    var pending: ChallengeStore.PendingPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text(statusTitle)
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text(pending.promptPreview)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(3)
                    Text(pending.purpose)
                        .font(.footnote)
                        .foregroundStyle(Palette.textSecondary.opacity(0.9))
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Text(pending.agent.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.accentBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Text(pending.agent.descriptor)
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                        Text(pending.familiarity.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer()
                Text(pending.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            content
        }
        .softCard(padding: 24, cornerRadius: 32)
    }

    @ViewBuilder
    private var content: some View {
        switch pending.status {
        case .queued, .generating:
            HStack(spacing: 12) {
                ProgressView()
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 12) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                HStack(spacing: 12) {
                    Button("Retry") {
                        store.retryPendingPlan(pending)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Dismiss") {
                        store.dismissPendingPlan(pending)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var statusTitle: String {
        switch pending.status {
        case .queued:
            return "Queued for drafting"
        case .generating:
            return "AI is crafting your plan"
        case .failed:
            return "Plan generation stalled"
        }
    }

    private var statusMessage: String {
        switch pending.status {
        case .queued:
            return "\(pending.agent.displayName) is queued to start drafting."
        case .generating:
            return "\(pending.agent.displayName) is writing the 30-day roadmap…"
        case .failed(let message):
            return message
        }
    }

    private var iconName: String {
        switch pending.status {
        case .queued:
            return "clock.arrow.circlepath"
        case .generating:
            return "sparkles"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch pending.status {
        case .queued:
            return Palette.accentBlue
        case .generating:
            return Palette.accentLavender
        case .failed:
            return Palette.accentCoral
        }
    }
}
