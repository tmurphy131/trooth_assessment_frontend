// App-level routes. AuthGate at `/` decides the dashboard from the user's
// role; signing out anywhere sends the user to `/login`. Detail screens are
// still pushed imperatively (Navigator.push) on top of these routes.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/assessments/data/assessments_repository.dart';
import 'features/assessments/models/mentor_report_v2.dart';
import 'features/assessments/screens/mentor_report_v2_screen.dart';
import 'features/assessments/screens/mentor_submission_detail_screen.dart';
import 'screens/agreement_sign_public_screen.dart';
import 'screens/assessment_screen.dart';
import 'screens/auth_gate.dart';
import 'screens/signup_screen.dart';
import 'screens/simple_login_screen.dart';
import 'screens/trivia_challenge_detail_screen.dart';
import 'services/api_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// App-wide snackbars that must survive a route change (e.g. after sign-out).
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Routes reachable while signed out.
bool _isPublic(String location) =>
    location == '/login' || location == '/signup' || location.startsWith('/agreements/sign/');

final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/',
  refreshListenable: _AuthChanges(),
  redirect: (context, state) {
    final signedIn = FirebaseAuth.instance.currentUser != null;
    if (!signedIn && !_isPublic(state.matchedLocation)) return '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const AuthGate()),
    GoRoute(path: '/login', builder: (_, _) => const SimpleLoginScreen()),
    GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
    // Deep link from draft reminder email
    GoRoute(
      path: '/assessment/draft/:draftId',
      builder: (_, state) => AssessmentScreen(draftId: state.pathParameters['draftId']),
    ),
    GoRoute(
      path: '/agreements/sign/:tokenType/:token',
      builder: (_, state) => AgreementSignPublicScreen(
        token: state.pathParameters['token']!,
        tokenType: state.pathParameters['tokenType']!,
      ),
    ),
    // Mentor-only screens; access is enforced server-side (403).
    GoRoute(
      path: '/mentor/submissions/:assessmentId',
      builder: (_, state) {
        final args = state.extra is Map ? state.extra as Map : const {};
        return MentorSubmissionDetailScreen(
          assessmentId: state.pathParameters['assessmentId']!,
          apprenticeId: args['apprenticeId'] is String ? args['apprenticeId'] as String : '',
          apprenticeName: args['apprenticeName'] is String ? args['apprenticeName'] as String : 'Apprentice',
        );
      },
      routes: [
        GoRoute(
          path: 'report',
          builder: (_, state) {
            final args = state.extra is Map ? state.extra as Map : const {};
            return _MentorReportLoader(
              assessmentId: state.pathParameters['assessmentId']!,
              apprenticeName: args['apprenticeName'] is String ? args['apprenticeName'] as String : 'Apprentice',
            );
          },
        ),
      ],
    ),
    // Deep link from push notifications
    GoRoute(
      path: '/trivia/challenges/:challengeId',
      builder: (_, state) => TriviaChallengeDetailScreen(challengeId: state.pathParameters['challengeId']!),
    ),
  ],
);

/// Re-runs the redirect whenever the signed-in user changes.
class _AuthChanges extends ChangeNotifier {
  _AuthChanges() {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
}

class _MentorReportLoader extends StatefulWidget {
  const _MentorReportLoader({required this.assessmentId, required this.apprenticeName});

  final String assessmentId;
  final String apprenticeName;

  @override
  State<_MentorReportLoader> createState() => _MentorReportLoaderState();
}

class _MentorReportLoaderState extends State<_MentorReportLoader> {
  late final Future<MentorReportV2> _report =
      AssessmentsRepository(ApiService()).getMentorReportV2(widget.assessmentId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MentorReportV2>(
      future: _report,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text("Couldn't load this report. Please go back and try again.", textAlign: TextAlign.center),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return MentorReportV2Screen(report: snap.data!, apprenticeName: widget.apprenticeName);
      },
    );
  }
}
