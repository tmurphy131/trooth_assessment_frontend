# Data Model: Trivia Integrity (App)

Client-side models in `lib/models/trivia_session.dart`, parsed from the backend's `SingleSessionState` ([contract](../../../trooth_assessment_backend/specs/001-trivia-integrity/contracts/trivia-api.md)).

## TriviaSessionState

| Field | Type | JSON | Notes |
|---|---|---|---|
| `sessionId` | String | `session_id` | |
| `status` | `TriviaSessionStatus` enum (`active`, `awaitingGrace`, `finished`) | `status` (`active` / `awaiting_grace` / `finished`) | Unknown values parse as `finished` (fail safe: show results) |
| `score` | int | `score` | |
| `streak` | int | `streak` | Multiplier is derived from it for display (1× under 5, 2× under 10, 3× under 15, 4× under 20, else 5×), matching the server |
| `correctCount` | int | `correct_count` | |
| `graceTokens` | int | `grace_tokens` | |
| `graceTokensUsed` | int | `grace_tokens_used` | |
| `questionNumber` | int | `question_number` | 1-based |
| `totalQuestions` | int | `total_questions` | |
| `timeLimitMs` | int | `time_limit_ms` | 30000 |
| `question` | `TriviaSessionQuestion?` | `question` | Present only when `active` |
| `lastAnswer` | `TriviaLastAnswer?` | `last_answer` | |
| `graceExpiresInMs` | int? | `grace_expires_in_ms` | Present only when `awaitingGrace` |
| `result` | `Map<String, dynamic>?` | `result` | Present only when `finished`; same shape `TriviaResultScreen` renders today |

## TriviaSessionQuestion

| Field | Type | JSON |
|---|---|---|
| `index` | int | `index` |
| `id` | int | `id` |
| `text` | String | `question_text` |
| `type` | String | `question_type` (`multiple_choice` / `true_false`) |
| `options` | `Map<String, String>` (letter → text, only non-null) | `option_a` … `option_d` |

This class has **no correct-option field** (FR-002).

## TriviaLastAnswer

| Field | Type | JSON |
|---|---|---|
| `questionId` | int | `question_id` |
| `selected` | String? | `selected` |
| `correct` | bool | `correct` |
| `correctOption` | String | `correct_option` |
| `timedOut` | bool | `timed_out` |

## Screen state (in `_TriviaGameScreenState`)

- `TriviaSessionState _state`: the latest server state; everything shown comes from it.
- `DateTime? _questionDeadline`: set when a new `question` arrives (`now + timeLimitMs`).
- `DateTime? _graceDeadline`: set when `status == awaitingGrace` (`now + graceExpiresInMs`).
- `bool _busy`: a request is in flight; option taps are ignored.
- `String? _picked`: the option the player tapped, for highlighting while feedback shows.

### Flow

```text
setup ──start──► game(active, Q1)
active ──tap / deadline──► POST answer ──► show feedback (lastAnswer) ~0.8 s ──►
    active          → next question, new deadline
    awaitingGrace   → grace prompt, grace deadline
    finished        → results(result)
awaitingGrace ──Use (before deadline)──► POST grace{use:true}  → active, next question
              ──No / deadline──────────► POST grace{use:false} → finished → results
resumed from background → recompute; if a deadline has passed, act as if it fired now
back + confirm → POST finish (best effort) → pop
```
