# Release Automation — One-Time Setup

Goal: push a git tag like `v1.0.39` and GitHub Actions builds both apps, uploads iOS to **TestFlight** and Android to the **Play internal track**. You still promote to production (and submit for App Review) by hand in each store console.

Stack: **GitHub Actions + fastlane** (iOS signing via `fastlane match`, Android upload via `r0adkll/upload-google-play`).

Each step is tagged:

- 🧑 **Manual** — needs a browser login, Apple/Google console access, or a secret you shouldn't paste into a chat.
- 🤖 **Claude can do** — file/code changes in this repo; ask Claude to do it.

---

## Part 1 — Stop hand-editing API URLs 🤖

Today the prod/dev URL lives in two files (`lib/services/api_service.dart` ~line 22, `lib/main.dart` ~line 129). Replace with a build-time define:

```dart
// lib/services/api_service.dart
const String _devBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://trooth-discipleship-api-dev.onlyblv.com/',
);
```

…and delete the `baseUrlOverride` line in `main.dart`. Builds then choose the backend explicitly:

```bash
flutter build ipa       --release --dart-define=API_BASE_URL=https://trooth-discipleship-api.onlyblv.com/
flutter build appbundle --release --dart-define=API_BASE_URL=https://trooth-discipleship-api.onlyblv.com/
```

Local `flutter run` defaults to dev. Update the `/deploy-dev` and `/deploy-prod` skills to drop their "fix frontend URLs" step.

> RevenueCat keys in `subscription_service.dart` are public SDK keys — fine to leave hardcoded.

---

## Part 2 — iOS

### 2.1 App Store Connect API key 🧑

1. <https://appstoreconnect.apple.com> → **Users and Access → Integrations → App Store Connect API → Team Keys → +**
2. Name `GitHub Actions`, role **App Manager**.
3. Download the `.p8` (one-time download). Note the **Key ID** and **Issuer ID**.

(You already have a key in `~/.appstoreconnect/private_keys/` — you can reuse it if its role is App Manager or Admin.)

### 2.2 Private certificates repo 🧑

Create an **empty private** GitHub repo, e.g. `tmurphy131/trooth-certs`. `match` stores the encrypted distribution cert + provisioning profile there.

Create a GitHub **fine-grained personal access token** with *Contents: read* on that repo only. Then:

```bash
echo -n "tmurphy131:<TOKEN>" | base64   # → MATCH_GIT_BASIC_AUTHORIZATION
```

### 2.3 Install fastlane 🤖 (files) + 🧑 (run `match` once)

Claude can create these files:

`ios/Gemfile`
```ruby
source "https://rubygems.org"
gem "fastlane"
```

`ios/fastlane/Appfile`
```ruby
app_identifier("com.trooth.flutterTroothAssessment")
team_id("69DZGC7C98")
```

`ios/fastlane/Matchfile`
```ruby
git_url("https://github.com/tmurphy131/trooth-certs.git")
storage_mode("git")
type("appstore")
app_identifier(["com.trooth.flutterTroothAssessment"])
team_id("69DZGC7C98")
```

`ios/fastlane/Fastfile`
```ruby
default_platform(:ios)

platform :ios do
  lane :beta do
    setup_ci
    api_key = app_store_connect_api_key(
      key_id: ENV["ASC_KEY_ID"],
      issuer_id: ENV["ASC_ISSUER_ID"],
      key_content: ENV["ASC_KEY_P8"]
    )
    match(type: "appstore", readonly: true, api_key: api_key)
    # fastlane `sh` runs from ios/fastlane, so ../.. is the repo root
    sh("cd ../.. && flutter build ipa --release " \
       "--export-options-plist=ios/ExportOptions.plist " \
       "--dart-define=API_BASE_URL=#{ENV['API_BASE_URL']}")
    upload_to_testflight(
      api_key: api_key,
      ipa: Dir["../../build/ios/ipa/*.ipa"].first,
      skip_waiting_for_build_processing: true
    )
  end
end
```

`ios/ExportOptions.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>signingStyle</key><string>manual</string>
  <key>teamID</key><string>69DZGC7C98</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>com.trooth.flutterTroothAssessment</key>
    <string>match AppStore com.trooth.flutterTroothAssessment</string>
  </dict>
</dict>
</plist>
```

Then **you** run once (interactive — it asks for a passphrase that encrypts the certs repo; save it as `MATCH_PASSWORD`):

```bash
cd ios
bundle install
bundle exec fastlane match appstore
```

> If Apple says you've hit the distribution-certificate limit, revoke an unused one in the developer portal first. Revoking a cert does **not** affect apps already on the store.

### 2.4 Switch Release signing to manual 🧑 (or 🤖)

Xcode → Runner target → **Signing & Capabilities → Release**: uncheck *Automatically manage signing*, pick profile **match AppStore com.trooth.flutterTroothAssessment**. Keep Debug on automatic so local dev is unchanged.

(Claude can make the equivalent `project.pbxproj` edit, but doing it in Xcode is safer.)

### 2.5 Remove Xcode Cloud leftovers 🤖

Delete `ios/ci_scripts/` so there's only one pipeline. If an Xcode Cloud workflow exists in App Store Connect, disable it there 🧑.

---

## Part 3 — Android

### 3.1 Service account for Play uploads 🧑

1. Google Cloud console (project `trooth-prod` is fine) → **IAM & Admin → Service Accounts → Create**, name `play-publisher`. No GCP roles needed.
2. **Keys → Add key → JSON** → download.
3. Play Console → **Users and permissions → Invite new users** → paste the service account email → **App permissions**: T[root]H → grant *Release to testing tracks* (and *Release to production* if you later want CI to promote).

(Claude could run steps 1–2 with `gcloud`, but step 3 is web-only.)

### 3.2 Keystore secret 🧑

```bash
base64 -i android/upload-keystore.jks | pbcopy   # → ANDROID_KEYSTORE_BASE64
cat android/key.properties                        # → passwords + alias
```

`android/upload-keystore.jks` is your **upload key** — also back it up somewhere outside this laptop (password manager / secure storage). Losing it means a Play support ticket to reset.

---

## Part 4 — GitHub secrets 🧑

Frontend repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
|---|---|
| `ASC_KEY_ID` | App Store Connect Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |
| `ASC_KEY_P8` | full contents of the `.p8` file |
| `MATCH_PASSWORD` | passphrase from `fastlane match` |
| `MATCH_GIT_BASIC_AUTHORIZATION` | base64 `user:token` from 2.2 |
| `ANDROID_KEYSTORE_BASE64` | from 3.2 |
| `ANDROID_STORE_PASSWORD` | `storePassword` in `key.properties` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` in `key.properties` |
| `ANDROID_KEY_ALIAS` | `keyAlias` in `key.properties` |
| `PLAY_SERVICE_ACCOUNT_JSON` | full contents of the service-account JSON |

(With `brew install gh` you can do `gh secret set ASC_KEY_P8 < AuthKey_XXXX.p8` etc.)

---

## Part 5 — The workflow 🤖

`.github/workflows/release.yml`

```yaml
name: Release

on:
  push:
    tags: ['v*']

env:
  API_BASE_URL: https://trooth-discipleship-api.onlyblv.com/

jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - uses: subosito/flutter-action@v2
        with: { channel: stable, cache: true }
      - name: Write signing config
        run: |
          echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > android/upload-keystore.jks
          printf "storeFile=../upload-keystore.jks\nstorePassword=%s\nkeyPassword=%s\nkeyAlias=%s\n" \
            "${{ secrets.ANDROID_STORE_PASSWORD }}" \
            "${{ secrets.ANDROID_KEY_PASSWORD }}" \
            "${{ secrets.ANDROID_KEY_ALIAS }}" > android/key.properties
      - run: flutter build appbundle --release --dart-define=API_BASE_URL=$API_BASE_URL
      - uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
          packageName: com.trooth.flutterTroothAssessment
          releaseFiles: build/app/outputs/bundle/release/app-release.aab
          track: internal
          status: completed

  ios:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable, cache: true }
      - uses: ruby/setup-ruby@v1
        with: { ruby-version: '3.3', bundler-cache: true, working-directory: ios }
      - run: flutter pub get && cd ios && pod install
      - run: bundle exec fastlane beta
        working-directory: ios
        env:
          ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          ASC_KEY_P8: ${{ secrets.ASC_KEY_P8 }}
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_BASIC_AUTHORIZATION }}
```

Paths match `android/app/build.gradle.kts`: it reads `android/key.properties`, and `storeFile` resolves from `android/app/`, so `../upload-keystore.jks` → `android/upload-keystore.jks`. Note Gradle silently falls back to **debug** signing if `key.properties` is missing — Play will reject that upload, so a failed secret shows up there.

---

## Part 6 — Every release after setup

```bash
/bump-version 1.0.39            # Claude skill: pubspec + Info.plist, commits
git checkout main && git merge <release-branch> && git push
git tag v1.0.39 && git push origin v1.0.39
```

Then:

1. Watch the **Actions** tab (~15–25 min; iOS is the slow one).
2. **TestFlight**: build appears after Apple processing → add to a test group or submit for review.
3. **Play Console** → Internal testing → **Promote release** → Production.

Version numbers must strictly increase — if a tag fails after uploading to one store, bump before retrying.

---

## Part 7 — Backend follow-ups (optional, recommended)

The old backend `ci.yml` was removed (it was broken and its deploy config had drifted from prod). When rebuilding backend CI:

- Use the exact `--set-env-vars` / `--set-secrets` from the `/deploy-prod` skill — `--set-secrets` **replaces** the whole set, so any omission strips that secret from prod.
- Tag images with the commit SHA (`gcr.io/trooth-prod/trooth-backend:$SHA`) in addition to `:latest`. Rollback becomes `gcloud run services update-traffic trooth-backend --to-revisions=<rev>=100`.
- Before running migrations, point the job at the same image:
  `gcloud run jobs update migrate-and-populate --image gcr.io/trooth-prod/trooth-backend:$SHA --region us-east4`
  (the job was pinned to an August 2025 image, so it never saw new migrations).
- Auto-deploy a `develop` branch to `trooth-backend-dev`; deploy prod only from `main`.
