part of 'mentor_report_simplified_screen.dart';

// Widget builders for _MentorReportSimplifiedScreenState. State and logic live in mentor_report_simplified_screen.dart.
extension _MentorReportSimplifiedScreenStateWidgets on _MentorReportSimplifiedScreenState {
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
}
