# Contract: API responses → report UI states

Backend source of truth: `trooth_assessment_backend/specs/004-reliable-ai-reports/contracts/scoring-api.md`.
This file fixes how the app maps those responses to what the user sees.

## Assessment status: `GET /assessments/{id}/status`

| Response | ReportPhase | Apprentice report screen / mentor Report tab |
|---|---|---|
| 200 `{"status": "done", …}` | done | load and show the report (existing behavior) |
| 200 `{"status": "processing", …}` | preparing | "Preparing your report…" with a progress indicator; poll (5 s → 30 s) |
| 200 `{"status": "processing"}` after 3 min on screen | preparing (slow) | "Taking longer than usual — we're on it" + "Check again"; keep polling every 30 s |
| 200 `{"status": "failed", "reason": "AI provider unavailable"}` | delayed | "Taking longer than usual — we're on it", the reason, "Check again"; no scores or insights |
| 200 with an unknown `status` value | preparing | same as processing |
| 200 with no `status` (older backend) | done if `has_scores`, else preparing | as today |
| 403 / 404 | (error) | existing error handling (`friendlyError`) |
| network error / 5xx | (error) | friendly error with retry; polling continues |

## Premium report: three endpoints

`GET /assessments/{id}/my-full-report`, `GET /apprentice/my-assessments/{id}/full-report`,
`GET /mentor/submitted-drafts/{id}/full-report`

| Response | PremiumReportResult | Premium section |
|---|---|---|
| 200 `{"report": {...}, "cached": …}` | ready | show the Premium report (existing) |
| 200 `{"status": "generating", "cached": false}` | generating | "Preparing your Premium report…" loading card; re-fetch every 10 s for up to 5 min, then the still-preparing card ("Your Premium report is still being prepared." + "Try again") |
| 200 with no `report` (older backend) | generating | same as above |
| request timeout (the server holds a Premium request up to 90 s while it's generated; the client times out at 20 s) | generating | same as generating |
| 503 `{"detail": "Report is temporarily unavailable"}` | unavailable | "Your Premium report is temporarily unavailable" + "Try again"; no upsell |
| 403 | premiumRequired | existing upsell (unchanged) |
| other errors | (error) | existing behavior |

The mentor simplified screen's "View full report" button uses the same mapping. For `generating`,
the button shows progress and re-fetches; at the 5-minute cap, a snackbar shows the still-preparing copy with "Try again". For `unavailable`, a snackbar offers "Try again".

## Copy

| Key | Text |
|---|---|
| preparing | Preparing your report… |
| preparing.sub | This usually takes less than a minute. |
| slow / delayed title | Taking longer than usual — we're on it |
| delayed.sub (no reason) | Your report will be ready as soon as our AI finishes. Check back soon. |
| check again | Check again |
| premium.generating | Preparing your Premium report… |
| premium.unavailable | Your Premium report is temporarily unavailable. |
| premium.stillPreparing | Your Premium report is still being prepared. |
| try again | Try again |
