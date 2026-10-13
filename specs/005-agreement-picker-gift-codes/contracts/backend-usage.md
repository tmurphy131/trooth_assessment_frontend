# Contract usage: agreement picker and gift codes (client side)

**Source of truth**: [`trooth_assessment_backend/specs/007-connected-apprentice-linking/contracts/api.md`](../../../../trooth_assessment_backend/specs/007-connected-apprentice-linking/contracts/api.md) (backend PR #44). This file records how the app calls those endpoints and reacts by status (Principle XII).

| App method | Endpoint | Change |
|---|---|---|
| `createAgreement({apprenticeId?, apprenticeEmail?, …})` (`lib/services/api/invites_agreements.dart`) | `POST /agreements` | **changed**: sends `apprentice_id` when an apprentice is picked, otherwise `apprentice_email` |
| `listApprentices()` (`lib/services/api/users_mentorship.dart`) | `GET /mentor/my-apprentices` | none; reused for the picker |
| `redeemGiftCode(code)` → `GiftCodeRedemption` (`lib/services/api/subscriptions.dart`) | `POST /apprentice/redeem-code` | **new** client method; the endpoint already exists |
| `SubscriptionService().refreshStatus()` | `GET /subscriptions/status` | none; called after a successful redemption |

## `createAgreement` outcomes

| Status | Behavior |
|--------|----------|
| 200 | as today (status card, list refresh) |
| 403 | "Create failed: This apprentice isn't connected to you anymore. Refresh and try again." |
| 422 | "Create failed: Choose an apprentice or enter an email." |
| other | "Create failed: " + `friendlyError()` |

## `redeemGiftCode` outcomes

| Status / body | Behavior |
|---------------|----------|
| 200, `success: true` | `refreshStatus()`, close the sheet, snackbar "Premium access activated! Gifted by {mentor}." |
| 200, `success: false` | show `message` inline, keep the input |
| 200, body can't be parsed | `ApiException(200)` → `friendlyError()` inline |
| 403 | "Gift codes are for apprentice accounts." inline |
| 422 | can't normally happen (the client always sends 16 characters); `friendlyError()` |
| other / network | `friendlyError()` inline |

## Release gate

- The **agreement picker (US1)** requires backend spec 007 on **prod** before this app version is tagged. An older backend ignores `apprentice_id` and returns 422 (email missing).
- **Gift codes (US2)** use an endpoint that's already on prod.
