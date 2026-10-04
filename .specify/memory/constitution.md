# T[root]H Discipleship Frontend Constitution

## Core Principles

### I. Single API Gateway

- All backend HTTP MUST go through `ApiService` and its `_ApiClient`. `package:http` MUST NOT be
  imported outside `lib/services/api_service.dart` (tests excepted).
- New endpoints MUST be added as an `extension <Domain>Api on ApiService` in
  `lib/services/api/<domain>.dart` (a `part` of `api_service.dart`).
- Endpoint failures MUST throw `ApiException`, `NetworkException` or `PremiumRequiredException`;
  new code MUST NOT throw a bare `Exception`.

**Rationale**: one client gives every call the same auth refresh, 401 retry, 20 s timeout, cache
invalidation and debug-only logging; typed errors let `friendlyError()` and premium upsells work.

### II. Environment by Build Define

- The backend URL MUST come only from `--dart-define=API_BASE_URL`; the default MUST stay the
  dev URL. Source MUST NOT hardcode backend URLs. `baseUrlOverride` is for e2e use only.
- Store builds MUST come only from the GitHub Actions release workflow (a `v*` tag builds
  against prod). Changes MUST be verified against dev before a release tag is pushed.

**Rationale**: local runs can never hit prod, and every store binary is reproducible from a tag.

### III. Security & Privacy

- Code MUST NOT log Firebase tokens, request/response bodies or personal data in release
  builds; network logging stays behind `kDebugMode`.
- Secrets (Android keystore, `key.properties`, App Store Connect and match credentials,
  test-account passwords) MUST stay out of git and arrive via CI secrets or `--dart-define`.
  RevenueCat public SDK keys are the documented exception.
- Client-side role and premium checks are UI only; authorization MUST be enforced by the
  backend, and features MUST NOT rely on hiding UI for access control.
- `firestore.rules` MUST stay deny-by-default and MUST NOT allow a user's `role` to change after
  signup. Any rules change MUST pass the `test/firestore_rules` emulator suite.
- `ios/Runner/PrivacyInfo.xcprivacy` MUST be updated when the app starts collecting new data
  types.

**Rationale**: the app handles minors' spiritual and personal data under App Store and Play
review; leaks or client-only access control are unrecoverable trust failures.

### IV. User-Facing Errors

- Error text shown to users MUST go through `friendlyError()` (`lib/utils/errors.dart`) so
  release builds never show raw exceptions.
- After every `await` in widget code, code MUST check `mounted` (`if (!mounted) return;`)
  before touching `context` or calling `setState`.
- Unexpected failures in critical flows (sign-in, purchase, restore) SHOULD be recorded with
  `FirebaseCrashlytics.instance.recordError(e, st, reason: ...)`.

**Rationale**: verified in the app review: raw errors confused users and async `context` use
crashed screens.

### V. Session Lifecycle

- Sign-in and sign-out side effects (push registration, prayer reminders, RevenueCat identity,
  API cache, Firebase sign-out) MUST go only through `SessionController` /
  `signOutEverywhere()`. Screens MUST NOT set `ApiService().bearerToken` or perform these steps
  directly.

**Rationale**: the serialized queue prevents interleaved account switches leaking one user's
data or notifications to another.

### VI. Structure & Naming

- State SHOULD use `StatefulWidget` + `setState` and the existing singleton services. Adding a
  state-management package MUST be preceded by a constitution amendment.
- App-level, auth and deep-link routes MUST live in `lib/router.dart` (go_router).
  `Navigator.push` is acceptable for detail screens. `Navigator.pushNamed` MUST NOT be used
  (no route table exists; see fix 9a57316).
- Files SHOULD follow existing names: `*_screen.dart` (`XScreen` / `_XScreenState`),
  `*_service.dart`, widgets in `lib/widgets/` with plain names. When a screen grows large, its
  builders SHOULD move to a `part` file `*_widgets.dart` declaring a private extension on the
  State class.
- New UI code SHOULD use `lib/theme.dart` constants (`kPrimaryGold`, `kCharcoal`, ...) rather
  than new raw `Color(0x...)` literals.

**Rationale**: matches how the codebase is actually built (61 StatefulWidgets, zero Provider),
keeping reviews and refactors predictable.

### VII. Accessibility

- Every `IconButton` MUST have a `tooltip`; tap targets MUST be at least 48 px.
- Text MUST be at least 11 logical px; dim text MUST be no darker than `grey[500]` / `white60`
  on the dark background.
- Layouts MUST work at 1.5x text scale (the app clamps at 1.5) without overflow.

**Rationale**: these were app-review findings fixed in d8bd909; regressions are easy and silent.

### VIII. Testing & Quality Gates

- `flutter analyze --no-fatal-infos` and `flutter test` MUST pass before merge (CI also gates
  every release on them).
- Changes to services, parsers or models MUST include unit tests. API tests MUST use the
  existing pattern: `MockClient` via `api.httpClient` and `api.setAuthForTesting(...)`.
- Changes to auth or session code SHOULD run `integration_test/session_flows_test.dart` on a
  simulator against dev, followed by `flutter build ios --config-only`.

**Rationale**: the release pipeline ships straight to TestFlight and Play internal; tests are
the only automated safety net.

### IX. Dependencies & Platform

- iOS MUST build with Swift Package Manager; CocoaPods MUST NOT be reintroduced.
- The Flutter version is pinned in `.github/workflows/release.yml`; changing it MUST be its own
  commit.
- When an upper bound matters, a dependency MUST be pinned narrowly with a comment explaining
  why (e.g. `app_links`).
- Each new dependency MUST be justified in the feature's `plan.md`.

**Rationale**: build breakage from platform tooling has been the costliest class of incident
(see CI and iOS fix history).

### X. Logging

- New code SHOULD log with `dev.log` (with a `name:`) or `debugPrint`, not `print`.

**Rationale**: `print` is muted in release and noisy in analysis; named logs are filterable.

### XI. Versioning & Release

- Version changes MUST go through `/bump-version`, producing the commit
  `chore: bump version to X.Y.Z (build N)`. Build numbers MUST strictly increase.
- Releases MUST be tagged `vX.Y.Z` from `main`.

**Rationale**: both stores reject reused build numbers; tags are what CI builds.

### XII. Cross-Repo Contract

- A feature needing backend changes MUST name each endpoint in its spec and confirm it exists
  (or is specified) in `trooth_assessment_backend` before frontend implementation. The
  backend feature's `specs/NNN-name/contracts/` is the source of truth for the contract.
- Client behavior MUST follow backend status codes (e.g. 403 on a premium endpoint → upgrade
  sheet), not response-body wording.
- Released app versions cannot be force-updated; the frontend MUST NOT depend on a backend
  change that is not yet deployed to prod when it ships.

**Rationale**: two repos ship independently; drift between them caused shipped bugs (e.g.
e62119d).

## Technology Constraints & Known Debt

- Stack: Flutter (pinned in CI) / Dart, Firebase Auth + Firestore (onboarding only), FastAPI
  backend, RevenueCat, Firebase Messaging and Crashlytics, go_router.
- Principles apply to new or touched code. The following existing violations are grandfathered
  debt; touching the code SHOULD fix them, and no change may increase them:
  - ~67 `print(` calls in `lib/` (X)
  - ~27 bare `throw Exception(` in `lib/services/` (I)
  - raw `Color(0x...)` / `Colors.amber` literals and little use of `lib/ui/ui_constants.dart` (VI)
  - dashboard State classes of ~1,000 lines; duplicate premium report implementations (VI)

## Development Workflow

- Every change reaches `main` through a GitHub pull request; direct pushes and local merges to
  `main` are not allowed. Work happens on `feature/<kebab-name>`, `fix/<kebab-name>` or
  `chore/<kebab-name>` branches.
- Commits follow Conventional Commits: `type(scope): summary` with types `feat`, `fix`, `chore`,
  `refactor`, `perf`, `test`, `docs`, `build`, `ci`.
- Non-trivial features follow the Spec Kit flow: `/speckit-specify` → `/speckit-plan` →
  `/speckit-tasks` → `/speckit-implement` → `/speckit-converge`, with artifacts in
  `specs/NNN-name/`. Bug fixes and chores MAY skip specs.
- The PR description links its spec folder (if any) and states how it was verified.

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for the day-to-day details.

## Governance

- This constitution supersedes other guidance in the repo (CLAUDE.md, CONTRIBUTING.md,
  `.github/copilot-instructions.md`); those documents MUST be updated if they conflict with it.
- Amendments are made by pull request that edits this file, updates the Sync Impact Report, and
  updates any affected templates in `.specify/templates/overrides/` and CONTRIBUTING.md.
- Versioning follows semver: MAJOR for removing or redefining a principle, MINOR for adding a
  principle or materially expanding one, PATCH for wording and clarifications.
- Compliance is checked at two points: the Constitution Check gate in every `plan.md`, and PR
  review. Any deviation MUST be recorded in the plan's Complexity Tracking table with a
  justification, or the PR is not merged.

**Version**: 1.0.0 | **Ratified**: 2026-10-04 | **Last Amended**: 2026-10-04
