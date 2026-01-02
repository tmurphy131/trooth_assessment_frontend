import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/base_dashboard.dart';
import '../services/api_service.dart';
import '../mixins/apprentice_dashboard_tutorial.dart';
import 'assessment_screen.dart';
import 'apprentice_invites_screen.dart';
// Use the unified mentor & agreements screen (overview merged in)
import 'apprentice_mentor_screen.dart';
import 'spiritual_gifts_assessment_screen.dart';
import 'spiritual_gifts_results_screen.dart';
import 'spiritual_gifts_history_screen.dart';
import 'progress_screen.dart';
import 'apprentice_resources_screen.dart';
import 'apprentice_profile_screen.dart';

class ApprenticeDashboardNew extends StatefulWidget {
  const ApprenticeDashboardNew({super.key});

  @override
  State<ApprenticeDashboardNew> createState() => _ApprenticeDashboardNewState();
}

class _SpiritualGiftsQuickActionsSheet extends StatelessWidget {
  final Future<bool?> Function()? onRequestStart;
  const _SpiritualGiftsQuickActionsSheet({this.onRequestStart});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const Text('Spiritual Gifts', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 6),
            Text("Choose what you'd like to do with your Spiritual Gifts Assessment.", style: TextStyle(color: Colors.white.withOpacity(0.7), fontFamily: 'Poppins', fontSize: 12, height: 1.3)),
            const SizedBox(height: 18),
            _action(
              context,
              icon: Icons.visibility,
              label: 'View Latest Results',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SpiritualGiftsResultsScreen()));
              },
            ),
            _action(
              context,
              icon: Icons.history,
              label: 'View History',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SpiritualGiftsHistoryScreen()));
              },
            ),
            _action(
              context,
              icon: Icons.refresh,
              label: 'Start New Assessment',
              color: Colors.amber,
              onTap: () async {
                // Capture a navigator capable context before closing the sheet
                final navigator = Navigator.of(context);
                Navigator.pop(context); // close sheet first
                bool proceed = true;
                if (onRequestStart != null) {
                  proceed = (await onRequestStart!()) == true;
                }
                if (proceed) {
                  // Use the captured navigator to push after sheet + dialog dismissed
                  navigator.push(
                    MaterialPageRoute(builder: (_) => const SpiritualGiftsAssessmentScreen()),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'Poppins')),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, Color? color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (color ?? Colors.blue).withOpacity(0.15),
          child: Icon(icon, color: color ?? Colors.blue),
        ),
        title: Text(label, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        onTap: onTap,
      ),
    );
  }
}
class _ApprenticeDashboardNewState extends State<ApprenticeDashboardNew> with ApprenticeDashboardTutorial {
  final user = FirebaseAuth.instance.currentUser;
  final _apiService = ApiService();
  List<Map<String, dynamic>> _assessments = [];
  // Cache of templateId -> template name for displaying draft titles
  Map<String, String> _templateNameById = {};
  bool _isLoading = true;
  String? _error;
  String? _name; // backend 'name' field
  int _inviteCount = 0;
  int _pendingAgreementCount = 0;

  /// Total badge count = invites + pending agreements
  int get _totalNotificationCount => _inviteCount + _pendingAgreementCount;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
    initApprenticeTutorial();
  }

  Future<void> _initializeAndLoadData() async {
    await Future.wait([
      _loadUserProfile(),
      _loadAssessments(),
      _loadInviteCount(),
      _loadPendingAgreementCount(),
    ]);
  }

  Future<void> _loadInviteCount() async {
    final email = user?.email;
    if (email == null) return;
    try {
      final invites = await _apiService.getApprenticeInvites(email);
      if (mounted) setState(() { _inviteCount = invites.length; });
    } catch (e) {
      debugPrint('Failed to load invites: $e');
    }
  }

  Future<void> _loadPendingAgreementCount() async {
    try {
      final agreements = await _apiService.listMyAgreements();
      final pendingCount = agreements
          .where((a) => a['status'] == 'awaiting_apprentice')
          .length;
      if (mounted) setState(() { _pendingAgreementCount = pendingCount; });
    } catch (e) {
      debugPrint('Failed to load pending agreements: $e');
    }
  }

  String _deriveDisplayName() {
    final n = _name?.trim();
    if (n != null && n.isNotEmpty) {
      // Return only the first name
      final firstName = n.split(' ').first;
      return firstName;
    }
    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@')[0];
    return 'Apprentice';
  }

  Future<void> _loadUserProfile() async {
    try {
      final uid = user?.uid;
      if (uid == null) return;
      final profile = await _apiService.getUserProfile(uid);
      final name = (profile['name'] as String?)?.trim();
      if (mounted) setState(() { _name = (name == null || name.isEmpty) ? null : name; });
    } catch (e) {
      debugPrint('Failed to load apprentice profile name: $e');
    }
  }

  Future<void> _loadAssessments() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      // Fetch all drafts (includes in-progress + possibly submitted depending on backend behavior)
      final list = await _apiService.getAllDrafts();
      // Normalize & filter to only those NOT submitted (drafts still in progress)
      final items = list
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .where((m) => m['is_submitted'] != true) // keep only active drafts
          .toList()
        ..sort((a,b){
          final da = DateTime.tryParse(a['updated_at'] ?? a['created_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final db = DateTime.tryParse(b['updated_at'] ?? b['created_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da); // newest first
        });
      // Build a lookup of template IDs to names to render accurate draft titles
      Map<String, String> names = {};
      try {
        final templates = await _apiService.getPublishedTemplates();
        for (final t in templates) {
          final id = (t['id'] ?? t['template_id'])?.toString();
          if (id == null) continue;
          final name = (t['name'] ?? t['display_name'] ?? t['title'] ?? '').toString();
          if (name.trim().isNotEmpty) names[id] = name.trim();
        }
      } catch (_) {
        // If template lookup fails, continue with empty map and fallbacks
      }
      if (mounted) {
        setState(() {
          _assessments = items;
          _templateNameById = names;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load assessments: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseDashboard(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: _buildQuickActions(),
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildRecentAssessments()),
          ],
        ),
      ),
      additionalActions: [
        // Profile icon
        IconButton(
          key: profileButtonKey,
          icon: const Icon(Icons.account_circle, color: Color(0xFFFFD700)),
          tooltip: 'My Profile',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ApprenticeProfileScreen()),
          ),
        ),
        // Mentor & Agreements icon
        IconButton(
          key: mentorButtonKey,
          icon: const Icon(Icons.people, color: Color(0xFFFFD700)),
          tooltip: 'Mentor & Agreements',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ApprenticeMentorScreen()),
          ),
        ),
        // Invitations icon with badge (badge hidden automatically when count == 0)
        Stack(
          key: invitationsButtonKey,
          alignment: Alignment.topRight,
          children: [
            IconButton(
              icon: const Icon(Icons.mail_outline, color: Color(0xFFFFD700)),
              tooltip: 'Invitations',
              onPressed: () async {
                _viewInvitations();
                // Refresh both counts after returning from invitations screen
                await Future.wait([
                  _loadInviteCount(),
                  _loadPendingAgreementCount(),
                ]);
              },
            ),
            if (_totalNotificationCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _totalNotificationCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      key: welcomeCardKey,
      elevation: 4,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.person, color: Colors.amber, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome back, ${_deriveDisplayName()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '#getrooted',
                    style: TextStyle(
                      color: Colors.amber[300],
                      fontSize: 11,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 6),
        // First row: New Assessment + Spiritual Gifts
        Expanded(
          child: Row(
          children: [
            Expanded(
              child: _buildActionCard(
                cardKey: newAssessmentCardKey,
                icon: Icons.quiz,
                title: 'New Assessment',
                subtitle: 'Start a spiritual assessment',
                color: Colors.amber,
                onTap: _startNewAssessment,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _apiService.getSpiritualGiftsLatest(),
                builder: (context, snap) {
                  final hasResult = snap.hasData && (snap.data?.isNotEmpty ?? false);
                  return _buildActionCard(
                    cardKey: spiritualGiftsCardKey,
                    icon: Icons.auto_awesome,
                    title: 'Spiritual Gifts',
                    subtitle: hasResult ? 'View or retake assessment' : 'Discover your gifts',
                    color: Colors.tealAccent.shade700,
                    onTap: () async {
                      if (!hasResult) {
                        final proceed = await _showSpiritualGiftsDisclaimer();
                        if (proceed == true && mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SpiritualGiftsAssessmentScreen()),
                          );
                        }
                      } else {
                        if (!mounted) return;
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.grey[900],
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
                          builder: (_) => _SpiritualGiftsQuickActionsSheet(
                            onRequestStart: _showSpiritualGiftsDisclaimer,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
        ),
        const SizedBox(height: 20),
        // Second row: View Progress + Resources
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  cardKey: progressCardKey,
                  icon: Icons.history,
                  title: 'View Progress',
                  subtitle: 'Track your growth',
                  color: Colors.blue,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProgressScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionCard(
                  cardKey: resourcesCardKey,
                  icon: Icons.menu_book,
                  title: 'Resources',
                  subtitle: 'Guides & weekly tips',
                  color: Colors.orange,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ApprenticeResourcesScreen()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    Key? cardKey,
  }) {
    return Card(
      key: cardKey,
      elevation: 2,
      color: Colors.grey[850],
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentAssessments() {
    // Draft assessments section - fills remaining space
    return Column(
      key: recentAssessmentsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Draft Assessments',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(
                height: 28,
                width: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: _loadAssessments,
                  icon: const Icon(Icons.refresh, color: Colors.amber, size: 18),
                  tooltip: 'Refresh',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
                  )
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _assessments.isEmpty
                        ? _buildEmptyStateCompact()
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _assessments.length,
                            itemBuilder: (context, index) {
                              return _buildAssessmentCardCompact(_assessments[index]);
                            },
                          ),
          ),
        ],
      );
  }

  Widget _buildEmptyState() {
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
                'No draft assessments',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Begin a new assessment to start your spiritual growth journey',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _startNewAssessment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Take First Assessment',
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

  Widget _buildEmptyStateCompact() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 24, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No drafts yet',
                style: TextStyle(color: Colors.grey[400], fontSize: 13, fontFamily: 'Poppins', fontWeight: FontWeight.w500),
              ),
              GestureDetector(
                onTap: _startNewAssessment,
                child: Text(
                  'Start a new assessment →',
                  style: TextStyle(color: Colors.amber[300], fontSize: 11, fontFamily: 'Poppins'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentCardCompact(Map<String, dynamic> assessment) {
    final title = _resolveDraftTitle(assessment);
    final assessmentId = assessment['id'] as String?;
    final updatedAt = assessment['updated_at'] as String?;
    final createdAt = assessment['created_at'] as String?;
    String timeInfo = '';
    try {
      final ts = updatedAt ?? createdAt;
      if (ts != null) {
        timeInfo = _relativeTime(DateTime.parse(ts).toLocal());
      }
    } catch (_) {}

    final cardContent = Card(
      elevation: 1,
      color: Colors.grey[850],
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _navigateToAssessment(assessment),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.edit_note, color: Colors.amber, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (timeInfo.isNotEmpty)
                      Text(
                        timeInfo,
                        style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'Poppins'),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
    );

    // Wrap with Dismissible for swipe-to-delete
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Dismissible(
          key: Key(assessmentId ?? title),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await _showDeleteConfirmationDialog(assessmentId, title);
          },
          background: Container(
            decoration: BoxDecoration(
              color: Colors.red[700],
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.close, color: Colors.white, size: 24),
                SizedBox(height: 2),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          child: cardContent,
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmationDialog(String? draftId, String title) async {
    if (draftId == null) return false;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Draft',
          style: TextStyle(
            color: Colors.red,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete the draft "$title"? This action cannot be undone.',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context, true);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await _deleteDraft(draftId);
      return true;
    }
    return false;
  }

  Widget _buildAssessmentCard(Map<String, dynamic> assessment) {
    final title = _resolveDraftTitle(assessment);
    final isSubmitted = assessment['is_submitted'] == true;
    final status = isSubmitted ? 'completed' : 'in_progress';
    final score = assessment['score'] ?? 0;
    final createdAt = assessment['created_at'] as String?;
    final updatedAt = assessment['updated_at'] as String?;
    final assessmentId = assessment['id'] as String?;
    String? relativeLine;
    try {
      if (createdAt != null) {
        final created = DateTime.parse(createdAt).toLocal();
        DateTime? updated;
        if (updatedAt != null) {
          try { updated = DateTime.parse(updatedAt).toLocal(); } catch (_) {}
        }
        // Decide which timestamp to surface: if we have a later updated > created + 2 minutes, show updated
        if (updated != null && updated.isAfter(created.add(const Duration(minutes: 2)))) {
          relativeLine = 'Updated ${_relativeTime(updated)}';
        } else {
          relativeLine = 'Created ${_relativeTime(created)}';
        }
      }
    } catch (_) {
      relativeLine = null; // fallback handled below
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
            color: _getStatusColor(status).withOpacity(0.2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            _getStatusIcon(status),
            color: _getStatusColor(status),
          ),
        ),
        title: Text(
          title,
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
              isSubmitted 
                ? (score > 0 ? 'Score: $score%' : 'Completed') 
                : 'In Progress - Tap to continue',
              style: TextStyle(
                color: Colors.grey[400],
                fontFamily: 'Poppins',
              ),
            ),
            if (relativeLine != null)
              Text(
                relativeLine,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              )
            else if (createdAt != null)
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isSubmitted) // Only show delete for in-progress drafts
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red[400],
                  size: 20,
                ),
                onPressed: () => _confirmDeleteDraft(assessmentId, title),
                tooltip: 'Delete Draft',
              ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[600],
              size: 16,
            ),
          ],
        ),
        onTap: () => _navigateToAssessment(assessment),
      ),
    );
  }

  String _resolveDraftTitle(Map<String, dynamic> assessment) {
    // Prefer explicit template name fields if available
    final templateObj = assessment['template'];
    final fromTemplateObj = (templateObj is Map) ? (templateObj['name'] ?? templateObj['display_name'])?.toString() : null;
    if (fromTemplateObj != null && fromTemplateObj.trim().isNotEmpty) return fromTemplateObj.trim();

    final templateName = (assessment['template_name'] ?? assessment['templateTitle'])?.toString();
    if (templateName != null && templateName.trim().isNotEmpty) return templateName.trim();

    // Try lookup from cached published templates
    final templateId = assessment['template_id']?.toString();
    final fromMap = templateId != null ? _templateNameById[templateId] : null;
    if (fromMap != null && fromMap.trim().isNotEmpty) return fromMap.trim();

    // Fall back to any provided title/name, then a generic label
    final fallback = (assessment['title'] ?? assessment['name'])?.toString();
    if (fallback != null && fallback.trim().isNotEmpty && fallback.trim().toLowerCase() != 'spiritual assessment') {
      return fallback.trim();
    }
    return 'Assessment';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.hourglass_empty;
      case 'pending':
        return Icons.schedule;
      default:
        return Icons.assignment;
    }
  }

  Future<void> _startNewAssessment() async {
    try {
      // First, get available templates
      final templates = await _apiService.getPublishedTemplates();
      
      if (templates.isEmpty) {
        _showMessage('No assessments available at this time.', isError: true);
        return;
      }
      
      String? selectedTemplateId;
      
      // If only one template, use it directly
      if (templates.length == 1) {
        selectedTemplateId = templates.first['id'] as String;
      } else {
        // Show selection dialog for multiple templates
        selectedTemplateId = await _showAssessmentSelectionDialog(templates);
      }
      
      if (selectedTemplateId == null) {
        return; // User cancelled selection
      }
      
      // Navigate to assessment screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AssessmentScreen(templateId: selectedTemplateId),
        ),
      );
      
      // If assessment was completed, refresh the assessments list
      if (result == true) {
        await _loadAssessments();
        _showMessage('Assessment completed successfully!');
      }
      
    } catch (e) {
      _showMessage('Failed to start assessment: $e', isError: true);
    }
  }
  
  Future<String?> _showAssessmentSelectionDialog(List<dynamic> templates) async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Choose Assessment',
            style: TextStyle(
              color: Colors.amber,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                final isMaster = template['is_master_assessment'] == true;
                
                return Card(
                  color: isMaster ? Colors.amber[700] : Colors.grey[800],
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      isMaster ? Icons.star : Icons.assignment,
                      color: isMaster ? Colors.white : Colors.amber,
                    ),
                    title: Text(
                      template['name'] ?? 'Unnamed Assessment',
                      style: TextStyle(
                        color: isMaster ? Colors.white : Colors.white,
                        fontFamily: 'Poppins',
                        fontWeight: isMaster ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: template['description'] != null 
                      ? Text(
                          template['description'],
                          style: TextStyle(
                            color: isMaster ? Colors.white70 : Colors.grey[400],
                            fontFamily: 'Poppins',
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                    trailing: isMaster 
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'OFFICIAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        )
                      : null,
                    onTap: () {
                      Navigator.of(context).pop(template['id'] as String);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        );
      },
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

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) {
      final w = (diff.inDays / 7).floor();
      return w == 1 ? '1w ago' : '${w}w ago';
    }
    if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return months <= 1 ? '1mo ago' : '${months}mo ago';
    }
    final years = (diff.inDays / 365).floor();
    return years <= 1 ? '1y ago' : '${years}y ago';
  }

  // Removed old _showComingSoon placeholder (now wired to Progress screen)

  Future<bool?> _showSpiritualGiftsDisclaimer() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Before You Begin',
          style: TextStyle(
            color: Colors.amber,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'This assessment works best when you respond based on your current reality, not your aspirations. If asked about prayer, answer how you actually pray now, not how you wish you prayed. Choose responses that reflect what comes naturally to you, not what you think sounds more spiritual. Avoid "should" thinking—focus on your genuine patterns and experiences. There are no right or wrong answers, only an opportunity to discover how God has uniquely gifted you.',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Begin',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _viewInvitations() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApprenticeInvitesScreen(user: user),
      ),
    );
  }

  void _navigateToAssessment(Map<String, dynamic> assessment) {
    // Debug: Print the assessment data to see what we're getting
    print('=== ASSESSMENT DEBUG ===');
    print('Full assessment data: $assessment');
    print('Keys: ${assessment.keys.toList()}');
    
    final assessmentId = assessment['id'] as String?;
    final templateId = assessment['template_id'] as String?;
    
    // Check multiple possible field names for submission status
    final isSubmittedRaw = assessment['is_submitted'];
    final submittedAt = assessment['submitted_at'];
    final status = assessment['status'];
    
    print('Raw is_submitted value: $isSubmittedRaw (type: ${isSubmittedRaw.runtimeType})');
    print('submitted_at: $submittedAt');
    print('status: $status');
    
    // Handle different possible formats for submission status
    bool isSubmitted = false;
    if (isSubmittedRaw is bool) {
      isSubmitted = isSubmittedRaw;
    } else if (isSubmittedRaw is String) {
      isSubmitted = isSubmittedRaw.toLowerCase() == 'true';
    } else if (isSubmittedRaw is int) {
      isSubmitted = isSubmittedRaw == 1;
    } else if (submittedAt != null) {
      isSubmitted = true;
    }
    
    print('Final isSubmitted: $isSubmitted');
    print('Assessment ID: $assessmentId');
    print('Template ID: $templateId');
    print('=== END DEBUG ===');
    
    if (assessmentId == null || templateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load assessment details'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (isSubmitted) {
      // For submitted assessments, show the results
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This assessment has already been submitted (is_submitted: $isSubmittedRaw)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Navigate to AssessmentScreen for in-progress drafts
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssessmentScreen(
          templateId: templateId,
          draftId: assessmentId,
        ),
      ),
    ).then((_) {
      // Refresh the assessments list when returning from AssessmentScreen
      _loadAssessments();
    });
  }

  void _confirmDeleteDraft(String? draftId, String title) {
    if (draftId == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Draft',
          style: TextStyle(
            color: Colors.red,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete the draft "$title"? This action cannot be undone.',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDraft(draftId);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDraft(String draftId) async {
    try {
      await _apiService.deleteDraft(draftId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Assessment draft deleted',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadAssessments(); // Refresh the list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete draft: $e',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
