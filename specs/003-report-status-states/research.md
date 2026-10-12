# Research: Clear Report Status

## R1. How to decide "done"

- **Decision**: use the status endpoint's `status` field: `done` means finished, `failed` means
  delayed, and `processing` or any other value means preparing. Only when `status` is missing (an
  older backend) fall back to `has_scores`.
- **Rationale**: the backend stores an instant placeholder score at submit, so `has_scores` is true
  within milliseconds. The released app's `status == 'done' || has_scores` check is why polling stops
  at the first tick (spec Background). The backend contract guarantees `status` on every response
  since spec 004, and it also derives `status` from scores for legacy rows.
- **Alternatives**: detect the placeholder by content ("Awaiting detailed AI analysis", level
  "Baseline"). That's fragile (copy can change) and unnecessary now that `status` is authoritative.

## R2. Polling mechanism

- **Decision**: a small `ReportStatusPoller` that runs a check callback on a schedule (every 5 s for
  the first 3 min, then every 30 s, stopping at 30 min). It reports each result through callbacks,
  never runs two checks at once, and takes an injectable `Timer Function(Duration, void Function())`
  for tests. Screens create it in `initState`, and cancel it in `dispose` and whenever the status
  leaves `processing`.
- **Rationale**: the same schedule is needed on three screens. Today the apprentice screen inlines a
  `Timer.periodic` (10 s × 30). An injectable timer avoids adding `fake_async` (a transitive
  dependency that would trip `depend_on_referenced_packages`) and keeps the schedule unit-testable.
- **Alternatives**: `Stream.periodic`, which is harder to test for backoff; a state-management
  package, which Principle VI forbids without an amendment; push or websockets, which are out of
  scope and have no backend support.

## R3. Timing values

- **Decision**:
  - status checks every 5 s for 3 min, then every 30 s, stopping at 30 min;
  - "longer than usual" copy after 3 min;
  - Premium re-requests every 10 s for up to 5 min.
- **Rationale**: the backend finishes in about 25 s (dev median 24 s, max 32.5 s), so 5 s checks meet
  SC-001 (finished report within 10 s). Retries after an AI outage back off for up to an hour, so
  30 s checks beyond 3 min avoid wasted calls. Premium takes about 40 s after the free report (dev
  revision 00098), so up to 5 min covers the slow tail (105–132 s observed). Each Premium request can
  itself wait up to 90 s on the server.
- **Alternatives**: a fixed 10 s interval, as today, which wastes about 180 calls/hour during an
  outage and is slower for normal finishes.

## R4. Premium response handling

- **Decision**: map every Premium endpoint response to `PremiumReportResult`:
  - `ready(report, cached)`: 200 with a `report`;
  - `generating`: 200 with `status == 'generating'`, or 200 with no `report` (older backends);
  - `unavailable`: 503;
  - a client timeout (`RequestTimeoutException`, a `NetworkException` subtype) maps to `generating`. Found in the simulator check: the server waits up to 90 s on another caller's generation, but the app's request timeout is 20 s, so the first Premium request after the report is done timed out and the section disappeared (the released app has the same bug);
  - `premiumRequired`: 403 (`PremiumRequiredException`, unchanged);
  - other errors: rethrown as today.

  Screens poll while `generating`, show a retry card for `unavailable`, and keep the existing upsell
  for `premiumRequired`.
- **Rationale**: the released code treats any 200 as premium-ready (empty section) and any non-403
  error as "not premium, no upsell" (silent hide). A single mapping fixes all three screens the same
  way.
- **Alternatives**: separate handling per screen, which would duplicate the bugs.

## R5. Mentor screens

- **Decision**:
  - **Submission detail:** check status before loading the report. While processing or failed, the
    Report tab shows the status view. The Answers and Notes tabs stay usable. The Premium section
    follows R4.
  - **Simplified report:** this screen receives an already-loaded report from the detail screen, so
    it's only opened once the status is `done`. Its "View full report" button follows R4. `generating`
    shows an in-place progress state on the button and re-requests up to 5 min, and `unavailable`
    shows a snackbar with "Try again".
- **Rationale**: answers and notes don't depend on AI scoring, so blocking them would be a
  regression. The simplified screen has no status of its own to check.

## R6. Backward compatibility (released app vs new backend, new app vs old backend)

- **New app on today's prod backend** (before #33/#34 reach prod):
  - prod already returns `status` as `processing`/`done` (`failed` arrives with spec 004, which isn't
    on prod yet), so the gate works;
  - Premium never returns `generating`, so `ready`/`premiumRequired` behave as today;
  - a 200 with no report maps to `generating` and times out to "Try again" after 5 min, which is
    acceptable.
- **Released app on the new backend** (backend T036): from reading the code,
  - `failed` shows the placeholder report with no explanation;
  - a `generating` Premium response shows an empty section;
  - 503 hides the section;
  - nothing crashes.

  To be confirmed on dev and recorded in the backend PR.
