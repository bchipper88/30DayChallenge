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
                    NavigationLink {
                        WeekOverviewView(planID: plan.id, breakdown: breakdown)
                    } label: {
                        WeeklyOutlineCard(breakdown: breakdown, showsChevron: true)
                    }
                    .buttonStyle(.plain)
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
        plan.keyPrinciples
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var riskHighlights: [RiskItem] {
        plan.riskHighlights
            .filter { !$0.risk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
    var showsChevron: Bool = false

    private var phaseName: String {
        breakdown.phase?.name ?? "Phase \(breakdown.week.weekNumber)"
    }

    private var phaseObjective: String {
        breakdown.phase?.objective ?? breakdown.week.reflectionQuestions.first ?? "Focus on consistent progress."
    }

    private var progress: Double {
        let tasks = breakdown.days.flatMap { $0.tasks }
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { $0.isComplete }.count
        return Double(completed) / Double(tasks.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Week \(breakdown.week.weekNumber)")
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text(breakdown.weekRangeDescription)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
            }

            Text(phaseName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accentBlue)

            Text(phaseObjective)
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
                .lineSpacing(3)

            ProgressView(value: progress) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Spacer()
                    let tasks = breakdown.days.flatMap { $0.tasks }
                    let completed = tasks.filter { $0.isComplete }.count
                    Text("\(completed)/\(tasks.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.textPrimary)
                }
            }
            .progressViewStyle(.linear)
            .tint(Palette.accentBlue)
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
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case summary
        case purpose
        case rally
        case principle(UUID)
        case risk(UUID)
    }

    init(plan: ChallengePlan, onSave: @escaping (ChallengePlan) -> Void) {
        self.plan = plan
        self.onSave = onSave
        _title = State(initialValue: plan.title)
        _summary = State(initialValue: plan.summary ?? plan.primaryGoal)
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
                .focused($focusedField, equals: .title)
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            TextEditor(text: $summary)
                .frame(minHeight: 120)
                .focused($focusedField, equals: .summary)
        }
    }

    private var purposeSection: some View {
        Section("Purpose") {
            TextEditor(text: $purpose)
                .frame(minHeight: 120)
                .focused($focusedField, equals: .purpose)
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
                        .focused($focusedField, equals: .principle(principle.id))
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
            Button(action: addPrinciple) {
                Label("Add Principle", systemImage: "plus.circle")
            }
        }
    }

    private var risksSection: some View {
        Section("Risks Radar") {
            ForEach($risks) { $risk in
                VStack(alignment: .leading, spacing: 12) {
                    Text("Risk")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Momentum drops after week 2", text: $risk.risk, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($focusedField, equals: .risk(risk.id))

                    Text("Likelihood")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Likelihood", selection: $risk.likelihood) {
                        ForEach(RiskItem.Likelihood.allCases, id: \.self) { likelihood in
                            Text(likelihood.rawValue.capitalized).tag(likelihood)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Mitigation")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("How will you counter this?", text: $risk.mitigation, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($focusedField, equals: .risk(risk.id))

                    if risks.count > 1 {
                        HStack {
                            Spacer()
                            Button(role: .destructive) {
                                removeRisk(id: risk.id)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                    Text("Remove Risk")
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Divider()
                        .padding(.top, 4)
                }
                .padding(.vertical, 6)
            }
            Button(action: addRisk) {
                Label("Add Risk", systemImage: "plus.circle")
            }
        }
    }

    private var rallyCrySection: some View {
        Section("Rally Cry") {
            TextEditor(text: $rallyCry)
                .frame(minHeight: 120)
                .focused($focusedField, equals: .rally)
        }
    }

    private func removePrinciple(id: UUID) {
        principles.removeAll { $0.id == id }
        if principles.isEmpty {
            let fallback = EditablePrinciple(text: "")
            principles = [fallback]
            focusedField = .principle(fallback.id)
        }
    }

    private func removeRisk(id: UUID) {
        risks.removeAll { $0.id == id }
        if risks.isEmpty {
            let fallback = EditableRisk(id: UUID(), risk: "", likelihood: .medium, mitigation: "")
            risks = [fallback]
            focusedField = .risk(fallback.id)
        }
    }

    private func addPrinciple() {
        if let empty = principles.first(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            DispatchQueue.main.async {
                focusedField = .principle(empty.id)
            }
            return
        }
        let newPrinciple = EditablePrinciple(text: "")
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            principles.append(newPrinciple)
        }
        DispatchQueue.main.async {
            focusedField = .principle(newPrinciple.id)
        }
    }

    private func addRisk() {
        if let empty = risks.first(where: { $0.risk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.mitigation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            DispatchQueue.main.async {
                focusedField = .risk(empty.id)
            }
            return
        }
        let newRisk = EditableRisk(id: UUID(), risk: "", likelihood: .medium, mitigation: "")
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            risks.append(newRisk)
        }
        DispatchQueue.main.async {
            focusedField = .risk(newRisk.id)
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
        }
        return result
    }
}

private struct WeekOverviewView: View {
    @Environment(ChallengeStore.self) private var store
    var planID: UUID
    var breakdown: WeeklyBreakdown

    @State private var expandedTaskIDs: Set<UUID> = []
    @State private var isEditingTasks = false

    private var plan: ChallengePlan? {
        store.plans.first(where: { $0.id == planID })
    }

    private var currentPhase: ChallengePhase? {
        guard let plan else { return breakdown.phase }
        let range = weekRange
        return plan.phases.first { phase in
            let phaseRange = phase.dayRange.lowerBound..<(phase.dayRange.upperBound)
            return phaseRange.overlaps(range.lowerBound..<(range.upperBound + 1))
        } ?? breakdown.phase
    }

    private var sortedDays: [DailyEntry] {
        latestDays.sorted { $0.dayNumber < $1.dayNumber }
    }

    private var latestDays: [DailyEntry] {
        if let plan {
            return plan.days.filter { weekRange.contains($0.dayNumber) }
        }
        return breakdown.days
    }

    private var weekRange: ClosedRange<Int> {
        let lower = max(1, (breakdown.week.weekNumber - 1) * 7 + 1)
        let upper = min(30, breakdown.week.weekNumber * 7)
        return lower...upper
    }

    private var allTasks: [TaskItem] {
        latestDays.flatMap { $0.tasks }
    }

    private var progress: Double {
        let tasks = allTasks
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { $0.isComplete }.count
        return Double(completed) / Double(tasks.count)
    }

    var body: some View {
        List {
            if let phase = currentPhase {
                Section("Phase") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(phase.name)
                            .font(.headline)
                        Text(phase.objective)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                ProgressView(value: progress) {
                    HStack {
                        Text("Week Progress")
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                        Spacer()
                        Text("\(allTasks.filter { $0.isComplete }.count)/\(allTasks.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
                .progressViewStyle(.linear)
                .tint(Palette.accentBlue)
                .padding(.vertical, 8)
            }

            ForEach(sortedDays) { day in
                Section(header: Text("Day \(day.dayNumber): \(day.theme)")) {
                    if day.tasks.isEmpty {
                        Text("No tasks scheduled.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(day.tasks) { task in
                            WeekTaskRow(
                                task: task,
                                isExpanded: expandedTaskIDs.contains(task.id),
                                onToggleCompletion: {
                                    store.toggleTask(planID: planID, dayNumber: day.dayNumber, taskID: task.id)
                                },
                                onToggleExpanded: {
                                    toggleExpansion(for: task.id)
                                }
                            )
                            .listRowInsets(EdgeInsets())
                            .padding(.vertical, 6)
                            .contextMenu {
                                Button("Edit Task") {
                                    isEditingTasks = true
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Week \(breakdown.week.weekNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit Tasks") {
                    isEditingTasks = true
                }
                .disabled(plan == nil)
            }
        }
        .sheet(isPresented: $isEditingTasks) {
            if let plan {
                EditWeekTasksView(plan: plan, weekRange: weekRange) { updatedPlan in
                    store.update(plan: updatedPlan)
                }
            }
        }
    }

    private func toggleExpansion(for id: UUID) {
        if expandedTaskIDs.contains(id) {
            expandedTaskIDs.remove(id)
        } else {
            expandedTaskIDs.insert(id)
        }
    }
}

private struct WeekTaskRow: View {
    var task: TaskItem
    var isExpanded: Bool
    var onToggleCompletion: () -> Void
    var onToggleExpanded: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                completionButton

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.textPrimary)

                    HStack(spacing: 10) {
                        Text(task.type.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.accentBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Palette.accentBlue.opacity(0.12), in: Capsule())
                        Text("\(task.expectedMinutes) min")
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }

                Spacer()

                Button(action: onToggleExpanded) {
                    Image(systemName: "chevron.down")
                        .rotationEffect(isExpanded ? .degrees(180) : .degrees(0))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(8)
                        .background(Color.secondary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleExpanded()
            }

            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {
                    if !task.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("How to execute")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.textSecondary)
                            Text(task.instructions)
                                .font(.subheadline)
                                .foregroundStyle(Palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !task.definitionOfDone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Definition of done")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.textSecondary)
                            Text(task.definitionOfDone)
                                .font(.subheadline)
                                .foregroundStyle(Palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let metric = task.metric {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Metric")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.textSecondary)
                            Text("\(metric.name) — target \(metric.target) \(metric.unit)")
                                .font(.subheadline)
                                .foregroundStyle(Palette.textPrimary)
                        }
                    }
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
        .padding(.horizontal, 4)
    }

    private var completionButton: some View {
        Button(action: onToggleCompletion) {
            ZStack {
                Circle()
                    .stroke(task.isComplete ? Color.clear : Palette.border, lineWidth: 2)
                    .fill(task.isComplete ? Palette.accentBlue : Color.clear)
                    .frame(width: 30, height: 30)

                if task.isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
            .overlay(
                Circle()
                    .stroke(task.isComplete ? Palette.accentBlue : Color.clear, lineWidth: task.isComplete ? 0 : 0)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isComplete ? "Mark incomplete" : "Mark complete")
    }
}

private struct EditWeekTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ChallengeStore.self) private var store
    var plan: ChallengePlan
    var weekRange: ClosedRange<Int>
    var onSave: (ChallengePlan) -> Void

    @State private var editablePlan: ChallengePlan
    @State private var editedDays: [DailyEntry]

    init(plan: ChallengePlan, weekRange: ClosedRange<Int>, onSave: @escaping (ChallengePlan) -> Void) {
        self.plan = plan
        self.weekRange = weekRange
        self.onSave = onSave
        _editablePlan = State(initialValue: plan)
        let days = plan.days.filter { weekRange.contains($0.dayNumber) }
        _editedDays = State(initialValue: days)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(editedDayBindings(), id: \.wrappedValue.id) { binding in
                    EditableDaySection(day: binding) {
                        addTask(to: binding)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Edit Week Tasks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                }
            }
        }
    }

    private func addTask(to day: Binding<DailyEntry>) {
        let newTask = TaskItem(
            id: UUID(),
            title: "New task",
            type: .build,
            expectedMinutes: 30,
            instructions: "",
            definitionOfDone: "",
            metric: nil,
            tags: [],
            isComplete: false
        )
        day.tasks.wrappedValue.append(newTask)
    }

    private func saveChanges() {
        var planCopy = editablePlan
        planCopy.days = planCopy.days.map { existing in
            if let updated = editedDays.first(where: { $0.dayNumber == existing.dayNumber }) {
                return updated
            }
            return existing
        }
        onSave(planCopy)
        dismiss()
    }

    private func editedDayBindings() -> [Binding<DailyEntry>] {
        $editedDays.indices.map { index in
            $editedDays[index]
        }
    }
}

private struct EditableDaySection: View {
    @Binding var day: DailyEntry
    var onAddTask: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ForEach($day.tasks) { $task in
                EditableTaskCard(task: $task)
            }
            addButton
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Day \(day.dayNumber)")
                    .font(.title3.weight(.semibold))
                Text("\(day.theme) focus")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Text("\(day.tasks.count) task\(day.tasks.count == 1 ? "" : "s")")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.accentBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Palette.accentBlue.opacity(0.12), in: Capsule())
        }
    }

    private var addButton: some View {
        Button(action: onAddTask) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Palette.accentBlue)
                Text("Add Task")
                    .font(.body.weight(.semibold))
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Palette.accentBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct EditableTaskCard: View {
    @Binding var task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleRow
            typeRow
            instructionsRow
            doneRow
            expectedRow
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Task Title")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            TextField("Name this task", text: $task.title)
                .font(.headline)
        }
    }

    private var typeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Type")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            Picker("Type", selection: $task.type) {
                ForEach(TaskItem.TaskType.allCases) { type in
                    Text(type.icon).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var instructionsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Instructions")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            TextField("Describe how to complete this task", text: $task.instructions, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var doneRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Definition of Done")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            TextField("What proves it’s complete?", text: $task.definitionOfDone, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var expectedRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Expected Minutes")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            Stepper(value: $task.expectedMinutes, in: 5...240, step: 5) {
                Text("\(task.expectedMinutes) min")
                    .font(.body.weight(.semibold))
            }
        }
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
