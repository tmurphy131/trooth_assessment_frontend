# Quickstart: validate Clear Report Status

## Prerequisites

- The backend on dev includes spec 004 (revision 00098 or later: failed status, Premium generating/503).
- Guide test accounts (`guide.apprentice@example.com`, `guide.mentor@example.com`; Premium on dev).
  Credentials are in `~/.config/onlyblv/test_accounts.env`.
- A local build pointed at dev: `flutter run` (dev is the default).

## 1. Automated checks

```bash
flutter analyze --no-fatal-infos
flutter test test/report_status_test.dart test/report_status_api_test.dart test/report_status_views_test.dart
flutter test
```

Expected: everything passes. The parser covers done/processing/failed/unknown/missing status. The
Premium mapping covers 200 report, 200 generating, 200 no report, 503 and 403. The poller covers the
5 s → 30 s schedule, the 3-minute slow flag, the 30-minute cap, no overlapping checks and cancel. The
widget tests cover the views at 1.5x text scale.

## 2. Apprentice: preparing → report (US1, SC-001)

1. Sign in as the guide apprentice, complete and submit a Master assessment (or run
   `python3 scripts/site/guide_capture/seed/seed_data.py complete` in the backend repo, then open
   the newest report quickly).
2. Open the report right away.

Expected: "Preparing your report…" shows, never the "Awaiting detailed AI analysis" placeholder. The
finished report appears by itself within 10 s of the backend marking it done (about 25–35 s after
submit). Repeat 10 times for SC-001.

## 3. Delayed and failed (US2, SC-002)

Make a failed assessment on dev. In the backend repo, temporarily set `LLM_MODEL` to an invalid model
and `SCORING_RETRY_WINDOW_S=120` on `trooth-backend-dev`, and set the queue's `maxRetryDuration` to
180 s (as in backend spec 004 quickstart §5). Submit, wait for `failed`, then **restore all three**.

Expected:
- the apprentice and the mentor both see "Taking longer than usual — we're on it" with "AI provider
  unavailable" and "Check again", and no scores;
- after `POST /admin/assessments/requeue` and the report finishing, "Check again" shows the report;
- "Check again" while it's re-queued but still processing shows the preparing view.

## 4. Mentor screens (US3)

As the guide mentor, open the apprentice's newest submission right after it's submitted.

Expected: the Report tab shows the preparing view, and the Answers and Notes tabs work. The report
appears by itself once it's done.

## 5. Premium generating and unavailable (US4, SC-003)

1. As the premium apprentice, open the report as soon as the free report is done.
   Expected: the Premium section shows "Preparing your Premium report…" and fills in within about a
   minute, without leaving the screen (9 of 10 runs).
2. Mentor simplified report → "View full report" right after the report is done.
   Expected: the button shows progress, then the Premium report opens.
3. Unavailable: covered by the widget and API tests (503). Optionally on dev, break `LLM_MODEL` after
   the free report is done and before Premium finishes, then restore.
   Expected: "temporarily unavailable" with "Try again", and no upsell.

## 6. Regressions (SC-004)

- A free user still sees the upgrade prompt.
- An already-finished report opens with no visible preparing state beyond the first status check.
- Run the app against **prod** (`--dart-define=API_BASE_URL=https://trooth-discipleship-api.onlyblv.com/`)
  before backend #33/#34 reach prod. Reports and Premium behave as they do today, with no crashes.

Record results in the PR.
