import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trooth_assessment/models/gift_code_redemption.dart';
import 'package:trooth_assessment/services/api_service.dart';
import 'package:trooth_assessment/utils/errors.dart';
import 'package:trooth_assessment/widgets/gift_code_sheet.dart';

void main() {
  const success = GiftCodeRedemption(success: true, message: 'Premium access activated!', mentorName: 'Marcus');

  late List<String> calls;
  late List<Object> reported;

  setUp(() {
    calls = [];
    reported = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    required Future<GiftCodeRedemption> Function(String) redeem,
    void Function(GiftCodeRedemption)? onRedeemed,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: GiftCodeForm(
          onRedeemed: onRedeemed ?? (_) {},
          redeem: (c) {
            calls.add(c);
            return redeem(c);
          },
          reportError: (e, st) => reported.add(e),
        ),
      ),
    ));
  }

  final field = find.byKey(const Key('giftCodeField'));
  final redeemButton = find.byKey(const Key('giftCodeRedeem'));

  Future<void> submit(WidgetTester tester, String text) async {
    await tester.enterText(field, text);
    await tester.pump();
    await tester.tap(redeemButton);
    await tester.pumpAndSettle();
  }

  testWidgets('incomplete code shows a hint and makes no call', (tester) async {
    await pump(tester, redeem: (_) async => success);
    await submit(tester, 'a7k9');
    expect(find.text('That code looks incomplete.'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('success sends the canonical code and calls back once', (tester) async {
    final got = <GiftCodeRedemption>[];
    await pump(tester, redeem: (_) async => success, onRedeemed: got.add);
    await submit(tester, 'a7k9 m2p4');
    expect(calls, ['TROOTH-A7K9-M2P4']);
    expect(got, [success]);
  });

  testWidgets('business failure shows the server message and keeps the input', (tester) async {
    await pump(tester, redeem: (_) async => const GiftCodeRedemption(success: false, message: 'This code has expired.'));
    await submit(tester, 'TROOTH-A7K9-M2P4');
    expect(find.text('This code has expired.'), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, 'TROOTH-A7K9-M2P4');
    expect(reported, isEmpty);
  });

  testWidgets('403 shows the apprentice-only message', (tester) async {
    await pump(tester, redeem: (_) async => throw ApiException(403, ''));
    await submit(tester, 'a7k9m2p4');
    expect(find.text('Gift codes are for apprentice accounts.'), findsOneWidget);
    expect(reported, isEmpty);
  });

  testWidgets('other errors show friendlyError and are reported', (tester) async {
    final error = ApiException(500, '');
    await pump(tester, redeem: (_) async => throw error);
    await submit(tester, 'a7k9m2p4');
    expect(find.text(friendlyError(error)), findsOneWidget);
    expect(reported, [error]);
  });

  testWidgets('no overflow at 1.5x text', (tester) async {
    await pump(tester, redeem: (_) async => const GiftCodeRedemption(success: false, message: 'This code has already been redeemed.'), scale: 1.5);
    await submit(tester, 'a7k9m2p4');
    expect(tester.takeException(), isNull);
  });
}
