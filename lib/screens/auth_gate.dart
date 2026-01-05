import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'simple_login_screen.dart';
import 'mentor_dashboard_new.dart';
import 'apprentice_dashboard_new.dart';
import 'signup_screen.dart';
import '../services/api_service.dart';

/// AuthGate checks Firebase Auth state on app startup and routes accordingly:
/// - If user is logged in → fetch role from Firestore → navigate to appropriate dashboard
/// - If no user → show login screen
/// 
/// This enables persistent login sessions across app restarts.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        // No user logged in → show login screen
        debugPrint('🔐 AuthGate: No user found, showing login');
        if (mounted) {
          setState(() {
            _destination = const SimpleLoginScreen();
            _isLoading = false;
          });
        }
        return;
      }

      debugPrint('🔐 AuthGate: Found user ${user.email}, fetching role...');
      
      // User exists → refresh token and set in ApiService
      try {
        final result = await user.getIdTokenResult(true); // force refresh
        final token = result.token;
        if (token != null) {
          ApiService().bearerToken = token;
          debugPrint('🔐 AuthGate: Token refreshed');
        }
      } catch (e) {
        debugPrint('⚠️ AuthGate: Token refresh failed: $e');
      }

      // Fetch role from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final data = doc.data();
      final role = data?['role'] as String?;
      
      debugPrint('🔐 AuthGate: User role = $role');
      
      if (!mounted) return;
      
      if (role == 'mentor') {
        setState(() {
          _destination = const MentorDashboardNew();
          _isLoading = false;
        });
      } else if (role == 'apprentice') {
        setState(() {
          _destination = const ApprenticeDashboardNew();
          _isLoading = false;
        });
      } else {
        // Legacy user or missing profile → send to signup to complete
        debugPrint('🔐 AuthGate: No role found, redirecting to signup');
        setState(() {
          _destination = const SignupScreen();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ AuthGate: Error checking auth state: $e');
      // On error, fall back to login screen
      if (mounted) {
        setState(() {
          _destination = const SimpleLoginScreen();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Show a loading screen that matches the splash (black bg with logo)
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png',
                width: 200,
                height: 200,
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            ],
          ),
        ),
      );
    }
    
    return _destination!;
  }
}
