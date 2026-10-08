# Implementation Plan: Trivia Integrity & Premium-Only Challenge Creation (App)

**Branch**: `fix/trivia-integrity` | **Date**: 2026-10-08 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-trivia-integrity/spec.md`

## Summary

**Single player:**
- It moves from the old "download questions with answers, grade locally, submit at the end" flow to the backend's server-run session (backend spec 001).
- The game screen renders whatever the server's latest state says: question, feedback, score, streak, grace and results.
- It sends one answer per question, or a timeout.
- Both countdowns run on real elapsed time (deadline − now), so backgrounding the app no longer pauses them. The screen re-checks the deadlines when the app returns to the foreground.

**Challenges:**
- Creating one is premium-only. The FAB on the challenge list shows a lock and an upgrade prompt.
- A 403 from the server shows the same prompt.

**Also:** the rules copy is corrected, and the old draw/submit API methods are deleted.

## Technical Context

**Language/Version**: Dart / Flutter (version pinned in `.github/workflows/release.yml`)

**Primary Dependencies**: existing only (`http`, `flutter_test`, `http/testing.dart` `MockClient`). No new packages.

**Backend Endpoints** (backend contract: `trooth_assessment_backend/specs/001-trivia-integrity/contracts/trivia-api.md`, implemented on backend `fix/trivia-integrity`, not yet deployed):
- New: `POST /trivia/single/start`, `POST /trivia/single/{id}/answer`, `POST /trivia/single/{id}/grace`, `POST /trivia/single/{id}/finish`.
- Changed: `POST /trivia/challenges` (403 for non-premium).
- Removed from the app: `GET /trivia/questions/draw`, `POST /trivia/single/submit`.

**Storage**: backend API only. No local persistence. A game can't be resumed after the app is killed; the server closes it.

**Testing**:
- `flutter test`: new `test/trivia_session_test.dart` (model and API) and `test/trivia_game_screen_test.dart` (widget flow with a fake server and injected clock).
- No `integration_test` needed: auth and session code are untouched.

**Target Platform**: iOS and Android (store builds)

**Project Type**: mobile-app (backend: `trooth_assessment_backend`)

**Performance Goals**: answer feedback within 1 s on dev (SC-003); one request per answer.

**Constraints**:
- The countdown must never show more time than really remains (SC-003a).
- At most one answer per question.
- Ships as **2.2.0**, only after the backend is live in prod.

**Scale/Scope**: about 6 screens or widgets touched, 1 API part file, 1 new model file, 1 new shared widget, 2 new test files.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Source: `.specify/memory/constitution.md`. Mark each ✅ / ❌ / N/A; every ❌ needs a row in Complexity Tracking.

- [x] ✅ **I. API gateway**:
  - The new calls are in the `TriviaApi` extension (`lib/services/api/trivia.dart`) and go through `_http`.
  - Failures throw `ApiException`, `NetworkException` or `PremiumRequiredException` only.
- [x] ✅ **II. Environment**: no URLs added. Verified on dev (quickstart) before the release tag.
- [x] ✅ **III. Security & privacy**:
  - No logging of bodies.
  - The premium check on the FAB is a UI hint only; the backend 403 is the real gate.
  - No Firestore or rules changes. No new data collected, so the privacy manifest is unchanged.
- [x] ✅ **IV. Errors**:
  - User-facing text goes through `friendlyError()`, which gains a 426 message.
  - Every `await` in the game, setup, result and create screens is followed by a `mounted` check.
- [x] ✅ **V. Session**: no auth or session changes.
- [x] ✅ **VI. Structure**:
  - `setState` in the game screen, plus the `SubscriptionService` singleton. No new state package.
  - Detail screens use `Navigator.push` as today. No `pushNamed`. No router change.
  - New files follow the naming conventions (`trivia_session.dart`, `premium_upgrade_dialog.dart`).
- [x] ✅ **VII. Accessibility**:
  - The lock FAB keeps its label text.
  - New dialog buttons are `TextButton`s with at least 48 px targets.
  - No new `IconButton`s without tooltips. Grace and leave text wraps at 1.5x text scale.
- [x] ✅ **VIII. Tests**:
  - Model and API unit tests using `MockClient`, `api.httpClient` and `setAuthForTesting`.
  - A widget test for the game flow, including the background-resume regression.
  - `flutter analyze` and `flutter test` must pass.
- [x] ✅ **IX. Dependencies**: none added.
- [x] ✅ **X. Logging**: no `print`.
- [x] ✅ **XI. Release**: version 2.2.0 set through `/bump-version` at release time, not in this change.
- [x] ✅ **XII. Cross-repo**:
  - Every endpoint is named and specified in the backend contract, and implemented on the backend branch.
  - **Gate**: this app version MUST NOT be tagged for release until the backend is deployed to prod (tracked as a release task).

**Post-design re-check**: all ✅. No Complexity Tracking entries.

## Project Structure

### Documentation (this feature)

```text
specs/001-trivia-integrity/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/README.md       # links the backend contract (source of truth)
├── checklists/requirements.md
└── tasks.md                  # /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── models/trivia_session.dart                 # NEW: TriviaSessionState / Question / LastAnswer (+ status enum)
├── services/api/trivia.dart                   # + triviaStartSingle/AnswerSingle/GraceSingle/FinishSingle;
│                                              #   − triviaDrawQuestions/SubmitSingleGame; create 403 → PremiumRequiredException
├── utils/errors.dart                          # friendlyError: + 426
├── widgets/premium_upgrade_dialog.dart        # NEW: showPremiumUpgradeDialog(context, message:)
└── screens/
    ├── trivia_setup_screen.dart               # single player: start session → TriviaGameScreen(initialState)
    ├── trivia_game_screen.dart                # server-driven state, deadline countdowns, lifecycle observer,
    │                                          #   retry-once, 409/404 handling, leave → finish
    ├── trivia_result_screen.dart              # takes the server result; no submit step
    ├── trivia_challenge_list_screen.dart      # FAB: lock + upgrade prompt for non-premium
    ├── trivia_challenge_create_screen.dart    # catch PremiumRequiredException → upgrade prompt
    └── trivia_home_screen.dart                # rules copy
test/
├── trivia_session_test.dart                   # NEW: model + API (MockClient)
└── trivia_game_screen_test.dart               # NEW: widget flow, fake server, injected clock
```

**Structure Decision**: trivia lives in `lib/screens/trivia_*` and `lib/services/api/trivia.dart`, so this feature stays there and isn't moved into `lib/features/`. The new model goes in `lib/models/` next to `prayer_entry.dart`. The upgrade dialog goes in `lib/widgets/` so both entry points share it.

## Complexity Tracking

No violations.
