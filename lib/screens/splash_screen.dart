import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:page_transition/page_transition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'simple_login_screen.dart';
import 'mentor_dashboard_new.dart';
import 'apprentice_dashboard_new.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  Future<Widget> _checkAuth() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SimpleLoginScreen();
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();

    if (data == null || data['onboarded'] != true) {
      return const OnboardingScreen();
    }

    final role = data['role'];
    if (role == 'mentor') {
      return const MentorDashboardNew();
    } else if (role == 'apprentice') {
      return const ApprenticeDashboardNew();
    }

    return const SimpleLoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _checkAuth(),
      builder: (context, snapshot) {
        return AnimatedSplashScreen.withScreenFunction(
          splash: Center(
            child: Image.asset(
              "assets/logo.png",
              height: 375,
              fit: BoxFit.contain,
            ),
          ),
          splashIconSize: 400,
          backgroundColor: Colors.black,
          duration: 1800,
          pageTransitionType: PageTransitionType.fade,
          screenFunction: () async => snapshot.data ?? const SimpleLoginScreen(),
        );
      },
    );
  }
}
