# Feature Specification: Clear Report Status (preparing, delayed, Premium generating)

**Feature Branch**: `feature/report-status-states` | **Spec Folder**: `specs/003-report-status-states/`

**Created**: 2026-10-11

**Status**: Draft

**Input**: User description: "Clear report status in the app for delayed, failed and still-generating AI reports (frontend follow-up to backend spec 004-reliable-ai-reports)."

**Backend contract**: `trooth_assessment_backend/specs/004-reliable-ai-reports/contracts/scoring-api.md` (status values `processing | done | failed`, failure `reason`, Premium `{"status": "generating"}` and 503 "Report is temporarily unavailable"). No backend changes are part of this feature.

## Background

The backend now scores assessments through a retry queue. A report is normally ready about 25
seconds after submission. If the AI provider is down, the assessment stays "processing" while it
retries, and after an hour without success it becomes "failed" with a short reason, such as "AI
provider unavailable". An admin or the automatic sweep can re-queue it later. The Premium report is
generated once, right after the free report. While it's being prepared, asking for it returns
"generating"; if generation failed, it returns "temporarily unavailable".

The released app doesn't understand these states:

- **Apprentice report screen:** an instant placeholder score is stored at submission, so the app
  thinks scoring has finished almost immediately. It stops checking after one tick and shows the
  placeholder report ("Awaiting detailed AI analysis") as if it were final. A failed assessment
  shows that placeholder with no explanation.
- **Mentor report screens** (submission detail, simplified report) never check status. They show
  whatever is stored, including the placeholder.
- **Premium section:** when the Premium report is "generating", the app treats the user as premium
  but shows an empty section and never checks again. "Temporarily unavailable" hides the section
  with no message.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Apprentice sees their report being prepared, then the real report (Priority: P1)

An apprentice submits an assessment and opens their report. While the AI is still working, they see
"Preparing your report…" instead of a placeholder report. The screen keeps checking on its own and
shows the finished report as soon as it's ready, with no need to leave and come back.

**Why this priority**: Every apprentice hits this on every submission. Today they're shown a fake
"Awaiting detailed AI analysis" report that looks broken, and they have to back out and reopen the
screen to see the real one.

**Independent Test**: Submit an assessment on dev and open the report right away. The preparing state
shows, then it switches to the finished report (with real strengths and insights) within a few
seconds of the backend marking it done, without any user action.

**Acceptance Scenarios**:

1. **Given** an assessment whose status is processing, **When** the apprentice opens the report,
   **Then** they see "Preparing your report…" and no placeholder scores or insights.
2. **Given** the preparing state is showing, **When** the backend marks the assessment done,
   **Then** the screen loads and shows the finished report within 10 seconds, without the user
   doing anything.
3. **Given** an assessment that is already done, **When** the apprentice opens the report,
   **Then** the report shows immediately (no preparing state).
4. **Given** the preparing state has lasted more than 3 minutes, **When** the apprentice is still on
   the screen, **Then** the message changes to "Taking longer than usual — we're on it", checking
   continues at a slower pace, and a "Check again" action is offered.

---

### User Story 2 - A delayed or failed report is explained, not faked (Priority: P1)

When scoring couldn't finish (the assessment is failed), the apprentice and the mentor see "Taking
longer than usual — we're on it" with the short reason and a "Check again" action. They never see
the placeholder report presented as the result. If the assessment is re-queued and finishes later,
"Check again" (or reopening the screen) shows the real report.

**Why this priority**: During the 2026-10-10 outage, users saw empty reports with a Health Score of
0%. The backend now reports the failure honestly, but users only benefit if the app shows it.

**Independent Test**: On dev, open an assessment whose status is failed. The delayed message and
reason show for both the apprentice and the mentor. Re-queue it with the admin tool. Once it's done,
"Check again" shows the finished report.

**Acceptance Scenarios**:

1. **Given** an assessment whose status is failed with reason "AI provider unavailable",
   **When** the apprentice or mentor opens the report, **Then** they see "Taking longer than usual —
   we're on it", the reason, and a "Check again" action, and no scores or insights.
2. **Given** the failed message is showing, **When** the assessment has since been re-queued and
   finished and the user taps "Check again", **Then** the finished report shows.
3. **Given** the failed message is showing, **When** the assessment has been re-queued but is still
   processing and the user taps "Check again", **Then** the preparing state from User Story 1 shows
   and automatic checking resumes.

---

### User Story 3 - Mentor report screens follow the same states (Priority: P2)

A mentor opening an apprentice's submission (the submission detail screen or the simplified report)
gets the same behavior as the apprentice: "Preparing…" while processing, with automatic checking;
the delayed message when failed; the report when done.

**Why this priority**: Mentors are usually notified once the report is done, so they hit the
preparing state less often than apprentices. But they can open a submission from the list at any
time, and today they'd see the placeholder.

**Independent Test**: As the mentor on dev, open an apprentice's submission right after the
apprentice submits. The preparing state shows, then switches to the report.

**Acceptance Scenarios**:

1. **Given** an apprentice's assessment is processing, **When** their mentor opens the submission,
   **Then** the mentor sees the preparing state and the report loads automatically once it's done.
2. **Given** the assessment is failed, **When** the mentor opens it, **Then** they see the delayed
   message with the reason and "Check again".

---

### User Story 4 - Premium section shows that it's being prepared (Priority: P2)

A premium user (apprentice or mentor) opens a finished report while the Premium report is still
being generated. The Premium section shows a loading state ("Preparing your Premium report…") and
fills in automatically when it's ready. If the Premium report is temporarily unavailable, the section
says so and offers "Try again", rather than disappearing or showing an upgrade prompt.

**Why this priority**: The Premium report takes about 40 seconds more after the free report.
Premium users who open their report right away currently see an empty Premium section with no sign
that anything is coming.

**Independent Test**: As the premium apprentice on dev, submit and open the report as soon as it's
done. The Premium section shows its loading state and fills in within about a minute. On a build
pointed at a backend that returns "temporarily unavailable", the section shows the message and
"Try again".

**Acceptance Scenarios**:

1. **Given** the Premium report is generating, **When** a premium user views the report,
   **Then** the Premium section shows "Preparing your Premium report…" and checks again
   automatically, every 10 seconds.
2. **Given** the Premium loading state is showing, **When** the Premium report becomes ready,
   **Then** it appears in the section without the user doing anything.
3. **Given** the Premium report is temporarily unavailable, **When** a premium user views the
   report, **Then** the section shows "Your Premium report is temporarily unavailable" and a
   "Try again" action, and no upgrade prompt.
4. **Given** a free user, **When** they view the report, **Then** the upgrade prompt shows exactly
   as it does today.
5. **Given** the Premium loading state has lasted more than 5 minutes, **When** the user is still on
   the screen, **Then** automatic checking stops and the section says "Your Premium report is still being
   prepared" and offers "Try again".

---

### Edge Cases

- **Older backends** that only return processing/done (no failed, no reason, no Premium
  "generating"): the screens still work. Processing shows the preparing state, done shows the
  report, and a Premium response with no report and no status is treated like today (no crash).
- **Unknown status value:** treated as not finished. Show the preparing state and keep checking,
  within the same time limits.
- **The status check itself fails** (network error, 5xx): show the user-friendly error with a retry,
  not the placeholder report. Automatic checking keeps going; one failed check doesn't stop it.
- **Leaving the screen** stops all automatic checking. Coming back starts fresh.
- **App backgrounded** while checking: checking continues harmlessly, and on return the screen
  checks once immediately so it shows the current state.
- **Done, but no AI insights** (an assessment with no open-ended answers): shown as a normal finished
  report. "Done" from the backend is trusted.
- **A legacy assessment with no status field:** fall back to today's rule (it has scores → show the
  report).
- **Premium report requested on a processing assessment:** the backend answers "generating". The app
  waits for the free report first, so this only happens briefly.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The apprentice report screen and the mentor submission detail screen MUST decide what
  to show from the assessment's status, and the mentor simplified report screen MUST only be
  reachable once the status is done. "Done" shows the
  report. "Processing" (or any unknown value) shows the preparing state. "Failed" shows the delayed
  state. Stored placeholder scores MUST NOT be treated as "done".
- **FR-002**: When the response has no status field (an older backend), the screens MUST fall back to
  the current rule: an assessment with scores is treated as done.
- **FR-003**: While in the preparing state, the screen MUST check the status automatically, every 5 seconds (no
  more often) for the first 3 minutes and every 30 seconds after that. It MUST load the
  report as soon as the status is done.
- **FR-004**: After 3 minutes in the preparing state, the screen MUST show "Taking longer than usual
  — we're on it" and a "Check again" action, and keep checking.
- **FR-005**: The delayed state (status failed) MUST show "Taking longer than usual — we're on it",
  the backend's reason when one is provided, and a "Check again" action that re-checks the status
  and moves to the right state. It MUST NOT show scores, insights or the placeholder report.
- **FR-006**: Automatic checking MUST stop when the user leaves the screen, and MUST stop after
  30 minutes on the screen (the user can still tap "Check again").
- **FR-007**: When a premium user's Premium report request returns "generating", the Premium section
  MUST show a loading state and re-request it every 10 seconds (no more often), for up to 5 minutes,
  then say it's still being prepared and offer "Try again".
- **FR-008**: When the Premium report request returns "temporarily unavailable", the Premium section
  MUST show a short message and a "Try again" action. It MUST NOT show the upgrade prompt or hide the
  section.
- **FR-009**: The upgrade prompt for non-premium users (the backend's premium-required response) MUST
  behave exactly as it does today.
- **FR-010**: User-facing text MUST be plain and reassuring. Error and failure messages MUST follow
  the app's existing friendly-error conventions, and the backend's raw error details MUST NOT be
  shown.
- **FR-011**: The new states MUST meet the app's accessibility rules: screen-reader labels for the
  loading indicators, readable text sizes, and layouts that work at 1.5x text scale.

### Key Entities

- **Assessment status**: processing, done or failed, plus an optional short reason when failed.
  Comes from the backend's assessment status endpoint.
- **Premium report state**: ready (report present), generating, temporarily unavailable, or premium
  required (not premium).

### Roles, Access & Backend Dependencies *(mandatory)*

- **Roles**: apprentice (own report), mentor (their apprentices' submissions).
- **Premium**: the Premium section is premium-gated. The backend enforces it, and the client shows
  the upgrade prompt on 403 (unchanged).
- **Backend**: all endpoints already exist in `trooth_assessment_backend` (spec 004, on dev):
  - `GET /assessments/{id}/status` returns `status` and `reason`;
  - the Premium endpoints `GET /assessments/{id}/my-full-report`,
    `GET /apprentice/my-assessments/{id}/full-report` and
    `GET /mentor/submitted-drafts/{id}/full-report` return `{"status": "generating"}` or 503.

  No backend changes. The status endpoint already allows the apprentice and their mentors.
- **Data & privacy**: no new personal data. No privacy manifest or store label changes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 10 dev submissions with the report screen opened immediately, the placeholder report
  is never shown, and the finished report appears within 10 seconds of the backend marking it done in
  all 10.
- **SC-002**: For a failed assessment, the apprentice and the mentor see the delayed message and
  reason in 100% of opens, and never a Health Score of 0 or empty insights presented as a result.
- **SC-003**: A premium user who opens the report as soon as it's done sees the Premium report appear
  without leaving the screen in at least 9 of 10 dev runs.
- **SC-004**: No regressions: free users still see the upgrade prompt, already-finished reports open
  with no extra delay (no preparing flash longer than the first status check), and the app works
  against a backend without the new states.

## Assumptions

- **Status access for mentors:** confirmed. `GET /assessments/{id}/status` authorizes the apprentice
  and any mentor linked to them, so the mentor screens use the same status check.
- **Timing values** (5 s / 30 s checks, 3-minute "longer than usual", 5-minute Premium limit,
  30-minute cap) are defaults chosen from the backend's normal timings (about 25 s free, about 40 s
  more for Premium, a 1-hour retry window). They can be tuned in planning.
- **Push notifications** for "your report is ready" are out of scope. Users reach the report through
  the existing screens and the mentor email.
- **List screens** (Progress, the mentor's submissions list) are out of scope. They keep their
  current display, and only opening a report shows the new states.
- Reports, layouts and copy outside these states are unchanged. Email changes are a separate feature.
