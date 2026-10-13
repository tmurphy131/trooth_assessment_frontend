import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trooth_assessment/services/api_service.dart';
import 'package:trooth_assessment/utils/gift_codes.dart';

void main() {
  final api = ApiService();
  http.Request? lastRequest;

  setUp(() {
    api.setAuthForTesting(authorization: ({bool force = false}) async => null, canRetryAuth: () => false);
    api.clearCache();
    lastRequest = null;
  });

  void respond(int code, Object body) {
    api.httpClient = MockClient((req) async {
      lastRequest = req;
      return http.Response(body is String ? body : jsonEncode(body), code);
    });
  }

  group('redeemGiftCode', () {
    test('posts the code and parses success', () async {
      respond(200, {
        'success': true,
        'message': 'Premium access activated!',
        'new_tier': 'mentor_gifted',
        'expires_at': null,
        'mentor_name': 'Marcus',
      });
      final r = await api.redeemGiftCode('TROOTH-A7K9-M2P4');
      expect(lastRequest!.url.path, endsWith('/apprentice/redeem-code'));
      expect(jsonDecode(lastRequest!.body), {'code': 'TROOTH-A7K9-M2P4'});
      expect(r.success, isTrue);
      expect(r.mentorName, 'Marcus');
    });

    test('parses a business failure', () async {
      respond(200, {'success': false, 'message': 'This code has already been redeemed.'});
      final r = await api.redeemGiftCode('TROOTH-A7K9-M2P4');
      expect(r.success, isFalse);
      expect(r.message, 'This code has already been redeemed.');
      expect(r.mentorName, isNull);
    });

    for (final code in [403, 500]) {
      test('throws ApiException on $code', () async {
        respond(code, {'detail': 'x'});
        await expectLater(api.redeemGiftCode('TROOTH-A7K9-M2P4'),
            throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', code)));
      });
    }

    for (final body in ['not json', '{}']) {
      test('malformed 200 body ($body) throws ApiException', () async {
        respond(200, body);
        await expectLater(api.redeemGiftCode('TROOTH-A7K9-M2P4'),
            throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 200)));
      });
    }
  });

  test('normalizeGiftCode', () {
    expect(normalizeGiftCode('a7k9m2p4'), 'TROOTH-A7K9-M2P4');
    expect(normalizeGiftCode(' trooth-a7k9-m2p4. '), 'TROOTH-A7K9-M2P4');
    expect(normalizeGiftCode('TROOTH A7K9 M2P4'), 'TROOTH-A7K9-M2P4');
    expect(normalizeGiftCode('A7K9'), isNull);
    expect(normalizeGiftCode(''), isNull);
    expect(normalizeGiftCode('A7K9M2P4X'), isNull);
  });
}
