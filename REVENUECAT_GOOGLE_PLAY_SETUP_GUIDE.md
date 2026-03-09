# RevenueCat + Google Play Integration Guide for T[root]H Discipleship

This guide walks through the complete setup of RevenueCat for in-app subscriptions on Android, from Google Play Console configuration to testing on a real device.

---

## Prerequisites

- Google Play Developer Account ($25 one-time fee, https://play.google.com/console)
- RevenueCat account (https://app.revenuecat.com)
- T[root]H Discipleship app already created in Google Play Console
- Physical Android device or emulator for testing
- The iOS RevenueCat project already exists (we'll add Android to the same project)

---

## Part 1: Google Play Console Configuration

### Step 1.1: Navigate to Your App

1. Go to [Google Play Console](https://play.google.com/console)
2. Select **T[root]H Discipleship** from your app list
3. If the app doesn't exist yet, click **Create app** and fill in the required details

### Step 1.2: Upload an Initial Build (Required Before Creating Subscriptions)

> ⚠️ **Google Play requires at least one APK/AAB uploaded before you can create in-app products.** You must complete this step first.

1. In the left sidebar, go to **Release** → **Production** (or **Internal testing** for faster setup)
2. Click **Create new release**
3. Upload your AAB file:
   ```bash
   cd "/Users/tmoney/Documents/ONLY BLV/trooth_assessment"
   flutter build appbundle --release
   ```
   The AAB will be at `build/app/outputs/bundle/release/app-release.aab`
4. Upload the AAB, add release notes, and **Save** (you can roll out later)

> 💡 **Tip**: Use **Internal testing** track first — it's approved instantly and doesn't require a full store listing.

### Step 1.3: Create Subscription Products

1. In the left sidebar, go to **Monetize** → **Products** → **Subscriptions**
2. Click **Create subscription**

#### Subscription 1: Mentor Premium Monthly

1. Enter:
   - **Product ID**: `mentor_premium_monthly` ⚠️ EXACT — this ID is used in code and must match RevenueCat
   - **Name**: `    `
2. Click **Create**
3. You'll be taken to the subscription detail page. Add a **base plan**:
   - Click **Add base plan**
   - **Base plan ID**: `mentor-premium-monthly-base`
   - **Auto-renewing**: Yes
   - **Billing period**: 1 Month
   - **Price**: Click **Set price** → $4.99 USD → **Update** → Apply to all countries or select individually
   - Click **Activate** on the base plan
4. Click **Save**

#### Subscription 2: Mentor Premium Annual

1. Create new subscription:
   - **Product ID**: `mentor_premium_annual`
   - **Name**: `Mentor Premium Annual`
2. Add base plan:
   - **Base plan ID**: `mentor-premium-annual-base`
   - **Billing period**: 1 Year
   - **Price**: $49.99 USD
   - **Activate** the base plan
3. Click **Save**

#### Subscription 3: Apprentice Premium Monthly

1. Create new subscription:
   - **Product ID**: `apprentice_premium_monthly`
   - **Name**: `Apprentice Premium Monthly`
2. Add base plan:
   - **Base plan ID**: `apprentice-premium-monthly-base`
   - **Billing period**: 1 Month
   - **Price**: $4.99 USD
   - **Activate** the base plan
3. Click **Save**

#### Subscription 4: Apprentice Premium Annual

1. Create new subscription:
   - **Product ID**: `apprentice_premium_annual`
   - **Name**: `Apprentice Premium Annual`
2. Add base plan:
   - **Base plan ID**: `apprentice-premium-annual-base`
   - **Billing period**: 1 Year
   - **Price**: $49.99 USD
   - **Activate** the base plan
3. Click **Save**

#### Subscription 5: Mentor Gift Seat

1. Create new subscription:
   - **Product ID**: `mentor_gift_seat_monthly`
   - **Name**: `Gift Seat for Apprentice`
2. Add base plan:
   - **Base plan ID**: `mentor-gift-seat-monthly-base`
   - **Billing period**: 1 Month
   - **Price**: $2.99 USD
   - **Activate** the base plan
3. Click **Save**

### Step 1.4: Verify Subscription Status

1. Go back to **Monetize** → **Products** → **Subscriptions**
2. All 5 subscriptions should show status **Active** ✅
3. Each must have at least one **active base plan**

> ⚠️ **Important**: If a subscription shows "Inactive" or "Draft", it won't be available for purchase. Make sure each base plan is activated.

### Step 1.5: Set Up Google Play Billing Permissions (Service Account)

RevenueCat needs a service account to validate purchases with Google Play. This is the most important (and most error-prone) step.

#### Create a Google Cloud Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select the project linked to your Google Play Console (or create a new one)
3. Navigate to **IAM & Admin** → **Service Accounts**
4. Click **+ Create Service Account**
5. Enter:
   - **Name**: `revenuecat-service-account`
   - **Description**: `Service account for RevenueCat subscription validation`
6. Click **Create and Continue**
7. Skip the role assignment (we'll grant access in Google Play Console instead)
8. Click **Done**

#### Generate a JSON Key

1. Click on the service account you just created
2. Go to the **Keys** tab
3. Click **Add Key** → **Create new key**
4. Select **JSON** format
5. Click **Create**
6. **Save the downloaded JSON file** — you'll upload this to RevenueCat

> ⚠️ **Keep this file secure!** It contains credentials that can access your billing data.

#### Grant Access in Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Click **Users and permissions** (left sidebar, under Settings)
3. Click **Invite new users**
4. Enter the **service account email** (looks like `revenuecat-service-account@your-project.iam.gserviceaccount.com`)
5. Under **App permissions**:
   - Click **Add app** → select **T[root]H Discipleship**
   - Enable these permissions:
     - ✅ **View financial data, orders, and cancellation survey responses**
     - ✅ **Manage orders and subscriptions**
6. Under **Account permissions**:
   - ✅ **View financial data, orders, and cancellation survey responses** (account level)
7. Click **Invite user**
8. Click **Send invite**

> ⚠️ **It can take up to 24 hours for Google to propagate service account permissions.** If RevenueCat shows errors validating, wait and try again.

### Step 1.6: Set Up License Testers

License testers can make test purchases without being charged.

1. In Google Play Console, go to **Settings** → **License testing** (left sidebar, under Developer account)
2. Under **Gmail accounts with testing access**, add your test email addresses (comma-separated)
3. Set **License test response** to **RESPOND_NORMALLY**
4. Click **Save changes**

> 📝 **Important**: The email must match the Google account signed into the Android device. Unlike iOS sandbox, Android uses your real Google account for test purchases.

---

## Part 2: RevenueCat Configuration

### Step 2.1: Open Your Existing RevenueCat Project

1. Go to [RevenueCat Dashboard](https://app.revenuecat.com)
2. Open the **T[root]H Discipleship** project (same one used for iOS)

### Step 2.2: Add Android App

1. Click **Apps & providers** in the left sidebar
2. Click **+ New** button
3. Select **Google Play Store (Android)**
4. Configure the app:

   **Basic Info:**
   - **App name**: `T[root]H Discipleship (Android)`
   - **Package name**: `com.trooth.flutterTroothAssessment` ⚠️ MUST MATCH your `applicationId` in `build.gradle.kts`

   **Service Account Credentials:**
   - Upload the **JSON key file** from Step 1.5
   - Click **Save**
   - RevenueCat will validate the credentials — you should see **"Valid credentials"** ✅

   > If validation fails, the service account permissions haven't propagated yet. Wait a few hours and retry.

5. Click **Save**

### Step 2.3: Add Google Play Products to RevenueCat

Since you already have the products from the iOS setup, you need to add the Google Play versions:

1. Go to **Product catalog → Products**
2. Click **+ New** for each product:

   **Product 1:**
   - **Identifier**: `mentor_premium_monthly` (must match Google Play Product ID)
   - **Store**: Google Play Store
   - **App**: T[root]H Discipleship (Android)
   - Click **Add**

   **Product 2:**
   - **Identifier**: `mentor_premium_annual`
   - **Store**: Google Play Store
   - **App**: T[root]H Discipleship (Android)

   **Product 3:**
   - **Identifier**: `apprentice_premium_monthly`
   - **Store**: Google Play Store
   - **App**: T[root]H Discipleship (Android)

   **Product 4:**
   - **Identifier**: `apprentice_premium_annual`
   - **Store**: Google Play Store
   - **App**: T[root]H Discipleship (Android)

   **Product 5:**
   - **Identifier**: `mentor_gift_seat_monthly`
   - **Store**: Google Play Store
   - **App**: T[root]H Discipleship (Android)

3. Verify all 5 Google Play products appear alongside the existing iOS ones

> 💡 **Alternative**: Click **Import Products** to automatically pull products from Google Play (requires valid service account credentials).

### Step 2.4: Attach Google Play Products to Existing Entitlement

1. Go to **Product catalog → Entitlements**
2. Click on the `premium` entitlement (already exists from iOS setup)
3. Click **Attach** or **+ Add Products**
4. Select all 5 **Google Play Store** products
5. Save

Now purchasing on *either* iOS or Android grants the same `premium` entitlement.

### Step 2.5: Add Google Play Products to Existing Offering Packages

1. Go to **Product catalog → Offerings**
2. Click on the **default** offering
3. For each existing package, add the Google Play product:

   **Package: $rc_monthly (Mentor Monthly)**
   - Click on the package
   - Under products, click **+ Add** for "T[root]H Discipleship (Android)"
   - Select `mentor_premium_monthly`
   - Save

   **Package: $rc_annual (Mentor Annual)**
   - Add `mentor_premium_annual` for the Android app

   **Package: apprentice_monthly**
   - Add `apprentice_premium_monthly` for the Android app

   **Package: apprentice_annual**
   - Add `apprentice_premium_annual` for the Android app

   **Package: gift_seat**
   - Add `mentor_gift_seat_monthly` for the Android app

4. Each package should now show products for **both** iOS and Android

### Step 2.6: Get Google API Key

1. Click **Apps & providers** in the left sidebar
2. Click on your **Android app** (T[root]H Discipleship (Android))
3. Find the **Public app-specific API key** — it starts with `goog_`
4. **Copy this key**

Example: `goog_AbCdEfGhIjKlMnOpQrStUvWxYz`

---

## Part 3: Flutter App Configuration

### Step 3.1: Update Google API Key in Code

Open `lib/services/subscription_service.dart` and update the Google API key.

**Current code (around line 220-222):**
```dart
static const String _revenueCatGoogleApiKey = String.fromEnvironment(
  'REVENUECAT_GOOGLE_KEY',
  defaultValue: '',
);
```

**Option A — Hardcode for testing (like iOS key):**
```dart
static const String _revenueCatGoogleApiKey = 'goog_YOUR_API_KEY_HERE';
```

**Option B — Keep environment variable and pass at build time:**
```bash
flutter build appbundle --release --dart-define=REVENUECAT_GOOGLE_KEY=goog_YOUR_API_KEY_HERE
```

> 💡 **Recommendation**: Use Option A for initial testing, then switch to Option B (environment variable) for production builds.

### Step 3.2: Verify Package Name

Confirm your Android package name matches what you configured in RevenueCat:

```bash
grep "applicationId" android/app/build.gradle.kts
```

Should output: `applicationId = "com.trooth.flutterTroothAssessment"`

### Step 3.3: Add Billing Permission (Usually Automatic)

The `purchases_flutter` package should add the billing permission automatically. Verify it exists:

```bash
grep "BILLING" android/app/src/main/AndroidManifest.xml
```

If not present, add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="com.android.vending.BILLING" />
```

### Step 3.4: Build and Deploy for Testing

```bash
cd "/Users/tmoney/Documents/ONLY BLV/trooth_assessment"

# Build release AAB
flutter build appbundle --release

# Or build APK for direct device install
flutter build apk --release
```

---

## Part 4: Testing Setup

### Step 4.1: Choose a Testing Track

Google Play offers multiple testing tracks. **Internal testing** is fastest:

| Track | Approval Time | Testers |
|-------|--------------|---------|
| Internal testing | Instant | Up to 100 invited emails |
| Closed testing | Hours | Invited groups |
| Open testing | Hours | Anyone with link |
| Production | 1-7 days | Public |

**Recommended**: Start with **Internal testing**.

### Step 4.2: Set Up Internal Testing

1. In Google Play Console, go to **Release** → **Testing** → **Internal testing**
2. Click **Create new release**
3. Upload your AAB (`build/app/outputs/bundle/release/app-release.aab`)
4. Add release notes
5. Click **Review release** → **Start rollout to internal testing**

### Step 4.3: Add Testers to Internal Testing

1. On the Internal testing page, under **Testers**, click **Create email list** (or use existing)
2. Add tester email addresses (must be Google accounts)
3. Save the list and make sure it's selected for the release
4. Copy the **opt-in link** — testers must visit this to join

### Step 4.4: Install on Device

1. On the test device, open the **opt-in link** in a browser (signed into the tester's Google account)
2. Accept the invitation
3. Click the Google Play link to install the app
4. Alternatively, install the APK directly:
   ```bash
   flutter install
   # or
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

### Step 4.5: Ensure License Tester Is Configured

Double-check the device's Google account is listed in **Settings → License testing** (Step 1.6). Without this, test purchases will charge real money.

---

## Part 5: Testing Purchases

### Step 5.1: Initial Verification

1. Open T[root]H Discipleship on your Android device
2. Log in as a mentor
3. Navigate to **Settings → Subscription**
4. The debug box should show:
   - `current=true`
   - `pkgs=2` (or more)
   - `keys=[default]`

If you see `current=false, pkgs=0`, see Troubleshooting below.

### Step 5.2: Test Purchase Flow

1. Tap on **Mentor Premium Monthly**
2. Google Play purchase sheet should appear
3. It should show **"Test card, always approves"** (confirms you're a license tester)
4. Confirm the purchase
5. App should show "Welcome to Premium!" message

> 💡 **Sandbox subscription renewals**: Google Play test subscriptions renew at accelerated rates:
> | Real Duration | Test Duration |
> |---------------|---------------|
> | 1 Week | 5 minutes |
> | 1 Month | 5 minutes |
> | 3 Months | 10 minutes |
> | 6 Months | 15 minutes |
> | 1 Year | 30 minutes |

### Step 5.3: Verify in RevenueCat Dashboard

1. Go to RevenueCat → **Customers**
2. Toggle **Sandbox data** to ON (top-right toggle)
3. Search for your user (by Firebase UID)
4. You should see:
   - Active subscription from Google Play Store
   - Entitlement: `premium` ✅
   - Store: Google Play

### Step 5.4: Test Restore Purchases

1. Uninstall and reinstall the app
2. Log in with the same account
3. Tap **Restore Purchases** on the subscription screen
4. Should restore the existing subscription

---

## Troubleshooting

### Debug Box Shows `current=false, pkgs=0, keys=[]`

**Cause**: RevenueCat SDK can't fetch offerings.

**Solutions**:
1. Verify `goog_` API key is correct and not empty
2. Check package name matches exactly: `com.trooth.flutterTroothAssessment`
3. Ensure the "default" offering is still marked as current in RevenueCat
4. Kill the app and reopen
5. Check logcat for RevenueCat errors:
   ```bash
   adb logcat | grep -i "purchases\|revenuecat"
   ```

### "Item not available" or "Product not found"

**Cause**: Product IDs don't match or products aren't active.

**Solutions**:
1. Verify product IDs in Google Play Console match RevenueCat **exactly**
2. Ensure each subscription has an **active** base plan
3. Confirm the app was uploaded to at least one testing track
4. Wait — new products can take several hours to become available
5. Verify the signed APK/AAB package name matches (`com.trooth.flutterTroothAssessment`)

### "This version of the app is not configured for billing"

**Cause**: The installed APK wasn't downloaded from Google Play or the version doesn't match.

**Solutions**:
1. Install via Google Play (internal testing track) instead of direct APK install
2. Make sure the version code of the installed build matches what's on Google Play
3. Verify the signing key matches (release key, not debug)

### Service Account Validation Fails in RevenueCat

**Cause**: Permissions haven't propagated or are misconfigured.

**Solutions**:
1. Wait 24-48 hours after granting permissions
2. Verify the service account email has the correct app-level permissions in Google Play Console
3. Re-download the JSON key and re-upload in RevenueCat
4. Ensure the Google Cloud project is the one linked to your Play Console

### Purchase Completes But No Premium Access

**Cause**: Entitlement not attached or backend webhook issue.

**Solutions**:
1. In RevenueCat, verify ALL Google Play products are attached to the `premium` entitlement
2. Check that webhook is configured for your backend (if applicable)
3. Tap **Restore Purchases** in the app
4. Check RevenueCat customer page — does the purchase appear?

### "Test card, always declines" Appears

**Cause**: License test response is set to decline.

**Solution**: In Google Play Console → Settings → License testing → set response to **RESPOND_NORMALLY**

---

## Quick Reference

### Product IDs (Google Play & RevenueCat)
| Product ID | Price | Duration |
|------------|-------|----------|
| `mentor_premium_monthly` | $4.99 | 1 Month |
| `mentor_premium_annual` | $49.99 | 1 Year |
| `apprentice_premium_monthly` | $4.99 | 1 Month |
| `apprentice_premium_annual` | $49.99 | 1 Year |
| `mentor_gift_seat_monthly` | $2.99 | 1 Month |

### RevenueCat Configuration (Android)
| Setting | Value |
|---------|-------|
| Package name | `com.trooth.flutterTroothAssessment` |
| Entitlement ID | `premium` (shared with iOS) |
| Offering ID | `default` (shared with iOS) |
| API Key | `goog_...` (from RevenueCat dashboard) |

### Base Plan IDs
| Subscription | Base Plan ID |
|-------------|-------------|
| Mentor Monthly | `mentor-premium-monthly-base` |
| Mentor Annual | `mentor-premium-annual-base` |
| Apprentice Monthly | `apprentice-premium-monthly-base` |
| Apprentice Annual | `apprentice-premium-annual-base` |
| Gift Seat | `mentor-gift-seat-monthly-base` |

### Key Differences from iOS Setup
| Aspect | iOS | Android |
|--------|-----|---------|
| Account type | Apple Developer ($99/yr) | Google Play Developer ($25 once) |
| Auth method | App-Specific Shared Secret + API Key | Service Account JSON key |
| Test accounts | Sandbox tester (separate account) | License tester (real Google account) |
| Test purchases | Always free in sandbox | Free with "Test card, always approves" |
| Subscription model | Product → Price | Product → Base Plan → Price |
| Propagation time | Usually instant | Up to 24-48 hours for service account |
| API key prefix | `appl_` | `goog_` |

---

## Build Commands Reference

```bash
# Debug build to connected device
flutter run -d <device_id>

# Release APK (for direct install)
flutter build apk --release

# Release AAB (for Google Play upload)
flutter build appbundle --release

# With RevenueCat key via environment
flutter build appbundle --release --dart-define=REVENUECAT_GOOGLE_KEY=goog_YOUR_KEY

# Install APK on connected device
adb install build/app/outputs/flutter-apk/app-release.apk

# List connected devices
flutter devices
```

---

## Additional Resources

- [RevenueCat Google Play Setup Guide](https://docs.revenuecat.com/docs/google-play-products)
- [RevenueCat Flutter SDK Docs](https://docs.revenuecat.com/docs/flutter)
- [Google Play Billing Overview](https://developer.android.com/google/play/billing)
- [Google Play Console Help — Subscriptions](https://support.google.com/googleplay/android-developer/answer/140504)
- [Google Play License Testing](https://developer.android.com/google/play/billing/test)
- [Service Account Setup for RevenueCat](https://docs.revenuecat.com/docs/creating-play-service-credentials)
