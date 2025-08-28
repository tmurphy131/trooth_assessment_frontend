import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/base_dashboard.dart';
import '../services/api_service.dart';
import 'template_management_screen.dart';
import 'apprentice_invite_screen.dart';
import 'assessment_results_screen.dart';

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
  Map<String, List<Map<String, dynamic>>> _completedAssessmentsByApprentice = {};
  bool _isLoadingApprentices = true;
  bool _isLoadingAssessments = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeAndLoadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      ]);
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoadingApprentices = false;
        _isLoadingAssessments = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return BaseDashboard(
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.amber,
        labelColor: Colors.amber,
        unselectedLabelColor: Colors.grey[500],
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
        ),
        tabs: const [
          Tab(icon: Icon(Icons.people), text: 'Apprentices'),
          Tab(icon: Icon(Icons.assignment), text: 'Assessments'),
          Tab(icon: Icon(Icons.note), text: 'Notes'),
          Tab(icon: Icon(Icons.history), text: 'History'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApprenticesTab(),
          _buildAssessmentsTab(),
          _buildNotesTab(),
          _buildHistoryTab(),
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
          ],
        ),
      ),
    );
  }

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

  Widget _buildNotesTab() {
    return const Center(
      child: Text(
        'Notes functionality coming soon',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return const Center(
      child: Text(
        'History functionality coming soon',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontFamily: 'Poppins',
        ),
      ),
    );
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
    _showComingSoon('Apprentice Assessments');
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

  void _showComingSoon(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Coming Soon!',
          style: TextStyle(
            color: Colors.amber,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '$feature functionality will be available soon. Stay tuned for updates!',
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
