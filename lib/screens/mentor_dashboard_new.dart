import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:developer' as dev;
import '../utils/logout_util.dart';
import '../services/api_service.dart';
import '../services/subscription_service.dart';
import 'template_management_screen.dart';
import 'apprentice_invite_screen.dart';
import 'assessment_results_screen.dart';
import 'assessment_screen.dart';
import 'apprentice_report_screen.dart';
import 'mentor_agreements_screen.dart';
import 'mentor_notifications_screen.dart';
import 'mentor_assessment_results_screen.dart';
import 'mentor_apprentice_prayers_screen.dart';
import 'mentor_gift_seats_screen.dart';
import 'subscription_screen.dart';
import 'mentor_profile_screen.dart';
import 'mentor_resources_screen.dart';
import 'mentor_spiritual_gifts_screen.dart';
import '../utils/assessments.dart';
import '../mixins/mentor_dashboard_tutorial.dart';
import 'trivia_home_screen.dart';
import '../features/assessments/screens/mentor_submission_detail_screen.dart';
import '../utils/errors.dart';

part 'mentor_dashboard_new_widgets.dart';

class MentorDashboardNew extends StatefulWidget {
  const MentorDashboardNew({super.key});

  @override
  State<MentorDashboardNew> createState() => _MentorDashboardNewState();
}

class _MentorDashboardNewState extends State<MentorDashboardNew> with TickerProviderStateMixin, MentorDashboardTutorial, WidgetsBindingObserver {
  late TabController _tabController;
  final user = FirebaseAuth.instance.currentUser;
  final _apiService = ApiService();
  
  // State management
  List<Map<String, dynamic>> _apprentices = [];
  // Inactive apprentice data moved to ApprenticeInviteScreen
  Map<String, List<Map<String, dynamic>>> _completedAssessmentsByApprentice = {};
  List<Map<String, dynamic>> _mentorOwnAssessments = [];
  bool _isLoadingMentorAssessments = true;
  List<Map<String, dynamic>> _mentorOwnDrafts = [];
  bool _isLoadingMentorDrafts = true;
  bool _isLoadingApprentices = true;
  bool _isLoadingAssessments = true;
  // Filter: '_all' sentinel means show all apprentices
  String _selectedApprenticeId = '_all';
  // bool _loadingInactive = false; // Removed unused inactive apprentice state
  String? _error;
  int _activeNotificationCount = 0;
  int _triviaPendingCount = 0;
  Timer? _notifTimer;
  
  // Subscription state
  final _subscriptionService = SubscriptionService();

  @override
  void initState() {
    super.initState();
  _tabController = TabController(length: 4, vsync: this); // Alerts moved to AppBar icon
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
        // Only fire once per tab switch — when animation has fully settled
        if (!_tabController.indexIsChanging && _tabController.index == 3) {
          _refreshTriviaPendingCount();
        }
      }
    });
    WidgetsBinding.instance.addObserver(this);
    _initializeAndLoadData();
    // Initialize tutorial after data loads
    initMentorTutorial();
  }

  Future<void> _initializeAndLoadData() async {
    try {
      // First load apprentices, then load dependent data to avoid empty results on first paint
      await _loadApprentices();
      await Future.wait([
        _loadCompletedAssessments(),
        _loadMentorOwnAssessments(),
        _loadMentorOwnDrafts(),
        _loadInactiveApprentices(),
        _refreshNotificationCount(),
        _loadSubscriptionData(),
        _refreshTriviaPendingCount(),
      ]);
      _startNotificationPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to initialize: ${friendlyError(e)}';
        _isLoadingApprentices = false;
        _isLoadingAssessments = false;
      });
    }
  }

  Future<void> _loadSubscriptionData() async {
    try {
      // Refresh subscription status
      await _subscriptionService.refreshStatus();
      
      // Trigger rebuild to show/hide premium features
      if (mounted) {
        setState(() {});
      }

    } catch (e) {
      // Silent fail - subscription features are optional
      dev.log('MentorDashboard: Failed to load subscription data: $e');
    }
  }

  Future<void> _refreshNotificationCount() async {
    try {
      final list = await _apiService.mentorNotifications();
      if (mounted) setState(() { _activeNotificationCount = list.length; });
    } catch (_) {
      // silent
    }
  }

  Future<void> _refreshTriviaPendingCount() async {
    try {
      final challenges = await _apiService.triviaListChallenges();
      final count = challenges.where((c) {
        final status = c['status'] as String? ?? '';
        final isMyTurn = c['is_my_turn'] == true;
        final myRole = c['my_role'] as String? ?? '';
        return isMyTurn || (status == 'pending' && myRole == 'challenged');
      }).length;
      if (mounted) setState(() => _triviaPendingCount = count);
    } catch (_) {}
  }

  void _startNotificationPolling() {
    _notifTimer?.cancel();
    _notifTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refreshNotificationCount();
      _refreshTriviaPendingCount();
    });
  }

  // Polling in the background wastes battery and backend calls.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationCount();
      _refreshTriviaPendingCount();
      _startNotificationPolling();
    } else if (state == AppLifecycleState.paused) {
      _notifTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadApprentices() async {
    try {
      setState(() {
        _isLoadingApprentices = true;
        _error = null;
      });

      final apprentices = await _apiService.listApprentices();
      setState(() {
        _apprentices = apprentices.cast<Map<String, dynamic>>();
        _isLoadingApprentices = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load apprentices: ${friendlyError(e)}';
        _isLoadingApprentices = false;
      });
    }
  }

  Future<void> _loadInactiveApprentices() async { /* no-op: feature relocated */ }

  Future<void> _loadMentorOwnAssessments() async {
    try {
      final results = await _apiService.getMentorOwnAssessments();
      if (mounted) {
        setState(() {
        _mentorOwnAssessments = results.cast<Map<String, dynamic>>();
        _isLoadingMentorAssessments = false;
      });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMentorAssessments = false);
    }
  }

  Future<void> _loadMentorOwnDrafts() async {
    try {
      final results = await _apiService.getAllDrafts();
      if (mounted) {
        setState(() {
        _mentorOwnDrafts = results.cast<Map<String, dynamic>>();
        _isLoadingMentorDrafts = false;
      });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMentorDrafts = false);
    }
  }

  Future<void> _startSelfAssessment() async {
    try {
      final templates = await _apiService.getPublishedTemplates();
      if (templates.isEmpty || !mounted) return;

      Map<String, dynamic>? selected;
      if (templates.length == 1) {
        selected = templates.first as Map<String, dynamic>;
      } else {
        selected = await _showSelfAssessmentSelectionDialog(templates);
      }
      if (selected == null || !mounted) return;

      final templateId = selected['id']?.toString();
      if (templateId == null || !mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AssessmentScreen(templateId: templateId),
        ),
      );
      // Always reload drafts (user may have saved progress without submitting)
      _loadMentorOwnDrafts();
      if (result == true) _loadMentorOwnAssessments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load assessment: ${friendlyError(e)}')),
      );
      }
    }
  }

  Future<Map<String, dynamic>?> _showSelfAssessmentSelectionDialog(List<dynamic> templates) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Choose Assessment',
          style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index] as Map<String, dynamic>;
              final isMaster = template['is_master_assessment'] == true;
              final isLocked = template['is_locked'] == true;
              return Card(
                color: isLocked
                    ? Colors.grey[850]
                    : (isMaster ? Colors.amber[700] : Colors.grey[800]),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    isLocked
                        ? Icons.lock
                        : (isMaster ? Icons.star : Icons.assignment),
                    size: 22,
                    color: isLocked
                        ? Colors.grey
                        : (isMaster ? Colors.white : Colors.amber),
                  ),
                  title: Text(
                    template['name'] ?? 'Unnamed Assessment',
                    style: TextStyle(
                      color: isLocked ? Colors.grey : Colors.white,
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: isMaster ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: isLocked
                      ? const Text(
                          'Premium subscription required',
                          style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontSize: 12),
                        )
                      : (template['description'] != null
                          ? Text(
                              template['description'],
                              style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null),
                  trailing: isLocked
                      ? const Icon(Icons.workspace_premium, color: Colors.amber, size: 18)
                      : null,
                  onTap: isLocked
                      ? () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                          );
                        }
                      : () => Navigator.of(ctx).pop(template),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCompletedAssessments() async {
    try {
      setState(() {
        _isLoadingAssessments = true;
        _error = null;
      });
      Map<String, List<Map<String, dynamic>>> grouped = {};
      
      // Filter apprentices based on selection
      var targets = _selectedApprenticeId == '_all'
          ? _apprentices
          : _apprentices.where((a) => a['id'] == _selectedApprenticeId).toList();
      
      // For free mentors, only load assessments for the first apprentice
      final status = _subscriptionService.status;
      final isPremium = status.isPremium;
      final isGrandfathered = status.isGrandfathered;
      
      // Use print() to ensure visibility in console
      print('🔒 FREEMIUM CHECK: isPremium=$isPremium, isGrandfathered=$isGrandfathered, tier=${status.tier}');
      print('🔒 FREEMIUM CHECK: total apprentices=${_apprentices.length}, targets before filter=${targets.length}');
      
      if (!isPremium && !isGrandfathered) {
        // Free user - only allow first apprentice
        if (_apprentices.isNotEmpty) {
          final firstApprenticeId = _apprentices[0]['id'];
          targets = targets.where((a) => a['id'] == firstApprenticeId).toList();
        }
        print('🔒 FREEMIUM CHECK: FREE USER → filtered to ${targets.length} apprentice(s)');
      } else {
        print('🔒 FREEMIUM CHECK: PREMIUM/GRANDFATHERED → all ${targets.length} apprentice(s) allowed');
      }
      
      final results = await Future.wait(targets.map((apprentice) async {
        final apprenticeId = apprentice['id'] as String;
        final assessments = await _apiService.getApprenticeSubmittedAssessments(apprenticeId, limit: 100);
        return MapEntry(apprenticeId, assessments.cast<Map<String, dynamic>>());
      }));
      grouped.addEntries(results);
      if (!mounted) return;
      setState(() {
        _completedAssessmentsByApprentice = grouped;
        _isLoadingAssessments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load completed assessments: ${friendlyError(e)}';
        _isLoadingAssessments = false;
      });
    }
  }

  // _confirmReinstateApprentice removed (handled in invite screen now)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Image.asset(
          'assets/logo.png',
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text('Trooth', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        ),
        actions: [
          if (_subscriptionService.isPremium)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 20),
            ),
          if (_subscriptionService.isPremium)
            IconButton(
              icon: const Icon(Icons.card_giftcard, color: Color(0xFFFFD700)),
              tooltip: 'Gift Seats',
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MentorGiftSeatsScreen()),
                );
                if (result == true) _loadSubscriptionData();
              },
            ),
          Stack(
            key: alertsTabKey,
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Color(0xFFFFD700)),
                tooltip: 'Alerts',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MentorNotificationsScreen(
                      onActivity: () async { await _refreshNotificationCount(); },
                    ),
                  ),
                ).then((_) => _refreshNotificationCount()),
              ),
              if (_activeNotificationCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _activeNotificationCount > 99 ? '99+' : _activeNotificationCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            key: profileButtonKey,
            icon: const Icon(Icons.account_circle, color: Color(0xFFFFD700)),
            tooltip: 'My Profile',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MentorProfileScreen()),
              );
              dev.log('FREEMIUM DEBUG: Returning from profile, reloading data...');
              await _loadSubscriptionData();
              await _loadCompletedAssessments();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            tooltip: 'Sign Out',
            onPressed: () => logoutAndRedirect(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApprenticesTab(),
          _buildAssessmentsTab(),
          const MentorResourcesScreen(),
          const TriviaHomeScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          border: Border(top: BorderSide(color: Colors.grey[800]!)),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _tabController.index,
            onTap: (i) => _tabController.animateTo(i),
            backgroundColor: Colors.grey[900],
            selectedItemColor: const Color(0xFFFFD700),
            unselectedItemColor: Colors.grey[500],
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 11),
            items: [
              BottomNavigationBarItem(
                key: apprenticesTabKey,
                icon: const Icon(Icons.people),
                label: 'Apprentices',
              ),
              BottomNavigationBarItem(
                key: assessmentsTabKey,
                icon: const Icon(Icons.assignment),
                label: 'Assessments',
              ),
              BottomNavigationBarItem(
                key: resourcesTabKey,
                icon: const Icon(Icons.link),
                label: 'Resources',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: _triviaPendingCount > 0,
                  backgroundColor: Colors.redAccent,
                  label: Text(
                    _triviaPendingCount > 9 ? '9+' : '$_triviaPendingCount',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  child: const Icon(Icons.quiz),
                ),
                label: 'Trivia',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpgradeForApprenticesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber),
            const SizedBox(width: 12),
            const Text('Premium Required', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Free accounts can only access one apprentice.',
              style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to Premium to:',
              style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildUpgradeFeatureRow(Icons.people, 'Mentor unlimited apprentices'),
            _buildUpgradeFeatureRow(Icons.auto_awesome, 'Access all assessment reports'),
            _buildUpgradeFeatureRow(Icons.edit_note, 'Create custom templates'),
            _buildUpgradeFeatureRow(Icons.card_giftcard, 'Gift premium to apprentices'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Upgrade Now', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showMeetingInfo(String apprenticeId, String apprenticeEmail, String apprenticeName) async {
    // Strategy: fetch mentor-scoped agreements first; fallback to broad list if needed.
    List<dynamic> agreements = [];
    try {
      agreements = await _apiService.listMyAgreements(limit: 100);
    } catch (_) {
      try { agreements = await _apiService.listAgreements(limit: 100); } catch (_) {}
    }

    Map<String,dynamic>? primary;
    for (final a in agreements) {
      if (a is Map && (
          a['apprentice_id'] == apprenticeId ||
          a['apprenticeEmail'] == apprenticeId ||
          a['apprentice_email'] == apprenticeEmail ||
          a['apprentice_email'] == apprenticeId // in case id used as email placeholder earlier
        )) {
        primary ??= a.cast<String,dynamic>();
        if (a['status'] != 'revoked') { primary = a.cast<String,dynamic>(); break; }
      }
    }

    Map<String,dynamic> fields = {};
    if (primary != null) {
      if (primary['fields_json'] is Map) {
        fields = (primary['fields_json'] as Map).cast<String,dynamic>();
      } else if (primary['fields'] is Map) { // some endpoints may serialize as 'fields'
        fields = (primary['fields'] as Map).cast<String,dynamic>();
      }
    }

    // Also tolerate camelCase keys if they slipped through from a different client version.
    if (fields.isEmpty && primary != null) {
      final camel = <String, dynamic>{};
      for (final e in primary.entries) {
        if (e.key.toString().toLowerCase().contains('meeting')) camel[e.key] = e.value;
      }
      if (camel.isNotEmpty) fields = camel;
    }
    final location = fields['meeting_location'];
    final duration = fields['meeting_duration_minutes'];
    final day = fields['meeting_day'];
    final time = fields['meeting_time'];
    final frequency = fields['meeting_frequency'];
    final startDate = fields['start_date'];
    final nextMeeting = _computeNextMeetingDate(day?.toString(), time?.toString(), frequency?.toString(), startDate?.toString());

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Meeting Info', style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 320,
          child: (primary == null) ? const Text('No agreement found for this apprentice.', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'))
            : (location == null && time == null && day == null && frequency == null)
            ? const Text('No meeting information set for this apprentice.', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(apprenticeName, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (day != null) Text('Day: $day', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                  if (time != null) Text('Time: $time', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                  if (location != null) Text('Location: $location', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                  if (frequency != null) Text('Frequency: $frequency', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                  if (duration != null) Text('Duration: ${duration}m', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                  if (startDate != null) Text('Start: $startDate', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                  if (nextMeeting != null) ...[
                    const SizedBox(height: 8),
                    Text('Next: ${_formatFriendly(nextMeeting)}', style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          )
        ],
      )
    );
  }

  DateTime? _computeNextMeetingDate(String? day, String? time, String? frequency, String? startDate) {
    if (day == null || time == null) return null;
  int? wd = _parseWeekday(day);
  final hm = _parseTime(time);
  if (wd == null) return null;
    final now = DateTime.now();
    final start = _parseDate(startDate) ?? now;
    final base = now.isAfter(start) ? now : start;
    String f = (frequency ?? 'weekly').toLowerCase();
    DateTime nextWeekly(DateTime from) {
      final fromAtTime = DateTime(from.year, from.month, from.day, hm.h, hm.m);
      final deltaDays = (wd - from.weekday + 7) % 7;
      var cand = fromAtTime.add(Duration(days: deltaDays));
      if (deltaDays == 0 && cand.isBefore(from)) cand = cand.add(const Duration(days: 7));
      return cand;
    }
    DateTime nextKWeekly(int k) {
      var first = nextWeekly(start);
      if (first.isBefore(start)) first = first.add(const Duration(days: 7));
      while (first.isBefore(base)) { first = first.add(Duration(days: 7 * k)); }
      return first;
    }
    final everyNWeeks = RegExp(r'every\s+(\d+)\s*weeks?');
    final m = everyNWeeks.firstMatch(f);
    if (m != null) { final n = int.tryParse(m.group(1)! ) ?? 1; return nextKWeekly(n.clamp(1, 52)); }
    if (f.contains('biweek') || f.contains('every other week') || f.contains('fortnight')) return nextKWeekly(2);
    return nextKWeekly(1);
  }

  int? _parseWeekday(String input) {
    final s = input.trim().toLowerCase();
    const map = {'mon':1,'monday':1,'tue':2,'tues':2,'tuesday':2,'wed':3,'weds':3,'wednesday':3,'thu':4,'thur':4,'thurs':4,'thursday':4,'fri':5,'friday':5,'sat':6,'saturday':6,'sun':7,'sunday':7};
    if (map.containsKey(s)) return map[s];
    for (final e in map.entries) { if (s.startsWith(e.key)) return e.value; }
    return null;
  }
  _MeetingHM _parseTime(String input) {
    var s = input.trim().toLowerCase();
    s = s.replaceAll('.', '').replaceAll(' ', '');
    final am = s.endsWith('am');
    final pm = s.endsWith('pm');
    if (am || pm) s = s.substring(0, s.length - 2);
    final parts = s.split(':');
    int h = int.tryParse(parts[0]) ?? 0; int m = parts.length>1 ? int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'),'')) ?? 0 : 0;
    if (am) { if (h==12) h=0; }
    if (pm) { if (h<12) h+=12; }
    return _MeetingHM(h,m);
  }
  DateTime? _parseDate(String? input) { if (input==null||input.isEmpty) return null; return DateTime.tryParse(input); }
  String _formatFriendly(DateTime dt) {
    const dows=['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const mos=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dow=dows[(dt.weekday-1).clamp(0,6)];
    final mon=mos[(dt.month-1).clamp(0,11)];
    final h24=dt.hour; final isPM=h24>=12; final h12raw=h24%12; final h12=h12raw==0?12:h12raw; final mm=dt.minute.toString().padLeft(2,'0'); final ap=isPM?'PM':'AM';
    return '$dow, $mon ${dt.day}, ${dt.year} · $h12:$mm $ap';
  }

  // Local minimal time holder (avoid importing apprentice screen private class)

  void _confirmDeleteMentorDraft(String? draftId) {
    if (draftId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Draft',
          style: TextStyle(color: Colors.red, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this draft? This action cannot be undone.',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'Poppins')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMentorDraft(draftId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMentorDraft(String draftId) async {
    try {
      await _apiService.deleteDraft(draftId);
      if (mounted) {
        setState(() {
          _mentorOwnDrafts.removeWhere((d) => d['id']?.toString() == draftId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete draft: ${friendlyError(e)}')),
        );
      }
    }
  }

  Widget _buildApprenticeFilter() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: '_all',
        child: Text('All Apprentices'),
      ),
      ..._apprentices.map((a) => DropdownMenuItem<String>(
            value: a['id'] as String,
            child: Text((a['name'] ?? a['email'] ?? 'Apprentice').toString()),
          )),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedApprenticeId,
          items: items,
          dropdownColor: Colors.grey[900],
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
          onChanged: (value) async {
            if (value == null) return;
            setState(() { _selectedApprenticeId = value; });
            await _loadCompletedAssessments();
          },
        ),
      ),
    );
  }

  Future<void> _reloadAssessments() async {
    // Ensure apprentices list is up-to-date first, then reload grouped submissions
    await _loadApprentices();
    await _loadCompletedAssessments();
  }

  String _buildCategoryScoresSummary(Map<String, dynamic> categoryScores) {
    final categories = categoryScores.entries.take(2).map((e) => '${e.key}: ${e.value}').join(', ');
    final remaining = categoryScores.length - 2;
    return remaining > 0 ? '$categories +$remaining more' : categories;
  }

  void _showAssessmentResults(Map<String, dynamic> assessment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssessmentResultsScreen(assessment: assessment),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  Future<void> _showApprenticeProfile(String apprenticeId) async {
    try {
      final profile = await _apiService.getApprenticeProfile(apprenticeId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Apprentice Profile',
              style: TextStyle(
                color: Colors.amber,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Name: ${profile['name'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Email: ${profile['email'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total Assessments: ${profile['total_assessments'] ?? 0}',
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Average Score: ${profile['average_score'] ?? 'N/A'}%',
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.amber, fontFamily: 'Poppins'),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showMessage('Failed to load apprentice profile: ${friendlyError(e)}', isError: true);
    }
  }

  Future<void> _showApprenticeAssessments(String apprenticeId) async {
    try {
      final apprentice = _apprentices.firstWhere((a) => a['id'] == apprenticeId, orElse: () => {});
      final name = (apprentice['name'] ?? apprentice['display_name'] ?? apprentice['email'] ?? 'Apprentice').toString();
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => MentorAssessmentResultsScreen(apprenticeId: apprenticeId, apprenticeName: name)));
    } catch (e) {
      _showMessage('Unable to open assessments: ${friendlyError(e)}', isError: true);
    }
  }

  void _showApprenticePrayers(String apprenticeId, String name) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MentorApprenticePrayersScreen(apprenticeId: apprenticeId, apprenticeName: name),
    ));
  }

  Future<void> _showTerminateDialog(String apprenticeId, String displayName) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;
    await showDialog(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Terminate Mentorship', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Provide a brief reason for terminating your mentorship with $displayName.', style: TextStyle(color: Colors.grey[300], fontFamily: 'Poppins')),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: controller,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      labelStyle: TextStyle(color: Colors.amber),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.amber,width:2)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Reason required';
                      if (v.trim().length < 5) return 'Please provide more detail';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text('This action notifies the apprentice and cannot be undone in the app.', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontFamily: 'Poppins')))
                    ],
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: submitting ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  print('[UI] Terminate pressed for apprentice=$apprenticeId reasonLen=${controller.text.trim().length}');
                  setState(() => submitting = true);
                  try {
                    await _apiService.terminateApprenticeship(apprenticeId, controller.text.trim());
                    // Refresh inactive apprentices list so dialog shows updated data if opened immediately
                    await _loadInactiveApprentices();
                    if (mounted) {
                      setState(() {
                        _apprentices.removeWhere((a) => a['id'] == apprenticeId);
                      });
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mentorship terminated')));
                    }
                  } catch (e) {
                    setState(() => submitting = false);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${friendlyError(e)}')));
                  }
                },
                child: submitting ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Text('Terminate'),
              )
            ],
          );
        });
      }
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          isError ? 'Error' : 'Success',
          style: TextStyle(
            color: isError ? Colors.red : Colors.amber,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.amber,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateString(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  

  void _navigateToInviteApprentices() {
    // Check if mentor can add more apprentices
    final status = _subscriptionService.status;
    
    // Free mentors can only have 1 apprentice
    // If they already have any apprentices and are not premium/grandfathered, block them
    if (!status.isPremium && !status.isGrandfathered && _apprentices.isNotEmpty) {
      _showUpgradeForApprenticesDialog();
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApprenticeInviteScreen(
          user: FirebaseAuth.instance.currentUser,
        ),
      ),
    );
  }
}

// Helper struct for meeting hour/minute used in meeting info calculations.
class _MeetingHM {
  final int h;
  final int m;
  const _MeetingHM(this.h, this.m);
}
