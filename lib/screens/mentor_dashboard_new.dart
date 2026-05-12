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
import 'mentor_gift_seats_screen.dart';
import 'subscription_screen.dart';
import 'mentor_profile_screen.dart';
import 'mentor_resources_screen.dart';
import 'mentor_spiritual_gifts_screen.dart';
import '../utils/assessments.dart';
import '../mixins/mentor_dashboard_tutorial.dart';

class MentorDashboardNew extends StatefulWidget {
  const MentorDashboardNew({super.key});

  @override
  State<MentorDashboardNew> createState() => _MentorDashboardNewState();
}

class _MentorDashboardNewState extends State<MentorDashboardNew> with TickerProviderStateMixin, MentorDashboardTutorial {
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
  Timer? _notifTimer;
  
  // Subscription state
  final _subscriptionService = SubscriptionService();
  int _giftSeatsCount = 0;
  int _usedGiftSeatsCount = 0;

  @override
  void initState() {
    super.initState();
  _tabController = TabController(length: 5, vsync: this); // Removed History tab; Resources now a tab
    _tabController.addListener(() { if (mounted) setState(() {}); });
    _initializeAndLoadData();
    // Initialize tutorial after data loads
    initMentorTutorial();
  }


  Future<void> _initializeAndLoadData() async {
    try {
      // Set the bearer token for API calls
      if (user != null) {
        final token = await user!.getIdToken();
        _apiService.bearerToken = token;
      }
      // First load apprentices, then load dependent data to avoid empty results on first paint
      await _loadApprentices();
      await Future.wait([
        _loadCompletedAssessments(),
        _loadMentorOwnAssessments(),
        _loadMentorOwnDrafts(),
        _loadInactiveApprentices(),
        _refreshNotificationCount(),
        _loadSubscriptionData(),
      ]);
      _startNotificationPolling();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
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
      
      // Load gift seats count if premium mentor
      if (_subscriptionService.isPremium) {
        final seats = await _apiService.getMentorGiftSeats();
        if (mounted) {
          setState(() {
            _giftSeatsCount = seats.length;
            _usedGiftSeatsCount = seats.where((s) => s['status'] == 'active').length;
          });
        }
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

  void _startNotificationPolling() {
    _notifTimer?.cancel();
    _notifTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refreshNotificationCount());
  }

  @override
  void dispose() {
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
        _error = 'Failed to load apprentices: $e';
        _isLoadingApprentices = false;
      });
    }
  }

  Future<void> _loadInactiveApprentices() async { /* no-op: feature relocated */ }

  Future<void> _loadMentorOwnAssessments() async {
    try {
      final results = await _apiService.getMentorOwnAssessments();
      if (mounted) setState(() {
        _mentorOwnAssessments = results.cast<Map<String, dynamic>>();
        _isLoadingMentorAssessments = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMentorAssessments = false);
    }
  }

  Future<void> _loadMentorOwnDrafts() async {
    try {
      final results = await _apiService.getAllDrafts();
      if (mounted) setState(() {
        _mentorOwnDrafts = results.cast<Map<String, dynamic>>();
        _isLoadingMentorDrafts = false;
      });
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load assessment: $e')),
      );
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
      
      for (final apprentice in targets) {
        final apprenticeId = apprentice['id'] as String;
        final assessments = await _apiService.getApprenticeSubmittedAssessments(apprenticeId, limit: 100);
        grouped[apprenticeId] = assessments.cast<Map<String, dynamic>>();
      }
      setState(() {
        _completedAssessmentsByApprentice = grouped;
        _isLoadingAssessments = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load completed assessments: $e';
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
          const MentorAgreementsScreen(),
          const MentorResourcesScreen(),
          MentorNotificationsScreen(
            onActivity: () async { await _refreshNotificationCount(); },
          ),
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
                key: agreementsTabKey,
                icon: const Icon(Icons.description),
                label: 'Agreements',
              ),
              BottomNavigationBarItem(
                key: resourcesTabKey,
                icon: const Icon(Icons.link),
                label: 'Resources',
              ),
              BottomNavigationBarItem(
                key: alertsTabKey,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications),
                    if (_activeNotificationCount > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _activeNotificationCount > 99 ? '99+' : _activeNotificationCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'Alerts',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApprenticesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Apprentices',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MentorSpiritualGiftsScreen()),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome, color: Colors.amber),
                    tooltip: 'Spiritual Gifts',
                  ),
                  // Resources button removed; Resources now accessible via main tab bar
                  IconButton(
                    key: inviteButtonKey,
                    onPressed: _navigateToInviteApprentices,
                    icon: const Icon(Icons.person_add_alt_1, color: Colors.amber),
                    tooltip: 'Invite Apprentice',
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TemplateManagementScreen(user: user),
                        ),
                      );
                    },
                    icon: const Icon(Icons.assignment_outlined, color: Colors.amber),
                    tooltip: 'Manage Templates',
                  ),
                  IconButton(
                    onPressed: _loadApprentices,
                    icon: const Icon(Icons.refresh, color: Colors.amber),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingApprentices
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontFamily: 'Poppins',
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadApprentices,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _apprentices.isEmpty
                        ? _buildEmptyApprenticesState()
                        : ListView.builder(
                            itemCount: _apprentices.length,
                            itemBuilder: (context, index) {
                              // Bounds check to prevent RangeError during list updates
                              if (index >= _apprentices.length) {
                                return const SizedBox.shrink();
                              }
                              return _buildApprenticeCard(_apprentices[index], index);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalApprentices = _apprentices.length;
    final allAssessments = _completedAssessmentsByApprentice.values.expand((x) => x).toList();
    final totalCompletedAssessments = allAssessments.length;
    // Calculate average score
    double averageScore = 0.0;
    if (allAssessments.isNotEmpty) {
      final scores = <double>[];
      for (final a in allAssessments) {
        final raw = (a as Map)['scores']?['overall_score'];
        double v;
        if (raw is num) v = raw.toDouble();
        else if (raw is String) v = double.tryParse(raw) ?? 0.0;
        else v = 0.0;
        if (v.isFinite) scores.add(v);
      }
      if (scores.isNotEmpty) {
        final sum = scores.fold<double>(0.0, (p, c) => p + c);
        averageScore = (sum / scores.length).clamp(0.0, 10.0);
      }
    }

    return Row(
      key: statsRowKey,
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.people,
            title: 'Active\nApprentices',
            value: totalApprentices.toString(),
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.assignment_turned_in,
            title: 'Completed\nAssessments',
            value: totalCompletedAssessments.toString(),
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.trending_up,
            title: 'Average\nScore',
            value: '${(averageScore * 10).toStringAsFixed(1)}%',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        // Reduce horizontal padding by 1px on each side to gain ~2px inner width
        padding: const EdgeInsets.fromLTRB(15, 16, 15, 16),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
                fontFamily: 'Poppins',
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyApprenticesState() {
    return Center(
      child: Card(
        elevation: 2,
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                'No apprentices yet',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start mentoring by inviting apprentices to your program',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _navigateToInviteApprentices(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Invite Apprentices',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApprenticeCard(Map<String, dynamic> apprentice, int index) {
    final name = apprentice['name'] ?? 'Unknown';
    final email = apprentice['email'] ?? '';
    final apprenticeId = apprentice['id'] as String;
    
    // Check if this apprentice is accessible based on subscription
    final isAccessible = _subscriptionService.status.canAccessApprentice(index);
    
    // If not accessible, show locked card
    if (!isAccessible) {
      return _buildLockedApprenticeCard(name, email, index);
    }
    
    return Card(
      elevation: 2,
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.person,
            color: Colors.amber,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        subtitle: Text(
          email,
          style: TextStyle(
            color: Colors.grey[400],
            fontFamily: 'Poppins',
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
          color: Colors.grey[800],
          onSelected: (value) async {
            switch (value) {
              case 'profile':
                await _showApprenticeProfile(apprenticeId);
                break;
              case 'assessments':
                await _showApprenticeAssessments(apprenticeId);
                break;
              case 'meeting':
                await _showMeetingInfo(apprenticeId, email, name);
                break;
              case 'gift_premium':
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MentorGiftSeatsScreen()),
                );
                if (result == true) {
                  _loadSubscriptionData();
                }
                break;
              case 'terminate':
                await _showTerminateDialog(apprenticeId, name);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('View Profile', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'assessments',
              child: Row(
                children: [
                  Icon(Icons.assignment, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('View Assessments', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'meeting',
              child: Row(
                children: [
                  Icon(Icons.event, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Meeting Info', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            if (_subscriptionService.isPremium)
              const PopupMenuItem(
                value: 'gift_premium',
                child: Row(
                  children: [
                    Icon(Icons.card_giftcard, color: Color(0xFFFFD700)),
                    SizedBox(width: 8),
                    Text('Gift Premium', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'terminate',
              child: Row(
                children: [
                  Icon(Icons.stop_circle, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Terminate', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedApprenticeCard(String name, String email, int index) {
    return Card(
      elevation: 2,
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _showUpgradeForApprenticesDialog,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Dimmed content
            Opacity(
              opacity: 0.4,
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.person, color: Colors.grey),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                subtitle: Text(
                  email,
                  style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Lock overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, color: Colors.black, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Upgrade',
                            style: TextStyle(
                              color: Colors.black,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

  Widget _buildUpgradeFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13))),
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
        if (primary == null) primary = a.cast<String,dynamic>();
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
          SnackBar(content: Text('Failed to delete draft: $e')),
        );
      }
    }
  }

  Widget _buildMyAssessmentsSection() {
    final loading = _isLoadingMentorAssessments || _isLoadingMentorDrafts;
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2)),
      );
    }
    if (_mentorOwnDrafts.isEmpty && _mentorOwnAssessments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No assessments yet — tap "Take One" to start.',
          style: TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 13),
        ),
      );
    }

    final draftCards = _mentorOwnDrafts.map((draft) {
      final answers = draft['answers'] as Map<String, dynamic>? ?? {};
      final questions = draft['questions'] as List<dynamic>? ?? [];
      final answeredCount = answers.length;
      final totalCount = questions.length;
      final draftId = draft['id']?.toString();
      return InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AssessmentScreen(draftId: draftId),
            ),
          );
          _loadMentorOwnDrafts();
          _loadMentorOwnAssessments();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.edit_note, color: Colors.lightBlueAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('In Progress', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(
                      totalCount > 0 ? '$answeredCount of $totalCount answered' : '$answeredCount answered',
                      style: const TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.4)),
                ),
                child: const Text('Continue', style: TextStyle(color: Colors.lightBlueAccent, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _confirmDeleteMentorDraft(draftId),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    final completedCards = _mentorOwnAssessments.map((assessment) {
      final scores = assessment['scores'] as Map<String, dynamic>? ?? {};
      final overallScore = scores['overall_score'];
      final createdAt = assessment['created_at'] as String?;
      String dateLabel = '';
      if (createdAt != null) {
        try {
          final dt = DateTime.parse(createdAt).toLocal();
          dateLabel = '${dt.month}/${dt.day}/${dt.year}';
        } catch (_) {
          dateLabel = createdAt;
        }
      }
      final assessmentId = assessment['id']?.toString() ?? '';
      return InkWell(
        onTap: assessmentId.isEmpty ? null : () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ApprenticeReportScreen(
              assessmentId: assessmentId,
              title: 'My Assessment Report',
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Icon(Icons.assignment_turned_in, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(assessment['template_name'] as String? ?? 'Assessment', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14)),
                    if (dateLabel.isNotEmpty)
                      Text(dateLabel, style: const TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 12)),
                  ],
                ),
              ),
              if (overallScore != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$overallScore%',
                    style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                )
              else
                const Text('Processing...', style: TextStyle(color: Colors.white38, fontFamily: 'Poppins', fontSize: 12)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
            ],
          ),
        ),
      );
    }).toList();

    return Column(children: [...draftCards, ...completedCards]);
  }

  Widget _buildAssessmentsTab() {
    // For free mentors, only show assessments for the first apprentice
    final status = _subscriptionService.status;
    final accessibleApprentices = (!status.isPremium && !status.isGrandfathered)
        ? (_apprentices.isNotEmpty ? [_apprentices.first] : <Map<String, dynamic>>[])
        : _apprentices;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── My Assessments section ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MY ASSESSMENTS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  fontFamily: 'Poppins',
                ),
              ),
              ElevatedButton.icon(
                onPressed: _startSelfAssessment,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Take One', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(child: _buildMyAssessmentsSection()),
          ),
          const Divider(color: Colors.white12, height: 24),
          // ── Apprentice Assessments section ─────────────────────────────
          const Text(
            'Assessment Results',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildApprenticeFilter()),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _reloadAssessments,
              icon: const Icon(Icons.refresh, color: Colors.amber),
              tooltip: 'Refresh',
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingAssessments
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  )
                : _completedAssessmentsByApprentice.isEmpty
                    ? _buildEmptyAssessmentsState()
                    : ListView(
                        children: (_selectedApprenticeId == '_all'
                                ? accessibleApprentices
                                : accessibleApprentices.where((a) => a['id'] == _selectedApprenticeId).toList())
                            .map((apprentice) {
                          final apprenticeId = apprentice['id'] as String;
                          final assessments = _completedAssessmentsByApprentice[apprenticeId] ?? [];
                          if (assessments.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  '${apprentice['name'] ?? 'Unknown'} (${apprentice['email'] ?? ''})',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                              ...assessments.map((assessment) => _buildCompletedAssessmentCard(assessment)).toList(),
                            ],
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
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

  Widget _buildEmptyAssessmentsState() {
    return Center(
      child: Card(
        elevation: 2,
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 64,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                'No assessments submitted yet',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Assessment submissions from your apprentices will appear here',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedAssessmentCard(Map<String, dynamic> assessment) {
    final scores = assessment['scores'] as Map<String, dynamic>? ?? {};
    // Normalize overall score to a 0..10 double if possible
    double overall10;
    try {
      final raw = scores['overall_score'];
      if (raw is num) {
        overall10 = raw.toDouble();
      } else if (raw is String) {
        overall10 = double.tryParse(raw) ?? 0.0;
      } else {
        overall10 = 0.0;
      }
    } catch (_) {
      overall10 = 0.0;
    }
    if (!overall10.isFinite) overall10 = 0.0;
    final overallPct = (overall10 * 10).clamp(0, 100).round();
    final createdAt = assessment['created_at'] as String?;
    final apprenticeName = assessment['apprentice_name'] ?? assessment['apprentice']?['name'] ?? 'Unknown Apprentice';
    final apprenticeId = assessment['apprentice_id'] ?? assessment['apprentice']?['id'] ?? '';
    final assessmentId = assessment['id']?.toString() ?? assessment['assessment_id']?.toString() ?? '';
    final templateName = assessment['template_name'] ?? assessment['template']?['name'] ?? assessment['category'] ?? 'Assessment';
    
    return Card(
      elevation: 2,
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getScoreColor(overallPct).withOpacity(0.2), // Percent 0..100
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.analytics,
            color: _getScoreColor(overallPct),
          ),
        ),
        title: Text(
          templateName.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              apprenticeName.toString(),
              style: TextStyle(
                color: Colors.grey[400],
                fontFamily: 'Poppins',
                fontSize: 13,
              ),
            ),
            Text(
              'Overall Score: ${overall10.toStringAsFixed(1)}/10',
              style: TextStyle(
                color: _getScoreColor(overallPct),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            if (scores.containsKey('category_scores'))
              Text(
                _buildCategoryScoresSummary(scores['category_scores'] as Map<String, dynamic>),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              ),
            if (createdAt != null)
              Text(
                _formatDateString(createdAt),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[600],
          size: 16,
        ),
        onTap: () {
          // If this submission is for Spiritual Gifts, route to the dedicated gifts screen
          if (isSpiritualGiftsAssessment(assessment)) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MentorSpiritualGiftsScreen(
                  initialApprenticeId: apprenticeId?.toString().isEmpty == false ? apprenticeId.toString() : null,
                  initialApprenticeName: apprenticeName?.toString(),
                ),
              ),
            );
            return;
          }

          // Navigate to mentor submission detail screen with real IDs
          if (assessmentId.isNotEmpty) {
            Navigator.of(context).pushNamed(
              '/mentor/submissions/$assessmentId',
              arguments: {
                'apprenticeName': apprenticeName,
                'apprenticeId': apprenticeId,
              },
            );
          } else {
            _showAssessmentResults(assessment); // fallback to legacy view
          }
        },
      ),
    );
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
      _showMessage('Failed to load apprentice profile: $e', isError: true);
    }
  }

  Future<void> _showApprenticeAssessments(String apprenticeId) async {
    try {
      final apprentice = _apprentices.firstWhere((a) => a['id'] == apprenticeId, orElse: () => {});
      final name = (apprentice['name'] ?? apprentice['display_name'] ?? apprentice['email'] ?? 'Apprentice').toString();
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => MentorAssessmentResultsScreen(apprenticeId: apprenticeId, apprenticeName: name)));
    } catch (e) {
      _showMessage('Unable to open assessments: $e', isError: true);
    }
  }

  Future<void> _showApprenticeDraft(String apprenticeId) async {
    try {
      final draft = await _apiService.getApprenticeDraft(apprenticeId);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Current Draft',
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
                  'Status: ${draft['is_submitted'] == true ? 'Submitted' : 'In Progress'}',
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Score: ${draft['score'] ?? 'Not yet scored'}',
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last Updated: ${_formatDateString(draft['updated_at'] ?? '')}',
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
      _showMessage('No current draft found for this apprentice', isError: true);
    }
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
                  print('[UI] Terminate pressed for apprentice=$apprenticeId reasonLen='+controller.text.trim().length.toString());
                  setState(() => submitting = true);
                  try {
                    await _apiService.terminateApprenticeship(apprenticeId, controller.text.trim());
                    // Refresh inactive apprentices list so dialog shows updated data if opened immediately
                    await _loadInactiveApprentices();
                    if (mounted) {
                      setState(() {
                        _apprentices.removeWhere((a) => a['id'] == apprenticeId);
                      });
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mentorship terminated')));
                    }
                  } catch (e) {
                    setState(() => submitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
