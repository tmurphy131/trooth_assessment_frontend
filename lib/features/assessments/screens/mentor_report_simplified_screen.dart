import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/mentor_report_v2.dart';
import '../../../services/api_service.dart';
import 'dart:developer' as dev;

/// Simplified mentor report with three-tier progressive disclosure:
/// TIER 1: Health score, 3 strengths, 3 gaps, 1 urgent flag, 1 primary action
/// TIER 2: Expandable sections for biblical knowledge, insights, conversation starters
/// TIER 3: Full details tab (accessible via button)
class MentorReportSimplifiedScreen extends StatefulWidget {
  final MentorReportV2 report;
  final String apprenticeName;
  final String? draftId; // Optional: needed for premium full report fetch
  const MentorReportSimplifiedScreen({
    super.key,
    required this.report,
    required this.apprenticeName,
    this.draftId,
  });

  @override
  State<MentorReportSimplifiedScreen> createState() => _MentorReportSimplifiedScreenState();
}

class _MentorReportSimplifiedScreenState extends State<MentorReportSimplifiedScreen> {
  bool _showBiblicalKnowledge = false;
  bool _showInsights = false;
  bool _showPlan = false;
  bool _isPremium = false;
  bool _checkingPremium = true;
  bool _loadingFullReport = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final isPremium = await ApiService().isPremiumUser();
      if (mounted) {
        setState(() {
          _isPremium = isPremium;
          _checkingPremium = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingPremium = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Mentor Report · ${widget.apprenticeName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Premium full report button with indicator
          if (_loadingFullReport)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
              ),
            )
          else
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.auto_awesome, color: Colors.amber),
                  tooltip: _isPremium ? 'View Full Report' : 'Premium Full Report',
                  onPressed: () => _showFullReport(context),
                ),
                if (!_isPremium && !_checkingPremium)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
              ],
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
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bandColor.withValues(alpha: 0.2), Colors.grey[900]!],
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
                        color: Colors.grey[400],
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
                  color: Colors.green.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade700),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.report.flags.green.first,
                        style: TextStyle(
                          color: Colors.green.shade200,
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
      color: Colors.red.shade900.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade700, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Urgent Attention Needed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade200,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    flag,
                    style: TextStyle(color: Colors.red.shade300, fontSize: 13),
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
      color: Colors.blue.shade900.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade700, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.track_changes, color: Colors.blue.shade400, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Priority Action This Week',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade200,
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
                color: Colors.blue.shade300,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              actionDescription,
              style: TextStyle(color: Colors.blue.shade200, fontSize: 14),
            ),
            if (scripture != null && scripture.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.menu_book, size: 16, color: Colors.blue.shade400),
                  const SizedBox(width: 4),
                  Text(
                    scripture,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade300,
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
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(item, style: TextStyle(fontSize: 13, color: Colors.grey[300]))),
                ],
              ),
            )),
            if (items.isEmpty)
              Text(
                'None identified',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
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
      color: Colors.grey[900],
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
                  Icon(icon, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1, color: Colors.grey[700]),
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
      return Text('No biblical knowledge data available.', style: TextStyle(color: Colors.grey[400]));
    }

    final knowledge = widget.report.biblicalKnowledge!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show percent score if available (v2.1 format)
        if (knowledge.percent != null) ...[
          Row(
            children: [
              Text(
                '${knowledge.percent!.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Biblical Knowledge Score',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        // Show weak topics if available
        if (knowledge.weakTopics != null && knowledge.weakTopics!.isNotEmpty) ...[
          Text(
            'Areas to Focus On:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.orange.shade400,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: knowledge.weakTopics!.map((topic) => Chip(
              label: Text(topic, style: TextStyle(fontSize: 12, color: Colors.orange.shade200)),
              backgroundColor: Colors.orange.shade900.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )).toList(),
          ),
          const SizedBox(height: 12),
        ],
        // Show study recommendation if available (v2.1 format)
        if (knowledge.studyRecommendation != null && knowledge.studyRecommendation!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade900.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade700),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.school, size: 18, color: Colors.blue.shade400),
                    const SizedBox(width: 8),
                    Text(
                      'Study Recommendation',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade300,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  knowledge.studyRecommendation!,
                  style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey[300]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Show summary if available (v2.0 format)
        if (knowledge.summary != null && knowledge.summary!.isNotEmpty) ...[
          Text(
            knowledge.summary!,
            style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[300]),
          ),
          const SizedBox(height: 16),
        ],
        // Show topic breakdown if available
        if (knowledge.topicBreakdown.isNotEmpty) ...[
          const Text(
            'Topic Breakdown:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
          ),
          const SizedBox(height: 8),
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[300]),
                  ),
                ),
                Text(
                  '${topic.correct}/${topic.total} ($percent%)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          );
        }),
        ],
      ],
    );
  }

  Widget _buildInsightsSection() {
    if (widget.report.openEndedInsights.isEmpty) {
      return Text('No insights available.', style: TextStyle(color: Colors.grey[400]));
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
                      color: _getLevelColor(insight.level).withValues(alpha: 0.3),
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
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                insight.observation,
                style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey[300]),
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
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
        ),
        const SizedBox(height: 8),
        ...widget.report.fourWeekPlan.rhythm.take(3).map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
              Expanded(child: Text(item, style: TextStyle(fontSize: 13, color: Colors.grey[300]))),
            ],
          ),
        )),
        const SizedBox(height: 16),
        const Text(
          'Checkpoints',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
        ),
        const SizedBox(height: 8),
        ...widget.report.fourWeekPlan.checkpoints.take(3).map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
              Expanded(child: Text(item, style: TextStyle(fontSize: 13, color: Colors.grey[300]))),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildConversationStarterCard(ColorScheme colorScheme) {
    return Card(
      elevation: 1,
      color: Colors.purple.shade900.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: Colors.purple.shade400, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Conversation Starter',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.purple.shade200),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.report.conversationStarters.first,
              style: TextStyle(fontSize: 14, color: Colors.purple.shade200),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullReport(BuildContext context) {
    // Show upgrade prompt for non-premium users
    if (!_isPremium) {
      _showPremiumUpgradeDialog(context);
      return;
    }

    // Premium users: Check if we have a draftId to fetch full report
    if (widget.draftId == null) {
      // Fallback to showing existing data if no draftId
      _showBasicFullReport(context);
      return;
    }

    // Fetch and show enhanced full report from API
    _fetchAndShowFullReport(context);
  }

  Future<void> _fetchAndShowFullReport(BuildContext context) async {
    if (_loadingFullReport) return;
    
    // Capture navigator and scaffold messenger before async gap
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    setState(() => _loadingFullReport = true);
    
    try {
      final response = await ApiService().fetchFullReport(draftId: widget.draftId!);
      
      if (!mounted) return;
      setState(() => _loadingFullReport = false);
      
      final report = response['report'] as Map<String, dynamic>?;
      final status = response['status'] as String?;
      
      dev.log('Full report fetched: status=$status, hasReport=${report != null}');
      
      if (report == null) {
        if (!mounted) return;
        navigator.push(
          MaterialPageRoute(
            builder: (_) => _buildBasicFullReportScaffold(),
          ),
        );
        return;
      }
      
      // Navigate to premium full report screen using captured navigator
      navigator.push(
        MaterialPageRoute(
          builder: (_) => _PremiumFullReportScreen(
            report: report,
            apprenticeName: widget.apprenticeName,
            isCached: status == 'cached',
          ),
        ),
      );
    } on PremiumRequiredException {
      if (!mounted) return;
      setState(() => _loadingFullReport = false);
      _showPremiumUpgradeDialogSync(navigator);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFullReport = false);
      dev.log('Error fetching full report: $e');
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error loading full report: $e'), backgroundColor: Colors.red),
      );
      // Fallback to basic report
      navigator.push(
        MaterialPageRoute(
          builder: (_) => _buildBasicFullReportScaffold(),
        ),
      );
    }
  }

  /// Builds the basic full report scaffold without needing BuildContext
  Widget _buildBasicFullReportScaffold() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Full Detailed Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('All Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            ...widget.report.openEndedInsights.map((i) => Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('Level: ${i.level}', style: TextStyle(color: Colors.grey[400])),
                    const SizedBox(height: 8),
                    if (i.evidence.isNotEmpty) ...[
                      Text(i.evidence, style: TextStyle(color: Colors.grey[300])),
                      const SizedBox(height: 8),
                    ],
                    Text(i.observation, style: TextStyle(color: Colors.grey[300])),
                    if (i.nextStep.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Next Steps:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.amber)),
                      Text('• ${i.nextStep}', style: TextStyle(color: Colors.grey[300])),
                    ],
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  /// Shows premium upgrade dialog using NavigatorState instead of BuildContext
  void _showPremiumUpgradeDialogSync(NavigatorState navigator) {
    navigator.push(
      DialogRoute(
        context: navigator.context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Premium Feature'),
          content: const Text(
            'Full detailed reports with AI-powered insights are available '
            'for Premium subscribers.\n\n'
            'Upgrade now to unlock:\n'
            '• Deep dive analysis on each category\n'
            '• Personalized conversation guides\n'
            '• Growth pathway recommendations\n'
            '• Biblical knowledge detailed breakdown',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Maybe Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // TODO: Navigate to subscription screen
              },
              child: const Text('Upgrade to Premium'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBasicFullReport(BuildContext context) {
    // Fallback: show existing report data (non-enhanced)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _buildBasicFullReportScaffold(),
      ),
    );
  }

  void _showPremiumUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber.shade700),
            const SizedBox(width: 8),
            const Text('Premium Feature'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unlock the Full Report for deeper insights:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildPremiumFeatureRow(Icons.analytics, 'Detailed AI Analysis'),
            _buildPremiumFeatureRow(Icons.psychology, 'Deep Spiritual Insights'),
            _buildPremiumFeatureRow(Icons.menu_book, 'Resource Recommendations'),
            _buildPremiumFeatureRow(Icons.chat, 'Personalized Mentoring Tips'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Premium subscription coming soon!',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Premium subscriptions coming soon!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Notify Me'),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.amber.shade700),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
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

/// Premium full report screen showing enhanced AI-generated insights
class _PremiumFullReportScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  final String apprenticeName;
  final bool isCached;

  const _PremiumFullReportScreen({
    required this.report,
    required this.apprenticeName,
    this.isCached = false,
  });

  @override
  Widget build(BuildContext context) {
    // Extract sections from the premium report
    // The API returns: strengths_deep_dive, gaps_deep_dive, conversation_guide, biblical_knowledge_analysis
    final strengthsDeepDive = report['strengths_deep_dive'] as List<dynamic>?;
    final gapsDeepDive = report['gaps_deep_dive'] as List<dynamic>?;
    final execSummary = report['executive_summary'] as Map<String, dynamic>?;
    final conversationGuide = report['conversation_guide'] as Map<String, dynamic>?;
    final biblicalKnowledge = report['biblical_knowledge_analysis'] as Map<String, dynamic>?;
    final spiritualFormation = report['spiritual_formation_insights'] as List<dynamic>?;
    final meta = report['_meta'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Premium Full Report', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isCached)
            Tooltip(
              message: 'Loaded from cache',
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(Icons.cached, color: Colors.amber.shade300),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Premium badge header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade900.withValues(alpha: 0.5), Colors.amber.shade900.withValues(alpha: 0.2)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium Report for $apprenticeName',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade200,
                        ),
                      ),
                      if (meta != null)
                        Text(
                          'Generated by ${meta['model'] ?? 'AI'} • ${meta['latency_ms'] ?? 0}ms',
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade400),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Executive Summary
          if (execSummary != null) ...[
            _buildSectionHeader('Executive Summary', Icons.summarize),
            const SizedBox(height: 12),
            _buildExecutiveSummary(execSummary),
            const SizedBox(height: 20),
          ],

          // Strengths Deep Dive
          if (strengthsDeepDive != null && strengthsDeepDive.isNotEmpty) ...[
            _buildSectionHeader('Strengths Deep Dive', Icons.thumb_up),
            const SizedBox(height: 12),
            ...strengthsDeepDive.map((s) => _buildStrengthDeepDiveCard(s as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],

          // Gaps Deep Dive (with growth pathways)
          if (gapsDeepDive != null && gapsDeepDive.isNotEmpty) ...[
            _buildSectionHeader('Growth Areas Deep Dive', Icons.trending_up),
            const SizedBox(height: 12),
            ...gapsDeepDive.map((g) => _buildGapDeepDiveCard(g as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],

          // Conversation Guide
          if (conversationGuide != null) ...[
            _buildSectionHeader('Mentor Conversation Guide', Icons.chat),
            const SizedBox(height: 12),
            _buildConversationGuideSection(conversationGuide),
            const SizedBox(height: 20),
          ],

          // Biblical Knowledge Deep Dive
          if (biblicalKnowledge != null) ...[
            _buildSectionHeader('Biblical Knowledge Analysis', Icons.menu_book),
            const SizedBox(height: 12),
            _buildBiblicalKnowledgeSection(biblicalKnowledge),
            const SizedBox(height: 20),
          ],

          // Spiritual Formation Insights
          if (spiritualFormation != null && spiritualFormation.isNotEmpty) ...[
            _buildSectionHeader('Spiritual Formation Insights', Icons.self_improvement),
            const SizedBox(height: 12),
            ...spiritualFormation.map((s) => _buildSpiritualFormationCard(s as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],

          // Fallback: show raw JSON if structure is unexpected
          if (strengthsDeepDive == null && gapsDeepDive == null && conversationGuide == null) ...[
            _buildSectionHeader('Report Data', Icons.data_object),
            const SizedBox(height: 12),
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _prettyPrintJson(report),
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey[300]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.amber),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildConversationGuideSection(Map<String, dynamic> guide) {
    final sessions = guide['sessions'] as List<dynamic>? ?? [];
    final openingQuestions = guide['opening_questions'] as List<dynamic>? ?? [];
    final topics = guide['suggested_topics'] as List<dynamic>? ?? [];

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (openingQuestions.isNotEmpty) ...[
              const Text('Opening Questions:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              ...openingQuestions.map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $q', style: TextStyle(fontSize: 13, color: Colors.grey[300])),
              )),
              const SizedBox(height: 12),
            ],
            if (sessions.isNotEmpty) ...[
              const Text('Session Structure:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              ...sessions.asMap().entries.map((entry) {
                final session = entry.value as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.blue.shade900,
                        child: Text('${entry.key + 1}', style: TextStyle(fontSize: 11, color: Colors.blue.shade200)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(session['focus'] ?? 'Session ${entry.key + 1}',
                                style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white)),
                            if (session['goal'] != null)
                              Text(session['goal'], style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (topics.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Topics to Explore:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: topics.map((t) => Chip(
                  label: Text(t.toString(), style: TextStyle(fontSize: 12, color: Colors.blue.shade200)),
                  backgroundColor: Colors.blue.shade900.withValues(alpha: 0.5),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBiblicalKnowledgeSection(Map<String, dynamic> knowledge) {
    final topicBreakdown = knowledge['topic_breakdown'] as List<dynamic>? ?? [];
    final weakAreas = knowledge['weak_areas'] as List<dynamic>? ?? [];
    final studyPlan = knowledge['study_plan'] as Map<String, dynamic>?;

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (topicBreakdown.isNotEmpty) ...[
              const Text('Topic Performance:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              ...topicBreakdown.take(5).map((topic) {
                if (topic is Map) {
                  final name = topic['topic'] ?? topic['name'] ?? 'Topic';
                  final score = topic['score'] ?? topic['percent'] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(name.toString(), style: TextStyle(fontSize: 13, color: Colors.grey[300])),
                            Text('$score%', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: (score is num ? score : 0) / 100,
                          backgroundColor: Colors.grey.shade800,
                          valueColor: AlwaysStoppedAnimation(
                            score > 70 ? Colors.green : score > 40 ? Colors.orange : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
            if (weakAreas.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Areas Needing Study:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: weakAreas.map((a) => Chip(
                  label: Text(a.toString(), style: TextStyle(fontSize: 11, color: Colors.orange.shade200)),
                  backgroundColor: Colors.orange.shade900.withValues(alpha: 0.3),
                  avatar: Icon(Icons.warning_amber, size: 14, color: Colors.orange.shade400),
                )).toList(),
              ),
            ],
            if (studyPlan != null) ...[
              const SizedBox(height: 12),
              const Text('Recommended Study Plan:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              if (studyPlan['weeks'] != null)
                ...(studyPlan['weeks'] as List<dynamic>).asMap().entries.map((e) {
                  final week = e.value as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Week ${e.key + 1}:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.amber)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(week['focus'] ?? week.toString(), style: TextStyle(fontSize: 13, color: Colors.grey[300]))),
                      ],
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }

  String _prettyPrintJson(Map<String, dynamic> json) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (e) {
      return json.toString();
    }
  }

  Widget _buildExecutiveSummary(Map<String, dynamic> summary) {
    final healthScore = summary['health_score'] ?? 0;
    final healthBand = summary['health_band'] ?? 'Unknown';
    final oneLiner = summary['one_liner'] ?? '';
    final trajectory = summary['trajectory'] ?? 'stable';
    final trajectoryNote = summary['trajectory_note'] ?? '';

    return Card(
      color: Colors.amber.shade900.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade800,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$healthScore',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade100,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(healthBand, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                      Row(
                        children: [
                          Icon(
                            trajectory == 'upward' ? Icons.trending_up
                              : trajectory == 'downward' ? Icons.trending_down
                              : Icons.trending_flat,
                            size: 16,
                            color: trajectory == 'upward' ? Colors.green : trajectory == 'downward' ? Colors.red : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(trajectory.toString().toUpperCase(),
                            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (oneLiner.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(oneLiner, style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey[300])),
            ],
            if (trajectoryNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(trajectoryNote, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthDeepDiveCard(Map<String, dynamic> strength) {
    final area = strength['area'] ?? 'Strength';
    final summary = strength['summary'] ?? '';
    final evidence = (strength['evidence'] as List<dynamic>?) ?? [];
    final maturityIndicator = strength['spiritual_maturity_indicator'] ?? '';
    final leverage = strength['how_to_leverage'] ?? '';
    final celebration = strength['celebration_talking_point'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.green.shade900.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.green.shade400),
                const SizedBox(width: 8),
                Expanded(child: Text(area, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade200))),
              ],
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(summary, style: TextStyle(fontSize: 14, color: Colors.grey[300])),
            ],
            if (evidence.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Evidence:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[400])),
              const SizedBox(height: 4),
              ...evidence.map((e) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: Colors.green.shade400)),
                    Expanded(child: Text(e.toString(), style: TextStyle(fontSize: 13, color: Colors.grey[300]))),
                  ],
                ),
              )),
            ],
            if (maturityIndicator.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📖 Spiritual Insight', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.green.shade300)),
                    const SizedBox(height: 4),
                    Text(maturityIndicator, style: TextStyle(fontSize: 13, color: Colors.grey[300])),
                  ],
                ),
              ),
            ],
            if (leverage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('How to Leverage:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[400])),
              const SizedBox(height: 4),
              Text(leverage, style: TextStyle(fontSize: 13, color: Colors.grey[300])),
            ],
            if (celebration.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💬 Celebration Talking Point', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.amber.shade300)),
                    const SizedBox(height: 4),
                    Text('"$celebration"', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey[300])),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGapDeepDiveCard(Map<String, dynamic> gap) {
    final area = gap['area'] ?? 'Growth Area';
    final summary = gap['summary'] ?? '';
    final severity = gap['severity'] ?? 'moderate';
    final rootCause = gap['root_cause_analysis'] ?? '';
    final evidence = (gap['evidence'] as List<dynamic>?) ?? [];
    final biblical = gap['biblical_perspective'] ?? '';
    final whyMatters = gap['why_it_matters'] ?? '';
    final pathway = gap['growth_pathway'] as Map<String, dynamic>?;

    final severityColor = severity == 'critical' ? Colors.red
        : severity == 'moderate' ? Colors.orange
        : Colors.yellow;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: severityColor.shade400),
                const SizedBox(width: 8),
                Expanded(child: Text(area, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.shade900.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(severity.toString().toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: severityColor.shade300)),
                ),
              ],
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(summary, style: TextStyle(fontSize: 14, color: Colors.grey[300])),
            ],
            if (rootCause.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Root Cause:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[400])),
              const SizedBox(height: 4),
              Text(rootCause, style: TextStyle(fontSize: 13, color: Colors.grey[300])),
            ],
            if (evidence.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Evidence:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[400])),
              const SizedBox(height: 4),
              ...evidence.map((e) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: severityColor.shade400)),
                    Expanded(child: Text(e.toString(), style: TextStyle(fontSize: 13, color: Colors.grey[300]))),
                  ],
                ),
              )),
            ],
            if (biblical.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📖 Biblical Perspective', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.blue.shade300)),
                    const SizedBox(height: 4),
                    Text(biblical, style: TextStyle(fontSize: 13, color: Colors.grey[300])),
                  ],
                ),
              ),
            ],
            if (whyMatters.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Why It Matters:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[400])),
              const SizedBox(height: 4),
              Text(whyMatters, style: TextStyle(fontSize: 13, color: Colors.grey[300])),
            ],
            if (pathway != null) ...[
              const SizedBox(height: 16),
              const Text('🎯 Growth Pathway', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
              const SizedBox(height: 8),
              _buildGrowthPhase(pathway['phase_1_weeks_1_4'] as Map<String, dynamic>?, 'Weeks 1-4', Colors.green),
              _buildGrowthPhase(pathway['phase_2_weeks_5_8'] as Map<String, dynamic>?, 'Weeks 5-8', Colors.blue),
              _buildGrowthPhase(pathway['phase_3_weeks_9_12'] as Map<String, dynamic>?, 'Weeks 9-12', Colors.purple),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthPhase(Map<String, dynamic>? phase, String label, MaterialColor color) {
    if (phase == null) return const SizedBox.shrink();
    final goal = phase['goal'] ?? '';
    final activities = (phase['activities'] as List<dynamic>?) ?? [];
    final metric = phase['success_metric'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.shade800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.shade200)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(goal, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey[300]))),
            ],
          ),
          if (activities.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...activities.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_box_outline_blank, size: 14, color: color.shade400),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a.toString(), style: TextStyle(fontSize: 12, color: Colors.grey[300]))),
                ],
              ),
            )),
          ],
          if (metric.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.flag, size: 14, color: color.shade400),
                const SizedBox(width: 4),
                Expanded(child: Text('Success: $metric', style: TextStyle(fontSize: 11, color: color.shade300))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpiritualFormationCard(Map<String, dynamic> insight) {
    final category = insight['category'] ?? 'Category';
    final level = insight['current_level'] ?? 'Unknown';
    final observation = insight['detailed_observation'] ?? '';
    final markersPresent = (insight['maturity_markers_present'] as List<dynamic>?) ?? [];
    final markersMissing = (insight['maturity_markers_missing'] as List<dynamic>?) ?? [];
    final questions = (insight['mentor_discussion_questions'] as List<dynamic>?) ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.purple.shade400),
                const SizedBox(width: 8),
                Expanded(child: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade900.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(level, style: TextStyle(fontSize: 12, color: Colors.purple.shade300)),
                ),
              ],
            ),
            if (observation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(observation, style: TextStyle(fontSize: 13, color: Colors.grey[300])),
            ],
            if (markersPresent.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('✓ Maturity Markers Present:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.green.shade400)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: markersPresent.map((m) => Chip(
                  label: Text(m.toString(), style: TextStyle(fontSize: 11, color: Colors.green.shade200)),
                  backgroundColor: Colors.green.shade900.withValues(alpha: 0.3),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ],
            if (markersMissing.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('○ Markers to Develop:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.orange.shade400)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: markersMissing.map((m) => Chip(
                  label: Text(m.toString(), style: TextStyle(fontSize: 11, color: Colors.orange.shade200)),
                  backgroundColor: Colors.orange.shade900.withValues(alpha: 0.3),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ],
            if (questions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Discussion Questions:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[400])),
              const SizedBox(height: 8),
              ...questions.map((q) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(8),
                  border: Border(left: BorderSide(color: Colors.purple.shade400, width: 3)),
                ),
                child: Text('"$q"', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey[300])),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
