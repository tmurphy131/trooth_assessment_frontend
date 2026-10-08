import 'package:flutter/material.dart';

import '../screens/subscription_screen.dart';

/// "Premium Required" prompt with a path to the subscription screen.
///
/// UI hint only: the backend enforces premium (403) and callers also show
/// this when they catch a PremiumRequiredException.
Future<void> showPremiumUpgradeDialog(BuildContext context, {required String message}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Row(
        children: [
          Icon(Icons.lock, color: Colors.amber),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Premium Required',
              style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Not now', style: TextStyle(color: Colors.white60, fontFamily: 'Poppins')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            );
          },
          child: const Text('Upgrade', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
