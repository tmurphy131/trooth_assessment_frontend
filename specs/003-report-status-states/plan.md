# Implementation Plan: Clear Report Status (preparing, delayed, Premium generating)

**Branch**: `feature/report-status-states` | **Date**: 2026-10-11 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-report-status-states/spec.md`

## Summary

Report screens stop treating the instant placeholder score as a finished report. They read the
backend's assessment `status` (`processing | done | failed` plus `reason`) through one parser, show a
"Preparing your report…" view while processing, with automatic checks on a backoff schedule, and a
"Taking longer than usual" view with the reason and "Check again" when failed. The Premium section
handles the backend's `{"status": "generating"}` with its own polling, and 503 "temporarily
unavailable" with a retry, instead of an empty section or silent hiding. The pieces:

- one status parser and one Premium result type (models, with unit tests);
- one small poller that takes an injectable timer;
- two shared status widgets;
- changes to three screens: the apprentice report, the mentor submission detail, and the mentor
  simplified report.

No backend changes and no new packages.

## Technical Context

**Language/Version**: Dart / Flutter (version pinned in `.github/workflows/release.yml`)

**Primary Dependencies**: existing only (`http`, `flutter`). No new packages. Tests use `flutter_test`
and `package:http/testing.dart` (`MockClient`), already used in `test/api_service_test.dart`.

**Backend Endpoints** (all exist; contract `trooth_assessment_backend/specs/004-reliable-ai-reports/contracts/scoring-api.md`):
- `GET /assessments/{id}/status` returns `{status, has_scores, health_score?, reason?}`. It authorizes the
  apprentice and linked mentors (verified in `app/routes/assessment.py`).
- `GET /assessments/{id}/my-full-report`, `GET /apprentice/my-assessments/{id}/full-report` and
  `GET /mentor/submitted-drafts/{id}/full-report` return 200 `{report, cached, …}`, 200
  `{"status": "generating", "cached": false}`, 503 `{"detail": "Report is temporarily unavailable"}`,
  or 403 (premium required).

**Storage**: backend API only.

**Testing**: `flutter test` (unit tests for the parser, Premium result mapping, poller schedule and API
methods; widget tests for the status views and the apprentice screen's state switching).
`integration_test/` isn't needed (no auth or session changes).

**Target Platform**: iOS and Android (store builds)

**Project Type**: mobile-app (backend: `trooth_assessment_backend`)

**Performance Goals**: the finished report appears within 10 s of the backend marking it done
(SC-001); there's no added delay for reports that are already done (one status call, then the
existing loads).

**Constraints**:
- polling at most every 5 s for the first 3 min, then every 30 s, capped at 30 min;
- Premium polling at most every 10 s for up to 5 min;
- all timers stop when the screen is disposed.

**Scale/Scope**: 3 screens, 2 new widgets, 2 new models, 1 poller, API methods in 2 extension files.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Source: `.specify/memory/constitution.md`.

- [x] **I. API gateway** ✅: status and Premium calls stay in `lib/services/api/assessments.dart` and
  `lib/services/api/mentor.dart`, and throw typed exceptions only. The existing bare
  `throw Exception('Assessment not found')` in `fetchMyFullReport` / `fetchOwnFullReport` becomes
  `ApiException(404, …)`.
- [x] **II. Environment** ✅: no URLs added. Verified on dev before any release tag.
- [x] **III. Security & privacy** ✅: no new data. Log lines keep to keys and status values (no bodies
  or PII). Access is still enforced by the backend.
- [x] **IV. Errors** ✅: status-check failures use `friendlyError()`. The backend `reason` is a short
  user-safe string by contract and is shown as-is with a fallback. Every `await` in the screens is
  followed by a `mounted` check, and the poller is cancelled in `dispose()`.
- [x] **V. Session** N/A: no sign-in or sign-out changes.
- [x] **VI. Structure** ✅: `setState` plus singletons. New files go in the existing feature folder
  `lib/features/assessments/` (`models/`, `data/`, `widgets/`). There are no new routes; the screens
  are pushed as today.
- [x] **VII. Accessibility** ✅: the status views use `Semantics` labels on progress indicators,
  text ≥ 11 px, buttons ≥ 48 px, and layouts that wrap at 1.5x text scale (widget test at 1.5x).
- [x] **VIII. Tests** ✅: unit tests for the models, poller and API changes; widget tests for the
  views. `flutter analyze --no-fatal-infos` and `flutter test` must pass.
- [x] **IX. Dependencies** ✅: none added (the poller takes a timer factory instead of using
  `fake_async`, a transitive dependency).
- [x] **X. Logging** ✅: `dev.log` only, no `print`.
- [x] **XI. Release** ✅: no version change in this feature. Released via `/bump-version` later.
- [x] **XII. Cross-repo** ✅: every endpoint is named above and exists in the backend (spec 004).
  **Ships after** backend PRs #33 and #34 are on prod. Against today's prod the app degrades to the
  current behavior (FR-002).

## Project Structure

### Documentation (this feature)

```text
specs/003-report-status-states/
├── plan.md              # This file
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   └── report-states.md # Phase 1: API responses → UI states
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/
├── features/assessments/
│   ├── models/report_status.dart            # NEW ReportStatus (phase + reason) and PremiumReportResult
│   ├── data/report_status_poller.dart       # NEW backoff poller with injectable timer factory
│   ├── widgets/report_status_views.dart     # NEW ReportPreparingView, ReportDelayedView, PremiumStatusCard
│   └── screens/
│       ├── mentor_submission_detail_screen.dart   # CHANGED: status gate on the Report tab + Premium states
│       └── mentor_report_simplified_screen.dart   # CHANGED: Premium generating/unavailable on "View full report"
├── screens/
│   ├── apprentice_report_screen.dart        # CHANGED: uses ReportStatus + poller; Premium states
│   ├── apprentice_report_screen_widgets.dart   # CHANGED: part file; `_contentView()` shows the Premium status cards; old `_generatingView` removed
│   └── apprentice_report_premium_widgets.dart  # CHANGED: part file of the apprentice screen; Premium content view (the status cards render from `_contentView()` in apprentice_report_screen_widgets.dart)
└── services/api/
    ├── assessments.dart                     # CHANGED: getReportStatus() → ReportStatus
    └── mentor.dart                          # CHANGED: fetch*FullReport → PremiumReportResult helpers; 404 typed
test/
├── report_status_test.dart                  # NEW parser, Premium mapping, poller schedule
├── report_status_api_test.dart              # NEW API methods via MockClient (200/503/403/legacy)
└── report_status_views_test.dart            # NEW widget tests (views, 1.5x text, apprentice state switch)
```

**Structure Decision**: everything goes in the existing `lib/features/assessments/` feature folder and
the two existing API extension files. The apprentice screen stays in `lib/screens/`, where it is today.
There are no new routes.

## Complexity Tracking

No constitution violations.
