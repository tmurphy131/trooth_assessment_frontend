import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trooth_assessment/screens/mentor_agreements_screen.dart';
import 'package:trooth_assessment/services/api_service.dart';
import 'package:trooth_assessment/widgets/apprentice_picker.dart';

// Screen behavior for spec 005 US1: picker vs email entry, fallback, error text.
void main() {
  final api = ApiService();
  late List<Map<String, dynamic>> createdBodies;

  void stub({int apprenticesStatus = 200, int createStatus = 200}) {
    createdBodies = [];
    api.httpClient = MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/agreements/templates')) {
        return http.Response(jsonEncode([
          {'id': 't1', 'version': 1, 'is_active': true, 'markdown_source': 'x', 'created_at': '2026-01-01T00:00:00'}
        ]), 200);
      }
      if (path.endsWith('/mentor/my-apprentices')) {
        return apprenticesStatus == 200
            ? http.Response(jsonEncode([
                {'id': 'a1', 'name': 'Jordan', 'email': 'relay@privaterelay.appleid.com'}
              ]), 200)
            : http.Response('{"detail":"boom"}', apprenticesStatus);
      }
      if (req.method == 'POST' && path.endsWith('/agreements')) {
        createdBodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        if (createStatus != 200) return http.Response('{"detail":"no"}', createStatus);
        return http.Response(jsonEncode({
          'id': 'ag1', 'template_version': 1, 'mentor_id': 'm1', 'apprentice_id': 'a1',
          'apprentice_email': 'relay@privaterelay.appleid.com', 'status': 'draft',
          'apprentice_is_minor': false, 'parent_required': false, 'parent_email': null,
          'fields_json': {}, 'content_rendered': 'x', 'created_at': '2026-01-01T00:00:00',
        }), 200);
      }
      if (req.method == 'GET' && path.endsWith('/agreements')) return http.Response('[]', 200);
      return http.Response('[]', 200);
    });
  }

  setUp(() {
    api.setAuthForTesting(authorization: ({bool force = false}) async => null, canRetryAuth: () => false);
    api.clearCache();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700 * 3, 2400 * 3); // wide: the test font is much wider than real fonts
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: MentorAgreementsScreen()));
    await tester.pumpAndSettle();
  }

  final emailField = find.widgetWithText(TextFormField, 'Apprentice Email');
  final createButton = find.text('Create Draft');

  testWidgets('picking an apprentice hides email and sends apprentice_id', (tester) async {
    stub();
    await pumpScreen(tester);

    await tester.tap(find.byType(ApprenticePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jordan').last);
    await tester.pumpAndSettle();

    expect(emailField, findsNothing);
    final nameField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Apprentice Full Name'));
    expect(nameField.controller!.text, 'Jordan');

    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(createdBodies, hasLength(1));
    expect(createdBodies.single['apprentice_id'], 'a1');
    expect(createdBodies.single.containsKey('apprentice_email'), isFalse);
  });

  testWidgets('"Someone else" shows email and sends apprentice_email', (tester) async {
    stub();
    await pumpScreen(tester);

    expect(emailField, findsOneWidget); // default selection is "Someone else"
    await tester.enterText(emailField, 'x@y.com');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(createdBodies.single['apprentice_email'], 'x@y.com');
    expect(createdBodies.single.containsKey('apprentice_id'), isFalse);
  });

  testWidgets('apprentice list failing falls back to the email form', (tester) async {
    stub(apprenticesStatus: 500);
    await pumpScreen(tester);
    expect(find.byType(ApprenticePicker), findsNothing);
    expect(emailField, findsOneWidget);
  });

  testWidgets('403 on create shows the not-connected message', (tester) async {
    stub(createStatus: 403);
    await pumpScreen(tester);

    await tester.tap(find.byType(ApprenticePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jordan').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(find.text("Create failed: This apprentice isn't connected to you anymore. Refresh and try again."), findsOneWidget);
  });
}
