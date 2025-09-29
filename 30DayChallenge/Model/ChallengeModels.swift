import Foundation
import SwiftUI

// MARK: - Domain Types

enum ChallengeDomain: String, Codable, CaseIterable, Identifiable {
    case fitness, business, learning, creative, productivity, finance, wellbeing, other

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

struct TargetOutcome: Codable, Hashable {
    var metric: String
    var value: Double
    var unit: String
    var timeframe: String
}

struct ChallengePlan: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var domain: ChallengeDomain
    var primaryGoal: String
    var targetOutcome: TargetOutcome
    var assumptions: [String]
    var constraints: [String]
    var resources: [String]
    var phases: [ChallengePhase]
    var days: [DailyEntry]
    var weeklyReviews: [WeeklyReview]
    var reminderRule: ReminderRule
    var celebrationRule: CelebrationRule
    var streakRule: StreakRule
    var callToAction: String
    var accentPalette: GradientDescriptor

    var accentColors: [Color] {
        accentPalette.colors
    }

    var shortSummary: String {
        "\(domain.displayName): \(primaryGoal)"
    }
}

struct ChallengePhase: Codable, Identifiable, Hashable {
    var id: UUID
    var index: Int
    var name: String
    var objective: String
    var milestones: [ChallengeMilestone]
    var keyPrinciples: [String]
    var risks: [RiskItem]

    var dayRange: Range<Int> {
        switch index {
        case 0: return 1..<8
        case 1: return 8..<15
        case 2: return 15..<22
        default: return 22..<31
        }
    }
}

struct MilestoneTaskGroup: Identifiable, Hashable {
    var milestone: ChallengeMilestone
    var days: [DailyEntry]
    var id: UUID { milestone.id }
}

struct ChallengeMilestone: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var detail: String
    var progress: Double
    var targetDay: Int
}

struct RiskItem: Codable, Identifiable, Hashable {
    var id: UUID
    var risk: String
    var likelihood: Likelihood
    var mitigation: String

    enum Likelihood: String, Codable, CaseIterable {
        case low, medium, high

        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }
    }
}

struct DailyEntry: Codable, Identifiable, Hashable {
    var id: UUID
    var dayNumber: Int
    var theme: String
    var tasks: [TaskItem]
    var checkInPrompt: String
    var celebrationMessage: String

    var displayTitle: String {
        "Day \(dayNumber): \(theme)"
    }
}

struct TaskItem: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var type: TaskType
    var expectedMinutes: Int
    var instructions: String
    var definitionOfDone: String
    var metric: Metric?
    var tags: [String]
    var isComplete: Bool

    enum TaskType: String, Codable, CaseIterable, Identifiable {
        case setup, research, practice, review, reflection, outreach, build, ship

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .setup: return "Setup"
            case .research: return "Research"
            case .practice: return "Practice"
            case .review: return "Review"
            case .reflection: return "Reflect"
            case .outreach: return "Outreach"
            case .build: return "Build"
            case .ship: return "Ship"
            }
        }
    }
}

struct Metric: Codable, Hashable {
    var name: String
    var unit: String
    var target: Double
}

struct WeeklyReview: Codable, Identifiable, Hashable {
    var id: UUID
    var weekNumber: Int
    var evidenceToCollect: [String]
    var reflectionQuestions: [String]
    var adaptationRules: [AdaptationRule]
}

struct AdaptationRule: Codable, Identifiable, Hashable {
    var id: UUID
    var condition: String
    var response: String
}

struct ReminderRule: Codable, Hashable {
    var timeOfDay: DateComponents
    var message: String
}

struct CelebrationRule: Codable, Hashable {
    var trigger: CelebrationTrigger
    var message: String

    enum CelebrationTrigger: String, Codable {
        case dayComplete
        case milestoneComplete
    }
}

struct StreakRule: Codable, Hashable {
    var thresholdMinutes: Int
    var graceDays: Int
}

struct StreakState: Codable, Hashable {
    var current: Int
    var longest: Int
    var lastCompletedDay: Int?
}

extension ChallengePlan {
    func phase(forDay dayNumber: Int) -> ChallengePhase? {
        phases.first { $0.dayRange.contains(dayNumber) }
    }

    func milestone(forDay dayNumber: Int) -> ChallengeMilestone? {
        guard let phase = phase(forDay: dayNumber) else { return nil }
        let milestones = phase.milestones.sorted { $0.targetDay < $1.targetDay }
        for milestone in milestones where dayNumber <= milestone.targetDay {
            return milestone
        }
        return milestones.last
    }

    func milestoneTaskGroups() -> [MilestoneTaskGroup] {
        var groups: [UUID: MilestoneTaskGroup] = [:]
        let sortedDays = days.sorted { $0.dayNumber < $1.dayNumber }
        for day in sortedDays {
            guard let milestone = milestone(forDay: day.dayNumber) else { continue }
            if var existing = groups[milestone.id] {
                existing.days.append(day)
                groups[milestone.id] = existing
            } else {
                groups[milestone.id] = MilestoneTaskGroup(milestone: milestone, days: [day])
            }
        }
        return groups.values.sorted { $0.milestone.targetDay < $1.milestone.targetDay }
    }
    func milestoneProgress(for milestoneID: UUID) -> Double {
        phases
            .flatMap { $0.milestones }
            .first { $0.id == milestoneID }?
            .progress ?? 0
    }

    func day(for number: Int) -> DailyEntry? {
        days.first(where: { $0.dayNumber == number })
    }
}

struct GradientDescriptor: Codable, Hashable {
    var stops: [GradientStop]

    var colors: [Color] {
        stops.map { $0.color }
    }
}

struct GradientStop: Codable, Hashable {
    var hex: String
    var opacity: Double

    var color: Color {
        Color(hex: hex, opacity: opacity)
    }
}

extension Color {
    init(hex: String, opacity: Double = 1.0) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: Double
        switch cleaned.count {
        case 3:
            r = Double((int >> 8) & 0xF) / 15.0
            g = Double((int >> 4) & 0xF) / 15.0
            b = Double(int & 0xF) / 15.0
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0.91
            g = 0.27
            b = 0.58
        }
        self.init(red: r, green: g, blue: b, opacity: opacity)
    }
}
