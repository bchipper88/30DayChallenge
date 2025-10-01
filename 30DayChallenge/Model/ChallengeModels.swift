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
    var createdAt: Date = Date()
    var targetOutcome: TargetOutcome
    var assumptions: [String]
    var constraints: [String]
    var resources: [String]
    var purpose: String?
    var keyPrinciples: [String]
    var riskHighlights: [RiskItem]
    var phases: [ChallengePhase]
    var days: [DailyEntry]
    var weeklyReviews: [WeeklyReview]
    var reminderRule: ReminderRule
    var celebrationRule: CelebrationRule
    var streakRule: StreakRule
    var callToAction: String
    var accentPalette: GradientDescriptor
    var summary: String?

    var accentColors: [Color] {
        accentPalette.colors
    }

    var shortSummary: String {
        "\(domain.displayName): \(primaryGoal)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case domain
        case primaryGoal
        case createdAt
        case targetOutcome
        case assumptions
        case constraints
        case resources
        case purpose
        case keyPrinciples
        case riskHighlights
        case phases
        case days
        case weeklyReviews
        case reminderRule
        case celebrationRule
        case streakRule
        case callToAction
        case accentPalette
        case summary
    }

    init(
        id: UUID,
        title: String,
        domain: ChallengeDomain,
        primaryGoal: String,
        createdAt: Date = Date(),
        targetOutcome: TargetOutcome,
        assumptions: [String],
        constraints: [String],
        resources: [String],
        purpose: String?,
        keyPrinciples: [String],
        riskHighlights: [RiskItem],
        phases: [ChallengePhase],
        days: [DailyEntry],
        weeklyReviews: [WeeklyReview],
        reminderRule: ReminderRule,
        celebrationRule: CelebrationRule,
        streakRule: StreakRule,
        callToAction: String,
        accentPalette: GradientDescriptor,
        summary: String? = nil
    ) {
        self.id = id
        self.title = title
        self.domain = domain
        self.primaryGoal = primaryGoal
        self.createdAt = createdAt
        self.targetOutcome = targetOutcome
        self.assumptions = assumptions
        self.constraints = constraints
        self.resources = resources
        self.purpose = Self.normalizePurpose(purpose, assumptions: assumptions)
        self.keyPrinciples = Self.normalizePrinciples(keyPrinciples)
        self.riskHighlights = Self.normalizeRisks(riskHighlights)
        self.phases = phases
        self.days = days
        self.weeklyReviews = weeklyReviews
        self.reminderRule = reminderRule
        self.celebrationRule = celebrationRule
        self.streakRule = streakRule
        self.callToAction = callToAction
        self.accentPalette = accentPalette
        self.summary = summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decode(UUID.self, forKey: .id)
        let title = try container.decode(String.self, forKey: .title)
        let domain = try container.decode(ChallengeDomain.self, forKey: .domain)
        let primaryGoal = try container.decode(String.self, forKey: .primaryGoal)
        let targetOutcome = try container.decode(TargetOutcome.self, forKey: .targetOutcome)
        let assumptions = try container.decode([String].self, forKey: .assumptions)
        let constraints = try container.decode([String].self, forKey: .constraints)
        let resources = try container.decode([String].self, forKey: .resources)
        let purpose = try container.decodeIfPresent(String.self, forKey: .purpose)
        let phases = try container.decode([ChallengePhase].self, forKey: .phases)
        let providedKeyPrinciples = try container.decodeIfPresent([String].self, forKey: .keyPrinciples)
        let providedRiskHighlights = try container.decodeIfPresent([RiskItem].self, forKey: .riskHighlights)
        let days = try container.decode([DailyEntry].self, forKey: .days)
        let weeklyReviews = try container.decode([WeeklyReview].self, forKey: .weeklyReviews)
        let reminderRule = try container.decode(ReminderRule.self, forKey: .reminderRule)
        let celebrationRule = try container.decode(CelebrationRule.self, forKey: .celebrationRule)
        let streakRule = try container.decode(StreakRule.self, forKey: .streakRule)
        let callToAction = try container.decode(String.self, forKey: .callToAction)
        let accentPalette = try container.decode(GradientDescriptor.self, forKey: .accentPalette)
        let summary = try container.decodeIfPresent(String.self, forKey: .summary)

        var createdAtDate = Date()
        if let date = try? container.decode(Date.self, forKey: .createdAt) {
            createdAtDate = date
        } else if let timestamp = try? container.decode(Double.self, forKey: .createdAt) {
            createdAtDate = Date(timeIntervalSince1970: timestamp)
        } else if let iso = try? container.decode(String.self, forKey: .createdAt),
                  let parsed = ISO8601DateFormatter().date(from: iso) {
            createdAtDate = parsed
        }

        self.init(
            id: id,
            title: title,
            domain: domain,
            primaryGoal: primaryGoal,
            createdAt: createdAtDate,
            targetOutcome: targetOutcome,
            assumptions: assumptions,
            constraints: constraints,
            resources: resources,
            purpose: purpose,
            keyPrinciples: providedKeyPrinciples ?? phases.flatMap { $0.keyPrinciples },
            riskHighlights: providedRiskHighlights ?? phases.flatMap { $0.risks },
            phases: phases,
            days: days,
            weeklyReviews: weeklyReviews,
            reminderRule: reminderRule,
            celebrationRule: celebrationRule,
            streakRule: streakRule,
            callToAction: callToAction,
            accentPalette: accentPalette,
            summary: summary
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(domain, forKey: .domain)
        try container.encode(primaryGoal, forKey: .primaryGoal)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(targetOutcome, forKey: .targetOutcome)
        try container.encode(assumptions, forKey: .assumptions)
        try container.encode(constraints, forKey: .constraints)
        try container.encode(resources, forKey: .resources)
        try container.encodeIfPresent(purpose, forKey: .purpose)
        try container.encode(keyPrinciples, forKey: .keyPrinciples)
        try container.encode(riskHighlights, forKey: .riskHighlights)
        try container.encode(phases, forKey: .phases)
        try container.encode(days, forKey: .days)
        try container.encode(weeklyReviews, forKey: .weeklyReviews)
        try container.encode(reminderRule, forKey: .reminderRule)
        try container.encode(celebrationRule, forKey: .celebrationRule)
        try container.encode(streakRule, forKey: .streakRule)
        try container.encode(callToAction, forKey: .callToAction)
        try container.encode(accentPalette, forKey: .accentPalette)
        try container.encodeIfPresent(summary, forKey: .summary)
    }

    private static func normalizePrinciples(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !value.isEmpty {
            if seen.insert(value.lowercased()).inserted {
                result.append(value)
            }
        }
        return result
    }

    private static func normalizeRisks(_ values: [RiskItem]) -> [RiskItem] {
        var seen = Set<String>()
        var result: [RiskItem] = []
        for value in values {
            let normalized = value.risk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            if seen.insert(normalized.lowercased()).inserted {
                result.append(value)
            }
        }
        return result
    }

    private static func normalizePurpose(_ rawValue: String?, assumptions: [String]) -> String? {
        if let raw = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw
        }

        if let assumptionLine = assumptions.first(where: { $0.lowercased().hasPrefix("purpose:") }) {
            let trimmed = assumptionLine.dropFirst("Purpose:".count)
            let value = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }

        return nil
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
