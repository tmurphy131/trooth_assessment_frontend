import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trooth_assessment/services/api_service.dart';
import 'package:trooth_assessment/utils/agreement_errors.dart';
import 'package:trooth_assessment/utils/errors.dart';
import 'package:trooth_assessment/widgets/apprentice_picker.dart';

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

  const fields = {'meeting_location': 'Cafe', 'meeting_duration_minutes': 45};

  group('createAgreement', () {
    test('by apprentice id sends apprentice_id and no email', () async {
      respond(200, {'id': 'ag1'});
      await api.createAgreement(templateVersion: 1, apprenticeId: 'a1', fields: fields);
      final body = jsonDecode(lastRequest!.body) as Map<String, dynamic>;
      expect(body['apprentice_id'], 'a1');
      expect(body.containsKey('apprentice_email'), isFalse);
    });

    test('by email sends apprentice_email and no id', () async {
      respond(200, {'id': 'ag1'});
      await api.createAgreement(templateVersion: 1, apprenticeEmail: 'x@y.com', fields: fields);
      final body = jsonDecode(lastRequest!.body) as Map<String, dynamic>;
      expect(body['apprentice_email'], 'x@y.com');
      expect(body.containsKey('apprentice_id'), isFalse);
    });

    for (final code in [403, 422]) {
      test('throws ApiException on $code', () async {
        respond(code, {'detail': 'x'});
        await expectLater(api.createAgreement(templateVersion: 1, apprenticeId: 'a1', fields: fields),
            throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', code)));
      });
    }
  });

  test('agreementCreateErrorMessage maps by status', () {
    expect(agreementCreateErrorMessage(ApiException(403, '')),
        "This apprentice isn't connected to you anymore. Refresh and try again.");
    expect(agreementCreateErrorMessage(ApiException(422, '')), 'Choose an apprentice or enter an email.');
    final server = ApiException(500, '');
    expect(agreementCreateErrorMessage(server), friendlyError(server));
    final other = StateError('x');
    expect(agreementCreateErrorMessage(other), friendlyError(other));
  });

  group('ApprenticePicker', () {
    final apprentices = [
      {'id': 'b', 'name': 'Zoe', 'email': 'z@x.com'},
      {'id': 'a', 'name': '', 'email': 'amy@x.com'},
      {'id': 'c', 'name': 'Ben', 'email': 'b@x.com'},
    ];

    Future<List<String?>> pumpAndOpen(WidgetTester tester, {required ValueChanged<String?> onChanged, double scale = 1}) async {
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: ApprenticePicker(apprentices: apprentices, value: null, onChanged: onChanged)),
      ));
      await tester.tap(find.byType(ApprenticePicker));
      await tester.pumpAndSettle();
      final items = tester.widgetList<DropdownMenuItem<String?>>(find.byType(DropdownMenuItem<String?>));
      return items.map((i) => i.value).toList();
    }

    testWidgets('sorted by label, falling back to email, "Someone else" last', (tester) async {
      final values = await pumpAndOpen(tester, onChanged: (_) {});
      // Menu items (the closed button also renders one copy; take the menu's order).
      expect(values.toSet(), {'a', 'b', 'c', null});
      final labels = ['amy@x.com', 'Ben', 'Zoe', 'Someone else (enter email)'];
      final ys = labels.map((l) => tester.getTopLeft(find.text(l).last).dy).toList();
      expect(ys, orderedEquals([...ys]..sort()));
      expect(apprentices.first['name'], 'Zoe', reason: 'input list must not be reordered');
    });

    testWidgets('choosing an apprentice or "Someone else" reports the value', (tester) async {
      final picked = <String?>[];
      await pumpAndOpen(tester, onChanged: picked.add);
      await tester.tap(find.text('Ben').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ApprenticePicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Someone else (enter email)').last);
      await tester.pumpAndSettle();
      expect(picked, ['c', null]);
    });

    testWidgets('no overflow at 1.5x text', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpAndOpen(tester, onChanged: (_) {}, scale: 1.5);
      expect(tester.takeException(), isNull);
    });
  });
}
