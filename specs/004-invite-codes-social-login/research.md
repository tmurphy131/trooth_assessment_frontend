# Research: Invite Codes & Social-First Login

## R1. Redeem call and outcome handling

- **Decision**: Add `Future<InviteRedemption> redeemInviteCode(String code)` to `InvitesAgreementsApi` (`lib/services/api/invites_agreements.dart`). It sends `{"code": code.trim()}` to `POST /invitations/redeem`. On 200 it parses the response into a small `InviteRedemption` model; a 200 with a body it can't parse also throws `ApiException`, so parse errors never escape as untyped exceptions (Principle I). On any other status it throws `ApiException(statusCode, …)`. A pure function `inviteCodeErrorMessage(Object error)` in `lib/utils/invite_codes.dart` maps `ApiException.statusCode` to the spec's FR-003 messages (404, 400, 403, 429) and uses `friendlyError(error)` for everything else.
- **Rationale**: Principle I requires typed exceptions from `ApiService`. Principle XII requires branching on status codes only. A pure mapper can be unit-tested without widgets.
- **Alternatives**: Parsing the backend `detail` text to tell "expired" from "used" was rejected because Principle XII forbids it. Adding these cases to `friendlyError()` for every 404/400 was rejected because those messages are specific to redeeming a code.

## R2. Getting the code back after sending an invite

- **Decision**: Change `sendInvite` from `Future<void>` to `Future<String?>`. It returns the `code` field of the 200 response, or `null` if the response doesn't include one. The only caller (`apprentice_invite_screen.dart`) shows the code dialog when a code comes back, and the existing "Invitation sent" snackbar otherwise.
- **Rationale**: This is the smallest change. A null fallback keeps the app safe against a backend without spec 006, although the release gate means that shouldn't happen in prod. The mentor's name for the share text comes from the backend profile (`getUserProfile`), because the Firebase `displayName` is often empty for mentors who signed up by email.

## R3. Sharing and copying

- **Decision**: Use `share_plus` (`Share.share(text, subject: …)`, already ^10.1.3 in pubspec and used in report screens) and `Clipboard.setData` (already used in `mentor_gift_seats_screen.dart`). A pure `buildInviteShareMessage({required String mentorName, required String code})` in `lib/utils/invite_codes.dart` builds the text. The store URLs are constants there: App Store `https://apps.apple.com/app/t-root-h-discipleship/id6757311543`, Play `https://play.google.com/store/apps/details?id=com.trooth.flutterTroothAssessment`. These match the backend landing page.
- **Rationale**: No new dependency (Principle IX). A pure builder is unit-testable.

## R4. Shared UI pieces

- **Decision**: Two widgets in `lib/widgets/`:
  - `invite_code_share.dart` (`InviteCodeShare`): shows the code in large monospace text with Copy and Share icon buttons, each with a tooltip and a 48 px target. Used in the post-send dialog and in each pending-invite card.
  - `invite_code_entry.dart` (`InviteCodeEntry`):
    - a code field with uppercase input (a `TextInputFormatter` that uppercases), `textCapitalization.characters`, `autocorrect: false`, and `maxLength: 32` with the counter hidden;
    - a submit button with a loading state;
    - an inline error line.

    It calls `redeemInviteCode`, shows `inviteCodeErrorMessage` on failure (keeping the typed text), and calls `onRedeemed(InviteRedemption)` on success. It is used on the apprentice invitations screen and the apprentice dashboard.
- **Rationale**: The same UI appears in two places for each role. Principle VI favors plain widgets in `lib/widgets/` and `setState`.

## R5. When the dashboard shows "Have an invite code?"

- **Decision**: `ApprenticeDashboardNew._loadAll` also calls the existing `ApiService().getMentorStatus()` (`GET /apprentice/mentor/status` → `{has_active, mentors}`). If `has_active == false`, the dashboard shows an `InviteCodeEntry` card near the top. After a successful redeem, it re-runs the load (mentor status, invite count, assessments) and shows the success message. If the status call fails, the card stays hidden (logged with `debugPrint`), so a network blip never blocks the dashboard. The invitations screen always shows the entry field, so redeeming is never out of reach.
- **Rationale**: The endpoint already exists and is used by `apprentice_mentor_screen.dart`. No backend change is needed (spec assumption).

## R6. Login screen layout and platform detection

- **Decision**: Restructure `SimpleLoginScreen` into two modes with `bool _showEmailForm` (default `false`):
  - **Social mode:** logo and title, then Apple (iOS only, first, using the package's system-styled `SignInWithAppleButton` with the white style), then Google (outlined), then a `TextButton` "Continue with email".
  - **Email mode:** the existing email and password form, Forgot Password, the Sign In button and the "Create account" link, plus a "Back to sign-in options" `TextButton`.

  An `AnimatedSwitcher` moves between the two. Switch platform detection from `dart:io Platform.isIOS` to `defaultTargetPlatform == TargetPlatform.iOS`, so widget tests can set `debugDefaultTargetPlatformOverride`. `Platform.isIOS/isAndroid` stays only inside `_initGoogleSignIn`, where it chooses client IDs and runs only on a real device. The file is 684 lines, so the builders for the two modes move to a `part` file `simple_login_screen_widgets.dart` (Principle VI).
- **Rationale**: This meets FR-008 and FR-009 with no change to the sign-in logic: `_signIn`, `_signInWithGoogle`, `_signInWithApple`, `_navigateBasedOnRole` and Forgot Password are untouched, as are `SessionController` and role selection (Principle V). Apple's guideline 4.8 is met because Sign in with Apple is offered and is at least as prominent as Google.
- **Alternatives**: Keeping the email fields visible below the buttons was rejected because the user approved "demote email". A separate route for the email screen was rejected as needless navigation (Principle VI keeps auth routes in `router.dart`, and this is just a state toggle).

## R7. Testing

- **Decision**:
  - Unit tests with `MockClient` (Principle VIII): `redeemInviteCode` parses 200 and throws `ApiException` with the right status for 400/403/404/429/500; `sendInvite` returns the code or null.
  - Pure-function tests: `inviteCodeErrorMessage` and `buildInviteShareMessage`.
  - Widget tests:
    - `InviteCodeEntry` with a fake redeem function: uppercase formatting, error display, the typed text kept after an error, the success callback;
    - `SimpleLoginScreen` button order under `TargetPlatform.iOS` vs `TargetPlatform.android` and the email toggle. Required: the screen touches Firebase only when a button is pressed, never while building, so it pumps without Firebase being set up.
  - Because login is auth code, run `integration_test/session_flows_test.dart` on a simulator against dev, then `flutter build ios --config-only` (Principle VIII, and the user's memory note about resetting the iOS config after integration tests).

## R8. Release dependency

- **Decision**: This build MUST NOT be tagged for release until backend spec 006 is deployed to prod (Principle XII). It's on dev now. The plan records this, and tasks.md will end with an explicit gate task.
