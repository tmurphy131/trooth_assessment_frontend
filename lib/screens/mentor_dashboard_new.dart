import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/base_dashboard.dart';
import '../services/api_service.dart';
import 'template_management_screen.dart';
import 'apprentice_invite_screen.dart';
import 'assessment_results_screen.dart';
import 'mentor_agreements_screen.dart';
import 'mentor_notifications_screen.dart';
import 'mentor_assessment_results_screen.dart';
import 'dart:async';
import 'mentor_profile_screen.dart';
import 'mentor_resources_screen.dart';
import 'mentor_spiritual_gifts_screen.dart';

class MentorDashboardNew extends StatefulWidget {
  const MentorDashboardNew({super.key});

  @override
  State<MentorDashboardNew> createState() => _MentorDashboardNewState();
}

class _MentorDashboardNewState extends State<MentorDashboardNew> with TickerProviderStateMixin {
  late TabController _tabController;
  final user = FirebaseAuth.instance.currentUser;
  final _apiService = ApiService();
  
  // State management
  List<Map<String, dynamic>> _apprentices = [];
  // Inactive apprentice data moved to ApprenticeInviteScreen
  Map<String, List<Map<String, dynamic>>> _completedAssessmentsByApprentice = {};
  bool _isLoadingApprentices = true;
  bool _isLoadingAssessments = true;
  // bool _loadingInactive = false; // Removed unused inactive apprentice state
  String? _error;
  int _activeNotificationCount = 0;
  Timer? _notifTimer;

  @override
  void initState() {
    super.initState();
  _tabController = TabController(length: 5, vsync: this); // Removed History tab; Resources now a tab
    _initializeAndLoadData();
  }


  Future<void> _initializeAndLoadData() async {
    try {
      // Set the bearer token for API calls
      if (user != null) {
        final token = await user!.getIdToken();
        _apiService.bearerToken = token;
      }
      
      await Future.wait([
        _loadApprentices(),
        _loadCompletedAssessments(),
        _loadInactiveApprentices(),
        _refreshNotificationCount(),
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

  Future<void> _loadCompletedAssessments() async {
    try {
      setState(() {
        _isLoadingAssessments = true;
        _error = null;
      });
      Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final apprentice in _apprentices) {
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
    return BaseDashboard(
      logoHeight: 64,
      additionalActions: [
        IconButton(
          icon: const Icon(Icons.account_circle, color: Color(0xFFFFD700)),
          tooltip: 'My Profile',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MentorProfileScreen()),
            );
          },
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.amber,
        labelColor: Colors.amber,
        unselectedLabelColor: Colors.grey[500],
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
        ),
        tabs: [
          const Tab(icon: Icon(Icons.people), text: 'Apprentices'),
          const Tab(icon: Icon(Icons.assignment), text: 'Assessments'),
          const Tab(icon: Icon(Icons.description), text: 'Agreements'),
          const Tab(icon: Icon(Icons.link), text: 'Resources'),
          Tab(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications),
                if (_activeNotificationCount > 0) Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _activeNotificationCount > 99 ? '99+' : _activeNotificationCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            text: 'Alerts',
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
                              return _buildApprenticeCard(_apprentices[index]);
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
      final scores = allAssessments
          .where((assessment) => assessment['scores']?['overall_score'] != null)
          .map((assessment) => (assessment['scores']['overall_score'] as num).toDouble())
          .toList();
      if (scores.isNotEmpty) {
        averageScore = scores.reduce((a, b) => a + b) / scores.length;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.people,
            title: 'Active Apprentices',
            value: totalApprentices.toString(),
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.assignment_turned_in,
            title: 'Completed Assessments',
            value: totalCompletedAssessments.toString(),
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.trending_up,
            title: 'Average Score',
            value: '${averageScore.toStringAsFixed(1)}%',
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
        padding: const EdgeInsets.all(16.0),
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
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
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

  Widget _buildApprenticeCard(Map<String, dynamic> apprentice) {
    final name = apprentice['name'] ?? 'Unknown';
    final email = apprentice['email'] ?? '';
    final apprenticeId = apprentice['id'] as String;
    
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
          ),
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
              case 'draft':
                await _showApprenticeDraft(apprenticeId);
                break;
              case 'meeting':
                await _showMeetingInfo(apprenticeId, email, name);
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
              value: 'draft',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Current Draft', style: TextStyle(color: Colors.white)),
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

  Widget _buildAssessmentsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Assessment Results',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              IconButton(
                onPressed: _loadCompletedAssessments,
                icon: const Icon(Icons.refresh, color: Colors.amber),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingAssessments
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  )
                : _completedAssessmentsByApprentice.isEmpty
                    ? _buildEmptyAssessmentsState()
                    : ListView(
                        children: _apprentices.map((apprentice) {
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
    final overallScore = scores['overall_score'] ?? 0;
    final createdAt = assessment['created_at'] as String?;
    final apprenticeName = assessment['apprentice_name'] ?? 'Unknown Apprentice';
    
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
            color: _getScoreColor(overallScore * 10).withOpacity(0.2), // Convert 1-10 to percentage
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.analytics,
            color: _getScoreColor(overallScore * 10),
          ),
        ),
        title: Text(
          apprenticeName,
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
              'Overall Score: $overallScore/10',
              style: TextStyle(
                color: _getScoreColor(overallScore * 10),
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
        onTap: () => _showAssessmentResults(assessment),
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
