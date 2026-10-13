import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trooth_assessment/widgets/invite_code_share.dart';

void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: InviteCodeShare(code: 'K7QM-3XPR', mentorName: 'Marcus', large: true)),
      ));

  testWidgets('shows the code with Copy and Share buttons', (tester) async {
    await pump(tester);
    expect(find.text('K7QM-3XPR'), findsOneWidget);
    expect(find.byTooltip('Copy code'), findsOneWidget);
    expect(find.byTooltip('Share code'), findsOneWidget);
    for (final tip in ['Copy code', 'Share code']) {
      final size = tester.getSize(find.byTooltip(tip));
      expect(size.width >= 48 && size.height >= 48, isTrue, reason: '$tip tap target');
    }
  });

  testWidgets('Copy puts the code on the clipboard and confirms', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await pump(tester);
    await tester.tap(find.byTooltip('Copy code'));
    await tester.pumpAndSettle();
    expect(copied, 'K7QM-3XPR');
    expect(find.text('Code copied'), findsOneWidget);
  });
}
