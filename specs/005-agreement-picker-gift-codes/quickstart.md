# Quickstart: validating the agreement picker and gift codes

The app targets dev by default. Backend spec 007 (PR #44) must be deployed to dev for US1. See [contracts/backend-usage.md](contracts/backend-usage.md) for status handling and [data-model.md](data-model.md) for the rules.

## 1. Automated (required before merge)

```bash
flutter analyze --no-fatal-infos
flutter test test/agreement_picker_test.dart test/mentor_agreements_screen_test.dart test/gift_codes_test.dart test/gift_code_form_test.dart
flutter test
```

Expected coverage:
- `createAgreement`: with `apprenticeId`, the body has `apprentice_id` and **no** `apprentice_email`; without it, the body has `apprentice_email` as today.
- `agreementCreateErrorMessage`: the exact texts for 403 and 422; `friendlyError` otherwise.
- `MentorAgreementsScreen`: picking an apprentice hides the email field and sends `apprentice_id`; "Someone else" sends the email; a failed apprentice list shows the plain email form; 403 shows the not-connected text.
- `ApprenticePicker`: items sorted by name (falling back to email), "Someone else" last, `onChanged` gives the id or `null`.
- `redeemGiftCode`: parses `success` true and false bodies; `ApiException` on 403, 500 and a malformed 200.
- `normalizeGiftCode`: the examples in the data model.
- `GiftCodeForm`:
  - `a7k9` shows "That code looks incomplete." and makes no call;
  - success calls back once;
  - `success: false` shows the server message and keeps the input;
  - 403 shows the apprentice-only text;
  - unexpected errors are reported (through an injectable reporter), without the code;
  - no overflow at 1.5x text.

## 2. Manual on dev

**Agreement picker**
1. As a mentor connected to an apprentice whose account uses a different email (for example Apple Hide My Email), open Agreements. The Apprentice picker lists your apprentices, plus "Someone else".
2. Pick the apprentice. The name fills in and the email field is hidden. Create and submit the agreement.
3. As that apprentice, the agreement shows in pending agreements. Sign it in the app; it succeeds.
4. Pick "Someone else", type an email, and create. It works as before.

**Gift codes**
5. As a premium mentor, open Gift Seats and copy an unassigned seat's code.
6. As an apprentice on the free tier, open Upgrade, tap "Have a gift code from your mentor?", and enter the code in lowercase without dashes. Expect "Premium access activated! Gifted by {mentor}." The upgrade screen closes and Premium features unlock.
7. Redeem the same code again from another free apprentice. The server's "already been redeemed" message shows.
8. Check that a mentor's Upgrade screen shows no gift-code entry.
9. At 1.5x text, check the picker, the gift-code sheet and the profile button.

## 3. Release gate

Before tagging, confirm backend spec 007 is on prod. For example, `POST /agreements` on prod with only `apprentice_id` must not return a 422 "email required" error.
