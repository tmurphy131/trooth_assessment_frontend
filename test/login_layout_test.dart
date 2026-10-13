import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:trooth_assessment/screens/simple_login_screen.dart';

// Layout only (spec 004 US3). The screen touches Firebase only when a sign-in button
// is pressed, so these tests never tap one.
void main() {
  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SimpleLoginScreen()));
    await tester.pumpAndSettle();
  }

  final apple = find.byType(SignInWithAppleButton);
  final google = find.text('Sign in with Google');
  final continueWithEmail = find.text('Continue with email');

  testWidgets('iOS: Apple first, then Google, then email option; no fields yet', (tester) async {
    await pumpLogin(tester);
    expect(apple, findsOneWidget);
    expect(google, findsOneWidget);
    expect(continueWithEmail, findsOneWidget);
    expect(tester.getTopLeft(apple).dy, lessThan(tester.getTopLeft(google).dy));
    expect(tester.getTopLeft(google).dy, lessThan(tester.getTopLeft(continueWithEmail).dy));
    expect(find.byType(TextFormField), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android: Google and email option, no Apple', (tester) async {
    await pumpLogin(tester);
    expect(apple, findsNothing);
    expect(google, findsOneWidget);
    expect(continueWithEmail, findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Continue with email shows the form; Back returns to the options', (tester) async {
    await pumpLogin(tester);
    await tester.tap(continueWithEmail);
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text("Don't have an account? Sign up"), findsOneWidget);
    expect(apple, findsNothing);

    await tester.tap(find.text('Back to sign-in options'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(apple, findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('no overflow at 1.5x text (both modes)', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: const SimpleLoginScreen(),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(continueWithEmail);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
