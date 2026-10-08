# Feature Specification: Trivia Integrity & Premium-Only Challenge Creation (App)

**Feature Branch**: `fix/trivia-integrity` | **Spec Folder**: `specs/001-trivia-integrity/`

**Created**: 2026-10-08

**Status**: Draft

**Input**: User description: "App side of trivia integrity + premium-only challenge creation, built against backend contract trooth_assessment_backend/specs/001-trivia-integrity/contracts/trivia-api.md.
- Single-player games use the new server-run session flow. The app gets one question at a time with no answer attached, and shows right/wrong and the correct option from the server's response after each answer. It sends a timeout when its 30 s timer runs out, shows the grace-token offer when the server says a decision is pending (10 s countdown) and sends use/decline, and shows results from the server's final result.
- The app no longer uses the old draw/submit endpoints (release 2.2.0 is the minimum version that doesn't need them).
- Creating multiplayer challenges is premium-only. Free users see a lock/upgrade prompt on the create entry point and get the upgrade screen if the server refuses. Challenges they receive keep working (accept, play, nudge, forfeit).
- Rules text is updated to say creating challenges is premium. The tie-break line that claims faster time wins is corrected, since the backend does not do it.
- Out of scope: prize gating, play caps."

**Backend spec & contract**: `trooth_assessment_backend/specs/001-trivia-integrity/` ([contracts/trivia-api.md](../../../trooth_assessment_backend/specs/001-trivia-integrity/contracts/trivia-api.md))

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play a single-player game graded by the server (Priority: P1)

A player picks a category and difficulty and starts a game. The game looks and feels as it does today:
- one question at a time, with a 30-second countdown that pulses in the last 5 seconds;
- a screen shake on a wrong answer, with the correct option highlighted;
- a grace-token offer when the player has one;
- the results screen with score, personal best, leaderboard rank and new badges.

The difference is that the app no longer knows the answers in advance. It finds out whether an answer was right, and which option was correct, only after the player answers. The final result comes from the server.

**Why this priority**: The launch competition starts Nov 1 2026, and its prizes depend on scores that can't be faked. The backend only accepts scores from this flow once the old flow is switched off, so app players can't play at all without it.

**Independent Test**:
- Play a game on dev: answer several questions correctly, let one time out, and use a grace token.
- Confirm feedback, score, streak and grace tokens match what the server reports.
- Confirm the results screen shows the server's result.
- Confirm no question's answer is available in the app before it's answered.

**Acceptance Scenarios**:

1. **Given** the player chose a category and difficulty, **When** they tap Start, **Then** the first question appears with its options, and the 30-second timer starts.
2. **Given** a question is showing, **When** the player taps an option, **Then** the options lock, the app shows whether it was right (green for the correct option, red for a wrong pick), the score, streak and multiplier update to the server's values, and after a short pause the next question appears.
3. **Given** a question is showing, **When** the timer reaches 0, **Then** the app sends the timeout, and the question is treated as wrong, with the correct option shown.
4. **Given** the player has a grace token, **When** they answer wrong, **Then** the "Use Grace Token?" prompt appears with a 10-second countdown.
   - Tapping it continues the game at the **next** question, with the streak intact.
   - Declining, or letting the countdown run out, ends the game.
5. **Given** the player has no grace token, **When** they answer wrong, **Then** after a short pause the game ends and the results screen appears.
6. **Given** the game has ended, **When** the results screen opens, **Then** it shows the server's final score, correct count, best streak, new-personal-best celebration, leaderboard rank and badges, without a second "saving your score" step.
7. **Given** every available question has been answered, **When** the last answer is graded, **Then** the game ends and shows results.
8. **Given** a game in progress, **When** the player leaves and confirms, **Then** the game ends for good (it can't be resumed), their score so far is saved, and the results screen shows it. This applies to both the ✕ button and the back gesture. The confirmation text says the game will end and the score so far will be saved.
9. **Given** a question is showing, **When** the player backgrounds the app (or locks the phone) and comes back, **Then** the countdown has kept running the whole time. If time remains, they see the true remaining seconds. If it ran out while they were away, the question counts as unanswered: the game is over, or, if they hold a grace token and its 10-second window hasn't also run out, the grace prompt shows the seconds actually left.
10. **Given** the grace prompt is showing, **When** the player backgrounds the app until its countdown passes, **Then** on return the game is over.

---

### User Story 2 - Free users can't start a challenge but can play ones they receive (Priority: P2)

Starting a multiplayer challenge is a premium feature. A free user who taps "New Challenge" sees that it's premium and can go to the upgrade screen. A free user who receives a challenge can still accept, decline, play every question, nudge and forfeit as before.

**Why this priority**: It's an upgrade incentive and must not cut free users off from challenges they receive. It's independent of story 1.

**Independent Test**:
- Sign in as a free user and tap "New Challenge": the upgrade prompt appears and no challenge is sent.
- Send a challenge from a premium account to that free user, then accept and finish it as the free user.

**Acceptance Scenarios**:

1. **Given** a free user on the challenges list, **When** they look at "New Challenge", **Then** it shows a lock/premium marker. **When** they tap it, **Then** they see a short explanation with an Upgrade action that opens the subscription screen, and they do not reach challenge setup.
2. **Given** a premium user (including gifted premium) or admin, **When** they tap "New Challenge", **Then** they reach challenge setup as today.
3. **Given** the app thinks the user is premium but the server refuses creation as premium-required (for example, the subscription just lapsed), **When** they send a challenge, **Then** the app shows the same upgrade prompt instead of a generic error.
4. **Given** a free user who received a challenge, **When** they open it, **Then** they can accept, decline, answer every question, nudge and forfeit as today.
5. **Given** a free user with challenges they created before this change, **When** they open them, **Then** those challenges keep working.

---

### User Story 3 - Rules say what the game really does (Priority: P3)

The in-app rules describe the current behaviour:
- creating challenges is premium, and anyone can accept;
- multiplayer ties are a draw (the "faster wins" claim is removed);
- a grace token moves you on to the next question;
- leaving a game saves your score so far.

**Why this priority**: Small copy change, but wrong rules cause disputes, especially with prizes involved.

**Independent Test**: Open the trivia rules and check each changed line.

**Acceptance Scenarios**:

1. **Given** the rules screen, **When** a user reads the multiplayer rules, **Then** they say creating a challenge requires premium and that anyone can accept one, and ties are described as a draw.
2. **Given** the rules screen, **When** a user reads the single-player rules, **Then** the grace-token line says it moves you on to the next question with your streak intact.

### Edge Cases

- **Network failure mid-game** (answer or grace request fails): the app retries the same request once automatically. The server treats a repeat of the last answer as a replay and does not grade it twice. If it still fails, the app says the connection was lost and offers Retry and Leave. Leaving ends the game and saves the score so far, and the server closes it later if the request can't reach it.
- **Timer runs out while an answer is in flight**: only one answer is sent per question. The tap or the timeout, whichever happens first, wins.
- **Server-side time limit:** if the server marks an answer late even though the app's timer hadn't reached 0 (slow network), the app shows it as wrong, with the correct option, exactly as the server says.
- **App goes to background mid-question**: the countdown is based on real elapsed time, not on ticks that pause in the background. That pause was how players could leave, look up the answer and come back. On return, the app recomputes the time left. If it has run out, it immediately sends the timeout and shows what the server says (game over, or grace with the true seconds remaining).
- **App killed mid-game**: the game cannot be resumed. The server closes it once the question expires and saves the score so far. Starting a new game also closes any unfinished one.
- **"Game is over" or "grace decision pending" refusal** (for example after a double tap): the app re-reads the state it has and shows results or the grace prompt instead of an error.
- **"Upgrade required" refusal** from a server: this can't happen on 2.2.0, since it no longer calls the old endpoints. Any unexpected 426 shows the friendly "please update" message.
- **No questions available** for a category and difficulty: the setup screen shows a friendly message and stays put.
- **Premium status still loading** when "New Challenge" is tapped: the app treats the user as free until premium status is known. If they were actually premium, a second tap works once it has loaded.

## Requirements *(mandatory)*

### Functional Requirements

**Single player**

- **FR-001**: The app MUST start single-player games through the server's game-start request and MUST NOT request question lists with answers.
- **FR-002**: The app MUST show only the current question received from the server. It MUST NOT have any question's correct option before that question is answered.
- **FR-003**: When the player picks an option, the app MUST send that one answer, then show right/wrong and the correct option using the server's response.
- **FR-004**: When the 30-second timer reaches 0 with no pick, the app MUST send a timeout answer and show the server's result.
- **FR-004a**: The question countdown and the grace countdown MUST be measured in real elapsed time, from when the question or prompt was shown. They MUST keep running while the app is in the background or the screen is locked. On returning to the foreground, the app MUST update the displayed time immediately and, if it has run out, act as in FR-004 or FR-006. A game MUST never resume with more time than really remains.
- **FR-005**: The score, streak, multiplier, grace-token count and question number the app shows MUST come from the server's latest response.
- **FR-006**: When the server reports a grace decision is pending, the app MUST show the grace prompt with a countdown taken from the server's remaining time (10 s by default). It MUST send the player's choice, or a decline when the countdown ends. Using a token MUST continue at the next question the server returns.
- **FR-007**: When the server reports the game finished, the app MUST show the results screen from the server's result (score, correct count, streak, personal best, rank, badges). It MUST NOT submit the game separately.
- **FR-008**: Leaving a game after confirming MUST tell the server to end it, so the score so far is saved and the game can't be continued. The confirmation text MUST say the game will end and the score so far will be saved.
- **FR-009**: The app MUST send at most one answer per question, and MUST retry a failed answer or grace request once before showing a connection error with Retry and Leave.
- **FR-010**: Server refusals MUST be handled by status code: "game over" or "grace pending" → show the matching state; "not your game" or "not found" → a friendly error and back to trivia home; "upgrade required" → a friendly update message.
- **FR-011**: The app MUST no longer call the old question-draw or game-submit requests anywhere, including the mid-game top-up.

**Challenge creation**

- **FR-012**: For users who aren't premium, the "New Challenge" action MUST show a premium marker. Tapping it MUST show an upgrade prompt (explanation plus Upgrade action to the subscription screen) instead of opening challenge setup.
- **FR-013**: If the server refuses challenge creation as premium-required, the app MUST show the same upgrade prompt, never a generic error.
- **FR-014**: Viewing, accepting, declining, answering, nudging and forfeiting challenges MUST NOT check premium in the app.

**Rules text**

- **FR-015**: The trivia rules MUST say:
  - creating challenges requires premium, and anyone can accept;
  - multiplayer ties are a draw (no time tie-break);
  - a grace token continues at the next question with the streak intact;
  - leaving a single-player game ends it and saves the score so far;
  - the timer keeps running if you leave the app.

### Key Entities

- **Game session (from the server)**: the current single-player game. It has:
  - an ID;
  - a status (in progress, awaiting a grace decision, finished);
  - the score, streak, correct count, grace tokens available and used, and the question number out of the total;
  - the current question (without its answer), the grading of the last answer, the grace time remaining, and the final result once finished.
- **Game result (existing)**: the final score, best streak, correct count, new-personal-best flag with previous best, leaderboard rank and badges earned. Its shape is unchanged.

### Roles, Access & Backend Dependencies *(mandatory)*

- **Roles**: mentors and apprentices (admins too) can play single player and take part in challenges.
- **Premium**:
  - Creating a challenge is premium-gated. The backend enforces it (403); the app shows the upgrade prompt on 403, and its own premium check is only a UI hint (constitution III, XII).
  - Everything else in trivia is free.
- **Backend** (all specified in backend spec 001, contract linked above):
  - New: `POST /trivia/single/start`, `POST /trivia/single/{id}/answer`, `POST /trivia/single/{id}/grace`, `POST /trivia/single/{id}/finish`.
  - Changed: `POST /trivia/challenges` (403 for non-premium), and `POST /trivia/challenges/{id}/answer` (400 when an answer isn't for the current question; the app always sends the current question, so this is not expected).
  - No longer used: `GET /trivia/questions/draw` and `POST /trivia/single/submit`.
  - The backend changes are implemented on `fix/trivia-integrity` but **not yet deployed**. Per constitution XII, this app release MUST NOT ship until they are live in prod.
- **Data & privacy**: no new personal data. Answers and timings were already sent to the server, so no change to the privacy manifest or store labels.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The app never holds a question's correct option before that question has been answered. This can be checked by inspecting network traffic over a full game.
- **SC-002**: The score and badges a player sees on the results screen match the server's record for that game in 100% of games.
- **SC-003**: Answer feedback appears within 1 second of tapping on dev under normal conditions, so the game feels as quick as today.
- **SC-003a**: Backgrounding the app during a question never adds time. After being away for N seconds, the countdown shows 30 − N (or the game is over), in 100% of trials.
- **SC-004**: 100% of free users who tap "New Challenge" see the upgrade prompt, and 0 reach challenge setup.
- **SC-005**: 100% of challenges sent to free users can be accepted and played to completion in the app.
- **SC-006**: Version 2.2.0 makes no calls to the old draw or submit requests (checked with a code search and by watching network traffic during a game).

## Assumptions

- **Grace token behaviour changes:**
  - Today's app re-asks the same question after a grace token, with the correct answer already shown. The server-run flow continues at the next question instead.
  - This is intended: re-asking a revealed question was effectively a free point.
  - The graced question scores 0 and the streak carries on.
- **Leaving now saves progress:** a game the player leaves is saved with its score so far. Today it is discarded. The server would close and save it anyway after an hour.
- **Premium status for the UI hint:** the app uses the existing subscription status it already loads, including gifted premium and admin. No new premium check is added.
- **Release version:** this ships as app version **2.2.0**, the minimum version named in the backend spec. The old endpoints are switched off in prod only after 2.2.0 is live in both stores, and before 2026-11-01.
- **Feedback timing:** the short pause after an answer (about 0.8 s today) and the 5-second pulse are kept.
- **Out of scope:**
  - gating competition prizes on premium;
  - play caps;
  - multiplayer timing or tie-break changes;
  - any multiplayer gameplay change beyond the premium create gate.
