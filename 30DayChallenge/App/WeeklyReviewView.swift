import SwiftUI

struct WeeklyReviewView: View {
    @Environment(ChallengeStore.self) private var store
    var planID: UUID
    @State private var selectedWeek: Int = 1
    @State private var questionAnswers: [String: String] = [:]
    @State private var journalEntries: [UUID: String] = [:]

    private var plan: ChallengePlan? {
        store.plans.first(where: { $0.id == planID })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let plan {
                    weekPicker(plan: plan)
                    ScrollView {
                        VStack(spacing: 24) {
                            if let review = currentReview(in: plan) {
                                evidenceSection(review: review)
                                reflectionSection(review: review)
                                adaptationSection(review: review)
                                journalSection(review: review)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Weekly Glow-Up")
        }
        .onAppear {
            if let plan, let firstWeek = plan.weeklyReviews.first?.weekNumber {
                selectedWeek = firstWeek
            }
        }
    }

    private func weekPicker(plan: ChallengePlan) -> some View {
        Picker("Week", selection: $selectedWeek) {
            ForEach(plan.weeklyReviews) { review in
                Text("Week \(review.weekNumber)").tag(review.weekNumber)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func currentReview(in plan: ChallengePlan) -> WeeklyReview? {
        plan.weeklyReviews.first(where: { $0.weekNumber == selectedWeek })
    }

    private func evidenceSection(review: WeeklyReview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Evidence to Capture", subtitle: "Collect signals of progress")
            ForEach(review.evidenceToCollect, id: \.self) { evidence in
                Label(evidence, systemImage: "camera.aperture")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private func reflectionSection(review: WeeklyReview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Reflection Spark", subtitle: "Journal your insights")
            ForEach(review.reflectionQuestions, id: \.self) { question in
                VStack(alignment: .leading, spacing: 8) {
                    Text(question)
                        .font(.subheadline.weight(.semibold))
                    TextEditor(text: Binding(
                        get: { questionAnswers[question] ?? "" },
                        set: { questionAnswers[question] = $0 }
                    ))
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private func adaptationSection(review: WeeklyReview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Adaptation Rules", subtitle: "If this happens → try that")
            ForEach(review.adaptationRules) { rule in
                VStack(alignment: .leading, spacing: 6) {
                    Text(rule.condition)
                        .font(.subheadline.weight(.semibold))
                    Text(rule.response)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private func journalSection(review: WeeklyReview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Week \(review.weekNumber) Journal", subtitle: "Capture your brightest win")
            TextEditor(text: Binding(
                get: { journalEntries[review.id] ?? "" },
                set: { journalEntries[review.id] = $0 }
            ))
            .frame(minHeight: 160)
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            Button {
                FunFeedback.playSuccessHaptics()
            } label: {
                Label("Save Reflection", systemImage: "sparkles")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 20))
                    .foregroundStyle(.white)
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
