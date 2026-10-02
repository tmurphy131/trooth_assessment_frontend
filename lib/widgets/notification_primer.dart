import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/push_notification_service.dart';

/// Explains why notifications matter before the one-shot system prompt.
/// Shown only while permission hasn't been asked; "Not now" waits a week.
class NotificationPrimer {
  static const _snoozeKey = 'notification_primer_snoozed_until';
  static const _snooze = Duration(days: 7);
  static bool _showing = false;

  static Future<void> maybeShow(BuildContext context, {required String reason}) async {
    if (_showing || !(Platform.isIOS || Platform.isAndroid)) return;
    try {
      final status = await PushNotificationService().getPermissionStatus();
      if (status != AuthorizationStatus.notDetermined) return;
      final prefs = await SharedPreferences.getInstance();
      final until = DateTime.tryParse(prefs.getString(_snoozeKey) ?? '');
      if (until != null && DateTime.now().isBefore(until)) return;
      if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) return;

      _showing = true;
      final enable = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: const Color(0xFF1C1C1E),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => _PrimerSheet(reason: reason),
      );
      _showing = false;

      if (enable == true) {
        await PushNotificationService().enableFromUser();
      } else {
        await prefs.setString(_snoozeKey, DateTime.now().add(_snooze).toIso8601String());
      }
    } catch (e) {
      _showing = false;
      debugPrint('⚠️ Notification primer failed: $e');
    }
  }
}

class _PrimerSheet extends StatelessWidget {
  const _PrimerSheet({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active_outlined, color: Color(0xFFD4AF37), size: 48, semanticLabel: 'Notifications'),
            const SizedBox(height: 16),
            const Text(
              'Stay in the loop',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4, fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Turn on notifications'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
