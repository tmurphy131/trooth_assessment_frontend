---

description: "Task list for agreement apprentice picker and gift code redemption"
---

# Tasks: Agreement Apprentice Picker & Gift Code Redemption

**Input**: Design documents from `/specs/005-agreement-picker-gift-codes/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/backend-usage.md, quickstart.md

**Tests**: Per constitution Principle VIII, test tasks are REQUIRED for any service, parser, model or API-extension change (unit tests with `MockClient` + `setAuthForTesting`, as in `test/invite_codes_test.dart`). Widget tests are included for the new widgets and the changed agreement screen. Each story ends with `flutter analyze --no-fatal-infos` and `flutter test` passing.

**Organization**: Tasks are grouped by user story so each can be implemented and tested independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 = agreement apprentice picker, US2 = apprentice gift-code redemption

**Conventions for every UI task**:
- `if (!mounted) return;` after every `await` before using `context` or `setState` (Principle IV);
- tooltips on icon buttons, tap targets of at least 48 px, text of at least 11 px, no overflow at 1.5x text (Principle VII);
- `kPrimaryGold` / `kCharcoal` from `lib/theme.dart` instead of new `Color(0x…)` literals (Principle VI);
- `debugPrint` only, and never the gift code (Principles III and X).

---

## Phase 1: Setup

- [X] T001 Run `flutter analyze --no-fatal-infos` and `flutter test` on `feature/agreement-apprentice-picker-gift-codes` and note the counts (infos, tests) as the baseline.

---

## Phase 2: Foundational

No shared blocking work: each story's API, model and widget files are separate. Stories can start right after T001.

---

## Phase 3: User Story 1 - Mentor sends an agreement by picking a connected apprentice (Priority: P1) 🎯 MVP

**Goal**: The agreement form offers the mentor's current apprentices, and picking one sends `apprentice_id`. "Someone else" keeps email entry.

**Independent Test**: On dev with backend #44, a mentor picks an apprentice whose account uses an Apple relay email and creates an agreement. That apprentice sees it in pending agreements and signs it in the app.

### Tests for User Story 1 ⚠️

- [X] T002 [P] [US1] Create `test/agreement_picker_test.dart`, using the `MockClient` + `api.setAuthForTesting(...)` + `api.clearCache()` pattern, capturing the request:
  - **`createAgreement` by ID:** with `apprenticeId: 'a1'` and no email, the JSON body has `apprentice_id: 'a1'` and **no** `apprentice_email` key.
  - **`createAgreement` by email:** with `apprenticeEmail: 'x@y.com'`, the body has `apprentice_email` and no `apprentice_id`.
  - **Errors:** 403 and 422 throw `ApiException` with that `statusCode`.
  - **`agreementCreateErrorMessage`:** returns exactly `"This apprentice isn't connected to you anymore. Refresh and try again."` for 403 and `"Choose an apprentice or enter an email."` for 422, and `friendlyError(e)` for 500 and non-API errors.
  - **`ApprenticePicker` widget:** pump with `[{'id':'b','name':'Zoe','email':'z@x.com'}, {'id':'a','name':'','email':'amy@x.com'}, {'id':'c','name':'Ben','email':'b@x.com'}]` and open the dropdown.
    - The labels appear in the order `amy@x.com`, `Ben`, `Zoe`, then `Someone else (enter email)` last. The empty name falls back to email, and sorting ignores case.
    - Choosing `Ben` calls `onChanged('c')`; choosing "Someone else" calls `onChanged(null)`.
    - No overflow at 1.5x text.
- [X] T003 [P] [US1] Create `test/mentor_agreements_screen_test.dart`. Pump `MentorAgreementsScreen` inside a `MaterialApp`, with `ApiService().httpClient = MockClient(...)` routing by path:
  - `GET .../agreements/templates` → one active template, matching the shape `_loadTemplates` reads (for example `[{"version":1,"is_active":true,"markdown_source":"x","created_at":"2026-01-01T00:00:00"}]`);
  - `GET .../mentor/my-apprentices` → `[{"id":"a1","name":"Jordan","email":"relay@privaterelay.appleid.com"}]`;
  - `GET .../agreements` (list) → `[]`;
  - `POST .../agreements` → capture the body and return a minimal agreement JSON.

  Also call `api.setAuthForTesting(...)` and `api.clearCache()`. Stub any other endpoint the screen reads on load with an empty success. Tests:
  - **Picker hides email:** choosing "Jordan" fills the name field with "Jordan" and hides the "Apprentice Email" field. Creating sends a body with `apprentice_id: "a1"` and no `apprentice_email`.
  - **"Someone else":** the email field shows; typing `x@y.com` and creating sends `apprentice_email` and no `apprentice_id`.
  - **List fails to load:** `/mentor/my-apprentices` → 500 means no picker, and the email field shows (FR-004).
  - **403 on create:** the screen shows `Create failed: This apprentice isn't connected to you anymore. Refresh and try again.`

### Implementation for User Story 1

- [X] T004 [P] [US1] In `lib/services/api/invites_agreements.dart`, `createAgreement`:
  - change `required String apprenticeEmail` to `String? apprenticeEmail`;
  - add `String? apprenticeId`;
  - build the payload with `if (apprenticeId != null) 'apprentice_id': apprenticeId else if (apprenticeEmail != null) 'apprentice_email': apprenticeEmail`.

  Everything else, including error handling, stays the same. The only caller is `mentor_agreements_screen.dart`, updated in T007.
- [X] T005 [P] [US1] Create `lib/utils/agreement_errors.dart` with `String agreementCreateErrorMessage(Object error)`:
  - `ApiException` 403 → `"This apprentice isn't connected to you anymore. Refresh and try again."`
  - 422 → `"Choose an apprentice or enter an email."`
  - otherwise → `friendlyError(error)` (from `errors.dart`).
- [X] T006 [P] [US1] Create `lib/widgets/apprentice_picker.dart` with `class ApprenticePicker extends StatelessWidget`. Parameters:
  - `final List<Map<String, dynamic>> apprentices`;
  - `final String? value`;
  - `final ValueChanged<String?> onChanged`;
  - `final bool enabled`.

  It renders a `DropdownButtonFormField<String?>` labeled "Apprentice", with `isExpanded: true` and white text, matching the form's existing `InputDecoration` style. Items:
  - one per apprentice: value `id`; label `name` if non-empty after trimming, else `email`; **sorted case-insensitively by label, on a copy, never changing the input list**;
  - a last item with value `null` and label `"Someone else (enter email)"`.

  Ellipsize long labels.
- [X] T007 [US1] Update `lib/screens/mentor_agreements_screen.dart` (depends on T004, T005, T006):
  - **State:** add `List<Map<String, dynamic>> _apprentices = []` and `String? _selectedApprenticeId`.
  - **Loading:** add `_loadApprentices()`, which calls `_api.listApprentices()` and stores the result cast to maps. On error it `debugPrint`s and keeps the list empty. Call it from `initState` next to `_loadTemplates()`.
  - **Form:** above the name field, `if (_apprentices.isNotEmpty) ApprenticePicker(...)`. On change: set `_selectedApprenticeId`; when non-null, fill `_apprenticeNameCtrl` with the apprentice's name (if any); when null, clear `_apprenticeEmailCtrl`.
  - **Email field:** show the existing field only when `_selectedApprenticeId == null`. With no apprentices, the picker isn't shown and it's exactly today's email form.
  - **`_createAgreement`:**
    - the guard becomes "template chosen **and** (`_selectedApprenticeId != null` **or** the email is non-empty)";
    - pass `apprenticeId: _selectedApprenticeId` and `apprenticeEmail: _selectedApprenticeId == null ? _apprenticeEmailCtrl.text.trim() : null`;
    - in the `catch`, use `'Create failed: ${agreementCreateErrorMessage(e)}'`;
    - add a `mounted` check after each `await`.
  - **`_resetForm`:** also clear `_selectedApprenticeId`.
- [X] T008 [US1] Run `flutter analyze --no-fatal-infos` and `flutter test test/agreement_picker_test.dart test/mentor_agreements_screen_test.dart` until both pass.

**Checkpoint**: Agreements can go to a connected apprentice by account. This is the MVP; it needs backend 007 deployed.

---

## Phase 4: User Story 2 - Apprentice redeems a gift code (Priority: P1)

**Goal**: Apprentices can enter a mentor's gift code on the Upgrade screen or their profile, and Premium unlocks straight away.

**Independent Test**: On dev, an apprentice on the free tier enters a mentor's unassigned seat code in lowercase without dashes. They see "Premium access activated! Gifted by {mentor}.", and the profile shows Premium (Gift).

### Tests for User Story 2 ⚠️

- [X] T009 [P] [US2] Create `test/gift_codes_test.dart`, using the MockClient pattern and capturing the request:
  - **`redeemGiftCode('TROOTH-A7K9-M2P4')`:**
    - posts `{"code":"TROOTH-A7K9-M2P4"}` to a path ending in `/apprentice/redeem-code`;
    - a 200 with `{"success":true,"message":"Premium access activated!","new_tier":"mentor_gifted","expires_at":null,"mentor_name":"Marcus"}` parses to `success == true` and `mentorName == 'Marcus'`;
    - a 200 with `{"success":false,"message":"This code has already been redeemed."}` parses to `success == false` with that message;
    - 403 and 500 throw `ApiException` with that `statusCode`;
    - a 200 with `'not json'` or `{}` throws `ApiException` with `statusCode == 200`.
  - **`normalizeGiftCode`:**
    - `'a7k9m2p4'` → `'TROOTH-A7K9-M2P4'`;
    - `' trooth-a7k9-m2p4. '` → `'TROOTH-A7K9-M2P4'`;
    - `'TROOTH A7K9 M2P4'` → `'TROOTH-A7K9-M2P4'`;
    - `'A7K9'` → `null`;
    - `''` → `null`;
    - `'A7K9M2P4X'` → `null`.
- [X] T010 [P] [US2] Create `test/gift_code_form_test.dart` (widget tests of `GiftCodeForm` with an injected fake `redeem`):
  - **Incomplete code:** typing `a7k9` and tapping Redeem shows `"That code looks incomplete."`, and the fake is **not** called.
  - **Success:** typing `a7k9 m2p4` calls the fake with `'TROOTH-A7K9-M2P4'`; returning success calls `onRedeemed` once with the result.
  - **`success: false`:** returning `success: false, message: 'This code has expired.'` shows exactly that text and keeps the input.
  - **403:** throwing `ApiException(403, '')` shows `"Gift codes are for apprentice accounts."`.
  - **Other errors:** throwing `ApiException(500, '')` shows `friendlyError` text.
  - **Accessibility:** no overflow at 1.5x text on a 360-wide screen.

  Inject a no-op error reporter (see T014) so tests never touch Crashlytics.

### Implementation for User Story 2

- [X] T011 [P] [US2] Create `lib/models/gift_code_redemption.dart`: `class GiftCodeRedemption { final bool success; final String message; final String? mentorName; final String? expiresAt; }` with `factory fromJson(Map<String, dynamic>)`. `success` and `message` are required (a cast failure throws); `mentor_name` and `expires_at` are optional. Add the import to `lib/services/api_service.dart` so the `subscriptions.dart` part can use it.
- [X] T012 [P] [US2] Create `lib/utils/gift_codes.dart` with `String? normalizeGiftCode(String raw)`, per the data model:
  1. uppercase;
  2. keep only `[A-Z0-9]`;
  3. if it starts with `TROOTH` and more than 8 characters remain, drop the `TROOTH`;
  4. exactly 8 left → `'TROOTH-${s.substring(0,4)}-${s.substring(4)}'`; else `null`.
- [X] T013 [US2] In `lib/services/api/subscriptions.dart` (`SubscriptionsApi`), add `Future<GiftCodeRedemption> redeemGiftCode(String code)`. It POSTs `{'code': code}` to `'$_base/apprentice/redeem-code'` with `_headers()`.
  - **Not 200:** throw `ApiException(r.statusCode, 'redeemGiftCode failed (${r.statusCode})')`.
  - **200:** `try { return GiftCodeRedemption.fromJson(jsonDecode(r.body) as Map<String, dynamic>); } catch (_) { throw ApiException(r.statusCode, 'redeemGiftCode: malformed response'); }`.

  Never put the code or the body in messages. Depends on T011.
- [X] T014 [US2] Create `lib/widgets/gift_code_sheet.dart`:
  - **`GiftCodeForm`** (`StatefulWidget`). Parameters:
    - `final void Function(GiftCodeRedemption) onRedeemed`;
    - `final Future<GiftCodeRedemption> Function(String code)? redeem` (defaults to `ApiService().redeemGiftCode`);
    - `final void Function(Object error, StackTrace stack)? reportError` (defaults to `FirebaseCrashlytics.instance.recordError(e, st, reason: 'Gift code redeem failed')`).

    It renders:
    - the title "Have a gift code from your mentor?";
    - a `TextField` (hint `TROOTH-XXXX-XXXX`, `textCapitalization: characters`, `autocorrect: false`, `maxLength: 24` with no counter);
    - a "Redeem" `ElevatedButton` with a loading state;
    - an inline error `Text`.

    On submit:
    1. `normalizeGiftCode(text)`. If it's `null`, set the error to `"That code looks incomplete."` and stop.
    2. Await `redeem(code)`.
       - **`success`:** call `onRedeemed(result)`.
       - **`success: false`:** set the error to `result.message` and keep the text.
       - **`ApiException` 403:** `"Gift codes are for apprentice accounts."`.
       - **Anything else:** `friendlyError(e)`, **and** call `reportError(e, st)`, since this is a Premium-granting flow (Principle IV). Never include the code in what's reported.
  - **`Future<bool> showGiftCodeSheet(BuildContext context)`.** It opens a `showModalBottomSheet` (`isScrollControlled: true`, padded for the keyboard) containing `GiftCodeForm`. On success it:
    1. `await SubscriptionService().refreshStatus()`;
    2. pops the sheet with `true`;
    3. shows a `SnackBar`: `"Premium access activated! Gifted by ${r.mentorName}."` when `mentorName` is non-empty, else `"Premium access activated!"`.

    It returns `true` on success, `false` when the sheet is dismissed.

  Depends on T011, T012, T013.
- [X] T015 [US2] In `lib/screens/subscription_screen.dart`, `_buildContent`: in the **non-Premium** branch, right after `_buildPricingOptions()`, add `if (_userRole == 'apprentice') TextButton.icon(icon: Icon(Icons.card_giftcard), label: Text('Have a gift code from your mentor?'), onPressed: _openGiftCode)`. Add `Future<void> _openGiftCode() async { final ok = await showGiftCodeSheet(context); if (!mounted) return; if (ok) Navigator.of(context).pop(); }`. Mentors never see the button.
- [X] T016 [US2] In `lib/screens/apprentice_profile_screen.dart`, `_buildSubscriptionCard`: when the tier is `SubscriptionTier.free`, add a `TextButton.icon` (same label and icon as T015) that does `final ok = await showGiftCodeSheet(context); if (!mounted) return; if (ok) _load();`. Hide it when the apprentice already has Premium (FR-005).
- [X] T017 [US2] Run `flutter analyze --no-fatal-infos` and `flutter test test/gift_codes_test.dart test/gift_code_form_test.dart` until both pass.

**Checkpoint**: Both stories are done.

---

## Phase 5: Polish & Cross-Cutting

- [X] T018 [P] Grep the new and changed files for `print(` and for logging of the gift code or response bodies (`lib/services/api/subscriptions.dart`, `lib/services/api/invites_agreements.dart`, `lib/widgets/gift_code_sheet.dart`, `lib/widgets/apprentice_picker.dart`, `lib/screens/mentor_agreements_screen.dart`, `lib/screens/subscription_screen.dart`, `lib/screens/apprentice_profile_screen.dart`). Fix anything found.
- [X] T019 Run `flutter analyze --no-fatal-infos` and the full `flutter test`. Results must match the T001 baseline plus the new tests.
- [ ] T020 Manual checks on dev: [quickstart.md §2](quickstart.md) steps 1–9. **Requires the user**: backend #44 deployed to dev, plus mentor and apprentice accounts and a premium mentor's gift seat.
- [ ] T021 **Release gate (Principle XII)**: before any `v*` tag with US1, confirm backend spec 007 is on prod (quickstart §3). **Requires the user** (`/deploy-prod`).

---

## Dependencies & Execution Order

- T001 → stories. **US1** (T002–T008) and **US2** (T009–T017) are fully independent; they touch different files.
- US1: T002, T003, T004, T005 and T006 in parallel, then T007 → T008.
- US2: T009, T010, T011 and T012 in parallel, then T013 → T014 → T015 and T016 (different screens, so those two can run in parallel) → T017.
- Shared file: `lib/services/api_service.dart` gets one import line in T011; no conflict with US1.

## Parallel Examples

- **Across stories**: build US1 and US2 at the same time.
- **US1**: T002 + T003 + T004 + T005 + T006 together; then T007.
- **US2**: T009 + T010 + T011 + T012 together; then T013; then T014; then T015 + T016.

## Implementation Strategy

1. **MVP**: US1, the agreement picker. It's the most common hidden-email gap. It needs backend 007 on prod before release.
2. **US2** (gift codes) can ship on its own, even before backend 007 reaches prod, because its endpoint is already live.
3. Polish, check on dev, then release under the T021 gate.
