import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trooth_assessment/services/api_service.dart';
import 'package:trooth_assessment/utils/errors.dart';

void main() {
  final api = ApiService();

  setUp(() => api.setAuthForTesting(authorization: ({bool force = false}) async => null, canRetryAuth: () => false));

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
}
