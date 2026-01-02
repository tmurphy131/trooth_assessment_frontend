import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'package:app_links/app_links.dart';
import 'screens/agreement_sign_public_screen.dart';
import 'theme.dart';
// import 'screens/splash_screen.dart'; // legacy complex splash (kept for later)
import 'screens/simple_login_screen.dart';
import 'services/api_service.dart';
import 'features/assessments/screens/mentor_submission_detail_screen.dart';
import 'features/assessments/screens/mentor_report_v2_screen.dart';
import 'features/assessments/data/assessments_repository.dart';
import 'features/assessments/models/mentor_report_v2.dart';

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

  // Hold the native splash for an additional 5 seconds per request.
  await Future.delayed(const Duration(seconds: 5));

  // Explicit sign-in only: listen for auth changes and update ApiService token.
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      try {
        final result = await user.getIdTokenResult();
        final token = result.token;
        if (token != null) {
          ApiService().bearerToken = token;
          print('🔐 User signed in');
        }
      } catch (e) {
        print('⚠️ Failed to fetch ID token after sign-in: $e');
      }
    } else {
      ApiService().bearerToken = null;
      print('👋 User signed out; cleared bearer token');
    }
  });

  // Point the frontend to the deployed backend for development/testing.
  // Update this URL if you deploy to a different host.
  ApiService().baseUrlOverride = 'https://trooth-discipleship-api.onlyblv.com';

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

    // Remove native splash now that initialization and delay are done.
    FlutterNativeSplash.remove();
    runApp(const MyApp());
  }, (error, stack) {
    // Last‑resort zone error logging
    debugPrint('💥 Uncaught zone error: $error\n$stack');
  });
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _handleIncomingUri(Uri link) {
  if (link.pathSegments.length == 4 && link.pathSegments[0] == 'agreements' && link.pathSegments[1] == 'sign') {
    final tokenType = link.pathSegments[2];
    final token = link.pathSegments[3];
    navigatorKey.currentState?.pushNamed('/agreements/sign/$tokenType/$token');
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
    return MaterialApp(
      title: 'T[root]H Discipleship',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
  navigatorKey: navigatorKey,
  home: const SimpleLoginScreen(), // Use only native launch screen, then show Login
      onGenerateRoute: (settings) {
        // Expected pattern: /agreements/sign/:tokenType/:token
        final uri = Uri.parse(settings.name ?? '');
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
