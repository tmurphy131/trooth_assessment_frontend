import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trooth_assessment/features/assessments/widgets/report_status_views.dart';
import 'package:trooth_assessment/features/assessments/screens/mentor_submission_detail_screen.dart';
import 'package:trooth_assessment/screens/apprentice_report_screen.dart';
import 'package:trooth_assessment/services/api_service.dart';

/// Scriptable backend for screen tests. Every endpoint the screens call is stubbed with a 200 so
/// nothing falls through to Firebase.
class FakeBackend {
  final requests = <String>[];
  final statuses = <Map<String, dynamic>>[];
  final premium = <http.Response>[];
  bool premiumUser = false;

  Map<String, dynamic> _status = {'status': 'processing', 'has_scores': true};

  http.Response _json(Object body, [int code = 200]) => http.Response(jsonEncode(body), code);

  Future<http.Response> handle(http.Request req) async {
    final path = req.url.path.replaceFirst(RegExp(r'^/+'), '/');
    requests.add(path);
    if (path.endsWith('/status') && path.startsWith('/assessments/')) {
      if (statuses.isNotEmpty) _status = statuses.removeAt(0);
      return _json(_status);
    }
    if (path.endsWith('/simplified')) {
      return _json({'health_score': 88, 'health_band': 'Flourishing', 'strengths': ['Prayer'], 'gaps': [],
                    'insights': [], 'flags': {}});
    }
    if (path.startsWith('/mentor-notes/')) return _json([]);
    if (path == '/mentor-profile/me') return _json({'email': 'guide.mentor@example.com'});
    if (path.startsWith('/mentor/assessment/')) {
      return _json({
        'id': 'a1', 'apprentice_id': 'p1', 'apprentice_name': 'Jordan', 'answers': {'q1': 'I pray daily'},
        'mentor_report_v2': {'health_score': 80, 'health_band': 'Maturing',
                             'biblical_knowledge': {'percent': 86.2, 'weak_topics': []},
                             'strengths': ['Prayer'], 'gaps': [], 'insights': [],
                             'flags': {'red': [], 'yellow': [], 'green': []}},
      });
    }
    if (path == '/subscriptions/status') return _json({'has_premium': premiumUser, 'is_premium': premiumUser});
    if (path.endsWith('/my-full-report')) {
      return premium.isNotEmpty ? premium.removeAt(0) : _json({'detail': 'premium required'}, 403);
    }
    return _json({});
  }

  bool requested(String suffix) => requests.any((p) => p.endsWith(suffix));
}

FakeBackend _installBackend() {
  final backend = FakeBackend();
  final api = ApiService();
  api.setAuthForTesting(authorization: ({bool force = false}) async => null, canRetryAuth: () => false);
  api.clearCache();
  api.httpClient = MockClient(backend.handle);
  return backend;
}

/// Lets queued HTTP futures and timers run without waiting for endless progress animations.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Widget _screen() => const MaterialApp(home: ApprenticeReportScreen(assessmentId: 'a1'));

Widget _host(Widget child, {double scale = 1.0}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(360, 720), textScaler: TextScaler.linear(scale)),
        child: Scaffold(backgroundColor: Colors.black, body: child),
      ),
    );

void main() {
  group('status views', () {
    testWidgets('preparing view, normal and slow', (tester) async {
      await tester.pumpWidget(_host(const ReportPreparingView()));
      expect(find.text('Preparing your report…'), findsOneWidget);
      expect(find.bySemanticsLabel('Preparing your report'), findsOneWidget);
      expect(find.text('Check again'), findsNothing);

      var taps = 0;
      await tester.pumpWidget(_host(ReportPreparingView(slow: true, onCheckAgain: () => taps++)));
      expect(find.text("Taking longer than usual — we're on it"), findsOneWidget);
      await tester.tap(find.text('Check again'));
      expect(taps, 1);
    });

    testWidgets('delayed view shows the reason and checks again', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(ReportDelayedView(reason: 'AI provider unavailable', onCheckAgain: () => taps++)));
      expect(find.text("Taking longer than usual — we're on it"), findsOneWidget);
      expect(find.text('AI provider unavailable'), findsOneWidget);
      await tester.tap(find.text('Check again'));
      expect(taps, 1);
    });

    testWidgets('premium cards', (tester) async {
      await tester.pumpWidget(_host(const PremiumStatusCard.generating()));
      expect(find.text('Preparing your Premium report…'), findsOneWidget);
      expect(find.bySemanticsLabel('Preparing your Premium report'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);

      var taps = 0;
      await tester.pumpWidget(_host(PremiumStatusCard.unavailable(onTryAgain: () => taps++)));
      expect(find.text('Your Premium report is temporarily unavailable.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpWidget(_host(PremiumStatusCard.stillPreparing(onTryAgain: () => taps++)));
      expect(find.text('Your Premium report is still being prepared.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(taps, 2);
    });

    testWidgets('no overflow at 1.5x text on a 360 px screen', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      for (final w in <Widget>[
        ReportPreparingView(slow: true, onCheckAgain: () {}),
        ReportDelayedView(reason: 'AI provider unavailable', onCheckAgain: () {}),
        Column(children: [
          const PremiumStatusCard.generating(),
          PremiumStatusCard.unavailable(onTryAgain: () {}),
          PremiumStatusCard.stillPreparing(onTryAgain: () {}),
        ]),
      ]) {
        await tester.pumpWidget(_host(SingleChildScrollView(child: w), scale: 1.5));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('ApprenticeReportScreen', () {
    testWidgets('US1: preparing until done, never loading the placeholder report', (tester) async {
      final backend = _installBackend();
      backend.statuses.addAll([
        {'status': 'processing', 'has_scores': true},
        {'status': 'done', 'has_scores': true},
      ]);
      await tester.pumpWidget(_screen());
      await tester.pump();
      expect(find.text('Preparing your report…'), findsOneWidget);
      expect(backend.requested('/simplified'), isFalse);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await _settle(tester);
      expect(backend.requested('/simplified'), isTrue);
      expect(find.text('Preparing your report…'), findsNothing);
    });

    testWidgets('US2: failed shows the reason; Check again moves to preparing, then the report', (tester) async {
      final backend = _installBackend();
      backend.statuses.addAll([
        {'status': 'failed', 'reason': 'AI provider unavailable', 'has_scores': true},
        {'status': 'processing', 'has_scores': true},
        {'status': 'done', 'has_scores': true},
      ]);
      await tester.pumpWidget(_screen());
      await tester.pump();
      expect(find.text("Taking longer than usual — we're on it"), findsOneWidget);
      expect(find.text('AI provider unavailable'), findsOneWidget);
      expect(backend.requested('/simplified'), isFalse);

      await tester.tap(find.text('Check again'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Preparing your report…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 3));
      await _settle(tester);
      expect(backend.requested('/simplified'), isTrue);
    });

    testWidgets('a failed first status check shows preparing, not the placeholder', (tester) async {
      final backend = _installBackend();
      ApiService().httpClient = MockClient((req) async {
        if (req.url.path.endsWith('/status')) return http.Response('boom', 500);
        return backend.handle(req);
      });
      await tester.pumpWidget(_screen());
      await tester.pump();
      await tester.pump();
      expect(find.text('Preparing your report…'), findsOneWidget);
      expect(backend.requested('/simplified'), isFalse);
      await tester.pumpWidget(const SizedBox()); // dispose: stops the poller
    });

    testWidgets('US4: Premium generating card, then the Premium report', (tester) async {
      final backend = _installBackend()..premiumUser = true;
      backend.statuses.add({'status': 'done', 'has_scores': true});
      backend.premium.addAll([
        http.Response(jsonEncode({'status': 'generating', 'cached': false}), 200),
        http.Response(jsonEncode({'report': {'executive_summary': {'health_score': 88}}, 'cached': true}), 200),
      ]);
      await tester.pumpWidget(_screen());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Preparing your Premium report…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(find.text('Preparing your Premium report…'), findsNothing);
      expect(backend.requests.where((p) => p.endsWith('/my-full-report')).length, 2);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('US4: Premium 503 shows Try again and no upsell; 403 keeps the upsell', (tester) async {
      var backend = _installBackend()..premiumUser = true;
      backend.statuses.add({'status': 'done', 'has_scores': true});
      backend.premium.add(http.Response(jsonEncode({'detail': 'Report is temporarily unavailable'}), 503));
      await tester.pumpWidget(_screen());
      await _settle(tester);
      expect(find.text('Your Premium report is temporarily unavailable.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      backend = _installBackend();
      backend.statuses.add({'status': 'done', 'has_scores': true});
      await tester.pumpWidget(_screen());
      await _settle(tester);
      expect(find.text('Your Premium report is temporarily unavailable.'), findsNothing);
      expect(find.text('Preparing your Premium report…'), findsNothing);
    });
  });

  group('MentorSubmissionDetailScreen', () {
    Widget mentorScreen() => const MaterialApp(
        home: MentorSubmissionDetailScreen(assessmentId: 'a1', apprenticeId: 'p1', apprenticeName: 'Jordan'));
    int mentorLoads(FakeBackend b) => b.requests.where((p) => p == '/mentor/assessment/a1').length;

    testWidgets('US3: Report tab waits for done; Answers tab still works', (tester) async {
      final backend = _installBackend();
      backend.statuses.add({'status': 'processing', 'has_scores': true}); // sticky until changed
      await tester.pumpWidget(mentorScreen());
      await _settle(tester);
      expect(find.text('I pray daily'), findsOneWidget); // Answers tab
      expect(mentorLoads(backend), 1); // answers only, no report load yet

      await tester.tap(find.text('Report'));
      await _settle(tester);
      expect(find.text('Preparing your report…'), findsOneWidget);
      expect(mentorLoads(backend), 1);

      backend.statuses.add({'status': 'done', 'has_scores': true});
      await tester.pump(const Duration(seconds: 5));
      await _settle(tester);
      expect(mentorLoads(backend), 2); // report loaded once done
      expect(find.text('Preparing your report…'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('US3: failed shows the delayed view on the Report tab', (tester) async {
      final backend = _installBackend();
      backend.statuses.add({'status': 'failed', 'reason': 'AI provider unavailable', 'has_scores': true});
      await tester.pumpWidget(mentorScreen());
      await _settle(tester);
      await tester.tap(find.text('Report'));
      await _settle(tester);
      expect(find.text("Taking longer than usual — we're on it"), findsOneWidget);
      expect(find.text('AI provider unavailable'), findsOneWidget);
      expect(mentorLoads(backend), 1);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
