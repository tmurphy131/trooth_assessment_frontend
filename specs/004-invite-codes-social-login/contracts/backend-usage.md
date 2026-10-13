# Contract usage: invite codes (client side)

**Source of truth**: [`trooth_assessment_backend/specs/006-invite-codes/contracts/invitations.md`](../../../../trooth_assessment_backend/specs/006-invite-codes/contracts/invitations.md). This file only records how the app calls those endpoints and reacts to each status (Principle XII).

| App method (`lib/services/api/invites_agreements.dart`) | Endpoint | Change in this feature |
|---|---|---|
| `redeemInviteCode(String code)` → `InviteRedemption` | `POST /invitations/redeem` | **new** |
| `sendInvite(payload)` → `String?` (the code) | `POST /invitations/invite-apprentice` | now returns `code` from the response (was `void`) |
| `getPendingInvites()` | `GET /invitations/pending-invites` | none; the screen reads the new `code` field |
| `getApprenticeInvites(email)` | `GET /invitations/apprentice-invites` | none; `code` is available but not shown to apprentices |
| `acceptInvite(payload)` | `POST /invitations/accept-invite` | none; it already sends sign-in and its own `apprentice_id`, which the backend still accepts |
| `getMentorStatus()` | `GET /apprentice/mentor/status` | none; reused for the dashboard's "no mentor" check |

## Status handling for `redeemInviteCode` (by status code only)

| Status | Client behavior | Message |
|--------|-----------------|---------|
| 200 | parse `InviteRedemption`, call `onRedeemed`, refresh | "You're now connected with {mentor}" / "You're already connected with {mentor}" |
| 200 with a body that can't be parsed | throw `ApiException(200, …)`, shown as an inline error | `friendlyError()` |
| 400 | inline error, keep the input | "This code can't be used. It may have expired or already been used. Ask your mentor for a new one." |
| 403 | inline error | "Invite codes are for apprentice accounts." |
| 404 | inline error, keep the input | "We couldn't find that code. Check it and try again." |
| 422 | inline error (shouldn't happen, because the field caps at 32 characters and blocks empty submits) | `friendlyError()` |
| 429 | inline error; the button stays enabled | "Too many tries. Please wait a while and try again." |
| 401 / 5xx / network | inline error | `friendlyError()` (the session layer already retries 401 once) |

The backend's `detail` text is never parsed or shown.

## Release gate

Backend spec 006 is on **dev** (revision `trooth-backend-dev-00103-xfn`). It MUST be on **prod** before this app version is tagged.
