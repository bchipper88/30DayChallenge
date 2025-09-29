import Foundation
import SwiftUI

struct ParsedPrompt {
    var goal: String
    var motivation: String
    var win: String
}

struct ChallengeDraft {
    var domain: ChallengeDomain = .other
    var prompt: String = ""
    var reminderTime: Date = ChallengeDraft.defaultReminderTime
    var streakMinutes: Int = 45

    private static var defaultReminderTime: Date {
        Calendar.current.date(from: DateComponents(hour: 8, minute: 30)) ?? Date()
    }

    var isValid: Bool {
        !trimmedPrimaryGoal.isEmpty
            && !trimmedCoreMotivation.isEmpty
            && !trimmedSpecificWin.isEmpty
    }

    private var parsedPrompt: ParsedPrompt {
        ChallengePlanFactory.extractSegments(from: prompt)
    }

    var trimmedPrimaryGoal: String { parsedPrompt.goal }
    var trimmedCoreMotivation: String { parsedPrompt.motivation }
    var trimmedSpecificWin: String { parsedPrompt.win }
}

enum ChallengePlanFactory {
    static func makePlan(from draft: ChallengeDraft) -> ChallengePlan {
        let goal = draft.trimmedPrimaryGoal
        let title = goal.isEmpty ? "New 30-Day Challenge" : goal
        let motivation = draft.trimmedCoreMotivation
        let specific = draft.trimmedSpecificWin
        let outcome = parsedOutcome(from: specific)

        let targetOutcome = TargetOutcome(
            metric: outcome.metric,
            value: outcome.value,
            unit: outcome.unit,
            timeframe: "30 days"
        )

        return ChallengePlan(
            id: UUID(),
            title: title,
            domain: draft.domain,
            primaryGoal: goal,
            targetOutcome: targetOutcome,
            assumptions: assumptions(for: draft),
            constraints: constraints(for: draft),
            resources: resources(),
            phases: makePhases(goal: goal),
            days: makeDays(goal: goal, metric: outcome.metric, unit: outcome.unit, target: outcome.value, streakMinutes: draft.streakMinutes),
            weeklyReviews: makeWeeklyReviews(goal: goal),
            reminderRule: reminderRule(for: draft, title: title),
            celebrationRule: CelebrationRule(trigger: .dayComplete, message: "Momentum unlocked! Celebrate the win."),
            streakRule: StreakRule(thresholdMinutes: draft.streakMinutes, graceDays: 2),
            callToAction: defaultCallToAction(for: goal, motivation: motivation),
            accentPalette: palette(for: draft.domain)
        )
    }

    static func extractSegments(from prompt: String) -> ParsedPrompt {
        var goal = ""
        var motivation = ""
        var win = ""

        let cleanedLines = prompt
            .replacingOccurrences(of: "\r", with: "")
            .components(separatedBy: CharacterSet.newlines)
            .flatMap { $0.components(separatedBy: "\u{2028}") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in cleanedLines {
            if goal.isEmpty, let value = extractValue(from: line, kind: .goal) {
                goal = value
                continue
            }
            if motivation.isEmpty, let value = extractValue(from: line, kind: .motivation) {
                motivation = value
                continue
            }
            if win.isEmpty, let value = extractValue(from: line, kind: .win) {
                win = value
                continue
            }
        }

        if goal.isEmpty || motivation.isEmpty || win.isEmpty {
            let sentenceSeparators = CharacterSet(charactersIn: ".!?")
            let sentences = cleanedLines
                .flatMap { line -> [String] in
                    line.components(separatedBy: sentenceSeparators)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                }
                .filter { !$0.isEmpty }

            if goal.isEmpty, let first = sentences.first {
                goal = first
            }
            if motivation.isEmpty, let next = sentences.dropFirst().first {
                motivation = next
            }
            if win.isEmpty, let final = sentences.dropFirst(2).first {
                win = final
            }
        }

        if motivation.isEmpty {
            motivation = defaultMotivationFallback(from: prompt)
        }
        if win.isEmpty {
            win = defaultWinFallback(from: goal)
        }

        return ParsedPrompt(goal: goal.trimmingCharacters(in: .whitespacesAndNewlines),
                            motivation: motivation.trimmingCharacters(in: .whitespacesAndNewlines),
                            win: win.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private enum SegmentKind { case goal, motivation, win }

    private static let goalKeywords: [String] = ["goal", "primary goal", "my goal", "objective", "aim"]
    private static let motivationKeywords: [String] = ["motivation", "why", "purpose", "reason", "because", "so that"]
    private static let winKeywords: [String] = ["specific win", "win", "target", "celebrate", "success", "specific", "milestone"]

    private static func extractValue(from line: String, kind: SegmentKind) -> String? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmedLine.lowercased()
        let keys: [String]
        switch kind {
        case .goal: keys = goalKeywords
        case .motivation: keys = motivationKeywords
        case .win: keys = winKeywords
        }

        for key in keys {
            let colonPrefix = "\(key):"
            if lower.hasPrefix(colonPrefix) {
                return trimmedLine.dropFirst(colonPrefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let dashPrefix = "\(key) -"
            if lower.hasPrefix(dashPrefix) {
                return trimmedLine.dropFirst(dashPrefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if let range = trimmedLine.range(of: "\(key) is", options: [.caseInsensitive]) {
                let substring = trimmedLine[range.upperBound...]
                return substring.trimmingCharacters(in: CharacterSet(charactersIn: ":- "))
            }
        }

        switch kind {
        case .goal:
            if lower.hasPrefix("my goal is") {
                return trimmedLine.dropFirst("My goal is".count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if lower.hasPrefix("i want to") {
                return trimmedLine.dropFirst("I want to".count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if lower.hasPrefix("i'm aiming to") {
                return trimmedLine.dropFirst("I'm aiming to".count).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        case .motivation:
            if let range = trimmedLine.range(of: "because", options: [.caseInsensitive]) {
                let substring = trimmedLine[range.upperBound...]
                return substring.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let range = trimmedLine.range(of: "so that", options: [.caseInsensitive]) {
                let substring = trimmedLine[range.upperBound...]
                return substring.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        case .win:
            if let range = trimmedLine.range(of: "I'll know I've succeeded when", options: [.caseInsensitive]) {
                let substring = trimmedLine[range.upperBound...]
                return substring.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let range = trimmedLine.range(of: "I'll celebrate when", options: [.caseInsensitive]) {
                let substring = trimmedLine[range.upperBound...]
                return substring.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    private static func defaultMotivationFallback(from prompt: String) -> String {
        if let range = prompt.range(of: "because", options: [.caseInsensitive]) {
            let substring = prompt[range.upperBound...]
            return substring.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Because momentum today unlocks bigger bets tomorrow."
    }

    private static func defaultWinFallback(from goal: String) -> String {
        guard !goal.isEmpty else { return "Celebrate completing this 30-day streak." }
        return "Celebrate shipping a visible milestone toward \(goal)."
    }

    private static func parsedOutcome(from specific: String) -> (metric: String, value: Double, unit: String) {
        let trimmed = specific.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (metric: "Momentum", value: 1, unit: "milestone")
        }

        let scanner = Scanner(string: trimmed)
        if let value = scanner.scanDouble() {
            let remainder = trimmed[scanner.currentIndex...]
            let unit = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
            return (metric: trimmed, value: value, unit: unit.isEmpty ? "target" : unit)
        }

        return (metric: trimmed, value: 1, unit: "milestone")
    }

    private static func assumptions(for draft: ChallengeDraft) -> [String] {
        [
            "Dedicate \(draft.streakMinutes) focused minutes each day.",
            "Capture one insight after every session to cement learning.",
            "Share weekly progress with someone you trust."
        ]
    }

    private static func constraints(for draft: ChallengeDraft) -> [String] {
        [
            "Keep sessions under \(draft.streakMinutes + 15) minutes to stay sustainable.",
            "Reserve one lighter recovery day each week.",
            "Avoid spinning up new initiatives until this challenge wraps."
        ]
    }

    private static func resources() -> [String] {
        [
            "Daily reflection log",
            "Accountability buddy or community check-in",
            "Calendar blocks for deep work",
            "Visible progress tracker"
        ]
    }

    private static func reminderRule(for draft: ChallengeDraft, title: String) -> ReminderRule {
        let components = Calendar.current.dateComponents([.hour, .minute], from: draft.reminderTime)
        let focusTitle = title.isEmpty ? "your challenge" : title
        return ReminderRule(timeOfDay: components, message: "Time to advance \(focusTitle).")
    }

    private static func defaultCallToAction(for goal: String, motivation: String) -> String {
        if !motivation.isEmpty {
            return motivation
        }
        let focus = focusGoal(goal)
        return "Every rep compounds—let's keep \(focus) moving."
    }

    private static func makePhases(goal: String) -> [ChallengePhase] {
        let descriptive = descriptiveGoal(goal)
        let focus = focusGoal(goal)

        let blueprints: [(name: String, objective: String, milestones: [(String, String, Int)], principles: [String], risks: [(String, RiskItem.Likelihood, String)])] = [
            (
                name: "Launch Pad",
                objective: "Clarify direction and prepare the systems that make \(focus) inevitable.",
                milestones: [
                    ("Vision Blueprint", "Write what success looks like for \(descriptive).", 3),
                    ("Daily Ritual Locked", "Protect a consistent work block and kickoff ritual.", 6)
                ],
                principles: [
                    "Plan the minimum viable win for each day.",
                    "Make progress visible in your workspace.",
                    "Default to starting before you feel ready."
                ],
                risks: [
                    ("Unclear definition of done", .medium, "Write a short success statement and share it with someone on day 2."),
                    ("Schedule friction", .medium, "Book recurring calendar blocks and set reminders.")
                ]
            ),
            (
                name: "Build Momentum",
                objective: "Ship visible slices of progress and collect early signals.",
                milestones: [
                    ("First tangible output", "Deliver something concrete that proves \(focus) is underway.", 10),
                    ("Feedback loop live", "Collect at least one real signal or response.", 14)
                ],
                principles: [
                    "Prioritise moves that create feedback.",
                    "Stack small deliverables into bigger wins.",
                    "Close the loop on commitments daily."
                ],
                risks: [
                    ("Scope creep sneaks in", .medium, "Keep a 'later' list and limit the week to three priorities."),
                    ("Energy dip mid-challenge", .high, "Pair deep work with a restorative ritual each evening.")
                ]
            ),
            (
                name: "Refine & Amplify",
                objective: "Iterate with confidence and make the work easier to share.",
                milestones: [
                    ("Iterated version live", "Implement the top improvements you discovered.", 20),
                    ("Story worth sharing", "Extract a story, case study, or demo to showcase progress.", 23)
                ],
                principles: [
                    "Seek critical feedback early.",
                    "Optimise for clarity over polish.",
                    "Remove friction for future-you."
                ],
                risks: [
                    ("Feedback backlog grows", .medium, "Triage insights every 3 days and action one immediately."),
                    ("Perfectionism stalls progress", .high, "Ship a version daily even if it's rough.")
                ]
            ),
            (
                name: "Celebrate & Sustain",
                objective: "Land the win, document lessons, and set up the next iteration.",
                milestones: [
                    ("Retrospective complete", "Document what worked, what didn't, and next experiments.", 27),
                    ("Celebration moment", "Share the story, thank collaborators, and define the sequel.", 30)
                ],
                principles: [
                    "Celebrate wins loudly.",
                    "Teach what you learned to lock it in.",
                    "Decide the next move before momentum fades."
                ],
                risks: [
                    ("Skipping celebration", .high, "Schedule a celebration now and invite someone who cheered you on."),
                    ("Post-challenge slump", .medium, "Line up a mini follow-up challenge before day 30.")
                ]
            )
        ]

        return blueprints.enumerated().map { index, blueprint in
            let milestones = blueprint.milestones.map { title, detail, day in
                ChallengeMilestone(
                    id: UUID(),
                    title: title,
                    detail: detail,
                    progress: 0,
                    targetDay: day
                )
            }

            let risks = blueprint.risks.map { description, likelihood, mitigation in
                RiskItem(
                    id: UUID(),
                    risk: description,
                    likelihood: likelihood,
                    mitigation: mitigation
                )
            }

            return ChallengePhase(
                id: UUID(),
                index: index,
                name: blueprint.name,
                objective: blueprint.objective,
                milestones: milestones,
                keyPrinciples: blueprint.principles,
                risks: risks
            )
        }
    }

    private static func makeDays(goal: String, metric: String, unit: String, target: Double, streakMinutes: Int) -> [DailyEntry] {
        let focus = focusGoal(goal)
        let prompts = [
            "What tiny win pushed \(focus) forward today?",
            "Where did you feel resistance while working on \(focus)?",
            "What support would make tomorrow smoother for \(focus)?",
            "Which moment made you proud about \(focus) today?"
        ]
        let celebrations = [
            "Brick placed! These reps compound.",
            "Momentum rising—keep stacking the streak.",
            "You showed up. That consistency is the superpower.",
            "Victory lap moment. Honor the effort."
        ]
        let taskTitles = [
            "Prime today's focus",
            "Tackle the core move",
            "Share a signal",
            "Reflect and reset"
        ]
        let taskTypes: [TaskItem.TaskType] = [.setup, .build, .outreach, .practice, .review, .reflection, .ship, .research]
        let reflectionMinutes = max(10, min(20, streakMinutes / 3))
        let metricDescriptor = Metric(name: metric.isEmpty ? "Progress" : metric, unit: unit.isEmpty ? "target" : unit, target: target == 0 ? 1 : target)

        return (1...30).map { day in
            let theme = ["Ignite", "Build", "Refine", "Amplify", "Celebrate"][(day - 1) % 5]
            let prompt = prompts[(day - 1) % prompts.count]
            let celebration = celebrations[(day - 1) % celebrations.count]
            let primaryType = taskTypes[(day - 1) % taskTypes.count]
            let primaryTitle = taskTitles[(day - 1) % taskTitles.count]

            let focusTask = TaskItem(
                id: UUID(),
                title: "\(primaryTitle) for \(focus)",
                type: primaryType,
                expectedMinutes: streakMinutes,
                instructions: "Use this block to advance \(focus) without distractions.",
                definitionOfDone: "Ship one tangible outcome or insight toward \(focus).",
                metric: metricDescriptor,
                tags: ["momentum", primaryType.rawValue],
                isComplete: false
            )

            let reflectionTask = TaskItem(
                id: UUID(),
                title: "Log insights and prime tomorrow",
                type: .reflection,
                expectedMinutes: reflectionMinutes,
                instructions: "Note what worked, what felt heavy, and tee up the first move for tomorrow.",
                definitionOfDone: "Record at least one insight and one next step.",
                metric: nil,
                tags: ["reflection"],
                isComplete: false
            )

            return DailyEntry(
                id: UUID(),
                dayNumber: day,
                theme: theme,
                tasks: [focusTask, reflectionTask],
                checkInPrompt: prompt,
                celebrationMessage: celebration
            )
        }
    }

    private static func makeWeeklyReviews(goal: String) -> [WeeklyReview] {
        let focus = focusGoal(goal)
        let descriptive = descriptiveGoal(goal)
        return (1...4).map { week in
            WeeklyReview(
                id: UUID(),
                weekNumber: week,
                evidenceToCollect: [
                    "Capture a snapshot or note that proves progress on \(descriptive).",
                    "List the most energising moment from the week.",
                    "Identify one friction to smooth for the next sprint."
                ],
                reflectionQuestions: [
                    "Which action moved \(focus) forward the most?",
                    "What habit is working? What needs a tweak?",
                    "Where can you reduce friction next week?"
                ],
                adaptationRules: [
                    AdaptationRule(id: UUID(), condition: "If you missed two sessions", response: "Use a grace day, shrink tomorrow's scope, and recommit to the ritual."),
                    AdaptationRule(id: UUID(), condition: "If progress feels flat", response: "Ask for feedback, define a smaller win, and celebrate completion."),
                    AdaptationRule(id: UUID(), condition: "If energy is low", response: "Swap one block for active recovery and prep a lighter task.")
                ]
            )
        }
    }

    private static func palette(for domain: ChallengeDomain) -> GradientDescriptor {
        switch domain {
        case .fitness:
            return gradient(["FF6B6B", "FF9E80", "FAD02E"])
        case .business:
            return gradient(["1D4ED8", "2563EB", "38BDF8"])
        case .learning:
            return gradient(["8B5CF6", "6366F1", "22D3EE"])
        case .creative:
            return gradient(["F472B6", "C084FC", "818CF8"])
        case .productivity:
            return gradient(["34D399", "10B981", "0EA5E9"])
        case .finance:
            return gradient(["FACC15", "F97316", "F59E0B"])
        case .wellbeing:
            return gradient(["F59E0B", "FDE68A", "34D399"])
        case .other:
            return gradient(["94A3B8", "818CF8", "38BDF8"])
        }
    }

    private static func gradient(_ hexes: [String]) -> GradientDescriptor {
        GradientDescriptor(stops: hexes.map { GradientStop(hex: $0, opacity: 1.0) })
    }

    private static func descriptiveGoal(_ goal: String) -> String {
        goal.isEmpty ? "this challenge" : goal
    }

    private static func focusGoal(_ goal: String) -> String {
        goal.isEmpty ? "your challenge" : goal.lowercased()
    }
}
