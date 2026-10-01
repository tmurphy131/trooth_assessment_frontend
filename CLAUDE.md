# T[root]H Discipleship — Flutter Frontend

Flutter app for the T[root]H spiritual mentorship platform. Paired with a FastAPI backend at `/Users/tmoney/Developer/trooth_assessment_backend`.

## Project Layout

```
lib/
  main.dart                  # Entry point; sets API base URL override (~line 129)
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

The active URL is set in two places:
- `lib/services/api_service.dart` line ~22 — `_devBaseUrl` constant
- `lib/main.dart` line ~129 — `ApiService().baseUrlOverride`

Both must match the intended environment before building.

## API Service

`ApiService` is a singleton (`ApiService()`). Set `bearerToken` after Firebase sign-in. The `baseUrlOverride` field in `main.dart` controls which backend is targeted at runtime.

## Skills

| Skill | Trigger | What it does |
|-------|---------|--------------|
| `/deploy-dev` | "deploy to dev" | Builds backend image, deploys to Cloud Run dev, fixes frontend URLs to dev, rebuilds Flutter (flutter clean → pub get → pod install) |
| `/deploy-prod` | "deploy to production", "release to prod" | Builds backend image, deploys to Cloud Run prod, fixes frontend URLs to prod, rebuilds Flutter (flutter clean → pub get → pod install) |
| `/bump-version <version>` | "bump version", "update version to X.Y.Z" | Updates pubspec.yaml and Info.plist, commits the change |
