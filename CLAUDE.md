# T[root]H Discipleship — Flutter Frontend

Flutter app for the T[root]H spiritual mentorship platform. Paired with a FastAPI backend at `/Users/tmoney/Developer/trooth_assessment_backend`.

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

`ApiService` is a singleton (`ApiService()`). Set `bearerToken` after Firebase sign-in. Use `ApiService().baseUrl` when a screen needs the backend URL; `baseUrlOverride` exists only for e2e/staging overrides.

## Skills

| Skill | Trigger | What it does |
|-------|---------|--------------|
| `/deploy-dev` | "deploy to dev" | Builds backend image, deploys to Cloud Run dev, confirms frontend defaults to dev, rebuilds Flutter (flutter clean → pub get → iOS config) |
| `/deploy-prod` | "deploy to production", "release to prod" | Builds backend image, deploys to Cloud Run prod, rebuilds Flutter (flutter clean → pub get → iOS config) |
| `/bump-version <version>` | "bump version", "update version to X.Y.Z" | Updates pubspec.yaml and Info.plist, commits the change |
