# Sign in with Apple Fix - Testing Guide

## What Changed

### The Problem
Apple rejected the app because after signing in with Apple (which provides name/email), the app was still showing a signup form asking for that same information. This violates Apple's Human Interface Guidelines.

### The Solution
1. **New screen**: `RoleSelectionScreen` - only asks for role (Mentor/Apprentice), not name/email
2. **Updated OAuth flow**: Extracts name/email directly from OAuth provider
3. **No signup form**: OAuth users never see the traditional signup form

## Flow Comparison

### Before (Rejected by Apple ❌)
```
User clicks "Sign in with Apple"
  ↓
Apple provides: name, email
  ↓
App routes to SignupScreen
  ↓
Form shows with PRE-FILLED name/email (but still shows form!)
  ↓
User has to click through form
  ↓
Apple Review: "Why are you asking for info we already gave you?"
```

### After (Compliant ✅)
```
User clicks "Sign in with Apple"
  ↓
Apple provides: name, email
  ↓
App routes to RoleSelectionScreen
  ↓
User only sees: "Are you a Mentor or Apprentice?"
  ↓
User selects role → Done! No form!
  ↓
Account created with Apple's data
```

## Testing Checklist

### Test 1: New User - Sign in with Apple
1. Delete app from device/simulator
2. Fresh install
3. Tap "Sign in with Apple"
4. Complete Apple authentication
5. ✅ Should see: Role selection screen (NOT signup form)
6. ✅ Screen should say: "Welcome, [Your First Name]!"
7. Select role (Mentor or Apprentice)
8. ✅ Should go directly to dashboard
9. Check Firestore - user doc should have correct name/email/role

### Test 2: New User - Sign in with Google
1. Delete app
2. Fresh install
3. Tap "Sign in with Google"
4. Complete Google authentication
5. ✅ Should see: Role selection screen
6. ✅ Name from Google should be displayed
7. Select role
8. ✅ Should go to dashboard

### Test 3: Existing User - Sign in with Apple
1. Use account that already exists
2. Tap "Sign in with Apple"
3. ✅ Should go DIRECTLY to dashboard (skip role selection)

### Test 4: Traditional Email/Password Signup (Should Still Work)
1. Delete app
2. Fresh install
3. Tap "Sign Up" button (NOT OAuth buttons)
4. ✅ Should see: Full signup form with name, email, password fields
5. Fill out form manually
6. Select role
7. ✅ Should create account and go to dashboard

### Test 5: Apple's Special Case - Name Only on First Sign-In
**Important**: Apple only provides givenName/familyName the FIRST time a user signs in. Subsequent sign-ins only provide email.

1. Use BRAND NEW Apple ID (never used with this app before)
2. Sign in with Apple
3. ✅ App should capture and save the full name
4. Sign out
5. Sign in again with same Apple ID
6. ✅ Should still show correct name (from Firebase user.displayName)

## Key Technical Details

### Apple Sign-In Name Extraction
```dart
// Apple provides givenName/familyName only on FIRST authentication
final parts = <String>[];
if (appleCredential.givenName?.isNotEmpty == true) {
  parts.add(appleCredential.givenName!);
}
if (appleCredential.familyName?.isNotEmpty == true) {
  parts.add(appleCredential.familyName!);
}
displayName = parts.join(' ');

// Save to Firebase so it's available on future logins
await userCredential.user?.updateDisplayName(displayName);
```

### Fallback Logic
If no name is provided (rare edge case):
- Use email prefix: `john@example.com` → `john`
- Or use generic: `User`

## What to Watch For

### Potential Issues
1. **No name from Apple**: If Apple user denies name sharing, app uses email prefix
2. **Empty email**: Shouldn't happen with Apple, but has fallback
3. **Role not selected**: Button is disabled until role selected

### Error Scenarios
- Network failure during role submission → Shows error, allows retry
- Backend API failure → Logs error, continues (Firestore is source of truth)

## Success Criteria for App Review

✅ **User never sees a form asking for name/email after OAuth**  
✅ **Role selection is clearly different from "signup"**  
✅ **Existing users have seamless login experience**  
✅ **Email/password signup still works normally**

## Version Info
- **Version**: 1.0.5+5
- **Branch**: develop/freemium
- **Files Changed**:
  - `lib/screens/role_selection_screen.dart` (NEW)
  - `lib/screens/simple_login_screen.dart` (updated OAuth handlers)
  - `pubspec.yaml` (version bump)

## Next Steps

1. ✅ Test locally on iOS simulator with Apple Sign-In
2. ✅ Test on physical device if possible
3. ✅ Test both new and existing user flows
4. ✅ Build and upload to TestFlight
5. ✅ Submit for App Store review
6. Wait for approval (should pass now - complies with Apple HIG)
