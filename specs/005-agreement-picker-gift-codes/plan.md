# Implementation Plan: Agreement Apprentice Picker & Gift Code Redemption

**Branch**: `feature/agreement-apprentice-picker-gift-codes` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/005-agreement-picker-gift-codes/spec.md`

## Summary

**Agreement picker.** The mentor's agreement form gets a picker of their current apprentices, reusing `listApprentices()`. Picking one sends `apprentice_id`, which backend spec 007 ties to the account. "Someone else" keeps today's email entry.

**Gift codes.** Apprentices get a "Have a gift code from your mentor?" bottom sheet on the Upgrade screen and the profile. It normalizes the code, calls the existing `POST /apprentice/redeem-code` through a new API method, and refreshes Premium status on success.

Errors are handled by status code and the `success` field, never by message text. No new packages and no new routes.

## Technical Context

**Language/Version**: Dart / Flutter (version pinned in `.github/workflows/release.yml`)

**Primary Dependencies**: existing only (Material widgets, `SubscriptionService`). **No new packages.**

**Backend Endpoints**:
- `POST /agreements` (adds `apprentice_id`; backend spec 007, PR #44);
- `GET /mentor/my-apprentices` (existing);
- `POST /apprentice/redeem-code` (existing; apprentice-only after spec 007);
- `GET /subscriptions/status` (existing, via `refreshStatus()`).

See [contracts/backend-usage.md](contracts/backend-usage.md).

**Storage**: backend API only.

**Testing**: `flutter test` (MockClient unit tests, pure-function tests, widget tests). No auth or session change, so no integration test is required.

**Target Platform**: iOS and Android (store builds)

**Project Type**: mobile-app (backend: `trooth_assessment_backend`)

**Performance Goals**: The agreement form adds one list request, run in parallel with the template load. Gift redemption is one request plus a status refresh.

**Constraints**: Status-code handling only (Principle XII). 1.5x text (Principle VII). Gift codes aren't logged.

**Scale/Scope**: 3 screens touched (mentor agreements, subscription, apprentice profile). New: 3 widgets or files (picker, gift sheet, models/utils). 2 API methods (1 changed, 1 new).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. API gateway** ✅ `createAgreement` (changed) and `redeemGiftCode` (new) are in their `ApiService` extensions and throw `ApiException`, including on a malformed 200.
- [x] **II. Environment** ✅ No URLs added. Verified on dev before release.
- [x] **III. Security & privacy** ✅ No new data collected. Codes aren't logged. Role gating of the gift entry is UI-only; the backend enforces it with 403, which the app handles.
- [x] **IV. Errors** ✅ Specific messages by status, with `friendlyError()` otherwise. Unexpected gift-redeem failures are reported to Crashlytics (a Premium-granting flow), without the code. `mounted` checks after every `await`.
- [x] **V. Session** ✅ Not touched. Premium refresh goes through the existing `SubscriptionService.refreshStatus()`.
- [x] **VI. Structure** ✅ `setState` and plain widgets in `lib/widgets/`. A bottom sheet, not a new route. `Navigator.pop` only. Theme constants.
- [x] **VII. Accessibility** ✅ The picker and sheet have targets of at least 48 px, tooltips on any icon buttons, and work at 1.5x text (widget-tested).
- [x] **VIII. Tests** ✅ API, model and util unit tests; widget tests for the new widgets. Analyze and test must pass.
- [x] **IX. Dependencies** ✅ None added.
- [x] **X. Logging** ✅ `debugPrint` only; no `print`.
- [x] **XI. Release** ✅ No version change here.
- [x] **XII. Cross-repo** ✅ Every endpoint is named, and the backend contract is linked. **Gate**: backend 007 on prod before tagging (US1).

**Post-design re-check**: passes.

## Project Structure

### Documentation (this feature)

```text
specs/005-agreement-picker-gift-codes/
├── spec.md
├── plan.md                      # this file
├── research.md                  # R1–R7
├── data-model.md
├── quickstart.md
├── contracts/backend-usage.md
├── checklists/requirements.md
└── tasks.md                     # /speckit-tasks
```

### Source Code (repository root)

```text
lib/
├── models/gift_code_redemption.dart         # NEW
├── utils/gift_codes.dart                    # NEW: normalizeGiftCode()
├── utils/agreement_errors.dart              # NEW: agreementCreateErrorMessage()
├── widgets/apprentice_picker.dart           # NEW: DropdownButtonFormField of apprentices + "Someone else"
├── widgets/gift_code_sheet.dart             # NEW: showGiftCodeSheet() + GiftCodeForm
├── services/api/invites_agreements.dart     # createAgreement: apprenticeId?, apprenticeEmail?
├── services/api/subscriptions.dart          # redeemGiftCode() new
├── services/api_service.dart                # import the new model for the part file
├── screens/mentor_agreements_screen.dart    # load apprentices; picker; send id or email; error text
├── screens/subscription_screen.dart         # apprentice-only "Have a gift code…" button; pop on success
└── screens/apprentice_profile_screen.dart   # "Have a gift code…" in the subscription section; _load() on success
test/
├── agreement_picker_test.dart               # NEW: createAgreement payload, error mapping, ApprenticePicker
├── mentor_agreements_screen_test.dart       # NEW: screen behavior (picker vs email, fallback, 403)
├── gift_codes_test.dart                     # NEW: redeemGiftCode, model, normalizeGiftCode
└── gift_code_form_test.dart                 # NEW: GiftCodeForm widget
```

**Structure Decision**: The existing layout: API extension parts, plain widgets, models, and utils. The two UI additions are self-contained widgets, so the large screens only gain a few lines each.

## Complexity Tracking

No constitution violations.
