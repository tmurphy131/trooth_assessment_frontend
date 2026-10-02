import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/simple_login_screen.dart';
import '../services/push_notification_service.dart';
import '../services/subscription_service.dart';

void logoutAndRedirect(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Log out?"),
      content: const Text("Are you sure you want to sign out?"),
      actions: [
        TextButton(
          child: const Text("Cancel"),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        ElevatedButton(
          child: const Text("Log out"),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  await signOutEverywhere();

  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const SimpleLoginScreen()),
    (route) => false,
  );
}

/// Single sign-out path: unregister push, detach RevenueCat, then Firebase.
/// Use this for logout and account deletion so the next user on the device
/// starts clean.
Future<void> signOutEverywhere() async {
  try {
    await PushNotificationService().onLogout();
  } catch (e) {
    debugPrint('⚠️ Failed to unregister push notifications: $e');
  }
  try {
    await SubscriptionService().signOut();
  } catch (e) {
    debugPrint('⚠️ Failed to reset subscription state: $e');
  }
  await FirebaseAuth.instance.signOut();
}
