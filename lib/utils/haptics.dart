import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class Haptics {
  static bool enabled = true;

  static Future<void> light() async {
    if (!enabled) return;
    if (Platform.isIOS || Platform.isAndroid) {
      try { await HapticFeedback.lightImpact(); } catch (_) {}
    }
  }

  static Future<void> medium() async {
    if (!enabled) return;
    if (Platform.isIOS || Platform.isAndroid) {
      try { await HapticFeedback.mediumImpact(); } catch (_) {}
    }
  }

  static Future<void> success() async => medium();
  static Future<void> selection() async {
    if (!enabled) return;
    if (Platform.isIOS || Platform.isAndroid) {
      try { await HapticFeedback.selectionClick(); } catch (_) {}
    }
  }
}
