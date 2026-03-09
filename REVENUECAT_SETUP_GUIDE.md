# RevenueCat Integration Guide for T[root]H Discipleship

This guide walks through the complete setup of RevenueCat for in-app subscriptions, from App Store Connect configuration to testing on a real device.

---

## Prerequisites

- Apple Developer Account with App Store Connect access
- RevenueCat account (https://app.revenuecat.com)
- T[root]H Discipleship app already in App Store Connect
- Physical iOS device for testing (simulator doesn't support IAP)
- TestFlight build installed on device

---

## Part 1: App Store Connect Configuration

### Step 1.1: Navigate to Your App

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **My Apps**
3. Select **T[root]H Discipleship**

### Step 1.2: Create Subscription Group

1. In the left sidebar, under **Features**, click **Subscriptions**
2. If no subscription group exists, click **Create** or **+**
3. Enter:
   - **Reference Name**: `T[root]H Discipleship Premium`
   - Click **Create**

### Step 1.3: Create Individual Subscriptions

Inside your subscription group, create each subscription:

#### Subscription 1: Mentor Premium Monthly
1. Click **+** or **Create Subscription**
2. Enter:
   - **Reference Name**: `Mentor Premium Monthly`
   - **Product ID**: `mentor_premium_monthly` ⚠️ EXACT - this ID is used in code
3. Click **Create**
4. Fill in subscription details:
   - **Subscription Duration**: 1 Month
   - **Subscription Prices**: Click **+**, select your territories, set **$4.99 USD**
   - **App Store Localization**: Click **+**, add at least one:
     - **Language**: English (U.S.)
     - **Subscription Display Name**: `Mentor Premium Monthly`
     - **Description**: `Full access to premium mentor features, billed monthly.`
5. Click **Save**

#### Subscription 2: Mentor Premium Annual
1. Create new subscription in the same group
2. Enter:
   - **Reference Name**: `Mentor Premium Annual`
   - **Product ID**: `mentor_premium_annual`
3. Fill in:
   - **Subscription Duration**: 1 Year
   - **Price**: $49.99 USD
   - **Localization**:
     - **Display Name**: `Mentor Premium Annual`
     - **Description**: `Full access to premium mentor features. Save 17% with annual billing!`

#### Subscription 3: Apprentice Premium Monthly
1. Create new subscription
2. Enter:
   - **Reference Name**: `Apprentice Premium Monthly`
   - **Product ID**: `apprentice_premium_monthly`
3. Fill in:
   - **Subscription Duration**: 1 Month
   - **Price**: $4.99 USD
   - **Localization**:
     - **Display Name**: `Apprentice Premium Monthly`
     - **Description**: `Full access to premium apprentice features, billed monthly.`

#### Subscription 4: Apprentice Premium Annual
1. Create new subscription
2. Enter:
   - **Reference Name**: `Apprentice Premium Annual`
   - **Product ID**: `apprentice_premium_annual`
3. Fill in:
   - **Subscription Duration**: 1 Year
   - **Price**: $49.99 USD
   - **Localization**:
     - **Display Name**: `Apprentice Premium Annual`
     - **Description**: `Full access to premium apprentice features. Save 17% with annual billing!`

#### Subscription 5: Mentor Gift Seat
1. Create new subscription
2. Enter:
   - **Reference Name**: `Mentor Gift Seat Monthly`
   - **Product ID**: `mentor_gift_seat_monthly`
3. Fill in:
   - **Subscription Duration**: 1 Month
   - **Price**: $2.99 USD
   - **Localization**:
     - **Display Name**: `Gift Seat for Apprentice`
     - **Description**: `Gift premium access to one of your apprentices.`

### Step 1.4: Verify Subscription Status

1. Go back to **Subscriptions** overview
2. Each subscription should show status: **Ready to Submit** ✅
3. If any show **Missing Metadata**, click on it and fill in missing fields

> ⚠️ **Important**: Subscriptions must show "Ready to Submit" for sandbox testing to work!

### Step 1.5: Get App-Specific Shared Secret

1. Go to **App Information** (left sidebar, under General)
2. Scroll down to **App-Specific Shared Secret**
3. Click **Manage**
4. If no secret exists, click **Generate**
5. **Copy the secret** and save it somewhere safe - you'll need it for RevenueCat

The secret looks like: `1234567890abcdef1234567890abcdef`

### Step 1.6: Create Sandbox Tester Account

1. Go to [App Store Connect Home](https://appstoreconnect.apple.com)
2. Click **Users and Access** (top navigation)
3. Click the **Sandbox** tab (near the top, next to "Testers")
4. Click **+** to add a new tester
5. Fill in:
   - **First Name**: Test
   - **Last Name**: User
   - **Email**: `testsandbox@yourdomain.com` (doesn't need to be real, but must be unique)
   - **Password**: Something you'll remember (e.g., `Test1234!`)
   - **Secret Question/Answer**: Anything
   - **Date of Birth**: Make them over 18
   - **Country**: United States
6. Click **Invite** or **Create**

> 📝 **Save these credentials** - you'll sign into your iPhone with this account!

---

## Part 2: RevenueCat Configuration

### Step 2.1: Create RevenueCat Account/Project

1. Go to [RevenueCat Dashboard](https://app.revenuecat.com)
2. Sign up or log in
3. Create a new project or use existing one (ONLY BLV LLC)

### Step 2.2: Clear Existing Configuration (If Starting Fresh)

If you have existing broken configuration:

1. **Apps & providers** → Click on your iOS app → Delete it
2. **Product catalog → Offerings** → Delete all offerings
3. **Product catalog → Products** → Delete all products  
4. **Product catalog → Entitlements** → Delete all entitlements

### Step 2.3: Add iOS App

1. Click **Apps & providers** in the left sidebar
2. Click **+ New** button
3. Select **App Store (iOS / macOS / watchOS / visionOS)**
4. Configure the app:

   **Basic Info:**
   - **App name**: `T[root]H Discipleship`
   - **Bundle ID**: `com.trooth.flutterTroothAssessment` ⚠️ MUST MATCH EXACTLY

   **App Store Connect API (Recommended):**
   
   This allows RevenueCat to automatically sync products. Get these from App Store Connect:
   
   1. Go to [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api)
   2. Click **Generate API Key** (or use existing)
   3. Select **Admin** role
   4. Download the `.p8` file
   5. Note the **Key ID** and **Issuer ID**
   
   Back in RevenueCat:
   - **Issuer ID**: Paste from App Store Connect
   - **Key ID**: Paste from App Store Connect  
   - **Key File**: Upload the `.p8` file
   - Click **Save credentials** - should show "Valid credentials" ✅

   **App-Specific Shared Secret:**
   - Paste the secret from Step 1.5
   - This is REQUIRED for receipt validation

5. Click **Save**

### Step 2.4: Create Products

1. Go to **Product catalog → Products**
2. Click **+ New** to create each product:

   **Product 1:**
   - **Identifier**: `mentor_premium_monthly` (must match App Store Connect Product ID exactly)
   - **Store**: App Store
   - **App**: T[root]H Discipleship
   - Click **Add**

   **Product 2:**
   - **Identifier**: `mentor_premium_annual`
   - **Store**: App Store
   - **App**: T[root]H Discipleship

   **Product 3:**
   - **Identifier**: `apprentice_premium_monthly`
   - **Store**: App Store
   - **App**: T[root]H Discipleship

   **Product 4:**
   - **Identifier**: `apprentice_premium_annual`
   - **Store**: App Store
   - **App**: T[root]H Discipleship

   **Product 5:**
   - **Identifier**: `mentor_gift_seat_monthly`
   - **Store**: App Store
   - **App**: T[root]H Discipleship

3. Verify all 5 products appear in the list

> 💡 **Alternative**: If you set up the App Store Connect API correctly, you can click **Import Products** to automatically pull them from App Store Connect.

### Step 2.5: Create Entitlement

Entitlements define what features a user unlocks when they purchase.

1. Go to **Product catalog → Entitlements**
2. Click **+ New**
3. Enter:
   - **Identifier**: `premium` ⚠️ EXACT - this ID is used in code
   - **Description**: `Premium subscription access`
4. Click **Add**
5. Now **attach products to this entitlement**:
   - Click on the `premium` entitlement
   - Click **Attach** or **+ Add Products**
   - Select ALL 5 products (mentor monthly, mentor annual, apprentice monthly, apprentice annual, gift seat)
   - Save

This means purchasing ANY of these 5 products grants the `premium` entitlement.

### Step 2.6: Create Offering

Offerings are what your app fetches to show users available subscriptions.

1. Go to **Product catalog → Offerings**
2. Click **+ New offering**
3. Enter:
   - **Identifier**: `default` ⚠️ MUST BE EXACTLY "default" - the SDK looks for this
   - **Display Name**: `T[root]H Discipleship Offerings`
4. Click **Add**

### Step 2.7: Add Packages to Offering

Packages organize products within an offering. The SDK uses these identifiers.

1. Click on the **default** offering to open it
2. Click **+ New Package** to add each:

   **Package 1: Mentor Monthly**
   - **Identifier**: Select `$rc_monthly` from dropdown (RevenueCat's standard monthly identifier)
   - **Description**: `Mentor Premium Monthly`
   - **Products**: 
     - For "T[root]H Discipleship" (iOS): Select `mentor_premium_monthly`
   - Click **Add**

   **Package 2: Mentor Annual**
   - **Identifier**: Select `$rc_annual` from dropdown
   - **Description**: `Mentor Premium Annual`
   - **Products**: 
     - For "T[root]H Discipleship" (iOS): Select `mentor_premium_annual`
   - Click **Add**

   **Package 3: Apprentice Monthly**
   - **Identifier**: Enter `apprentice_monthly` (custom identifier)
   - **Description**: `Apprentice Premium Monthly`
   - **Products**: 
     - For "T[root]H Discipleship" (iOS): Select `apprentice_premium_monthly`
   - Click **Add**

   **Package 4: Apprentice Annual**
   - **Identifier**: Enter `apprentice_annual` (custom identifier)
   - **Description**: `Apprentice Premium Annual`
   - **Products**: 
     - For "T[root]H Discipleship" (iOS): Select `apprentice_premium_annual`
   - Click **Add**

   **Package 5: Gift Seat**
   - **Identifier**: Enter `gift_seat` (custom identifier)
   - **Description**: `Gift Seat for Apprentice`
   - **Products**: 
     - For "T[root]H Discipleship" (iOS): Select `mentor_gift_seat_monthly`
   - Click **Add**

3. Verify all 5 packages appear in the offering

### Step 2.8: Set Default Offering as Current

This is **CRITICAL** - if the offering isn't marked as current, the SDK returns empty!

1. Go back to **Product catalog → Offerings**
2. You should see "default" with a blue checkmark ✓ indicating it's current
3. If NOT current:
   - Click the **three dots (⋮)** menu next to "default"
   - Select **Make Default** or **Set as Current**

### Step 2.9: Get API Key

1. Click **API keys** in the left sidebar
2. Find the **Public app-specific API keys** section
3. Your iOS key starts with `appl_`
4. **Copy this key** - you'll need it for the Flutter app

Example: `appl_xdfVjYgjmatKVoHnEcyIhRRWqNL`

---

## Part 3: Flutter App Configuration

### Step 3.1: Update API Key in Code

Open `lib/services/subscription_service.dart` and verify/update the API key:

```dart
// Around line 218-220
static const String _revenueCatAppleApiKey = 'appl_YOUR_API_KEY_HERE';
```

Replace with your actual API key from Step 2.9.

### Step 3.2: Verify Bundle ID

Check that your iOS bundle ID matches what you configured in RevenueCat:

```bash
grep "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj | head -1
```

Should output: `com.trooth.flutterTroothAssessment`

### Step 3.3: Build New TestFlight Version

```bash
cd "/Users/tmoney/Documents/ONLY BLV/trooth_assessment"
flutter build ipa --release --build-number=19
```

### Step 3.4: Upload to TestFlight

1. Open **Transporter** app on Mac
2. Drag the IPA file from `build/ios/ipa/trooth_assessment.ipa`
3. Click **Deliver**
4. Wait for processing in App Store Connect (5-15 minutes)

---

## Part 4: Device Setup for Testing

### Step 4.1: Sign Out of Any Existing Sandbox Account

1. On your iPhone, go to **Settings**
2. Scroll down and tap **App Store**
3. Scroll to the bottom to **Sandbox Account** section
4. If signed in, tap and **Sign Out**

### Step 4.2: Install TestFlight Build

1. Open **TestFlight** app on your iPhone
2. Find T[root]H Discipleship
3. Install the latest build (the one you just uploaded)

### Step 4.3: Sign Into Sandbox Account

1. Open the T[root]H app
2. Navigate to the **Subscription** screen
3. When you tap a subscription to purchase, iOS will prompt for sign-in
4. Choose **Use Existing Apple ID**
5. Enter your **Sandbox Tester credentials** from Step 1.6
6. Complete the purchase

> ⚠️ **Do NOT sign into the sandbox account in regular Settings → Apple ID**. Only use it when prompted during an in-app purchase, or in Settings → App Store → Sandbox Account.

---

## Part 5: Testing

### Step 5.1: Initial Test

1. Kill the T[root]H app completely (swipe up in app switcher)
2. Reopen the app
3. Log in as a mentor
4. Navigate to **Settings → Subscription**
5. The debug box should show:
   - `current=true`
   - `pkgs=2` (or more)
   - `keys=[default]`

### Step 5.2: Test Purchase Flow

1. Tap on **Mentor Premium Monthly**
2. iOS purchase sheet should appear
3. Confirm with Face ID / Touch ID / Password
4. Purchase should complete (sandbox purchases are free!)
5. App should show "Welcome to Premium!" message

### Step 5.3: Verify in RevenueCat Dashboard

1. Go to RevenueCat → **Customers**
2. Toggle **Sandbox data** (top right) to ON
3. Search for your user (by Firebase UID or app user ID)
4. You should see:
   - Active subscription
   - Entitlement: `premium` ✅

---

## Troubleshooting

### Debug Box Shows `current=false, pkgs=0, keys=[]`

**Cause**: RevenueCat SDK can't fetch offerings

**Solutions**:
1. Verify "default" offering is marked as current in RevenueCat
2. Check API key matches exactly (no extra spaces)
3. Check bundle ID matches exactly
4. Kill app and reopen
5. Try on different network (WiFi vs cellular)

### Debug Box Shows `current=true, pkgs=0`

**Cause**: Offering exists but has no packages

**Solution**: 
1. Go to RevenueCat → Offerings → default
2. Verify packages are added with products attached

### "Product Not Found" or "Invalid Product"

**Cause**: Product IDs don't match between App Store Connect and RevenueCat

**Solution**:
1. Check App Store Connect product IDs are EXACTLY: `mentor_premium_monthly`, etc.
2. Check RevenueCat product identifiers match exactly
3. Check products are attached to packages in the offering

### Purchase Shows "Cannot Connect to App Store"

**Cause**: Not signed into sandbox account, or Apple sandbox servers are down

**Solutions**:
1. Go to Settings → App Store → Sandbox Account and sign in
2. Wait and try again (Apple sandbox can be flaky)
3. Try on different network

### Purchase Completes But No Premium Access

**Cause**: Backend not receiving/processing webhook, or entitlement not set up

**Solutions**:
1. Verify the `premium` entitlement exists and has all products attached
2. Check RevenueCat webhook is configured for your backend
3. Manually trigger restore: tap "Restore Purchases" in app

---

## Quick Reference

### Product IDs (App Store Connect & RevenueCat)
| Product ID | Price | Duration |
|------------|-------|----------|
| `mentor_premium_monthly` | $4.99 | 1 Month |
| `mentor_premium_annual` | $49.99 | 1 Year |
| `apprentice_premium_monthly` | $4.99 | 1 Month |
| `apprentice_premium_annual` | $49.99 | 1 Year |
| `mentor_gift_seat_monthly` | $2.99 | 1 Month |

### RevenueCat Configuration
| Setting | Value |
|---------|-------|
| Bundle ID | `com.trooth.flutterTroothAssessment` |
| Entitlement ID | `premium` |
| Offering ID | `default` |
| API Key | `appl_xdfVjYgjmatKVoHnEcyIhRRWqNL` |

### Package Identifiers
| Package | Identifier |
|---------|------------|
| Mentor Monthly | `$rc_monthly` |
| Mentor Annual | `$rc_annual` |
| Apprentice Monthly | `apprentice_monthly` |
| Apprentice Annual | `apprentice_annual` |
| Gift Seat | `gift_seat` |

---

## Additional Resources

- [RevenueCat iOS Setup Guide](https://docs.revenuecat.com/docs/ios-products)
- [RevenueCat Flutter SDK](https://docs.revenuecat.com/docs/flutter)
- [App Store Connect Subscriptions](https://developer.apple.com/documentation/storekit/in-app_purchase/subscriptions_and_offers)
- [Sandbox Testing Guide](https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases_with_sandbox)
