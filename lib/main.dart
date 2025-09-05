import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:uni_links/uni_links.dart';
import 'screens/agreement_sign_public_screen.dart';
import 'theme.dart';
import 'screens/splash_screen.dart'; // <-- NEW
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
