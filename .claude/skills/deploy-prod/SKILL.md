---
name: deploy-prod
description: Use when someone asks to deploy to production, push to prod, release to production, or run the production deployment pipeline.
disable-model-invocation: true
---

## What This Skill Does

Deploys the backend to the GCloud production environment and prepares the Flutter frontend to point at the prod API. Runs four phases in order: build → deploy → frontend URL fix → Flutter rebuild.

---

## Step 1 — Build the Backend Image

Run:

```
cd "/Users/tmoney/Developer/trooth_assessment_backend" && gcloud builds submit --tag gcr.io/trooth-prod/trooth-backend:latest
```

If the command exits with a non-zero status, **pause and ask the user** what to do:
- Retry the build
- Skip the build and continue to the deploy step
- Abort the entire deployment

Do not proceed until the user decides.

---

## Step 2 — Deploy to Cloud Run Production

Run:

```
cd "/Users/tmoney/Developer/trooth_assessment_backend" && gcloud run deploy trooth-backend \
  --image gcr.io/trooth-prod/trooth-backend:latest \
  --region us-east4 \
  --platform managed \
  --service-account trooth-run-sa@trooth-prod.iam.gserviceaccount.com \
  --set-env-vars "^||^ENV=production||SHOW_DOCS=true||EMAIL_FROM_ADDRESS=admin@onlyblv.com||BACKEND_API_URL=https://trooth-discipleship-api.onlyblv.com/||API_URL=https://trooth-discipleship-api.onlyblv.com/||IOS_APP_STORE_URL=https://apps.apple.com/app/t-root-h-discipleship/id6757311543||METRICS_REPORT_RECIPIENTS=admin@onlyblv.com,tay.murphy88@gmail.com" \
  --set-secrets "DATABASE_URL=DB_URL:latest,PRINTFUL_API_TOKEN=PRINTFUL_API_TOKEN:latest,FIREBASE_CERT_JSON=FIREBASE_CERT_JSON:latest,SENDGRID_API_KEY=SENDGRID_API_KEY:latest,REVENUECAT_WEBHOOK_SECRET=REVENUECAT_WEBHOOK_SECRET:latest,OPENAI_API_KEY=OPENAI_API_KEY:latest,CRON_SECRET=CRON_SECRET:latest" \
  --add-cloudsql-instances trooth-prod:us-east4:app-pg \
  --allow-unauthenticated 2>&1 | tail -15
```

If the command exits with a non-zero status, **pause and ask the user** what to do:
- Retry the deploy
- Abort

Do not proceed until the user decides.

---

## Step 3 — Verify and Fix Frontend API URLs

The prod API base URL must be: `https://trooth-discipleship-api.onlyblv.com/`

Check both files:

**File 1:** `lib/services/api_service.dart` line ~22
- Must read: `const String _devBaseUrl = 'https://trooth-discipleship-api.onlyblv.com/';`
- If it contains any other URL, replace that URL with the prod URL.

**File 2:** `lib/main.dart` line ~129
- Must read: `ApiService().baseUrlOverride = 'https://trooth-discipleship-api.onlyblv.com/';`
- If it contains any other URL on that line, replace it with the prod URL.

Use the Edit tool to make the replacements. Report what was changed (or confirm no change was needed).

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
cd "/Users/tmoney/Developer/trooth_assessment/ios" && rm -rf Pods Podfile.lock && pod install
```

If either command fails, report the error and stop.

---

## Final Report

After all steps complete, print a summary:

```
## deploy-prod complete

- [x] Backend image built
- [x] Deployed to Cloud Run (trooth-backend, us-east4)
- [x] Frontend API URLs verified → prod
- [x] DerivedData: [cleaned / skipped — X GB free]
- [x] flutter clean + pub get
- [x] pod install
```

Replace any skipped or failed steps with `[ ]` and a short note.
