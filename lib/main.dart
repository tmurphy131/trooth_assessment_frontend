import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'package:app_links/app_links.dart';
import 'screens/agreement_sign_public_screen.dart';
import 'screens/assessment_screen.dart';
import 'theme.dart';
// import 'screens/splash_screen.dart'; // legacy complex splash (kept for later)
import 'screens/simple_login_screen.dart';
import 'screens/auth_gate.dart';
import 'services/api_service.dart';
import 'services/push_notification_service.dart';
import 'services/subscription_service.dart';
import 'features/assessments/screens/mentor_submission_detail_screen.dart';
import 'features/assessments/screens/mentor_report_v2_screen.dart';
import 'features/assessments/data/assessments_repository.dart';
import 'features/assessments/models/mentor_report_v2.dart';
import 'screens/weekly_tip_detail_screen.dart';
import 'screens/apprentice_weekly_tip_detail_screen.dart';
import 'data/weekly_tips_data.dart';
import 'data/apprentice_weekly_tips_data.dart';

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

  // Explicit sign-in only: listen for auth changes and update ApiService token.
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      try {
        final result = await user.getIdTokenResult();
        final token = result.token;
        if (token != null) {
          ApiService().bearerToken = token;
          print('🔐 User signed in');
          
          // Initialize subscription service after successful sign-in
          try {
            await SubscriptionService().initialize(user.uid);
            print('💳 Subscription service initialized');
          } catch (e) {
            print('⚠️ Subscription service init failed: $e');
          }
          
          // Initialize push notifications after successful sign-in
          // Small delay to ensure auth token is fully set up
          Future.delayed(const Duration(milliseconds: 500), () async {
            try {
              final pushService = PushNotificationService();
              // Set up notification tap handler
              pushService.onNotificationTap = _handleNotificationTap;
              await pushService.initialize();
            } catch (e) {
              print('⚠️ Push notification init failed: $e');
            }
          });
        }
      } catch (e) {
        print('⚠️ Failed to fetch ID token after sign-in: $e');
      }
    } else {
      ApiService().bearerToken = null;
      SubscriptionService().clear(); // Clear subscription state on logout
      print('👋 User signed out; cleared bearer token');
    }
  });

  // Point the frontend to the deployed backend for development/testing.
  // Update this URL if you deploy to a different host.
  ApiService().baseUrlOverride = 'https://trooth-discipleship-api.onlyblv.com/';

  // Quick connectivity check at startup — logs the backend response.
  try {
    final pingMessage = await ApiService().ping();
    print('✅ Backend ping successful: $pingMessage');
  } catch (e) {
    print('⚠️ Backend ping failed: $e');
  }

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
  });
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _handleIncomingUri(Uri link) {
  // trooth://assessment/draft/{draftId}
  if (link.host == 'assessment' &&
      link.pathSegments.length == 2 &&
      link.pathSegments[0] == 'draft') {
    final draftId = link.pathSegments[1];
    navigatorKey.currentState?.pushNamed('/assessment/draft/$draftId');
    return;
  }

  // trooth://agreements/sign/{tokenType}/{token}  (or https://links.onlyblv.com/agreements/sign/...)
  if (link.pathSegments.length == 4 && link.pathSegments[0] == 'agreements' && link.pathSegments[1] == 'sign') {
    final tokenType = link.pathSegments[2];
    final token = link.pathSegments[3];
    navigatorKey.currentState?.pushNamed('/agreements/sign/$tokenType/$token');
  }
}

/// Handle notification tap - navigate to appropriate screen based on notification data
void _handleNotificationTap(Map<String, dynamic> data) {
  debugPrint('🔔 Handling notification tap: $data');
  
  final type = data['type'] as String?;
  
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
      // Navigate to invitations screen
      // TODO: Add invitations route when screen exists
      debugPrint('🔔 Invitation received - navigation TBD');
      break;
      
    case 'agreement_signed':
      // Navigate to agreements screen
      final agreementId = data['agreement_id'] as String?;
      if (agreementId != null) {
        // TODO: Add agreement detail route
        debugPrint('🔔 Agreement signed - navigation TBD');
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

    // Diagnostic test screen toggle (set _forceTestScreenRuntime = true during a debugging session)
    final bool forceTestScreen = _forceTestScreenRuntime; // not const to avoid dead code warning
    if (forceTestScreen) {
      return const MaterialApp(debugShowCheckedModeBanner: false, home: _RenderTestScreen());
    }
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
        home: const AuthGate(), // Check auth state and route to appropriate screen
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');

        // /assessment/draft/:draftId — deep link from draft reminder email
        if (uri.pathSegments.length == 3 &&
            uri.pathSegments[0] == 'assessment' &&
            uri.pathSegments[1] == 'draft') {
          final draftId = uri.pathSegments[2];
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => AssessmentScreen(draftId: draftId),
          );
        }

        // Expected pattern: /agreements/sign/:tokenType/:token
        if (uri.pathSegments.length == 4 && uri.pathSegments[0] == 'agreements' && uri.pathSegments[1] == 'sign') {
          final tokenType = uri.pathSegments[2];
          final token = uri.pathSegments[3];
          return MaterialPageRoute(
            builder: (_) => AgreementSignPublicScreen(token: token, tokenType: tokenType),
            settings: settings,
          );
        }

        // Mentor routes
        // /mentor/submissions/:assessmentId
        if (uri.pathSegments.length == 3 && uri.pathSegments[0] == 'mentor' && uri.pathSegments[1] == 'submissions') {
          final assessmentId = uri.pathSegments[2];
          return _guardedMentorRoute(settings, builder: (ctx, claims) {
            final apprenticeName = settings.arguments is Map && (settings.arguments as Map)['apprenticeName'] is String
                ? (settings.arguments as Map)['apprenticeName'] as String
                : 'Apprentice';
            final apprenticeId = settings.arguments is Map && (settings.arguments as Map)['apprenticeId'] is String
                ? (settings.arguments as Map)['apprenticeId'] as String
                : '';
            return MentorSubmissionDetailScreen(
              assessmentId: assessmentId,
              apprenticeId: apprenticeId,
              apprenticeName: apprenticeName,
            );
          });
        }

        // /mentor/submissions/:assessmentId/report
        if (uri.pathSegments.length == 4 && uri.pathSegments[0] == 'mentor' && uri.pathSegments[1] == 'submissions' && uri.pathSegments[3] == 'report') {
          final assessmentId = uri.pathSegments[2];
          return _guardedMentorRoute(settings, builder: (ctx, claims) {
            // We can fetch report here synchronously via repo mock or pass placeholder and let screen fetch.
            // Keep it simple: instantiate repository and fetch in a FutureBuilder.
            final repo = AssessmentsRepository(ApiService());
            return FutureBuilder<MentorReportV2>(
              future: repo.getMentorReportV2(assessmentId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                final apprenticeName = settings.arguments is Map && (settings.arguments as Map)['apprenticeName'] is String
                    ? (settings.arguments as Map)['apprenticeName'] as String
                    : 'Apprentice';
                return MentorReportV2Screen(report: snap.data!, apprenticeName: apprenticeName);
              },
            );
          });
        }
        return null; // fall back to unknown
      },
      ),
    );
  }
}

Route<dynamic> _guardedMentorRoute(RouteSettings settings, {required Widget Function(BuildContext, Map<String, dynamic> claims) builder}) {
  // Simple role guard using Firebase custom claims (mentor/admin). If claims missing, allow and rely on server 403.
  // We still try to fetch claims for UX.
  Future<Map<String, dynamic>> _claims() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};
      final result = await user.getIdTokenResult(true);
      return (result.claims ?? const {});
    } catch (_) { return {}; }
  }

  return MaterialPageRoute(
    settings: settings,
    builder: (context) {
      return FutureBuilder<Map<String, dynamic>>(
        future: _claims(),
        builder: (context, snap) {
          final claims = snap.data ?? const {};
          // Always render the route. Server-side auth (403) will control data access.
          // This avoids blocking UI with an overlay and preserves back navigation.
          if (snap.connectionState == ConnectionState.waiting) {
            // Render target page quickly; let pages show spinners for their own data.
            return builder(context, claims);
          }
          return builder(context, claims);
        },
      );
    },
  );
}

/// Simple diagnostic screen to validate rendering pipeline independent of app logic.
class _RenderTestScreen extends StatelessWidget {
  const _RenderTestScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 72, color: Colors.greenAccent),
            const SizedBox(height: 24),
            Text('Render Test OK', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
            const SizedBox(height: 12),
            Text('If you can see this, the painting pipeline works.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[300])),
          ],
        ),
      ),
    );
  }
}

// Runtime adjustable debug flag (could be wired to a dev menu later)
const bool _forceTestScreenRuntime = false;
