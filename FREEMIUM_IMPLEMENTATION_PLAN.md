# T[root]H Freemium Implementation Plan

## Executive Summary

Convert T[root]H from a fully free app to a freemium model with premium subscriptions at **$4.99/month** or **$50/year**. This document covers architecture, implementation, store setup, testing, and rollout strategy.

---

## Table of Contents

1. [Business Model Summary](#1-business-model-summary)
2. [Premium Features Matrix](#2-premium-features-matrix)
3. [Technical Architecture](#3-technical-architecture)
4. [Subscription Service: RevenueCat vs Native](#4-subscription-service-revenuecat-vs-native)
5. [Backend Changes](#5-backend-changes)
6. [Frontend Changes](#6-frontend-changes)
7. [Apple App Store Connect Setup](#7-apple-app-store-connect-setup)
8. [Google Play Console Setup](#8-google-play-console-setup)
9. [Branch Strategy & Version Management](#9-branch-strategy--version-management)
10. [Testing Subscriptions (Sandbox)](#10-testing-subscriptions-sandbox)
11. [Migration Plan for Existing Users](#11-migration-plan-for-existing-users)
12. [Edge Cases & Business Logic](#12-edge-cases--business-logic)
13. [Additional Premium Feature Recommendations](#13-additional-premium-feature-recommendations)
14. [Promotions & Incentive Programs](#14-promotions--incentive-programs)
15. [Implementation Phases](#15-implementation-phases)
16. [Checklist](#16-checklist)

---

## 1. Business Model Summary

### Pricing
| Plan | Monthly | Yearly | Savings |
|------|---------|--------|---------|
| Premium | $4.99 | $50.00 | ~17% |

### Who Pays for What

| Scenario | Who Pays | What They Get |
|----------|----------|---------------|
| Mentor wants >1 apprentice | Mentor | Ability to link multiple apprentices |
| Mentor wants apprentice to have premium | Mentor (per seat) | Code to give apprentice premium access |
| Apprentice wants premium independently | Apprentice | Access to all assessments |

### Subscription Types (Backend)
1. **`mentor_premium`** - Mentor's own subscription (unlocks multiple apprentices + template creation)
2. **`apprentice_premium`** - Apprentice's own subscription (unlocks all assessments)
3. **`mentor_gifted_seat`** - Apprentice premium paid for by mentor (code redemption)

---

## 2. Premium Features Matrix

### Mentor Features

| Feature | Free | Premium |
|---------|------|---------|
| Link apprentices | 1 max | Unlimited |
| View apprentice reports | ✅ | ✅ |
| Add mentor notes | ✅ | ✅ |
| Create custom templates | ❌ | ✅ |
| "Getting Started" mentor guides | ✅ | ✅ |
| All other mentor resource guides | ❌ | ✅ |
| Purchase premium seats for apprentices | ❌ | ✅ |
| Priority support | ❌ | ✅ |

### Apprentice Features

| Feature | Free | Premium |
|---------|------|---------|
| Master T[root]H Assessment | ✅ | ✅ |
| Spiritual Gifts Assessment | ✅ | ✅ |
| All other assessments (Romans, Samuel, etc.) | ❌ | ✅ |
| "Getting Started" growth guides | ✅ | ✅ |
| All other growth resource guides | ❌ | ✅ |
| View own reports | ✅ | ✅ |
| Connect with mentor | ✅ | ✅ |
| Priority support | ❌ | ✅ |

### Configurable Free Assessments
Store a list of "free assessment keys" in backend config:
```python
FREE_ASSESSMENT_KEYS = [
    "master_assessment_v1",
    "spiritual_gifts_v1",
    # Add more here to make them free without code changes
]
```

---

## 3. Technical Architecture

### Current State
```
┌─────────────┐      ┌─────────────────┐      ┌──────────────┐
│   Flutter   │ ───▶ │  FastAPI        │ ───▶ │  PostgreSQL  │
│   App       │      │  Backend        │      │  Database    │
└─────────────┘      └─────────────────┘      └──────────────┘
                            │
                            ▼
                     ┌─────────────┐
                     │  Firebase   │
                     │  Auth       │
                     └─────────────┘
```

### Freemium State (with RevenueCat)
```
┌─────────────┐      ┌─────────────────┐      ┌──────────────┐
│   Flutter   │ ───▶ │  FastAPI        │ ───▶ │  PostgreSQL  │
│   App       │      │  Backend        │      │  Database    │
└──────┬──────┘      └────────┬────────┘      └──────────────┘
       │                      │
       │                      │ Webhooks
       ▼                      ▼
┌─────────────┐      ┌─────────────────┐
│  RevenueCat │ ◀────│  RevenueCat     │
│  SDK        │      │  Dashboard      │
└──────┬──────┘      └─────────────────┘
       │                      │
       ▼                      ▼
┌─────────────┐      ┌─────────────────┐
│  App Store  │      │  Google Play    │
│  Connect    │      │  Console        │
└─────────────┘      └─────────────────┘
```

### Data Flow for Subscription Check
1. User opens app → RevenueCat SDK checks subscription status
2. App stores subscription status locally (for offline access)
3. Backend receives webhook from RevenueCat on subscription changes
4. Backend updates user's `subscription_tier` in database
5. API calls validate tier server-side before returning premium content

---

## 4. Subscription Service: RevenueCat vs Native

### Recommendation: **RevenueCat** ✅

| Factor | RevenueCat | Native (StoreKit + Google Billing) |
|--------|------------|-----------------------------------|
| Cross-platform code | Single SDK | Two separate implementations |
| Receipt validation | Automatic (server-side) | Must build your own |
| Webhook support | Built-in | Must build your own |
| Subscription analytics | Dashboard included | Must build or use Firebase |
| Grace periods/retries | Handled automatically | Must implement manually |
| Promo codes | Built-in support | Platform-specific |
| Testing | Excellent sandbox support | Good but separate flows |
| Cost | Free up to $2,500/mo revenue, then 1% | Free |
| Time to implement | ~1-2 weeks | ~4-6 weeks |
| Maintenance | Low | High |

### RevenueCat Setup Overview
1. Create RevenueCat account (free)
2. Connect App Store Connect & Google Play Console
3. Define "Offerings" (your subscription products)
4. Add RevenueCat SDK to Flutter app
5. Configure webhooks to your backend
6. Handle entitlements in app & backend

---

## 5. Backend Changes

### 5.1 Database Schema Changes

#### New Tables

```sql
-- User subscription information
ALTER TABLE users ADD COLUMN subscription_tier VARCHAR(50) DEFAULT 'free';
-- Values: 'free', 'mentor_premium', 'apprentice_premium', 'mentor_gifted'

ALTER TABLE users ADD COLUMN subscription_expires_at TIMESTAMP;
ALTER TABLE users ADD COLUMN subscription_platform VARCHAR(20);
-- Values: 'apple', 'google', 'gifted', 'admin_granted'

ALTER TABLE users ADD COLUMN revenuecat_customer_id VARCHAR(255);
ALTER TABLE users ADD COLUMN subscription_auto_renew BOOLEAN DEFAULT false;

-- Mentor seat purchases (for gifting to apprentices)
CREATE TABLE mentor_premium_seats (
    id UUID PRIMARY KEY,
    mentor_id UUID REFERENCES users(id) NOT NULL,
    apprentice_id UUID REFERENCES users(id),  -- NULL until redeemed
    redemption_code VARCHAR(20) UNIQUE NOT NULL,
    is_redeemed BOOLEAN DEFAULT false,
    redeemed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,  -- Tied to mentor's subscription
    is_active BOOLEAN DEFAULT true
);

-- Subscription event log (for debugging/auditing)
CREATE TABLE subscription_events (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    event_type VARCHAR(50) NOT NULL,
    -- 'purchase', 'renewal', 'cancellation', 'expiration', 'refund', 'gift_redeemed'
    platform VARCHAR(20),
    product_id VARCHAR(100),
    revenuecat_event_id VARCHAR(255),
    raw_payload JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Configurable free assessments
CREATE TABLE free_assessments (
    id UUID PRIMARY KEY,
    assessment_key VARCHAR(100) UNIQUE NOT NULL,
    added_at TIMESTAMP DEFAULT NOW(),
    added_by UUID REFERENCES users(id)
);
```

### 5.2 New API Endpoints

```python
# Subscription Management
POST   /subscriptions/webhook          # RevenueCat webhook receiver
GET    /subscriptions/status           # Get current user's subscription status
POST   /subscriptions/restore          # Trigger restore purchases

# Mentor Seat Management
POST   /mentor/seats/purchase          # Record seat purchase (after RevenueCat confirms)
GET    /mentor/seats                   # List mentor's purchased seats
POST   /mentor/seats/{seat_id}/revoke  # Revoke a seat (reassign to different apprentice)
DELETE /mentor/seats/{seat_id}         # Cancel a seat

# Apprentice Code Redemption
POST   /apprentice/redeem-code         # Redeem mentor's gift code
GET    /apprentice/subscription-source # Check if gifted or self-purchased

# Admin
POST   /admin/users/{user_id}/grant-premium   # Manually grant premium
DELETE /admin/users/{user_id}/revoke-premium  # Manually revoke premium
GET    /admin/subscriptions/stats             # Subscription analytics
POST   /admin/free-assessments                # Add assessment to free tier
DELETE /admin/free-assessments/{key}          # Remove from free tier
```

### 5.3 Assessment Access Control

Modify existing assessment endpoints:

```python
# In /templates/published endpoint
def get_published_templates(current_user: User, db: Session):
    templates = db.query(AssessmentTemplate).filter(
        AssessmentTemplate.is_published == True
    ).all()
    
    # Get free assessment keys
    free_keys = get_free_assessment_keys(db)
    
    # Check user's subscription
    is_premium = current_user.subscription_tier in ['apprentice_premium', 'mentor_gifted']
    
    result = []
    for template in templates:
        template_data = template.to_dict()
        template_data['is_locked'] = not (
            template.key in free_keys or is_premium
        )
        result.append(template_data)
    
    return result

# In /assessment-drafts/start endpoint
def start_assessment(template_id: str, current_user: User, db: Session):
    template = get_template(template_id)
    free_keys = get_free_assessment_keys(db)
    is_premium = current_user.subscription_tier in ['apprentice_premium', 'mentor_gifted']
    
    if template.key not in free_keys and not is_premium:
        raise ForbiddenException("Premium subscription required for this assessment")
    
    # ... continue with draft creation
```

### 5.4 Mentor Apprentice Limit

```python
# In invitation acceptance / apprentice linking
def link_apprentice_to_mentor(mentor_id: str, apprentice_id: str, db: Session):
    mentor = get_user(mentor_id)
    current_apprentice_count = get_apprentice_count(mentor_id, db)
    
    is_premium = mentor.subscription_tier == 'mentor_premium'
    max_apprentices = 999 if is_premium else 1
    
    if current_apprentice_count >= max_apprentices:
        raise ForbiddenException(
            "Free mentors can only have 1 apprentice. Upgrade to premium for unlimited."
        )
    
    # ... continue with linking
```

### 5.5 RevenueCat Webhook Handler

```python
@router.post("/subscriptions/webhook")
async def revenuecat_webhook(request: Request, db: Session = Depends(get_db)):
    # Verify webhook signature (RevenueCat provides this)
    payload = await request.json()
    
    event_type = payload.get('event', {}).get('type')
    app_user_id = payload.get('event', {}).get('app_user_id')  # Firebase UID
    product_id = payload.get('event', {}).get('product_id')
    
    user = db.query(User).filter(User.firebase_uid == app_user_id).first()
    if not user:
        return {"status": "user_not_found"}
    
    # Map product IDs to subscription tiers
    tier_map = {
        'mentor_premium_monthly': 'mentor_premium',
        'mentor_premium_yearly': 'mentor_premium',
        'apprentice_premium_monthly': 'apprentice_premium',
        'apprentice_premium_yearly': 'apprentice_premium',
    }
    
    if event_type in ['INITIAL_PURCHASE', 'RENEWAL']:
        user.subscription_tier = tier_map.get(product_id, 'free')
        user.subscription_expires_at = parse_expiration(payload)
        user.subscription_auto_renew = True
        
    elif event_type in ['CANCELLATION', 'EXPIRATION']:
        user.subscription_tier = 'free'
        user.subscription_auto_renew = False
        # Handle mentor seats - deactivate gifted apprentices
        if 'mentor' in product_id:
            deactivate_mentor_seats(user.id, db)
    
    elif event_type == 'REFUND':
        user.subscription_tier = 'free'
        # May need to handle mid-cycle refunds
    
    # Log event
    log_subscription_event(user.id, event_type, payload, db)
    
    db.commit()
    return {"status": "ok"}
```

---

## 6. Frontend Changes

### 6.1 New Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  purchases_flutter: ^6.0.0  # RevenueCat SDK
```

### 6.2 New Files to Create

```
lib/
├── services/
│   └── subscription_service.dart      # RevenueCat wrapper
├── models/
│   └── subscription_status.dart       # Subscription data model
├── screens/
│   ├── subscription_screen.dart       # Purchase/manage subscription
│   ├── mentor_seats_screen.dart       # Mentor: manage apprentice seats
│   └── redeem_code_screen.dart        # Apprentice: enter gift code
├── widgets/
│   ├── premium_badge.dart             # "Premium" indicator
│   ├── upgrade_prompt.dart            # "Upgrade to unlock" CTA
│   ├── locked_assessment_card.dart    # Locked assessment with lock icon
│   └── subscription_status_card.dart  # Show current plan status
└── providers/
    └── subscription_provider.dart     # State management for subscription
```

### 6.3 Subscription Service (RevenueCat Wrapper)

```dart
// lib/services/subscription_service.dart
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  bool _isInitialized = false;
  CustomerInfo? _customerInfo;

  // Product IDs (must match App Store Connect / Google Play)
  static const String mentorMonthly = 'mentor_premium_monthly';
  static const String mentorYearly = 'mentor_premium_yearly';
  static const String apprenticeMonthly = 'apprentice_premium_monthly';
  static const String apprenticeYearly = 'apprentice_premium_yearly';

  Future<void> initialize(String userId) async {
    if (_isInitialized) return;

    await Purchases.setLogLevel(LogLevel.debug); // Remove in production
    
    PurchasesConfiguration config = PurchasesConfiguration(
      Platform.isIOS 
        ? 'appl_YOUR_REVENUECAT_IOS_KEY' 
        : 'goog_YOUR_REVENUECAT_ANDROID_KEY'
    );
    
    await Purchases.configure(config);
    await Purchases.logIn(userId); // Use Firebase UID
    
    _isInitialized = true;
    await refreshCustomerInfo();
  }

  Future<void> refreshCustomerInfo() async {
    _customerInfo = await Purchases.getCustomerInfo();
  }

  bool get isMentorPremium {
    return _customerInfo?.entitlements.active.containsKey('mentor_premium') ?? false;
  }

  bool get isApprenticePremium {
    return _customerInfo?.entitlements.active.containsKey('apprentice_premium') ?? false;
  }

  bool get isPremium => isMentorPremium || isApprenticePremium;

  Future<List<Package>> getOfferings(String role) async {
    final offerings = await Purchases.getOfferings();
    final offeringId = role == 'mentor' ? 'mentor_offering' : 'apprentice_offering';
    return offerings.getOffering(offeringId)?.availablePackages ?? [];
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      _customerInfo = result;
      return true;
    } catch (e) {
      if (e is PurchasesErrorCode && e == PurchasesErrorCode.purchaseCancelledError) {
        return false; // User cancelled
      }
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    _customerInfo = await Purchases.restorePurchases();
  }
}
```

### 6.4 Assessment List & Preview Modifications

The app now has an **Assessment Preview Screen** that displays between selecting an assessment and starting it. This is the ideal place to handle premium gating - users can see what they're missing before being prompted to upgrade.

**Flow:**
1. User taps assessment in list → Opens `AssessmentPreviewScreen`
2. Preview shows: title, description, times taken, last score (if any)
3. If assessment is **free** OR user **has premium** → Show "Begin Assessment" button
4. If assessment is **locked** (premium required) → Show "Unlock with Premium" button + upgrade prompt

```dart
// In AssessmentPreviewScreen - modify the bottom button section
Widget _buildActionButtons() {
  final isLocked = widget.template['is_locked'] == true;
  final isPremium = SubscriptionService().isPremium;
  final canStart = !isLocked || isPremium;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (canStart) ...[
        // User can start - show Begin button
        ElevatedButton(
          onPressed: _startAssessment,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Begin Assessment',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ] else ...[
        // Locked - show premium info and upgrade button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.lock, color: Colors.amber),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Premium subscription required',
                  style: TextStyle(color: Colors.amber),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SubscriptionScreen()),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Unlock with Premium',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text('Cancel', style: TextStyle(color: Colors.grey[500])),
      ),
    ],
  );
}
```

**Assessment List Card (optional lock indicator):**
```dart
// In assessment selection dialog/list - show lock icon but still allow tap to preview
Widget _buildAssessmentCard(Map<String, dynamic> template) {
  final isLocked = template['is_locked'] == true;
  final isPremium = SubscriptionService().isPremium;
  final showLockIcon = isLocked && !isPremium;
  
  return Card(
    child: ListTile(
      title: Text(template['name']),
      subtitle: Text(template['description'] ?? ''),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLockIcon) ...[
            Icon(Icons.lock, color: Colors.amber, size: 18),
            SizedBox(width: 8),
          ],
          Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
      // Always allow tap to see preview - gating happens on preview screen
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssessmentPreviewScreen(template: template),
        ),
      ),
    ),
  );
}
```

**Benefits of preview-based gating:**
1. Users see the full description before hitting the paywall - builds desire
2. "Times Taken: 0" reminds them they haven't tried it yet
3. Less frustrating than instant "you can't do this" popup
4. Preview screen is already built - just need to add conditional button logic

### 6.5 Mentor Dashboard Modifications

```dart
// Show apprentice limit warning
Widget _buildApprenticeSection() {
  final isMentorPremium = SubscriptionService().isMentorPremium;
  final apprenticeCount = _apprentices.length;
  
  return Column(
    children: [
      if (!isMentorPremium && apprenticeCount >= 1)
        _buildUpgradeCard(
          'Want to mentor more?',
          'Upgrade to Premium to mentor unlimited apprentices.',
        ),
      
      // Invite button - disabled if at limit
      ElevatedButton(
        onPressed: (isMentorPremium || apprenticeCount < 1)
          ? () => _inviteApprentice()
          : null,
        child: Text('Invite Apprentice'),
      ),
      
      if (isMentorPremium)
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MentorSeatsScreen()),
          ),
          child: Text('Manage Premium Seats for Apprentices'),
        ),
    ],
  );
}
```

---

## 7. Apple App Store Connect Setup

### 7.1 Create Subscription Group

1. Go to **App Store Connect** → Your App → **Subscriptions**
2. Click **Create** → **Subscription Group**
3. Name: `T[root]H Premium`
4. Reference Name: `trooth_premium_group`

### 7.2 Create Subscription Products

| Reference Name | Product ID | Duration | Price |
|---------------|------------|----------|-------|
| Mentor Premium Monthly | `mentor_premium_monthly` | 1 Month | $4.99 |
| Mentor Premium Yearly | `mentor_premium_yearly` | 1 Year | $50.00 |
| Apprentice Premium Monthly | `apprentice_premium_monthly` | 1 Month | $4.99 |
| Apprentice Premium Yearly | `apprentice_premium_yearly` | 1 Year | $50.00 |

For each product:
1. Set **Subscription Duration**
2. Set **Subscription Price** (select all territories)
3. Add **Localizations** (display name, description)
4. Set **App Store Promotion** image (optional but recommended)

### 7.3 Subscription Details for Each Product

**Display Name (English):**
- Mentor Premium Monthly → "Mentor Premium"
- Apprentice Premium Monthly → "Apprentice Premium"

**Description:**
- Mentor: "Mentor unlimited apprentices, create custom templates, and gift premium to your apprentices."
- Apprentice: "Access all assessments to deepen your spiritual journey and growth."

### 7.4 Set Up Sandbox Testing

1. Go to **Users and Access** → **Sandbox** → **Testers**
2. Click **+** to add sandbox tester
3. Use a **real email you control** (must be unique, not used as Apple ID)
4. Create test accounts for different scenarios:
   - `mentor-test@yourdomain.com`
   - `apprentice-test@yourdomain.com`

### 7.5 Configure Server Notifications (for RevenueCat)

1. Go to **App Information** → **App Store Server Notifications**
2. Production URL: `https://api.revenuecat.com/v1/subscribers/app_store`
3. Sandbox URL: Same as above
4. Version: **Version 2**

---

## 8. Google Play Console Setup

### 8.1 Create Subscription Products

1. Go to **Google Play Console** → Your App → **Monetize** → **Subscriptions**
2. Click **Create subscription**

| Product ID | Name | Billing Period | Price |
|------------|------|----------------|-------|
| `mentor_premium_monthly` | Mentor Premium | Monthly | $4.99 |
| `mentor_premium_yearly` | Mentor Premium | Yearly | $50.00 |
| `apprentice_premium_monthly` | Apprentice Premium | Monthly | $4.99 |
| `apprentice_premium_yearly` | Apprentice Premium | Yearly | $50.00 |

### 8.2 For Each Subscription

1. **Base plan**: Create at least one (e.g., `monthly-base`)
2. **Offers**: Optional introductory pricing or free trials
3. **Grace period**: Enable 3-7 day grace period (recommended)
4. **Resubscribe**: Allow resubscribe from Play Store

### 8.3 Set Up License Testing

1. Go to **Setup** → **License testing**
2. Add tester email addresses
3. Set **License response**: `LICENSED` for testing purchases

### 8.4 Real-time Developer Notifications (for RevenueCat)

1. Go to **Monetization setup** → **Real-time developer notifications**
2. Topic name: Create a Google Cloud Pub/Sub topic
3. RevenueCat will provide the Cloud Pub/Sub configuration

---

## 9. Branch Strategy & Version Management

### Current State
```
main (v1.0.1) ← In App Store Review
  └── develop/mentor_notes ← Active development
```

### Recommended Strategy
```
main (v1.0.1) ← In Review / Production
  │
  ├── develop/mentor_notes ← Current features (merge to main for v1.0.2)
  │
  └── develop/freemium ← New branch for all subscription work
        │
        ├── Phase 1: Backend subscription schema
        ├── Phase 2: RevenueCat integration
        ├── Phase 3: UI changes
        └── Phase 4: Testing & polish
```

### Steps to Create Freemium Branch

```bash
# In frontend repo
cd "/Users/tmoney/Documents/ONLY BLV/trooth_assessment"
git checkout main
git pull origin main
git checkout -b develop/freemium
git push -u origin develop/freemium

# In backend repo
cd "/Users/tmoney/Documents/ONLY BLV/trooth_assessment_backend"
git checkout main
git pull origin main
git checkout -b develop/freemium
git push -u origin develop/freemium
```

### Version Numbering Plan

| Version | Branch | Description |
|---------|--------|-------------|
| 1.0.1 | main | Current TestFlight/Review build |
| 1.0.2 | develop/mentor_notes → main | Bug fixes, mentor notes polish |
| 1.1.0 | develop/freemium → main | Freemium launch |

---

## 10. Testing Subscriptions (Sandbox)

### 10.1 iOS Sandbox Testing

1. **Sign out of App Store** on test device:
   - Settings → App Store → Sign Out
   
2. **Do NOT sign into sandbox account in Settings**
   - Only sign in when prompted by the app during purchase

3. **In your app**, trigger a purchase flow
   - You'll be prompted to sign in
   - Use sandbox tester credentials
   
4. **Sandbox subscription behavior**:
   - 1 month → 5 minutes
   - 1 year → 1 hour
   - Auto-renews up to 6 times, then cancels
   - Renewals happen automatically (can't manually trigger)

### 10.2 Android License Testing

1. Add tester emails in **Play Console** → **License testing**
2. Install app via **Internal testing track** (not from Play Store)
3. Purchase will show "$0.00" or "Test purchase"
4. Subscriptions renew faster (similar to iOS sandbox)

### 10.3 RevenueCat Sandbox Mode

1. RevenueCat automatically detects sandbox vs production
2. Use **RevenueCat Dashboard** → **Customers** to view test purchases
3. Can manually grant/revoke entitlements for testing
4. Webhook events work the same in sandbox

### 10.4 Testing Checklist

- [ ] Fresh install → free tier works correctly
- [ ] Purchase mentor monthly → unlocks features
- [ ] Purchase apprentice monthly → unlocks assessments
- [ ] Cancel subscription → reverts to free after expiration
- [ ] Restore purchases → restores active subscription
- [ ] Mentor purchases seat → generates code
- [ ] Apprentice redeems code → gets premium
- [ ] Mentor cancels → apprentice loses gifted premium
- [ ] Free mentor at limit → can't add apprentice
- [ ] Premium assessment locked → shows upgrade prompt
- [ ] Offline mode → cached subscription status works

---

## 11. Migration Plan for Existing Users

### 11.1 Default State

All existing users start as **free tier** when freemium launches.

### 11.2 Admin Override

Add admin capability to manually grant premium:

```python
# Backend: POST /admin/users/{user_id}/grant-premium
{
  "tier": "mentor_premium",  # or "apprentice_premium"
  "expires_at": "2026-12-31T23:59:59Z",  # or null for indefinite
  "reason": "Beta tester reward"
}
```

### 11.3 Beta Tester Handling Options

| Option | Pros | Cons |
|--------|------|------|
| All convert to free | Simple, fair | May upset active testers |
| 1 month free premium | Rewards testers, soft landing | Revenue delay |
| Permanent premium for top testers | Loyalty reward | Manual work to identify |

**Recommendation**: Give active beta testers **1 month free premium** as a thank-you, then convert to free.

### 11.4 Mentor with Multiple Apprentices at Launch

If a free mentor has >1 apprentice when freemium launches:
1. **Don't break existing relationships** - grandfather them in
2. **Block NEW apprentices** until they upgrade
3. Show message: "You have 3 apprentices. Free mentors can only add 1 new apprentice. Upgrade to add more."

---

## 12. Edge Cases & Business Logic

### 12.1 Mentor Cancels with Multiple Apprentices

**Scenario**: Mentor has 5 apprentices, cancels premium subscription.

**Solution**:
1. Mentor keeps all existing apprentice relationships (don't break)
2. Mentor can VIEW all apprentice reports (read-only for >1)
3. Mentor can only INTERACT with 1 apprentice (most recent? or let them choose)
4. Mentor cannot accept new apprentice invitations
5. Show message explaining the limitation

**UI Indicator**:
```
⚠️ Free Account Limitation
You have 5 apprentices but free accounts can only actively mentor 1.
Upgrade to interact with all apprentices.

[Active Apprentice: John Smith ▼]  [Upgrade Now]
```

**Database**:
```sql
ALTER TABLE mentor_apprentice ADD COLUMN is_active_mentorship BOOLEAN DEFAULT true;
```
When mentor downgrades, set `is_active_mentorship = false` for all but one.

### 12.2 Mentor Gift Seat Expiration

**Scenario**: Mentor buys seats, gives codes to apprentices, then cancels.

**Flow**:
1. RevenueCat webhook fires `CANCELLATION` event
2. Backend marks all `mentor_premium_seats` for this mentor as `is_active = false`
3. Apprentices with `subscription_tier = 'mentor_gifted'` AND seat now inactive → tier becomes `'free'`
4. Next time apprentice opens app, they see free tier

**Grace Period**: Match RevenueCat's grace period (typically 3-16 days for billing retry).

### 12.3 Apprentice Has Both Self-Purchase and Gift

**Scenario**: Apprentice buys their own premium, THEN mentor gives them a seat code.

**Solution**: 
- Don't allow redemption if already premium
- Show message: "You already have Premium! No need to redeem a code."

### 12.4 Apprentice Self-Premium, Mentor is Free

**Scenario**: Premium apprentice with free mentor.

**Behavior**:
- Apprentice can access all assessments ✅
- Mentor can still view apprentice's reports ✅
- No conflict - these are independent

### 12.5 Refund Handling

**Scenario**: User requests refund through Apple/Google.

**Flow**:
1. RevenueCat webhook fires `REFUND` event
2. Immediately set `subscription_tier = 'free'`
3. Log event for audit
4. If mentor, deactivate gifted seats

---

## 13. Additional Premium Feature Recommendations

### High Value (Recommend Adding)

| Feature | Tier | Effort | Value |
|---------|------|--------|-------|
| **Export reports as PDF** | Both | Medium | High - shareable |
| **Email reports to mentor/self** | Both | Low | High - convenience |
| **Progress tracking over time** | Both | Medium | High - shows growth |
| **Comparison across assessments** | Apprentice | Medium | High - insights |
| **Bulk invite apprentices** | Mentor | Low | Medium - efficiency |
| **Custom branding on reports** | Mentor | High | Medium - professional |

### Medium Value (Consider for v1.2)

| Feature | Tier | Effort | Value |
|---------|------|--------|-------|
| Group mentorship (1 mentor: many apprentices at once) | Mentor | High | Medium |
| Scheduled reminders for apprentices | Mentor | Medium | Medium |
| Private notes on individual questions | Both | Medium | Medium |
| Dark mode | Both | Low | Low (free is fine) |

### Not Recommended for Premium

- Basic functionality (view reports, take assessments)
- Connecting with mentor
- Push notifications
- Core app stability

---

## 14. Promotions & Incentive Programs

This section covers time-limited promotions, reward systems, and engagement incentives to drive premium adoption and user engagement.

### 14.1 Launch Merch Giveaway Campaign

#### Campaign Overview

| Aspect | Apprentice Track | Mentor Track |
|--------|------------------|--------------|
| **Goal** | Complete 7 unique assessments | Connect 3 apprentices who each complete 4+ assessments |
| **Winners** | First 20 to achieve | First 20 to achieve |
| **Reward** | Free T-shirt OR Hat (their choice) | Free T-shirt OR Hat (their choice) |
| **Duration** | 30 days from activation | 30 days from activation |
| **Requires Premium** | Yes (7 unique = must be premium) | Yes (3 apprentices = must be premium) |

#### Why This Works

1. **Drives instant premium conversion** - Cannot win without premium
2. **Revenue offsets cost** - At $4.99/month × 20 winners = ~$100 revenue to fund ~$400-600 in merch
3. **Creates urgency** - Limited spots + time limit
4. **Encourages depth** - Not just sign up, but actually USE the app
5. **Social proof** - Winners become ambassadors

#### Reward Fulfillment via Shopify

**Recommended Flow:**
1. User achieves goal in app
2. App shows celebration modal: "🎉 You Won!"
3. Backend generates **unique Shopify discount code** (100% off, one-time use, specific products)
4. Code displayed in app + emailed to user
5. User visits your Shopify store, selects shirt OR hat, applies code
6. You fulfill and ship

**Shopify Setup:**
1. Create a "Promotion Winners" collection with eligible products (shirts, hats)
2. Use Shopify's **Discount Codes** feature:
   - Type: **Percentage** → 100%
   - Applies to: **Specific collections** → "Promotion Winners"
   - Usage limits: **One use per customer** + **Limit to one use total**
3. Generate codes programmatically via **Shopify Admin API**:
   ```
   POST /admin/api/2024-01/price_rules.json
   POST /admin/api/2024-01/price_rules/{id}/discount_codes.json
   ```
4. Or use a Shopify app like **Bulk Discount Code Generator** for manual batches

**Code Format Recommendation:**
```
TROOTH-WIN-{USER_ID_SHORT}-{RANDOM}
Example: TROOTH-WIN-ABC12-X7K9
```

#### Database Schema for Promotions

```sql
-- Promotion campaigns (admin-controlled)
CREATE TABLE promotion_campaigns (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    campaign_type VARCHAR(50) NOT NULL,  -- 'apprentice_assessments', 'mentor_apprentices'
    
    -- Goals
    target_count INT NOT NULL,  -- 7 assessments or 3 apprentices
    apprentice_assessment_requirement INT,  -- For mentor track: each apprentice needs X assessments
    
    -- Limits
    max_winners INT NOT NULL,  -- 20
    current_winners INT DEFAULT 0,
    
    -- Timing
    starts_at TIMESTAMP NOT NULL,
    ends_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT false,
    
    -- Reward
    reward_description VARCHAR(255),  -- "Free T-shirt or Hat"
    shopify_collection_id VARCHAR(100),
    
    created_at TIMESTAMP DEFAULT NOW(),
    created_by UUID REFERENCES users(id)
);

-- User progress toward promotion goals
CREATE TABLE promotion_progress (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id) NOT NULL,
    campaign_id UUID REFERENCES promotion_campaigns(id) NOT NULL,
    
    -- Progress tracking
    current_progress INT DEFAULT 0,  -- Assessments completed or qualifying apprentices
    progress_details JSONB,  -- {"assessment_ids": [...]} or {"apprentice_ids": [...]}
    
    -- Completion
    is_completed BOOLEAN DEFAULT false,
    completed_at TIMESTAMP,
    
    -- Reward
    reward_code VARCHAR(50),  -- Shopify discount code
    reward_claimed BOOLEAN DEFAULT false,
    reward_claimed_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(user_id, campaign_id)
);

-- Promotion winners (separate for easy querying/display)
CREATE TABLE promotion_winners (
    id UUID PRIMARY KEY,
    campaign_id UUID REFERENCES promotion_campaigns(id) NOT NULL,
    user_id UUID REFERENCES users(id) NOT NULL,
    position INT NOT NULL,  -- 1st, 2nd, ... 20th
    won_at TIMESTAMP DEFAULT NOW(),
    reward_code VARCHAR(50) NOT NULL,
    
    UNIQUE(campaign_id, user_id),
    UNIQUE(campaign_id, position)
);
```

#### API Endpoints for Promotions

```python
# Public (authenticated users)
GET  /promotions/active                    # List active campaigns user can participate in
GET  /promotions/{campaign_id}/progress    # User's progress toward a specific campaign
GET  /promotions/{campaign_id}/leaderboard # How many spots left, recent winners (anonymized)

# Triggered automatically (internal)
POST /promotions/check-progress            # Called after assessment completion or apprentice milestone

# Admin
POST   /admin/promotions                   # Create new campaign
PATCH  /admin/promotions/{id}              # Update campaign (activate, extend, etc.)
GET    /admin/promotions/{id}/winners      # List all winners with details
POST   /admin/promotions/{id}/generate-codes  # Bulk generate Shopify codes
```

#### Frontend UI Components

**1. Progress Banner (Dashboard)**
```
┌─────────────────────────────────────────────────────────────┐
│  🎁 LAUNCH GIVEAWAY                           12 spots left │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━░░░░░░░  5/7 assessments        │
│  Complete 2 more assessments to win free merch!             │
│                                              [View Details] │
└─────────────────────────────────────────────────────────────┘
```

**2. Winner Celebration Modal**
```
┌─────────────────────────────────────────────────────────────┐
│                          🎉                                 │
│                     YOU WON!                                │
│                                                             │
│   You're one of the first 20 apprentices to complete        │
│   7 assessments! Claim your free T-shirt or Hat.            │
│                                                             │
│   Your code: TROOTH-WIN-ABC12-X7K9                          │
│                                                             │
│   [Copy Code]              [Go to Store]                    │
│                                                             │
│   Code also sent to your email.                             │
└─────────────────────────────────────────────────────────────┘
```

**3. Campaign Details Screen**
- Full rules and requirements
- Current progress with visual indicator
- Time remaining
- Spots remaining
- Recent winners (anonymized: "Someone just won! 19 spots left")

#### Progress Tracking Logic

**Apprentice Track:**
```python
def check_apprentice_promotion_progress(user_id: str, db: Session):
    campaign = get_active_campaign('apprentice_assessments', db)
    if not campaign or campaign.current_winners >= campaign.max_winners:
        return  # No active campaign or already full
    
    # Count unique completed assessments (not drafts)
    completed_assessments = db.query(Assessment).filter(
        Assessment.user_id == user_id,
        Assessment.status == 'done'
    ).distinct(Assessment.template_id).all()
    
    unique_count = len(completed_assessments)
    assessment_ids = [a.id for a in completed_assessments]
    
    # Update progress
    progress = get_or_create_progress(user_id, campaign.id, db)
    progress.current_progress = unique_count
    progress.progress_details = {"assessment_ids": assessment_ids}
    
    # Check for win
    if unique_count >= campaign.target_count and not progress.is_completed:
        award_promotion_win(user_id, campaign, progress, db)
    
    db.commit()
```

**Mentor Track:**
```python
def check_mentor_promotion_progress(mentor_id: str, db: Session):
    campaign = get_active_campaign('mentor_apprentices', db)
    if not campaign or campaign.current_winners >= campaign.max_winners:
        return
    
    # Get all apprentices for this mentor
    apprentices = get_mentor_apprentices(mentor_id, db)
    
    # Count apprentices who have completed X+ assessments
    qualifying_apprentices = []
    for apprentice in apprentices:
        completed_count = db.query(Assessment).filter(
            Assessment.user_id == apprentice.id,
            Assessment.status == 'done'
        ).distinct(Assessment.template_id).count()
        
        if completed_count >= campaign.apprentice_assessment_requirement:  # e.g., 4
            qualifying_apprentices.append(apprentice.id)
    
    # Update progress
    progress = get_or_create_progress(mentor_id, campaign.id, db)
    progress.current_progress = len(qualifying_apprentices)
    progress.progress_details = {"apprentice_ids": qualifying_apprentices}
    
    # Check for win
    if len(qualifying_apprentices) >= campaign.target_count and not progress.is_completed:  # e.g., 3
        award_promotion_win(mentor_id, campaign, progress, db)
    
    db.commit()
```

#### Fraud Prevention Analysis

**Concern: Fake accounts to win multiple times**

| Attack | Impact | Mitigation |
|--------|--------|------------|
| One person creates multiple accounts | Medium - each account needs premium ($5+) | Cost prohibitive + email verification |
| Mentor invites fake apprentices | Medium - apprentices need to complete 4 assessments each | Time consuming + those accounts need to pay too |
| Shared accounts | Low - still only 1 win per account | ToS violation, but hard to detect |
| Bot automation | Low - requires payment, completing assessments takes time | Rate limiting, CAPTCHA if needed |

**Built-in Fraud Deterrents:**
1. **Premium requirement** - Each winning account paid $5-50. Gaming it costs money.
2. **Assessment completion** - Takes real time and effort (15-30 min each)
3. **Email verification** - Already required for Firebase auth
4. **One code per user** - Even with multiple accounts, each code = one item
5. **Manual fulfillment** - You'll see shipping addresses; duplicates are obvious
6. **Limited quantity** - Only 40 total winners (20 + 20), limits exposure

**Additional Measures (if needed):**
- Require phone verification for promotion eligibility
- Flag accounts created during promotion window for review
- Limit one shipping address per unique winner
- Review winner list before generating codes

**Recommendation:** Start with built-in deterrents. The cost/effort to game the system ($5+ per account, 3.5+ hours of assessments) isn't worth a $20 shirt. Monitor first campaign, add friction only if abuse detected.

#### Shopify Integration Details

**Option A: Manual Code Generation (Simpler)**
1. Before campaign, generate 50 codes in Shopify (extra for buffer)
2. Store codes in database table
3. When user wins, assign next available code
4. Simpler but requires pre-planning

**Option B: Shopify API Integration (Automated)**
1. Backend calls Shopify API when user wins
2. Dynamically generates unique code
3. More complex but fully automated

**Shopify API Setup:**
```python
# Backend service for Shopify integration
import requests

class ShopifyService:
    def __init__(self):
        self.shop_url = "your-store.myshopify.com"
        self.api_key = os.getenv("SHOPIFY_API_KEY")
        self.api_secret = os.getenv("SHOPIFY_API_SECRET")
        self.access_token = os.getenv("SHOPIFY_ACCESS_TOKEN")
    
    def create_discount_code(self, user_id: str, collection_id: str) -> str:
        """Create a 100% off single-use discount code"""
        
        # First create a price rule
        price_rule = {
            "price_rule": {
                "title": f"TROOTH-WIN-{user_id[:6]}",
                "target_type": "line_item",
                "target_selection": "entitled",
                "allocation_method": "across",
                "value_type": "percentage",
                "value": "-100.0",
                "usage_limit": 1,
                "entitled_collection_ids": [collection_id],
                "starts_at": datetime.utcnow().isoformat(),
            }
        }
        
        response = requests.post(
            f"https://{self.shop_url}/admin/api/2024-01/price_rules.json",
            json=price_rule,
            headers={"X-Shopify-Access-Token": self.access_token}
        )
        price_rule_id = response.json()["price_rule"]["id"]
        
        # Then create the discount code
        code_suffix = generate_random_string(4)
        code = f"TROOTH-WIN-{user_id[:6].upper()}-{code_suffix}"
        
        discount_code = {
            "discount_code": {"code": code}
        }
        
        requests.post(
            f"https://{self.shop_url}/admin/api/2024-01/price_rules/{price_rule_id}/discount_codes.json",
            json=discount_code,
            headers={"X-Shopify-Access-Token": self.access_token}
        )
        
        return code
```

**Shopify Permissions Needed:**
- `write_price_rules` - Create discount rules
- `write_discounts` - Create discount codes
- `read_products` - Verify collection exists

---

### 14.2 Future Incentive Programs

These are additional incentive ideas to implement after the initial launch campaign. Prioritized by impact and complexity.

#### Tier 1: High Impact, Lower Effort

**1. Referral Program**
| Aspect | Details |
|--------|---------|
| Mechanic | User shares unique link → friend signs up + goes premium → both get reward |
| Referrer Reward | 1 month free premium OR $5 credit toward next subscription |
| Referee Reward | 7-day free trial extended to 14 days |
| Tracking | Generate unique referral code per user, track in database |
| Fraud Prevention | Referee must stay premium for 30+ days for referrer to get credit |

**2. Streak Rewards**
| Aspect | Details |
|--------|---------|
| Mechanic | Complete at least 1 assessment per week for consecutive weeks |
| Milestones | 4 weeks → badge, 8 weeks → 1 week free premium, 12 weeks → exclusive content |
| UI | Streak counter on dashboard, warning if streak about to break |
| Premium Required | No - drives engagement that leads to premium |

**3. Early Bird Pricing (Launch Only)**
| Aspect | Details |
|--------|---------|
| Mechanic | First 100 yearly subscribers get discounted rate |
| Pricing | $50/year → $40/year for first year |
| Urgency | "87 of 100 spots remaining" counter |
| Implementation | Separate product ID in RevenueCat, or discount code |

#### Tier 2: Medium Impact, Medium Effort

**4. Founding Member Badge**
| Aspect | Details |
|--------|---------|
| Mechanic | Anyone who goes premium in first 90 days gets permanent badge |
| Badge | Displays on profile, visible to mentor/apprentice |
| Exclusive | Can never be earned after window closes |
| Cost | Free to you, high perceived value |

**5. Assessment Completion Milestones**
| Aspect | Details |
|--------|---------|
| Milestones | 3 assessments → "Seeker" badge, 7 → "Student", 15 → "Scholar", All → "Master" |
| Rewards | Badges + at "Scholar" level, unlock 1 premium assessment permanently for free |
| Gamification | Progress bar, celebration animations |

**6. Mentor Impact Score**
| Aspect | Details |
|--------|---------|
| Mechanic | Track mentor effectiveness: apprentice completion rates, engagement |
| Display | "Your apprentices have completed 23 assessments" |
| Social Proof | "Top 10% of Mentors" badge for high performers |
| Premium Tie-in | Full analytics dashboard only for premium mentors |

#### Tier 3: Consider for Future

**7. Group Challenges**
- Mentor + all their apprentices complete a "Bible book of the month"
- Leaderboard of mentor groups
- Winning group gets recognition + small prize

**8. Seasonal Campaigns**
- Lent Challenge: Complete specific assessments during Lent
- Advent Devotional: Daily micro-assessments in December
- Back-to-School: Student-focused promotion in August

**9. Church/Organization Bulk Licensing**
- Churches buy licenses for their entire youth group
- Volume discount pricing
- Admin dashboard for church leaders
- Separate revenue stream

---

### 14.3 Promotion Administration

#### Admin Dashboard Requirements

**Campaign Management:**
- Create new campaigns with all parameters
- Activate/deactivate campaigns
- Extend campaign deadlines
- Adjust winner limits (carefully)
- View real-time progress/leaderboard

**Winner Management:**
- View all winners with contact info
- Generate Shopify codes (bulk or individual)
- Mark codes as sent/redeemed
- Export winner list for fulfillment

**Analytics:**
- Campaign performance metrics
- Conversion rate (free → premium during campaign)
- Cost analysis (prizes given vs. revenue generated)

#### Notification System

**In-App Notifications:**
- "New promotion available!"
- "You're 2 assessments away from winning!"
- "Only 5 spots left!"
- "🎉 You won! Claim your prize."

**Email Notifications:**
- Campaign launch announcement
- Weekly progress update (if enrolled)
- Winner notification with code
- Reminder: "Your code expires in 7 days"

**Push Notifications (if enabled):**
- "Last 3 spots in the giveaway! Complete 1 more assessment to win."

---

### 14.4 Promotion Campaign Checklist

#### Pre-Launch (1 week before)
- [ ] Database tables created and tested
- [ ] API endpoints implemented
- [ ] Frontend progress UI built
- [ ] Winner celebration modal built
- [ ] Shopify integration tested
- [ ] Discount codes ready (if pre-generating)
- [ ] Email templates created
- [ ] Campaign created in admin (but not activated)

#### Launch Day
- [ ] Activate campaign in admin
- [ ] Send announcement email to all users
- [ ] Post on social media
- [ ] In-app banner goes live
- [ ] Monitor for issues

#### During Campaign
- [ ] Daily: Check winner count and code generation
- [ ] Daily: Monitor for abuse/fraud
- [ ] Weekly: Social media update on spots remaining
- [ ] If issues: Adjust or pause campaign

#### Post-Campaign
- [ ] Generate final winner report
- [ ] Send all discount codes (if not automated)
- [ ] Fulfill merch orders via Shopify
- [ ] Analyze campaign performance
- [ ] Document learnings for next campaign

---

## 14. Implementation Phases

### Phase 1: Backend Foundation (1-2 weeks)
- [ ] Create database migrations
- [ ] Add subscription fields to User model
- [ ] Create `mentor_premium_seats` table
- [ ] Create `subscription_events` table
- [ ] Create `free_assessments` config table
- [ ] Add `/subscriptions/webhook` endpoint (stubbed)
- [ ] Add subscription tier checks to assessment endpoints
- [ ] Add apprentice limit check to mentor endpoints
- [ ] Add admin endpoints for manual premium grants
- [ ] Write tests for all new endpoints

### Phase 2: RevenueCat Integration (1 week)
- [ ] Create RevenueCat account
- [ ] Configure iOS products in App Store Connect
- [ ] Configure Android products in Google Play Console
- [ ] Connect stores to RevenueCat
- [ ] Create Offerings in RevenueCat
- [ ] Add RevenueCat SDK to Flutter app
- [ ] Implement `SubscriptionService` wrapper
- [ ] Configure webhooks to backend
- [ ] Implement webhook handler

### Phase 3: Frontend UI (1-2 weeks)
- [ ] Create `SubscriptionScreen` (purchase flow)
- [ ] Create `MentorSeatsScreen` (seat management)
- [ ] Create `RedeemCodeScreen` (code entry)
- [ ] Add lock icons to assessment list
- [ ] Add upgrade prompts throughout app
- [ ] Add subscription status to profile/settings
- [ ] Handle subscription state in app (caching, refresh)
- [ ] Add restore purchases button

### Phase 4: Testing & Polish (1 week)
- [ ] Set up sandbox testers (iOS)
- [ ] Set up license testers (Android)
- [ ] Test all purchase flows
- [ ] Test cancellation/expiration flows
- [ ] Test mentor seat gifting
- [ ] Test edge cases (see Section 12)
- [ ] Fix bugs from testing
- [ ] Polish UI/UX

### Phase 5: Launch Prep (1 week)
- [ ] Update App Store screenshots (if showing premium UI)
- [ ] Update App Store description to mention premium
- [ ] Submit for review with subscription products
- [ ] Prepare customer support for subscription questions
- [ ] Plan announcement to beta testers
- [ ] Set up analytics/monitoring for subscriptions

**Total Estimated Time: 5-7 weeks**

---

## 15. Checklist

### Store Setup
- [ ] Apple Developer Program active ($99/year)
- [ ] Google Play Developer account active ($25 one-time)
- [ ] App Store Connect: Subscription group created
- [ ] App Store Connect: 4 subscription products created
- [ ] App Store Connect: Sandbox testers added
- [ ] App Store Connect: Server notifications configured
- [ ] Google Play: 4 subscription products created
- [ ] Google Play: License testers added
- [ ] Google Play: Real-time notifications configured

### RevenueCat Setup
- [ ] RevenueCat account created
- [ ] iOS app connected
- [ ] Android app connected
- [ ] Products imported
- [ ] Offerings configured
- [ ] Entitlements configured
- [ ] Webhooks configured

### Backend
- [ ] Database migrations created and tested
- [ ] Subscription endpoints implemented
- [ ] Webhook handler implemented
- [ ] Assessment access control implemented
- [ ] Mentor limit implemented
- [ ] Admin endpoints implemented
- [ ] All tests passing

### Frontend
- [ ] RevenueCat SDK integrated
- [ ] SubscriptionService implemented
- [ ] Purchase screens implemented
- [ ] Lock UI implemented
- [ ] Upgrade prompts implemented
- [ ] Restore purchases working

### Testing
- [ ] iOS sandbox purchases working
- [ ] Android test purchases working
- [ ] Cancellation flow tested
- [ ] Seat gifting flow tested
- [ ] All edge cases tested

### Launch
- [ ] Beta testers notified of changes
- [ ] Store listings updated
- [ ] App submitted for review
- [ ] Customer support prepared
- [ ] Analytics configured

---

## Appendix: RevenueCat Dashboard Configuration

### Entitlements

| Identifier | Description |
|------------|-------------|
| `mentor_premium` | Access to mentor premium features |
| `apprentice_premium` | Access to apprentice premium features |

### Offerings

| Identifier | Packages |
|------------|----------|
| `mentor_offering` | mentor_premium_monthly, mentor_premium_yearly |
| `apprentice_offering` | apprentice_premium_monthly, apprentice_premium_yearly |

### Products Mapping

| Store | Product ID | Entitlement |
|-------|------------|-------------|
| App Store | mentor_premium_monthly | mentor_premium |
| App Store | mentor_premium_yearly | mentor_premium |
| App Store | apprentice_premium_monthly | apprentice_premium |
| App Store | apprentice_premium_yearly | apprentice_premium |
| Play Store | mentor_premium_monthly | mentor_premium |
| Play Store | mentor_premium_yearly | mentor_premium |
| Play Store | apprentice_premium_monthly | apprentice_premium |
| Play Store | apprentice_premium_yearly | apprentice_premium |

---

*Document created: January 5, 2026*
*Last updated: January 5, 2026*
