import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'T[root]H Assessment',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // <-- Use splash first
    );
  }
}
