---
description: "Tasks for Daily Trivia Question & Streak Rewards (app)"
---

# Tasks: Daily Trivia Question & Streak Rewards (app)

**Input**: [spec.md](spec.md), [plan.md](plan.md), and the backend contract `trooth_assessment_backend/specs/002-daily-trivia/contracts/daily-trivia-api.md`

**Tests**: unit tests for the models and API (`MockClient`) and widget tests for the streak view and modal, per constitution Principle VIII.

## Phase 1: Foundational

- [x] T001 Models in `lib/models/daily_trivia.dart`, parsed from the contract shapes. `DailyQuestion.options` holds only the options that are present, and no question type carries the correct option.
- [x] T002 `extension DailyTriviaApi on ApiService` in `lib/services/api/daily_trivia.dart`: `dailyTriviaToday`, `dailyTriviaAnswer`, `dailyTriviaStreak`, `setMyTimezone`. Register the part and import in `lib/services/api_service.dart`. A 409 with detail `question_expired` throws `DailyQuestionExpiredException`.

## Phase 2: US1 + US2, modal and streak (P1) 🎯 MVP

- [x] T003 [US2] `DailyStreakView` in `lib/widgets/daily_streak_view.dart`:
  - flame count and freezes
  - the week row when the streak is under 7, the month calendar from 7
  - next milestone line
  - reward card with copy and shop buttons (US3)
- [x] T004 [US1] `DailyTriviaModal` and `DailyTriviaPrompt` in `lib/widgets/daily_trivia_modal.dart`:
  - load, answer, show the result and the streak
  - on expiry, reload the new day's question
  - `DailyTriviaPrompt.maybeShow` (once per day, only on the top route, silent on failure) and `DailyTriviaPrompt.open` (always)
- [x] T005 [US1] Dashboards:
  - in `_afterTutorial`, run the primer, then `DailyTriviaPrompt.maybeShow`
  - mentor dashboard resume calls it too
  - apprentice dashboard gets a lifecycle observer and calls it on resume

## Phase 3: US3–US6 (P2)

- [x] T006 [US4] In `lib/main.dart` `_handleNotificationTap`, add `daily_trivia` and `daily_trivia_reward` cases that call `DailyTriviaPrompt.open`.
- [x] T007 [US5] Daily Question card in `lib/screens/trivia_home_screen.dart`.
- [x] T007b [US5b] `DailyTriviaProfileCard` in `lib/widgets/daily_trivia_profile_card.dart`, added to `mentor_profile_screen.dart` and `apprentice_profile_screen.dart` above "Need Help?". Tests in `test/daily_trivia_test.dart`.
- [x] T008 [US6] In `SessionController._onSignedIn`, send `FlutterTimezone.getLocalTimezone()` to `setMyTimezone`, best-effort.

## Phase 3b: Feedback from dev testing (2026-10-08)

- [x] T012 [US1] Replace the auto-opening modal with `DailyTriviaPill` (`lib/widgets/daily_trivia_pill.dart`) in both dashboards' floating action button slot. The pill has a once-per-day fading nudge and hides when answered, through `DailyTriviaPrompt.answered`. Remove `DailyTriviaPrompt.maybeShow` and the tutorial-mixin and resume hooks. Tests in `test/daily_trivia_test.dart`.

## Phase 4: Tests & polish

- [x] T009 `test/daily_trivia_test.dart`:
  - model parsing, including no correct option before answering and true/false having 2 options
  - API paths and bodies, and 409 expiry mapping to its exception
  - streak view picks week vs month
  - modal renders chips and options, shows the result after an answer, and survives 1.5× text
- [x] T010 `flutter analyze` and `flutter test` pass; reset the iOS config with `flutter build ios --config-only`.
- [ ] T011 Manual check on dev, once the backend is on dev: launch, resume, push taps, the 7-day switch, a reward code. Use backend `quickstart.md` to seed states.

## Dependencies

T001 → T002 → T003 → T004 → T005–T008 → T009–T011. The backend (spec 002) must be on dev for T011 and in prod before release.
