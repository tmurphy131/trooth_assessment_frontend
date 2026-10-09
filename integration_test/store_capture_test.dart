// App Store capture harness for the "Bible Trivia Challenge" custom product page.
//
// Renders the real trivia screens on a simulator, but every API call is answered
// with FICTIONAL demo data (no backend, no real users), and pauses at each shot
// so a host script can take a simulator screenshot (status bar included):
//
//   flutter test integration_test/store_capture_test.dart -d <simulator> \
//     --dart-define=CAPTURE_MODE=screens   # or: video
//
// Each pause prints `CAPTURE:<name>`; the host runs `xcrun simctl io <id> screenshot`.
// Store art must not show prices or discount codes, so the demo data has none.
//
// Afterwards run `flutter build ios --config-only` (flutter test repoints Generated.xcconfig).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trooth_assessment/models/trivia_session.dart';
import 'package:trooth_assessment/screens/trivia_challenge_detail_screen.dart';
import 'package:trooth_assessment/screens/trivia_game_screen.dart';
import 'package:trooth_assessment/screens/trivia_home_screen.dart';
import 'package:trooth_assessment/screens/trivia_leaderboard_screen.dart';
import 'package:trooth_assessment/services/api_service.dart';
import 'package:trooth_assessment/theme.dart';
import 'package:trooth_assessment/widgets/daily_trivia_modal.dart';

const mode = String.fromEnvironment('CAPTURE_MODE', defaultValue: 'screens');

final now = DateTime.now();
String day(int offset) {
  final d = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ---------- Fictional demo data ----------

const dailyQuestion = {
  'category': 'old_testament',
  'category_label': 'Old Testament',
  'difficulty': 'challenger',
  'difficulty_label': 'Challenger',
  'question_type': 'multiple_choice',
  'question_text': 'Which prophet was taken up to heaven in a whirlwind?',
  'option_a': 'Elisha',
  'option_b': 'Elijah',
  'option_c': 'Isaiah',
  'option_d': 'Enoch',
};

Map<String, dynamic> streak({required int current, required bool answeredToday}) => {
      'current_streak': current,
      'longest_streak': 31,
      'freezes_available': 1,
      'max_freezes': 2,
      'perfect_run': false,
      'answered_today': answeredToday,
      'streak_started_on': day(-(current - 1)),
      'calendar': [
        for (var i = answeredToday ? 0 : 1; i < current; i++)
          {'date': day(-i), 'status': i == 9 ? 'freeze' : 'correct'},
        for (var i = current + 1; i < current + 6; i++) {'date': day(-i), 'status': i.isEven ? 'correct' : 'wrong'},
      ],
      // No milestone or reward: their text includes discount amounts
      'next_milestone': null,
      'active_reward': null,
    };

final competition = {
  'slug': 'launch-2026',
  'name': '60-Day Launch Competition',
  'status': 'active',
  'difficulty': 'challenger',
  'starts_at': now.subtract(const Duration(days: 8)).toUtc().toIso8601String(),
  'ends_at': now.add(const Duration(days: 52, hours: 6)).toUtc().toIso8601String(),
  'server_now': now.toUtc().toIso8601String(),
  'prizes': <Map<String, dynamic>>[],
  'standings': [
    {'rank': 1, 'user_id': 'u1', 'display_name': 'Grace M.', 'score': 14900, 'streak_length': 38},
    {'rank': 2, 'user_id': 'u2', 'display_name': 'Elijah R.', 'score': 12400, 'streak_length': 33},
    {'rank': 3, 'user_id': 'me', 'display_name': 'Jordan D.', 'score': 11200, 'streak_length': 31},
    {'rank': 4, 'user_id': 'u4', 'display_name': 'Hannah K.', 'score': 9800, 'streak_length': 28},
    {'rank': 5, 'user_id': 'u5', 'display_name': 'Josiah P.', 'score': 7600, 'streak_length': 24},
  ],
  'my_rank': 3,
  'my_score': 11200,
  'is_eligible': true,
  'finalized': false,
  'winners': <Map<String, dynamic>>[],
  'my_prize': null,
};

final leaderboard = [
  for (final (i, e) in [
    ('Grace M.', 14900, 38), ('Elijah R.', 12400, 33), ('Jordan D.', 11200, 31), ('Hannah K.', 9800, 28),
    ('Josiah P.', 7600, 24), ('Naomi L.', 6900, 22), ('Caleb T.', 5400, 19), ('Priscilla W.', 4700, 17),
    ('Silas B.', 3900, 15), ('Lydia F.', 3100, 13), ('Micah S.', 2600, 11), ('Ruth A.', 1900, 9),
  ].indexed)
    {'rank': i + 1, 'user_id': 'u$i', 'display_name': e.$1, 'score': e.$2, 'streak_length': e.$3},
];

final challenges = [
  {
    'id': 'demo-1', 'challenger_name': 'Jordan D.', 'challenged_name': 'Marcus J.', 'category': 'new_testament',
    'difficulty': 'challenger', 'num_questions': 20, 'status': 'active', 'current_question_index': 6,
    'challenger_score': 900, 'challenged_score': 700, 'my_role': 'challenger', 'is_my_turn': true,
    'created_at': now.subtract(const Duration(days: 1)).toUtc().toIso8601String(),
    'expires_at': now.add(const Duration(days: 6)).toUtc().toIso8601String(),
  },
];

Map<String, dynamic> challengeQuestion(int i, String text, List<String> opts, String correct,
        {String? mine, String? theirs, bool revealed = true}) =>
    {
      'question_index': i,
      'question': {
        'id': 100 + i, 'question_text': text, 'question_type': 'multiple_choice',
        'option_a': opts[0], 'option_b': opts[1], 'option_c': opts[2], 'option_d': opts[3],
      },
      'my_answer': mine,
      'opponent_answer': revealed ? theirs : null,
      'my_correct': mine == null ? null : mine == correct,
      'opponent_correct': revealed && theirs != null ? theirs == correct : null,
      'revealed': revealed,
    };

final challengeDetail = {
  ...challenges.first,
  'challenger_id': 'me',
  'challenged_id': 'u9',
  'winner_id': null,
  'questions': [
    challengeQuestion(0, 'Where was Jesus born?', ['Nazareth', 'Bethlehem', 'Jerusalem', 'Capernaum'], 'b', mine: 'b', theirs: 'b'),
    challengeQuestion(1, 'Who wrote most of the letters in the New Testament?', ['Peter', 'John', 'Paul', 'James'], 'c', mine: 'c', theirs: 'c'),
    challengeQuestion(2, 'Which disciple walked on water toward Jesus?', ['Andrew', 'Peter', 'Thomas', 'Philip'], 'b', mine: 'b', theirs: 'a'),
    challengeQuestion(3, 'How many loaves fed the five thousand?', ['Two', 'Five', 'Seven', 'Twelve'], 'b', mine: 'b', theirs: 'b'),
    challengeQuestion(4, 'Who was the tax collector who climbed a tree to see Jesus?', ['Matthew', 'Zacchaeus', 'Levi', 'Nicodemus'], 'b', mine: 'b', theirs: 'b'),
    challengeQuestion(5, 'On what road was Saul converted?', ['Road to Emmaus', 'Road to Jericho', 'Road to Damascus', 'Road to Gaza'], 'c', mine: 'c', theirs: 'a'),
    challengeQuestion(6, 'Which book tells of the early church at Pentecost?', ['Romans', 'Acts', 'Hebrews', 'Galatians'], 'b', revealed: false),
  ],
};

Map<String, dynamic> session(int streakLen, int score, {int questionNumber = 15}) => {
      'session_id': 'demo-session',
      'status': 'active',
      'score': score,
      'streak': streakLen,
      'correct_count': streakLen,
      'grace_tokens': streakLen ~/ 10,
      'grace_tokens_used': 0,
      'question_number': questionNumber,
      'total_questions': 120,
      'time_limit_ms': 30000,
      'question': {
        'index': questionNumber - 1, 'id': 501, 'question_text': 'Who was the first king of Israel?',
        'question_type': 'multiple_choice', 'option_a': 'David', 'option_b': 'Saul', 'option_c': 'Samuel', 'option_d': 'Solomon',
      },
      'last_answer': null,
      'grace_expires_in_ms': null,
      'result': null,
    };

// ---------- Fake server ----------

var dailyAnswered = false;

http.Response ok(Object body) => http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

Future<http.Response> fakeServer(http.Request req) async {
  final path = req.url.path;
  if (path.endsWith('/trivia/daily/today')) {
    return ok({'question': {...dailyQuestion, 'date': day(0)}, 'answer': null, 'streak': streak(current: 22, answeredToday: false)});
  }
  if (path.endsWith('/trivia/daily/today/answer')) {
    dailyAnswered = true;
    return ok({
      'question': {...dailyQuestion, 'date': day(0)},
      'answer': {'selected_option': 'b', 'correct': true, 'correct_option': 'b'},
      'streak': streak(current: 23, answeredToday: true),
      'freezes_used': 0, 'streak_reset': false, 'freeze_earned': false, 'new_reward': null,
    });
  }
  if (path.endsWith('/trivia/daily/streak')) {
    return ok(dailyAnswered ? streak(current: 23, answeredToday: true) : streak(current: 22, answeredToday: false));
  }
  if (path.endsWith('/trivia/competition')) return ok(competition);
  if (path.endsWith('/trivia/leaderboard')) return ok(leaderboard);
  if (path.endsWith('/trivia/challenges') && req.method == 'GET') return ok(challenges);
  if (path.contains('/trivia/challenges/')) return ok(challengeDetail);
  if (path.endsWith('/trivia/single/demo-session/answer')) {
    return ok({
      ...session(15, 3200, questionNumber: 16),
      'question': {
        'index': 15, 'id': 502, 'question_text': 'Which prophet was swallowed by a great fish?',
        'question_type': 'multiple_choice', 'option_a': 'Jonah', 'option_b': 'Amos', 'option_c': 'Hosea', 'option_d': 'Micah',
      },
      'last_answer': {'question_id': 501, 'selected': 'b', 'correct': true, 'correct_option': 'b', 'timed_out': false},
    });
  }
  return http.Response('{"detail":"not in demo"}', 404);
}

// ---------- Capture helpers ----------

Future<void> hold(WidgetTester tester, String name, {int seconds = 3, int settleFrames = 20}) async {
  // Let animations and async loads settle, then hold still for the host screenshot
  for (var i = 0; i < settleFrames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  // ignore: avoid_print
  print('CAPTURE:$name');
  await Future<void>.delayed(Duration(seconds: seconds));
}

Future<void> beat(WidgetTester tester, double seconds) async {
  final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

var _pointer = 1000;

/// Taps as a *device* pointer: the test framework only draws its tap crosshair
/// for test-sourced events, and that must not show up in store footage.
Future<void> deviceTap(WidgetTester tester, Finder finder) async {
  final binding = tester.binding as LiveTestWidgetsFlutterBinding;
  final at = tester.getCenter(finder);
  final id = ++_pointer;
  binding.handlePointerEventForSource(PointerDownEvent(pointer: id, position: at), source: TestBindingEventSource.device);
  await tester.pump(const Duration(milliseconds: 60));
  binding.handlePointerEventForSource(PointerUpEvent(pointer: id, position: at), source: TestBindingEventSource.device);
  await tester.pump();
}

Widget app(Widget home) => MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: home);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  binding.shouldPropagateDevicePointerEvents = true;

  setUpAll(() {
    final api = ApiService();
    api.setAuthForTesting(authorization: ({bool force = false}) async => null, canRetryAuth: () => false);
    api.httpClient = MockClient(fakeServer);
  });

  testWidgets('store capture ($mode)', (tester) async {
    final video = mode == 'video';
    Future<void> shot(String name, {int settleFrames = 20}) async {
      if (!video) return hold(tester, name, settleFrames: settleFrames, seconds: settleFrames == 20 ? 3 : 1);
      // ignore: avoid_print
      print('SCENE:$name'); // host timestamps scenes for captions
      await beat(tester, 2.2);
    }

    // 1. Trivia home → daily question
    await tester.pumpWidget(app(const TriviaHomeScreen()));
    await beat(tester, 1.5);
    if (video) await shot('home_before');
    final dailyCard = find.textContaining('Daily Question');
    await tester.ensureVisible(dailyCard.first);
    await deviceTap(tester, dailyCard.first);
    await beat(tester, 1.2);
    await shot('01_daily_question');

    // 2. Answer correctly → streak
    final modal = find.byType(DailyTriviaModal);
    await deviceTap(tester, find.descendant(of: modal, matching: find.textContaining('Elijah')).first);
    await beat(tester, 1.5);
    await shot('02_daily_streak');
    if (!video) {
      final scrollable = find.descendant(of: modal, matching: find.byType(Scrollable)).first;
      await tester.drag(scrollable, const Offset(0, -600));
      await beat(tester, 0.8);
      await shot('02b_daily_calendar');
    }
    Navigator.of(tester.element(modal)).pop();
    await beat(tester, 1.0);

    // 3. Home with the competition standings
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await beat(tester, 0.6);
    await shot('03_home_competition');

    // 4. Single player, mid-run
    final nav = Navigator.of(tester.element(find.byType(TriviaHomeScreen)));
    nav.push(MaterialPageRoute(
      builder: (_) => TriviaGameScreen(
        initialState: TriviaSessionState.fromJson(session(14, 2900)),
        category: 'old_testament',
        difficulty: 'challenger',
      ),
    ));
    await beat(tester, 1.6);
    await shot('04_game_question');
    await deviceTap(tester, find.textContaining('Saul').first);
    await beat(tester, 0.25);
    await shot('05_game_correct', settleFrames: 1); // catch the green feedback before it moves on
    nav.pop();
    await beat(tester, 0.6);

    // 5. Head-to-head challenge
    nav.push(MaterialPageRoute(builder: (_) => const TriviaChallengeDetailScreen(challengeId: 'demo-1')));
    await beat(tester, 1.5);
    await shot('06_challenge');
    nav.pop();
    await beat(tester, 0.6);

    // 6. Leaderboard
    nav.push(MaterialPageRoute(builder: (_) => const TriviaLeaderboardScreen()));
    await beat(tester, 1.5);
    await shot('07_leaderboard');
  });
}
