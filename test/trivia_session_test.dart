import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trooth_assessment/models/trivia_session.dart';
import 'package:trooth_assessment/services/api_service.dart';

Map<String, dynamic> stateJson({
  String status = 'active',
  int streak = 0,
  Map<String, dynamic>? question,
  Map<String, dynamic>? lastAnswer,
  int? graceExpiresInMs,
  Map<String, dynamic>? result,
}) =>
    {
      'session_id': 'sess-1',
      'status': status,
      'score': 300,
      'streak': streak,
      'correct_count': 3,
      'grace_tokens': 1,
      'grace_tokens_used': 0,
      'question_number': 4,
      'total_questions': 55,
      'time_limit_ms': 30000,
      'question': question,
      'last_answer': lastAnswer,
      'grace_expires_in_ms': graceExpiresInMs,
      'result': result,
    };

const mcQuestion = {
  'index': 3,
  'id': 412,
  'question_text': 'Who built the ark?',
  'question_type': 'multiple_choice',
  'option_a': 'Moses',
  'option_b': 'Noah',
  'option_c': 'Abraham',
  'option_d': 'David',
};

void main() {
  group('TriviaSessionState.fromJson', () {
    test('parses an active state with its question', () {
      final s = TriviaSessionState.fromJson(stateJson(question: mcQuestion));
      expect(s.sessionId, 'sess-1');
      expect(s.status, TriviaSessionStatus.active);
      expect(s.score, 300);
      expect(s.graceTokens, 1);
      expect(s.questionNumber, 4);
      expect(s.totalQuestions, 55);
      expect(s.timeLimitMs, 30000);
      expect(s.question!.id, 412);
      expect(s.question!.index, 3);
      expect(s.question!.text, 'Who built the ark?');
      expect(s.question!.options, {'a': 'Moses', 'b': 'Noah', 'c': 'Abraham', 'd': 'David'});
      expect(s.lastAnswer, isNull);
      expect(s.result, isNull);
    });

    test('a question never carries its answer, even if the server sent one', () {
      final leaky = {...mcQuestion, 'correct_option': 'b'};
      final q = TriviaSessionState.fromJson(stateJson(question: leaky)).question!;
      // Only option letters → text; nothing about which one is right
      expect(q.options.keys, ['a', 'b', 'c', 'd']);
      expect(q.options.values, isNot(contains('b')));
    });

    test('true/false questions have two options', () {
      final q = TriviaSessionQuestion.fromJson({
        'index': 0, 'id': 1, 'question_text': 'True?', 'question_type': 'true_false',
        'option_a': 'True', 'option_b': 'False', 'option_c': null, 'option_d': null,
      });
      expect(q.options, {'a': 'True', 'b': 'False'});
      expect(q.type, 'true_false');
    });

    test('parses awaiting grace with the grading and time left', () {
      final s = TriviaSessionState.fromJson(stateJson(
        status: 'awaiting_grace',
        lastAnswer: {'question_id': 412, 'selected': 'a', 'correct': false, 'correct_option': 'b', 'timed_out': false},
        graceExpiresInMs: 13000,
      ));
      expect(s.status, TriviaSessionStatus.awaitingGrace);
      expect(s.graceExpiresInMs, 13000);
      expect(s.lastAnswer!.correct, isFalse);
      expect(s.lastAnswer!.correctOption, 'b');
      expect(s.lastAnswer!.selected, 'a');
    });

    test('parses a timeout answer with a null selection', () {
      final s = TriviaSessionState.fromJson(stateJson(
        status: 'finished',
        lastAnswer: {'question_id': 412, 'selected': null, 'correct': false, 'correct_option': 'c', 'timed_out': true},
        result: {'score': 300, 'streak_length': 3, 'correct_count': 3, 'is_new_high_score': false,
                 'previous_best': 900, 'leaderboard_rank': 7, 'badges_earned': []},
      ));
      expect(s.lastAnswer!.selected, isNull);
      expect(s.lastAnswer!.timedOut, isTrue);
      expect(s.result!['leaderboard_rank'], 7);
    });

    test('unknown status fails safe to finished', () {
      expect(TriviaSessionState.fromJson(stateJson(status: 'mystery')).status, TriviaSessionStatus.finished);
    });

    test('multiplier matches server scoring boundaries', () {
      int m(int streak) => TriviaSessionState.fromJson(stateJson(streak: streak)).multiplier;
      expect(m(0), 1);
      expect(m(4), 1);
      expect(m(5), 2);
      expect(m(9), 2);
      expect(m(10), 3);
      expect(m(15), 4);
      expect(m(19), 4);
      expect(m(20), 5);
      expect(m(55), 5);
    });
  });

  group('TriviaApi session calls', () {
    final api = ApiService();
    late http.Request lastRequest;

    setUp(() {
      api.setAuthForTesting(authorization: ({bool force = false}) async => null, canRetryAuth: () => false);
      api.clearCache();
    });

    void respondWith(int status, Object body) {
      api.httpClient = MockClient((req) async {
        lastRequest = req;
        return http.Response(jsonEncode(body), status);
      });
    }

    test('start posts category and difficulty', () async {
      respondWith(200, stateJson(question: mcQuestion));
      final s = await api.triviaStartSingle(category: 'random', difficulty: 'challenger');
      expect(lastRequest.method, 'POST');
      expect(lastRequest.url.path, endsWith('/trivia/single/start'));
      expect(jsonDecode(lastRequest.body), {'category': 'random', 'difficulty': 'challenger'});
      expect(s.question!.id, 412);
    });

    test('answer posts the question and letter', () async {
      respondWith(200, stateJson(question: mcQuestion));
      await api.triviaAnswerSingle('sess-1', questionId: 412, selected: 'b');
      expect(lastRequest.url.path, endsWith('/trivia/single/sess-1/answer'));
      expect(jsonDecode(lastRequest.body), {'question_id': 412, 'selected': 'b'});
    });

    test('a timeout sends selected: null', () async {
      respondWith(200, stateJson(status: 'finished'));
      await api.triviaAnswerSingle('sess-1', questionId: 412);
      final body = jsonDecode(lastRequest.body) as Map<String, dynamic>;
      expect(body.containsKey('selected'), isTrue);
      expect(body['selected'], isNull);
    });

    test('grace posts the decision', () async {
      respondWith(200, stateJson(question: mcQuestion));
      await api.triviaGraceSingle('sess-1', use: true);
      expect(lastRequest.url.path, endsWith('/trivia/single/sess-1/grace'));
      expect(jsonDecode(lastRequest.body), {'use': true});
    });

    test('finish returns the result', () async {
      respondWith(200, {'score': 1500, 'streak_length': 12, 'correct_count': 12, 'is_new_high_score': true,
                        'previous_best': 900, 'leaderboard_rank': 4, 'badges_earned': []});
      final result = await api.triviaFinishSingle('sess-1');
      expect(lastRequest.url.path, endsWith('/trivia/single/sess-1/finish'));
      expect(result['score'], 1500);
    });

    for (final status in [409, 404, 426, 400]) {
      test('$status keeps its status code', () async {
        respondWith(status, {'detail': 'nope'});
        await expectLater(
          api.triviaAnswerSingle('sess-1', questionId: 1, selected: 'a'),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', status)),
        );
      });
    }

    test('transport failure becomes NetworkException', () async {
      api.httpClient = MockClient((_) async => throw http.ClientException('offline'));
      await expectLater(api.triviaStartSingle(category: 'random', difficulty: 'beginner'),
          throwsA(isA<NetworkException>()));
    });
  });

  group('challenges', () {
    final api = ApiService();

    setUp(() {
      api.setAuthForTesting(authorization: ({bool force = false}) async => null, canRetryAuth: () => false);
      api.clearCache();
    });

    test('create returning 403 throws PremiumRequiredException', () async {
      api.httpClient = MockClient((_) async => http.Response(
          jsonEncode({'detail': {'error': 'premium_required'}}), 403));
      await expectLater(api.triviaCreateChallenge({'challenged_email': 'a@b.c'}),
          throwsA(isA<PremiumRequiredException>()));
    });

    test('create returning 200 returns the challenge', () async {
      api.httpClient = MockClient((_) async => http.Response(jsonEncode({'id': 'ch-1'}), 200));
      expect((await api.triviaCreateChallenge({'challenged_email': 'a@b.c'}))['id'], 'ch-1');
    });

    test('create returning 404 stays an ApiException', () async {
      api.httpClient = MockClient((_) async => http.Response(jsonEncode({'detail': 'No user'}), 404));
      await expectLater(api.triviaCreateChallenge({'challenged_email': 'a@b.c'}),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)));
    });
  });
}
