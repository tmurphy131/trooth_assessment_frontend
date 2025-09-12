import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/base_dashboard.dart';
import '../services/api_service.dart';
import 'assessment_screen.dart';
import 'apprentice_invites_screen.dart';
// Use the unified mentor & agreements screen (overview merged in)
import 'apprentice_mentor_screen.dart';

class ApprenticeDashboardNew extends StatefulWidget {
  const ApprenticeDashboardNew({super.key});

  @override
  State<ApprenticeDashboardNew> createState() => _ApprenticeDashboardNewState();
}

class _ApprenticeDashboardNewState extends State<ApprenticeDashboardNew> {
  final user = FirebaseAuth.instance.currentUser;
  final _apiService = ApiService();
  List<Map<String, dynamic>> _assessments = [];
  bool _isLoading = true;
  String? _error;
  String? _name; // backend 'name' field

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  String _deriveDisplayName() {
    final n = _name?.trim();
    if (n != null && n.isNotEmpty) return n;
    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@')[0];
    return 'Apprentice';
  }

  Future<void> _initializeAndLoadData() async {
    try {
      // Set the bearer token for API calls
      if (user != null) {
        final token = await user!.getIdToken();
        _apiService.bearerToken = token;
      }
      
      // In parallel: user profile + assessments
      await Future.wait([
        _loadUserProfile(),
        _loadAssessments(),
      ]);
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final uid = user?.uid;
      if (uid == null) return;
  final profile = await _apiService.getUserProfile(uid);
  final name = (profile['name'] as String?)?.trim();
  if (mounted) setState(() { _name = (name == null || name.isEmpty) ? null : name; });
    } catch (e) {
      // Silent fail; fall back to email prefix
      debugPrint('Failed to load apprentice profile name: $e');
    }
  }

  Future<void> _loadAssessments() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      if (user?.uid != null) {
        // Get all drafts (both in progress and submitted)
        final allDrafts = await _apiService.getAllDrafts();
        print('=== API RESPONSE DEBUG ===');
        print('Number of drafts received: ${allDrafts.length}');
        for (int i = 0; i < allDrafts.length; i++) {
          print('Draft $i: ${allDrafts[i]}');
        }
        print('=== END API RESPONSE DEBUG ===');
        
        setState(() {
          _assessments = allDrafts.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load assessments: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseDashboard(
      logoHeight: 64,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            
            // Quick Actions
            _buildQuickActions(),
            const SizedBox(height: 24),
            
            // Recent Assessments
            Expanded(
              child: _buildRecentAssessments(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.amber,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    _deriveDisplayName(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#getrooted',
                    style: TextStyle(
                      color: Colors.amber[300],
                      fontSize: 12,
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.quiz,
                title: 'New Assessment',
                subtitle: 'Start a spiritual assessment',
                color: Colors.amber,
                onTap: () => _startNewAssessment(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.mail_outline,
                title: 'Invitations',
                subtitle: 'View mentor invites',
                color: Colors.green,
                onTap: () => _viewInvitations(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.history,
                title: 'View Progress',
                subtitle: 'Track your growth',
                color: Colors.blue,
                onTap: () => _showComingSoon('Progress Tracking'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.people,
                title: 'Mentor',
                subtitle: 'Mentor & Agreements',
                color: Colors.purple,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ApprenticeMentorScreen()),
                ),
              ),
            ),
          ],
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
  }) {
    return Card(
      elevation: 2,
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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
                  fontSize: 12,
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

  Widget _buildRecentAssessments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Assessments',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            IconButton(
              onPressed: _loadAssessments,
              icon: const Icon(Icons.refresh, color: Colors.amber),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoading
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
                            onPressed: _loadAssessments,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _assessments.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: _assessments.length,
                          itemBuilder: (context, index) {
                            return _buildAssessmentCard(_assessments[index]);
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
                'No assessments yet',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start your spiritual growth journey by taking your first assessment',
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

  Widget _buildAssessmentCard(Map<String, dynamic> assessment) {
    final title = assessment['title'] ?? 'Spiritual Assessment';
    final isSubmitted = assessment['is_submitted'] == true;
    final status = isSubmitted ? 'completed' : 'in_progress';
    final score = assessment['score'] ?? 0;
    final createdAt = assessment['created_at'] as String?;
    final assessmentId = assessment['id'] as String?;
    
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAssessments(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete draft: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
