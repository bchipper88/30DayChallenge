import SwiftUI

struct SettingsTabView: View {
    @Environment(ChallengeStore.self) private var store

    var body: some View {
        if let activePlan = store.selectedPlan ?? store.plans.first {
            SettingsView(plan: activePlan)
                .onAppear {
                    if store.selectedPlan == nil {
                        store.select(activePlan)
                    }
                }
        } else {
            NavigationStack {
                VStack(spacing: 16) {
                    Image(systemName: "gearshape")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No project yet")
                        .font(.headline)
                    Text("Create a challenge from the Home tab to configure reminders and data settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .navigationTitle("Settings")
            }
        }
    }
}
