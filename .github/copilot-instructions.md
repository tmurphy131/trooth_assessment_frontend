# T[root]H Discipleship - AI Agent Instructions (Frontend)

## Project Overview
T[root]H is a spiritual mentorship platform with a **Flutter mobile frontend** (this repo) and a **FastAPI backend** (sibling repo: `trooth_assessment_backend`). The app enables mentor-apprentice relationships, AI-scored spiritual assessments, mentorship agreements, and progress tracking.

**Key Concept**: This is a dual-role app (Mentor/Apprentice) with Firebase Auth + Firestore for onboarding, but all core data lives in the backend PostgreSQL database.

## Architecture & Data Flow

### Authentication Chain
1. **Firebase Auth** handles login/signup (`lib/screens/simple_login_screen.dart`)
2. **Firestore** stores `role` (mentor/apprentice) + `onboarded` flag during first-time setup
3. **Backend API** uses Firebase ID tokens for authentication (Bearer token in headers)
4. User context flows: Firebase → `ApiService` → Backend → Role-specific UI

### API Communication Pattern
- **Singleton service**: `lib/services/api_service.dart` (2000+ lines)
- All HTTP calls funnel through `ApiService()` with automatic token refresh
- Backend base URL: `https://trooth-discipleship-api.onlyblv.com` (dev environment)
- Token management: Call `await _maybeRefreshToken()` before API calls; token expires hourly
- Every request logs via `dev.log()` for debugging network issues

### Feature Architecture
- **Feature-based structure**: `lib/features/assessments/` contains models, screens, data repos, widgets for assessment feature
- **Repository pattern**: Data repos (`assessments_repository.dart`) abstract API calls from UI
- **Provider pattern**: State management uses Flutter Provider package
- **Screen naming**: `*_screen.dart` for full pages, `*_widget.dart` for reusable components

### Backend Integration Points
Key endpoints (see `MOBILE_API_GUIDE.md` in backend repo):
- Authentication: `POST /users/`, `GET /apprentice/me`, `GET /mentor/my-apprentices`
- Assessments: `POST /assessment-drafts/start`, `PATCH /assessment-drafts` (auto-save), `POST /assessment-drafts/submit`
- Templates: `GET /templates/published` (apprentice view), `GET /admin/templates` (admin view)
- Invitations: `POST /invitations/invite-apprentice`, `POST /invitations/accept-invite`
- Agreements: `POST /agreements/send`, `PATCH /agreements/{id}/sign-apprentice`

## Critical Development Patterns

### Theme & Styling
- **Theme definition**: `lib/theme.dart` - black (#1A1A1A), gold/amber (0xFFD4AF37), grey (#424242)
- **Fonts**: Unkempt (logo), Poppins (body text) - loaded via `google_fonts` package
- **AppBar style**: Always centered title, black background, gold text
- **Button style**: ElevatedButton with amber/gold colors, rounded corners (BorderRadius.circular(12))

### Error Handling & User Feedback
- **Loading states**: Show CircularProgressIndicator (amber color) during async operations
- **Error display**: Use SnackBar for transient errors, AlertDialog for critical failures
- **Retry logic**: Wrap network calls in try-catch, provide "Retry" button on failures
- **Validation**: Form validation before API calls (email format, required fields)

### Assessment Workflow (Critical Business Logic)
1. **Start**: Apprentice selects published template → `POST /assessment-drafts/start` → returns draft_id
2. **Auto-save**: On answer change → debounced `PATCH /assessment-drafts` with answers dict
3. **Submit**: Validates completeness → `POST /assessment-drafts/submit` → triggers backend AI scoring
4. **Polling**: Frontend polls `/assessments/{id}/status` for scoring completion (status: "done")
5. **Report**: Mentor views via `/mentor/submitted-drafts/{id}` → renders `MentorReportV2Screen`

### Navigation Patterns
- **Auth flow**: `SimpleLoginScreen` → check Firestore `onboarded` → if false: onboarding, else: role dashboard
- **Role routing**: After auth, route to `MentorDashboardNew` or `ApprenticeDashboardNew` based on Firestore `role`
- **Deep links**: `uni_links` package handles invite tokens (`/invite?token=...`) → `AgreementSignPublicScreen`

## Testing & Quality

### Running Tests
```bash
# Backend tests (in trooth_assessment_backend repo)
pytest -q

# Flutter tests (this repo)
flutter test

# Integration testing
flutter drive --target=test_driver/app.dart
```

### Common Test Patterns (Backend Reference)
- Tests use SQLite in-memory DB with `StaticPool` for connection sharing
- `conftest.py` provides fixtures: `client`, `admin_user`, `mentor_user`, `apprentice_user`
- Auth mocking: Override `get_current_user` dependency with test user
- Example: `tests/test_invitations.py`, `tests/test_agreements.py`

## Build & Deployment

### Flutter Build Commands
```bash
# iOS simulator
flutter run -d iPhone

# Android emulator (use 10.0.2.2 for localhost backend)
flutter run -d emulator-5554

# Web (use host machine IP for Docker backend)
flutter run -d chrome --web-port=5000

# Production builds
flutter build ios --release
flutter build appbundle --release  # Android
```

### iOS-Specific Issues
- **Codesign issues**: Multiple scripts exist (`fix_ios_signing.sh`, `reset_flutter_ios.sh`) - iOS build has been problematic
- **Embed frameworks order matters**: See extensive logs (`flutter_build*.log`) documenting "Embed Pods Framework" phase issues
- **Workaround pattern**: Clean build folder, delete Pods, `flutter pub get`, rebuild

### Firebase Hosting (Web)
```bash
firebase deploy --only hosting
```
Config: `firebase.json` points to `build/web`

## Project-Specific Gotchas

### 1. Dual Repository Structure
- **This repo**: Flutter frontend (`trooth_assessment`)
- **Sibling repo**: FastAPI backend (`trooth_assessment_backend`)
- When adding features, ALWAYS check if backend endpoint exists (see `MOBILE_API_GUIDE.md`)

### 2. Role-Based UI Rendering
- **Never** show mentor features to apprentices and vice versa
- Check `user.role` from Firestore or backend before rendering sections
- Examples: Mentor sees "Invite Apprentices", apprentice sees "View Invitations"

### 3. Agreement System Complexity
- Agreements require 3 signatures: mentor, apprentice, parent (if under 18)
- Status flow: `draft` → `awaiting_apprentice` → `awaiting_parent` → `fully_signed`
- Token-based signing: Each signer gets a unique token for public-access signing page
- UI must show different states: pending, awaiting you, awaiting parent, fully signed

### 4. Mentor Reports (Multi-Version System)
- **V1 reports**: Legacy system (older assessments)
- **V2 reports**: New format with improved AI scoring feedback (`MentorReportV2Screen`)
- Check assessment `scores` JSON structure to determine version
- V2 includes per-question feedback, rubric scoring, top-3 categories

### 5. Assessment Template vs Assessment Instance
- **Template**: Blueprint created by admin/mentor (reusable)
- **Draft**: In-progress assessment instance (apprentice working)
- **Assessment**: Completed & scored instance (immutable record)
- Templates have `published` flag - only published ones appear to apprentices

## Documentation Resources

**Critical docs in this repo**:
- `REQUIREMENTS.md` - Original product spec
- `MENTOR_SECTION_REQUIREMENTS.md` - Detailed mentor UI requirements
- `INVITE_SYSTEM_SUMMARY.md` - Invitation flow implementation

**Critical docs in backend repo** (`trooth_assessment_backend`):
- `MOBILE_API_GUIDE.md` - Complete API reference for frontend integration
- `DEPLOYMENT.md` - Backend deployment (Cloud Run) with exact commands
- `AI_SCORING_DETAILS.md` - How OpenAI scoring works (understand for debugging)
- `MULTI_MENTOR_DESIGN.md` - Future multi-mentor support (not yet implemented)

## Common Tasks

### Adding a New Screen
1. Create `lib/screens/my_feature_screen.dart`
2. Import theme: `import '../theme.dart';`
3. Use Scaffold with AppBar (centered title, theme colors)
4. Add navigation in dashboard: `Navigator.push(context, MaterialPageRoute(builder: (_) => MyFeatureScreen()))`

### Adding a New API Endpoint Integration
1. Check if backend endpoint exists (see backend `app/routes/` or `MOBILE_API_GUIDE.md`)
2. Add method in `ApiService`: `Future<Map<String, dynamic>> myEndpoint()`
3. Implement with `_request()` helper (handles auth, logging, errors)
4. Create data model in `lib/models/` if needed
5. Use in screen with try-catch error handling

### Debugging Backend Connection
1. Check `ApiService._base` URL is correct for your environment
2. Verify Firebase token: `print(await FirebaseAuth.instance.currentUser?.getIdToken())`
3. Check backend logs: `docker logs <container>` or Cloud Run logs
4. Use `dev.log()` in `ApiService` - all requests/responses logged
5. Test with curl: `curl -H "Authorization: Bearer $TOKEN" https://trooth-discipleship-api.onlyblv.com/health`

## Security Considerations
- **Never log Firebase tokens** in production (masked in `ApiService._headers()`)
- **Role validation**: Always validate on backend - frontend checks are UI-only
- **Token refresh**: Tokens expire hourly - `ApiService` auto-refreshes before expiry
- **Public routes**: Only `/invite?token=...` and login/signup should work unauthenticated
