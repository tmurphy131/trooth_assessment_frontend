import 'package:flutter/material.dart';
import '../services/tutorial_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Mixin to add tutorial walkthrough functionality to the Mentor Dashboard.
/// 
/// Usage:
/// 1. Add `with MentorDashboardTutorial` to your State class
/// 2. Call `initTutorialKeys()` in initState()
/// 3. Call `showMentorTutorialIfNeeded(context)` after the first frame renders
/// 4. Use the GlobalKeys (apprenticesTabKey, etc.) on your widgets
mixin MentorDashboardTutorial<T extends StatefulWidget> on State<T> {
  // Global keys for tutorial targets
  final GlobalKey apprenticesTabKey = GlobalKey();
  final GlobalKey assessmentsTabKey = GlobalKey();
  final GlobalKey agreementsTabKey = GlobalKey();
  final GlobalKey resourcesTabKey = GlobalKey();
  final GlobalKey alertsTabKey = GlobalKey();
  final GlobalKey inviteButtonKey = GlobalKey();
  final GlobalKey profileButtonKey = GlobalKey();
  final GlobalKey statsRowKey = GlobalKey();

  static const String tutorialId = 'mentor_dashboard_v1';

  /// Call this in initState() to set up tutorial
  void initMentorTutorial() {
    // Show tutorial after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showMentorTutorialIfNeeded();
    });
  }

  /// Shows the mentor dashboard tutorial if user hasn't seen it
  Future<void> showMentorTutorialIfNeeded({bool force = false}) async {
    if (!mounted) return;
    
    final targets = _buildMentorTutorialTargets();
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
              content: Text('Tutorial complete! You\'re ready to start mentoring.'),
              backgroundColor: Color(0xFFD4AF37),
            ),
          );
        }
      },
    );
  }

  List<TargetFocus> _buildMentorTutorialTargets() {
    final targets = <TargetFocus>[];

    // Welcome target (stats row)
    if (statsRowKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: statsRowKey,
        title: 'Welcome to Your Dashboard!',
        description: 'This is your mentor command center. Here you can see your apprentices, assessments, and overall progress at a glance.',
        icon: Icons.dashboard,
        contentAlign: ContentAlign.bottom,
      ));
    }

    // Apprentices tab
    if (apprenticesTabKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: apprenticesTabKey,
        title: 'Apprentices Tab',
        description: 'View all your active apprentices here. You can see their progress, send assessments, and track their spiritual growth journey.',
        icon: Icons.people,
        contentAlign: ContentAlign.bottom,
      ));
    }

    // Invite button
    if (inviteButtonKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: inviteButtonKey,
        title: 'Invite Apprentices',
        description: 'Tap here to invite new apprentices to your mentorship. They\'ll receive an email invitation to join.',
        icon: Icons.person_add,
        contentAlign: ContentAlign.bottom,
      ));
    }

    // Assessments tab
    if (assessmentsTabKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: assessmentsTabKey,
        title: 'Assessments Tab',
        description: 'Track all completed assessments here. Review detailed reports, see AI-generated insights, and identify areas to focus on with each apprentice.',
        icon: Icons.assignment,
        contentAlign: ContentAlign.bottom,
      ));
    }

    // Agreements tab
    if (agreementsTabKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: agreementsTabKey,
        title: 'Agreements Tab',
        description: 'Manage mentorship agreements. Create new agreements, track signing progress, and maintain clear expectations with your apprentices.',
        icon: Icons.description,
        contentAlign: ContentAlign.bottom,
      ));
    }

    // Resources tab
    if (resourcesTabKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: resourcesTabKey,
        title: 'Resources Tab',
        description: 'Access mentor guides, weekly tips, and training materials to help you become a more effective mentor.',
        icon: Icons.link,
        contentAlign: ContentAlign.bottom,
      ));
    }

    // Alerts tab
    if (alertsTabKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: alertsTabKey,
        title: 'Alerts & Notifications',
        description: 'Stay informed! Get notified when apprentices complete assessments, sign agreements, or need your attention.',
        icon: Icons.notifications,
        contentAlign: ContentAlign.bottom,
      ));
    }

    // Profile button
    if (profileButtonKey.currentContext != null) {
      targets.add(TutorialService.createTarget(
        key: profileButtonKey,
        title: 'Your Profile',
        description: 'Access your profile settings, sign out, or view your mentor information here.',
        icon: Icons.account_circle,
        contentAlign: ContentAlign.bottom,
      ));
    }

    return targets;
  }

  /// Reset the tutorial to show it again
  Future<void> resetMentorTutorial() async {
    await TutorialService.resetTutorial(tutorialId);
  }
}
