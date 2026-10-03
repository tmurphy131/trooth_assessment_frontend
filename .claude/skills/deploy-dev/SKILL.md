---
name: deploy-dev
description: Use when someone asks to deploy to dev, push to the dev environment, build and deploy the backend, or run the dev deployment pipeline.
disable-model-invocation: true
---

## What This Skill Does

Deploys the backend to the GCloud dev environment and prepares the Flutter frontend to point at the dev API. Runs four phases in order: build → deploy → frontend URL check → Flutter rebuild.

---

## Step 1 — Build the Backend Image

Run:

```
cd "/Users/tmoney/Developer/trooth_assessment_backend" && gcloud builds submit --tag gcr.io/trooth-prod/trooth-backend-dev:latest
```

If the command exits with a non-zero status, **pause and ask the user** what to do:
- Retry the build
- Skip the build and continue to the deploy step
- Abort the entire deployment

Do not proceed until the user decides.

---

## Step 1b — Run Database Migrations

The deploy does not migrate. Run the dev migration job (it uses the `trooth-backend-dev:latest` image just built) **before** deploying:

```
gcloud run jobs execute migrate-and-populate-dev --region us-east4 --wait
```

If the execution fails, **pause and ask the user** before deploying.

---

## Step 2 — Deploy to Cloud Run Dev

Run:

```
cd "/Users/tmoney/Developer/trooth_assessment_backend" && gcloud run deploy trooth-backend-dev \
  --image gcr.io/trooth-prod/trooth-backend-dev:latest \
  --region us-east4 \
  --platform managed \
  --service-account trooth-run-sa@trooth-prod.iam.gserviceaccount.com \
  --set-env-vars "^||^ENV=dev||RATE_LIMIT_ENABLED=true||MOCK_AI_SCORING=false||SHOW_DOCS=true||EMAIL_FROM_ADDRESS=admin@onlyblv.com||BACKEND_API_URL=https://trooth-discipleship-api-dev.onlyblv.com/||API_URL=https://trooth-discipleship-api.onlyblv.com/||IOS_APP_STORE_URL=https://apps.apple.com/app/t-root-h-discipleship/id6757311543||METRICS_REPORT_RECIPIENTS=admin@onlyblv.com,tay.murphy88@gmail.com" \
  --set-secrets "DATABASE_URL=DB_URL_DEV:latest,FIREBASE_CERT_JSON=FIREBASE_CERT_JSON:latest,SENDGRID_API_KEY=SENDGRID_API_KEY:latest,REVENUECAT_WEBHOOK_SECRET=REVENUECAT_WEBHOOK_SECRET:latest,REVENUECAT_SECRET_API_KEY=REVENUECAT_SECRET_API_KEY:latest,OPENAI_API_KEY=OPENAI_API_KEY:latest,CRON_SECRET=CRON_SECRET:latest" \
  --add-cloudsql-instances trooth-prod:us-east4:app-pg-dev \
  --allow-unauthenticated 2>&1 | tail -15
```

If the command exits with a non-zero status, **pause and ask the user** what to do:
- Retry the deploy
- Abort

Do not proceed until the user decides.

---

## Step 3 — Frontend API URL (no edit needed)

The frontend picks its backend at build time via `--dart-define=API_BASE_URL=...` (see `lib/services/api_service.dart`). It defaults to dev, so local `flutter run` already targets `https://trooth-discipleship-api-dev.onlyblv.com/`. Do not edit any source files.

Confirm the default is still dev:

```
grep -n "defaultValue" "/Users/tmoney/Developer/trooth_assessment/lib/services/api_service.dart"
```

If it shows any URL other than `https://trooth-discipleship-api-dev.onlyblv.com/`, report it to the user and stop.

---

## Step 4 — Check Disk Space and Clean DerivedData (if needed)

Run:

```
df -k / | awk 'NR==2 {print $4}'
```

This prints available disk space in kilobytes. If the result is less than **5242880** (5 GB), run:

```
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
```

Report whether cleanup was performed and how much space was freed (run `df -k /` again after to compare).

---

## Step 5 — Rebuild Flutter Environment

Run these commands **in sequence**, waiting for each to complete before starting the next:

```
cd "/Users/tmoney/Developer/trooth_assessment" && flutter clean && flutter pub get
```

Then:

```
cd "/Users/tmoney/Developer/trooth_assessment" && flutter build ios --config-only
```

iOS uses Swift Package Manager (no CocoaPods, no Podfile): this regenerates Flutter's iOS config and Swift package integration. Xcode fetches the packages on the next build.

If either command fails, report the error and stop.

---

## Final Report

After all steps complete, print a summary:

```
## deploy-dev complete

- [x] Backend image built
- [x] Migrations run (migrate-and-populate-dev)
- [x] Deployed to Cloud Run (trooth-backend-dev, us-east4)
- [x] Frontend API URL default confirmed → dev
- [x] DerivedData: [cleaned / skipped — X GB free]
- [x] flutter clean + pub get
- [x] iOS config regenerated (Swift Package Manager)
```

Replace any skipped or failed steps with `[ ]` and a short note.
