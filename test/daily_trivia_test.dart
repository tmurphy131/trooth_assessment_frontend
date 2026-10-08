import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trooth_assessment/models/daily_trivia.dart';
import 'package:trooth_assessment/services/api_service.dart';
import 'package:trooth_assessment/widgets/daily_streak_view.dart';
import 'package:trooth_assessment/widgets/daily_trivia_modal.dart';
import 'package:trooth_assessment/widgets/daily_trivia_profile_card.dart';
import 'package:trooth_assessment/widgets/daily_trivia_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';

final today = DateTime(2026, 11, 5); // a Thursday

const mcQuestion = {
  'date': '2026-11-05',
  'category': 'old_testament',
  'category_label': 'Old Testament',
  'difficulty': 'challenger',
  'difficulty_label': 'Challenger',
  'question_type': 'multiple_choice',
  'question_text': 'Who built the ark?',
  'option_a': 'Moses',
  'option_b': 'Noah',
  'option_c': 'Abraham',
  'option_d': 'David',
};

Map<String, dynamic> streakJson({
  int current = 0,
  List<Map<String, String>> calendar = const [],
  Map<String, dynamic>? reward,
  Map<String, dynamic>? next = const {'tier': 45, 'days_remaining': 45, 'percent': 15, 'percent_if_perfect': 25},
  bool answeredToday = false,
}) =>
    {
      'current_streak': current,
      'longest_streak': current,
      'freezes_available': 1,
      'max_freezes': 2,
      'perfect_run': true,
      'answered_today': answeredToday,
      'streak_started_on': current > 0 ? '2026-10-01' : null,
      'calendar': calendar,
      'next_milestone': next,
      'active_reward': reward,
    };

const answerJson = {
  'selected_option': 'a',
  'correct': false,
  'correct_option': 'b',
  'answered_at': '2026-11-05T15:00:00Z',
};

const rewardJson = {
  'id': 7,
  'tier': 45,
  'percent': 25,
  'perfect': true,
  'status': 'active',
  'discount_code': 'TROOTH-STREAK45-ABC123',
  'expires_at': '2027-01-04T15:00:00Z',
  'shop_url': 'https://shop.example.com',
};

Widget host(Widget child, {double textScale = 1.0}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(390, 844), textScaler: TextScaler.linear(textScale)),
        child: Scaffold(backgroundColor: Colors.black, body: child),
      ),
    );

void main() {
  group('models', () {
    test('a daily question never carries its answer, even if the server sent one', () {
      final q = DailyQuestion.fromJson({...mcQuestion, 'correct_option': 'b'});
      expect(q.options, {'a': 'Moses', 'b': 'Noah', 'c': 'Abraham', 'd': 'David'});
      expect(q.categoryLabel, 'Old Testament');
      expect(q.difficultyLabel, 'Challenger');
      expect(q.date, today);
    });

    test('true/false questions have two options', () {
      final q = DailyQuestion.fromJson({
        ...mcQuestion,
        'question_type': 'true_false',
        'option_a': 'True',
        'option_b': 'False',
        'option_c': null,
        'option_d': null,
      });
      expect(q.options, {'a': 'True', 'b': 'False'});
    });

    test('streak parses calendar, milestone and reward', () {
      final s = DailyStreak.fromJson(streakJson(current: 12, calendar: [
        {'date': '2026-11-03', 'status': 'freeze'},
        {'date': '2026-11-04', 'status': 'wrong'},
        {'date': '2026-11-05', 'status': 'correct'},
      ], reward: rewardJson));
      expect(s.current, 12);
      expect(s.showMonth, isTrue);
      expect(s.calendar[DateTime(2026, 11, 3)], DayStatus.freeze);
      expect(s.calendar[DateTime(2026, 11, 4)], DayStatus.wrong);
      expect(s.calendar[today], DayStatus.correct);
      expect(s.nextMilestone!.percentIfPerfect, 25);
      expect(s.reward!.status, DailyRewardStatus.active);
      expect(s.reward!.code, 'TROOTH-STREAK45-ABC123');
    });

    test('week view under 7 days, month view from 7', () {
      expect(DailyStreak.fromJson(streakJson(current: 6)).showMonth, isFalse);
      expect(DailyStreak.fromJson(streakJson(current: 7)).showMonth, isTrue);
    });
  });

  group('DailyTriviaApi', () {
    final api = ApiService();
    late http.Request lastRequest;

    setUp(() {
      api.setAuthForTesting(authorization: ({bool force = false}) async => null, canRetryAuth: () => false);
    });

    void respondWith(int status, Object body) {
      api.httpClient = MockClient((req) async {
        lastRequest = req;
        return http.Response(jsonEncode(body), status);
      });
    }

    test('today', () async {
      respondWith(200, {'question': mcQuestion, 'answer': null, 'streak': streakJson()});
      final t = await api.dailyTriviaToday();
      expect(lastRequest.method, 'GET');
      expect(lastRequest.url.path, endsWith('/trivia/daily/today'));
      expect(t.answer, isNull);
      expect(t.question.text, 'Who built the ark?');
    });

    test('answer posts the date and letter', () async {
      respondWith(200, {
        'question': mcQuestion,
        'answer': answerJson,
        'streak': streakJson(current: 1, answeredToday: true),
        'freezes_used': 0,
        'streak_reset': false,
        'freeze_earned': false,
        'new_reward': null,
      });
      final o = await api.dailyTriviaAnswer(questionDate: today, option: 'a');
      expect(lastRequest.url.path, endsWith('/trivia/daily/today/answer'));
      expect(jsonDecode(lastRequest.body), {'question_date': '2026-11-05', 'option': 'a'});
      expect(o.answer.correctOption, 'b');
      expect(o.streak.current, 1);
    });

    test('409 question_expired becomes DailyQuestionExpiredException', () async {
      respondWith(409, {'detail': 'question_expired'});
      expect(api.dailyTriviaAnswer(questionDate: today, option: 'a'),
          throwsA(isA<DailyQuestionExpiredException>()));
    });

    test('409 already_answered stays an ApiException', () async {
      respondWith(409, {'detail': 'already_answered'});
      expect(api.dailyTriviaAnswer(questionDate: today, option: 'a'),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
    });

    test('timezone puts the IANA name', () async {
      respondWith(200, {'timezone': 'America/Chicago'});
      await api.setMyTimezone('America/Chicago');
      expect(lastRequest.method, 'PUT');
      expect(lastRequest.url.path, endsWith('/users/me/timezone'));
      expect(jsonDecode(lastRequest.body), {'timezone': 'America/Chicago'});
    });
  });

  group('DailyStreakView', () {
    testWidgets('short streak shows this week', (tester) async {
      final s = DailyStreak.fromJson(streakJson(current: 2, calendar: [
        {'date': '2026-11-04', 'status': 'correct'},
        {'date': '2026-11-05', 'status': 'wrong'},
      ]));
      await tester.pumpWidget(host(DailyStreakView(streak: s, today: today)));
      expect(find.text('2 days in a row'), findsOneWidget);
      expect(find.text('November 2026'), findsNothing);
      expect(find.bySemanticsLabel('Wednesday, November 4: answered correctly'), findsOneWidget);
      expect(find.bySemanticsLabel('Thursday, November 5: answered, today'), findsOneWidget);
      expect(find.bySemanticsLabel('Monday, November 2: not answered'), findsOneWidget);
      expect(find.textContaining('2/45 days → 15% off merch (25% if every answer is right)'), findsOneWidget);
    });

    testWidgets('long streak shows the month with freezes', (tester) async {
      final s = DailyStreak.fromJson(streakJson(current: 9, calendar: [
        {'date': '2026-11-03', 'status': 'freeze'},
        {'date': '2026-11-05', 'status': 'correct'},
      ]));
      await tester.pumpWidget(host(SingleChildScrollView(child: DailyStreakView(streak: s, today: today))));
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.bySemanticsLabel('Tuesday, November 3: covered by a streak freeze'), findsOneWidget);
      expect(find.bySemanticsLabel('Monday, November 30: upcoming'), findsOneWidget);
    });

    testWidgets('active reward shows code and shop', (tester) async {
      final s = DailyStreak.fromJson(streakJson(current: 45, reward: rewardJson,
          next: const {'tier': 60, 'days_remaining': 15, 'percent': 35, 'percent_if_perfect': 45}));
      await tester.pumpWidget(host(SingleChildScrollView(child: DailyStreakView(streak: s, today: today))));
      expect(find.text('TROOTH-STREAK45-ABC123'), findsOneWidget);
      expect(find.byTooltip('Copy code'), findsOneWidget);
      expect(find.text('Shop merch'), findsOneWidget);
    });

    testWidgets('pending reward says the code is on its way', (tester) async {
      final s = DailyStreak.fromJson(streakJson(current: 45, reward: {
        ...rewardJson,
        'status': 'pending',
        'discount_code': null,
        'expires_at': null,
      }));
      await tester.pumpWidget(host(SingleChildScrollView(child: DailyStreakView(streak: s, today: today))));
      expect(find.textContaining('being created'), findsOneWidget);
      expect(find.text('Shop merch'), findsNothing);
    });

    testWidgets('after 90 days there is no next milestone', (tester) async {
      final s = DailyStreak.fromJson(streakJson(current: 95, next: null));
      await tester.pumpWidget(host(SingleChildScrollView(child: DailyStreakView(streak: s, today: today))));
      expect(find.textContaining('top streak reward'), findsOneWidget);
    });
  });

  group('DailyTriviaModal', () {
    final api = ApiService();
    final requests = <http.Request>[];

    setUp(() {
      requests.clear();
      api.setAuthForTesting(authorization: ({bool force = false}) async => null, canRetryAuth: () => false);
      api.httpClient = MockClient((req) async {
        requests.add(req);
        if (req.url.path.endsWith('/answer')) {
          return http.Response(
              jsonEncode({
                'question': mcQuestion,
                'answer': answerJson,
                'streak': streakJson(current: 3, answeredToday: true),
                'freezes_used': 1,
                'streak_reset': false,
                'freeze_earned': false,
                'new_reward': null,
              }),
              200);
        }
        return http.Response(jsonEncode({'question': mcQuestion, 'answer': null, 'streak': streakJson(current: 2)}), 200);
      });
    });

    Future<void> pumpModal(WidgetTester tester, {double textScale = 1.0}) async {
      await tester.pumpWidget(host(DailyTriviaModal(today: today), textScale: textScale));
      await tester.pumpAndSettle();
    }

    testWidgets('shows category, level and the options', (tester) async {
      await pumpModal(tester);
      expect(find.text('Old Testament'), findsOneWidget);
      expect(find.text('Challenger'), findsOneWidget);
      expect(find.text('Who built the ark?'), findsOneWidget);
      for (final o in ['Moses', 'Noah', 'Abraham', 'David']) {
        expect(find.text(o), findsOneWidget);
      }
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.textContaining('2-day streak'), findsOneWidget);
    });

    testWidgets('answering shows the result and the streak', (tester) async {
      await pumpModal(tester);
      await tester.tap(find.text('Moses'));
      await tester.pumpAndSettle();
      expect(jsonDecode(requests.last.body), {'question_date': '2026-11-05', 'option': 'a'});
      expect(find.textContaining('The answer was "Noah"'), findsOneWidget);
      expect(find.textContaining('A streak freeze covered'), findsOneWidget);
      expect(find.text('3 days in a row'), findsOneWidget);
      expect(find.bySemanticsLabel('B: Noah, correct answer'), findsOneWidget);
      expect(find.bySemanticsLabel('A: Moses, your answer, incorrect'), findsOneWidget);

      // Locked once answered
      final before = requests.length;
      await tester.tap(find.text('Abraham'));
      await tester.pumpAndSettle();
      expect(requests.length, before);
    });

    testWidgets('reopening after answering shows the question, the answer and the streak', (tester) async {
      api.httpClient = MockClient((req) async => http.Response(
          jsonEncode({
            'question': mcQuestion,
            'answer': answerJson,
            'streak': streakJson(current: 3, answeredToday: true),
          }),
          200));
      await pumpModal(tester);
      expect(find.text('Who built the ark?'), findsOneWidget);
      expect(find.bySemanticsLabel('A: Moses, your answer, incorrect'), findsOneWidget);
      expect(find.bySemanticsLabel('B: Noah, correct answer'), findsOneWidget);
      expect(find.text('3 days in a row'), findsOneWidget);
    });

    testWidgets('fits at 1.5x text scale', (tester) async {
      await pumpModal(tester, textScale: 1.5);
      await tester.tap(find.text('Moses'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('DailyTriviaProfileCard', () {
    final api = ApiService();

    setUp(() {
      api.setAuthForTesting(authorization: ({bool force = false}) async => null, canRetryAuth: () => false);
    });

    testWidgets('shows the streak and whether today is answered', (tester) async {
      api.httpClient = MockClient((req) async => http.Response(
          jsonEncode(streakJson(current: 12, answeredToday: true)), 200));
      await tester.pumpWidget(host(const DailyTriviaProfileCard()));
      await tester.pumpAndSettle();
      expect(find.text('Daily Question & Streak'), findsOneWidget);
      expect(find.text('🔥 12 days in a row · answered today'), findsOneWidget);
    });

    testWidgets('tapping opens the daily question', (tester) async {
      api.httpClient = MockClient((req) async => http.Response(
          jsonEncode(req.url.path.endsWith('/streak')
              ? streakJson(current: 3, answeredToday: true)
              : {'question': mcQuestion, 'answer': answerJson, 'streak': streakJson(current: 3, answeredToday: true)}),
          200));
      await tester.pumpWidget(host(const DailyTriviaProfileCard()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daily Question & Streak'));
      await tester.pumpAndSettle();
      expect(find.text('Daily Question'), findsOneWidget);
      expect(find.text('Who built the ark?'), findsOneWidget);
      // Close it so the next test can open one (only one modal at a time)
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('a failed load still shows the entry', (tester) async {
      api.httpClient = MockClient((_) async => http.Response('{}', 500));
      await tester.pumpWidget(host(const DailyTriviaProfileCard()));
      await tester.pumpAndSettle();
      expect(find.text("See today's question and your streak"), findsOneWidget);
    });
  });

  group('DailyTriviaPill', () {
    final api = ApiService();
    var answered = false;

    setUp(() {
      answered = false;
      SharedPreferences.setMockInitialValues({});
      api.setAuthForTesting(authorization: ({bool force = false}) async => null, canRetryAuth: () => false);
      api.httpClient = MockClient((req) async {
        if (req.url.path.endsWith('/answer')) {
          answered = true;
          return http.Response(
              jsonEncode({
                'question': mcQuestion,
                'answer': answerJson,
                'streak': streakJson(current: 13, answeredToday: true),
                'freezes_used': 0,
                'streak_reset': false,
                'freeze_earned': false,
                'new_reward': null,
              }),
              200);
        }
        return http.Response(
            jsonEncode({
              'question': mcQuestion,
              'answer': answered ? answerJson : null,
              'streak': streakJson(current: answered ? 13 : 12, answeredToday: answered),
            }),
            200);
      });
    });

    Widget dashboard() => MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: const SizedBox.expand(),
            floatingActionButton: const DailyTriviaPill(nudgeFor: Duration(seconds: 1)),
          ),
        );

    testWidgets('shows the streak, nudges once, then the nudge fades', (tester) async {
      await tester.pumpWidget(dashboard());
      await tester.pumpAndSettle();
      expect(find.text('🔥 12 · Daily question'), findsOneWidget);
      expect(find.byTooltip("Answer today's daily question"), findsOneWidget);
      // No modal opens on its own
      expect(find.text('Who built the ark?'), findsNothing);

      final bubble = find.text("Today's question is ready!");
      double opacity() => tester.widget<AnimatedOpacity>(
          find.ancestor(of: bubble, matching: find.byType(AnimatedOpacity))).opacity;
      expect(opacity(), 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(opacity(), 0);

      // Same day again: no second nudge
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(dashboard());
      await tester.pumpAndSettle();
      expect(opacity(), 0);
    });

    testWidgets('hidden once today is answered', (tester) async {
      answered = true;
      await tester.pumpWidget(dashboard());
      await tester.pumpAndSettle();
      expect(find.textContaining('Daily question'), findsNothing);
    });

    testWidgets('tap opens the question; answering makes the pill go away', (tester) async {
      await tester.pumpWidget(dashboard());
      await tester.pumpAndSettle();
      await tester.tap(find.text('🔥 12 · Daily question'));
      await tester.pumpAndSettle();
      expect(find.text('Who built the ark?'), findsOneWidget);

      await tester.tap(find.text('Moses'));
      await tester.pumpAndSettle();
      expect(find.text('13 days in a row'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Daily question'), findsNothing);
    });
  });
}
