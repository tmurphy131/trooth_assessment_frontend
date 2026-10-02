// lib/services/session_controller.dart
//
// Owns what happens when a user signs in or out, in one place and in order:
// RevenueCat identity, subscription state, push registration, cached API
// reads. Screens never set tokens themselves; ApiService fetches a fresh
// Firebase ID token for every request.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'push_notification_service.dart';
import 'subscription_service.dart';

class SessionController {
  factory SessionController() => _instance;
  SessionController._();
  static final SessionController _instance = SessionController._();

  StreamSubscription<User?>? _authSub;
  String? _uid;

  // Sign-in and sign-out work runs one step at a time, so a quick
  // sign-out → sign-in can't interleave the two (e.g. RevenueCat logOut
  // landing after the next user's logIn).
  Future<void> _queue = Future.value();

  /// Starts following Firebase auth state. Call once, after Firebase init.
  void start({required void Function(Map<String, dynamic> data) onNotificationTap}) {
    PushNotificationService().onNotificationTap = onNotificationTap;
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      final uid = user?.uid;
      if (uid == _uid) return; // token refreshes re-emit the same user
      _uid = uid;
      _enqueue(uid == null ? _onSignedOut : () => _onSignedIn(uid));
    });
  }

  /// Signs out everywhere: unregisters push, detaches RevenueCat, then
  /// Firebase. Use for logout and account deletion so the next user on the
  /// device starts clean.
  Future<void> signOut() {
    final done = Completer<void>();
    _enqueue(() async {
      try {
        await _try('push unregister', () => PushNotificationService().onLogout());
        await _try('subscription sign-out', () => SubscriptionService().signOut());
        ApiService().clearCache();
        await FirebaseAuth.instance.signOut();
        done.complete();
      } catch (e, stack) {
        done.completeError(e, stack);
      }
    });
    return done.future;
  }

  Future<void> _onSignedIn(String uid) async {
    ApiService().clearCache();
    await _try('subscription init', () => SubscriptionService().initialize(uid));
    // Not awaited: on iOS this waits for the user to answer the notification
    // prompt, and later sign-in/sign-out steps must not queue behind that.
    unawaited(_try('push init', () => PushNotificationService().initialize()));
  }

  Future<void> _onSignedOut() async {
    ApiService()
      ..bearerToken = null
      ..clearCache();
    SubscriptionService().clear();
  }

  void _enqueue(Future<void> Function() step) {
    _queue = _queue.then((_) => step()).catchError((Object e) {
      debugPrint('⚠️ Session step failed: $e');
    });
  }

  static Future<void> _try(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('⚠️ Session $what failed: $e');
    }
  }
}
