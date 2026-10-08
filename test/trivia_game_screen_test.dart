import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trooth_assessment/models/trivia_session.dart';
import 'package:trooth_assessment/screens/trivia_game_screen.dart';
import 'package:trooth_assessment/services/api_service.dart';

Map<String, dynamic> question(int id) => {
      'index': id - 1,
      'id': id,
      'question_text': 'Question $id?',
      'question_type': 'multiple_choice',
      'option_a': 'Alpha $id',
      'option_b': 'Bravo $id',
      'option_c': 'Charlie $id',
      'option_d': 'Delta $id',
    };

Map<String, dynamic> state({
  String status = 'active',
  int score = 0,
  int streak = 0,
  int graceTokens = 0,
  int? questionId,
  Map<String, dynamic>? lastAnswer,
  int? graceExpiresInMs,
  Map<String, dynamic>? result,
}) =>
    {
      'session_id': 'sess-1',
      'status': status,
      'score': score,
      'streak': streak,
      'correct_count': streak,
      'grace_tokens': graceTokens,
      'grace_tokens_used': 0,
      'question_number': questionId ?? 1,
      'total_questions': 55,
      'time_limit_ms': 30000,
      'question': questionId == null ? null : question(questionId),
      'last_answer': lastAnswer,
      'grace_expires_in_ms': graceExpiresInMs,
      'result': result,
    };

Map<String, dynamic> graded(int questionId, String? selected, String correctOption, {bool timedOut = false}) => {
      'question_id': questionId,
      'selected': selected,
      'correct': selected == correctOption && !timedOut,
      'correct_option': correctOption,
      'timed_out': timedOut,
    };

const finalResult = {
  'score': 0,
  'streak_length': 0,
  'correct_count': 0,
  'is_new_high_score': false,
  'previous_best': null,
  'leaderboard_rank': 9,
  'badges_earned': [],
};

void main() {
  final api = ApiService();
  late DateTime now;
  late List<(String, Map<String, dynamic>)> requests;
  late Map<String, List<http.Response>> scripted;

  void serve(String endpoint, int status, Object body) =>
      scripted.putIfAbsent(endpoint, () => []).add(http.Response(jsonEncode(body), status));

  setUp(() {
    now = DateTime(2026, 11, 5, 12);
    requests = [];
    scripted = {};
    api.setAuthForTesting(authorization: ({bool force = false}) async => null, canRetryAuth: () => false);
    api.clearCache();
    api.httpClient = MockClient((req) async {
      final endpoint = req.url.pathSegments.last; // answer | grace | finish
      requests.add((endpoint, req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>));
      final queue = scripted[endpoint];
      if (queue == null || queue.isEmpty) return http.Response('{"detail":"unscripted"}', 400);
      return queue.removeAt(0);
    });
  });

  Future<void> pumpGame(WidgetTester tester, Map<String, dynamic> initial) async {
    await tester.pumpWidget(MaterialApp(
      home: TriviaGameScreen(
        initialState: TriviaSessionState.fromJson(initial),
        category: 'old_testament',
        difficulty: 'challenger',
        now: () => now,
      ),
    ));
    await tester.pump();
  }

  Future<void> advance(WidgetTester tester, Duration d) async {
    now = now.add(d);
    await tester.pump(d);
  }

  Future<void> settleNavigation(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a tap sends one answer, shows feedback, then the next question', (tester) async {
    await pumpGame(tester, state(questionId: 1));
    serve('answer', 200, state(questionId: 2, score: 100, streak: 1, lastAnswer: graded(1, 'b', 'b')));

    await tester.tap(find.text('B. Bravo 1'));
    await tester.pump();

    expect(requests, hasLength(1));
    expect(requests.single.$2, {'question_id': 1, 'selected': 'b'});
    expect(find.text('Question 1?'), findsOneWidget, reason: 'feedback shows on the answered question');

    await advance(tester, const Duration(milliseconds: 800));
    expect(find.text('Question 2?'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('a double tap sends only one answer', (tester) async {
    await pumpGame(tester, state(questionId: 1));
    serve('answer', 200, state(questionId: 2, score: 100, streak: 1, lastAnswer: graded(1, 'a', 'a')));

    await tester.tap(find.text('A. Alpha 1'));
    await tester.tap(find.text('C. Charlie 1'));
    await tester.pump();
    await advance(tester, const Duration(milliseconds: 800));

    expect(requests.where((r) => r.$1 == 'answer'), hasLength(1));
  });

  testWidgets('when the timer runs out the app sends a timeout', (tester) async {
    await pumpGame(tester, state(questionId: 1));
    serve('answer', 200, state(status: 'finished', lastAnswer: graded(1, null, 'c'), result: finalResult));

    await advance(tester, const Duration(seconds: 29));
    expect(requests, isEmpty);
    await advance(tester, const Duration(seconds: 1));

    expect(requests.single.$2, {'question_id': 1, 'selected': null});
    await advance(tester, const Duration(milliseconds: 800));
    await settleNavigation(tester);
    expect(find.text('Game Over'), findsOneWidget);
  });

  testWidgets('time spent in the background counts: resume sends the timeout at once', (tester) async {
    await pumpGame(tester, state(questionId: 1, streak: 3, score: 300));
    serve('answer', 200, state(status: 'finished', lastAnswer: graded(1, null, 'a', timedOut: true), result: finalResult));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 40)); // away; the app's timers didn't run
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(requests.single.$2, {'question_id': 1, 'selected': null},
        reason: 'no free time: the expired question is answered as a timeout immediately');
    await advance(tester, const Duration(milliseconds: 800));
    await settleNavigation(tester);
    expect(find.text('Game Over'), findsOneWidget);
  });

  testWidgets('countdown shows real time left after a short absence', (tester) async {
    await pumpGame(tester, state(questionId: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 12));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(requests, isEmpty);
    expect(find.text('18'), findsOneWidget);
  });

  testWidgets('using a grace token continues at the next question', (tester) async {
    await pumpGame(tester, state(questionId: 11, streak: 10, score: 1700, graceTokens: 1));
    serve('answer', 200, state(status: 'awaiting_grace', streak: 10, score: 1700, graceTokens: 1,
        lastAnswer: graded(11, 'a', 'd'), graceExpiresInMs: 13000));
    serve('grace', 200, state(questionId: 12, streak: 10, score: 1700));

    await tester.tap(find.text('A. Alpha 11'));
    await tester.pump();
    expect(find.text('Use Grace Token?'), findsOneWidget);

    await tester.ensureVisible(find.text('Use Token'));
    await tester.tap(find.text('Use Token'));
    await tester.pump();
    expect(requests.last.$1, 'grace');
    expect(requests.last.$2, {'use': true});
    expect(find.text('Question 12?'), findsOneWidget);
  });

  testWidgets('letting the grace countdown run out declines and ends the game', (tester) async {
    await pumpGame(tester, state(questionId: 11, streak: 10, graceTokens: 1));
    serve('answer', 200, state(status: 'awaiting_grace', streak: 10, graceTokens: 1,
        lastAnswer: graded(11, 'a', 'd'), graceExpiresInMs: 13000));
    serve('grace', 200, state(status: 'finished', result: finalResult));

    await tester.tap(find.text('A. Alpha 11'));
    await tester.pump();
    await advance(tester, const Duration(seconds: 12));
    expect(requests.where((r) => r.$1 == 'grace'), isEmpty);
    await advance(tester, const Duration(seconds: 1));

    expect(requests.last.$1, 'grace');
    expect(requests.last.$2, {'use': false});
    await settleNavigation(tester);
    expect(find.text('Game Over'), findsOneWidget);
  });

  testWidgets('a 409 re-syncs by replaying the last answer, without reading the message', (tester) async {
    await pumpGame(tester, state(questionId: 11, streak: 10, graceTokens: 1));
    serve('answer', 200, state(status: 'awaiting_grace', streak: 10, graceTokens: 1,
        lastAnswer: graded(11, 'a', 'd'), graceExpiresInMs: 13000));
    serve('grace', 409, {'detail': 'anything'});
    serve('answer', 200, state(status: 'finished', lastAnswer: graded(11, 'a', 'd'), result: finalResult));

    await tester.tap(find.text('A. Alpha 11'));
    await tester.pump();
    await tester.ensureVisible(find.text('Use Token'));
    await tester.tap(find.text('Use Token'));
    await tester.pump();

    expect(requests.map((r) => r.$1), ['answer', 'grace', 'answer']);
    expect(requests.last.$2, {'question_id': 11, 'selected': 'a'});
    await settleNavigation(tester);
    expect(find.text('Game Over'), findsOneWidget);
  });

  testWidgets('grace prompt fits a small phone at 1.5x text without overflow', (tester) async {
    tester.view.physicalSize = const Size(375 * 2, 667 * 2); // iPhone SE
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    serve('answer', 200, state(status: 'awaiting_grace', streak: 10, graceTokens: 1,
        lastAnswer: graded(11, 'a', 'd'), graceExpiresInMs: 13000));

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: TriviaGameScreen(
        initialState: TriviaSessionState.fromJson(state(questionId: 11, streak: 10, graceTokens: 1)),
        category: 'old_testament',
        difficulty: 'challenger',
        now: () => now,
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('A. Alpha 11'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Use Token'));
    expect(find.text('Use Token').hitTestable(), findsOneWidget);
  });

  testWidgets('quitting ends the game on the server and shows the saved result', (tester) async {
    await pumpGame(tester, state(questionId: 1));
    serve('finish', 200, finalResult);

    await tester.tap(find.byTooltip('Quit game'));
    await tester.pump();
    expect(find.text('Your game will end and your score so far will be saved.'), findsOneWidget);
    await tester.tap(find.text('Quit'));
    await tester.pump();

    expect(requests.single.$1, 'finish');
    await settleNavigation(tester);
    expect(find.text('Game Over'), findsOneWidget);
  });
}
