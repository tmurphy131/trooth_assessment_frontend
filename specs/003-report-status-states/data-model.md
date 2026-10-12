# Data Model: Clear Report Status

Client-side models only (`lib/features/assessments/models/report_status.dart`). Nothing is stored.

## ReportStatus

Parsed from `GET /assessments/{id}/status`.

| Field | Type | Rule |
|---|---|---|
| `phase` | enum `ReportPhase { preparing, done, delayed }` | `status == 'done'` → done; `status == 'failed'` → delayed; any other non-null `status` → preparing; `status` missing → done if `has_scores == true`, else preparing (older backends, FR-002) |
| `reason` | `String?` | from `reason` when delayed; trimmed; `null` if empty |
| `healthScore` | `int?` | from `health_score` when present (informational) |

`ReportStatus.fromJson(Map<String, dynamic>)` never throws on unexpected shapes. An unknown or garbled
response becomes `preparing`.

## PremiumReportResult

Returned by the Premium fetch helpers in `lib/services/api/mentor.dart`.

| Variant | When | Carries |
|---|---|---|
| `ready` | 200 with a non-null `report` | `report` (Map), `cached` (bool) |
| `generating` | 200 with `status == 'generating'`, or 200 with no `report` | none |
| `unavailable` | 503 | none |
| `premiumRequired` | 403 | none. The new `fetch*PremiumReport` methods **return** this variant and never throw `PremiumRequiredException`; the existing `fetch*FullReport` methods keep throwing it for their current callers |

Other failures (network, 404, 5xx other than 503) are thrown as `NetworkException` / `ApiException`,
as today.

## ReportStatusPoller (behavior, `lib/features/assessments/data/report_status_poller.dart`)

| Property | Value |
|---|---|
| interval | 5 s while elapsed < 3 min; 30 s after |
| `isSlow` | true once elapsed ≥ 3 min (drives the "Taking longer than usual" copy, FR-004) |
| cap | stops after 30 min; the screen keeps its "Check again" action (FR-006) |
| overlap | never runs a check while the previous one is in flight |
| errors | a failed check is reported (`onError`) and the schedule continues |
| stop | `cancel()` on dispose, and when the status becomes done or delayed |
| test seam | constructor takes `Timer Function(Duration, void Function()) createTimer` and `DateTime Function() now` |

Premium polling reuses the same class with a fixed 10 s interval and a 5-minute cap.

## Screen state transitions

```text
open → check status
  done      → load report (existing loaders) → Premium fetch (if premium)
  preparing → PreparingView + poller ──(done)──► load report
                         └─(3 min)─► PreparingView(slow: "Taking longer than usual", Check again)
                         └─(failed)─► DelayedView
  delayed   → DelayedView(reason, Check again) ──tap──► check status (any branch above)

Premium (premium users, after the report is done):
  ready → show report
  generating → PremiumStatusCard(loading) + 10 s re-fetch ≤ 5 min ──► ready | PremiumStatusCard(stillPreparing, Try again)
  unavailable → PremiumStatusCard(message + Try again)
  premiumRequired → existing upsell
```
