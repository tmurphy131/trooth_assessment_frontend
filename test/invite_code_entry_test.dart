import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trooth_assessment/models/invite_redemption.dart';
import 'package:trooth_assessment/services/api_service.dart';
import 'package:trooth_assessment/widgets/invite_code_entry.dart';

void main() {
  const redemption = InviteRedemption(mentorId: 'm1', mentorName: 'Marcus', relationship: InviteRelationship.created);

  Future<void> pump(
    WidgetTester tester, {
    required Future<InviteRedemption> Function(String) redeem,
    void Function(InviteRedemption)? onRedeemed,
  }) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(body: InviteCodeEntry(redeem: redeem, onRedeemed: onRedeemed ?? (_) {})),
      ));

  final field = find.byKey(const Key('inviteCodeField'));
  final join = find.byKey(const Key('inviteCodeJoin'));

  String fieldText(WidgetTester tester) => tester.widget<TextField>(field).controller!.text;
  bool joinEnabled(WidgetTester tester) => tester.widget<ElevatedButton>(join).onPressed != null;

  testWidgets('uppercases as typed', (tester) async {
    await pump(tester, redeem: (_) async => redemption);
    await tester.enterText(field, 'k7qm 3xpr');
    expect(fieldText(tester), 'K7QM 3XPR');
  });

  testWidgets('Join is disabled when empty or whitespace', (tester) async {
    await pump(tester, redeem: (_) async => redemption);
    expect(joinEnabled(tester), isFalse);
    await tester.enterText(field, '   ');
    await tester.pump();
    expect(joinEnabled(tester), isFalse);
    await tester.enterText(field, 'K7QM');
    await tester.pump();
    expect(joinEnabled(tester), isTrue);
  });

  testWidgets('error shows the status message and keeps the text', (tester) async {
    await pump(tester, redeem: (_) async => throw ApiException(404, 'x'));
    await tester.enterText(field, 'abcd-efgh');
    await tester.pump();
    await tester.tap(join);
    await tester.pumpAndSettle();
    expect(find.text("We couldn't find that code. Check it and try again."), findsOneWidget);
    expect(fieldText(tester), 'ABCD-EFGH');
    expect(joinEnabled(tester), isTrue);
  });

  testWidgets('success calls onRedeemed once and clears the field', (tester) async {
    final received = <InviteRedemption>[];
    String? sent;
    await pump(tester, redeem: (c) async {
      sent = c;
      return redemption;
    }, onRedeemed: received.add);
    await tester.enterText(field, ' k7qm-3xpr ');
    await tester.pump();
    await tester.tap(join);
    await tester.pumpAndSettle();
    expect(received, [redemption]);
    expect(sent, 'K7QM-3XPR');
    expect(fieldText(tester), isEmpty);
  });

  testWidgets('caps input at 32 characters', (tester) async {
    await pump(tester, redeem: (_) async => redemption);
    await tester.enterText(field, 'A' * 40);
    await tester.pump();
    expect(fieldText(tester).length, 32);
  });

  testWidgets('no overflow at 1.5x text on a phone width', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(360, 800), textScaler: TextScaler.linear(1.5)),
        child: Scaffold(body: InviteCodeEntry(redeem: (_) async => throw ApiException(400, 'x'), onRedeemed: (_) {})),
      ),
    ));
    await tester.enterText(field, 'K7QM-3XPR');
    await tester.pump();
    await tester.tap(join);
    await tester.pumpAndSettle();
    expect(find.textContaining("can't be used"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
