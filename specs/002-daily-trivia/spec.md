# Feature Specification: Daily Trivia Question & Streak Rewards (app)

**Feature Branch**: `feature/daily-trivia` | **Spec Folder**: `specs/002-daily-trivia/`

**Created**: 2026-10-08

**Status**: Draft

**Input**: User description: "Daily trivia questions. Each user gets a daily trivia notification at 9am, and when they open the app there is a daily trivia modal with a multiple choice question. Everyone sees the same question each day. Questions are random between beginner and challenger level, from a random category, and the category and level are shown in the modal. The app keeps track of daily question streaks and shows the streak weekly or monthly depending on how many the person has answered in a row. 45/60/90-day streaks earn 15/35/50% off merch, upgraded rather than stacked, with +10% for a perfect run. All coupons are automated."

Backend contract (source of truth): [`trooth_assessment_backend/specs/002-daily-trivia/contracts/daily-trivia-api.md`](../../../trooth_assessment_backend/specs/002-daily-trivia/contracts/daily-trivia-api.md). Backend spec: `trooth_assessment_backend/specs/002-daily-trivia/spec.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Daily question modal on open (Priority: P1)

When a signed-in user reaches their dashboard and hasn't answered today, a modal shows today's question. It shows the category and level as chips, then the question and its options (four, or two for true/false). The user taps an option and sees right or wrong, the correct answer and their updated streak. They can close the modal without answering.

**Why this priority**: This is the daily touchpoint the feature exists for.

**Independent Test**: With an unanswered day on dev, open the app. The modal appears once with the category, level and options. Answer it and see the result. Reopen the app the same day and the modal doesn't appear.

**Acceptance Scenarios**:

1. **Given** a user who hasn't answered today, **When** their dashboard finishes loading (after the first-run tutorial and notification prompt, if those show), **Then** the daily question modal opens.
2. **Given** the modal is open, **When** the user taps an option, **Then** the options lock, the correct one is marked, the chosen wrong one (if any) is marked, and the streak view appears below.
3. **Given** a user who already answered today, or who closed today's modal, **When** they open or resume the app the same local day, **Then** the modal doesn't open on its own.
4. **Given** the modal is open across midnight, **When** the user answers, **Then** they're told the question has changed and the new day's question loads.
5. **Given** the question can't load (offline, server error, no questions), **When** the dashboard opens, **Then** no modal and no error dialog appear.

---

### User Story 2 - See the streak (Priority: P1)

The streak view shows a flame count and progress to the next reward, e.g. "32/45 → 15% off (25% if perfect)", and freezes held. Under 7 days it shows a row of 7 dots for the current week. From 7 days it shows the current month as a calendar, with correct, wrong and freeze-covered days marked.

**Why this priority**: The streak is what brings people back each day.

**Independent Test**: With users at streaks of 3 and 20 on dev, open the streak view. The 3-day user sees the week row; the 20-day user sees the month calendar with their days marked.

**Acceptance Scenarios**:

1. **Given** a streak of 0–6, **When** the streak view shows, **Then** it's a Monday-to-Sunday row for the current week with answered days filled.
2. **Given** a streak of 7 or more, **When** the streak view shows, **Then** it's a calendar of the current month with answered days filled (correct and wrong told apart) and freeze days marked.
3. **Given** any streak, **Then** the view shows the current streak, freezes held out of 2, and the next milestone with days remaining and its base and perfect-run percentages, or a "top reward earned" message after 90.

---

### User Story 3 - See and use a reward code (Priority: P2)

When a user holds an active reward, the streak view shows the percentage, the code, its expiry date, a copy button and a "Shop" button that opens the merch store. While the code is still being created, it says the code is on its way.

**Independent Test**: With a dev user holding an active reward, open the streak view. The code shows, copies to the clipboard and "Shop" opens the store.

**Acceptance Scenarios**:

1. **Given** an active reward, **Then** the streak view shows its percent, code, expiry, a copy button and a shop button.
2. **Given** a pending reward, **Then** the view says the code is being created and will arrive by email and notification.
3. **Given** the answer that reached 45, 60 or 90 days, **When** the result shows, **Then** a celebration message names the reward.

---

### User Story 4 - Notifications open the question (Priority: P2)

Tapping the 9am reminder (`daily_trivia`) opens the daily question modal. Tapping a reward notification (`daily_trivia_reward`) opens the streak view showing the code.

**Independent Test**: Send each push type to a dev device with `/scheduled/test-push`, tap it, and check the right view opens.

---

### User Story 5 - Answer later from Trivia (Priority: P2)

The Trivia home screen has a "Daily Question" card showing the streak and whether today is answered. Tapping it opens the modal: the question if today is unanswered, otherwise today's result and the streak view.

---

### User Story 6 - The app reports the device timezone (Priority: P2)

After sign-in, the app sends the device's IANA timezone so the user's "today" and 9am reminder follow their clock.

### Edge Cases

- **First launch**: the onboarding tutorial and notification primer show first, and the modal opens after them.
- **Navigation**: if a notification or deep link has pushed another screen, the modal doesn't open on top of it.
- **Text scaling**: at 1.5× text, the modal scrolls instead of overflowing.
- **Timezone failure**: if the timezone can't be read, nothing is sent and the backend default applies.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST open the daily question modal automatically at most once per local day per device, only when today is unanswered, and only when the dashboard is the top screen.
- **FR-002**: The modal MUST show the category label and level label from the backend, the question, and only the options the question has.
- **FR-003**: The app MUST NOT know or show the correct option before the server returns it.
- **FR-004**: After answering, the app MUST show correct or wrong, the correct option, the updated streak, and any freeze used, freeze earned, reset or new reward.
- **FR-005**: The streak view MUST use the week row when the streak is under 7 and the month calendar from 7, as described in US2.
- **FR-006**: The streak view MUST show the active or pending reward as described in US3.
- **FR-007**: Tapping `daily_trivia` and `daily_trivia_reward` notifications MUST open the modal.
- **FR-008**: The Trivia home MUST offer a Daily Question entry point.
- **FR-009**: After sign-in, the app MUST send the device's IANA timezone through `PUT /users/me/timezone`, best-effort.
- **FR-010**: Errors MUST be shown with `friendlyError()`, with one exception: when the daily question can't load on launch, the app MUST say nothing.

### Roles, Access & Backend Dependencies *(mandatory)*

- **Roles**: mentor, apprentice and admin, i.e. every signed-in user.
- **Premium**: free.
- **Backend**: `GET /trivia/daily/today`, `POST /trivia/daily/today/answer`, `GET /trivia/daily/streak`, `PUT /users/me/timezone`, and push types `daily_trivia` / `daily_trivia_reward`, all from backend spec 002. They don't exist in production yet; the backend ships first.
- **Data & privacy**: the device timezone name is sent to the backend. It is used for app functionality, isn't tied to precise location, and isn't one of Apple's collected data types. `PrivacyInfo.xcprivacy` is checked and needs no change.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can go from opening the app to seeing their result in under 15 seconds.
- **SC-002**: The modal opens on its own at most once per local day per device.
- **SC-003**: The modal and streak view work at 1.5× text scale with no overflow.

## Assumptions

- "Once per day" is per device: closing the modal on one phone doesn't hide it on another.
- The week row starts on Monday.
- The merch store URL comes from the reward's `shop_url`.
