# 30DayChallenge

30DayChallenge is a SwiftUI iOS application that helps users design and stick to structured 30-day challenges. The base build focuses on a clean architecture, vivid interactions, and placeholders for Supabase-backed data sync.

## Architecture Overview

- **Presentation (SwiftUI)**
  - `ChallengeListView`: displays the user's projects with playful gradient cards.
  - `ChallengeDashboardView`: shows phased roadmap, progress rings, and streak momentum.
  - `DailyFocusView`: checklist experience with confetti-ready completion flow.
  - `WeeklyReviewView`: journaling-first UX with adaptive prompts.
  - `SettingsView`: toggles for notifications, data export stubs, and Supabase key management.
- **State Management**
  - `ChallengeStore`: `@Observable` store that loads challenge plans from repositories, manages edits, and drives streak logic.
- **Domain Models** (value types in `Model/`)
  - `ChallengePlan`, `ChallengePhase`, `ChallengeMilestone`, `DailyEntry`, `TaskItem`, `WeeklyReview`, `ReminderRule`, `StreakState`.
  - Models mirror Supabase tables so syncing remains straightforward.
- **Data Layer**
  - `PlanRepository`: protocol describing CRUD, reset, and sync hooks.
  - `InMemoryPlanRepository`: local stub seeded with an LLM-generated sample.
  - `SupabasePlanRepository`: placeholder implementation that will wrap Supabase Swift SDK operations.
  - `NotificationScheduler`: wraps `UNUserNotificationCenter` for reminders.
- **Utilities**
  - `FunFeedback`: confetti, haptics, and celebratory strings.

## Data Flow

1. `ChallengeStore` requests plans from a repository on launch and keeps them in memory.
2. UI layers subscribe via `@StateObject` / `@Environment` to present phases, tasks, and weekly reviews.
3. User interactions (edit, reorder, complete) mutate store state, which is later flushed to Supabase via repository sync.
4. Notifications and streak tracking run inside the store with background-friendly hooks ready for future WorkManager equivalents.

## Current Scope (Base Build)

- Mock plan seeded locally with bright gradients and charismatic milestone copy for a fun first-run experience.
- Comprehensive Swift models matching the product requirements.
- SwiftUI screens wired with sample data and navigation between core flows.
- Stubbed Supabase service with clearly marked TODOs for credential wiring and API calls.
- App storage ready for offline caching via `FileManager` JSON persistence (placeholder implementation).

## Next Steps

1. Wire Supabase Swift SDK to `SupabasePlanRepository` and auth flows.
2. Implement real notification scheduling and streak persistence.
3. Add edit surfaces (drag-and-drop reordering, forms) and change logging.
4. Replace mock data with LLM-generated plan ingestion and validation.

