import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'push_notification_service.dart';

/// Daily on-device prayer reminder. Nothing is sent to the backend.
class PrayerReminderService {
  factory PrayerReminderService() => _instance;
  PrayerReminderService._internal();
  static final PrayerReminderService _instance = PrayerReminderService._internal();

  static const _notificationId = 7001;
  static const _enabledKey = 'prayer_reminder_enabled';
  static const _hourKey = 'prayer_reminder_hour';
  static const _minuteKey = 'prayer_reminder_minute';
  static const defaultTime = TimeOfDay(hour: 8, minute: 0);

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _tzReady = false;

  Future<({bool enabled, TimeOfDay time})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      enabled: prefs.getBool(_enabledKey) ?? false,
      time: TimeOfDay(
        hour: prefs.getInt(_hourKey) ?? defaultTime.hour,
        minute: prefs.getInt(_minuteKey) ?? defaultTime.minute,
      ),
    );
  }

  /// Schedules the daily reminder. Returns false if notification permission
  /// was denied, in which case nothing is scheduled or saved as enabled.
  Future<bool> enable(TimeOfDay time) async {
    await PushNotificationService().ensureLocalNotifications();
    if (!await _requestPermission()) return false;
    await _ensureTimezone();

    await _plugin.cancel(id: _notificationId);
    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Time to pray 🙏',
      body: 'Take a few minutes with God and your prayer journal.',
      scheduledDate: _nextInstanceOf(time),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_reminders',
          'Prayer reminders',
          channelDescription: 'Daily reminder to pray',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact avoids the exact-alarm permission; a few minutes' drift is fine.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setInt(_hourKey, time.hour);
    await prefs.setInt(_minuteKey, time.minute);
    return true;
  }

  Future<void> disable() async {
    await PushNotificationService().ensureLocalNotifications();
    await _plugin.cancel(id: _notificationId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  Future<bool> _requestPermission() async {
    if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? true; // null below Android 13, where no runtime permission exists
    }
    return false;
  }

  Future<void> _ensureTimezone() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      // Unknown zone name: fall back to UTC rather than failing to schedule.
    }
    _tzReady = true;
  }

  tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }
}
