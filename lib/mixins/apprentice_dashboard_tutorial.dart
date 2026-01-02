import 'package:flutter/material.dart';
import '../services/tutorial_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Mixin to add tutorial walkthrough functionality to the Apprentice Dashboard.
/// 
/// Usage:
/// 1. Add `with ApprenticeDashboardTutorial` to your State class
/// 2. Call `initApprenticeTutorial()` in initState()
/// 3. Use the GlobalKeys on your widgets
mixin ApprenticeDashboardTutorial<T extends StatefulWidget> on State<T> {
  // Global keys for tutorial targets - matching actual UI elements
  final GlobalKey welcomeCardKey = GlobalKey();
  final GlobalKey newAssessmentCardKey = GlobalKey();
  final GlobalKey spiritualGiftsCardKey = GlobalKey();
  final GlobalKey progressCardKey = GlobalKey();
  final GlobalKey resourcesCardKey = GlobalKey();
  final GlobalKey profileButtonKey = GlobalKey();
  final GlobalKey mentorButtonKey = GlobalKey();
  final GlobalKey invitationsButtonKey = GlobalKey();
  final GlobalKey recentAssessmentsKey = GlobalKey();

  static const String tutorialId = 'apprentice_dashboard_v1';

  /// Call this in initState() to set up tutorial
  void initApprenticeTutorial() {
    // Show tutorial after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showApprenticeTutorialIfNeeded();
    });
  }

  /// Shows the apprentice dashboard tutorial if user hasn't seen it
  Future<void> showApprenticeTutorialIfNeeded({bool force = false}) async {
    if (!mounted) return;
    
    final targets = _buildApprenticeTutorialTargets();
    if (targets.isEmpty) return;

    await TutorialService.showTutorial(
      context: context,
      tutorialId: tutorialId,
      targets: targets,
      forceShow: force,
      onFinish: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tutorial complete! You\'re ready to begin your journey.'),
              backgroundColor: Color(0xFFD4AF37),
            ),
          );
        }
      },
    );
  }

  List<TargetFocus> _buildApprenticeTutorialTargets() {
    final targets = <TargetFocus>[];

    // Welcome card
    if (welcomeCardKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: welcomeCardKey,
        title: 'Welcome!',
        description: 'This is your personal dashboard. Let\'s take a quick tour of what you can do here.',
        icon: Icons.waving_hand,
        contentAlign: ContentAlign.bottom,
      ));
    }

    // New Assessment card
    if (newAssessmentCardKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: newAssessmentCardKey,
        title: 'Start an Assessment',
        description: 'Tap here to begin a spiritual assessment. Answer honestly - your responses help your mentor guide you better.',
        icon: Icons.quiz,
        contentAlign: ContentAlign.bottom,
      ));
    }

    // Spiritual Gifts card
    if (spiritualGiftsCardKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: spiritualGiftsCardKey,
        title: 'Discover Your Gifts',
        description: 'Take the Spiritual Gifts assessment to discover your unique God-given gifts and how to use them.',
        icon: Icons.auto_awesome,
        contentAlign: ContentAlign.bottom,
      ));
    }

    // Progress card
    if (progressCardKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: progressCardKey,
        title: 'Track Your Growth',
        description: 'View your progress over time. See how you\'re growing in different spiritual areas.',
        icon: Icons.trending_up,
        contentAlign: ContentAlign.top,
      ));
    }

    // Resources card
    if (resourcesCardKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: resourcesCardKey,
        title: 'Learning Resources',
        description: 'Access guides, articles, and weekly tips to support your spiritual growth journey.',
        icon: Icons.menu_book,
        contentAlign: ContentAlign.top,
      ));
    }

    // Recent assessments section
    if (recentAssessmentsKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: recentAssessmentsKey,
        title: 'Your Assessments',
        description: 'See your in-progress and past assessments here. Resume where you left off anytime!',
        icon: Icons.history,
        contentAlign: ContentAlign.top,
      ));
    }

    // Profile button
    if (profileButtonKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: profileButtonKey,
        title: 'Your Profile',
        description: 'Update your profile info and settings here.',
        icon: Icons.account_circle,
        contentAlign: ContentAlign.bottom,
      ));
    }

    // Mentor button
    if (mentorButtonKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: mentorButtonKey,
        title: 'Mentor & Agreements',
        description: 'View your mentor details and mentorship agreement status. Make sure to sign your agreement!',
        icon: Icons.people,
        contentAlign: ContentAlign.bottom,
      ));
    }

    // Invitations button
    if (invitationsButtonKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: invitationsButtonKey,
        title: 'Invitations',
        description: 'Check for mentor invitations here. Accept an invitation to connect with a mentor.',
        icon: Icons.mail,
        contentAlign: ContentAlign.bottom,
      ));
    }

    return targets;
  }

  /// Reset the tutorial to show it again
  Future<void> resetApprenticeTutorial() async {
    await TutorialService.resetTutorial(tutorialId);
  }
}
