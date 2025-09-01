import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'simple_login_screen.dart';
import 'mentor_dashboard_new.dart';
import 'apprentice_dashboard_new.dart';
import 'onboarding_screen.dart';

/// Minimal placeholder that matches the native (flutter_native_splash) screen.
/// Shows black background with logo only while auth / profile resolution runs.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  Future<Widget> _resolveStart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SimpleLoginScreen();

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data == null || data['onboarded'] != true) return const OnboardingScreen();
      final role = data['role'];
      if (role == 'mentor') return const MentorDashboardNew();
      if (role == 'apprentice') return const ApprenticeDashboardNew();
    } catch (_) {}
    return const SimpleLoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolveStart(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return snapshot.data!;
        }
        // Placeholder identical to native splash so user perceives a single splash.
        return Scaffold(
          backgroundColor: Colors.black,
          body: const Center(
            child: SizedBox(
              height: 180,
              child: Image(image: AssetImage('assets/logo.png')),
            ),
          ),
        );
      },
    );
  }
}
