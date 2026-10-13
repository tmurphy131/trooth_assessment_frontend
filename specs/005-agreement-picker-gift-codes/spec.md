# Feature Specification: Agreement Apprentice Picker & Gift Code Redemption

**Feature Branch**: `feature/agreement-apprentice-picker-gift-codes` | **Spec Folder**: `specs/005-agreement-picker-gift-codes/`

**Created**: 2026-10-13

**Status**: Draft

**Input**: User description: "Agreements and gift seats should work for apprentices whose account email doesn't match what the mentor knows (Apple Hide My Email, a different Google account). App side of backend spec 007."

**Backend contract**: [`trooth_assessment_backend/specs/007-connected-apprentice-linking/contracts/api.md`](../../../trooth_assessment_backend/specs/007-connected-apprentice-linking/contracts/api.md) (backend PR #44).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Mentor sends an agreement by picking a connected apprentice (Priority: P1)

When creating an agreement, the mentor picks one of their current apprentices from a list instead of typing an email. The app fills in the apprentice's name, and the agreement goes to that apprentice's account, so the apprentice sees and signs it in the app whatever email they signed in with. For someone the mentor isn't connected to yet, "Someone else" keeps today's email entry.

**Why this priority**: Most agreements go to apprentices the mentor already has. Today the mentor has to know and type the exact email the apprentice signed in with, which fails for hidden-email apprentices.

**Independent Test**: On dev, a mentor connected to an apprentice whose account uses an Apple relay email opens "New agreement", picks that apprentice, fills in the meeting details and creates it. The apprentice sees it in their pending agreements and signs it in the app.

**Acceptance Scenarios**:

1. **Given** a mentor with active apprentices, **When** they open the agreement form, **Then** an "Apprentice" picker lists those apprentices by name, plus a "Someone else (enter email)" option.
2. **Given** the mentor picks an apprentice, **Then** the name field is filled with that apprentice's name (still editable), the email field is hidden, and the agreement is created for that account.
3. **Given** the mentor picks "Someone else", **Then** the name and email fields work as today, and an email is required.
4. **Given** a mentor with no apprentices yet, **When** they open the form, **Then** the picker isn't shown and the form is today's email form.
5. **Given** the backend refuses the pick because the mentorship has ended (403), **Then** the mentor sees "This apprentice isn't connected to you anymore. Refresh and try again." and nothing is created.
6. **Given** the apprentice list fails to load, **Then** the form falls back to email entry and stays usable.

---

### User Story 2 - Apprentice redeems a gift code (Priority: P1)

A mentor gives their apprentice a gift code (`TROOTH-XXXX-XXXX`, already shown on the mentor's gift-seats screen). The apprentice enters it in the app and gets Premium straight away. That works whatever email they signed in with, because the code, not an email, identifies the gift.

**Why this priority**: Without it, a mentor can only gift a hidden-email apprentice by picking them from the connected list. Codes shared any other way have nowhere to go: the backend redeem endpoint exists, but the app has no screen for it.

**Independent Test**: On dev, a mentor with a free gift seat copies its code. An apprentice opens the upgrade screen, taps "Have a gift code?", enters the code (in lowercase, without dashes) and sees Premium activate. Their profile then shows "Premium (Gift)" and "Gifted by {mentor}".

**Acceptance Scenarios**:

1. **Given** an apprentice on the upgrade (subscription) screen or the subscription section of their profile, **Then** they see "Have a gift code from your mentor?".
2. **Given** they enter a valid code, in any case, with or without the `TROOTH-` prefix, dashes or spaces, **When** they submit, **Then** the app sends it in canonical form `TROOTH-XXXX-XXXX`.
3. **Given** the code is accepted, **Then** they see "Premium access activated! Gifted by {mentor}." and the app's Premium status refreshes right away (no restart).
4. **Given** the code is invalid, already used, inactive or expired, or they already have Premium, **Then** they see the explanation the server returns, and the code stays in the field.
5. **Given** a mentor account somehow reaches the entry (the backend returns 403), **Then** they see "Gift codes are for apprentice accounts."
6. **Given** the entry is shown to a mentor's own upgrade screen, **Then** it isn't: the gift-code entry appears for apprentices only.

---

### Edge Cases

- **The mentor picks an apprentice and switches to "Someone else":** the email field reappears empty, and the chosen apprentice is cleared.
- **Many apprentices:** the picker works with a long list, sorted by name and searchable or scrollable, and stays readable at 1.5x text.
- **An apprentice without a name:** they're listed by email.
- **Gift code typed with extra characters** (for example a trailing period from a pasted message): those are removed when converting to canonical form. If the result isn't 8 code characters, the app says the code looks incomplete without calling the server.
- **Network or server error on either action:** `friendlyError()`, the input is kept, and the user can retry.
- **An apprentice already on Premium (paid):** the server returns `success: false` "You already have a premium subscription.", and the app shows it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The mentor's agreement form MUST offer a picker of the mentor's current apprentices (from the existing "my apprentices" list) plus "Someone else (enter email)".
- **FR-002**: Choosing an apprentice MUST create the agreement by account (`apprentice_id`), fill in the name (editable), and hide the email field. "Someone else" MUST keep today's email entry and validation.
- **FR-003**: Agreement creation outcomes MUST be handled by status code (Principle XII): 403 → "This apprentice isn't connected to you anymore. Refresh and try again."; 422 → "Choose an apprentice or enter an email."; anything else → `friendlyError()`.
- **FR-004**: If the apprentice list can't load, the form MUST fall back to email entry.
- **FR-005**: Apprentices (only) MUST have a "Have a gift code from your mentor?" entry on the upgrade screen and in the subscription section of their profile, shown only while the apprentice isn't Premium. On the upgrade screen it's on the non-Premium path; on the profile it's hidden for Premium apprentices.
- **FR-006**: Gift-code input MUST be normalized before sending: uppercase; remove spaces, dashes and other non-code characters; strip a leading `TROOTH`; and, if exactly 8 code characters remain, send `TROOTH-XXXX-XXXX`. Otherwise show "That code looks incomplete." and don't call the server.
- **FR-007**: Gift-code results MUST be handled by structure, not wording: HTTP 200 with `success: true` → success message, then a subscription status refresh; HTTP 200 with `success: false` → show the server's `message`; 403 → "Gift codes are for apprentice accounts."; anything else → `friendlyError()`.
- **FR-008**: After a successful redemption, the app's Premium state (`SubscriptionService`) MUST refresh so Premium features unlock without restarting.
- **FR-009**: New UI MUST meet Principle VII (tooltips, 48 px targets, at least 11 px text, 1.5x text without overflow).
- **FR-010**: Gift codes MUST NOT be logged in release builds.

### Key Entities

- **Connected apprentice** (existing, from `GET /mentor/my-apprentices`): id, name, email. Used to fill the picker.
- **Gift code** (existing): `TROOTH-XXXX-XXXX`, made by the backend and shown to mentors on the gift-seats screen.

### Roles, Access & Backend Dependencies *(mandatory)*

- **Roles**: Mentors use the agreement picker. Apprentices redeem gift codes. The backend enforces both: active-connection check (403) and apprentice-only redemption (403).
- **Premium**: Creating gift seats stays premium-mentor-only (unchanged). Redeeming grants the apprentice `mentor_gifted` Premium.
- **Backend**:
  - `POST /agreements` with `apprentice_id`: **new in backend spec 007**, PR #44.
  - `GET /mentor/my-apprentices`: existing.
  - `POST /apprentice/redeem-code`: existing; apprentice-only after spec 007.
  - `GET /subscriptions/status` (via `SubscriptionService.refreshStatus`): existing.

  **Release gate (Principle XII): US1 MUST NOT ship to the stores until backend spec 007 is on prod.** Against an older backend, `apprentice_id` is ignored and the email is missing, so creation fails with 422. US2 depends only on endpoints that are already live.
- **Data & privacy**: No new personal data collected.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A mentor can send an agreement to a connected apprentice without knowing or typing their email.
- **SC-002**: An apprentice whose account email differs from what the mentor knows can see and sign that agreement in the app.
- **SC-003**: An apprentice can redeem a gift code and see Premium unlocked in under 30 seconds, with no app restart.
- **SC-004**: Agreements by email for apprentices who aren't connected yet work exactly as before.

## Assumptions

- `GET /mentor/my-apprentices` returns only current (active) apprentices, with `id`, `name` and `email`, as the gift-seats picker already relies on.
- The gift-code entry lives on the existing subscription (upgrade) screen and the apprentice profile. No new route.
- Gift codes are only `TROOTH-` followed by 8 characters from the backend's alphabet. The client normalizes the format but doesn't validate the alphabet; the server is the authority.
- The picker lists every current apprentice regardless of the mentor's plan. That matches today: creating agreements isn't gated by plan, and the email path already reaches anyone. The free-tier limit applies to *viewing* an apprentice's data, which this feature doesn't touch.
- The apprentice side of agreements needs no app change: once the backend ties the agreement to the account, the existing pending and sign screens show it.
