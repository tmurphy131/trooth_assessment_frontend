import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'assessment_screen.dart';

/// Preview screen shown before starting an assessment.
/// Displays assessment title, description, times taken, and last score.
class AssessmentPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> template;

  const AssessmentPreviewScreen({
    super.key,
    required this.template,
  });

  @override
  State<AssessmentPreviewScreen> createState() => _AssessmentPreviewScreenState();
}

class _AssessmentPreviewScreenState extends State<AssessmentPreviewScreen> {
  final ApiService _apiService = ApiService();
  
  bool _isLoading = true;
  int _timesTaken = 0;
  double? _lastScore;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAssessmentHistory();
  }

  Future<void> _loadAssessmentHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final templateId = widget.template['id'] as String;
      final historyResponse = await _apiService.getGenericHistory(templateId, limit: 100);
      
      final results = historyResponse['results'] as List<dynamic>? ?? [];
      
      setState(() {
        _timesTaken = results.length;
        if (results.isNotEmpty) {
          // Get the most recent score (first item since sorted desc)
          final latestScores = results.first as Map<String, dynamic>?;
          if (latestScores != null) {
            // Try to get overall_score from the scores object
            final overallScore = latestScores['overall_score'];
            if (overallScore != null) {
              _lastScore = (overallScore is num) ? overallScore.toDouble() : double.tryParse(overallScore.toString());
            }
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        // Don't show error for 404 (no history yet)
        if (!e.toString().contains('404')) {
          _errorMessage = 'Unable to load assessment history';
        }
      });
    }
  }

  void _startAssessment() {
    final templateId = widget.template['id'] as String;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AssessmentScreen(templateId: templateId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMaster = widget.template['is_master_assessment'] == true;
    final name = widget.template['name'] ?? 'Assessment';
    final description = widget.template['description'] ?? 'No description available.';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.amber),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Assessment Preview',
          style: TextStyle(
            color: Colors.amber,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Assessment Icon
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isMaster ? Colors.amber.withOpacity(0.2) : Colors.grey[800],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isMaster ? Icons.star : Icons.assignment,
                          size: 40,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Assessment Title
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    // Official Badge
                    if (isMaster) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'OFFICIAL ASSESSMENT',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Description
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontFamily: 'Poppins',
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // History Stats
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.amber),
                      )
                    else ...[
                      _buildStatsCard(),
                    ],
                  ],
                ),
              ),
            ),

            // Fixed bottom buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Begin Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _startAssessment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey[700],
                    ),
                    child: const Text(
                      'Begin Assessment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cancel Button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                        fontFamily: 'Poppins',
                      ),
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

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Times Taken
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.replay,
                color: Colors.grey[500],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Times Taken:',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_timesTaken',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          
          // Last Score (only if taken before)
          if (_timesTaken > 0 && _lastScore != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.grey, height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  color: _getScoreColor(_lastScore!),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Last Score:',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatScore(_lastScore!),
                  style: TextStyle(
                    color: _getScoreColor(_lastScore!),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ],

          // First time message
          if (_timesTaken == 0) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.grey, height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.celebration,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "This will be your first time!",
                  style: TextStyle(
                    color: Colors.amber[300],
                    fontSize: 14,
                    fontFamily: 'Poppins',
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatScore(double score) {
    // If score is on a 1-10 scale
    if (score <= 10) {
      return '${score.toStringAsFixed(1)}/10';
    }
    // If score is a percentage (0-100)
    return '${score.toStringAsFixed(0)}%';
  }

  Color _getScoreColor(double score) {
    // Normalize to 0-1 scale
    double normalized = score <= 10 ? score / 10 : score / 100;
    
    if (normalized >= 0.8) return Colors.green;
    if (normalized >= 0.6) return Colors.amber;
    if (normalized >= 0.4) return Colors.orange;
    return Colors.red;
  }
}
