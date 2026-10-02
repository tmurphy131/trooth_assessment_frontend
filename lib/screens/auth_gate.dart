import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'simple_login_screen.dart';
import 'mentor_dashboard_new.dart';
import 'apprentice_dashboard_new.dart';
import 'signup_screen.dart';
import '../services/api_service.dart';
import '../utils/role_cache.dart';

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
        FlutterNativeSplash.remove();
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
      if (role != null) await cacheRole(user.uid, role);
      
      if (!mounted) return;
      _routeForRole(role);
    } catch (e) {
      debugPrint('❌ AuthGate: Error checking auth state: $e');
      // Still signed in, just offline or the server is down. Use the last
      // known role rather than bouncing the user to the login screen.
      final user = FirebaseAuth.instance.currentUser;
      final lastRole = user == null ? null : await cachedRole(user.uid);
      if (!mounted) return;
      if (lastRole != null) {
        _routeForRole(lastRole);
        return;
      }
      FlutterNativeSplash.remove();
      setState(() {
        _destination = user == null ? const SimpleLoginScreen() : _ConnectionErrorView(onRetry: _retry);
        _isLoading = false;
      });
    }
  }

  void _retry() {
    setState(() => _isLoading = true);
    _checkAuthState();
  }

  void _routeForRole(String? role) {
      if (role == 'mentor') {
        FlutterNativeSplash.remove();
        setState(() {
          _destination = const MentorDashboardNew();
          _isLoading = false;
        });
      } else if (role == 'apprentice') {
        FlutterNativeSplash.remove();
        setState(() {
          _destination = const ApprenticeDashboardNew();
          _isLoading = false;
        });
      } else {
        // Legacy user or missing profile → send to signup to complete
        debugPrint('🔐 AuthGate: No role found, redirecting to signup');
        FlutterNativeSplash.remove();
        setState(() {
          _destination = const SignupScreen();
          _isLoading = false;
        });
      }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Show a loading screen that matches the splash (black bg with logo)
      // Mirrors the native splash (black, 150-wide centered logo) so the
      // handover is invisible; the spinner sits below without moving the logo.
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset('assets/splash/splash_logo.png', width: 150),
            const Padding(
              padding: EdgeInsets.only(top: 160),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return _destination!;
  }
}

class _ConnectionErrorView extends StatelessWidget {
  const _ConnectionErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Can't connect right now",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
