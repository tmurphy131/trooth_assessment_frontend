// lib/services/push_notification_service.dart
//
// Push notification service for T[root]H Discipleship app.
// Handles FCM token management, permission requests, and notification handling.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');
  // Background messages are handled by the system notification tray
  // No need to show local notification here
}

/// Service for managing push notifications via Firebase Cloud Messaging
class PushNotificationService {
  /* ── Singleton ──────────────────────────────────────────────────────── */
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();
  static final PushNotificationService _instance = PushNotificationService._internal();

  /* ── State ──────────────────────────────────────────────────────────── */
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  String? _fcmToken;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  /// Callback for handling notification taps (set by the app)
  void Function(Map<String, dynamic> data)? onNotificationTap;

  /// Get the current FCM token (may be null if not initialized or permission denied)
  String? get fcmToken => _fcmToken;

  /// Check if push notifications are initialized
  bool get isInitialized => _isInitialized;

  /* ── Initialization ─────────────────────────────────────────────────── */

  /// Initialize push notification service
  /// Call this after Firebase.initializeApp() and user login
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('🔔 PushNotificationService already initialized');
      return true;
    }

    try {
      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Initialize local notifications for foreground display
      await _initializeLocalNotifications();

      // Request permission
      final permissionGranted = await requestPermission();
      if (!permissionGranted) {
        debugPrint('🔔 Push notification permission not granted');
        return false;
      }

      // On iOS, wait for APNs token before getting FCM token
      if (Platform.isIOS) {
        await _waitForAPNsToken();
      }

      // Get FCM token
      _fcmToken = await _messaging.getToken();
      debugPrint('🔔 FCM Token: ${_fcmToken?.substring(0, 20)}...');

      if (_fcmToken != null) {
        // Register with backend
        await _registerTokenWithBackend(_fcmToken!);
        
        // Save token locally for logout cleanup
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
      }

      // Listen for token refresh
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(_onTokenRefresh);

      // Handle foreground messages
      _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Handle notification tap when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

      // Check if app was opened from a notification (cold start)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔔 App opened from terminated state via notification');
        // Delay handling to allow app to fully initialize
        Future.delayed(const Duration(milliseconds: 500), () {
          _onNotificationTap(initialMessage);
        });
      }

      _isInitialized = true;
      debugPrint('✅ PushNotificationService initialized successfully');
      return true;
    } catch (e, stack) {
      debugPrint('❌ Failed to initialize push notifications: $e');
      debugPrint('$stack');
      return false;
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // We request via FCM
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'trooth_notifications', // id
        'T[root]H Notifications', // name
        description: 'Notifications from T[root]H Discipleship app',
        importance: Importance.high,
      );
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  /* ── APNs Token (iOS) ───────────────────────────────────────────────── */

  /// Wait for APNs token on iOS before getting FCM token
  /// APNs token is required for FCM to work on iOS
  Future<void> _waitForAPNsToken() async {
    debugPrint('🔔 Waiting for APNs token...');
    
    // Try up to 10 times with 500ms delay (5 seconds total)
    for (int i = 0; i < 10; i++) {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken != null) {
        debugPrint('🔔 APNs token received (attempt ${i + 1})');
        return;
      }
      debugPrint('🔔 APNs token not ready, waiting... (attempt ${i + 1})');
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // If we still don't have it, log warning but continue
    // FCM might still work or fail gracefully
    debugPrint('⚠️ APNs token not received after 5 seconds, continuing anyway');
  }

  /* ── Permission ─────────────────────────────────────────────────────── */

  /// Request notification permission from the user
  /// Returns true if permission was granted
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final status = settings.authorizationStatus;
    debugPrint('🔔 Notification permission status: $status');

    return status == AuthorizationStatus.authorized ||
           status == AuthorizationStatus.provisional;
  }

  /// Check current permission status without requesting
  Future<AuthorizationStatus> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /* ── Token Management ───────────────────────────────────────────────── */

  /// Handle token refresh - update backend with new token
  Future<void> _onTokenRefresh(String newToken) async {
    debugPrint('🔔 FCM token refreshed: ${newToken.substring(0, 20)}...');
    
    final oldToken = _fcmToken;
    _fcmToken = newToken;

    // Unregister old token if different
    if (oldToken != null && oldToken != newToken) {
      await _unregisterTokenFromBackend(oldToken);
    }

    // Register new token
    await _registerTokenWithBackend(newToken);

    // Update local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', newToken);
  }

  /// Register FCM token with backend
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      final platform = _getPlatform();
      await ApiService().registerDevice(fcmToken: token, platform: platform);
      debugPrint('✅ FCM token registered with backend');
    } catch (e) {
      debugPrint('⚠️ Failed to register FCM token with backend: $e');
      // Don't throw - notifications can still work locally
    }
  }

  /// Unregister FCM token from backend
  Future<void> _unregisterTokenFromBackend(String token) async {
    try {
      await ApiService().unregisterDevice(fcmToken: token);
      debugPrint('✅ FCM token unregistered from backend');
    } catch (e) {
      debugPrint('⚠️ Failed to unregister FCM token from backend: $e');
    }
  }

  /// Get platform string for backend
  String _getPlatform() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (kIsWeb) return 'web';
    return 'unknown';
  }

  /* ── Message Handling ───────────────────────────────────────────────── */

  /// Handle foreground messages - show local notification
  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 Foreground message: ${message.notification?.title}');
    
    final notification = message.notification;
    if (notification == null) return;

    // Show local notification
    _showLocalNotification(
      title: notification.title ?? 'T[root]H',
      body: notification.body ?? '',
      payload: jsonEncode(message.data),
    );
  }

  /// Show a local notification (for foreground messages)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'trooth_notifications',
      'T[root]H Notifications',
      channelDescription: 'Notifications from T[root]H Discipleship app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use timestamp as notification ID for uniqueness
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Handle notification tap from FCM (background/terminated)
  void _onNotificationTap(RemoteMessage message) {
    debugPrint('🔔 Notification tapped: ${message.data}');
    _handleNotificationData(message.data);
  }

  /// Handle notification tap from local notification (foreground)
  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('🔔 Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _handleNotificationData(data);
      } catch (e) {
        debugPrint('⚠️ Failed to parse notification payload: $e');
      }
    }
  }

  /// Process notification data and trigger navigation
  void _handleNotificationData(Map<String, dynamic> data) {
    if (onNotificationTap != null) {
      onNotificationTap!(data);
    } else {
      debugPrint('⚠️ No notification tap handler registered');
    }
  }

  /* ── Cleanup ────────────────────────────────────────────────────────── */

  /// Call on user logout to unregister device
  Future<void> onLogout() async {
    debugPrint('🔔 Cleaning up push notifications on logout');
    
    // Get token from local storage (in case _fcmToken is null)
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('fcm_token');
    final tokenToUnregister = _fcmToken ?? storedToken;

    if (tokenToUnregister != null) {
      await _unregisterTokenFromBackend(tokenToUnregister);
    }

    // Clear local storage
    await prefs.remove('fcm_token');
    
    // Reset initialization flag so next login will re-register
    _isInitialized = false;
    
    // Note: We don't delete the FCM token itself - it's still valid
    // for the device. We just unlink it from this user on the backend.
  }

  /// Dispose of subscriptions (typically not needed for singleton)
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    _isInitialized = false;
  }

  /* ── Utility ────────────────────────────────────────────────────────── */

  /// Subscribe to a topic (e.g., 'mentors', 'apprentices')
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('🔔 Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('🔔 Unsubscribed from topic: $topic');
  }
}
