import SwiftUI

struct ChallengeDashboardView: View {
    @Environment(ChallengeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var plan: ChallengePlan
    @State private var showDeleteConfirmation = false
    @State private var isEditing = false

    init(plan: ChallengePlan) {
        _plan = State(initialValue: plan)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                dueDatesRow
                summarySection
                outlineSection
                principlesSection
                risksSection
                rallyCrySection
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Challenge Overview")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                }

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
        .sheet(isPresented: $isEditing) {
            EditChallengeView(plan: plan) { updatedPlan in
                plan = updatedPlan
                store.update(plan: updatedPlan)
            }
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
        VStack(alignment: .leading, spacing: 14) {
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

            if let purpose = purposeText {
                Text("Purpose")
                    .font(.title3.bold())
                    .foregroundStyle(Palette.textPrimary)
                Text(purpose)
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .lineSpacing(5)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
            }

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
                ForEach(riskHighlights) { risk in
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
        Group {
            if !trimmedCallToAction.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rally Cry")
                        .font(.title3.bold())
                        .foregroundStyle(Palette.textPrimary)
                    Text(trimmedCallToAction)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
                }
            }
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
        let trimmed = plan.keyPrinciples.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !trimmed.isEmpty {
            return trimmed
        }
        return plan.phases.flatMap { $0.keyPrinciples }
    }

    var riskHighlights: [RiskItem] {
        let trimmed = plan.riskHighlights.filter { !$0.risk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !trimmed.isEmpty {
            return trimmed
        }
        return plan.phases.flatMap { $0.risks }
    }

    private var trimmedCallToAction: String {
        plan.callToAction.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var purposeText: String? {
        if let purpose = plan.purpose?.trimmingCharacters(in: .whitespacesAndNewlines), !purpose.isEmpty {
            return purpose
        }

        if let assumption = plan.assumptions.first(where: { $0.lowercased().hasPrefix("purpose:") }) {
            let value = assumption.dropFirst("Purpose:".count).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }

        return nil
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

private struct EditChallengeView: View {
    struct EditablePhase: Identifiable {
        var id: UUID
        var index: Int
        var name: String
        var objective: String
    }

    struct EditablePrinciple: Identifiable {
        var id: UUID = UUID()
        var text: String
    }

    struct EditableRisk: Identifiable {
        var id: UUID
        var risk: String
        var likelihood: RiskItem.Likelihood
        var mitigation: String
    }

    @Environment(\.dismiss) private var dismiss

    let plan: ChallengePlan
    let onSave: (ChallengePlan) -> Void

    @State private var title: String
    @State private var summary: String
    @State private var purpose: String
    @State private var rallyCry: String
    @State private var phases: [EditablePhase]
    @State private var principles: [EditablePrinciple]
    @State private var risks: [EditableRisk]

    init(plan: ChallengePlan, onSave: @escaping (ChallengePlan) -> Void) {
        self.plan = plan
        self.onSave = onSave
        _title = State(initialValue: plan.title)
        _summary = State(initialValue: plan.summary ?? "")
        _purpose = State(initialValue: plan.purpose ?? "")
        _rallyCry = State(initialValue: plan.callToAction)
        _phases = State(initialValue: plan.phases.map { phase in
            EditablePhase(id: phase.id, index: phase.index, name: phase.name, objective: phase.objective)
        })
        _principles = State(initialValue: {
            let existing = plan.keyPrinciples
            if existing.isEmpty {
                return [EditablePrinciple(text: "")]
            }
            return existing.map { EditablePrinciple(text: $0) }
        }())
        _risks = State(initialValue: {
            let existing = plan.riskHighlights
            if existing.isEmpty {
                return [EditableRisk(id: UUID(), risk: "", likelihood: .medium, mitigation: "")]
            }
            return existing.map { risk in
                EditableRisk(id: risk.id, risk: risk.risk, likelihood: risk.likelihood, mitigation: risk.mitigation)
            }
        }())
    }

    var body: some View {
        NavigationStack {
            Form {
                basicsSection
                summarySection
                purposeSection
                outlineSection
                principlesSection
                risksSection
                rallyCrySection
            }
            .navigationTitle("Edit Challenge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var basicsSection: some View {
        Section("Title") {
            TextField("Title", text: $title)
                .textInputAutocapitalization(.sentences)
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            TextEditor(text: $summary)
                .frame(minHeight: 120)
        }
    }

    private var purposeSection: some View {
        Section("Purpose") {
            TextEditor(text: $purpose)
                .frame(minHeight: 120)
        }
    }

    private var outlineSection: some View {
        Section("Outline Cards") {
            ForEach($phases) { $phase in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phase \(phase.index + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Name", text: $phase.name)
                        .textInputAutocapitalization(.words)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Objective")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $phase.objective)
                            .frame(minHeight: 80)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var principlesSection: some View {
        Section("Key Principles") {
            ForEach($principles) { $principle in
                HStack {
                    TextField("Principle", text: $principle.text, axis: .vertical)
                        .lineLimit(1...3)
                    if principles.count > 1 {
                        Button {
                            removePrinciple(id: principle.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if principles.count < 5 {
                Button {
                    principles.append(EditablePrinciple(text: ""))
                } label: {
                    Label("Add Principle", systemImage: "plus.circle")
                }
            }
        }
    }

    private var risksSection: some View {
        Section("Risks Radar") {
            ForEach($risks) { $risk in
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Risk", text: $risk.risk, axis: .vertical)
                        .lineLimit(1...3)
                    Picker("Likelihood", selection: $risk.likelihood) {
                        ForEach(RiskItem.Likelihood.allCases, id: \.self) { likelihood in
                            Text(likelihood.rawValue.capitalized).tag(likelihood)
                        }
                    }
                    TextField("Mitigation", text: $risk.mitigation, axis: .vertical)
                        .lineLimit(1...3)
                    if risks.count > 1 {
                        Button(role: .destructive) {
                            removeRisk(id: risk.id)
                        } label: {
                            Label("Remove Risk", systemImage: "trash")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            if risks.count < 6 {
                Button {
                    risks.append(EditableRisk(id: UUID(), risk: "", likelihood: .medium, mitigation: ""))
                } label: {
                    Label("Add Risk", systemImage: "plus.circle")
                }
            }
        }
    }

    private var rallyCrySection: some View {
        Section("Rally Cry") {
            TextEditor(text: $rallyCry)
                .frame(minHeight: 120)
        }
    }

    private func removePrinciple(id: UUID) {
        principles.removeAll { $0.id == id }
        if principles.isEmpty {
            principles = [EditablePrinciple(text: "")]
        }
    }

    private func removeRisk(id: UUID) {
        risks.removeAll { $0.id == id }
        if risks.isEmpty {
            risks = [EditableRisk(id: UUID(), risk: "", likelihood: .medium, mitigation: "")]
        }
    }

    private func saveChanges() {
        var updated = plan

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.title = trimmedTitle

        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.summary = trimmedSummary.isEmpty ? nil : trimmedSummary

        let trimmedPurpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.purpose = trimmedPurpose.isEmpty ? nil : trimmedPurpose

        let trimmedRally = rallyCry.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRally.isEmpty {
            updated.callToAction = trimmedRally
        }

        for index in updated.phases.indices {
            if let edited = phases.first(where: { $0.id == updated.phases[index].id }) {
                updated.phases[index].name = edited.name.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.phases[index].objective = edited.objective.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        updated.keyPrinciples = cleanedPrinciples()
        updated.riskHighlights = cleanedRisks()

        onSave(updated)
        dismiss()
    }

    private func cleanedPrinciples() -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for principle in principles {
            let trimmed = principle.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                result.append(trimmed)
            }
            if result.count == 5 { break }
        }
        return result
    }

    private func cleanedRisks() -> [RiskItem] {
        var seen = Set<String>()
        var result: [RiskItem] = []
        for risk in risks {
            let trimmedRisk = risk.risk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedRisk.isEmpty else { continue }
            let trimmedMitigation = risk.mitigation.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmedRisk.lowercased()
            if seen.insert(key).inserted {
                let mitigation = trimmedMitigation.isEmpty ? "" : trimmedMitigation
                result.append(RiskItem(id: risk.id, risk: trimmedRisk, likelihood: risk.likelihood, mitigation: mitigation))
            }
            if result.count == 6 { break }
        }
        return result
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
