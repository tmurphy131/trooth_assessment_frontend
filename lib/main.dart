import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:uni_links/uni_links.dart';
import 'screens/agreement_sign_public_screen.dart';
import 'theme.dart';
import 'screens/splash_screen.dart'; // splash / auth bootstrap
import 'services/api_service.dart';

void main() {
  // Wrap everything so uncaught async errors surface in logs & UI.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

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
  ApiService().baseUrlOverride = 'https://trooth-assessment-dev.onlyblv.com';

  // Quick connectivity check at startup — logs the backend response.
  try {
    final pingMessage = await ApiService().ping();
    print('✅ Backend ping successful: $pingMessage');
  } catch (e) {
    print('⚠️ Backend ping failed: $e');
  }

  // Handle initial link (cold start)
  try {
    final initialUri = await getInitialUri();
    if (initialUri != null) {
      _handleIncomingUri(initialUri);
    }
  } catch (e) {
    print('⚠️ Failed to get initial URI: $e');
  }

  // Listen to incoming links (warm / background)
  uriLinkStream.listen((uri) {
    if (uri != null) {
      _handleIncomingUri(uri);
    }
  }, onError: (err) {
    print('⚠️ URI stream error: $err');
  });

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
      title: 'T[root]H Assessment',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: const SplashScreen(), // <-- Use splash first
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
        return null; // fall back to unknown
      },
    );
  }
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
