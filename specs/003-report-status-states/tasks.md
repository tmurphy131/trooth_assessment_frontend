---

description: "Tasks: Clear Report Status (preparing, delayed, Premium generating)"
---

# Tasks: Clear Report Status (preparing, delayed, Premium generating)

**Input**: Design documents from `/specs/003-report-status-states/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/report-states.md, quickstart.md

**Tests**: Principle VIII requires unit tests for the new models, the poller and the API-extension changes (`MockClient` + `setAuthForTesting`, following `test/api_service_test.dart`). Widget tests cover the new views. Each story ends with `flutter analyze --no-fatal-infos` and `flutter test` passing.

**Organization**: Tasks are grouped by user story. US1 and US2 (P1) share the status gate, so US2 builds on US1's screen wiring. US3 reuses both. US4 (Premium) depends only on the foundational Premium mapping.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: Setup

**Purpose**: Confirm the starting point.

- [X] T001 Confirm the branch is `feature/report-status-states` and that `flutter analyze --no-fatal-infos` and `flutter test` pass before any change (baseline), and note any pre-existing failures in the PR description

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Models, the poller, API methods and shared views that every story uses.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests (write first; they fail until the code below exists)

- [X] T002 [P] Create `test/report_status_test.dart` with unit tests for `ReportStatus.fromJson`:
  - `{"status":"done"}` → done;
  - `{"status":"processing"}` → preparing;
  - `{"status":"failed","reason":"AI provider unavailable"}` → delayed with that reason;
  - `{"status":"failed","reason":"  "}` → delayed with reason `null`;
  - an unknown status (`"queued"`) → preparing;
  - no `status` with `has_scores: true` → done, and with `has_scores: false` or missing → preparing;
  - a garbled map (wrong types) → preparing without throwing;
  - `health_score` parsed when present.
- [X] T003 [P] In `test/report_status_test.dart`, add `ReportStatusPoller` tests using a fake `createTimer` (records the requested durations and lets the test fire them) and a fake `now`:
  - the first interval is 5 s, still 5 s at 2:59, and 30 s from 3:00;
  - `isSlow` becomes true at 3:00;
  - no further checks are scheduled after 30:00;
  - the next check isn't scheduled until the in-flight check completes (no overlap);
  - a check that throws calls `onError` and the schedule continues;
  - `cancel()` stops everything and a late result after `cancel()` is ignored;
  - the fixed-interval mode (10 s, 5-minute cap) used for Premium.
- [X] T004 [P] Create `test/report_status_api_test.dart` (`MockClient`, `setAuthForTesting`, `clearCache` as in `test/api_service_test.dart`):
  - `getReportStatus(id)` parses 200 bodies into `ReportStatus` and throws `ApiException` on 403/404/500;
  - for each Premium fetch (`fetchOwnFullReport`, `fetchMyFullReport`, `fetchFullReport`) via the new result-returning variants:
    - 200 with `report` → ready (report and `cached`);
    - 200 `{"status":"generating","cached":false}` → generating;
    - 200 `{}` → generating;
    - 503 → unavailable;
    - 403 → premiumRequired;
    - 404 → `ApiException` with `statusCode == 404` (not a bare `Exception`);
    - 500 → `ApiException`.

### Implementation

- [X] T005 [P] Create `lib/features/assessments/models/report_status.dart`:
  - `enum ReportPhase { preparing, done, delayed }`;
  - `class ReportStatus { final ReportPhase phase; final String? reason; final int? healthScore; factory ReportStatus.fromJson(Map<String, dynamic>) }`, following data-model.md exactly ("`status == 'done'` → done; `status == 'failed'` → delayed; any other non-null `status` → preparing; `status` missing → done if `has_scores == true`, else preparing"; `reason` trimmed, `null` if empty; never throws);
  - `PremiumReportResult` with variants `ready(report, cached)`, `generating`, `unavailable`, `premiumRequired` (a sealed class or a class with a kind enum; no new packages).
- [X] T006 [P] Create `lib/features/assessments/data/report_status_poller.dart`:
  - `ReportStatusPoller<T>` with constructor params `Future<T> Function() check`, `void Function(T) onResult`, `void Function(Object) onError`, `Duration Function(Duration elapsed) interval` (default: 5 s while elapsed < 3 min, else 30 s), `Duration cap` (default 30 min), and test seams `Timer Function(Duration, void Function()) createTimer` (default `Timer.new`) and `DateTime Function() now` (default `DateTime.now`);
  - methods `start()` and `cancel()`, and getters `isSlow` (elapsed ≥ 3 min) and `isRunning`;
  - never overlaps checks; ignores results after `cancel()`;
  - a named constructor `ReportStatusPoller.fixed(Duration every, Duration cap, …)` for Premium.
- [X] T007 In `lib/services/api/assessments.dart`, add `Future<ReportStatus> getReportStatus(String assessmentId)`, which calls `GET /assessments/$assessmentId/status` (same request as `getAssessmentStatus`, which stays for existing callers), returns `ReportStatus.fromJson`, and throws `ApiException` on non-200.
- [X] T008 In `lib/services/api/mentor.dart`:
  - replace `throw Exception('Assessment not found')` in `fetchMyFullReport` and `fetchOwnFullReport` with `throw ApiException(404, 'Assessment not found')` (Principle I);
  - add `Future<PremiumReportResult> fetchOwnPremiumReport({required String assessmentId})`, `fetchMyPremiumReport({required String assessmentId})` and `fetchMentorPremiumReport({required String draftId})`, sharing one private mapper per contracts/report-states.md:
    - 200 with `report` → ready;
    - 200 with `status == 'generating'` or no `report` → generating;
    - 503 → unavailable;
    - 403 → premiumRequired;
    - others throw `ApiException`.

  Keep the existing `fetch*FullReport` methods (other callers).
- [X] T009 [P] Create `lib/features/assessments/widgets/report_status_views.dart`, using the copy in contracts/report-states.md exactly:
  - `ReportPreparingView({bool slow, VoidCallback? onCheckAgain})`: progress indicator with `Semantics(label: 'Preparing your report')`, title "Preparing your report…", subtitle "This usually takes less than a minute.". When `slow`, the title is "Taking longer than usual — we're on it" and a "Check again" button shows;
  - `ReportDelayedView({String? reason, required VoidCallback onCheckAgain, bool checking})`: title "Taking longer than usual — we're on it", the reason (or "Your report will be ready as soon as our AI finishes. Check back soon."), and a "Check again" button that shows progress while `checking`;
  - `PremiumStatusCard.generating()` ("Preparing your Premium report…" with a semantics-labelled progress indicator), `PremiumStatusCard.unavailable({required VoidCallback onTryAgain})` ("Your Premium report is temporarily unavailable." + "Try again"), and `PremiumStatusCard.stillPreparing({required VoidCallback onTryAgain})` ("Your Premium report is still being prepared." + "Try again"; shown when Premium polling reaches its 5-minute cap).

  Use the existing theme colors (black background, amber accents as in `apprentice_report_screen.dart`), text ≥ 11 px, buttons ≥ 48 px tall, and wrap rather than overflow at 1.5x text scale.
- [X] T010 [P] Create `test/report_status_views_test.dart`, with widget tests for each view (including all three `PremiumStatusCard` variants):
  - the expected text shows;
  - "Check again" and "Try again" call their callbacks;
  - the progress semantics label exists;
  - no overflow at `MediaQuery(textScaler: TextScaler.linear(1.5))` on a 360 px-wide surface.

**Checkpoint**: `flutter test test/report_status_test.dart test/report_status_api_test.dart test/report_status_views_test.dart` passes.

---

## Phase 3: User Story 1 - Apprentice sees their report being prepared, then the real report (Priority: P1) 🎯 MVP

**Goal**: The apprentice report screen shows the preparing view while processing and loads the real report automatically. It never shows the placeholder as final.

**Independent Test**: quickstart §2. Submit on dev and open the report right away. The preparing view shows, then the finished report appears within 10 s of `done`.

- [X] T011 [US1] In `lib/screens/apprentice_report_screen.dart`:
  - replace `_checkStatusThenLoad`, `_startPolling`, `_maxPollAttempts` and the `Timer.periodic` code with a `ReportStatus`-driven flow. Keep a `ReportStatus? _status` state, initially `null`, which shows the existing spinner. In `initState`, call `getReportStatus`;
  - `done` → `_loadReport()` and `_checkPremiumAndLoadFullReport()` (existing);
  - `preparing` → set `_status`, start a `ReportStatusPoller<ReportStatus>(check: () => _api.getReportStatus(id), onResult: _onStatus, onError: …)`;
  - `_onStatus` stops the poller and loads the report on `done`, and updates the view on `preparing`;
  - cancel the poller in `dispose()`, and add `if (!mounted) return;` after every `await`;
  - if the first status call throws, don't load the report. Show `ReportPreparingView(slow: false)` and a snackbar with `friendlyError(e)`, and start the poller anyway (it continues through errors), so the placeholder report is never shown (spec Edge Cases: "The status check itself fails");
  - also run one immediate check when the app returns to the foreground (`AppLifecycleListener(onResume: _checkNow)`, disposed with the screen; spec Edge Cases: "App backgrounded").
- [X] T012 [US1] In `lib/screens/apprentice_report_screen.dart`, `build()`, replace `_isProcessing ? _generatingView()` with `ReportPreparingView(slow: _poller?.isSlow ?? false, onCheckAgain: _checkNow)` while the phase is preparing. `_checkNow` runs one immediate `getReportStatus` and handles the result like `_onStatus`. Remove the now-unused `_generatingView` from `lib/screens/apprentice_report_screen_widgets.dart` if nothing else uses it. Make sure the AppBar refresh action also re-checks status first.
- [X] T013 [P] [US1] In `test/report_status_views_test.dart`, add a widget test for `ApprenticeReportScreen` with a `MockClient`:
  - status returns `processing`, then `done` on the second call;
  - pump past 5 s;
  - assert the preparing view first, then that the simplified-report request was made and the preparing view is gone;
  - assert the screen never requested the simplified report while the status was `processing`.

  Stub the other endpoints the screen calls (notes, full report → 403).

**Checkpoint**: US1 is testable on its own. `flutter analyze --no-fatal-infos` and `flutter test` pass.

---

## Phase 4: User Story 2 - A delayed or failed report is explained, not faked (Priority: P1)

**Goal**: `failed` shows the delayed view with the reason and "Check again" on the apprentice screen. "Check again" moves to the right state.

**Independent Test**: quickstart §3. A failed dev assessment shows the delayed view with "AI provider unavailable". After a re-queue and finish, "Check again" shows the report.

- [X] T014 [US2] In `lib/screens/apprentice_report_screen.dart`, handle `ReportPhase.delayed` in both the initial check and `_onStatus`:
  - stop the poller;
  - show `ReportDelayedView(reason: _status!.reason, onCheckAgain: _checkNow, checking: _checking)`;
  - don't call `_loadReport()` or the Premium fetch.

  `_checkNow` sets `_checking` and handles the outcome:
  - done → load the report;
  - preparing → show the preparing view and restart the poller;
  - delayed → stay;
  - throws → snackbar with `friendlyError(e)`.
- [X] T015 [P] [US2] In `test/report_status_views_test.dart`, add an `ApprenticeReportScreen` widget test:
  - status `{"status":"failed","reason":"AI provider unavailable"}` → the delayed view and reason show, and no simplified-report request is made;
  - tap "Check again" with status now `processing` → the preparing view shows;
  - then `done` → the report loads.

**Checkpoint**: US1 + US2 cover the apprentice screen completely.

---

## Phase 5: User Story 3 - Mentor report screens follow the same states (Priority: P2)

**Goal**: The mentor submission detail screen gates its Report tab on status (preparing or delayed views, auto-loading when done). The Answers and Notes tabs stay usable.

**Independent Test**: quickstart §4. As the mentor, open a just-submitted assessment. The Report tab shows the preparing view and then the report. A failed one shows the delayed view.

- [X] T016 [US3] In `lib/features/assessments/screens/mentor_submission_detail_screen.dart`:
  - add `ReportStatus? _status`, a `ReportStatusPoller<ReportStatus>? _poller` and `bool _checking`;
  - in `initState`, check `getReportStatus(widget.assessmentId)` before calling the report part of `_load()`. Keep `getSubmissionDetail` (answers) loading regardless, and load `getMentorReportV2` only when the status is `done`. If the status check throws, the Report tab shows `ReportPreparingView(slow: false)` with a snackbar using `friendlyError(e)` and the poller starts anyway; the mentor report is never loaded before `done` (spec Edge Cases);
  - run one immediate check on app resume (`AppLifecycleListener(onResume: …)`, disposed with the screen);
  - `_reportTab()` returns `ReportPreparingView` / `ReportDelayedView` while preparing or delayed. The Answers and Notes tabs are unchanged;
  - the poller starts on preparing, loads the report on done, and switches to the delayed view on delayed;
  - cancel it in `dispose()`, and add `mounted` checks after every `await`.
- [X] T017 [US3] In `lib/features/assessments/screens/mentor_submission_detail_screen.dart`, also gate anything that opens `MentorReportSimplifiedScreen` or the Premium report, so nothing opens before the status is `done`: disable the button or show the status view instead, and add a tooltip on any affected `IconButton`.
- [X] T018 [P] [US3] In `test/report_status_views_test.dart`, add a `MentorSubmissionDetailScreen` widget test. Stub every endpoint the screen calls (submission detail, mentor report, notes, subscription status and the mentor profile used by `_loadMentorEmail`) with 200s, so the `FirebaseAuth.instance` fallback (`mentor_submission_detail_screen.dart` `_loadMentorEmail`) never runs. Apply the same stubbing rule in T013, T015 and T022:
  - status `processing` → the Answers tab content renders and the Report tab shows the preparing view;
  - status flips to `done` → the mentor report request is made and the report renders;
  - status `failed` → the Report tab shows the delayed view.

**Checkpoint**: Apprentice and mentor screens follow the same states.

---

## Phase 6: User Story 4 - Premium section shows that it's being prepared (Priority: P2)

**Goal**: The Premium section handles generating (loading plus 10 s re-fetch for up to 5 min), unavailable (message plus "Try again", no upsell) and premiumRequired (unchanged upsell) on all three screens.

**Independent Test**: quickstart §5. As the premium apprentice, open the report as soon as it's done. The Premium section shows its loading card and fills in without leaving the screen.

- [X] T019 [US4] In `lib/screens/apprentice_report_screen.dart` (and its part file `lib/screens/apprentice_report_premium_widgets.dart`), switch `_checkPremiumAndLoadFullReport` to `fetchOwnPremiumReport`:
  - `ready` → `_isPremium = true`, `_fullReport = report` (existing premium view);
  - `generating` → `_isPremium = true`, `_premiumState = generating`, start a `ReportStatusPoller<PremiumReportResult>.fixed(every: 10 s, cap: 5 min)` that re-fetches until ready;
  - `unavailable` → `_premiumState = unavailable`;
  - `premiumRequired` → `_showPremiumUpsell = true` (unchanged);
  - other errors → hide the section as today.

  In `_contentView()`, where the upsell or Premium entry renders, show `PremiumStatusCard.generating()` or `PremiumStatusCard.unavailable(onTryAgain: _retryPremium)` for those states. When the poller reaches its cap, show `PremiumStatusCard.stillPreparing(onTryAgain: _retryPremium)`. Cancel it in `dispose()`.
- [X] T020 [US4] In `lib/features/assessments/screens/mentor_submission_detail_screen.dart`, switch `_loadFullReport` to `fetchMentorPremiumReport(draftId: widget.assessmentId)` with the same state handling (generating → 10 s / 5-minute poller; unavailable → card with "Try again"; cap → `stillPreparing` card; premiumRequired → existing `_showPremiumGate` path). Move the Premium fetch out of `initState`: call `_checkPremiumAndLoadFullReport()` only once the status is `done` (from the same place `getMentorReportV2` loads in T016), so no Premium request is made for a processing assessment (spec Edge Cases). Update `_onPremiumReportTap` so that a tap while generating shows a snackbar saying it's still being prepared, instead of the old generic snackbar.
- [X] T021 [US4] In `lib/features/assessments/screens/mentor_report_simplified_screen.dart`, `_fetchAndShowFullReport`, use `fetchMentorPremiumReport(draftId: widget.draftId!)`:
  - `ready` → push `_PremiumFullReportScreen` (existing);
  - `generating` → keep `_loadingFullReport` true and re-fetch every 10 s for up to 5 min (a fixed poller, cancelled in `dispose()`), then open the report when ready, or show a snackbar "Your Premium report is still being prepared." with a "Try again" `SnackBarAction` at the cap (same copy as `PremiumStatusCard.stillPreparing`);
  - `unavailable` → snackbar "Your Premium report is temporarily unavailable." with a "Try again" `SnackBarAction`;
  - `premiumRequired` → the existing upgrade dialog.

  Remove the `report == null → _buildBasicFullReportScaffold()` branch only if nothing else uses it.
- [X] T022 [P] [US4] In `test/report_status_views_test.dart`, add an `ApprenticeReportScreen` Premium widget test:
  - status `done`, Premium returns `{"status":"generating"}` then a report on the second call → the generating card shows, then the Premium content after 10 s;
  - Premium 503 → the unavailable card with "Try again" and no upsell;
  - Premium 403 → the upsell (unchanged).

**Checkpoint**: All four stories work. `flutter analyze --no-fatal-infos` and `flutter test` pass.

---

## Phase 7: Polish & Cross-Cutting

- [X] T023 [P] Remove dead code left by the old polling: `_isProcessing`, `_maxPollAttempts`, an unused `_generatingView`, and unused imports in `lib/screens/apprentice_report_screen.dart` and `lib/screens/apprentice_report_screen_widgets.dart`. Confirm there's no new `print` (Principle X) and that log lines contain no bodies or PII (Principle III).
- [X] T024 Run `flutter analyze --no-fatal-infos` and `flutter test`; all pass.
- [ ] T025 Manual validation on dev per `quickstart.md` §2–§6 (simulator, guide accounts; for §3, break and then **restore** the dev backend config exactly as described). Record the results (SC-001 10-run count, SC-002, SC-003 count, SC-004 checks including the run against prod) in the PR.
  - **Simulator results, 2026-10-11** (iPhone 17 Pro, dev revision 00098, guide accounts, 10 runs):
    - §2 / SC-001: the preparing view showed in 10/10 runs and the placeholder in 0/10. The finished report appeared 3.2–7.6 s after the backend marked it done (backend done 20–74 s after submit).
    - §5 / SC-003: the Premium loading card showed and the Premium report filled in without leaving the screen in 10/10 runs (15–37 s after the free report). This was found and fixed during the run: the 20 s client timeout was shorter than the server's 90 s Premium wait, so the request timed out and the section disappeared. A timeout now maps to `generating` (`RequestTimeoutException`).
    - §4 (US3): mentor Report tab showed preparing with the Answers tab built; the report appeared 28.6 s after the mentor opened it.
    - Not run live: §3 (needs breaking the dev AI config; covered by widget tests), §6 free-user upsell (guide accounts are premium; covered by widget/API tests) and the prod run.
- [X] T026 Record the backend T036 result (the released store app against the dev backend: `failed` shows the placeholder without crashing, a generating Premium response shows an empty section, 503 hides it) in backend PR #34 or the spec 004 polish PR.
- [X] T027 Release note: this app version ships only after backend #33/#34 are on prod (Principle XII). Version bump via `/bump-version` when releasing (Principle XI); not part of this feature's PR.

---

## Dependencies & Execution Order

- **Phase 1 → Phase 2** (T002–T004 tests and T005, T006, T009, T010 in parallel; T007 after T005; T008 after T005).
- **US1 (T011–T013)** depends on Phase 2.
- **US2 (T014–T015)** depends on US1 (same screen, same flow).
- **US3 (T016–T018)** depends on Phase 2. It can run in parallel with US1 and US2 (different file).
- **US4 (T019–T022)** depends on Phase 2:
  - T019 touches the apprentice screen, so do it after T011–T014;
  - T020 touches the mentor detail screen, so do it after T016–T017;
  - T021 can run any time after Phase 2.
- **Polish** last.

## Parallel Opportunities

- Phase 2: T002, T003 and T004 together; then T005, T006, T009 and T010 together.
- US3 (mentor detail screen) alongside US1 and US2 (apprentice screen).
- T021 (simplified screen) alongside any other story.
- Widget test tasks marked [P] can be written alongside their story's implementation.

## Implementation Strategy

1. **MVP = Phase 2 + US1 + US2**: the apprentice never sees the placeholder report, and failed reports are explained. This alone fixes the most visible problem.
2. **US3**: mentors get the same states.
3. **US4**: Premium generating and unavailable handling on all three screens.
4. Polish and dev validation, then release after the backend reaches prod.
