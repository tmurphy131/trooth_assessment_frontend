import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/base_dashboard.dart';
import '../services/api_service.dart';
import 'assessment_screen.dart';
import 'agreement_preview_screen.dart';
import 'spiritual_gifts_results_screen.dart';

class ApprenticeDashboard extends StatefulWidget {
  const ApprenticeDashboard({super.key});

  @override
  State<ApprenticeDashboard> createState() => _ApprenticeDashboardState();
}

class _ApprenticeDashboardState extends State<ApprenticeDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  final _apiService = ApiService();
  List<Map<String, dynamic>> _assessments = [];
  List<Map<String, dynamic>> _agreements = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
        _loadAssessments(),
        _loadAgreements(),
      ]);
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAgreements() async {
    try {
      final list = await _apiService.listMyAgreements();
      setState(() { _agreements = list.cast<Map<String, dynamic>>(); });
    } catch (e) {
      // Soft-fail; keep dashboard usable
      debugPrint('Failed to load agreements: $e');
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

            // Spiritual Gifts Progress Card (preview of latest)
            _SpiritualGiftsProgressCard(api: _apiService, onStart: _startNewAssessment, onView: _openSpiritualGiftsResults),
            const SizedBox(height: 24),
            
            // Mentorship Agreements (only when present)
            if (_agreements.isNotEmpty) _buildAgreementsSection(),
            if (_agreements.isNotEmpty) const SizedBox(height: 24),

            // Recent Assessments
            Expanded(
              child: _buildRecentAssessments(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgreementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mentorship Agreements',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            IconButton(
              onPressed: _loadAgreements,
              icon: const Icon(Icons.refresh, color: Colors.amber),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          children: _agreements.map(_buildAgreementRow).toList(),
        ),
      ],
    );
  }

  Widget _buildAgreementRow(Map<String, dynamic> ag) {
    final status = ag['status'] as String? ?? 'unknown';
    final mentorName = ag['mentor_name'] ?? 'Mentor';
    final createdAt = ag['created_at'] as String?;
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.assignment, color: _statusColor(status)),
        title: Text('With $mentorName', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        subtitle: Text(
          '${_statusLabel(status)}${createdAt != null ? ' • ${_shortDate(createdAt)}' : ''}',
          style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins'),
        ),
        trailing: TextButton(
          onPressed: () => _openAgreement(ag),
          child: const Text('Open', style: TextStyle(color: Colors.amber, fontFamily: 'Poppins')),
        ),
      ),
    );
  }

  void _openAgreement(Map<String, dynamic> ag) {
    final markdown = ag['content_rendered'] as String?;
    if (markdown == null || markdown.isEmpty) {
      _showSnack('No preview available');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AgreementPreviewScreen(
          markdown: markdown,
          status: ag['status'] ?? 'draft',
          apprenticeEmail: ag['apprentice_email'],
          parentEmail: ag['parent_email'],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'awaiting_apprentice': return Colors.orange;
      case 'awaiting_parent': return Colors.purple;
      case 'fully_signed': return Colors.green;
      case 'revoked': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'awaiting_apprentice': return 'Awaiting you';
      case 'awaiting_parent': return 'Awaiting parent';
      case 'fully_signed': return 'Completed';
      case 'revoked': return 'Revoked';
      default: return status;
    }
  }

  String _shortDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) { return iso; }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
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
                    user?.email?.split('@')[0] ?? 'Apprentice',
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
                icon: Icons.history,
                title: 'View Progress',
                subtitle: 'Track your growth',
                color: Colors.blue,
                onTap: () => _showComingSoon('Progress Tracking'),
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
    
    // Debug: Print the assessment data to understand the structure
    print('Assessment data: $assessment');
    print('is_submitted value: ${assessment['is_submitted']} (type: ${assessment['is_submitted'].runtimeType})');
    print('isSubmitted boolean: $isSubmitted');
    
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
        onTap: () {
          print('Tapped assessment. isSubmitted: $isSubmitted, assessmentId: $assessmentId');
          if (isSubmitted) {
            _showComingSoon('Assessment Details');
          } else {
            // Navigate to continue the assessment
            if (assessmentId != null) {
              _continueAssessment(assessmentId);
            } else {
              _showMessage('No assessment ID found', isError: true);
            }
          }
        },
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
        _showMessage('No assessment templates available', isError: true);
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
      
      // Start a new draft
      await _apiService.startDraft(selectedTemplateId);
      
      _showMessage('New assessment started successfully!');
      
      // Navigate to assessment screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssessmentScreen(templateId: selectedTemplateId),
          ),
        );
      }
      
    } catch (e) {
      _showMessage('Failed to start assessment: $e', isError: true);
    }
  }

  void _openSpiritualGiftsResults() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SpiritualGiftsResultsScreen(),
      ),
    );
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

  Future<void> _continueAssessment(String draftId) async {
    try {
      // Navigate to assessment screen with the draft
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AssessmentScreen(draftId: draftId),
        ),
      );
      
      // Refresh the assessments list when returning
      if (result != null) {
        await _loadAssessments();
      }
      
    } catch (e) {
      _showMessage('Failed to continue assessment: $e', isError: true);
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
      _showMessage('Draft deleted successfully');
      _loadAssessments(); // Refresh the list
    } catch (e) {
      _showMessage('Failed to delete draft: $e', isError: true);
    }
  }
}

class _SpiritualGiftsProgressCard extends StatefulWidget {
  final ApiService api;
  final VoidCallback onStart;
  final VoidCallback onView;
  const _SpiritualGiftsProgressCard({required this.api, required this.onStart, required this.onView});

  @override
  State<_SpiritualGiftsProgressCard> createState() => _SpiritualGiftsProgressCardState();
}

class _SpiritualGiftsProgressCardState extends State<_SpiritualGiftsProgressCard> {
  bool _loading = true;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await widget.api.getSpiritualGiftsLatest();
      if (!mounted) return;
      if (json.isEmpty) {
        setState(() { _loading = false; _result = null; });
      } else {
        setState(() { _loading = false; _result = json; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 26),
                const SizedBox(width: 10),
                const Text('Spiritual Gifts', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh, color: Colors.amber, size: 20),
                  tooltip: 'Refresh',
                )
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2)))
            else if (_error != null)
              _buildError()
            else if (_result == null)
              _buildEmpty()
            else
              _buildPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Failed to load: $_error', style: const TextStyle(color: Colors.redAccent, fontFamily: 'Poppins', fontSize: 12)),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _load,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
          child: const Text('Retry', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  Widget _buildEmpty() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'Discover how God has uniquely gifted you. Take the Spiritual Gifts Assessment to see your top gifts.',
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontFamily: 'Poppins', fontSize: 13, height: 1.3),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: widget.onStart,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          child: const Text('Start', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  Widget _buildPreview() {
    final createdAt = _result!['created_at'] as String?;
    final truncated = (_result!['top_gifts_truncated'] ?? _result!['top_gifts'] ?? []) as List<dynamic>;
    final gifts = truncated.take(3).map((g) => g['gift'] ?? g['gift_name'] ?? g['name'] ?? 'Gift').cast<String>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (createdAt != null)
          Text(_friendlyDate(createdAt), style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'Poppins')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: gifts.map((g) => _GiftChip(label: g)).toList(),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            ElevatedButton(
              onPressed: widget.onView,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
              child: const Text('View Report', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: widget.onStart,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.amber, side: const BorderSide(color: Colors.amber), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
              child: const Text('Retake', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            )
          ],
        )
      ],
    );
  }

  String _friendlyDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    } catch (_) { return iso; }
  }
}

class _GiftChip extends StatelessWidget {
  final String label;
  const _GiftChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.45)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
