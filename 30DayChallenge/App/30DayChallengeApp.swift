import SwiftUI

@main
struct ThirtyDayChallengeApp: App {
    @State private var store = ChallengeStore()

    var body: some Scene {
        WindowGroup {
            ZStack {
                Palette.background
                    .ignoresSafeArea()
                RootView()
                    .environment(store)
            }
        }
    }
}

struct RootView: View {
    @Environment(ChallengeStore.self) private var store

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Summoning your challenge magic...")
                    .progressViewStyle(.circular)
            } else {
                FunShellView()
            }
        }
    }
}

struct FunShellView: View {
    @Environment(ChallengeStore.self) private var store
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ChallengeListView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                TaskOverviewView()
                    .tabItem { Label("My Tasks", systemImage: "checkmark.square") }
                    .tag(1)

                SettingsTabView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(2)
            }
            .accentColor(.pink)

            ConfettiOverlay(isActive: store.showConfetti)
                .ignoresSafeArea()
                .transition(.opacity)
                .overlay(alignment: .top) {
                    if let message = store.celebrationMessage, store.showConfetti {
                        CelebrationBanner(message: message)
                            .padding(.top, 40)
                    }
                }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.4), value: store.showConfetti)
    }
}

struct CelebrationBanner: View {
    var message: String

    var body: some View {
        Text(message)
            .font(.title3.weight(.bold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(LinearGradient(colors: [.pink, .purple, .blue], startPoint: .leading, endPoint: .trailing), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
