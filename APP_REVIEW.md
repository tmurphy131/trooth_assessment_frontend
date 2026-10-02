
# T[root]H Discipleship: App Review

Reviewed 2026-10-01 · branch `main` @ `092659f` · version 1.0.39+39 · read-only review

Every finding below cites files I opened. Where I'm inferring rather than reading the behavior directly, I mark it **(inferred)**. Some of the most serious problems live in the paired backend (`trooth_assessment_backend`), not in the Flutter code. I included them because the app's purchase and auth flows depend on them. Those findings are tagged **[backend]**.

---

## 0. Orientation

**What it is:** a discipleship and mentorship app. Mentors invite apprentices, apprentices take scripture and spiritual-gifts assessments, the backend scores them with an LLM, and mentors see reports, notes, agreements, weekly tips, guides and a trivia "challenge" game. Monetization is a freemium model through RevenueCat (mentor premium, apprentice premium, and gift seats that mentors buy for apprentices).

**Architecture:** Flutter app (Dart ≥3.8, built in CI with Flutter 3.47.5). Firebase Auth handles identity (email, Google, Apple). Firestore holds only the `users/{uid}.role` doc. Everything else goes through a FastAPI backend on Cloud Run (Postgres) via a 2,862-line singleton `ApiService` built on raw `package:http`. There is no state management library: state lives in StatefulWidget `setState` calls (406 of them) plus two singletons (`SubscriptionService` is a ChangeNotifier that no widget listens to; `PushNotificationService`). FCM and local notifications handle push, `app_links` handles deep links, and GitHub Actions plus fastlane ship releases.

**Things that seemed off while orienting:**
- "Built over a year ago" undersells it. The first commit is 2025-08-23, but there are active commits through 2026-10 (CI, iOS 15 target, SPM disabled). It's an actively maintained codebase with a long tail of experiments.
- **Two sources of truth for role:** Firestore `users/{uid}.role` (read by `AuthGate`) and the backend Postgres user. The app routes on the Firestore value.
- `provider` is a dependency but is imported **nowhere**.
- linux/windows/macos/web platform folders exist, but nothing suggests they're shipped.
- There are two generations of dashboards (`*_dashboard.dart` and `*_dashboard_new.dart`). Only the `_new` ones are reachable.

---

## 1. Outdated dependencies & APIs

From `flutter pub outdated` (current → latest):

| Package | Current | Latest | Breaking? |
|---|---|---|---|
| firebase_core / auth / messaging / cloud_firestore | 3.15 / 5.7 / 15.2 / 5.6 | 4.15 / 6.7 / 16.7 / 6.10 | Yes, a coordinated major bump. Must move together. |
| google_sign_in | 6.3.0 | 7.2.0 | **Yes, the API was rewritten.** `GoogleSignIn().signIn()` is gone, replaced by `GoogleSignIn.instance.initialize()` + `authenticate()`. On Android, 7.x uses Credential Manager. |
| flutter_local_notifications | 18.0.1 | 22.3.1 | Yes (4 majors; init and timezone API changes) |
| sign_in_with_apple | 6.1.4 | 8.2.0 | Yes (minor API) |
| share_plus | 10.1.4 | 13.3.1 | Yes (`Share.share` → `SharePlus.instance.share(ShareParams)`) |
| google_fonts | 6.3.3 (pinned exact) | 9.0.0 | Yes |
| app_links | 6.4.1 | 7.2.1 | Minor |
| intl | 0.19 | 0.20 | Minor |
| purchases_flutter | 10.4.2 | 10.14.0 | No (same major) |
| **flutter_markdown** | 0.7.7+1 | **discontinued** | Replaced by `flutter_markdown_plus` (drop-in rename) |

### 1.1 flutter_markdown is discontinued
- **Evidence:** `pubspec.yaml:42`, used in 4 files. pub.dev marks it `isDiscontinued: true, replacedBy: flutter_markdown_plus`.
- **Why it matters:** it will get no fixes for future Flutter SDK breakages, and it renders LLM report text, which is the core feature.
- **Severity / effort:** Medium / Small
- **Fix:** swap to `flutter_markdown_plus` and update the 4 imports.

### 1.2 Firebase and google_sign_in are a major version behind
- **Evidence:** `pubspec.yaml:36-39, 50, 55`
- **Why it matters:** Firebase iOS SDK updates are usually what bump the minimum iOS and Xcode versions, and staying behind compounds. On Android, google_sign_in 6.x uses the legacy Google Sign-In SDK, which Google has deprecated in favor of Credential Manager **(inferred from Google's deprecation notices; I didn't check a removal date)**.
- **Severity / effort:** High / Medium. Do it as one branch: Firebase bump, then the google_sign_in 7 rewrite of `simple_login_screen.dart:187-230`.
- **Fix:** bump all `firebase_*` packages together, rewrite the Google sign-in flow for 7.x, run on both platforms, then bump flutter_local_notifications.

### 1.3 Deprecated Flutter APIs (330 analyzer hits)
- **Evidence:** `flutter analyze` reports 330 `deprecated_member_use`, mostly `Color.withOpacity` (293 call sites). There is also `WillPopScope` at `lib/screens/trivia_game_screen.dart:279`.
- **Why it matters:** these get removed in future SDKs. `WillPopScope` doesn't work with Android predictive back, which is on by default for apps targeting SDK 36 **(inferred from Android 16 behavior changes)**. On Android, the "leave the game?" confirmation can be skipped.
- **Severity / effort:** Medium / Small. Running `dart fix --apply` handles most of these.
- **Fix:** run `dart fix --apply`, then convert `WillPopScope` → `PopScope(canPop: false, onPopInvokedWithResult: ...)` by hand.

### 1.4 Build-time tools listed as runtime dependencies
- **Evidence:** `pubspec.yaml:40-41` lists `flutter_launcher_icons` and `flutter_native_splash` under `dependencies`.
- **Why it matters:** `flutter_launcher_icons` (with the `image` package) has no place in the runtime dependency graph and increases resolution conflicts. `flutter_native_splash` *is* used at runtime (`preserve`/`remove`), so it stays.
- **Severity / effort:** Low / Small
- **Fix:** move `flutter_launcher_icons` to `dev_dependencies`.

### 1.5 Unused dependencies
- **Evidence:** zero imports in `lib/` for `provider`, `page_transition` and `crypto`.
- **Severity / effort:** Low / Small
- **Fix:** remove `provider` and `page_transition`. Keep `crypto` only if you implement the Apple nonce in 2.6.

---

## 2. Security

### 2.1 [backend] Any signed-in user can grant themselves premium (`/subscriptions/admin/set-tier`)
- **Evidence:** `trooth_assessment_backend/app/routes/subscriptions.py:240-288`. The route depends only on `get_current_user` and has no admin check. It sets the *caller's* tier, and `expires_days` is client-controlled with no upper bound. The client wrapper ships in the app at `lib/services/api_service.dart:2530`.
- **Why it matters:** this is a direct revenue bypass. One `curl` with any user's Firebase ID token gives that user premium for as long as they like.
- **Severity / effort:** **Critical / Small**
- **Fix:** delete the route, or gate it with `require_admin` and refuse it when `ENV == prod`. Also remove `debugSetSubscriptionTier` from `ApiService`.
- **Confidence:** I read the code on the backend checkout's `main` branch. I didn't verify that this is what's deployed to prod.

### 2.2 [backend] The server trusts client-reported purchases
- **Evidence:**
  - `subscriptions.py:154-226` (`/subscriptions/restore`): if the body says `is_active: true` with any `product_id`, the server writes the tier and an expiry date the client chose.
  - `subscriptions.py:434+` (`/mentor/seats/purchase`): it creates a gift seat from a client-supplied `subscription_id`.
  - The client side makes this worse: `lib/services/subscription_service.dart:131-135` (in `purchaseGiftSeat`) *invents* an ID (`productId_timestamp`) when no entitlement is found.
- **Why it matters:** premium and gift seats can be forged without paying. It's the same class of bug as 2.1.
- **Severity / effort:** **Critical / Medium**
- **Fix:** on the server, ignore client-supplied entitlement fields. On restore and confirm, call RevenueCat's REST API (`GET /v1/subscribers/{app_user_id}`) with the secret key and derive the tier and expiry from that. Treat RevenueCat webhooks as the source of truth. On the client, stop fabricating subscription IDs.

### 2.3 [backend] The free-tier apprentice limit is only enforced in the client
- **Evidence:**
  - `lib/screens/mentor_dashboard_new.dart:345-361` filters to the first apprentice when not premium.
  - `SubscriptionStatus.canAccessApprentice` lives in `subscription_service.dart`.
  - Backend `app/routes/mentor.py:191-215` checks only the mentor↔apprentice mapping, not premium status.
- **Why it matters:** a modified client, or anyone calling the API directly, gets premium data for free. **(Inferred:** other mentor endpoints may have the same gap. I checked only this one.)
- **Severity / effort:** High / Medium
- **Fix:** add a server-side check (premium, grandfathered, or first apprentice by `created_at`) in a shared dependency on every per-apprentice mentor route.

### 2.4 Bearer token and request bodies printed to the device log
- **Evidence:** `lib/services/api_service.dart:987, 1023, 1053` print the full `headers` map, including `Authorization: Bearer …`. Lines 96-104 (`_logRes`) `print` every response, plus full error bodies. There are 121 `avoid_print` hits overall.
- **Why it matters:** `print` still runs in release builds. On iOS it goes to the unified log, which you can read from a connected Mac. On Android it goes to logcat. A Firebase ID token is valid for an hour, and the response bodies contain PII (names, emails, assessment answers).
- **Severity / effort:** Medium / Small
- **Fix:** replace `print` with `debugPrint` behind `if (kDebugMode)` (or a tiny `log()` helper), never log headers, then enable `avoid_print` as an error in `analysis_options.yaml`.

### 2.5 The release ErrorWidget shows raw exceptions and stack traces to users
- **Evidence:** `lib/main.dart:42-73`. There are also 69 `Text(...$e...)` and 50 `_error = '...$e'` sites that put raw exception strings in the UI.
- **Why it matters:** it leaks internal URLs and response bodies (for example, `createUser failed (422) body=...`) and confuses users.
- **Severity / effort:** Medium / Medium
- **Fix:** keep the verbose widget under `kDebugMode`. In release, show a friendly message and send the error to Crashlytics (see 5.6). Map exceptions to user messages in one place.

### 2.6 Apple Sign-In without a nonce
- **Evidence:** `lib/screens/simple_login_screen.dart:233-250` calls `getAppleIDCredential` and builds the `OAuthProvider('apple.com').credential` with no `nonce`/`rawNonce`. `crypto` is a dependency but unused.
- **Why it matters:** Firebase's documented flow uses a SHA-256 nonce to stop replay of Apple identity tokens.
- **Severity / effort:** Low-Medium / Small
- **Fix:** generate `rawNonce`, pass `nonce: sha256(rawNonce)` to Apple and `rawNonce` to the credential. Or switch to `FirebaseAuth.instance.signInWithProvider(AppleAuthProvider())`.

### 2.7 Role comes from a client-writable Firestore doc
- **Evidence:** `lib/screens/auth_gate.dart:66-90` routes on `users/{uid}.role`, which the client itself writes (`signup_screen.dart:111`, `role_selection_screen.dart:73`). There are no `firestore.rules` in the repo.
- **Why it matters:** if the Firestore rules let a user rewrite their own `role`, they can switch between mentor and apprentice UIs. The backend still enforces `require_mentor`, so this is mostly a UX and integrity issue. **(Inferred:** I couldn't see the deployed rules.)
- **Severity / effort:** Low / Small
- **Fix:** take the role from the backend `/users/me` (or a custom claim), and lock `role` in Firestore rules to create-only.

### 2.8 Hardcoded RevenueCat keys, with a stale TODO
- **Evidence:** `lib/services/subscription_service.dart:216-220` says "TEMPORARY … TODO: Replace with String.fromEnvironment".
- **Why it matters:** RevenueCat `appl_`/`goog_` keys are *public* SDK keys by design, so this is **not a leak**. The real risk is that the misleading TODO and log line (`--dart-define=REVENUECAT_APPLE_KEY`) invite someone to "fix" it and ship an empty key.
- **Severity / effort:** Low / Small
- **Fix:** delete the TODO, and say in a comment that these are public keys.

### Checked and fine
- HTTPS everywhere. The base URL comes from `--dart-define` (`api_service.dart:25`).
- There is no cleartext traffic config.
- Firebase Auth keeps its tokens in Keychain/Keystore. `shared_preferences` holds only the FCM token and tutorial flags.
- Firebase `google-services.json`/`GoogleService-Info.plist` are committed, which is normal because they aren't secrets.
- `android/key.properties` and `upload-keystore.jks` exist locally and are **not** tracked in git.
- Certificate pinning isn't present. That's a reasonable choice for this app.

---

## 3. Performance

### 3.1 Startup blocks on a network ping with no timeout
- **Evidence:** `lib/main.dart:128-133` runs `await ApiService().ping()` before `runApp`, and the native splash is preserved until `AuthGate` resolves. `ping()` (`api_service.dart:111`) has no timeout.
- **Why it matters:** on a bad network or with the backend down, the user stares at the splash until the OS TCP timeout (tens of seconds), and the ping result isn't even used. Cloud Run cold starts add more delay.
- **Severity / effort:** High / Small
- **Fix:** delete the ping, or fire it without `await` after `runApp`.

### 3.2 N+1 sequential requests on the mentor dashboard
- **Evidence:** `lib/screens/mentor_dashboard_new.dart:363-367` awaits each apprentice's assessments one after another, `limit: 100` each.
- **Why it matters:** load time grows linearly with apprentice count (premium mentors have unlimited apprentices).
- **Severity / effort:** Medium / Small (client) or Medium (backend endpoint)
- **Fix:** use `Future.wait` over the apprentices right away. Better: add a backend endpoint that returns recent assessments for all of a mentor's apprentices in one call.

### 3.3 ~~The dashboard rebuilds on every frame of a tab animation~~ (retracted)
On closer reading this was wrong. `TabController` notifies listeners only when the index changes, not on every animation frame. The `setState` at `mentor_dashboard_new.dart:64-71` runs once or twice per tab switch, which is fine.

### 3.4 A FutureBuilder refetches on every rebuild
- **Evidence:** `lib/screens/apprentice_dashboard_new.dart:404` has `future: _apiService.getSpiritualGiftsLatest()` inline in `build`.
- **Why it matters:** every `setState` on the dashboard fires a new HTTP request and makes the card flicker.
- **Severity / effort:** Low / Small
- **Fix:** store the future in a field during `initState` and refresh it explicitly.

### 3.5 Polling continues in the background and can run forever
- **Evidence:**
  - `mentor_dashboard_new.dart:155-160` polls 2 endpoints every 60 s and never pauses when the app is in the background.
  - `lib/screens/apprentice_report_screen.dart:76-90` polls every 10 s with **no max attempts**: if scoring fails server-side, it polls until the user leaves, and errors are swallowed.
  - `trivia_challenge_detail_screen.dart:44` polls every 10 s.
- **Why it matters:** battery, data, and Cloud Run cost.
- **Severity / effort:** Medium / Small
- **Fix:** pause timers through a `WidgetsBindingObserver` (`AppLifecycleState.paused`), cap the report poll (for example, 30 tries, then show an error with a retry button), and rely on push for the "scoring done" notice.

### 3.6 No response caching, so every screen refetches
- **Evidence:** `ApiService` has no cache layer. Subscription status alone is fetched at sign-in (`main.dart:96`), again on the dashboard (`mentor_dashboard_new.dart:110`), and again on the paywall.
- **Severity / effort:** Low / Medium
- **Fix:** cache `SubscriptionStatus` in the existing singleton with a TTL, and have widgets listen to it (it's already a `ChangeNotifier`).

### 3.7 The paywall does heavy work every time it opens
- **Evidence:** `subscription_service.dart:314-390` (`getOfferings`) calls `syncPurchases()`, `invalidateCustomerInfoCache()` and `getCustomerInfo()` before `getOfferings()`, then retries up to 3× with 3 s sleeps.
- **Why it matters:** the paywall opens slowly. RevenueCat advises against routine `syncPurchases` calls **(inferred from RevenueCat docs; on iOS it can trigger StoreKit receipt work)**.
- **Severity / effort:** Medium / Small
- **Fix:** call just `Purchases.getOfferings()`. RevenueCat already caches offerings.

### 3.8 Google Fonts are probably fetched at runtime even though Poppins is bundled
- **Evidence:** `lib/theme.dart:24,33` use `GoogleFonts.poppins…`, while Poppins is declared under `fonts:` (`pubspec.yaml`), not `assets:`.
- **Why it matters:** `google_fonts` only uses bundled files it finds in *assets*. Otherwise it downloads from fonts.gstatic.com on first launch. That costs a network hit at startup, causes a font swap flash, and sends a third-party request you'd need to disclose. **(Inferred** from google_fonts' documented behavior; I didn't observe network traffic.)
- **Severity / effort:** Low / Small
- **Fix:** since the TTFs are already bundled, use `fontFamily: 'Poppins'` in the theme and drop `google_fonts`, or set `GoogleFonts.config.allowRuntimeFetching = false`.

### 3.9 Lists and assets
22 `ListView(` versus 35 builders. I didn't find any unbounded list built eagerly from API data at scale, so I'm not raising this as a finding. Assets total 848 KB, which is fine. `lib/data/mentor_guides_data.dart` (7,247 lines) and `apprentice_guides_data.dart` (4,459) compile content into the binary. That's acceptable, but it means a content edit needs a release (see 4.5).

---

## 4. Architecture & maintainability

### 4.1 God files
- **Evidence:**
  - `features/assessments/screens/mentor_submission_detail_screen.dart` (3,442 lines)
  - `services/api_service.dart` (2,862)
  - `screens/mentor_dashboard_new.dart` (2,080)
  - `screens/apprentice_report_screen.dart` (1,885)
  - `mentor_report_simplified_screen.dart` (1,850)
  - `template_management_screen.dart` (1,756)
- **Why it matters:** these are hard to change safely, can't be tested, and every `setState` rebuilds everything.
- **Severity / effort:** Medium / Large (do it incrementally)
- **Fix:** split `ApiService` by domain (`AuthApi`, `AssessmentsApi`, `SubscriptionsApi`, `TriviaApi`) behind one shared `_send()` (see 4.2). Pull each screen's tabs and cards into their own widgets.

### 4.2 159 hand-written HTTP calls with copy-pasted boilerplate
- **Evidence:** every method in `api_service.dart` repeats `_ensureFreshToken()` → `_logReq` → `http.X` → `_logRes` → a status check → `jsonDecode`.
- **Why it matters:** cross-cutting fixes (timeouts, retries, 401 refresh, error mapping) have to be made 159 times. That's why there are none today (see 5.1).
- **Severity / effort:** Medium / Medium
- **Fix:** add one `Future<T> _send<T>(method, path, {body, query, parse})` that owns token refresh, timeouts, one retry on 401 with a forced refresh, logging and typed exceptions. Migrate methods mechanically.

### 4.3 Dead code
- **Evidence:** these files are never imported:
  - `screens/apprentice_dashboard.dart` (1,188 lines)
  - `screens/mentor_dashboard.dart` (435)
  - `screens/onboarding_screen.dart`
  - `screens/apprentice_progress_screen.dart`
  - `screens/mentor_notes_screen.dart`
  - `screens/apprentice_mentor_overview.dart`
  - `screens/simple_splash_screen.dart`
  - `services/api_service_old.dart`
  - plus `splash_screen.dart`, referenced only in a comment

  The analyzer also flags 10 `unused_element` (for example, `_buildPremiumReportTab` at `mentor_submission_detail_screen.dart:666`), 6 `unused_field` and 7 `unused_import`. `main.dart:328-349` contains a `_RenderTestScreen` debug toggle.
- **Severity / effort:** Low / Small
- **Fix:** delete them.

### 4.4 Token, subscription and push setup are spread across three places
- **Evidence:**
  - The `authStateChanges` listener in `main.dart:87-125` sets the token and inits subscriptions and push (after a magic 500 ms delay).
  - `AuthGate` (`auth_gate.dart:53-62`) force-refreshes the token.
  - `MentorDashboardNew._initializeAndLoadData` (`mentor_dashboard_new.dart:80-84`) sets it again.
  - `ApiService._ensureFreshToken` also refreshes it.
- **Why it matters:** the order isn't guaranteed. `AuthGate` and the listener race on cold start, and the 500 ms delay papers over that.
- **Severity / effort:** Medium / Medium
- **Fix:** make `ApiService` pull the token from `FirebaseAuth.instance.currentUser!.getIdToken()` on each request (the SDK caches it), and delete `bearerToken` writes everywhere else. Put session setup and teardown in one `SessionController`.

### 4.5 Repo hygiene
- **Evidence:** these are tracked in git:
  - `ios_backup_before_regen_1756776404.tgz` (15 MB)
  - ~28 `.flutter-plugins-dependencies N` macOS-conflict duplicates
  - `ios/build_signing_log*.txt`
  - `ios/Flutter/flutter_export_environment 2.sh`

  Untracked clutter in the root includes a 17 MB `Build Runner_*.txt`, `flutter_0N.log`, `.dart_tool 2/` and 6 one-off `fix_*.sh` scripts. That's also 11 planning `.md` files at the root.
- **Severity / effort:** Low / Small
- **Fix:** `git rm --cached` the tracked junk (the `.gitignore` patterns already exist), and move the docs into `docs/`.

---

## 5. Error handling & reliability

### 5.1 No HTTP timeouts or retries anywhere
- **Evidence:** 159 `http.get/post/put/delete` calls in `api_service.dart` and **0** `.timeout(` calls.
- **Why it matters:** on flaky mobile networks a request can hang for a long time, leaving the spinner up with no error and no retry button. This is the root cause behind 3.1.
- **Severity / effort:** High / Small, once 4.2 exists (Medium without it)
- **Fix:** add `.timeout(const Duration(seconds: 20))` in the shared `_send`, map `TimeoutException`/`SocketException` to a typed `NetworkException` with a friendly message, and retry idempotent GETs once.

### 5.2 RevenueCat cancellation detection never matches
- **Evidence:** `subscription_service.dart:416` and `:604` check `if (e is PurchasesErrorCode)`. The SDK throws `PlatformException`, so this is never true.
- **Why it matters:** when a user cancels the purchase sheet, `_error = 'Purchase failed: PlatformException(...)'` gets set, and the UI shows a failure for a normal cancel.
- **Severity / effort:** Medium / Small
- **Fix:** catch `PlatformException` and use `PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError`.

### 5.3 RevenueCat identity breaks when users switch accounts
- **Evidence:** `SubscriptionService.clear()` (`:706-711`) resets `_isInitialized`. The next sign-in calls `Purchases.configure(... appUserID = newUid)` again (`:253`). `Purchases.logIn`/`logOut` are never used.
- **Why it matters:** RevenueCat expects `configure` exactly once per process. Re-configuring may keep the *previous* user's identity, so a purchase could be attributed to the wrong account, and your backend keys entitlements by Firebase UID. **(Inferred** from RevenueCat docs; I didn't reproduce it.)
- **Severity / effort:** High / Small
- **Fix:** call `configure` once (anonymous, or with the first UID). Call `Purchases.logIn(uid)` on sign-in and `Purchases.logOut()` on sign-out.

### 5.4 Account deletion skips push and RevenueCat cleanup
- **Evidence:** `mentor_profile_screen.dart:461-466` and `apprentice_profile_screen.dart:524-529` call `closeAccount` → `signOut` directly. They don't call `PushNotificationService().onLogout()`, which only `utils/logout_util.dart:28` calls. The FCM token stays registered, and `_isInitialized` stays `true`, so the next user on that device never registers a token.
- **Why it matters:** the next user on that device gets no notifications. Notifications could also reach the wrong person if the backend doesn't purge tokens on account close **(inferred)**.
- **Severity / effort:** Medium / Small
- **Fix:** route every sign-out through one `signOutEverywhere()` that unregisters push, calls `Purchases.logOut()`, clears subscription state, then calls `FirebaseAuth.signOut()`.

### 5.5 AuthGate sends signed-in users to Login when offline
- **Evidence:** `auth_gate.dart:66-70` reads Firestore. On any exception (`:97-108`) it shows `SimpleLoginScreen` even though Firebase still has a valid user. It's a one-shot check with no listener, so nothing recovers.
- **Why it matters:** a user who opens the app on the subway looks logged out, and signing in again fails too.
- **Severity / effort:** Medium / Small
- **Fix:** on error, show a "Can't connect" screen with a retry button. Cache the last known role in `shared_preferences` so the app can route offline. Firestore's offline cache helps only if the doc has been read before.

### 5.6 No crash reporting
- **Evidence:** `main.dart:37-40` and `:150-153` only dump errors to the console. There's no Crashlytics or Sentry dependency.
- **Why it matters:** you're blind to production crashes and to the many `catch (_) {}` sites that swallow errors silently.
- **Severity / effort:** Medium / Small
- **Fix:** add `firebase_crashlytics`, and wire it into `FlutterError.onError`, `PlatformDispatcher.instance.onError` and the zone handler.

### 5.7 BuildContext used across async gaps (42 sites)
- **Evidence:** the analyzer reports 42 `use_build_context_synchronously` hits, for example `utils/logout_util.dart:36` (navigates after `await signOut()` with no `mounted` check). Some `setState` calls in catch blocks have no `mounted` guard, for example `mentor_dashboard_new.dart:98-103`.
- **Why it matters:** "setState() called after dispose" and "looking up a deactivated widget's ancestor" crashes when users navigate away mid-request.
- **Severity / effort:** Medium / Small
- **Fix:** add `if (!context.mounted) return;` / `if (!mounted) return;` after each await the analyzer flags.

### 5.8 Notification taps that go nowhere
- **Evidence:** `main.dart:216-230`. `invitation_received` and `agreement_signed` are TODOs that only log. The `/mentor/submissions/:id/report` route (`main.dart:276-296`) shows a spinner forever if the fetch throws (`!snap.hasData` with no `hasError` branch).
- **Severity / effort:** Low-Medium / Small
- **Fix:** route these to the existing invites and agreements screens, and add an error branch to the FutureBuilder.

---

## 6. Testing

**What's covered:** effectively nothing.
- `test/onboarding_validation_test.dart` has 3 unit tests for `utils/onboarding_validation.dart`, and that file is used only by `onboarding_screen.dart`, which is dead code (see 4.3).
- `test/widget_test.dart` is the untouched Flutter counter template. It pumps `MyApp`, which needs Firebase, and expects a `'0'` counter, so **it would fail if run (inferred; I didn't run tests, to keep the review read-only).**
- CI (`.github/workflows/release.yml`) builds and uploads to the stores with no `flutter analyze` or `flutter test` step.

**Critical paths with no tests:** `SubscriptionStatus.fromJson` and the premium gating, `ApiService` error handling, deep-link and notification routing (`_handleIncomingUri`, `onGenerateRoute`, `_handleNotificationTap`), `AuthGate` routing, report parsing (`MentorReportV2`, `submission_models`), assessment draft save and submit, and the trivia timer logic.

### Three highest-value tests to add first
1. **`SubscriptionStatus.fromJson` + `canAccessApprentice` unit tests.** Cover the free, premium, grandfathered and gifted tiers, plus missing fields. These are pure functions that decide what paying versus free users see, and they cost nothing to test.
2. **Route-parsing tests for deep links and notifications.** Extract `_handleIncomingUri`, the `onGenerateRoute` matching and `_handleNotificationTap` into a pure `RouteResolver` that maps a URI or notification data to a route. Then table-test `trooth://assessment/draft/x`, `https://links.onlyblv.com/agreements/sign/a/b`, each notification `type`, and malformed input. These links come from emails and pushes, so they break silently.
3. **`ApiService` contract tests with `http.MockClient`.** Inject an `http.Client`, which is a small refactor. Assert that the 200/401/403/422/500 responses and timeouts become the right typed exceptions, and that `PremiumRequiredException` fires on the premium 403. This locks down the fixes from 5.1 and 4.2.

Also replace `widget_test.dart` and add `flutter analyze && flutter test` as the first job in `release.yml`.

---

## 7. UX & accessibility

### 7.1 Screen reader labels are sparse
- **Evidence:**
  - 28 `GestureDetector(` taps: these don't expose button semantics or focus.
  - 67 `IconButton`s with ~35 `tooltip`s.
  - Only 51 `Semantics`/`semanticLabel`/`tooltip` uses in ~57k lines.
  - Dashboard action cards are `GestureDetector`/`InkWell` on custom containers, for example `apprentice_dashboard_new.dart:398`.
- **Why it matters:** VoiceOver and TalkBack users hear unlabeled icons or nothing. Apple and Google both review for basic accessibility.
- **Severity / effort:** Medium / Medium
- **Fix:** give every `IconButton` a `tooltip`. Wrap custom tappables in `Semantics(button: true, label: …)` or use `InkWell` inside `Material` with a label. Audit with the Accessibility Inspector.

### 7.2 Small text, and Gold-on-white contrast is likely a problem
- **Evidence:** there are 131 `fontSize: 8–11` literals, and `theme.dart:5` uses Gold `#D4AF37`. Gold on white is about 2:1 contrast **(computed: it fails WCAG AA 4.5:1 for text)**. I didn't audit every place gold text lands on a light surface. There are also 195 uses of `Colors.grey[600-800]` or `white24/30/38`, which is a contrast risk on dark cards.
- **Severity / effort:** Medium / Medium
- **Fix:** set a minimum of 12 sp. Use gold for fills and icons, not body text on white. Add a darker `kGoldText` (about `#8A6D1F`) for text.

### 7.3 Text scaling hasn't been considered
- **Evidence:** there are no `textScaler` references. Fixed-height containers are common in the dashboard cards **(inferred from a skim, not measured)**.
- **Why it matters:** at 200% system font size, card text overflows or gets clipped.
- **Severity / effort:** Low-Medium / Medium
- **Fix:** test at the largest accessibility size, replace fixed heights with `ConstrainedBox(minHeight:)`, and if necessary clamp scaling globally with `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.6)`.

### 7.4 Keyboard and autofill handling
- **Evidence:** there are **0** `autofillHints` on the login and signup fields (`simple_login_screen.dart:~400-420`), and `textInputAction` is used sparsely. Tap-outside-to-dismiss is global (`main.dart:247`), which is good.
- **Why it matters:** password managers and iOS strong passwords won't offer to fill.
- **Severity / effort:** Low / Small
- **Fix:** add `autofillHints: [AutofillHints.email]`/`[AutofillHints.password]`, wrap the fields in an `AutofillGroup`, and set `textInputAction: next/done`.

### 7.5 Inconsistent navigation
- **Evidence:** a mix of named routes (`onGenerateRoute`) and ad-hoc `MaterialPageRoute`. Notification taps push onto whatever stack happens to exist. Logout pushes `SimpleLoginScreen` while `MyApp.home` is `AuthGate`. `main.dart:259-275` has a mentor route "guard" that never guards anything.
- **Severity / effort:** Low / Medium
- **Fix:** move to `go_router` with an auth redirect at some point. Meanwhile, delete the no-op guard to avoid false confidence.

---

## 8. Platform readiness

### 8.1 iOS universal links aren't set up, so https agreement links won't open the app
- **Evidence:** `ios/Runner/Runner.entitlements` has no `com.apple.developer.associated-domains` entry. Android declares `links.onlyblv.com` with `autoVerify` (`AndroidManifest.xml:30-41`), and `public/.well-known/` exists for hosting.
- **Why it matters:** on iOS, `https://links.onlyblv.com/agreements/sign/...` opens Safari instead of the app.
- **Severity / effort:** High (if those links are emailed) / Small
- **Fix:** add `applinks:links.onlyblv.com` to the entitlements and the App ID, and confirm the AASA file is served.

### 8.2 Android doesn't handle `trooth://assessment/draft/...` links
- **Evidence:** `AndroidManifest.xml:43-53`. The custom-scheme filter is `host="agreements"` only. iOS registers the whole `trooth` scheme (`Info.plist`), and `main.dart:160-166` handles `assessment/draft`.
- **Why it matters:** draft-reminder emails work on iOS but do nothing on Android.
- **Severity / effort:** Medium / Small
- **Fix:** add a second `<data android:scheme="trooth" android:host="assessment"/>`. Better: use https app links for both.

### 8.3 No PrivacyInfo.xcprivacy for the Runner target
- **Evidence:** there is no `ios/Runner/PrivacyInfo.xcprivacy`.
- **Why it matters:** third-party SDKs (Firebase, RevenueCat, shared_preferences) ship their own manifests, so App Store uploads currently pass. But Apple expects the *app's* manifest to declare its tracking status, collected data types and any required-reason APIs it uses directly. **(Inferred:** the uploads succeed today, so this is about completeness and accuracy, not a block.)
- **Severity / effort:** Low-Medium / Small
- **Fix:** add a Runner `PrivacyInfo.xcprivacy` with `NSPrivacyTracking=false` and the collected data types: email, name, user content (assessment answers), purchase history, device ID (FCM). Make sure it matches the App Store privacy label and the Play Data Safety form.

### 8.4 Missing the export compliance key
- **Evidence:** `ios/Runner/Info.plist` has no `ITSAppUsesNonExemptEncryption`.
- **Why it matters:** every TestFlight build waits on a manual export-compliance answer in App Store Connect, which undercuts the fastlane automation.
- **Severity / effort:** Low / Small
- **Fix:** add `<key>ITSAppUsesNonExemptEncryption</key><false/>`, since the app only uses HTTPS.

### 8.5 Notification permission is requested immediately after sign-in, without context
- **Evidence:** `push_notification_service.dart:66` calls `requestPermission()` inside `initialize()`, which runs automatically after auth (`main.dart:106-115`).
- **Why it matters:** a cold system prompt gets lower opt-in on both iOS and Android 13+, and you only get one ask on iOS.
- **Severity / effort:** Low / Small
- **Fix:** show a short in-app "why we notify" screen first, and request permission from that screen's button.

### 8.6 Android build settings
- **Evidence:** `android/app/build.gradle.kts`:
  - `targetSdk = 36` and `compileSdk = 36`: ✅ meets Play's 2026 requirement.
  - `minSdk = 24`: fine.
  - Release `isMinifyEnabled` is commented out (`:68-70`), so there's no R8 shrinking.
  - Release signing silently **falls back to debug** when `key.properties` is missing (`:60-66`).
- **Why it matters:** the AAB is bigger than it needs to be. A CI misconfiguration produces a debug-signed artifact, which Play would reject, but only after the build.
- **Severity / effort:** Low / Small
- **Fix:** fail the release build when signing is missing. Enable R8 with Flutter's default proguard rules, and test RevenueCat/Firebase with it on.

### 8.7 16 KB page size and edge-to-edge
- **Why it matters:** Play requires 16 KB page-size support for apps targeting Android 15+, and SDK 35+ enforces edge-to-edge. Flutter 3.47 handles both for the engine. **(Inferred:** native plugin `.so` files weren't checked, and screens without `SafeArea` may draw under the status bar or gesture bar.)
- **Severity / effort:** Low / Small to verify
- **Fix:** run Play Console's App Bundle Explorer 16 KB check, and visually check full-bleed screens on an Android 15 device.

### 8.8 Fine as is
- **iOS deployment target:** 15.0 (`Podfile:2`, pbxproj). It's consistent for Runner, though `RunnerTests` is 16.6, which is harmless.
- **Account deletion:** in-app (`closeAccount`), which satisfies App Store 5.1.1(v). For Play, also make sure a **web** deletion-request URL is listed in the Data Safety form **(inferred: I didn't find one in the app or `public/`)**.
- **Privacy and terms links** are present on signup and the paywall.
- `aps-environment` is `development` in the entitlements file. Xcode normally rewrites it to production on App Store export, so this is OK **(inferred)**.

---

## Top 10, ordered by impact vs effort

| # | Item | Ref | Severity | Effort |
|---|---|---|---|---|
| 1 | Remove or admin-gate `/subscriptions/admin/set-tier`, and drop `debugSetSubscriptionTier` from the app | 2.1 | Critical | S |
| 2 | Verify purchases server-side with the RevenueCat REST API; stop trusting the client in `/restore` and the seat confirm | 2.2 | Critical | M |
| 3 | Remove the blocking startup ping and add timeouts to all HTTP calls | 3.1, 5.1 | High | S |
| 4 | Use `Purchases.logIn/logOut` (configure once) and fix cancel detection | 5.3, 5.2 | High | S |
| 5 | Fix deep links: iOS associated domains plus the Android `trooth://assessment` filter | 8.1, 8.2 | High | S |
| 6 | Enforce the free-tier apprentice limit on the server | 2.3 | High | M |
| 7 | Stop printing tokens and bodies; gate logs on `kDebugMode`; friendly release error UI plus Crashlytics | 2.4, 2.5, 5.6 | Medium | S |
| 8 | Unify sign-out (push, RevenueCat, state) and handle AuthGate offline | 5.4, 5.5 | Medium | S |
| 9 | CI gate: replace the broken widget test, add the 3 tests above, run `analyze` + `test` before release | 6 | Medium | S |
| 10 | Bump Firebase + google_sign_in 7 + flutter_markdown_plus as one branch | 1.1, 1.2 | Medium-High | M |

## Quick wins (an afternoon)
- [ ] Delete the `await ApiService().ping()` at `main.dart:128-133`.
- [ ] `dart fix --apply` (this clears most of the 330 deprecations and the unused imports).
- [ ] `WillPopScope` → `PopScope` in `trivia_game_screen.dart:279`.
- [ ] Remove the `print('🔍 Headers…')` lines in `api_service.dart:975-1060`, and make `_logRes` debug-only.
- [ ] Fix the `PurchasesErrorCode` cancel checks (`subscription_service.dart:416, 604`).
- [ ] Remove `syncPurchases`/`invalidateCustomerInfoCache` from `getOfferings`.
- [ ] Cache the `getSpiritualGiftsLatest()` future (`apprentice_dashboard_new.dart:404`).
- [ ] Cap the report poll at N attempts (`apprentice_report_screen.dart:76`).
- [ ] Call `PushNotificationService().onLogout()` in both `_executeCloseAccount` methods.
- [ ] Add `ITSAppUsesNonExemptEncryption=false` to `Info.plist`.
- [ ] Add the Android `trooth://assessment` intent filter.
- [ ] Remove the `provider` and `page_transition` deps; move `flutter_launcher_icons` to dev deps; swap to `flutter_markdown_plus`.
- [ ] Delete the 8 unreferenced Dart files, plus `git rm --cached` the 15 MB tgz and the duplicate `.flutter-plugins-dependencies N` files.
- [ ] Add `autofillHints` to the login and signup fields.


---

## Status: fixes on `fix/app-review` (app) and `fix/subscription-security` (backend)

**New bug found while fixing (not in the original review):** `trooth://agreements/sign/{type}/{token}` links never opened the signing screen. In a custom-scheme URI, `agreements` parses as the host, so `pathSegments` had 3 entries and the length-4 check never matched. The new parser (`lib/utils/deep_links.dart`) handles both the custom-scheme and https forms, and a test covers it.

| Ref | Status |
|---|---|
| 2.1 set-tier open to all users | **Fixed (backend):** admin-only and refused when `ENV=production`. The app's `debugSetSubscriptionTier` is removed. |
| 2.2 server trusts client purchases | **Fixed and verified on dev (backend):** `/subscriptions/restore` and the gift-seat confirm ignore entitlement fields from the client and look the user up at RevenueCat (`GET /v1/subscribers/{user.id}`) with a secret API key (Secret Manager `REVENUECAT_SECRET_API_KEY`). A seat is only created when RevenueCat shows more gift-seat purchases than the mentor has seats. On dev, RevenueCat answers the lookup and forged claims are rejected. The app no longer fabricates gift-seat IDs. |
| 2.3 free-tier limit client-only | **Fixed (backend):** enforced on the draft and submitted-assessments routes. `/mentor/my-apprentices` is now ordered oldest-first, so "first apprentice" means the same thing on client and server. The `limit` query param is capped at 200. |
| 2.4 tokens and bodies in device logs | **Fixed:** the header prints are deleted, and every `print`/`debugPrint` is muted in release through the root zone. |
| 2.5 raw errors in release | **Fixed:** the release crash screen is friendly, and 129 user-facing messages go through `friendlyError()` (`lib/utils/errors.dart`). Release builds show a plain message; debug builds keep the detail. |
| 2.6 Apple nonce | **Fixed** |
| 3.1 / 5.1 blocking ping, no timeouts | **Fixed:** the ping is removed, and every request has a 20 s timeout and maps failures to `NetworkException`. |
| 3.2 N+1 dashboard fetch | **Fixed** (`Future.wait`) |
| 3.4 FutureBuilder refetch | **Fixed** |
| 3.5 polling | **Fixed:** the report poll is capped at about 5 minutes, and dashboard polling pauses in the background. |
| 3.7 heavy paywall | **Fixed** |
| 4.3 dead code | **Fixed:** 10 unreferenced files, 27 unused methods, and the unused fields and fetches are removed. |
| 4.5 tracked repo junk | **Fixed:** 28 tracked files removed (backup tgz, numbered duplicates, signing logs), with ignore rules added. Untracked local logs in the project root were left in place. |
| 5.2 / 5.3 RevenueCat cancel + identity | **Fixed:** `configure` runs once, then `logIn`/`logOut`; cancellation is detected with `PurchasesErrorHelper`. |
| 5.4 account deletion cleanup | **Fixed:** `signOutEverywhere()` in `utils/logout_util.dart`. |
| 5.5 AuthGate offline | **Fixed:** cached role per user, plus a retry screen. |
| 5.7 BuildContext across async gaps | **Fixed:** all 42 sites. |
| 5.8 dead notification taps / stuck report | **Fixed** |
| 1.1, 1.3, 1.4, 1.5 deps and deprecations | **Fixed:** `flutter_markdown_plus`, `PopScope`, `dart fix`, unused deps removed. 12 Radio `groupValue` deprecations remain (non-breaking). |
| 6 tests and CI | **Fixed:** 29 unit tests across 3 new files plus a device integration test; the release workflow is gated on `analyze` + `test`. |
| 7.4 autofill | **Fixed** |
| 8.1 / 8.2 / 8.4 links and export compliance | **Fixed:** see the iOS signing note below. |
| 1.2 Firebase and google_sign_in majors | **Fixed:** firebase_core 4.15, auth 6.7, firestore 6.10, messaging 16.7 (iOS SDK 12.19), google_sign_in 7.2 (Credential Manager on Android, web client as `serverClientId`), flutter_local_notifications 22.3. Device-tested on iOS against dev. **Note:** Firebase stops publishing CocoaPods after October 2026, so the iOS build needs to move to Swift Package Manager (currently disabled in `pubspec.yaml`). |
| 2.7 Firestore role rules | **Open:** the rules aren't in the repo; check that `users/{uid}.role` is create-only. |
| 2.8 hardcoded RevenueCat keys | **Fixed:** misleading TODO replaced with a note that these are public SDK keys. |
| 3.6 response caching | **Open (low).** |
| 3.8 Google Fonts runtime fetch | **Fixed:** `google_fonts` removed. Poppins is fully bundled (Medium and SemiBold added from google/fonts, OFL), so there are no runtime font downloads. |
| 4.2 HTTP boilerplate | **Partly fixed:** one wrapper for timeouts and network errors. The full `_send()` (401 refresh, typed errors) is still open. |
| 5.6 crash reporting | **Fixed:** Firebase Crashlytics records Flutter, platform and zone errors in release builds. iOS dSYM upload isn't configured, so native iOS crashes won't be symbolicated (Dart traces are). |
| 8.6 Android build settings | **Fixed:** release builds fail without `key.properties` instead of silently debug-signing. R8 shrinking is on. Verified on a release build (Pixel 8 emulator, Android 16) against dev: sign-in, Firestore role, API calls, subscription status and FCM device registration all work. |
| 8.7 16 KB pages | **Verified:** every 64-bit `.so` is zip-aligned and has LOAD segments of 2^14 or larger. |
| Splash screens (new) | **Fixed:** iOS lost the logo (black screen) before the first frame because `AppDelegate` builds `FlutterViewController(engine:)`, which doesn't show the launch screen; it now calls `loadDefaultSplashScreenView()`. Android 12+ squeezed the wide wordmark into its circular icon; it now uses a square icon with the logo inside the safe circle. Both platforms measure 150 units wide, and the Flutter loading screen matches. |
| Tutorial overlay over deep links (new) | **Fixed:** the tutorial is dismissed before link and notification navigation, and isn't shown if its screen is no longer on top. |
| 4.1, 4.4, 7.1-7.3, 7.5, 8.3, 8.5 | **Deferred:** larger efforts, unchanged. |

**Release note:** Associated Domains is already enabled on the App ID. If the match provisioning profiles predate that, regenerate them before the next tag so they include the `applinks:links.onlyblv.com` entitlement.

### Verified on dev (2026-10-02)

Three linked test accounts (a free mentor and two apprentices) on the dev backend, revision `trooth-backend-dev-00071-9rx`:

- **API, as real users:** a free mentor gets 200 for apprentice 1 and 403 for apprentice 2 (assessments and draft). A mentor calling set-tier gets 403. A restore with a forged premium claim stays free. A seat confirm with a made-up ID gets 409.
- **Verified purchase path:** after a one-day promotional `premium` entitlement was granted in RevenueCat, restore (sending no client claims) made the mentor premium, and apprentice 2 became visible (200). The grant was then revoked.
- **iOS simulator** (`integration_test/session_flows_test.dart`): sign-in through the UI. RevenueCat identity follows when switching from the mentor to the apprentice. An offline launch with an empty Firestore cache opens the dashboard from the cached role. With no cached role either, the retry screen appears, and "Try again" recovers.
- **Android emulator:** `trooth://agreements/sign/...` opens the signing screen. `trooth://assessment/draft/<id>` opens the real draft.

**Bugs found during device testing (fixed):**
- Emails were not URL-encoded in `/invitations/apprentice-invites?email=`, so any user with a `+` in their address got a 403 and never saw invites.
- The role was only cached at app start, not on sign-in or signup, so a user who signed in and then relaunched offline could get the retry screen.
- Flutter's built-in deep linking handled links a second time alongside app_links and logged route errors. It's now disabled on both platforms.

**Found, not fixed:** on a first sign-in, the dashboard's "Welcome!" tutorial overlay stays on top of a screen opened by a deep link.

**Not verifiable here:** iOS shows a system "Open in app?" prompt for externally opened links, which I can't tap on the simulator, so iOS link routing is covered by unit tests only. The cancel-purchase sheet needs a person to tap it.
