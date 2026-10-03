import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trooth_assessment/widgets/trivia_competition_banner.dart';

Map<String, dynamic> _competition(String status, {Map<String, dynamic> extra = const {}}) {
  final now = DateTime.now().toUtc();
  return {
    'slug': 'launch-2026',
    'name': '60-Day Launch Competition',
    'status': status,
    'difficulty': 'challenger',
    'starts_at': now.add(const Duration(days: 2, hours: 3)).toIso8601String(),
    'ends_at': now.add(const Duration(days: 62)).toIso8601String(),
    'server_now': now.toIso8601String(),
    'prizes': [
      {'place': 1, 'amount': 59, 'label': '\$59 off — any merch item free'},
      {'place': 2, 'amount': 30, 'label': '\$30 off ONLY BLV merch'},
      {'place': 3, 'amount': 15, 'label': '\$15 off ONLY BLV merch'},
    ],
    'standings': [],
    'my_rank': null,
    'my_score': null,
    'is_eligible': true,
    'finalized': false,
    'winners': [],
    'my_prize': null,
    ...extra,
  };
}

Future<void> _pump(WidgetTester tester, Map<String, dynamic> competition) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: TriviaCompetitionBanner(competition: competition, onPhaseChanged: () {}),
      ),
    ),
  ));
}

void main() {
  testWidgets('upcoming shows a countdown to the start and the prizes', (tester) async {
    await _pump(tester, _competition('upcoming'));
    expect(find.text('COMING SOON'), findsOneWidget);
    expect(find.text('STARTS IN'), findsOneWidget);
    expect(find.text('02'), findsWidgets); // 2 days
    expect(find.text('Any item free'), findsOneWidget);
    expect(find.text('\$15 off'), findsOneWidget);
  });

  testWidgets('active shows standings and the viewer rank', (tester) async {
    await _pump(tester, _competition('active', extra: {
      'standings': [
        {'rank': 1, 'user_id': 'a', 'display_name': 'Ann', 'score': 4200, 'streak_length': 20},
        {'rank': 2, 'user_id': 'b', 'display_name': 'Ben', 'score': 3100, 'streak_length': 15},
      ],
      'my_rank': 2,
      'my_score': 3100,
    }));
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('ENDS IN'), findsOneWidget);
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('4,200'), findsOneWidget);
    expect(find.text('Your rank: #2 · 3,100 pts'), findsOneWidget);
  });

  testWidgets('ended shows the podium and the winner their code', (tester) async {
    await _pump(tester, _competition('ended', extra: {
      'finalized': true,
      'winners': [
        {'place': 1, 'display_name': 'Ann', 'score': 4200, 'is_me': true},
        {'place': 2, 'display_name': 'Ben', 'score': 3100, 'is_me': false},
      ],
      'my_prize': {
        'place': 1,
        'label': '\$59 off — any merch item free',
        'discount_code': 'TROOTH-1ST-ABC123',
        'code_expires_at': '2027-03-31T05:00:00Z',
        'shop_url': 'https://shop.onlyblv.com',
      },
    }));
    expect(find.text('FINAL'), findsOneWidget);
    expect(find.text('Ann (you)'), findsOneWidget);
    expect(find.text('Ben'), findsOneWidget);
    expect(find.text('TROOTH-1ST-ABC123'), findsOneWidget);
    expect(find.text('Shop Now'), findsOneWidget);
    expect(find.textContaining('STARTS IN'), findsNothing);
  });

  testWidgets('ended before finalization says winners are coming', (tester) async {
    await _pump(tester, _competition('ended'));
    expect(find.textContaining('Winners are being finalized'), findsOneWidget);
  });
}
