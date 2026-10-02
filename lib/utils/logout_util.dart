import 'package:flutter/material.dart';
import '../screens/simple_login_screen.dart';
import '../services/session_controller.dart';

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
Future<void> signOutEverywhere() => SessionController().signOut();
