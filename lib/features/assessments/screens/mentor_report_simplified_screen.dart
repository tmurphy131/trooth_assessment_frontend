import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/mentor_report_v2.dart';
import '../../../services/api_service.dart';
import '../../../screens/subscription_screen.dart';
import 'dart:developer' as dev;
import '../../../utils/errors.dart';

part 'mentor_report_simplified_screen_widgets.dart';
part 'mentor_report_premium_screen.dart';

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
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
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
        SnackBar(content: Text('Error loading full report: ${friendlyError(e)}'), backgroundColor: Colors.red),
      );
      // Fallback to basic report
      navigator.push(
        MaterialPageRoute(
          builder: (_) => _buildBasicFullReportScaffold(),
        ),
      );
    }
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
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                // Navigate to subscription screen
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
                if (result == true && mounted) {
                  setState(() => _isPremium = true);
                }
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
                      'Upgrade to unlock all premium features!',
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
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
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
