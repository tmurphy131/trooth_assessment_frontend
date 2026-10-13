# Data Model: Invite Codes & Social-First Login

Client-side only. Nothing is stored; these models live for the duration of one screen.

## InviteRedemption (new, `lib/models/invite_redemption.dart`)

Parsed from a `200` response to `POST /invitations/redeem` (backend contract `InviteRedeemOut`).

| Field | Type | From JSON | Notes |
|-------|------|-----------|-------|
| `mentorId` | `String` | `mentor_id` | required |
| `mentorName` | `String?` | `mentor_name` | may be null; the UI falls back to "your mentor" |
| `relationship` | `InviteRelationship` | `relationship` | `created` / `reactivated` / `alreadyActive` (from `already_active`); an unknown value is treated as `created` |

The UI shows "You're now connected with {name}" for `created` and `reactivated`, and "You're already connected with {name}" for `alreadyActive`.

## Invite code (display value, no class)

- Comes from `invite-apprentice` (`code`) and from each item of `pending-invites` / `apprentice-invites` (`code`, possibly missing on an older backend).
- Always shown exactly as the backend sends it (`XXXX-XXXX`). The client never reformats or validates it; the backend normalizes input.
- **Entry field rules**: input is uppercased as typed; at most 32 characters (matching the backend's 422 limit); trimmed before sending. Submit is disabled when the trimmed field is empty.

## Login screen state (`SimpleLoginScreen`)

| State | Values | Transition |
|-------|--------|------------|
| `_showEmailForm` | `false` (social mode, default) / `true` (email mode) | "Continue with email" → `true`; "Back to sign-in options" → `false` |
| `_isLoading` | existing | unchanged |

The platform comes from `defaultTargetPlatform`. The Apple button is shown only for `TargetPlatform.iOS`.
