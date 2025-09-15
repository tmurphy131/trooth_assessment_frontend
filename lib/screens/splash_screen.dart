import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'simple_login_screen.dart';
import 'mentor_dashboard_new.dart';
import 'apprentice_dashboard_new.dart';
import 'signup_screen.dart';

/// Minimal placeholder that matches the native (flutter_native_splash) screen.
/// Shows black background with logo only while auth / profile resolution runs.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Future<Widget> _next;
  Widget? _resolved;

  Future<Widget> _determineNext() async {
    debugPrint('[Splash] Start resolving destination');
    // Enforce a minimum 5 second splash regardless of auth/profile speed.
    final gate = Future.delayed(const Duration(seconds: 5));
    const hardTimeout = Duration(seconds: 10); // absolute cap

    Future<Widget> destination() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return const SimpleLoginScreen();
      try {
        final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = snap.data();
        final role = data?['role'];
        if (role == 'mentor') return const MentorDashboardNew();
        if (role == 'apprentice') return const ApprenticeDashboardNew();
        return const SignupScreen();
      } catch (_) {
        return const SimpleLoginScreen();
      }
    }

    try {
      final destFuture = destination();
      final results = await Future.wait<Widget>([
        destFuture,
        // Map gate to a dummy widget just to await
        gate.then((_) => const SizedBox.shrink()),
      ]).timeout(hardTimeout, onTimeout: () {
        debugPrint('[Splash] Timeout after ${hardTimeout.inSeconds}s; falling back to login');
        return const [SimpleLoginScreen(), SizedBox.shrink()];
      });
      debugPrint('[Splash] Destination resolved: ${results.first.runtimeType}');
      return results.first;
    } catch (e, st) {
      debugPrint('[Splash] Error determining start screen: $e\n$st');
      return const SimpleLoginScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    _next = _determineNext();
    _next.then((w) {
      if (!mounted) return;
      debugPrint('[Splash] Future completed with ${w.runtimeType}; swapping child in-place');
      setState(() {
        _resolved = w;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_resolved != null) {
      return _TransitionDebugWrapper(child: _resolved!);
    }
    return const _SplashScaffold();
  }
}

class _SplashScaffold extends StatelessWidget {
  const _SplashScaffold();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: const [
          Center(
            child: SizedBox(
              height: 180,
              child: Image(image: AssetImage('assets/logo.png')),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Text('Splash...', style: TextStyle(color: Colors.white54, fontSize: 12)),
          )
        ],
      ),
    );
  }
}

/// Wraps a destination widget to log first build & paint after splash.
class _TransitionDebugWrapper extends StatefulWidget {
  final Widget child;
  const _TransitionDebugWrapper({required this.child});

  @override
  State<_TransitionDebugWrapper> createState() => _TransitionDebugWrapperState();
}

class _TransitionDebugWrapperState extends State<_TransitionDebugWrapper> {
  bool _postFrameLogged = false;
  @override
  void initState() {
    super.initState();
    debugPrint('[TransitionDebug] initState for ${widget.child.runtimeType}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_postFrameLogged) {
        _postFrameLogged = true;
        debugPrint('[TransitionDebug] First frame of ${widget.child.runtimeType} rendered');
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        const Positioned(
          right: 8,
          bottom: 8,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0x661E88E5), borderRadius: BorderRadius.all(Radius.circular(4))),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text('DBG', style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
          ),
        )
      ],
    );
  }
}
