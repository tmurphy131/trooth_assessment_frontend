# T[root]H Discipleship: Flutter app

The iOS and Android app for **T[root]H Discipleship**, a spiritual mentorship platform. Mentors
guide apprentices through spiritual assessments, AI-generated growth reports, a shared prayer
journal and Bible trivia.

The backend is a FastAPI service in the sibling repo
[`trooth_assessment_backend`](https://github.com/tmurphy131/trooth_assessment_backend).

## What's in the app

- **Mentors and apprentices:** invitations, mentorship agreements, and dashboards for each role.
- **Assessments:** the Master T[root]H and Spiritual Gifts assessments, mentor-created templates,
  and AI scoring with full reports.
- **Prayer journal:** private entries, with optional sharing to a mentor.
- **Bible trivia:**
  - single player, graded and timed by the server;
  - head-to-head challenges (starting one is premium);
  - a daily question with streaks and rewards;
  - leaderboard competitions.
- **Premium:** RevenueCat subscriptions and mentor-gifted seats. The backend enforces premium;
  the app only decides what UI to show.
- **Push notifications:** Firebase Cloud Messaging.

## Tech stack

| Area | Choice |
|---|---|
| Framework | Flutter (version pinned in `.github/workflows/release.yml`, currently 3.47.5), Dart SDK ^3.8.1 |
| State | `setState` and singleton services; no state-management package |
| Navigation | `go_router` for app-level and deep-link routes (`lib/router.dart`) |
| Auth and push | Firebase Auth, Firebase Messaging |
| Payments | RevenueCat (`purchases_flutter`) |
| iOS dependencies | Swift Package Manager (CocoaPods is not used) |

## Project layout

```text
lib/
  main.dart, router.dart, theme.dart
  screens/               top-level screens (mentor, apprentice, trivia, assessments, …)
  features/assessments/  assessments feature (screens, models, repository)
  services/
    api_service.dart     HTTP singleton; every backend call goes through it
    api/<domain>.dart    endpoints as `extension <Domain>Api on ApiService`
    subscription_service.dart, push_notification_service.dart
  models/  widgets/  utils/  data/  ui/  mixins/
test/                    unit and widget tests
integration_test/        device tests (session flows, App Store capture)
specs/NNN-name/          Spec Kit feature specs, plans and tasks
store-assets/            App Store art and the tools that build it
```

## Getting started

1. **Install tools.** Use the Flutter version from `release.yml`, plus Xcode (iOS) and Android
   Studio (Android).
2. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```
3. **Run the app.** It points at the **dev** backend unless told otherwise:
   ```bash
   flutter run
   ```

Firebase client config (`firebase_options.dart`, `GoogleService-Info.plist`, `google-services.json`) is
committed, so no extra setup is needed.

### Environments

The backend URL is chosen at build time and is never hard-coded:

| Env | URL | How |
|---|---|---|
| Dev (default) | `https://trooth-discipleship-api-dev.onlyblv.com/` | `flutter run` |
| Prod | `https://trooth-discipleship-api.onlyblv.com/` | `--dart-define=API_BASE_URL=https://trooth-discipleship-api.onlyblv.com/` |

Store builds always come from the release workflow, which passes the prod URL.

## Testing

```bash
flutter analyze --no-fatal-infos
flutter test
```

Both must pass before merging, and CI gates releases on them. API tests fake HTTP with `MockClient`
through `ApiService().httpClient` (see `test/api_service_test.dart`).

After any `integration_test` run, use `flutter build ios --config-only` to reset the iOS build
config before building from Xcode.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR. In short:

- **Rules:** the [constitution](.specify/memory/constitution.md) is the source of truth.
- **Specs first:** features go through [GitHub Spec Kit](https://github.com/github/spec-kit),
  with artifacts in `specs/NNN-name/`. Bug fixes and chores can skip the spec.
- **Branches:** use `feature/`, `fix/` or `chore/` branches, Conventional Commits, and a PR to
  `main` for every change.
- **Backend changes:** specify the API contract in the backend repo first and link it from the
  frontend spec.

[CLAUDE.md](CLAUDE.md) covers the Claude Code skills used in this repo (`/deploy-dev`, `/deploy-prod`,
`/bump-version`, `/speckit-*`).

## Releasing

1. Run `/bump-version X.Y.Z`. The build number must always increase.
2. Merge to `main` through a PR.
3. Run `git tag vX.Y.Z && git push origin vX.Y.Z`. GitHub Actions tests the build and uploads it to
   TestFlight and the Play internal track.
4. Promote the build in each store console.

If a release depends on backend changes, they must be live in prod first. One-time CI setup is in
[docs/RELEASE_AUTOMATION.md](docs/RELEASE_AUTOMATION.md).

## App Store assets

`store-assets/` holds the product page header, search results art and custom product pages. The
real app screens are captured from the simulator with fictional demo data. See
[store-assets/README.md](store-assets/README.md) for upload steps and how to rebuild them.

## Other docs

| Doc | Topic |
|---|---|
| [APP_REVIEW.md](APP_REVIEW.md) | App Store review notes |
| [BETA_TESTING_GUIDE.md](BETA_TESTING_GUIDE.md) | TestFlight and beta testing |
| [REVENUECAT_SETUP_GUIDE.md](REVENUECAT_SETUP_GUIDE.md), [REVENUECAT_GOOGLE_PLAY_SETUP_GUIDE.md](REVENUECAT_GOOGLE_PLAY_SETUP_GUIDE.md) | Subscription setup |
| [APPLE_SIGNIN_FIX.md](APPLE_SIGNIN_FIX.md) | Sign in with Apple configuration |

Older planning docs at the repo root (`REQUIREMENTS.md`, `FREEMIUM_*.md`, `MENTOR_SECTION_REQUIREMENTS.md`,
`INVITE_SYSTEM_SUMMARY.md`) are historical background; current features are specified in `specs/`.
