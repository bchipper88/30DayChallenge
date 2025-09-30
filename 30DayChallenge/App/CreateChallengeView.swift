import SwiftUI

struct CreateChallengeView: View {
    @Environment(ChallengeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ChallengeDraft()
    @State private var isSaving = false
    @State private var selectedAgent: PlanGenerationAgent = .spark
    @FocusState private var isPromptFocused: Bool

    private var isCreateDisabled: Bool {
        isSaving || !draft.isValid
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background
                    .ignoresSafeArea()
                VStack(alignment: .leading, spacing: 24) {
                    headerMessage
                    agentPicker
                    chatBox
                    HelperFooter(isValid: draft.isValid)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("New Challenge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await handleCreate() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isCreateDisabled)
                }
            }
            .task {
                await MainActor.runAfter(0.35) {
                    isPromptFocused = true
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private var headerMessage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tell the assistant what you're plotting")
                .font(.title2.bold())
                .foregroundStyle(Palette.textPrimary)
            Text("Think of this like a chat message. Share your 30-day goal, why it matters, and the specific win you'll celebrate.")
                .font(.callout)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Palette.border, lineWidth: 1)
        )
    }

    private var chatBox: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Palette.border, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 12)
            TextEditor(text: $draft.prompt)
                .focused($isPromptFocused)
                .padding(18)
                .scrollContentBackground(.hidden)
                .font(.body)
                .foregroundColor(Palette.textPrimary)
            if draft.prompt.isEmpty {
                Text(examplePrompt)
                    .foregroundStyle(Palette.textSecondary.opacity(0.7))
                    .font(.body)
                    .padding(22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var examplePrompt: String {
        "Example:\nMy goal is to launch a polished beta for my mindful journaling app.\nI'm doing this because proving demand unlocks runway to keep building.\nI'll celebrate when 15 real users finish the onboarding flow and share feedback."
    }

    @MainActor
    private func handleCreate() async {
        guard !isCreateDisabled else { return }
        isSaving = true
        let success = await store.createPlan(from: draft, agent: selectedAgent)
        isSaving = false
        if success {
            dismiss()
        }
    }
}

private extension CreateChallengeView {
    var agentPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your AI assistant")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 12) {
                ForEach(PlanGenerationAgent.allCases) { agent in
                    AgentChip(agent: agent, isSelected: agent == selectedAgent)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedAgent = agent
                            }
                        }
                }
            }
        }
    }
}

private struct AgentChip: View {
    var agent: PlanGenerationAgent
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(agent.displayName)
                .font(.headline)
                .foregroundStyle(isSelected ? Color.white : Palette.textPrimary)
            Text(agent.descriptor)
                .font(.caption)
                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Palette.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isSelected ? Palette.accentBlue : Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isSelected ? Palette.accentBlue : Palette.border, lineWidth: isSelected ? 0 : 1)
        )
        .shadow(color: Color.black.opacity(isSelected ? 0.1 : 0.03), radius: 16, x: 0, y: 10)
    }
}

private struct HelperFooter: View {
    var isValid: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !isValid {
                Label("Include a goal, the motivation, and a specific outcome so we can draft the plan.", systemImage: "sparkle")
                    .foregroundStyle(Palette.textSecondary)
                    .font(.footnote)
            }
            Text("Tip: Mention numbers or checkpoints (e.g. '15 signups' or 'publish weekly videos') so the daily roadmap feels bespoke.")
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary.opacity(0.8))
        }
    }
}

private extension MainActor {
    static func runAfter(_ delay: TimeInterval, perform action: @escaping () -> Void) async {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        action()
    }
}
