import 'package:flutter/material.dart';
import '../models/mentor_report_v2.dart';

/// Simplified mentor report with three-tier progressive disclosure:
/// TIER 1: Health score, 3 strengths, 3 gaps, 1 urgent flag, 1 primary action
/// TIER 2: Expandable sections for biblical knowledge, insights, conversation starters
/// TIER 3: Full details tab (accessible via button)
class MentorReportSimplifiedScreen extends StatefulWidget {
  final MentorReportV2 report;
  final String apprenticeName;
  const MentorReportSimplifiedScreen({
    super.key,
    required this.report,
    required this.apprenticeName,
  });

  @override
  State<MentorReportSimplifiedScreen> createState() => _MentorReportSimplifiedScreenState();
}

class _MentorReportSimplifiedScreenState extends State<MentorReportSimplifiedScreen> {
  bool _showBiblicalKnowledge = false;
  bool _showInsights = false;
  bool _showPlan = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Mentor Report · ${widget.apprenticeName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.article_outlined),
            tooltip: 'View Full Report',
            onPressed: () => _showFullReport(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // TIER 1: Health Score Card
          _buildHealthScoreCard(colorScheme),
          const SizedBox(height: 16),

          // Urgent Flags (if any)
          if (widget.report.flags.red.isNotEmpty) ...[
            _buildUrgentFlag(widget.report.flags.red.first, colorScheme),
            const SizedBox(height: 16),
          ],

          // Priority Action Card
          _buildPriorityActionCard(colorScheme),
          const SizedBox(height: 16),

          // Top Strengths & Gaps
          _buildStrengthsGapsRow(colorScheme),
          const SizedBox(height: 24),

          // TIER 2: Expandable Sections
          _buildExpandableSection(
            title: 'Biblical Knowledge',
            icon: Icons.menu_book,
            isExpanded: _showBiblicalKnowledge,
            onTap: () => setState(() => _showBiblicalKnowledge = !_showBiblicalKnowledge),
            child: _buildBiblicalKnowledgeSection(),
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),

          _buildExpandableSection(
            title: 'Spiritual Insights',
            icon: Icons.lightbulb_outline,
            isExpanded: _showInsights,
            onTap: () => setState(() => _showInsights = !_showInsights),
            child: _buildInsightsSection(),
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),

          _buildExpandableSection(
            title: 'Four-Week Plan',
            icon: Icons.calendar_month,
            isExpanded: _showPlan,
            onTap: () => setState(() => _showPlan = !_showPlan),
            child: _buildFourWeekPlanSection(),
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 24),

          // Conversation Starter Card
          if (widget.report.conversationStarters.isNotEmpty) ...[
            _buildConversationStarterCard(colorScheme),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthScoreCard(ColorScheme colorScheme) {
    final overallPercent = widget.report.snapshot.overallMcPercent;
    final band = widget.report.snapshot.knowledgeBand;
    
    Color bandColor = _getBandColor(band);
    IconData bandIcon = _getBandIcon(band);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bandColor.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
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
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${overallPercent.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: bandColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Icon(bandIcon, color: bandColor, size: 32),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: bandColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    band,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.report.flags.green.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.report.flags.green.first,
                        style: TextStyle(
                          color: Colors.green.shade900,
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

  Widget _buildUrgentFlag(String flag, ColorScheme colorScheme) {
    return Card(
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade300, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Urgent Attention Needed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    flag,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityActionCard(ColorScheme colorScheme) {
    // Extract first action from insights
    String actionTitle = 'Continue spiritual growth';
    String actionDescription = 'Focus on consistent practice';
    String? scripture;

    if (widget.report.openEndedInsights.isNotEmpty) {
      final firstInsight = widget.report.openEndedInsights.first;
      if (firstInsight.nextStep.isNotEmpty) {
        actionTitle = 'Focus on ${firstInsight.title}';
        actionDescription = firstInsight.nextStep;
        scripture = firstInsight.evidence; // evidence field may contain scripture
      }
    }

    return Card(
      elevation: 2,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade300, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.track_changes, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Priority Action This Week',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              actionTitle,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              actionDescription,
              style: TextStyle(color: Colors.blue.shade900, fontSize: 14),
            ),
            if (scripture != null && scripture.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.menu_book, size: 16, color: Colors.blue.shade600),
                  const SizedBox(width: 4),
                  Text(
                    scripture,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthsGapsRow(ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildListCard(
            title: 'Top Strengths',
            icon: Icons.star,
            items: widget.report.snapshot.topStrengths.take(3).toList(),
            color: Colors.green,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildListCard(
            title: 'Top Gaps',
            icon: Icons.trending_up,
            items: widget.report.snapshot.topGaps.take(3).toList(),
            color: Colors.orange,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }

  Widget _buildListCard({
    required String title,
    required IconData icon,
    required List<String> items,
    required Color color,
    required ColorScheme colorScheme,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),
            if (items.isEmpty)
              Text(
                'None identified',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withOpacity(0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
    required ColorScheme colorScheme,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBiblicalKnowledgeSection() {
    if (widget.report.biblicalKnowledge == null) {
      return const Text('No biblical knowledge data available.');
    }

    final knowledge = widget.report.biblicalKnowledge!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (knowledge.summary != null && knowledge.summary!.isNotEmpty)
          Text(
            knowledge.summary!,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        if (knowledge.summary != null && knowledge.summary!.isNotEmpty)
          const SizedBox(height: 16),
        if (knowledge.summary == null || knowledge.summary!.isEmpty)
          const Text(
            'Biblical knowledge overview based on assessment responses.',
            style: TextStyle(fontSize: 14, height: 1.5, fontStyle: FontStyle.italic),
          ),
        const SizedBox(height: 16),
        ...knowledge.topicBreakdown.take(5).map((topic) {
          final percent = topic.total > 0 
              ? (topic.correct / topic.total * 100).toStringAsFixed(0) 
              : '0';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    topic.topic,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${topic.correct}/${topic.total} ($percent%)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInsightsSection() {
    if (widget.report.openEndedInsights.isEmpty) {
      return const Text('No insights available.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.report.openEndedInsights.take(3).map((insight) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getLevelColor(insight.level).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      insight.level,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getLevelColor(insight.level),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                insight.observation,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFourWeekPlanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weekly Rhythm',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ...widget.report.fourWeekPlan.rhythm.take(3).map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
            ],
          ),
        )),
        const SizedBox(height: 16),
        const Text(
          'Checkpoints',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ...widget.report.fourWeekPlan.checkpoints.take(3).map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildConversationStarterCard(ColorScheme colorScheme) {
    return Card(
      elevation: 1,
      color: Colors.purple.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: Colors.purple.shade700, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Conversation Starter',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.report.conversationStarters.first,
              style: TextStyle(fontSize: 14, color: Colors.purple.shade900),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullReport(BuildContext context) {
    // Navigate to existing full report screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Full Detailed Report')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('All Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...widget.report.openEndedInsights.map((i) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Level: ${i.level}'),
                        const SizedBox(height: 8),
                        if (i.evidence.isNotEmpty) ...[
                          Text(i.evidence),
                          const SizedBox(height: 8),
                        ],
                        Text(i.observation),
                        if (i.nextStep.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Next Steps:', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text('• ${i.nextStep}'),
                        ],
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 24),
                const Text('Recommended Resources', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...widget.report.recommendedResources.map((r) => ListTile(
                  title: Text(r.title),
                  subtitle: Text('${r.why} (${r.type})'),
                  leading: const Icon(Icons.book),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBandColor(String band) {
    switch (band.toLowerCase()) {
      case 'excellent':
      case 'flourishing':
        return Colors.green.shade700;
      case 'good':
      case 'maturing':
        return Colors.blue.shade700;
      case 'average':
      case 'stable':
        return Colors.orange.shade700;
      case 'needs improvement':
      case 'developing':
        return Colors.deepOrange.shade700;
      case 'significant study':
      case 'beginning':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getBandIcon(String band) {
    switch (band.toLowerCase()) {
      case 'excellent':
      case 'flourishing':
        return Icons.emoji_events;
      case 'good':
      case 'maturing':
        return Icons.trending_up;
      case 'average':
      case 'stable':
        return Icons.horizontal_rule;
      case 'needs improvement':
      case 'developing':
        return Icons.trending_down;
      case 'significant study':
      case 'beginning':
        return Icons.warning_amber;
      default:
        return Icons.help_outline;
    }
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'flourishing':
        return Colors.green.shade700;
      case 'maturing':
        return Colors.blue.shade700;
      case 'stable':
        return Colors.orange.shade700;
      case 'developing':
        return Colors.deepOrange.shade700;
      case 'beginning':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}
