import SwiftUI

struct ChallengeDashboardView: View {
    @Environment(ChallengeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var plan: ChallengePlan

    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                dueDatesRow
                summarySection
                rallyCrySection
                outlineSection
                principlesSection
                risksSection
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Challenge Overview")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("Delete this challenge?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await deletePlan()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.title)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dueDatesRow: some View {
        HStack(spacing: 16) {
            DueTile(title: "Due", systemImage: "calendar", text: dueDate.formatted(date: .abbreviated, time: .omitted))
            DueTile(title: "Days Remaining", systemImage: "clock", text: "\(daysRemaining) days")
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Summary")
                .font(.title3.bold())
                .foregroundStyle(Palette.textPrimary)
            Text(plan.summary?.isEmpty == false ? plan.summary! : plan.primaryGoal)
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
                .lineSpacing(5)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
        }
    }

    private var outlineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Outline")
                .font(.title3.bold())
                .foregroundStyle(Palette.textPrimary)
            VStack(spacing: 16) {
                ForEach(weeklyBreakdowns) { breakdown in
                    WeeklyOutlineCard(breakdown: breakdown)
                }
            }
        }
    }

    private var principlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Principles")
                .font(.title3.bold())
                .foregroundStyle(Palette.textPrimary)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(keyPrinciples, id: \.self) { principle in
                    HStack(spacing: 10) {
                        Image(systemName: "sparkle")
                            .foregroundStyle(Palette.accentBlue)
                        Text(principle)
                            .font(.body)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                }
            }
        }
    }

    private var risksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Risks Radar")
                .font(.title3.bold())
                .foregroundStyle(Palette.textPrimary)
            VStack(spacing: 12) {
                ForEach(plan.phases.flatMap { $0.risks }) { risk in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(risk.risk)
                                .font(.headline)
                                .foregroundStyle(Palette.textPrimary)
                            Spacer()
                            Text(risk.likelihood.rawValue.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(risk.likelihood.color.opacity(0.2), in: Capsule())
                                .foregroundStyle(risk.likelihood.color)
                        }
                        Text(risk.mitigation)
                            .font(.footnote)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
                }
            }
        }
    }

    private var rallyCrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rally Cry")
                .font(.title3.bold())
                .foregroundStyle(Palette.textPrimary)
            Text(plan.callToAction)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
        }
    }

    private var dueDate: Date {
        Calendar.current.date(byAdding: .day, value: 29, to: plan.createdAt) ?? plan.createdAt
    }

    private var daysRemaining: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: dueDate)
        return max(0, calendar.dateComponents([.day], from: today, to: due).day ?? 0)
    }

    var keyPrinciples: [String] {
        plan.phases.flatMap { $0.keyPrinciples }
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

private extension ChallengeDashboardView {
    func deletePlan() async {
        await store.deletePlan(plan.id)
    }
}

struct DueTile: View {
    var title: String
    var systemImage: String
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(text)
                    .font(.body)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
        }
    }
}

struct WeeklyOutlineCard: View {
    var breakdown: WeeklyBreakdown

    private var phaseName: String {
        breakdown.phase?.name ?? "Phase \(breakdown.week.weekNumber)"
    }

    private var phaseObjective: String {
        breakdown.phase?.objective ?? breakdown.week.reflectionQuestions.first ?? "Focus on consistent progress."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Week \(breakdown.week.weekNumber)")
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(breakdown.weekRangeDescription)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }

            Text(phaseName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accentBlue)

            Text(phaseObjective)
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
                .lineSpacing(3)
        }
        .padding(18)
        .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Palette.border.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
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
