import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MentorDashboard extends StatefulWidget {
  const MentorDashboard({super.key});

  @override
  State<MentorDashboard> createState() => _MentorDashboardState();
}

class _MentorDashboardState extends State<MentorDashboard> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _apprentices = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApprentices();
  }

  Future<void> _loadApprentices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get submitted drafts from mentor endpoint
      final submittedDrafts = await _apiService.getSubmittedDrafts();
      
      // Group drafts by apprentice (using user_id)
      Map<String, List<Map<String, dynamic>>> apprenticeGroups = {};
      
      for (var draft in submittedDrafts) {
        final userId = draft['user_id']?.toString() ?? 'unknown';
        if (!apprenticeGroups.containsKey(userId)) {
          apprenticeGroups[userId] = [];
        }
        apprenticeGroups[userId]!.add(draft);
      }
      
      // Convert to list format for UI
      List<Map<String, dynamic>> apprenticesList = [];
      apprenticeGroups.forEach((userId, userDrafts) {
        apprenticesList.add({
          'id': userId,
          'name': 'Apprentice $userId', // We'll improve this with real names later
          'drafts': userDrafts,
          'total_assessments': userDrafts.length,
          'completed_assessments': userDrafts.where((d) => d['is_submitted'] == true).length,
          'in_progress_assessments': userDrafts.where((d) => d['is_submitted'] == false).length,
        });
      });

      setState(() {
        _apprentices = apprenticesList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDateString(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Color _getProgressColor(int completed, int total) {
    if (total == 0) return Colors.grey;
    final ratio = completed / total;
    if (ratio >= 0.8) return Colors.green;
    if (ratio >= 0.5) return Colors.orange;
    return Colors.red;
  }

  void _viewApprenticeDetails(Map<String, dynamic> apprentice) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[700],
                  child: Text(
                    apprentice['name'][0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  apprentice['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Assessment Progress',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            ...((apprentice['drafts'] as List<Map<String, dynamic>>).map((draft) {
              final isSubmitted = draft['is_submitted'] == true;
              final title = draft['title'] ?? 'Spiritual Assessment';
              final createdAt = draft['created_at'] as String?;
              final score = draft['score'] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSubmitted ? Icons.check_circle : Icons.access_time,
                      color: isSubmitted ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          Text(
                            isSubmitted 
                              ? 'Completed${score > 0 ? ' - Score: $score%' : ''}'
                              : 'In Progress',
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
                                fontSize: 11,
                                fontFamily: 'Poppins',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            })),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprenticeCard(Map<String, dynamic> apprentice) {
    final totalAssessments = apprentice['total_assessments'] as int;
    final completedAssessments = apprentice['completed_assessments'] as int;
    final inProgressAssessments = apprentice['in_progress_assessments'] as int;
    final progressColor = _getProgressColor(completedAssessments, totalAssessments);

    return Card(
      elevation: 2,
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[700],
          child: Text(
            apprentice['name'][0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          apprentice['name'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.assessment, color: progressColor, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$completedAssessments/$totalAssessments completed',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            if (inProgressAssessments > 0)
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$inProgressAssessments in progress',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: totalAssessments > 0 ? completedAssessments / totalAssessments : 0,
              backgroundColor: Colors.grey[700],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[600],
          size: 16,
        ),
        onTap: () => _viewApprenticeDetails(apprentice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Mentor Dashboard',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.grey[850],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadApprentices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                          fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadApprentices,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _apprentices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No apprentices found',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 18,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Apprentices will appear here once they start assessments',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                              fontFamily: 'Poppins',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadApprentices,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.people,
                                  color: Colors.blue[700],
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Apprentice Progress',
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_apprentices.length} apprentices',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _apprentices.length,
                                itemBuilder: (context, index) {
                                  return _buildApprenticeCard(_apprentices[index]);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}
