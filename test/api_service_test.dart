import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trooth_assessment/services/api_service.dart';

void main() {
  final api = ApiService();

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

  test('sends the bearer token when set', () async {
    String? auth;
    respondWith((req) {
      auth = req.headers['Authorization'];
      return http.Response(jsonEncode({'message': 'ok'}), 200);
    });
    api.bearerToken = 'abc';
    await api.ping();
    expect(auth, 'Bearer abc');
    api.bearerToken = null;
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
