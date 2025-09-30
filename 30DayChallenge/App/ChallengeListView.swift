import SwiftUI

struct ChallengeListView: View {
    @Environment(ChallengeStore.self) private var store
    @State private var path: [ChallengeListDestination] = []
    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 28) {
                        heroHeader
                        segmentRow
                        LazyVStack(spacing: 20) {
                            ForEach(store.pendingPlans) { pending in
                                PendingPlanCard(pending: pending)
                            }
                        ForEach(store.plans) { plan in
                            NavigationLink(value: ChallengeListDestination.plan(plan)) {
                                PlanCardView(plan: plan)
                            }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded {
                                    store.select(plan)
                                })
                            }
                            NewPlanCardLink()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }

                FloatingCreateButton {
                    path.append(.create)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 32)
            }
            .background(Palette.background)
            .navigationDestination(for: ChallengeListDestination.self) { destination in
                switch destination {
                case .plan(let plan):
                    ChallengeDashboardView(plan: plan)
                        .onAppear { store.select(plan) }
                case .create:
                    CreateChallengeView()
                }
            }
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Challenges")
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

    private var completedTasks: Int {
        plan.days.reduce(0) { partial, day in
            partial + day.tasks.filter { $0.isComplete }.count
        }
    }

    private var totalTasks: Int {
        plan.days.reduce(0) { $0 + $1.tasks.count }
    }

    private var progressFraction: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }

    private var percentageComplete: Int {
        Int(round(progressFraction * 100))
    }

    private var currentDayNumber: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: plan.createdAt)
        let today = calendar.startOfDay(for: Date())
        let diff = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        return max(1, diff + 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(plan.title)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
                Spacer()
                Text("Day \(currentDayNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Palette.accentLavender.opacity(0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            ProgressView(value: progressFraction)
                .progressViewStyle(.linear)
                .tint(Palette.accentBlue)

            HStack {
                Text("\(percentageComplete)% Complete")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Palette.accentBlue)
            }
        }
        .softCard(padding: 24, cornerRadius: 32)
    }
}

struct NewPlanCardLink: View {
    var body: some View {
        NavigationLink(value: ChallengeListDestination.create) {
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

struct FloatingCreateButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                Text("New")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                LinearGradient(colors: [Palette.accentBlue, Palette.accentLavender], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .cornerRadius(28)
            )
            .foregroundColor(.white)
            .shadow(color: Palette.accentBlue.opacity(0.35), radius: 18, x: 0, y: 14)
        }
    }
}

enum ChallengeListDestination: Hashable {
    case plan(ChallengePlan)
    case create
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
