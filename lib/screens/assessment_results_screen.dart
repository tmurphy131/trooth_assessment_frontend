import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AssessmentResultsScreen extends StatefulWidget {
  final Map<String, dynamic> assessment;

  const AssessmentResultsScreen({
    super.key,
    required this.assessment,
  });

  @override
  State<AssessmentResultsScreen> createState() => _AssessmentResultsScreenState();
}

class _AssessmentResultsScreenState extends State<AssessmentResultsScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _detailedResults;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetailedResults();
  }

  Future<void> _loadDetailedResults() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final results = await _apiService.getAssessmentResults(widget.assessment['id']);
      setState(() {
        _detailedResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load detailed results: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.assessment['apprentice_name']} - Assessment Results',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
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
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDetailedResults,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildResultsContent(),
    );
  }

  Widget _buildResultsContent() {
    final scores = _detailedResults?['scores'] as Map<String, dynamic>? ?? {};
    final overallScore = scores['overall_score'] ?? 0;
    final categoryScores = scores['category_scores'] as Map<String, dynamic>? ?? {};
    final recommendations = scores['recommendations'] as Map<String, dynamic>? ?? {};
    final questionFeedback = scores['question_feedback'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Score Card
          _buildScoreCard(overallScore),
          const SizedBox(height: 24),

          // Category Scores
          if (categoryScores.isNotEmpty) ...[
            _buildSectionTitle('Category Scores'),
            const SizedBox(height: 12),
            ...categoryScores.entries.map((entry) => 
              _buildCategoryScoreRow(entry.key, entry.value)
            ),
            const SizedBox(height: 24),
          ],

          // Recommendations
          if (recommendations.isNotEmpty) ...[
            _buildSectionTitle('Recommendations'),
            const SizedBox(height: 12),
            ...recommendations.entries.map((entry) => 
              _buildRecommendationCard(entry.key, entry.value)
            ),
            const SizedBox(height: 24),
          ],

          // Question Feedback
          if (questionFeedback.isNotEmpty) ...[
            _buildSectionTitle('Detailed Question Feedback'),
            const SizedBox(height: 12),
            ...questionFeedback.map((feedback) => 
              _buildQuestionFeedbackCard(feedback as Map<String, dynamic>)
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreCard(int score) {
    return Card(
      elevation: 4,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _getScoreColor(score * 10).withOpacity(0.2),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Center(
                child: Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(score * 10),
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overall Score',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    '$score out of 10',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'Poppins',
      ),
    );
  }

  Widget _buildCategoryScoreRow(String category, dynamic score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              category,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getScoreColor(score * 10).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$score/10',
              style: TextStyle(
                color: _getScoreColor(score * 10),
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(String category, String recommendation) {
    return Card(
      elevation: 2,
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              recommendation,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionFeedbackCard(Map<String, dynamic> feedback) {
    final question = feedback['question'] ?? '';
    final answer = feedback['answer'] ?? '';
    final correct = feedback['correct'] ?? true;
    final explanation = feedback['explanation'] ?? '';

    return Card(
      elevation: 2,
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  correct ? Icons.check_circle : Icons.cancel,
                  color: correct ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Question',
                    style: TextStyle(
                      color: correct ? Colors.green : Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your Answer:',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              answer,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
            ),
            if (explanation.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'AI Feedback:',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                explanation,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}
