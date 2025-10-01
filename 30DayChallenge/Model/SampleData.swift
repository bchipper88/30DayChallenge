import Foundation
import SwiftUI

enum SampleData {
    static let plan: ChallengePlan = {
        let phases: [ChallengePhase] = [
            ChallengePhase(
                id: UUID(),
                index: 0,
                name: "Kickoff Momentum",
                objective: "Prime your space, schedule, and mindset for a 30-day sprint.",
                milestones: [
                    ChallengeMilestone(
                        id: UUID(),
                        title: "Launch Pad Ready",
                        detail: "Workspace organized, time blocks locked, and accountability buddy invited.",
                        progress: 0.25,
                        targetDay: 3
                    ),
                    ChallengeMilestone(
                        id: UUID(),
                        title: "Vision Locked",
                        detail: "Crystal clear outcome storyboarded with success criteria.",
                        progress: 0.6,
                        targetDay: 6
                    )
                ],
                keyPrinciples: [
                    "Start messy, refine later.",
                    "Default to action over perfection.",
                    "Celebrate tiny wins loudly."
                ],
                risks: [
                    RiskItem(id: UUID(), risk: "Calendar clashes with work", likelihood: .medium, mitigation: "Protect morning power hour with calendar blocks."),
                    RiskItem(id: UUID(), risk: "Motivation dip after day 4", likelihood: .high, mitigation: "Pre-record hype message and schedule reminder.")
                ]
            ),
            ChallengePhase(
                id: UUID(),
                index: 1,
                name: "Build Mode",
                objective: "Stack deliberate practice sessions and ship visible progress.",
                milestones: [
                    ChallengeMilestone(id: UUID(), title: "Prototype Live", detail: "MVP published for feedback.", progress: 0.4, targetDay: 10),
                    ChallengeMilestone(id: UUID(), title: "Feedback Bank", detail: "Collect 5 user insights.", progress: 0.1, targetDay: 14)
                ],
                keyPrinciples: ["Design tight feedback loops.", "Block deep work sprints.", "Stay playful."],
                risks: [
                    RiskItem(id: UUID(), risk: "Scope creep stealing focus", likelihood: .medium, mitigation: "Limit backlog to top 3 weekly bets."),
                    RiskItem(id: UUID(), risk: "Energy dip mid-week", likelihood: .low, mitigation: "Schedule walk + audio pep talk on Day 11.")
                ]
            ),
            ChallengePhase(
                id: UUID(),
                index: 2,
                name: "Amplify & Iterate",
                objective: "Collect signals, iterate boldly, and expand reach.",
                milestones: [
                    ChallengeMilestone(id: UUID(), title: "Glow-Up Update", detail: "Implement top 3 improvements from feedback.", progress: 0.2, targetDay: 18),
                    ChallengeMilestone(id: UUID(), title: "Launch Beta", detail: "Invite 10 users to test full flow.", progress: 0.05, targetDay: 21)
                ],
                keyPrinciples: ["Feedback is candy.", "Reduce friction daily.", "Ship smiles."],
                risks: [
                    RiskItem(id: UUID(), risk: "No feedback responses", likelihood: .medium, mitigation: "Automate reminders + share in community."),
                    RiskItem(id: UUID(), risk: "Burnout warning", likelihood: .low, mitigation: "Plan two recovery micro-retreats.")
                ]
            ),
            ChallengePhase(
                id: UUID(),
                index: 3,
                name: "Victory Lap",
                objective: "Lock the habit, celebrate loudly, and package learnings.",
                milestones: [
                    ChallengeMilestone(id: UUID(), title: "Story Deck", detail: "Summarize journey and key wins.", progress: 0.0, targetDay: 26),
                    ChallengeMilestone(id: UUID(), title: "Final Celebration", detail: "Host live demo or share progress recap.", progress: 0.0, targetDay: 30)
                ],
                keyPrinciples: ["Reflect, don't rush.", "Share gratitude.", "Prepare next quest."],
                risks: [
                    RiskItem(id: UUID(), risk: "Skip celebration", likelihood: .high, mitigation: "Schedule party now + invite squad."),
                    RiskItem(id: UUID(), risk: "Post-challenge slump", likelihood: .medium, mitigation: "Pre-plan next mini challenge.")
                ]
            )
        ]

        let dailyEntries: [DailyEntry] = (1...30).map { day in
            DailyEntry(
                id: UUID(),
                dayNumber: day,
                theme: dailyTheme(for: day),
                tasks: sampleTasks(for: day),
                checkInPrompt: checkInPrompt(for: day),
                celebrationMessage: celebration(for: day)
            )
        }

        let weeklyReviews = (1...4).map { week -> WeeklyReview in
            WeeklyReview(
                id: UUID(),
                weekNumber: week,
                evidenceToCollect: [
                    "Capture a snapshot of your proudest artefact.",
                    "List three signals that you're on track.",
                    "Note one friction to smooth next week."
                ],
                reflectionQuestions: [
                    "What felt energising this week?",
                    "Which milestone moved forward most?",
                    "Where do you want extra support?"
                ],
                adaptationRules: [
                    AdaptationRule(id: UUID(), condition: "If tasks took > 90 minutes twice", response: "Trim tomorrow to a single high-leverage task."),
                    AdaptationRule(id: UUID(), condition: "If streak paused", response: "Use a grace day and schedule a playful catch-up session."),
                    AdaptationRule(id: UUID(), condition: "If motivation dips", response: "Play hype playlist + revisit vision board before next session.")
                ]
            )
        }

        var principleSet = Set<String>()
        var planPrinciples: [String] = []
        for principle in phases.flatMap({ $0.keyPrinciples }) {
            let trimmed = principle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if principleSet.insert(trimmed.lowercased()).inserted {
                planPrinciples.append(trimmed)
            }
            if planPrinciples.count == 5 { break }
        }

        var riskSet = Set<String>()
        var planRisks: [RiskItem] = []
        for risk in phases.flatMap({ $0.risks }) {
            let key = risk.risk.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            if riskSet.insert(key).inserted {
                planRisks.append(risk)
            }
            if planRisks.count == 6 { break }
        }

        return ChallengePlan(
            id: UUID(),
            title: "30-Day Builder Sprint",
            domain: .creative,
            primaryGoal: "Launch a playful micro-product",
            targetOutcome: TargetOutcome(metric: "Beta signups", value: 30, unit: "people", timeframe: "30 days"),
            assumptions: ["You have 60 minutes per day.", "Internet access for research."],
            constraints: ["Weekends lighter workload.", "No budget for ads."],
            resources: ["Notion template", "Figma starter kit", "3 accountability buddies"],
            purpose: "Prove consistency by shipping joyful progress every day for a month.",
            keyPrinciples: planPrinciples,
            riskHighlights: planRisks,
            phases: phases,
            days: dailyEntries,
            weeklyReviews: weeklyReviews,
            reminderRule: ReminderRule(timeOfDay: DateComponents(hour: 8, minute: 30), message: "Time to build today's magic!"),
            celebrationRule: CelebrationRule(trigger: .dayComplete, message: "Smashing it! Confetti unlocked."),
            streakRule: StreakRule(thresholdMinutes: 45, graceDays: 2),
            callToAction: "You are the kind of creator who ships joy. Let's go!",
            accentPalette: GradientDescriptor(stops: [
                GradientStop(hex: "FF7EB3", opacity: 1.0),
                GradientStop(hex: "A855F7", opacity: 1.0),
                GradientStop(hex: "3B82F6", opacity: 1.0)
            ])
        )
    }()

    private static func sampleTasks(for day: Int) -> [TaskItem] {
        let baseMinutes = [35, 45, 50, 40, 30, 55, 60]
        let types: [TaskItem.TaskType] = [.setup, .research, .practice, .build, .review, .reflection, .outreach, .ship]

        return (0..<Int.random(in: 2...3)).map { index in
            TaskItem(
                id: UUID(),
                title: taskTitle(for: day, index: index),
                type: types.randomElement() ?? .practice,
                expectedMinutes: baseMinutes.randomElement() ?? 45,
                instructions: "Focus on one crisp outcome. Time-box and play your pump-up track.",
                definitionOfDone: "Document progress and share a one-sentence win.",
                metric: Metric(name: "Deep Work", unit: "min", target: 45),
                tags: day % 7 == 0 ? ["celebration"] : ["momentum"],
                isComplete: false
            )
        }
    }

    private static func taskTitle(for day: Int, index: Int) -> String {
        switch day % 4 {
        case 0:
            return index == 0 ? "Storyboard customer journey" : "Ship micro-enhancement"
        case 1:
            return index == 0 ? "Warm-up power ritual" : "Research spark nuggets"
        case 2:
            return index == 0 ? "Build playful prototype" : "Record quick demo"
        default:
            return index == 0 ? "Collect feedback love" : "Reflect + brag";
        }
    }

    private static func dailyTheme(for day: Int) -> String {
        let themes = ["Spark", "Build", "Glow", "Celebrate"]
        return themes[(day - 1) % themes.count]
    }

    private static func checkInPrompt(for day: Int) -> String {
        let prompts = [
            "What win are you proud of today?",
            "Which tiny courage move did you make?",
            "What will make tomorrow 1% more joyful?",
            "Who can you thank for the momentum?"
        ]
        return prompts[(day - 1) % prompts.count]
    }

    private static func celebration(for day: Int) -> String {
        day % 7 == 0 ? "Big week! Treat yourself to a mini victory dance." : "High-five! Another brick in your creative castle."
    }
}
