import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trooth_assessment/models/prayer_entry.dart';
import 'package:trooth_assessment/services/api_service.dart';
import 'package:trooth_assessment/utils/errors.dart';

void main() {
  final api = ApiService();

  setUp(() {
    api.setAuthForTesting(authorization: ({bool force = false}) async => null, canRetryAuth: () => false);
    api.clearCache();
  });

  void respondWith(http.Response Function(http.Request) handler) {
    api.httpClient = MockClient((req) async => handler(req));
  }

  test('ping returns the backend message on 200', () async {
    respondWith((_) => http.Response(jsonEncode({'message': 'ok'}), 200));
    expect(await api.ping(), 'ok');
  });

  test('ping throws on a server error', () async {
    respondWith((_) => http.Response('boom', 500));
    expect(api.ping(), throwsA(isA<Exception>()));
  });

  test('connection failures become NetworkException', () async {
    api.httpClient = MockClient((_) async => throw http.ClientException('connection refused'));
    expect(api.ping(), throwsA(isA<NetworkException>()));
  });

  test('adds the Authorization header from the token provider', () async {
    String? auth;
    respondWith((req) {
      auth = req.headers['Authorization'];
      return http.Response(jsonEncode({'message': 'ok'}), 200);
    });
    api.setAuthForTesting(authorization: ({bool force = false}) async => 'Bearer abc');
    await api.ping();
    expect(auth, 'Bearer abc');
  });

  test('retries once on 401 with a force-refreshed token', () async {
    final seen = <String?>[];
    respondWith((req) {
      seen.add(req.headers['Authorization']);
      return seen.length == 1
          ? http.Response('expired', 401)
          : http.Response(jsonEncode({'message': 'ok'}), 200);
    });
    api.setAuthForTesting(
      authorization: ({bool force = false}) async => force ? 'Bearer fresh' : 'Bearer stale',
    );
    expect(await api.ping(), 'ok');
    expect(seen, ['Bearer stale', 'Bearer fresh']);
  });

  test('does not retry a second 401, and surfaces it as ApiException', () async {
    var calls = 0;
    respondWith((_) {
      calls++;
      return http.Response('nope', 401);
    });
    api.setAuthForTesting(authorization: ({bool force = false}) async => 'Bearer x');
    await expectLater(
      api.fetchOwnFullReport(assessmentId: 'a1'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
    expect(calls, 2);
  });

  test('error statuses become ApiException with the status code', () async {
    respondWith((_) => http.Response('boom', 500));
    await expectLater(api.ping(), throwsA(isA<ApiException>().having((e) => e.isServerError, 'isServerError', true)));
  });

  test('friendlyError maps API and network failures to plain messages', () {
    expect(friendlyError(ApiException(503, 'x failed (503)')), startsWith('The server had a problem'));
    expect(friendlyError(ApiException(404, 'x failed (404)')), startsWith("We couldn't find that"));
    expect(friendlyError(NetworkException('Could not reach the server.')), startsWith('Could not reach the server.'));
  });

  test('plus-addressed emails survive the invites query', () async {
    String? sent;
    respondWith((req) {
      sent = req.url.queryParameters['email'];
      return http.Response('[]', 200);
    });
    await api.getApprenticeInvites('a+b@example.com');
    expect(sent, 'a+b@example.com');
  });

  group('fetchOwnFullReport', () {
    test('403 means premium is required', () async {
      respondWith((_) => http.Response('forbidden', 403));
      expect(api.fetchOwnFullReport(assessmentId: 'a1'), throwsA(isA<PremiumRequiredException>()));
    });

    test('200 returns the decoded report', () async {
      respondWith((req) {
        expect(req.url.path, endsWith('/assessments/a1/my-full-report'));
        return http.Response(jsonEncode({'id': 'a1'}), 200);
      });
      expect(await api.fetchOwnFullReport(assessmentId: 'a1'), {'id': 'a1'});
    });
  });

  group('read cache', () {
    test('repeat and concurrent reads share one request', () async {
      var calls = 0;
      respondWith((_) {
        calls++;
        return http.Response(jsonEncode({'has_premium': false}), 200);
      });
      await Future.wait([api.getSubscriptionStatus(), api.getSubscriptionStatus()]);
      await api.getSubscriptionStatus();
      expect(calls, 1);
    });

    test('each caller gets its own copy', () async {
      respondWith((_) => http.Response(jsonEncode({'has_premium': false}), 200));
      final a = await api.getSubscriptionStatus();
      a['has_premium'] = true;
      expect((await api.getSubscriptionStatus())['has_premium'], false);
    });

    test('a successful write clears cached reads', () async {
      var reads = 0;
      respondWith((req) {
        if (req.method == 'GET') {
          reads++;
          return http.Response(jsonEncode({'has_premium': reads > 1}), 200);
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      });
      expect((await api.getSubscriptionStatus())['has_premium'], false);
      await api.restoreSubscription();
      expect((await api.getSubscriptionStatus())['has_premium'], true);
      expect(reads, 2);
    });

    test('failures are not cached', () async {
      var calls = 0;
      respondWith((_) {
        calls++;
        return calls == 1 ? http.Response('boom', 500) : http.Response(jsonEncode({'has_premium': true}), 200);
      });
      await expectLater(api.getSubscriptionStatus(), throwsA(isA<ApiException>()));
      expect((await api.getSubscriptionStatus())['has_premium'], true);
    });
  });

  group('prayer journal', () {
    Map<String, dynamic> entryJson({String id = 'p1', String? answeredAt}) => {
          'id': id,
          'apprentice_id': 'u1',
          'title': 'Job search',
          'body': null,
          'category': 'intercession',
          'praying_for': 'Marcus',
          'scripture_ref': null,
          'shared_with_mentor': true,
          'answered_at': answeredAt,
          'answer_note': null,
          'created_at': '2026-10-01T12:00:00',
          'updated_at': null,
        };

    test('lists entries with status and category filters', () async {
      late Uri seen;
      respondWith((req) {
        seen = req.url;
        return http.Response(jsonEncode([entryJson()]), 200);
      });
      final entries = await api.getPrayerEntries(status: 'active', category: 'intercession');
      expect(seen.path, endsWith('/prayer-journal/entries'));
      expect(seen.queryParameters, {'status': 'active', 'category': 'intercession'});
      expect(entries.single.category, PrayerCategory.intercession);
      expect(entries.single.sharedWithMentor, isTrue);
    });

    test('create sends trimmed fields and nulls for blanks', () async {
      late Map<String, dynamic> body;
      respondWith((req) {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(entryJson()), 200);
      });
      await api.createPrayerEntry(PrayerEntry(
        id: '',
        title: 'Job search',
        body: '   ',
        category: PrayerCategory.intercession,
        prayingFor: ' Marcus ',
        createdAt: DateTime.now(),
      ));
      expect(body['body'], isNull);
      expect(body['praying_for'], 'Marcus');
      expect(body['category'], 'intercession');
      expect(body['shared_with_mentor'], isFalse);
    });

    test('mark answered posts the note and parses answered_at', () async {
      late http.Request seen;
      respondWith((req) {
        seen = req;
        return http.Response(jsonEncode(entryJson(answeredAt: '2026-10-02T09:30:00')), 200);
      });
      final entry = await api.markPrayerAnswered('p1', answerNote: '  Got the job  ');
      expect(seen.method, 'POST');
      expect(seen.url.path, endsWith('/prayer-journal/entries/p1/answered'));
      expect(jsonDecode(seen.body), {'answer_note': 'Got the job'});
      expect(entry.isAnswered, isTrue);
      expect(entry.answeredAt, DateTime.utc(2026, 10, 2, 9, 30).toLocal());
    });

    test('delete accepts 204', () async {
      respondWith((_) => http.Response('', 204));
      await api.deletePrayerEntry('p1');
    });

    test('mentor view surfaces 403 as ApiException', () async {
      respondWith((_) => http.Response('{"detail":"Not authorized"}', 403));
      await expectLater(
        api.mentorGetSharedPrayerEntries('u1'),
        throwsA(isA<ApiException>().having((e) => e.isForbidden, 'isForbidden', true)),
      );
    });

    test('unknown category falls back to request', () {
      final entry = PrayerEntry.fromJson({...entryJson(), 'category': 'something_new'});
      expect(entry.category, PrayerCategory.request);
    });
  });
}
