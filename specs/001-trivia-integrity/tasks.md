---

description: "Task list for 001-trivia-integrity (app)"
---

# Tasks: Trivia Integrity & Premium-Only Challenge Creation (App)

**Input**: Design documents from `/specs/001-trivia-integrity/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/README.md (links the backend contract), quickstart.md

**Tests**: Principle VIII requires unit tests for the new model and API-extension methods (`MockClient` via `api.httpClient` plus `api.setAuthForTesting`). A widget test covers the game flow and the background-clock regression. Each story ends with `flutter analyze --no-fatal-infos` and `flutter test` passing.

**Organization**: tasks are grouped by user story (spec.md):
- US1: server-graded single player (P1)
- US2: premium-only challenge creation (P2)
- US3: rules copy (P3)

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

- [X] T001 [P] In `lib/utils/errors.dart` `friendlyError`, add `426 => 'Please update the app to keep playing trivia.'` to the `ApiException` switch, before the `_` case.

---

## Phase 2: Foundational (Blocking Prerequisites)

- [X] T002 Create `lib/models/trivia_session.dart`, field for field per data-model.md:
  - `enum TriviaSessionStatus { active, awaitingGrace, finished }`, parsed from `status`. `'active'` → active, `'awaiting_grace'` → awaitingGrace, **any other value → finished**.
  - `TriviaSessionQuestion {index, id, text (question_text), type (question_type), options: Map<String,String> built from non-null, non-empty option_a..option_d}`, with **no correct-option field**.
  - `TriviaLastAnswer {questionId, selected (nullable), correct, correctOption, timedOut}`.
  - `TriviaSessionState {sessionId, status, score, streak, correctCount, graceTokens, graceTokensUsed, questionNumber, totalQuestions, timeLimitMs, question?, lastAnswer?, graceExpiresInMs?, result (Map<String,dynamic>?)}`.
  - Every class gets a `factory fromJson(Map<String, dynamic>)`.
  - Add a getter `int get multiplier` on `TriviaSessionState`: 1 if streak < 5, 2 if < 10, 3 if < 15, 4 if < 20, else 5.
- [X] T003 In `lib/services/api/trivia.dart`, add the methods below. They follow the existing style (`_http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(...))`). Non-200 throws `ApiException(r.statusCode, '<name> failed (${r.statusCode}) ${r.body}')`.
  - `Future<TriviaSessionState> triviaStartSingle({required String category, required String difficulty})` → `POST /trivia/single/start`.
  - `Future<TriviaSessionState> triviaAnswerSingle(String sessionId, {required int questionId, String? selected})` → `POST /trivia/single/$sessionId/answer`, body `{"question_id": ..., "selected": selected}`. `selected` is sent as JSON null when null.
  - `Future<TriviaSessionState> triviaGraceSingle(String sessionId, {required bool use})` → `POST /trivia/single/$sessionId/grace`.
  - `Future<Map<String, dynamic>> triviaFinishSingle(String sessionId)` → `POST /trivia/single/$sessionId/finish`.
  - Import `../models/trivia_session.dart` in `lib/services/api_service.dart` alongside the other model imports (the API files are `part`s).
- [X] T004 [P] Create `test/trivia_session_test.dart`:
  - **Model tests**:
    - full active state parses;
    - `question` has no correct option, even when the JSON wrongly includes `correct_option` (it is ignored);
    - true/false questions give two options;
    - `awaiting_grace` with `grace_expires_in_ms`;
    - finished with `result`;
    - unknown status → finished;
    - multiplier boundaries 4→1, 5→2, 19→4, 20→5.
  - **API tests** (`MockClient` pattern from `test/api_service_test.dart`):
    - each of the four methods hits the right path and method, sends the right body (including `"selected": null`), and parses the response;
    - 409, 404 and 426 → `ApiException` with that `statusCode`;
    - a transport failure → `NetworkException`.

**Checkpoint**: `flutter test test/trivia_session_test.dart` passes.

---

## Phase 3: User Story 1 - Server-graded single player (Priority: P1) 🎯 MVP

**Goal**: single player runs entirely on the server session. Countdowns use real elapsed time.

**Independent Test**: play on dev per quickstart steps 1–6. The widget test passes, including the background-resume regression.

### Tests for User Story 1 ⚠️

- [X] T005 [P] [US1] Create `test/trivia_game_screen_test.dart`.
  - Pump `TriviaGameScreen(initialState: ..., category: 'old_testament', difficulty: 'challenger', now: () => fakeNow)`.
  - Use a scripted `MockClient` fake server that returns canned `SingleSessionState` JSON per request and records request bodies.
  - Tests:
    - (a) tapping an option sends exactly one answer with that letter, shows the server's feedback (correct option highlighted), then shows the next question and the updated score;
    - (b) advancing `fakeNow` 30 s and pumping sends `{"selected": null}` once;
    - (c) **background regression**: simulate `AppLifecycleState.paused`, advance `fakeNow` by 40 s, simulate `resumed`. The timeout is sent immediately on resume, and the server's `finished` response navigates to `TriviaResultScreen`;
    - (d) a pending grace state shows the "Use Grace Token?" prompt. Tapping Use sends `{"use": true}` and shows the next question. In another test, the grace deadline passing sends `{"use": false}`;
    - (e) a 409 on a grace call resends the last answer sent (same `question_id` and `selected`) and routes by the replayed status (finished → results);
    - (f) a double tap sends only one answer.
  - Lifecycle is driven with `tester.binding.handleAppLifecycleStateChanged(...)`.

### Implementation for User Story 1

- [X] T006 [US1] Rewrite the state handling in `lib/screens/trivia_game_screen.dart`, keeping the existing layout, animations, colours and accessibility.
  - **Constructor**: `TriviaGameScreen({required TriviaSessionState initialState, required String category, required String difficulty, @visibleForTesting DateTime Function()? now})`.
  - **Remove**:
    - local question lists, `_fetchMoreQuestions` and `_seenIds`;
    - local grading (`correct_option` lookups) and local score, streak and token maths;
    - `_answers` and the `TriviaResultScreen` submission arguments.
  - **State**: `TriviaSessionState _state`, `DateTime? _questionDeadline`, `DateTime? _graceDeadline`, `bool _busy`, `String? _picked`, `bool _showingFeedback`.
  - **Countdown** (research R3):
    - when a state with `status == active` and a new `question` arrives, set `_questionDeadline = _now().add(Duration(milliseconds: _state.timeLimitMs))`;
    - a 250 ms `Timer.periodic` repaints; displayed seconds are `max(0, (deadline − now).inSeconds rounded up)`;
    - the pulse runs at 5 s or less;
    - when remaining time reaches 0 and the player hasn't answered, call `_submit(null)` once.
  - **Lifecycle**: `with WidgetsBindingObserver`, added in `initState` and removed in `dispose`. `didChangeAppLifecycleState(resumed)` re-runs the expiry checks immediately (question → `_submit(null)`, grace → `_decideGrace(false)`).
  - **`_submit(String? letter)`**:
    - guard `_busy` / already answered;
    - set `_busy` and `_picked`;
    - call `triviaAnswerSingle` through `_withRetry`;
    - `setState(_state = response)`;
    - show feedback from `response.lastAnswer` (green on `correctOption`, red on a wrong pick, shake and haptic on wrong) for about 800 ms;
    - then route by status: active → next question (new deadline); awaitingGrace → grace prompt with `_graceDeadline = now + graceExpiresInMs`; finished → `_showResults(response.result!)`.
  - **Grace prompt**:
    - countdown from `_graceDeadline`;
    - "Use Grace Token" → `_decideGrace(true)`; expiry → `_decideGrace(false)`;
    - `_decideGrace` calls `triviaGraceSingle` through `_withRetry` and routes by status as above.
  - **HUD**: score, streak, multiplier (`_state.multiplier`), grace tokens and question number all come from `_state`.
- [X] T007 [US1] In `lib/screens/trivia_game_screen.dart`, add error handling (research R5):
  - `_withRetry<T>(Future<T> Function() call)` retries once on `NetworkException` or `ApiException` with `isServerError`.
  - If it fails again, show an `AlertDialog`: `friendlyError(e)` text, **Retry** (repeat the same call) and **Leave** (best-effort `triviaFinishSingle`, then pop).
  - `ApiException` 409 on answer or grace (the app's view is stale: the game is over, or a grace decision is pending): **re-sync without reading the body**.
    - Keep `({int questionId, String? selected})? _lastSent`, set on every answer sent. It's needed because grace responses carry no `last_answer`.
    - If `_lastSent != null`, resend it with `triviaAnswerSingle(sessionId, questionId: _lastSent.questionId, selected: _lastSent.selected)`. The server replays the current state for the last answered question, whatever the status. Route by that status.
    - If nothing has been sent yet, call `triviaFinishSingle` and show results.
    - Never parse `detail` (Principle XII).
  - 404: show a SnackBar with `friendlyError(e)` and pop to the first trivia route.
  - Check `mounted` after every `await`.
- [X] T008 [US1] In `lib/screens/trivia_game_screen.dart` `PopScope`:
  - The dialog text becomes `'Your game will end and your score so far will be saved.'`, with Keep Playing and Quit buttons.
  - On Leave (✕ button or back gesture, one shared dialog): cancel timers, call `triviaFinishSingle` and show `TriviaResultScreen` with the saved result. If the call fails, show a SnackBar and pop.
  - If the state is already finished, pop without the dialog.
- [X] T009 [US1] In `lib/screens/trivia_result_screen.dart`:
  - The constructor becomes `TriviaResultScreen({required Map<String, dynamic> result, required String category, required String difficulty})`.
  - Delete `_submit`, `_isSubmitting`, `_error` and the "Saving your score…" spinner.
  - Render from `result`: `score`, `correct_count`, `streak_length`, `is_new_high_score`, `previous_best`, `leaderboard_rank`, `badges_earned`.
  - The "Grace Tokens Used" row is dropped. The result schema has no such field, so don't add one.
  - Start the celebration in `initState` when `is_new_high_score == true`.
  - Keep the Play Again, Home and Leaderboard buttons. Play Again still opens `TriviaSetupScreen(mode: TriviaMode.single)`.
- [X] T010 [US1] In `lib/screens/trivia_setup_screen.dart` `_startSinglePlayer`:
  - Replace `triviaDrawQuestions` with `ApiService().triviaStartSingle(category: _selectedCategory, difficulty: _selectedDifficulty)`.
  - Push `TriviaGameScreen(initialState: state, category: ..., difficulty: ...)`.
  - If the start state is already `finished` (empty pool edge), go straight to `TriviaResultScreen`.
  - A 400 shows the SnackBar `'No questions are available for that category and difficulty yet.'`; other errors use `friendlyError`.
- [X] T011 [US1] Delete `triviaDrawQuestions` and `triviaSubmitSingleGame` from `lib/services/api/trivia.dart`. Confirm `grep -rn "triviaDrawQuestions\|triviaSubmitSingleGame" lib test` returns nothing (FR-011, SC-006).

**Checkpoint**: `flutter analyze --no-fatal-infos` is clean, and `flutter test test/trivia_session_test.dart test/trivia_game_screen_test.dart` passes.

---

## Phase 4: User Story 2 - Premium-only challenge creation (Priority: P2)

**Goal**: free users can't start challenges and are shown an upgrade path. Received challenges are untouched.

**Independent Test**: quickstart steps 7–8.

### Tests for User Story 2 ⚠️

- [X] T012 [P] [US2] In `test/trivia_session_test.dart` (group "challenges"), add: `triviaCreateChallenge` returning 403 throws `PremiumRequiredException`; 200 returns the map; 404 → `ApiException(404)`.

### Implementation for User Story 2

- [X] T013 [US2] In `lib/services/api/trivia.dart` `triviaCreateChallenge`, add before the generic throw: `if (r.statusCode == 403) throw PremiumRequiredException('Creating challenges is a premium feature.');`.
- [X] T014 [P] [US2] Create `lib/widgets/premium_upgrade_dialog.dart`, modelled on `_showUpgradePrompt` in `lib/screens/apprentice_dashboard_new.dart:777`:
  - `Future<void> showPremiumUpgradeDialog(BuildContext context, {required String message})`;
  - `AlertDialog` with a grey[900] background and a lock icon, title "Premium Required" in amber/Poppins, and the message;
  - actions: `TextButton('Not now')` and an amber `TextButton('Upgrade')` that pops then pushes `SubscriptionScreen` (`lib/screens/subscription_screen.dart`).
- [X] T015 [US2] In `lib/screens/trivia_challenge_list_screen.dart`, the FAB:
  - Listen to `SubscriptionService()` (`ListenableBuilder`), so the lock updates once status loads.
  - When `!SubscriptionService().isPremium`: icon `Icons.lock`, same label "New Challenge"; `onPressed` → `showPremiumUpgradeDialog(context, message: 'Starting a challenge is a premium feature. You can still accept and play challenges others send you.')`.
  - Otherwise the current behaviour is unchanged.
- [X] T016 [US2] In `lib/screens/trivia_challenge_create_screen.dart` `_createChallenge`: catch `PremiumRequiredException` before the generic catch. Then `setState(_isCreating = false)` and `showPremiumUpgradeDialog(context, message: 'Starting a challenge is a premium feature.')`, with `mounted` checks.

**Checkpoint**: tests pass. A free account sees the lock and the prompt. A premium account creates challenges as before.

---

## Phase 5: User Story 3 - Rules copy (Priority: P3)

- [X] T017 [US3] In `lib/screens/trivia_home_screen.dart`:
  - `_singlePlayerRules`:
    - grace line → `'A wrong answer (or running out of time) triggers a screen shake. If you have a grace token, a "Use Grace Token?" prompt appears for 10 seconds. Tap it to keep your streak and move on to the next question.'`;
    - timer line → add `'The timer keeps running if you leave the app.'`;
    - add `'Leaving a game ends it. Your score so far is saved.'`.
  - `_multiplayerRules`:
    - first line → `'Starting a challenge requires premium. Anyone can accept a challenge sent to them.'` (keep the email line as a second rule);
    - tie line → `'The player with the most points wins. Equal points is a draw.'`.

**Checkpoint**: the rules screen reads correctly at 1.5x text scale.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T023 [US1] The game body scrolls on short screens and at 1.5x text, so the grace prompt is always reachable. The old layout overflowed by 89 px and pushed "Use Token" off-screen. A widget test at iPhone SE size with 1.5x text covers it.

- [X] T018 `flutter analyze --no-fatal-infos` and `flutter test` (full suite) pass.
- [X] T019 Run `grep -rn "correct_option" lib/screens/trivia_game_screen.dart lib/screens/trivia_setup_screen.dart`. Expect no matches: the client never reads answers ahead of time.
- [X] T020 After `flutter test`, run `flutter build ios --config-only` to reset `Generated.xcconfig` (memory note).
- [ ] T021 With the backend deployed to dev (`/deploy-dev`), run quickstart "Manual on dev" steps 1–9 on a simulator, including 1.5x text scale on the game, grace and dialog screens.
- [ ] T022 Release gate (Principle XII): bump to 2.2.0 via `/bump-version 2.2.0` and tag **only after** the backend is deployed to prod. Then follow backend task T025 (switch off the old endpoints once 2.2.0 is in both stores).

---

## Dependencies & Execution Order

- **T001** stands alone.
- **T002 → T003 → T004** (tests need both).
- **US1**:
  - T006 depends on T002 and T003, and T007 and T008 build on it in the same file, one after the other.
  - T009 and T010 depend on T006's constructor.
  - T011 comes after T010 (the last callers removed). T005 can be written in parallel with T006.
- **US2**: depends only on Phase 1. T013 and T014 can run in parallel; T015 and T016 depend on T014.
- **US3**: independent.
- **Polish**: after all stories. T021 needs the backend dev deploy. T022 needs the backend in prod.

## Parallel Example

```bash
Task: "T004 test/trivia_session_test.dart"
Task: "T005 test/trivia_game_screen_test.dart"
Task: "T014 lib/widgets/premium_upgrade_dialog.dart"
Task: "T017 rules copy in lib/screens/trivia_home_screen.dart"
```

## Implementation Strategy

1. **MVP**: Phase 1, Phase 2 and US1. Single player works against the new backend, and the cheat is closed.
2. US2 and US3 are small and ship in the same 2.2.0 release.
3. Deploy the backend to dev → run quickstart on a simulator → deploy the backend to prod → `/bump-version 2.2.0` → tag → once it's in the stores, switch off the old endpoints.

## Notes

- Don't commit until asked.
- `[P]` = different files, with no dependency on unfinished tasks.
