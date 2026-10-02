import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'package:app_links/app_links.dart';
import 'screens/agreement_sign_public_screen.dart';
import 'screens/assessment_screen.dart';
import 'theme.dart';
import 'screens/auth_gate.dart';
import 'services/api_service.dart';
import 'services/session_controller.dart';
import 'features/assessments/screens/mentor_submission_detail_screen.dart';
import 'features/assessments/screens/mentor_report_v2_screen.dart';
import 'features/assessments/data/assessments_repository.dart';
import 'features/assessments/models/mentor_report_v2.dart';
import 'screens/weekly_tip_detail_screen.dart';
import 'screens/apprentice_weekly_tip_detail_screen.dart';
import 'data/weekly_tips_data.dart';
import 'data/apprentice_weekly_tips_data.dart';
import 'screens/trivia_challenge_detail_screen.dart';
import 'utils/deep_links.dart';
import 'services/tutorial_service.dart';
import 'screens/apprentice_invites_screen.dart';
import 'screens/mentor_agreements_screen.dart';

void main() {
  // Wrap everything so uncaught async errors surface in logs & UI.
  runZonedGuarded(() async {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    // Keep the native splash visible until we explicitly remove it.
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    // Attach a global error handler for framework errors.
    FlutterError.onError = (FlutterErrorDetails details) {
      // Always log full details.
      FlutterError.dumpErrorToConsole(details);
    };

    // Replace red screen (in release becomes a silent fail) with a visible banner style.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      if (!kDebugMode) {
        return const Material(
          color: Colors.black,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Something went wrong. Please go back and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade900,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent, width: 2),
            ),
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('App Error', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    details.exceptionAsString(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (details.stack ?? StackTrace.empty).toString().split('\n').take(8).join('\n'),
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 11, height: 1.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };

    final firebaseStopwatch = Stopwatch()..start();
    debugPrint('🔄 Firebase.initializeApp starting...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseStopwatch.stop();
    debugPrint('✅ Firebase.initializeApp completed in ${firebaseStopwatch.elapsedMilliseconds}ms');

    // Crash reporting (release only; debug errors stay in the console).
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
      crashlytics.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };

  // Sign-in/sign-out side effects (RevenueCat, push, caches) live in one place.
  SessionController().start(onNotificationTap: _handleNotificationTap);

  // Handle initial link (cold start) and stream (app_links)
  final appLinks = AppLinks();
  try {
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null) {
      _handleIncomingUri(initialUri);
    }
  } catch (e) {
    print('⚠️ Failed to get initial URI: $e');
  }

  // Listen to incoming links (warm / background)
  appLinks.uriLinkStream.listen((uri) {
    _handleIncomingUri(uri);
  }, onError: (err) {
    print('⚠️ URI stream error: $err');
  });

    // Note: Native splash is removed in AuthGate after auth state is resolved
    runApp(const MyApp());
  }, (error, stack) {
    // Last‑resort zone error logging
    debugPrint('💥 Uncaught zone error: $error\n$stack');
    if (Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  },
      // print() output reaches device logs in release builds; keep it debug-only.
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          if (kDebugMode) parent.print(zone, line);
        },
      ));
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _handleIncomingUri(Uri link) {
  final routeName = routeNameForLink(link);
  if (routeName == null) return;
  TutorialService.dismissActive();
  navigatorKey.currentState?.pushNamed(routeName);
}

/// Handle notification tap - navigate to appropriate screen based on notification data
void _handleNotificationTap(Map<String, dynamic> data) {
  debugPrint('🔔 Handling notification tap: $data');
  
  final type = data['type'] as String?;
  TutorialService.dismissActive();
  
  switch (type) {
    case 'assessment_submitted':
      // Navigate to assessment detail
      final assessmentId = data['assessment_id'] as String?;
      if (assessmentId != null) {
        navigatorKey.currentState?.pushNamed(
          '/mentor/submissions/$assessmentId',
          arguments: {
            'apprenticeName': data['apprentice_name'] ?? 'Apprentice',
            'apprenticeId': data['apprentice_id'] ?? '',
          },
        );
      }
      break;
      
    case 'weekly_tip':
      final isMentor = data['is_mentor'] != 'false';
      if (isMentor) {
        final tip = getCurrentWeekTip();
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => WeeklyTipDetailScreen(tip: tip)),
        );
      } else {
        final tip = getApprenticeCurrentWeekTip();
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => ApprenticeWeeklyTipDetailScreen(tip: tip)),
        );
      }
      break;
      
    case 'invitation_received':
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ApprenticeInvitesScreen()),
      );
      break;
      
    case 'agreement_signed':
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const MentorAgreementsScreen()),
      );
      break;
      
    case 'trivia_challenge_received':
    case 'trivia_question_unlocked':
    case 'trivia_challenge_result':
    case 'trivia_nudge':
    case 'trivia_challenge_expired':
      final challengeId = data['challenge_id'] as String?;
      if (challengeId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => TriviaChallengeDetailScreen(challengeId: challengeId),
          ),
        );
      }
      break;

    default:
      debugPrint('🔔 Unknown notification type: $type');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Log first frame after build of root widget tree to detect if we ever paint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🖼️ First Flutter frame rendered (postFrameCallback)');
    });

    return GestureDetector(
      // Dismiss keyboard when tapping outside of text fields
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: MaterialApp(
        title: 'T[root]H Discipleship',
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        // Honor larger system text, but cap it so fixed layouts don't clip at
        // the extreme accessibility sizes (iOS goes past 3x).
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.5,
          child: child!,
        ),
        home: const AuthGate(), // Check auth state and route to appropriate screen
      onGenerateRoute: (settings) {
        final args = settings.arguments is Map ? settings.arguments as Map : const {};
        final apprenticeName = args['apprenticeName'] is String ? args['apprenticeName'] as String : 'Apprentice';

        switch (parseRouteName(settings.name)) {
          // Deep link from draft reminder email
          case DraftAssessmentRoute(:final draftId):
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => AssessmentScreen(draftId: draftId),
            );
          case AgreementSignRoute(:final tokenType, :final token):
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => AgreementSignPublicScreen(token: token, tokenType: tokenType),
            );
          case MentorSubmissionRoute(:final assessmentId):
            return _guardedMentorRoute(settings, builder: (ctx) {
              final apprenticeId = args['apprenticeId'] is String ? args['apprenticeId'] as String : '';
              return MentorSubmissionDetailScreen(
                assessmentId: assessmentId,
                apprenticeId: apprenticeId,
                apprenticeName: apprenticeName,
              );
            });
          case MentorReportRoute(:final assessmentId):
            final reportFuture = AssessmentsRepository(ApiService()).getMentorReportV2(assessmentId);
            return _guardedMentorRoute(settings, builder: (ctx) {
              return FutureBuilder<MentorReportV2>(
                future: reportFuture,
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
                  return MentorReportV2Screen(report: snap.data!, apprenticeName: apprenticeName);
                },
              );
            });
          // Deep link from push notifications
          case TriviaChallengeRoute(:final challengeId):
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => TriviaChallengeDetailScreen(challengeId: challengeId),
            );
          case null:
            return null; // fall back to unknown
        }
      },
      ),
    );
  }
}

/// Mentor-only screens. Access is enforced server-side (403); the client
/// doesn't gate these routes.
Route<dynamic> _guardedMentorRoute(RouteSettings settings, {required WidgetBuilder builder}) {
  return MaterialPageRoute(settings: settings, builder: builder);
}
