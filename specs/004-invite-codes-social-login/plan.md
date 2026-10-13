# Implementation Plan: Invite Codes & Social-First Login

**Branch**: `feature/invite-codes-social-login` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/004-invite-codes-social-login/spec.md`

## Summary

Apprentices can enter a mentor's invite code from the invitations screen, and from the dashboard when they have no active mentor. The app calls the new `POST /invitations/redeem` and reacts by status code only. Mentors get the code back after sending an invite and see it on each pending invite, with Copy and Share (share sheet). The login screen leads with Sign in with Apple (iOS only) and Google, and the existing email form moves behind "Continue with email". Sign-in logic, role selection and `SessionController` are untouched. No new packages. Backend spec 006 provides every endpoint and must reach prod before this ships.

## Technical Context

**Language/Version**: Dart / Flutter (version pinned in `.github/workflows/release.yml`)

**Primary Dependencies**: existing only: `share_plus` ^10.1.3 (`Share.share`), Flutter `services` (`Clipboard`, `TextInputFormatter`), `firebase_auth`, `google_sign_in`, `sign_in_with_apple`. **No new packages.**

**Backend Endpoints**:
- `POST /invitations/redeem` (new);
- `POST /invitations/invite-apprentice` (now returns `code`);
- `GET /invitations/pending-invites` (items have `code`);
- `GET /apprentice/mentor/status` (existing).

See [contracts/backend-usage.md](contracts/backend-usage.md), which links the backend contract in `trooth_assessment_backend/specs/006-invite-codes/contracts/invitations.md`.

**Storage**: backend API only. Nothing is stored on the device.

**Testing**: `flutter test` (unit + widget). `integration_test/session_flows_test.dart` on a simulator against dev, because the login screen changes.

**Target Platform**: iOS and Android (store builds)

**Project Type**: mobile-app (backend: `trooth_assessment_backend`)

**Performance Goals**: redeem feedback is shown within about 1 s on a normal connection (the backend p95 is under 300 ms). The login screen renders with no added network calls.

**Constraints**: the app reacts to status codes only (Principle XII). The UI works at 1.5x text (Principle VII). The code is never logged.

**Scale/Scope**: 5 screens touched (login, mentor invite screen, apprentice invitations screen, apprentice dashboard, plus dialogs), 2 new widgets, 1 model, 1 utility file, 1 new and 1 changed API method.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. API gateway** ✅ `redeemInviteCode` and the changed `sendInvite` live in the `InvitesAgreementsApi` extension (`lib/services/api/invites_agreements.dart`). Failures throw `ApiException`. No `package:http` outside `api_service.dart`.
- [x] **II. Environment** ✅ No hardcoded backend URLs; the backend URL comes from `ApiService().baseUrl`. The App Store and Play links in share text are public store URLs, not backend URLs. Verified on dev before release.
- [x] **III. Security & privacy** ✅ No new data is collected, so `PrivacyInfo.xcprivacy` is unchanged. Codes and tokens aren't logged. Role checks are UI only, and the backend enforces them (403 is handled). Firestore rules aren't touched.
- [x] **IV. Errors** ✅ The redeem errors are specific FR-003 messages chosen by status code, with `friendlyError()` for everything else. Every `await` in widgets is followed by a `mounted` check. Sign-in flows keep their Crashlytics reporting.
- [x] **V. Session** ✅ Sign-in methods and `_navigateBasedOnRole` are unchanged; only layout changes. No direct token handling.
- [x] **VI. Structure** ✅ `setState` and plain widgets in `lib/widgets/`. Detail navigation stays as `Navigator.push`, with no `pushNamed` and no new app-level route. The login builders move to a `part` file `simple_login_screen_widgets.dart` (the screen is 684 lines). Theme constants from `lib/theme.dart` are used for new UI.
- [x] **VII. Accessibility** ✅ Copy and Share are `IconButton`s with tooltips and 48 px targets. Text is at least 11 px. Layout is checked at 1.5x text (quickstart §2.11).
- [x] **VIII. Tests** ✅ MockClient unit tests for the API methods, pure-function tests, and widget tests for the entry widget and login layout. Analyze and test must pass. The session integration test runs because login is touched.
- [x] **IX. Dependencies** ✅ None added.
- [x] **X. Logging** ✅ New code uses `debugPrint` / `dev.log` only. No `print`.
- [x] **XI. Release** ✅ No version change in this feature; it's done later with `/bump-version`.
- [x] **XII. Cross-repo** ✅ Every endpoint is named and confirmed in backend spec 006 (contract linked) and deployed to dev. **Gate**: backend 006 must be on prod before this is tagged (tracked as a final task).

**Post-design re-check**: passes. The design adds no route, package, stored data or body-text branching.

## Project Structure

### Documentation (this feature)

```text
specs/004-invite-codes-social-login/
├── spec.md
├── plan.md                      # this file
├── research.md                  # R1–R8
├── data-model.md
├── quickstart.md
├── contracts/backend-usage.md   # client usage of backend contract 006
├── checklists/requirements.md
└── tasks.md                     # /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── models/invite_redemption.dart                # NEW: InviteRedemption + InviteRelationship
├── utils/invite_codes.dart                      # NEW: inviteCodeErrorMessage(), buildInviteShareMessage(), store URL consts,
│                                                #      UpperCaseTextFormatter
├── widgets/invite_code_share.dart               # NEW: code display + Copy/Share
├── widgets/invite_code_entry.dart               # NEW: code field + submit + inline error
├── services/api/invites_agreements.dart         # redeemInviteCode() new; sendInvite() returns String?
├── screens/simple_login_screen.dart             # social-first layout, _showEmailForm, defaultTargetPlatform
├── screens/simple_login_screen_widgets.dart     # NEW part file: _buildSocialOptions / _buildEmailForm
├── screens/apprentice_invite_screen.dart        # mentor: code dialog after send; code + share on each pending card;
│                                                #   remove _copyInviteLink placeholder
├── screens/apprentice_invites_screen.dart       # apprentice: InviteCodeEntry at top
└── screens/apprentice_dashboard_new.dart        # mentor status → "Have an invite code?" card; refresh on success
test/
├── invite_codes_test.dart                       # NEW: API (MockClient) + pure functions
├── invite_code_entry_test.dart                  # NEW: widget
├── invite_code_share_test.dart                  # NEW: widget
└── login_layout_test.dart                       # NEW: widget (platform order, email toggle)
```

**Structure Decision**: This follows the existing layout: API extension parts, plain widgets in `lib/widgets/`, models in `lib/models/`, helpers in `lib/utils/`, and `*_widgets.dart` part files for large screens. Nothing goes in `lib/router.dart` because no app-level route changes.

## Complexity Tracking

No constitution violations.
