// Device tests against a real backend (dev by default). Credentials come from
// --dart-define so nothing is committed:
//
//   flutter test integration_test/session_flows_test.dart -d <simulator> \
//     --dart-define=TEST_MENTOR_EMAIL=... --dart-define=TEST_APPRENTICE_EMAIL=... \
//     --dart-define=TEST_PASSWORD=...

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trooth_assessment/main.dart' as app;
import 'package:trooth_assessment/screens/apprentice_dashboard_new.dart';
import 'package:trooth_assessment/screens/auth_gate.dart';
import 'package:trooth_assessment/screens/mentor_dashboard_new.dart';
import 'package:trooth_assessment/screens/simple_login_screen.dart';
import 'package:trooth_assessment/services/push_notification_service.dart';
import 'package:trooth_assessment/services/subscription_service.dart';
import 'package:trooth_assessment/utils/logout_util.dart';

const mentorEmail = String.fromEnvironment('TEST_MENTOR_EMAIL');
const apprenticeEmail = String.fromEnvironment('TEST_APPRENTICE_EMAIL');
const password = String.fromEnvironment('TEST_PASSWORD');

/// Pumps until [finder] matches or [timeout] passes. Network-backed screens
/// never "settle", so pumpAndSettle isn't usable here.
Future<void> pumpUntil(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 45)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> waitFor(WidgetTester tester, bool Function() condition, String what,
    {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (condition()) return;
  }
  throw TestFailure('Timed out waiting for $what');
}

Future<void> signInThroughUi(WidgetTester tester, String email) async {
  await pumpUntil(tester, find.byType(SimpleLoginScreen));
  await tester.pump(const Duration(seconds: 1)); // let the route transition finish
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), password);
  FocusManager.instance.primaryFocus?.unfocus(); // keyboard can cover the button
  await tester.pump(const Duration(milliseconds: 500));
  final button = find.text('Sign In');
  await tester.ensureVisible(button);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(button);
}

Future<void> backToLogin(WidgetTester tester) async {
  await signOutEverywhere(); // the router redirects signed-out users to /login
  await pumpUntil(tester, find.byType(SimpleLoginScreen));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    if (mentorEmail.isEmpty || apprenticeEmail.isEmpty || password.isEmpty) {
      fail('Pass TEST_MENTOR_EMAIL, TEST_APPRENTICE_EMAIL and TEST_PASSWORD via --dart-define');
    }
  });

  testWidgets('sign-in, account switch and offline launch', (tester) async {
    // main() installs its own FlutterError.onError; restore the test
    // framework's handler afterwards or the binding reports a failure.
    final testErrorHandler = FlutterError.onError;
    final testErrorWidgetBuilder = ErrorWidget.builder;
    addTearDown(() {
      FlutterError.onError = testErrorHandler;
      ErrorWidget.builder = testErrorWidgetBuilder;
    });
    app.main();
    // Signed out, the router goes straight to /login; signed in, AuthGate.
    final authGate = find.byType(AuthGate);
    final login = find.byType(SimpleLoginScreen);
    await pumpUntil(tester, find.byWidgetPredicate((_) => authGate.evaluate().isNotEmpty || login.evaluate().isNotEmpty));
    FlutterError.onError = testErrorHandler;

    // Start from a clean, signed-out state.
    if (FirebaseAuth.instance.currentUser != null) await backToLogin(tester);

    // 1. Mentor signs in through the UI; RevenueCat identity follows.
    await signInThroughUi(tester, mentorEmail);
    await pumpUntil(tester, find.byType(MentorDashboardNew));
    final mentorUid = FirebaseAuth.instance.currentUser!.uid;
    await waitFor(tester, () => SubscriptionService().isInitialized, 'subscriptions (mentor)');
    expect(await Purchases.appUserID, mentorUid, reason: 'RevenueCat should identify the mentor');

    // 2. Switch accounts on the same device. Before the fix, RevenueCat kept
    //    the first user's identity because configure() ran twice.
    await backToLogin(tester);
    await signInThroughUi(tester, apprenticeEmail);
    await pumpUntil(tester, find.byType(ApprenticeDashboardNew));
    final apprenticeUid = FirebaseAuth.instance.currentUser!.uid;
    expect(apprenticeUid, isNot(mentorUid));
    await waitFor(tester, () => SubscriptionService().isInitialized, 'subscriptions (apprentice)');
    expect(await Purchases.appUserID, apprenticeUid, reason: 'RevenueCat should follow the new user');

    // 2b. Notifications: never a cold system prompt. If permission hasn't
    //     been asked, the explanation sheet appears (after the tutorial);
    //     "Not now" snoozes it.
    if (await PushNotificationService().getPermissionStatus() == AuthorizationStatus.notDetermined) {
      final primer = find.text('Stay in the loop');
      final skip = find.text('SKIP');
      await pumpUntil(tester, find.byWidgetPredicate((_) => primer.evaluate().isNotEmpty || skip.evaluate().isNotEmpty));
      if (skip.evaluate().isNotEmpty) await tester.tap(skip.first);
      await pumpUntil(tester, primer);
      expect(await PushNotificationService().getPermissionStatus(), AuthorizationStatus.notDetermined,
          reason: 'the system prompt must not appear before the user opts in');
      await tester.tap(find.text('Not now'));
      await tester.pump(const Duration(seconds: 1));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('notification_primer_snoozed_until'), isNotNull);
    }

    // 3. Offline launch with an empty Firestore cache: AuthGate should use the
    //    role cached at sign-in instead of showing the login screen.
    final firestore = FirebaseFirestore.instance;
    await firestore.terminate();
    await firestore.clearPersistence();
    await FirebaseFirestore.instance.disableNetwork();

    await tester.pumpWidget(const MaterialApp(home: AuthGate()));
    await pumpUntil(tester, find.byType(ApprenticeDashboardNew));
    expect(find.byType(SimpleLoginScreen), findsNothing);

    // 4. Same, but with no cached role either: retry screen, then recovery.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_role_$apprenticeUid');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const MaterialApp(home: AuthGate()));
    await pumpUntil(tester, find.text("Can't connect right now"));
    expect(find.byType(SimpleLoginScreen), findsNothing);

    await FirebaseFirestore.instance.enableNetwork();
    await tester.tap(find.text('Try again'));
    await pumpUntil(tester, find.byType(ApprenticeDashboardNew));

    await signOutEverywhere();
    // The binding checks these before teardown callbacks run.
    FlutterError.onError = testErrorHandler;
    ErrorWidget.builder = testErrorWidgetBuilder;
  });
}
