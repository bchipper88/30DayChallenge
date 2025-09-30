import SwiftUI

struct ChallengeDashboardView: View {
    @Environment(ChallengeStore.self) private var store
    var plan: ChallengePlan

    @State private var showWeeks = true
    @State private var showPrinciples = true
    @State private var showRisks = true
    @State private var showCallToAction = true

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                heroHeader
                weeksSection
                principlesSection
                risksSection
                callToAction
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Challenge Overview")
        .toolbar { streakToolbar }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(plan.title)
                .font(.system(.largeTitle, design: .rounded).bold())
                .foregroundStyle(Palette.textPrimary)

            Text(plan.primaryGoal)
                .font(.headline)
                .foregroundStyle(Palette.textSecondary)

            gradientCard
        }
        .softCard(padding: 26, cornerRadius: 34)
    }

    private var gradientCard: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(LinearGradient(colors: plan.accentColors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(height: 160)
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Reminder", systemImage: "alarm")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(plan.reminderRule.message)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Daily • \(formattedTime(plan.reminderRule.timeOfDay))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(24)
            }
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing) {
                    Text("Streak")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    if let streak = store.streakStates[plan.id] {
                        Text("🔥 \(streak.current) current")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Best: \(streak.longest)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(24)
            }
    }

    private var weeksSection: some View {
        DisclosureGroup(isExpanded: $showWeeks) {
            VStack(spacing: 18) {
                ForEach(weeklyBreakdowns) { breakdown in
                    WeeklyPlanView(breakdown: breakdown)
                }
            }
            .padding(.top, 12)
        } label: {
            sectionHeader(title: "Weekly Ramp", subtitle: "Every 7-day sprint with checkpoints")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disclosureGroupStyle(.automatic)
        .softCard()
    }

    private var principlesSection: some View {
        DisclosureGroup(isExpanded: $showPrinciples) {
            let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(plan.phases.flatMap { $0.keyPrinciples }, id: \.self) { principle in
                    Text(principle)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                }
            }
            .padding(.top, 12)
        } label: {
            sectionHeader(title: "Key Principles", subtitle: "Success heuristics to keep you playful")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disclosureGroupStyle(.automatic)
        .softCard()
    }

    private var risksSection: some View {
        DisclosureGroup(isExpanded: $showRisks) {
            VStack(spacing: 12) {
                ForEach(plan.phases.flatMap { $0.risks }) { risk in
                    RiskRow(risk: risk)
                }
            }
            .padding(.top, 12)
        } label: {
            sectionHeader(title: "Risks Radar", subtitle: "Spot the friction before it appears")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disclosureGroupStyle(.automatic)
        .softCard()
    }

    private var callToAction: some View {
        DisclosureGroup(isExpanded: $showCallToAction) {
            Text(plan.callToAction)
                .font(.title3.weight(.semibold))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                .padding(.top, 12)
        } label: {
            sectionHeader(title: "Rally Cry", subtitle: "Keep this mantra visible")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disclosureGroupStyle(.automatic)
        .softCard()
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var streakToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if let streak = store.streakStates[plan.id] {
                VStack(spacing: 2) {
                    Text("🔥\(streak.current)")
                        .font(.headline)
                    Text("Longest \(streak.longest)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func formattedTime(_ components: DateComponents) -> String {
        guard let hour = components.hour, let minute = components.minute else { return "--:--" }
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private extension ChallengeDashboardView {
    var weeklyBreakdowns: [WeeklyBreakdown] {
        plan.weeklyReviews
            .sorted { $0.weekNumber < $1.weekNumber }
            .map { review in
                let range = Self.weekRange(for: review.weekNumber)
                let days = plan.days.filter { range.contains($0.dayNumber) }
                let matchingPhase = plan.phases.first { phase in
                    let weekRange = range.lowerBound..<(range.upperBound + 1)
                    return phase.dayRange.overlaps(weekRange)
                }
                return WeeklyBreakdown(week: review, days: days, phase: matchingPhase)
            }
    }

    static func weekRange(for week: Int) -> ClosedRange<Int> {
        let lower = max(1, (week - 1) * 7 + 1)
        let upper = min(30, week * 7)
        return lower...upper
    }
}

struct WeeklyBreakdown: Identifiable {
    var id: UUID { week.id }
    let week: WeeklyReview
    let days: [DailyEntry]
    let phase: ChallengePhase?

    var weekRangeDescription: String {
        let lower = days.first?.dayNumber ?? ((week.weekNumber - 1) * 7 + 1)
        let upper = days.last?.dayNumber ?? min(30, week.weekNumber * 7)
        return "Days \(lower)-\(upper)"
    }
}

struct WeeklyPlanView: View {
    var breakdown: WeeklyBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            dayHighlights
            Divider()
            reviewSection
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Palette.border, lineWidth: 1)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Week \(breakdown.week.weekNumber)")
                    .font(.title3.bold())
                    .foregroundStyle(Palette.textPrimary)
                Text(breakdown.weekRangeDescription)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
            }
            if let phase = breakdown.phase {
                Text(phase.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accentBlue)
                Text(phase.objective)
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private var dayHighlights: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily themes")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
            ForEach(breakdown.days) { day in
                HStack(alignment: .center, spacing: 8) {
                    Capsule()
                        .fill(Palette.accentLavender)
                        .frame(width: 6, height: 6)
                    Text("Day \(day.dayNumber):")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(day.theme)
                        .font(.footnote)
                        .foregroundStyle(Palette.textSecondary)
                    Spacer()
                    Text("\(day.tasks.count) tasks")
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly review")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Evidence to collect") {
                    bulletList(breakdown.week.evidenceToCollect)
                }
                LabeledContent("Reflection prompts") {
                    bulletList(breakdown.week.reflectionQuestions)
                }
                LabeledContent("Adaptation rules") {
                    bulletList(breakdown.week.adaptationRules.map { "\($0.condition) → \($0.response)" })
                }
            }
            .font(.footnote)
            .foregroundStyle(Palette.textSecondary)
        }
    }

    @ViewBuilder
    private func bulletList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                    Text(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct CollapsiblePhaseView: View {
    var phase: ChallengePhase
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Text(phase.objective)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Milestones")
                        .font(.headline)
                    ForEach(phase.milestones) { milestone in
                        MilestoneRow(milestone: milestone)
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Phase \(phase.index + 1)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Days \(phase.dayRange.lowerBound)–\(phase.dayRange.upperBound - 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(phase.name)
                    .font(.title3.bold())
            }
        }
        .softCard(padding: 20, cornerRadius: 28)
    }
}

struct MilestoneRow: View {
    var milestone: ChallengeMilestone

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(.pink.opacity(0.4), lineWidth: 2)
                    .frame(width: 40, height: 40)
                Text("D\(milestone.targetDay)")
                    .font(.caption.weight(.bold))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.subheadline.weight(.semibold))
                Text(milestone.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ProgressView(value: milestone.progress)
                    .tint(.pink)
            }
        }
    }
}

struct RiskRow: View {
    var risk: RiskItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(risk.likelihood.color)
                .frame(width: 16, height: 16)
                .overlay(
                    Text(risk.likelihood.rawValue.prefix(1).uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(risk.risk)
                    .font(.subheadline.weight(.semibold))
                Text("Mitigation: \(risk.mitigation)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
