# Implementation Plan: Daily Trivia Question & Streak Rewards (app)

**Branch**: `feature/daily-trivia` | **Date**: 2026-10-08 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-daily-trivia/spec.md`

## Summary

- **API layer**: a `DailyTriviaApi` extension on `ApiService` and typed models parsed from the backend 002 contract.
- **Widgets**: a `DailyTriviaModal` (question, result, streak), a `DailyStreakView` (week row under 7 days, month calendar from 7, milestone and reward card), and a `DailyTriviaPrompt` helper that decides when the modal opens on its own.
- **Dashboards**: they call the prompt after the existing tutorial and notification-primer step, and again when the app resumes.
- **Other entry points**: the notification taps in `main.dart` open the modal, and a Daily Question card on Trivia home.
- **Timezone**: `SessionController` sends the device timezone after sign-in.

## Technical Context

**Language/Version**: Dart / Flutter (version pinned in `.github/workflows/release.yml`)

**Primary Dependencies**: existing only. `flutter_timezone` (already used by `PrayerReminderService`) for the IANA name, `shared_preferences` for the once-per-day flag, `url_launcher` for the shop, `flutter/services` for the clipboard. **No new packages.**

**Backend Endpoints**: `GET /trivia/daily/today`, `POST /trivia/daily/today/answer`, `GET /trivia/daily/streak`, `PUT /users/me/timezone`. Contract: `trooth_assessment_backend/specs/002-daily-trivia/contracts/daily-trivia-api.md`.

**Storage**: backend API; `shared_preferences` key `daily_trivia_prompted_<yyyy-mm-dd>`.

**Testing**: `flutter test`: model parsing and API tests with `MockClient`, streak-view mode selection, and modal widget tests.

**Target Platform**: iOS and Android (store builds)

**Project Type**: mobile-app (backend: `trooth_assessment_backend`)

**Performance Goals**: the modal opens within one request after the dashboard settles.

**Constraints**: no correct answer client-side before grading; failures on launch stay silent.

**Scale/Scope**: 3 new widgets/helpers, 1 API extension, 1 model file, and edits to 2 mixins, 1 dashboard, `main.dart`, `session_controller.dart` and `trivia_home_screen.dart`.

## Constitution Check

- [x] ✅ **I. API gateway**: new `lib/services/api/daily_trivia.dart` part file; throws `ApiException`.
- [x] ✅ **II. Environment**: no URLs (the shop URL comes from the API).
- [x] ✅ **III. Security & privacy**: nothing logged beyond status codes. The timezone name isn't a collected data type, so the privacy manifest is checked and unchanged. Firestore isn't touched.
- [x] ✅ **IV. Errors**: `friendlyError()` in the modal; `mounted`/`context.mounted` after every await.
- [x] ✅ **V. Session**: the timezone upload lives in `SessionController._onSignedIn`.
- [x] ✅ **VI. Structure**: `StatefulWidget` + `setState`; the modal is a dialog, not a route (as `NotificationPrimer` is); no `pushNamed`; `kPrimaryGold` from `theme.dart`.
- [x] ✅ **VII. Accessibility**: tooltips on icon buttons; options at least 48px tall; text at least 12px; the modal scrolls; calendar days have semantics labels.
- [x] ✅ **VIII. Tests**: `test/daily_trivia_test.dart`. `flutter analyze` and `flutter test` must pass.
- [x] ✅ **IX. Dependencies**: none new.
- [x] ✅ **X. Logging**: `debugPrint` only.
- [x] ✅ **XI. Release**: no version bump in this change.
- [x] ✅ **XII. Cross-repo**: the endpoints are confirmed in backend spec 002. The backend must be deployed to prod before this app version ships.

## Project Structure

```text
lib/
├── models/daily_trivia.dart                # NEW: DailyQuestion, DailyAnswerResult, DailyReward, NextMilestone,
│                                           #      CalendarDay, DailyStreak, DailyToday, DailyAnswerOutcome
├── services/api/daily_trivia.dart          # NEW: extension DailyTriviaApi on ApiService
├── services/api_service.dart               # + part 'api/daily_trivia.dart'; import model
├── services/session_controller.dart        # + send timezone on sign-in
├── widgets/daily_trivia_modal.dart         # NEW: modal + DailyTriviaPrompt
├── widgets/daily_streak_view.dart          # NEW: week row / month calendar / milestone / reward
├── mixins/mentor_dashboard_tutorial.dart   # _afterTutorial → primer, then daily prompt
├── mixins/apprentice_dashboard_tutorial.dart
├── screens/mentor_dashboard_new.dart       # resume → daily prompt
├── screens/apprentice_dashboard_new.dart   # + lifecycle observer → daily prompt
├── screens/trivia_home_screen.dart         # + Daily Question card
└── main.dart                               # + daily_trivia / daily_trivia_reward taps
test/daily_trivia_test.dart                 # NEW
```

## Complexity Tracking

No violations.
