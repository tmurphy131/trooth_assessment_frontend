# Research: Agreement Apprentice Picker & Gift Code Redemption

## R1. Creating an agreement by account

- **Decision**: In `InvitesAgreementsApi.createAgreement` (`lib/services/api/invites_agreements.dart`), make `apprenticeEmail` optional (`String?`) and add `String? apprenticeId`. The payload sends `apprentice_id` when given; otherwise it sends `apprentice_email`, as today. The `ApiException(statusCode, …)` error behavior is unchanged.
- **Rationale**: This is additive, and the existing caller keeps working. The backend contract (spec 007) treats the ID as preferred and ignores the email when both are sent; the client sends just one, to keep requests clear.

## R2. Apprentice picker on the agreement form

- **Decision**: A new plain widget `ApprenticePicker` (`lib/widgets/apprentice_picker.dart`). It's a `DropdownButtonFormField<String?>` whose items are the mentor's apprentices, **sorted by name, falling back to email**, plus a fixed last item "Someone else (enter email)" with value `null`. `MentorAgreementsScreen`:
  - loads `ApiService().listApprentices()` (`GET /mentor/my-apprentices`, active apprentices only) alongside the templates;
  - keeps `String? _selectedApprenticeId`;
  - fills `_apprenticeNameCtrl` when an apprentice is picked;
  - shows the email field only for "Someone else";
  - sends `apprenticeId` or `apprenticeEmail` accordingly.

  If the list fails to load, or is empty, the picker is hidden and the form is exactly today's email form (FR-004).
- **Rationale**: The gift-seats screen already uses `listApprentices()` for its picker. A separate widget keeps the 654-line screen from growing and can be widget-tested without the screen's template loading.
- **Note on order**: `/mentor/my-apprentices` comes oldest-account-first because the free tier relies on that order. Sorting by name happens in the picker only, never in the shared list.

## R3. Agreement create error text

- **Decision**: Add a pure `agreementCreateErrorMessage(Object e)` in `lib/utils/agreement_errors.dart`:
  - 403 → "This apprentice isn't connected to you anymore. Refresh and try again."
  - 422 → "Choose an apprentice or enter an email."
  - anything else → `friendlyError(e)`.

  The screen's existing `catch` uses it in place of `'Create failed: ${friendlyError(e)}'`, keeping the "Create failed: " prefix.
- **Rationale**: Principle XII (status codes only) and Principle IV (user text goes through `friendlyError()` unless a specific status has its own message). A pure function is easy to unit-test.

## R4. Gift-code API and model

- **Decision**: Add `Future<GiftCodeRedemption> redeemGiftCode(String code)` to the subscriptions API extension (`lib/services/api/subscriptions.dart`). It posts `{"code": code}` to `/apprentice/redeem-code`.
  - **On 200:** parse `RedeemCodeResponse` into `GiftCodeRedemption { bool success; String message; String? mentorName; String? expiresAt; }` (`lib/models/gift_code_redemption.dart`).
  - **On other statuses:** throw `ApiException(statusCode, 'redeemGiftCode failed (…)')`.
  - **On a 200 body that can't be parsed:** throw `ApiException(200, 'redeemGiftCode: malformed response')`, the same pattern as `redeemInviteCode` in spec 004.
- **Rationale**: Principle I (typed exceptions). The backend answers business failures (invalid, used, expired, already Premium) with **200 + `success: false` + `message`**, so the client branches on `success` (structure) and shows `message`. Principle XII forbids branching on wording, not displaying it.

## R5. Gift-code input normalization

- **Decision**: A pure `normalizeGiftCode(String raw) -> String?` in `lib/utils/gift_codes.dart`:
  1. uppercase;
  2. keep only `[A-Z0-9]`;
  3. strip a leading `TROOTH` if more than 8 characters remain;
  4. if exactly 8 remain, return `TROOTH-${first4}-${last4}`; otherwise return `null`.

  `null` shows "That code looks incomplete." and makes no request.
- **Rationale**: The backend matches the exact canonical string after `strip().upper()`, so dashes matter. Mentors copy codes as `TROOTH-A7K9-M2P4`, but apprentices may type them in many ways (FR-006).
- **Alternatives**: Sending what was typed and relying on the server would make `a7k9m2p4` fail.

## R6. Where the gift-code entry lives, and Premium refresh

- **Decision**: A reusable bottom sheet `showGiftCodeSheet(BuildContext context)` (`lib/widgets/gift_code_sheet.dart`, with a `GiftCodeForm` stateful widget inside that takes an injectable `redeem` function for tests).
  - Opened from a `TextButton.icon` "Have a gift code from your mentor?" on `SubscriptionScreen`, shown only when `_userRole == 'apprentice'` (the screen already reads the role).
  - Opened from the subscription section of `ApprenticeProfileScreen` (that screen is apprentice-only).
  - On success it calls `await SubscriptionService().refreshStatus()`, closes the sheet, and shows a snackbar: "Premium access activated! Gifted by {mentor}." (or "Premium access activated!" when there's no name).
  - `showGiftCodeSheet` returns `true` on success, so the caller can react:
    - `ApprenticeProfileScreen` calls its existing `_load()` to show "Premium (Gift)" and "Gifted by …";
    - `SubscriptionScreen` closes itself (`Navigator.pop`), because the apprentice is now Premium and the upgrade offer no longer applies. It has no general reload, only `_loadOfferings()` and `_restorePurchases()`.
- **Rationale**: One component, two entry points (FR-005). `SubscriptionService.refreshStatus()` is the existing way the app picks up a new tier (FR-008). No new route (Principle VI).
- **403 / other failures**: 403 → "Gift codes are for apprentice accounts."; anything else → `friendlyError()`. These go inline in the sheet, keeping the input.

## R7. Testing

- **Decision**:
  - MockClient unit tests: `createAgreement` sends `apprentice_id` without `apprentice_email` when an ID is given, and the email otherwise; `redeemGiftCode` parses success and failure bodies, throws `ApiException` on 403 and 500, and on a malformed 200.
  - Pure tests: `normalizeGiftCode`, `agreementCreateErrorMessage`.
  - Widget tests:
    - `ApprenticePicker`: sorted items, "Someone else" last, the `onChanged` value, falling back to email for names;
    - `GiftCodeForm`: incomplete code makes no call; success callback; `success: false` shows the server message and keeps the input; 403 text; no overflow at 1.5x.

  No auth or session code changes, so the session integration test isn't required (Principle VIII says SHOULD only for auth changes).
