# Feature Specification: Invite Codes & Social-First Login

**Feature Branch**: `feature/invite-codes-social-login` | **Spec Folder**: `specs/004-invite-codes-social-login/`

**Created**: 2026-10-13

**Status**: Draft

**Input**: User description: "Make Sign in with Apple (iOS only) and Google the primary sign-in and sign-up options, with email and password kept as a secondary fallback. No Apple sign-in on Android. Let apprentices join their mentor by entering an invite code, because a hidden Apple email never matches the address the mentor invited. Let mentors see and share each invite's code."

**Backend contract**: [`trooth_assessment_backend/specs/006-invite-codes/contracts/invitations.md`](../../../trooth_assessment_backend/specs/006-invite-codes/contracts/invitations.md). Built and deployed to dev; not yet in prod.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Apprentice joins a mentor with a code (Priority: P1)

An apprentice gets an invite code from their mentor by text, email or in person. They open the app, sign in any way they like, enter the code, and are connected to that mentor straight away. It works even if their account email is an Apple hidden relay address or a different Google account from the one the mentor invited.

**Why this priority**: Without it, apprentices who sign in with Apple's hidden email, or any email that differs from the invite, can't be connected to their mentor. That blocks the core mentoring flow, and it gets more common once social sign-in is the default (Story 3).

**Independent Test**: On dev, a mentor invites `someone@example.com`. A different apprentice account enters the code and sees a confirmation naming the mentor. Their dashboard then shows that mentor.

**Acceptance Scenarios**:

1. **Given** a signed-in apprentice with a valid code, **When** they enter it and submit, **Then** they see "You're now connected with {mentor name}" and their dashboard refreshes to show the mentor.
2. **Given** the apprentice types the code in lowercase, without the dash, or with spaces, **When** they submit, **Then** it is accepted. The field doesn't make them reformat it.
3. **Given** a code that doesn't exist, **When** submitted, **Then** they see "We couldn't find that code. Check it and try again." and the field keeps what they typed.
4. **Given** a code that has expired or was already used, **When** submitted, **Then** they see "This code can't be used. It may have expired or already been used. Ask your mentor for a new one."
5. **Given** too many wrong codes, **When** they submit again, **Then** they see "Too many tries. Please wait a while and try again." and the submit button stays usable.
6. **Given** a signed-in apprentice with no mentor yet, **When** they open their dashboard, **Then** they see a clear "Have an invite code?" entry point without opening any menu.
7. **Given** an apprentice who already has a mentor, **When** they want to add another mentor, **Then** they can still enter a code from the invitations screen.

---

### User Story 2 - Mentor shares an invite code (Priority: P1)

After sending an invite, the mentor sees the code and can copy it or share it through the phone's share sheet (Messages, WhatsApp and so on). Every pending invite in their list shows its code with the same copy and share actions.

**Why this priority**: An apprentice can only redeem a code they have received. This story and Story 1 together are the minimum release.

**Independent Test**: On dev, as a mentor, send an invite. A dialog shows a code like `K7QM-3XPR` with Copy and Share. The pending-invites list shows the same code with the same actions.

**Acceptance Scenarios**:

1. **Given** a mentor sends an invite, **When** it succeeds, **Then** a dialog shows the code in large text, the line "Your apprentice enters this code in the T[root]H app", and Copy and Share buttons.
2. **Given** the mentor taps Copy, **Then** the code is on the clipboard and a confirmation appears.
3. **Given** the mentor taps Share, **Then** the share sheet opens with a ready-made message. The message has the code, how to use it, and the app download links.
4. **Given** pending invites, **When** the mentor views the list, **Then** each invite shows its code with Copy and Share. The placeholder `yourapp.com` link is gone.

---

### User Story 3 - Social-first sign-in and sign-up (Priority: P2)

The login screen leads with one-tap sign-in. On iOS that's "Sign in with Apple" then "Sign in with Google"; on Android it's "Sign in with Google" only. Email and password are behind a secondary "Continue with email" option that opens the existing email form, including Forgot Password and the sign-up link. New users who choose Apple or Google go through the existing role and terms step.

**Why this priority**: It's easier to sign up, and the app has no passwords to manage for most users. Its risk depends on Stories 1 and 2: once more people sign in with hidden emails, the code flow must already exist. So Story 3 ships in the same release as Stories 1 and 2, or after them, never before.

**Independent Test**:
- On an iOS device, the login screen shows Apple, then Google, then "Continue with email". The email fields aren't visible until that's tapped.
- On an Android device, it shows Google, then "Continue with email", with no Apple button.
- The App Review account still signs in by email.

**Acceptance Scenarios**:

1. **Given** iOS, **When** the login screen opens, **Then** Apple is first and most prominent, Google second, and "Continue with email" is a smaller secondary action.
2. **Given** Android, **When** the login screen opens, **Then** Google is first, there is no Apple button, and "Continue with email" is secondary.
3. **Given** the user taps "Continue with email", **Then** the existing email and password form appears with Forgot Password, and the user can go back to the social options.
4. **Given** an existing email-and-password user (including `apple.reviewer.apprentice@onlyblv.com`), **When** they use "Continue with email", **Then** they sign in exactly as before.
5. **Given** a first-time Apple or Google user, **When** they sign in, **Then** they go through the existing role selection and terms acceptance before reaching a dashboard.
6. **Given** the "Create account" link, **Then** it remains reachable from the email option, and the sign-up screen still offers email sign-up.

---

### Edge Cases

- **Apprentice enters a code while already connected to that mentor:** the backend returns success with `already_active`. Show "You're already connected with {mentor name}."
- **A mentor or admin account enters a code** (for example from a shared device): the backend returns 403. Show "Invite codes are for apprentice accounts." Only apprentices see the entry point, but the app still handles a 403.
- **No network or a server error while redeeming:** show the standard `friendlyError()` message, keep the code in the field, and allow retry.
- **Mentor status can't be loaded on the dashboard** (network error): the "Have an invite code?" card stays hidden rather than guessing. Code entry is always available on the invitations screen, including when that screen's invite list fails to load.
- **Pending invites created before the backend change** (`code` missing): show the invite without code actions. Don't show an empty code.
- **Mentor's share sheet is cancelled:** nothing happens and no error is shown.
- **User signed up with email, later taps Google using the same Gmail address:** Firebase's account-linking behavior applies, unchanged from today. "Continue with email" always remains available.
- **Large text (1.5x):** the code dialog, code field and login buttons stay readable without overflow.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Apprentices MUST be able to enter an invite code from the invitations screen. Apprentices with no active mentor MUST also be able to enter one directly from their dashboard.
- **FR-002**: The code field MUST accept any case, with or without the dash, and with spaces. It MUST show the code in uppercase as typed and MUST NOT require the user to reformat it.
- **FR-003**: Submitting a code MUST call the backend redeem endpoint and handle the outcome **by HTTP status code only** (Principle XII), never by the error text:

  | Status | Message |
  |--------|---------|
  | 200 | Success, naming the mentor (or "already connected" when the relationship is `already_active`) |
  | 404 | "We couldn't find that code. Check it and try again." |
  | 400 | "This code can't be used. It may have expired or already been used. Ask your mentor for a new one." |
  | 403 | "Invite codes are for apprentice accounts." |
  | 429 | "Too many tries. Please wait a while and try again." |
  | Anything else | `friendlyError()` |
- **FR-004**: After a successful redeem, the apprentice's dashboard, mentor information and invite count MUST refresh without restarting the app.
- **FR-005**: After a mentor sends an invite, the app MUST show the returned code with Copy and Share actions.
- **FR-006**: Each pending invite in the mentor's list MUST show its code with Copy and Share. The placeholder invite-link message MUST be removed.
- **FR-007**: Shared text MUST include the mentor's name, the code, a one-line instruction, and the iOS and Android store links.
- **FR-008**: On iOS the login screen MUST show Sign in with Apple first and Sign in with Google second. On Android it MUST show Sign in with Google and MUST NOT show Apple. On both, email sign-in MUST be reachable through a secondary "Continue with email" action that reveals the existing form.
- **FR-009**: Email sign-in, Forgot Password and email sign-up MUST keep working exactly as today. The App Review demo account MUST still be able to sign in.
- **FR-010**: Existing behavior MUST be kept:
  - first-time social users go through role selection and terms acceptance;
  - sign-in side effects still go only through `SessionController`;
  - error text still goes through `friendlyError()`.
- **FR-011**: All new interactive elements MUST meet Principle VII: tooltips on icon buttons, tap targets of at least 48 px, and no overflow at 1.5x text.
- **FR-012**: The app MUST NOT log the invite code in release builds (Principle III/X).

### Key Entities

- **Invite code**: an 8-character code from the mentor's invitation, shown as `XXXX-XXXX`. The app displays it, lets the mentor share it, and lets the apprentice submit it. The app never stores it beyond the current screen.

### Roles, Access & Backend Dependencies *(mandatory)*

- **Roles**: Apprentices enter codes. Mentors see and share codes. Sign-in changes affect everyone who isn't signed in. The backend enforces roles; hiding UI is cosmetic only (Principle III).
- **Premium**: Free.
- **Backend**: All endpoints come from backend spec 006 ([contract](../../../trooth_assessment_backend/specs/006-invite-codes/contracts/invitations.md)):
  - `POST /invitations/redeem` (new);
  - `POST /invitations/invite-apprentice` (now also returns `id`, `code`, `expires_at`);
  - `GET /invitations/pending-invites` and `GET /invitations/apprentice-invites` (each item now has `code`);
  - `POST /invitations/accept-invite` (now requires sign-in, which the app already sends).

  All are implemented and deployed to dev. **Release gate (Principle XII): this app version MUST NOT ship to the stores until backend spec 006 is deployed to prod.**
- **Data & privacy**: No new personal data is collected. Sign in with Apple and Google are already in the app, so the privacy manifest and store labels don't change.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An apprentice whose account email differs from the invited email can connect to their mentor in under 30 seconds after signing in, without contacting support.
- **SC-002**: Everyone who enters a valid, unused code is connected on the first try, whatever the case, dash or spacing.
- **SC-003**: A mentor can share a code through any messaging app in two taps from the moment the invite is sent.
- **SC-004**: A new user can create an account with Apple (iOS) or Google in 3 taps or fewer, plus role selection and terms.
- **SC-005**: Every existing email-and-password user, including the App Review account, can still sign in.

## Assumptions

- The backend accepts any form of the code, so the app sends whatever the user typed (trimmed) and doesn't need to normalize it.
- "No active mentor" is determined from data the dashboard already loads. No new endpoint is needed.
- The existing email-matched invites list stays as it is. Codes are an extra way in, not a replacement.
- Store links in shared messages use the same App Store and Play Store URLs the backend landing page uses.
- Deep links (tapping a link to open the app with the code pre-filled) are out of scope. Copy-paste is enough for this release.
- Agreements and gift seats still match by email. They're out of scope here, as in backend spec 006.
