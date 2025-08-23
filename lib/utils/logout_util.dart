import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/simple_login_screen.dart';

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

  await FirebaseAuth.instance.signOut();

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const SimpleLoginScreen()),
    (route) => false,
  );
}
