import 'package:flutter/material.dart';
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

  // The router sends signed-out users to /login.
  await signOutEverywhere();
}

/// Single sign-out path: unregister push, detach RevenueCat, then Firebase.
/// Use this for logout and account deletion so the next user on the device
/// starts clean.
Future<void> signOutEverywhere() => SessionController().signOut();
