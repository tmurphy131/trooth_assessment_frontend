import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trooth_assessment/models/invite_redemption.dart';
import 'package:trooth_assessment/services/api_service.dart';
import 'package:trooth_assessment/utils/errors.dart';
import 'package:trooth_assessment/utils/invite_codes.dart';

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

  group('redeemInviteCode', () {
    test('parses the redemption and sends the trimmed code', () async {
      respond(200, {
        'message': 'Invitation accepted, relationship already active',
        'mentor_id': 'm1',
        'mentor_name': 'Marcus',
        'relationship': 'already_active',
      });
      final r = await api.redeemInviteCode('  K7QM-3XPR ');
      expect(r.mentorId, 'm1');
      expect(r.mentorName, 'Marcus');
      expect(r.relationship, InviteRelationship.alreadyActive);
      expect(lastRequest!.url.path, endsWith('/invitations/redeem'));
      expect(jsonDecode(lastRequest!.body), {'code': 'K7QM-3XPR'});
    });

    test('unknown relationship is treated as created', () async {
      respond(200, {'mentor_id': 'm1', 'mentor_name': null, 'relationship': 'something_new'});
      final r = await api.redeemInviteCode('K7QM-3XPR');
      expect(r.relationship, InviteRelationship.created);
      expect(r.mentorName, isNull);
    });

    for (final body in ['not json', '{}']) {
      test('malformed 200 body ($body) throws ApiException, not a parse error', () async {
        respond(200, body);
        await expectLater(api.redeemInviteCode('K7QM-3XPR'),
            throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 200)));
      });
    }

    for (final code in [400, 403, 404, 429, 500]) {
      test('throws ApiException on $code', () async {
        respond(code, {'detail': 'whatever'});
        await expectLater(api.redeemInviteCode('K7QM-3XPR'),
            throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', code)));
      });
    }
  });

  group('sendInvite', () {
    test('returns the code', () async {
      respond(200, {'message': 'Invitation sent', 'id': 'i1', 'code': 'K7QM-3XPR', 'expires_at': '2026-10-20T00:00:00'});
      expect(await api.sendInvite({'apprentice_name': 'A', 'apprentice_email': 'a@x.com'}), 'K7QM-3XPR');
    });

    test('returns null when the backend sends no code', () async {
      respond(200, {'message': 'Invitation sent'});
      expect(await api.sendInvite({'apprentice_name': 'A', 'apprentice_email': 'a@x.com'}), isNull);
    });

    test('still throws on failure', () async {
      respond(400, {'detail': 'An invitation is already pending for this apprentice'});
      await expectLater(api.sendInvite({'apprentice_name': 'A', 'apprentice_email': 'a@x.com'}),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400)));
    });
  });

  group('inviteCodeErrorMessage', () {
    test('maps statuses to the spec messages', () {
      expect(inviteCodeErrorMessage(ApiException(404, '')), "We couldn't find that code. Check it and try again.");
      expect(inviteCodeErrorMessage(ApiException(400, '')),
          "This code can't be used. It may have expired or already been used. Ask your mentor for a new one.");
      expect(inviteCodeErrorMessage(ApiException(403, '')), 'Invite codes are for apprentice accounts.');
      expect(inviteCodeErrorMessage(ApiException(429, '')), 'Too many tries. Please wait a while and try again.');
    });

    test('falls back to friendlyError', () {
      final server = ApiException(500, '');
      expect(inviteCodeErrorMessage(server), friendlyError(server));
      final other = StateError('x');
      expect(inviteCodeErrorMessage(other), friendlyError(other));
    });
  });

  test('inviteRedeemedMessage', () {
    expect(
      inviteRedeemedMessage(const InviteRedemption(mentorId: 'm', mentorName: 'Marcus', relationship: InviteRelationship.created)),
      "You're now connected with Marcus.",
    );
    expect(
      inviteRedeemedMessage(const InviteRedemption(mentorId: 'm', mentorName: 'Marcus', relationship: InviteRelationship.reactivated)),
      "You're now connected with Marcus.",
    );
    expect(
      inviteRedeemedMessage(const InviteRedemption(mentorId: 'm', mentorName: ' ', relationship: InviteRelationship.alreadyActive)),
      "You're already connected with your mentor.",
    );
  });

  test('buildInviteShareMessage includes name, code and store links', () {
    final msg = buildInviteShareMessage(mentorName: 'Marcus', code: 'K7QM-3XPR');
    expect(msg, contains('Marcus'));
    expect(msg, contains('K7QM-3XPR'));
    expect(msg, contains(kAppStoreUrl));
    expect(msg, contains(kPlayStoreUrl));
  });

  test('UpperCaseTextFormatter uppercases', () {
    final out = UpperCaseTextFormatter().formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: 'k7qm 3xpr', selection: TextSelection.collapsed(offset: 9)),
    );
    expect(out.text, 'K7QM 3XPR');
    expect(out.selection.baseOffset, 9);
  });
}
