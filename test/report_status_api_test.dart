import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trooth_assessment/features/assessments/models/report_status.dart';
import 'package:trooth_assessment/services/api_service.dart';

void main() {
  final api = ApiService();

  setUp(() {
    api.setAuthForTesting(authorization: ({bool force = false}) async => null, canRetryAuth: () => false);
    api.clearCache();
  });

  void respond(int code, Object body) {
    api.httpClient = MockClient((_) async => http.Response(body is String ? body : jsonEncode(body), code));
  }

  group('getReportStatus', () {
    test('parses status bodies', () async {
      respond(200, {'status': 'failed', 'reason': 'AI provider unavailable', 'has_scores': true});
      final s = await api.getReportStatus('a1');
      expect(s.phase, ReportPhase.delayed);
      expect(s.reason, 'AI provider unavailable');
    });

    for (final code in [403, 404, 500]) {
      test('throws ApiException on $code', () async {
        respond(code, 'nope');
        await expectLater(api.getReportStatus('a1'),
            throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', code)));
      });
    }
  });

  final fetchers = <String, Future<PremiumReportResult> Function()>{
    'own': () => api.fetchOwnPremiumReport(assessmentId: 'a1'),
    'apprentice': () => api.fetchMyPremiumReport(assessmentId: 'a1'),
    'mentor': () => api.fetchMentorPremiumReport(draftId: 'a1'),
  };

  fetchers.forEach((name, fetch) {
    group('Premium report ($name)', () {
      test('200 with report → ready', () async {
        respond(200, {'report': {'executive_summary': {}}, 'cached': true});
        final r = await fetch();
        expect(r.kind, PremiumReportKind.ready);
        expect(r.cached, isTrue);
        expect(r.report, isNotNull);
      });

      test('200 generating or empty → generating', () async {
        respond(200, {'status': 'generating', 'cached': false});
        expect((await fetch()).kind, PremiumReportKind.generating);
        respond(200, <String, dynamic>{});
        expect((await fetch()).kind, PremiumReportKind.generating);
      });

      test('503 → unavailable, 403 → premiumRequired', () async {
        respond(503, {'detail': 'Report is temporarily unavailable'});
        expect((await fetch()).kind, PremiumReportKind.unavailable);
        respond(403, {'detail': 'Premium subscription required'});
        expect((await fetch()).kind, PremiumReportKind.premiumRequired);
      });

      test('a timeout while the server waits → generating', () async {
        api.httpClient = MockClient((_) async => throw TimeoutException('slow'));
        expect((await fetch()).kind, PremiumReportKind.generating);
        api.httpClient = MockClient((_) async => throw http.ClientException('refused'));
        await expectLater(fetch(), throwsA(isA<NetworkException>()));
      });

      test('404 and 500 throw ApiException', () async {
        respond(404, 'missing');
        await expectLater(fetch(), throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)));
        respond(500, 'boom');
        await expectLater(fetch(), throwsA(isA<ApiException>()));
      });
    });
  });

  test('legacy full-report fetchers throw a typed 404', () async {
    respond(404, 'missing');
    await expectLater(api.fetchOwnFullReport(assessmentId: 'a1'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)));
    await expectLater(api.fetchMyFullReport(assessmentId: 'a1'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)));
  });
}
