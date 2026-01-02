import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Service to manage interactive tutorials/walkthroughs using tutorial_coach_mark.
/// 
/// Usage:
/// 1. Create GlobalKeys for each widget you want to highlight
/// 2. Call TutorialService.showTutorial() with the targets
/// 3. The service automatically tracks if a tutorial has been shown
class TutorialService {
  static const String _prefKeyPrefix = 'tutorial_shown_';

  /// Check if a specific tutorial has been completed
  static Future<bool> hasSeenTutorial(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefKeyPrefix$tutorialId') ?? false;
  }

  /// Mark a tutorial as completed
  static Future<void> markTutorialComplete(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefKeyPrefix$tutorialId', true);
  }

  /// Reset a specific tutorial (for testing or "show tutorial again" feature)
  static Future<void> resetTutorial(String tutorialId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefKeyPrefix$tutorialId');
  }

  /// Reset all tutorials
  static Future<void> resetAllTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefKeyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Show a tutorial walkthrough
  /// 
  /// [context] - BuildContext
  /// [tutorialId] - Unique identifier for this tutorial (used for tracking)
  /// [targets] - List of TargetFocus objects defining what to highlight
  /// [onFinish] - Callback when tutorial completes
  /// [onSkip] - Callback when user skips the tutorial
  /// [forceShow] - If true, shows even if user has seen it before
  static Future<void> showTutorial({
    required BuildContext context,
    required String tutorialId,
    required List<TargetFocus> targets,
    VoidCallback? onFinish,
    VoidCallback? onSkip,
    bool forceShow = false,
  }) async {
    // Check if already seen (unless forced)
    if (!forceShow) {
      final hasSeen = await hasSeenTutorial(tutorialId);
      if (hasSeen) return;
    }

    // Small delay to ensure widgets are built
    await Future.delayed(const Duration(milliseconds: 500));

    if (!context.mounted) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: const Color(0xFF1A1A1A),
      opacityShadow: 0.9,
      textSkip: "SKIP",
      textStyleSkip: const TextStyle(
        color: Colors.white70,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        fontFamily: 'Poppins',
      ),
      paddingFocus: 10,
      focusAnimationDuration: const Duration(milliseconds: 400),
      pulseAnimationDuration: const Duration(milliseconds: 1000),
      onFinish: () {
        markTutorialComplete(tutorialId);
        onFinish?.call();
      },
      onSkip: () {
        markTutorialComplete(tutorialId);
        onSkip?.call();
        return true; // Return true to allow skip
      },
    ).show(context: context);
  }

  /// Create a target for the tutorial
  /// 
  /// [key] - GlobalKey of the widget to highlight
  /// [title] - Title text for this step
  /// [description] - Description text for this step
  /// [shape] - Shape of the highlight (circle or rect)
  /// [alignSkip] - Where to place the skip button
  /// [contentAlign] - Where to place the content relative to the target
  static TargetFocus createTarget({
    required GlobalKey key,
    required String title,
    required String description,
    ShapeLightFocus shape = ShapeLightFocus.RRect,
    Alignment alignSkip = Alignment.topRight,
    ContentAlign contentAlign = ContentAlign.bottom,
    IconData? icon,
  }) {
    return TargetFocus(
      identify: key.toString(),
      keyTarget: key,
      alignSkip: alignSkip,
      shape: shape,
      radius: 8,
      contents: [
        TargetContent(
          align: contentAlign,
          builder: (context, controller) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: const Color(0xFFD4AF37), size: 32),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                      fontSize: 20,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontFamily: 'Poppins',
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.touch_app, color: Colors.white54, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Tap anywhere to continue',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
