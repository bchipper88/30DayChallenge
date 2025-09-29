import Foundation
import SwiftUI
import UIKit

@MainActor
enum FunFeedback {
    static func playSuccessHaptics() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func playfulMessage(for plan: ChallengePlan) -> String {
        return "Boom! \(plan.title) streak just leveled up!"
    }
}

struct ConfettiOverlay: View {
    var isActive: Bool

    var body: some View {
        Canvas { context, size in
            guard isActive else { return }
            for _ in 0..<60 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let width = CGFloat.random(in: 4...14)
                let height = CGFloat.random(in: 8...18)
                var shape = Path()
                shape.addRoundedRect(in: CGRect(x: x, y: y, width: width, height: height), cornerSize: CGSize(width: 3, height: 3))
                context.fill(shape, with: .color(randomColor()))
            }
        }
        .animation(.easeInOut(duration: 0.6), value: isActive)
        .allowsHitTesting(false)
        .opacity(isActive ? 1 : 0)
    }

    private func randomColor() -> Color {
        [.pink, .orange, .yellow, .mint, .blue, .purple].randomElement() ?? .pink
    }
}
