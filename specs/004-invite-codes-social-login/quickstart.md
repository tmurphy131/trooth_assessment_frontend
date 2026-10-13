# Quickstart: validating invite codes & social-first login

The app is pointed at dev by default (no `--dart-define`). Backend spec 006 is deployed to dev. Status handling is in [contracts/backend-usage.md](contracts/backend-usage.md).

## 1. Automated (required before merge)

```bash
flutter analyze --no-fatal-infos
flutter test test/invite_codes_test.dart test/invite_code_entry_test.dart test/invite_code_share_test.dart test/login_layout_test.dart
flutter test                        # full suite
```

Expected coverage:
- `redeemInviteCode`: 200 parses `mentorName` and `relationship`; 400/403/404/429/500 throw `ApiException` with that `statusCode`.
- `sendInvite`: returns the `code`, or `null` when the response has none.
- `inviteCodeErrorMessage`: the exact FR-003 text for 400/403/404/429; `friendlyError` for others.
- `buildInviteShareMessage`: contains the mentor name, the code and both store URLs.
- `InviteCodeEntry`: typing `k7qm 3xpr` shows `K7QM 3XPR`; an error keeps the text; success calls `onRedeemed`; submit is disabled when empty.
- `redeemInviteCode` with a malformed 200 body throws `ApiException`, not `TypeError`.
- Login layout: on iOS, `SignInWithAppleButton` appears before Google; on Android there's no Apple; "Continue with email" reveals the email field; "Back" hides it.

## 2. Manual on dev (simulator or device)

**Login**
1. On the iOS simulator, open the login screen. Apple is on top, then Google, then "Continue with email". There are no email fields yet.
2. Tap "Continue with email". The email form appears with Forgot Password and the sign-up link. "Back to sign-in options" returns to the buttons.
3. Sign in with `apple.reviewer.apprentice@onlyblv.com` by email. You reach the apprentice dashboard.
4. On an Android emulator: Google, then "Continue with email", with no Apple button.
5. Sign in for the first time with a new Google or Apple account. Role selection and terms appear before the dashboard.

**Invite codes**
6. As a mentor, send an invite to `someone+test@example.com`. A dialog shows `XXXX-XXXX` with Copy and Share. Copy, and confirm the snackbar. Share, and confirm the sheet opens with a message that includes the code and store links.
7. The pending list shows the same code with Copy and Share. There's no `yourapp.com` message.
8. As an apprentice with **no** mentor and an account email that's different from the invite: the dashboard shows "Have an invite code?". Enter the code in lowercase without the dash. You see "You're now connected with {mentor}", the card disappears and the mentor shows up.
9. Enter the same code again from the invitations screen. You see the 400 message.
10. Enter `ABCD-EFGH`. You see the 404 message, and the text stays in the field.
11. At 1.5x text size, check the login screen, the code dialog and the code field for overflow.
12. **Sign-up taps (SC-004)**: with a fresh Apple (iOS) or Google account, count the taps from the login screen to the role selection screen. It should be 3 or fewer (for example: the button, choosing the account, confirming).
13. **Redeem response time (plan performance goal)**: on a normal connection, the success or error message should appear within about 1 second of tapping Join.

## 3. Auth regression (login touched, Principle VIII)

```bash
flutter test integration_test/session_flows_test.dart -d <iOS simulator id>
flutter build ios --config-only     # reset Generated.xcconfig after integration tests
```

## 4. Release gate

Before tagging: confirm backend spec 006 is on prod (`POST https://trooth-discipleship-api.onlyblv.com/invitations/redeem` without auth returns 401, not 404).
