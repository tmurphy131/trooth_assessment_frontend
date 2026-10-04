# T[root]H Discipleship — Flutter Frontend

Flutter app for the T[root]H spiritual mentorship platform. Paired with a FastAPI backend at `/Users/tmoney/Developer/trooth_assessment_backend`.

**Source of truth for rules: [.specify/memory/constitution.md](.specify/memory/constitution.md).** If anything here conflicts with it, the constitution wins. Contributor workflow: [CONTRIBUTING.md](CONTRIBUTING.md).

## Spec-Driven Workflow (GitHub Spec Kit)

Features are built spec-first. Artifacts live in `specs/NNN-feature-name/` (`spec.md`, `plan.md`, `research.md`, `contracts/`, `tasks.md`). Templates are customized in `.specify/templates/overrides/`; never edit the core templates in `.specify/templates/`.

| Step | Command | Use it when |
|------|---------|-------------|
| 0 | `/speckit-constitution` | Only to amend the constitution (via its own PR) |
| 1 | `/speckit-specify <what & why>` | Starting any new feature or user-visible change. No tech choices here |
| 1b | `/speckit-clarify` | The spec has `[NEEDS CLARIFICATION]` items or ambiguous behavior |
| 2 | `/speckit-plan <tech notes>` | Spec is settled; produces the plan with the Constitution Check gate |
| 2b | `/speckit-checklist` | Optional quality check on requirements before tasks |
| 3 | `/speckit-tasks` | Plan passes the Constitution Check |
| 3b | `/speckit-analyze` | Before implementing anything non-trivial; fix issues at the source artifact |
| 4 | `/speckit-implement` | Tasks are approved |
| 5 | `/speckit-converge` | After implementing; repeat implement → converge until "Converged" |

Small bug fixes, chores and version bumps may skip specs but still follow the constitution. Work on a `feature/`, `fix/` or `chore/` branch (Spec Kit does not create branches here), and don't commit until the user asks. If a feature needs backend changes, its contract is specified in the backend repo's `specs/` first (Principle XII).

## Project Layout

```
lib/
  main.dart                  # Entry point
  theme.dart
  screens/                   # All top-level screens (mentor, apprentice, trivia, assessments, etc.)
  features/assessments/      # Assessments feature (own screens, models, repo)
  services/
    api_service.dart         # HTTP singleton — all backend calls go through here
    push_notification_service.dart
    subscription_service.dart
  models/
  data/                      # Static data (weekly tips, etc.)
  widgets/
  ui/
  utils/
  mixins/
```

## Environments

| Env  | URL |
|------|-----|
| Dev  | `https://trooth-discipleship-api-dev.onlyblv.com/` |
| Prod | `https://trooth-discipleship-api.onlyblv.com/`     |

The backend URL is chosen at build time with `--dart-define=API_BASE_URL=<url>` (read in `lib/services/api_service.dart`). With no define it defaults to **dev**, so local `flutter run` never hits prod. Store builds come from the GitHub Actions release workflow (push a `v*` tag), which passes the prod URL. Don't hardcode URLs in source.

## API Service

`ApiService` is a singleton (`ApiService()`). Endpoints are `extension <Domain>Api on ApiService` part files in `lib/services/api/`. Auth tokens are handled by `_ApiClient` and `SessionController` — screens never set `bearerToken`. Use `ApiService().baseUrl` when a screen needs the backend URL; `baseUrlOverride` exists only for e2e/staging overrides.

## Skills

| Skill | Trigger | What it does |
|-------|---------|--------------|
| `/deploy-dev` | "deploy to dev" | Builds backend image, deploys to Cloud Run dev, confirms frontend defaults to dev, rebuilds Flutter (flutter clean → pub get → iOS config) |
| `/deploy-prod` | "deploy to production", "release to prod" | Builds backend image, deploys to Cloud Run prod, rebuilds Flutter (flutter clean → pub get → iOS config) |
| `/bump-version <version>` | "bump version", "update version to X.Y.Z" | Updates pubspec.yaml and Info.plist, commits the change |
| `/speckit-*` | see Spec-Driven Workflow | Spec Kit v1.1.0 workflow skills (`.claude/skills/speckit-*`) |
