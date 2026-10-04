# Contributing to T[root]H Discipleship (Flutter frontend)

The rules for how this app is built are in the
[constitution](.specify/memory/constitution.md). This guide covers the day-to-day workflow.
Where the two disagree, the constitution wins.

The backend lives in the sibling repo `trooth_assessment_backend` and has its own constitution
and CONTRIBUTING guide.

## 1. Spec-driven workflow

Features and user-visible changes start with a spec, made with
[GitHub Spec Kit](https://github.com/github/spec-kit) (v1.1.0). In Claude Code:

1. `/speckit-specify <what and why>`: creates `specs/NNN-name/spec.md`. Describe behavior,
   roles and premium gating, but not implementation.
2. `/speckit-clarify` (optional): resolves open questions in the spec.
3. `/speckit-plan <technical notes>`: writes `plan.md`. Its **Constitution Check** must pass,
   and any exception goes in the Complexity Tracking table.
4. `/speckit-tasks`, then `/speckit-analyze` for anything non-trivial.
5. `/speckit-implement`, then `/speckit-converge`. Repeat until it reports *Converged*.

You can skip the spec for bug fixes, chores, dependency bumps and version bumps. Those changes
still have to follow the constitution.

**Backend changes.** If a feature needs backend changes, specify the API contract in the backend
repo first (`specs/NNN-name/contracts/`). Link that contract from the frontend spec.

## 2. Branches

Branch from `main` using one of these prefixes, followed by a kebab-case name:

| Prefix | For |
|---|---|
| `feature/` | New features (`feature/prayer-journal`) |
| `fix/` | Bug fixes (`fix/mentor-submission-tap`) |
| `chore/` | Tooling, CI, docs, dependencies, version bumps (`chore/adopt-speckit`) |

Never commit directly to `main`. Spec folders are numbered separately (`specs/003-trivia-mode/`).
Spec Kit does not create branches in this repo.

## 3. Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`.

- **Types:** `feat`, `fix`, `chore`, `refactor`, `perf`, `test`, `docs`, `build`, `ci`.
- **Common scopes:** `api`, `ios`, `android`, `ci`, `a11y`, `nav`, `firestore`, `splash`.
- **Summary:** lowercase, no trailing period, and written as the user-visible effect.
  - Good: `fix: opening a submission from the mentor screens did nothing`
- **Body:** explain *why* and the root cause, not a list of changed files.
- **Version bumps:** run `/bump-version`, which writes `chore: bump version to X.Y.Z (build N)`.

## 4. Pull requests

Every change reaches `main` through a GitHub pull request.

- **Title:** in commit format.
- **Description:** link the spec folder if there is one. Then explain what changed and why, and
  how you verified it: tests, and the device or simulator you used against **dev**.
- **Before requesting review:** `flutter analyze --no-fatal-infos` and `flutter test` both pass.
- **Separate PRs:** constitution amendments and Flutter version changes each go in their own PR.

## 5. Testing and linting

| Check | Command | When |
|---|---|---|
| Static analysis | `flutter analyze --no-fatal-infos` | Every PR (CI gates releases on it) |
| Unit and widget tests | `flutter test` | Every PR (CI gates releases on it) |
| Device session test | `flutter test integration_test/session_flows_test.dart -d <simulator> --dart-define=TEST_MENTOR_EMAIL=… --dart-define=TEST_APPRENTICE_EMAIL=… --dart-define=TEST_PASSWORD=…` | Changes to auth or session code |
| Firestore rules | `firebase emulators:exec --only firestore --project demo-trooth "npm test --prefix test/firestore_rules"` | Any change to `firestore.rules` |

**Lint rules.** The lint set is `flutter_lints` (see `analysis_options.yaml`). Infos don't fail CI,
but don't add new `print` calls.

**API tests.** Fake HTTP with `MockClient` through `ApiService().httpClient`, and fake auth with
`setAuthForTesting(...)` (see `test/api_service_test.dart`).

**After running the integration test,** run `flutter build ios --config-only` before you build
from Xcode.

## 6. Code review standards

Reviewers check the PR against the constitution. In practice, that means:

- **API calls:** backend calls go through `ApiService` extensions and throw typed exceptions.
  Nothing calls `http` directly.
- **Errors:** user-facing errors use `friendlyError()`, and code checks `mounted` after every
  `await`.
- **Logging and secrets:** no tokens, bodies or personal data in logs, and no secrets or
  hardcoded backend URLs.
- **Access control:** the backend enforces it. Client checks only decide what UI to show.
- **Sign-in and sign-out:** handled only by `SessionController`.
- **Accessibility:** icon buttons have tooltips, tap targets are at least 48 px, text is at
  least 11 px, and layouts work at 1.5x text scale.
- **Tests:** service, parser and model changes come with tests.
- **New dependencies:** justified in the plan.

## 7. Releasing

1. Run `/bump-version X.Y.Z`. Build numbers must always increase.
2. Merge to `main` through a PR.
3. Run `git tag vX.Y.Z && git push origin vX.Y.Z`. GitHub Actions then tests the build and
   uploads it to TestFlight and the Play internal track.
4. Promote the build to production by hand in each store console.

See [docs/RELEASE_AUTOMATION.md](docs/RELEASE_AUTOMATION.md) for one-time setup.

## 8. Changing the constitution

1. Open a `chore/` branch and run `/speckit-constitution <the change and why>`. It updates
   `.specify/memory/constitution.md` and its Sync Impact Report.
2. Bump the version using the semver rules in the constitution's Governance section:
   - MAJOR: a principle is removed or redefined.
   - MINOR: a principle is added or expanded.
   - PATCH: wording only.
3. Update any affected templates in `.specify/templates/overrides/`, plus this guide and
   `CLAUDE.md`.
4. Open a PR that contains only the amendment. Remove the Sync Impact Report comment before
   merging.
5. Amendments that affect the API contract need a matching amendment in the backend repo.
