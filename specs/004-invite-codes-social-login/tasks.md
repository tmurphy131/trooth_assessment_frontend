---

description: "Task list for invite codes & social-first login"
---

# Tasks: Invite Codes & Social-First Login

**Input**: Design documents from `/specs/004-invite-codes-social-login/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/backend-usage.md, quickstart.md

**Tests**: Per constitution Principle VIII, test tasks are REQUIRED for any service, parser, model or API-extension change (unit tests with `MockClient` + `setAuthForTesting`, as in `test/report_status_api_test.dart`). Widget tests are included for the new UI. Each story ends with `flutter analyze --no-fatal-infos` and `flutter test` passing.

**Organization**: Tasks are grouped by user story so each can be implemented and tested independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 = apprentice enters a code, US2 = mentor shares a code, US3 = social-first login

**Conventions for every UI task**:
- check `if (!mounted) return;` after each `await` before using `context` or `setState` (Principle IV);
- give every `IconButton` a `tooltip`, with tap targets of at least 48 px and text of at least 11 px (Principle VII);
- use `kPrimaryGold` / `kCharcoal` from `lib/theme.dart` instead of new `Color(0x…)` literals (Principle VI);
- log with `debugPrint` only, never the code (Principles III and X).

---

## Phase 1: Setup

- [X] T001 Run `flutter analyze --no-fatal-infos` and `flutter test` on `feature/invite-codes-social-login` and note any warnings or failures that already exist, as a baseline for later runs.

---

## Phase 2: Foundational (blocks US1 and US2)

**Purpose**: The shared model, pure helpers and API methods. All unit-testable with no UI.

- [X] T002 [P] Create `lib/models/invite_redemption.dart`:
  - `enum InviteRelationship { created, reactivated, alreadyActive }`;
  - `class InviteRedemption { final String mentorId; final String? mentorName; final InviteRelationship relationship; }`;
  - `factory InviteRedemption.fromJson(Map<String, dynamic> json)`, mapping `mentor_id` (required), `mentor_name` (nullable) and `relationship` (`"created"` / `"reactivated"` / `"already_active"`; **an unknown value is treated as `created`**).
- [X] T003 [P] Create `lib/utils/invite_codes.dart` (imports only `package:flutter/services.dart`, `api_service.dart` and `errors.dart`):
  - Constants `kAppStoreUrl = 'https://apps.apple.com/app/t-root-h-discipleship/id6757311543'` and `kPlayStoreUrl = 'https://play.google.com/store/apps/details?id=com.trooth.flutterTroothAssessment'`.
  - `class UpperCaseTextFormatter extends TextInputFormatter`, which uppercases the new value and keeps the selection.
  - `String inviteCodeErrorMessage(Object error)`. **By `ApiException.statusCode` only**:
    - 404 → `"We couldn't find that code. Check it and try again."`
    - 400 → `"This code can't be used. It may have expired or already been used. Ask your mentor for a new one."`
    - 403 → `"Invite codes are for apprentice accounts."`
    - 429 → `"Too many tries. Please wait a while and try again."`
    - anything else → `friendlyError(error)`.
  - `String buildInviteShareMessage({required String mentorName, required String code})`. It returns, for example: `"{mentorName} invited you to T[root]H Discipleship.\n\nYour invite code: {code}\n\nInstall the app, sign in, and enter the code to connect.\niPhone: {kAppStoreUrl}\nAndroid: {kPlayStoreUrl}"`.
- [X] T004 In `lib/services/api/invites_agreements.dart` (`InvitesAgreementsApi`):
  - Add `Future<InviteRedemption> redeemInviteCode(String code)`. It POSTs `{'code': code.trim()}` to `'$_base/invitations/redeem'` with `_headers()`. On 200 it returns `InviteRedemption.fromJson(jsonDecode(r.body))`; otherwise it throws `ApiException(r.statusCode, 'redeemInviteCode failed (${r.statusCode})')`. Wrap the 200 parse in `try`/`catch`: a body that can't be parsed (not JSON, or `mentor_id` missing or not a string) throws `ApiException(r.statusCode, 'redeemInviteCode: malformed response')`, so no `TypeError` or `FormatException` escapes (Principle I). **Never include `r.body` or the code in any message.**
  - Change `sendInvite` to `Future<String?>`. On 200, decode the body and return `body['code'] as String?` (a body that isn't JSON, or has no `code`, returns `null`). Error behavior is unchanged.
  - Add the `invite_redemption.dart` import to `lib/services/api_service.dart` if the part file needs it.

  Depends on T002.
- [X] T005 [P] Create `test/invite_codes_test.dart`, following the `MockClient` + `api.setAuthForTesting(...)` + `api.clearCache()` pattern in `test/report_status_api_test.dart`:
  - `redeemInviteCode`:
    - a 200 with `{"message":"…","mentor_id":"m1","mentor_name":"Marcus","relationship":"already_active"}` parses to `alreadyActive` and `mentorName == 'Marcus'`;
    - an unknown relationship parses to `created`;
    - a 200 with a malformed body (`'not json'`, or `{}` with no `mentor_id`) throws `ApiException` with `statusCode == 200` rather than a `TypeError` or `FormatException`;
    - 400/403/404/429/500 each throw `ApiException` with that `statusCode`;
    - the request body is `{"code":"K7QM-3XPR"}` when called with `"  K7QM-3XPR "`.
  - `sendInvite`: returns `'K7QM-3XPR'` from `{"message":"Invitation sent","id":"i1","code":"K7QM-3XPR","expires_at":"…"}`; returns `null` for `{"message":"Invitation sent"}`.
  - `inviteCodeErrorMessage`: the exact texts for 400/403/404/429; equals `friendlyError(e)` for a 500 and for a non-API error.
  - `buildInviteShareMessage`: contains the mentor name, the code, `kAppStoreUrl` and `kPlayStoreUrl`.
  - `UpperCaseTextFormatter`: `'k7qm 3xpr'` → `'K7QM 3XPR'`.

**Checkpoint**: `flutter test test/invite_codes_test.dart` passes.

---

## Phase 3: User Story 1 - Apprentice joins a mentor with a code (Priority: P1) 🎯 MVP

**Goal**: Apprentices can enter a code from the invitations screen, and from the dashboard when they have no mentor, and are connected to that mentor.

**Independent Test**: On dev, an apprentice with no mentor, whose email differs from the invited one, enters the code from the dashboard. They see "You're now connected with {mentor}", and the card disappears.

- [X] T006 [P] [US1] Create `lib/widgets/invite_code_entry.dart`. `class InviteCodeEntry extends StatefulWidget` takes:
  - `final void Function(InviteRedemption) onRedeemed`;
  - `final Future<InviteRedemption> Function(String code)? redeem` (defaults to `ApiService().redeemInviteCode`, injectable for tests);
  - `final bool compact` (default `false`).

  It renders:
  - a title "Have an invite code?";
  - one line of help: "Enter the code your mentor shared with you.";
  - a `TextField` with `inputFormatters: [UpperCaseTextFormatter()]`, `textCapitalization: TextCapitalization.characters`, `autocorrect: false`, `enableSuggestions: false`, `maxLength: 32` with `counterText: ''`, hint `XXXX-XXXX`, and `textInputAction: TextInputAction.done` (submitting from the keyboard calls submit);
  - a "Join" `ElevatedButton`, disabled when the trimmed text is empty or a request is in flight, showing a small spinner while loading;
  - an inline error `Text` (red accent, at least 12 px) under the field.

  On submit it calls `redeem(text.trim())`. On success it clears the field and error and calls `onRedeemed`. On error it sets the error to `inviteCodeErrorMessage(e)` **and keeps the text**. The button stays enabled after a 429. It must work at 1.5x text scale.
- [X] T007 [P] [US1] Create `test/invite_code_entry_test.dart` (widget tests with a fake `redeem`):
  - typing `k7qm 3xpr` shows `K7QM 3XPR`;
  - Join is disabled when the field is empty or whitespace;
  - a fake that throws `ApiException(404, '')` shows the 404 message and the field still shows the typed text;
  - a fake returning an `InviteRedemption` calls `onRedeemed` once and clears the field;
  - the field won't take more than 32 characters.
- [X] T008 [US1] Add a top-level helper `String inviteRedeemedMessage(InviteRedemption r)` to `lib/utils/invite_codes.dart`. It returns `"You're already connected with {name}."` for `alreadyActive`, otherwise `"You're now connected with {name}."`, where `{name}` falls back to `"your mentor"` when `mentorName` is null or empty. Add a test for it to `test/invite_codes_test.dart`. Depends on T002 and T003.
- [X] T009 [US1] In `lib/screens/apprentice_invites_screen.dart`, add an `InviteCodeEntry` card at the top of the body in **all three** non-loading states: the empty state, the list state, **and the error state** (`_buildErrorView`, around lines 91–92). Code entry must stay available even when loading the email-matched invites fails (FR-001). Wrap the body so the entry card comes first and the existing empty-state or `ListView.builder` follows; it must scroll as one list so 1.5x text doesn't overflow. On `onRedeemed`:
  1. show a `SnackBar` with `inviteRedeemedMessage(r)`;
  2. `await _loadPendingInvites()`;
  3. `if (!mounted) return;`.

  Import `../widgets/invite_code_entry.dart` and `../utils/invite_codes.dart`.
- [X] T010 [US1] In `lib/screens/apprentice_dashboard_new.dart`:
  - Add state `bool? _hasActiveMentor` (null = unknown).
  - Add `Future<void> _loadMentorStatus()`, which calls `_apiService.getMentorStatus()` and sets `_hasActiveMentor = status['has_active'] == true`. On error it calls `debugPrint('Failed to load mentor status: $e')` and leaves the value `null`, so the card stays hidden.
  - Add `_loadMentorStatus()` to the `Future.wait` list next to `_loadInviteCount()` (around line 199).
  - In the body `ListView` (around line 322), right after the welcome card, insert `if (_hasActiveMentor == false) InviteCodeEntry(onRedeemed: _onInviteRedeemed)`, wrapped in the dashboard's card styling.
  - Add `_onInviteRedeemed(InviteRedemption r)`: show a `SnackBar` with `inviteRedeemedMessage(r)`, then re-run the same loads (mentor status, invite count, assessments), with `mounted` checks.
  - Put the card builder in `lib/screens/apprentice_dashboard_new_widgets.dart` as `_buildInviteCodeCard()` on the existing private extension.
- [X] T011 [US1] Run `flutter analyze --no-fatal-infos` and `flutter test test/invite_codes_test.dart test/invite_code_entry_test.dart` until both pass.

**Checkpoint**: Apprentices can redeem codes. It's demoable on dev with codes from the backend.

---

## Phase 4: User Story 2 - Mentor shares an invite code (Priority: P1)

**Goal**: The mentor sees the code right after sending an invite and on every pending invite, with Copy and Share. The placeholder link is gone.

**Independent Test**: On dev, a mentor sends an invite. A dialog shows `XXXX-XXXX`; Copy shows a confirmation and Share opens the share sheet. The pending card shows the same code and actions.

- [X] T012 [P] [US2] Create `lib/widgets/invite_code_share.dart`. `class InviteCodeShare extends StatelessWidget` takes `final String code`, `final String mentorName` and `final bool large` (default `false`). It renders:
  - the code as `SelectableText` in monospace: 28 px bold with letter spacing 4 when `large`, otherwise 18 px;
  - a Copy `IconButton(icon: Icon(Icons.copy), tooltip: 'Copy code')`, which runs `Clipboard.setData(ClipboardData(text: code))` and then shows a `SnackBar` "Code copied";
  - a Share `IconButton(icon: Icon(Icons.ios_share), tooltip: 'Share code')`, which calls `Share.share(buildInviteShareMessage(mentorName: mentorName, code: code), subject: 'Your T[root]H invite code')` from `package:share_plus/share_plus.dart`. If the user cancels the sheet, nothing happens.

  Both buttons need targets of at least 48 px.
- [X] T013 [P] [US2] Create `test/invite_code_share_test.dart` with widget tests:
  - `InviteCodeShare(code: 'K7QM-3XPR', mentorName: 'Marcus')` shows the code;
  - it has buttons with the tooltips 'Copy code' and 'Share code';
  - tapping Copy writes `K7QM-3XPR` to the clipboard. Mock `SystemChannels.platform` with `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler` and assert `Clipboard.setData`.
- [X] T014 [US2] In `lib/screens/apprentice_invite_screen.dart`, `_sendInvite`:
  - capture `final code = await _apiService.sendInvite(payload);`, then `await _loadPendingInvites();` and `if (!mounted) return;`;
  - if `code != null`, call `_showInviteCodeDialog(name.trim(), code)`; otherwise keep `_showMessage('Invitation sent successfully!')`.

  Add `_showInviteCodeDialog(String apprenticeName, String code)`, an `AlertDialog` with:
  - title "Invite sent to {apprenticeName}";
  - content: `InviteCodeShare(code: code, mentorName: <mentor's display name>, large: true)` plus the text "Your apprentice enters this code in the T[root]H app. It expires in 7 days.";
  - a "Done" action.

  For the mentor name (FR-007), add state `String? _mentorName`. Load it once in the screen's init path with the existing `_apiService.getUserProfile(user!.uid)` (as `apprentice_dashboard_new.dart` `_loadUserProfile` does): use the profile's `name` when it isn't empty, then `FirebaseAuth.instance.currentUser?.displayName`, then `'Your mentor'`. A failed profile load uses `debugPrint` and the fallbacks. Pass `_mentorName` to every `InviteCodeShare` on this screen (the dialog here and the pending cards in T015).
- [X] T015 [US2] In `lib/screens/apprentice_invite_screen.dart`, `_buildInviteCard`: remove the "Copy link" `ElevatedButton.icon` that calls `_copyInviteLink`, and delete `_copyInviteLink` (the `yourapp.com` placeholder). When `invite['code'] is String`, show `InviteCodeShare(code: invite['code'], mentorName: …)` in its place. When `code` is missing (an older backend), show nothing there. Keep the existing Revoke action.
- [X] T016 [US2] Run `flutter analyze --no-fatal-infos` and `flutter test` for the touched tests until both pass.

**Checkpoint**: US1 and US2 together are the user-facing code feature.

---

## Phase 5: User Story 3 - Social-first sign-in and sign-up (Priority: P2)

**Goal**: The login screen leads with Apple (iOS only) and Google, with email behind "Continue with email". Sign-in logic is untouched.

**Independent Test**: The iOS layout shows Apple, then Google, then "Continue with email", with no email fields. Android shows no Apple. The email toggle works. The reviewer account still signs in by email.

- [X] T017 [P] [US3] Create `test/login_layout_test.dart`. Pump `SimpleLoginScreen` inside a `MaterialApp` with `debugDefaultTargetPlatformOverride` set (reset it in `tearDown`):
  - **iOS:** `find.byType(SignInWithAppleButton)` appears above the 'Sign in with Google' button (compare `tester.getTopLeft(...).dy`), 'Continue with email' is present, and no `TextFormField` exists;
  - **Android:** `find.byType(SignInWithAppleButton)` finds nothing;
  - tapping 'Continue with email' shows 2 `TextFormField`s and 'Forgot Password?', and tapping 'Back to sign-in options' hides them.

  This test is **required**. The login screen only touches Firebase when a button is pressed (`_signIn`, `_signInWithGoogle`, `_signInWithApple`, Forgot Password), never while building, so it pumps without Firebase being set up. Don't tap the sign-in buttons in this test.
- [X] T018 [US3] In `lib/screens/simple_login_screen.dart`:
  - add state `bool _showEmailForm = false;`;
  - replace `Platform.isIOS` at the layout sites (around lines 575, 603 and 604) with `defaultTargetPlatform == TargetPlatform.iOS` (`package:flutter/foundation.dart`);
  - **keep** `Platform.isIOS` / `Platform.isAndroid` inside `_initGoogleSignIn` (around lines 183–184), which chooses device client IDs;
  - leave `_signIn`, `_signInWithGoogle`, `_signInWithApple`, Forgot Password and `_navigateBasedOnRole` unchanged.
- [X] T019 [US3] Create the part file `lib/screens/simple_login_screen_widgets.dart` (`part of 'simple_login_screen.dart';`) and add `part 'simple_login_screen_widgets.dart';` to the screen. It has a private extension on the login State class with:
  - `_buildSocialOptions()`:
    1. on iOS, the package's system-styled button, following Apple's guidelines: `SignInWithAppleButton(style: SignInWithAppleButtonStyle.white, height: 50, onPressed: _isLoading ? () {} : _signInWithApple)` from `package:sign_in_with_apple`, full width and first;
    2. the existing outlined "Sign in with Google" button calling `_signInWithGoogle`;
    3. a `TextButton` "Continue with email" doing `setState(() => _showEmailForm = true)`.
  - `_buildEmailForm()`: the existing email and password `TextFormField`s, Forgot Password, the Sign In button and the "Create account" link, moved here unchanged, plus a `TextButton.icon` "Back to sign-in options" doing `setState(() => _showEmailForm = false)`.

  In `build`, keep the logo and title, and below them use `AnimatedSwitcher(duration: 200ms, child: _showEmailForm ? _buildEmailForm() : _buildSocialOptions())` with distinct `ValueKey`s. Remove the old "or" divider. Keep `_isLoading` disabling all buttons. Check at 1.5x text with no overflow.
- [X] T020 [US3] Run `flutter analyze --no-fatal-infos` and `flutter test test/login_layout_test.dart` until both pass.

**Checkpoint**: All three stories are done.

---

## Phase 6: Polish & Cross-Cutting

- [X] T021 [P] Grep the touched files for `print(` and for logging of `code`, `token` or response bodies (`lib/services/api/invites_agreements.dart`, `lib/widgets/invite_code_*.dart`, `lib/screens/apprentice_invite*_screen.dart`, `lib/screens/apprentice_dashboard_new*.dart`, `lib/screens/simple_login_screen*.dart`). Fix anything found (Principles III and X).
- [X] T022 Run `flutter analyze --no-fatal-infos` and the full `flutter test`. Results must match the T001 baseline plus the new passing tests.
- [ ] T023 Run `flutter test integration_test/session_flows_test.dart -d <booted iOS simulator>` against dev (login is touched, Principle VIII), then **`flutter build ios --config-only`** to reset `ios/Flutter/Generated.xcconfig`.

  *Progress 2026-10-13:* updated `signInThroughUi` in `integration_test/session_flows_test.dart` to tap "Continue with email" before filling the fields; without that change it would fail against the new layout. Not run yet: it needs `TEST_MENTOR_EMAIL`, `TEST_APPRENTICE_EMAIL` and `TEST_PASSWORD` dart-defines, which aren't in the repo.
- [ ] T024 Manual checks on dev: [quickstart.md §2](quickstart.md) steps 1–13 (including the tap count for SC-004 and the redeem timing for the plan's performance goal) on an iOS simulator and an Android emulator, including the App Review account sign-in and the 1.5x text check. **Requires the user**: real Apple and Google sign-in needs interactive accounts.
- [ ] T025 **Release gate (Principle XII)**: before any `v*` tag for a build with this feature, confirm backend spec 006 is on prod. `curl -s -o /dev/null -w '%{http_code}' -X POST https://trooth-discipleship-api.onlyblv.com/invitations/redeem -H 'Content-Type: application/json' -d '{"code":"X"}'` must return `401`, not `404`. **Requires the user** (`/deploy-prod` for the backend first).

---

## Dependencies & Execution Order

- **Phase 1 → Phase 2.** T002 and T003 in parallel, then T004, then T005.
- **US1** (T006–T011) needs T002–T004. **US2** (T012–T016) needs T003 and T004. US1 and US2 don't depend on each other.
- **US3** (T017–T020) needs nothing from Phase 2 and can run alongside US1 and US2. Per the spec, it must not **ship** before US1 and US2.
- **Polish** comes after all stories. T025 is the last gate before release.
- Shared files: `lib/utils/invite_codes.dart` (T003, T008), `test/invite_codes_test.dart` (T005, T008), `lib/screens/apprentice_invite_screen.dart` (T014, T015). Tasks on the same file run one after another.

## Parallel Examples

- **Phase 2**: T002 (model) and T003 (utils) together.
- **US1**: T006 (entry widget) and T007 (its test) together, then T008 → T009 → T010.
- **US2**: T012 (share widget) and T013 (its test) together, then T014 → T015.
- **Across stories**: US3 (login, T017–T019) can be built at the same time as US1 and US2. It touches different files.

## Implementation Strategy

1. **MVP**: Phase 2 + US1. Apprentices can redeem codes, although mentors only see them in the email for now.
2. **Code feature complete**: add US2. This is the smallest version worth releasing.
3. **Login**: add US3 in the **same release** (never before US1 and US2; spec Story 3 rationale).
4. Polish, check on dev, deploy backend 006 to prod, then `/bump-version` and tag.
