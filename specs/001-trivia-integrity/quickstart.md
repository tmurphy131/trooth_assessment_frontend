# Quickstart: Validating Trivia Integrity (App)

## Automated

```bash
flutter analyze --no-fatal-infos
flutter test test/trivia_session_test.dart test/trivia_game_screen_test.dart
flutter test          # full suite (Principle VIII)
grep -rn "triviaDrawQuestions\|triviaSubmitSingleGame\|questions/draw\|single/submit" lib   # expect no matches (SC-006)
```

## Manual on dev

**Prerequisite:** the backend `fix/trivia-integrity` branch is deployed to dev (`/deploy-dev`). The app defaults to the dev API, so run it with `flutter run`.

1. **Single player**: Trivia → Single Player → pick a category → Start.
   - Answer 3 correctly: feedback is green, and the score and multiplier update.
   - Answer 1 wrong with no token: red plus the correct option in green, then results. No "Saving your score…" step.
2. **Clock while away (the cheat)**: start a game. On a question, background the app for about 40 s and return.
   - The game is over (results), or, with a grace token and less than ~43 s away, the grace prompt shows only the seconds really left.
   - Background for about 10 s and return: the countdown shows about 20 s, not 30.
3. **Grace**: reach 10 correct, then miss. The prompt counts down from 10. Use it: the **next** question appears and the streak is kept. Repeat and let it expire: results.
4. **Timeout**: let the timer hit 0: wrong, with the correct option shown.
5. **Leave**: press back mid-game. The confirmation says the score will be saved. Confirm, then check the leaderboard/profile for the saved score.
6. **Network**: turn on airplane mode, then tap an answer. After one automatic retry, a Retry/Leave dialog appears. Turn the network back on and tap Retry: the game continues.
7. **Challenges (free account)**: Trivia → Challenges. "New Challenge" shows a lock; tapping it shows the upgrade prompt, and Upgrade opens the subscription screen.
8. **Challenges (premium → free)**: from a premium account, challenge the free account. On the free account, accept and play to the end, and nudge.
9. **Rules**: Trivia home → rules. The multiplayer rules say creating requires premium and ties are a draw; the single-player rules describe grace, leaving and the timer.

## Network check (SC-001)

With a proxy (Charles or Proxyman) on a debug build, play 5 questions. No `question` object in any response contains `correct_option`.
