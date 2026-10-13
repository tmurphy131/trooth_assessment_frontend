# Data Model: Agreement Apprentice Picker & Gift Code Redemption

Client-side only; nothing is stored on the device.

## ConnectedApprentice (no new class)

These are rows from `GET /mentor/my-apprentices` (`List<dynamic>` of maps), already used by the gift-seats screen.

| Field | Use |
|-------|-----|
| `id` | Sent as `apprentice_id` when picked |
| `name` | Picker label and name pre-fill. If null or empty, the label falls back to `email` |
| `email` | Fallback label only. **Never** sent when an apprentice is picked |

**Picker rules**
- Items are sorted case-insensitively by label (name, else email). The shared list's order isn't changed.
- The last item is "Someone else (enter email)", with value `null`.
- Picking an item fills the name field (still editable). Switching to "Someone else" clears the selection and shows an empty email field.

## GiftCodeRedemption (new, `lib/models/gift_code_redemption.dart`)

Parsed from a 200 response to `POST /apprentice/redeem-code`.

| Field | Type | From JSON | Notes |
|-------|------|-----------|-------|
| `success` | `bool` | `success` | required |
| `message` | `String` | `message` | required; shown as-is when `success` is false |
| `mentorName` | `String?` | `mentor_name` | used in the success text |
| `expiresAt` | `String?` | `expires_at` | not displayed in this feature |

## Gift code input

`normalizeGiftCode(raw)`:
1. uppercase;
2. keep only `[A-Z0-9]`;
3. strip a leading `TROOTH` when more than 8 characters remain;
4. exactly 8 left → `TROOTH-XXXX-XXXX`; otherwise `null`, meaning "That code looks incomplete." and no request.

Examples: `a7k9m2p4` → `TROOTH-A7K9-M2P4`; ` trooth-a7k9-m2p4. ` → `TROOTH-A7K9-M2P4`; `A7K9` → `null`.

## Agreement form state (`MentorAgreementsScreen`, additions)

| State | Values |
|-------|--------|
| `_apprentices` | `List<Map<String, dynamic>>`; empty when loading fails or there are none (the picker is then hidden) |
| `_selectedApprenticeId` | `String?`; `null` means "Someone else" (email entry) |

The submit guard changes from "email not empty" to "apprentice picked, **or** email not empty".
