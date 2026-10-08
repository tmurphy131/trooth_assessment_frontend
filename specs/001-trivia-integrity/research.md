# Research: Trivia Integrity (App)

All decisions are bound by the backend contract `trooth_assessment_backend/specs/001-trivia-integrity/contracts/trivia-api.md`. No open questions remain.

## R1. Typed session model instead of raw maps

- **Decision**: add `lib/models/trivia_session.dart` with three classes, each with `fromJson`:
  - `TriviaSessionState`
  - `TriviaSessionQuestion`
  - `TriviaLastAnswer`

  `result` stays a `Map<String, dynamic>`, because `TriviaResultScreen` already renders that shape.
- **Rationale**:
  - The game screen reads status, score, streak, tokens, question and last answer after every request.
  - Typed fields make the "no answer in the question" rule visible: `TriviaSessionQuestion` has no correct-option field.
  - Parsing gets unit tests (Principle VIII).
- **Alternative considered**: keep `Map` access as today. That is untested and makes key typos easy.

## R2. API methods

- **Decision**: replace `triviaDrawQuestions` and `triviaSubmitSingleGame` in `lib/services/api/trivia.dart` with four methods:
  - `triviaStartSingle(category, difficulty)` returns a `TriviaSessionState`;
  - `triviaAnswerSingle(sessionId, questionId, selected)` returns a `TriviaSessionState` (`selected` is null on timeout);
  - `triviaGraceSingle(sessionId, use)` returns a `TriviaSessionState`;
  - `triviaFinishSingle(sessionId)` returns the result map.

  Non-200 responses throw `ApiException(status, …)` and keep the status code, so the screen can branch on 409, 404 and 426.
- **Change to `triviaCreateChallenge`**: a 403 throws `PremiumRequiredException`.
- **Rationale**: this follows Principle I (typed exceptions, `ApiService` extensions) and Principle XII (branch on status codes, not body text).

## R3. Countdown on real elapsed time

- **Decision**:
  - The screen stores a `DateTime deadline` for the question (receipt time + 30 s) and, when prompted, for grace (receipt time + `grace_expires_in_ms`).
  - Remaining time is always `deadline − now()`.
  - A `Timer.periodic` (about 250 ms) only repaints and checks for expiry.
  - The screen also implements `WidgetsBindingObserver`. On `resumed` it recomputes immediately and, if expired, sends the timeout (question) or the decline (grace).
  - `now()` is injectable (`@visibleForTesting`) so widget tests can control the clock.
- **Rationale**: the old countdown decremented an int once per tick. iOS and Android suspend timers in the background, so time stood still while the player was away. That was the cheat. A deadline can't be paused. The server's clock is still the authority; the app just shouldn't show more time than really remains.
- **Note**: the local deadline starts when the response *arrives*, a little after the server's `served_at`. The server's 3 s allowance absorbs that, so an on-time tap is never marked late.
- **Alternative considered**: compute the countdown from a server timestamp. That needs clock-sync handling, and the contract doesn't expose one. Not needed.

## R4. Where the game logic lives

- **Decision**: keep it in `_TriviaGameScreenState` with `setState`, as today (Principle VI: setState and singletons, no new state package).
  - The screen holds the latest `TriviaSessionState` and renders from it.
  - Local flags only cover "request in flight" and "showing feedback".
  - The deadline and the retry-once helper are small private methods.
- **Rationale**: this is the smallest change, and it keeps the existing animations and layout.
- **Alternative considered**: extract a `ChangeNotifier` controller. That would be cleaner to test, but it's a bigger rewrite than the feature needs. The widget tests in R6 cover the flow.

## R5. Retries and refusals

- **Decision**:
  - An answer, grace or finish request that fails with `NetworkException` or a 5xx is retried **once** automatically. Replaying the same answer is safe because the server replays the last answered question.
  - If the retry also fails, a dialog shows `friendlyError` with **Retry** and **Leave**. Leave calls finish (best effort) and pops.
  - 409 refusals ("game over" or "grace pending") re-sync without an error message and without reading the body. The app resends its **last answer**; the backend replays the current state for the last answered question whatever the status, and the app routes by that status. With no last answer, it calls finish and shows results.
  - 404 shows a friendly error and pops to trivia home.
  - 426: `friendlyError` gains a 426 case, "Please update the app to keep playing trivia."
- **Rationale**: covers FR-009 and FR-010 without new infrastructure.

## R6. Tests

- **Unit**: `test/trivia_session_test.dart` covers model parsing, including asserting that no correct option is present in a question, and the four API methods using `MockClient`:
  - the path and body sent;
  - parsing of the response;
  - each error status mapped to the right exception;
  - create-challenge 403 → `PremiumRequiredException`.
- **Widget**: `test/trivia_game_screen_test.dart` drives `TriviaGameScreen` against a fake session server (`MockClient` scripted per request) with an injected clock:
  - a correct answer shows feedback and advances;
  - the timer reaching 0 sends `selected: null`;
  - **resume after being away 40 s sends the timeout immediately and shows game over** (the cheat regression);
  - the grace prompt's use and decline paths.
- **Not done**: no device integration test. Auth and session code aren't touched.

## R7. Upgrade prompt

- **Decision**: add a shared `showPremiumUpgradeDialog(context, message:)` in `lib/widgets/premium_upgrade_dialog.dart`. It matches the existing "Premium Required" dialog style (`apprentice_dashboard_new.dart:777`): lock icon, message, **Not now** and **Upgrade**. Upgrade pushes `SubscriptionScreen`.
  - It is used from the challenge list's "New Challenge" FAB when `!SubscriptionService().isPremium`. The FAB also shows a lock icon in that case.
  - It is also used from `TriviaChallengeCreateScreen` when a `PremiumRequiredException` is caught.
- **Rationale**: one dialog for the two entry points. `isPremium` comes from the backend's `has_premium`, which already includes admins and gifted users.

## R8. Leaving a game

- **Decision**: the back-button confirmation text becomes "Your game will end and your score so far will be saved." On confirm, from either the ✕ button or the back gesture, the app calls `triviaFinishSingle` and shows the saved result. If that call fails, it shows a message and pops; the server closes the game anyway.
- **Rationale**: FR-008. The server closes the game regardless once the question expires.
