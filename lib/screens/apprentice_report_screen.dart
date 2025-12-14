import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Screen for apprentices to view their own assessment report.
/// Uses simplified report data structure similar to mentor report.
class ApprenticeReportScreen extends StatefulWidget {
  final String assessmentId;
  final String? title;
  
  const ApprenticeReportScreen({
    super.key,
    required this.assessmentId,
    this.title,
  });

  @override
  State<ApprenticeReportScreen> createState() => _ApprenticeReportScreenState();
}

class _ApprenticeReportScreenState extends State<ApprenticeReportScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() { _loading = true; _error = null; });
    try {
      final report = await _api.getMySimplifiedReport(widget.assessmentId);
      if (mounted) {
        setState(() {
          _report = report;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Failed to load report: $e'; _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? _report?['template_name'] ?? 'Assessment Report';
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.amber),
            onPressed: _loadReport,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _error != null
              ? _errorView()
              : _contentView(),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Poppins'), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReport,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: const Text('Retry', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentView() {
    if (_report == null) return const SizedBox.shrink();
    
    final healthScore = _report!['health_score'] ?? 0;
    final healthBand = _report!['health_band'] ?? 'Unknown';
    final strengths = (_report!['strengths'] as List<dynamic>? ?? []).cast<String>();
    final gaps = (_report!['gaps'] as List<dynamic>? ?? []).cast<String>();
    final priorityAction = _report!['priority_action'] as Map<String, dynamic>? ?? {};
    final insights = (_report!['insights'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final flags = _report!['flags'] as Map<String, dynamic>? ?? {};
    final redFlags = (flags['red'] as List<dynamic>? ?? []).cast<String>();
    final completedAt = _report!['completed_at']?.toString();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Health Score Card
          _buildHealthScoreCard(healthScore, healthBand),
          const SizedBox(height: 16),
          
          // Red Flags (if any)
          if (redFlags.isNotEmpty) ...[
            _buildRedFlagCard(redFlags.first),
            const SizedBox(height: 16),
          ],
          
          // Priority Action
          if (priorityAction.isNotEmpty) ...[
            _buildPriorityActionCard(priorityAction),
            const SizedBox(height: 16),
          ],
          
          // Strengths & Gaps
          if (strengths.isNotEmpty || gaps.isNotEmpty) ...[
            _buildStrengthsGapsSection(strengths, gaps),
            const SizedBox(height: 16),
          ],
          
          // Insights
          if (insights.isNotEmpty) ...[
            _buildInsightsSection(insights),
            const SizedBox(height: 16),
          ],
          
          // Completion Date
          if (completedAt != null) ...[
            _buildCompletedAtSection(completedAt),
          ],
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHealthScoreCard(int score, String band) {
    final color = _getBandColor(band);
    
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health Score',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$score%',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Icon(_getBandIcon(band), color: color, size: 32),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    band,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedFlagCard(String flag) {
    return Card(
      color: Colors.red[900]!.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red[400]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[400], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                flag,
                style: TextStyle(
                  color: Colors.red[100],
                  fontFamily: 'Poppins',
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityActionCard(Map<String, dynamic> action) {
    final title = action['title'] ?? 'Next Step';
    final description = action['description'] ?? '';
    final scripture = action['scripture'] ?? '';
    final steps = (action['steps'] as List<dynamic>? ?? []).cast<String>();
    
    return Card(
      color: Colors.amber.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.withOpacity(0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Priority Action',
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
                fontSize: 16,
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontFamily: 'Poppins',
                  fontSize: 14,
                ),
              ),
            ],
            if (steps.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...steps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontFamily: 'Poppins',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
            if (scripture.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book, color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        scripture,
                        style: TextStyle(
                          color: Colors.amber[100],
                          fontFamily: 'Poppins',
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthsGapsSection(List<String> strengths, List<String> gaps) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Strengths
            if (strengths.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.thumb_up, color: Colors.green[400], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Your Strengths',
                    style: TextStyle(
                      color: Colors.green[400],
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...strengths.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check, color: Colors.green[400], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
            
            if (strengths.isNotEmpty && gaps.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.grey[700]),
              const SizedBox(height: 12),
            ],
            
            // Gaps
            if (gaps.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.orange[400], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Areas to Grow',
                    style: TextStyle(
                      color: Colors.orange[400],
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...gaps.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.arrow_forward, color: Colors.orange[400], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        g,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsSection(List<Map<String, dynamic>> insights) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Spiritual Insights',
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...insights.take(5).map((insight) {
              final category = insight['category'] ?? '';
              final level = insight['level'] ?? '';
              final observation = insight['observation'] ?? '';
              final nextStep = insight['next_step'] ?? '';
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getLevelColor(level).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: _getLevelColor(level),
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (level.isNotEmpty)
                            Text(
                              level,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontFamily: 'Poppins',
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      if (observation.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          observation,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (nextStep.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.arrow_right, color: Colors.amber, size: 16),
                            Expanded(
                              child: Text(
                                nextStep,
                                style: TextStyle(
                                  color: Colors.amber[200],
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedAtSection(String iso) {
    String dateStr;
    try {
      final d = DateTime.parse(iso).toLocal();
      final hour = d.hour;
      final minute = d.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} at $hour12:$minute $period';
    } catch (_) {
      dateStr = iso;
    }
    
    return Center(
      child: Text(
        'Completed $dateStr',
        style: TextStyle(
          color: Colors.grey[500],
          fontFamily: 'Poppins',
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getBandColor(String band) {
    switch (band.toLowerCase()) {
      case 'excellent':
        return Colors.green;
      case 'maturing':
        return Colors.blue;
      case 'growing':
        return Colors.amber;
      case 'developing':
        return Colors.orange;
      case 'beginning':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getBandIcon(String band) {
    switch (band.toLowerCase()) {
      case 'excellent':
        return Icons.emoji_events;
      case 'maturing':
        return Icons.trending_up;
      case 'growing':
        return Icons.eco;
      case 'developing':
        return Icons.spa;
      case 'beginning':
        return Icons.grass;
      default:
        return Icons.help_outline;
    }
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'strong':
        return Colors.green;
      case 'moderate':
        return Colors.amber;
      case 'developing':
        return Colors.orange;
      case 'beginning':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
