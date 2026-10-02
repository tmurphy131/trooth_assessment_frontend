part of 'mentor_submission_detail_screen.dart';

// Full-screen premium report and PDF preview opened from MentorSubmissionDetailScreen.

/// PDF Preview screen with share functionality
class _PdfPreviewScreen extends StatelessWidget {
  final String filePath;
  final String fileName;
  final String apprenticeName;

  const _PdfPreviewScreen({
    required this.filePath,
    required this.fileName,
    required this.apprenticeName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Report Preview', style: TextStyle(color: Colors.amber.shade300)),
        iconTheme: IconThemeData(color: Colors.amber.shade300),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () => _shareFile(context),
            tooltip: 'Share',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.picture_as_pdf, size: 80, color: Colors.red.shade400),
              ),
              const SizedBox(height: 24),
              Text(
                'T[root]H Mentor Report',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade300,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                apprenticeName,
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                fileName,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade300, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'PDF ready for export',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap "Share" to save to Files, Notes, iCloud Drive, send via AirDrop, or open in another app.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _shareFile(context),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share PDF', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openInExternalApp(context),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open in Another App'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.grey.shade600),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareFile(BuildContext context) async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null 
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100);
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'application/pdf')],
        subject: 'T[root]H Report - $apprenticeName',
        text: 'Mentor Report for $apprenticeName',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share error: ${friendlyError(e)}')));
    }
  }

  Future<void> _openInExternalApp(BuildContext context) async {
    // Use share sheet which allows "Open in..." on iOS
    try {
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null 
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100);
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'application/pdf')],
        subject: 'T[root]H Report - $apprenticeName',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${friendlyError(e)}')));
    }
  }
}

/// Full-screen premium report viewer

/// Full-screen premium report viewer
class _PremiumReportFullScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  final String apprenticeName;
  final bool cached;

  const _PremiumReportFullScreen({
    required this.report,
    required this.apprenticeName,
    this.cached = false,
  });

  @override
  Widget build(BuildContext context) {
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
        title: Text('Premium Report · $apprenticeName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Premium badge header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.amber.shade100, Colors.amber.shade50]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Premium Report', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                      Row(
                        children: [
                          if (cached) ...[
                            Icon(Icons.cached, size: 12, color: Colors.amber.shade700),
                            const SizedBox(width: 4),
                            Text('Instant load', style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
                          ],
                          if (meta != null) ...[
                            if (cached) Text(' • ', style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
                            Text('Generated by ${meta['model'] ?? 'AI'}', style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
                          ],
                        ],
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
            _sectionHeader('Executive Summary', Icons.summarize),
            const SizedBox(height: 12),
            _buildExecutiveSummaryCard(execSummary),
            const SizedBox(height: 20),
          ],

          // Strengths Deep Dive
          if (strengthsDeepDive != null && strengthsDeepDive.isNotEmpty) ...[
            _sectionHeader('Strengths Deep Dive', Icons.thumb_up),
            const SizedBox(height: 12),
            ...strengthsDeepDive.map((s) => _buildStrengthCard(s as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],

          // Growth Opportunities
          if (gapsDeepDive != null && gapsDeepDive.isNotEmpty) ...[
            _sectionHeader('Growth Opportunities', Icons.trending_up),
            const SizedBox(height: 12),
            ...gapsDeepDive.map((g) => _buildGapCard(g as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],

          // Conversation Guide
          if (conversationGuide != null) ...[
            _sectionHeader('Conversation Guide', Icons.chat),
            const SizedBox(height: 12),
            _buildConversationGuideCard(conversationGuide),
            const SizedBox(height: 20),
          ],

          // Biblical Knowledge
          if (biblicalKnowledge != null) ...[
            _sectionHeader('Biblical Knowledge', Icons.menu_book),
            const SizedBox(height: 12),
            _buildBiblicalKnowledgeCard(biblicalKnowledge),
            const SizedBox(height: 20),
          ],

          // Spiritual Formation
          if (spiritualFormation != null && spiritualFormation.isNotEmpty) ...[
            _sectionHeader('Spiritual Formation', Icons.self_improvement),
            const SizedBox(height: 12),
            ...spiritualFormation.map((s) => _buildFormationCard(s as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.amber),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildExecutiveSummaryCard(Map<String, dynamic> summary) {
    final healthScore = summary['health_score'];
    final healthBand = summary['health_band'] as String?;
    final oneLiner = summary['one_liner'] as String?;
    final trajectory = summary['trajectory'] as String?;
    final trajectoryNote = summary['trajectory_note'] as String?;

    Color trajectoryColor = Colors.grey;
    IconData trajectoryIcon = Icons.trending_flat;
    if (trajectory == 'upward') {
      trajectoryColor = Colors.green;
      trajectoryIcon = Icons.trending_up;
    } else if (trajectory == 'downward') {
      trajectoryColor = Colors.red;
      trajectoryIcon = Icons.trending_down;
    }

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (healthScore != null) ...[
              Row(
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amber.withValues(alpha: 0.2),
                      border: Border.all(color: Colors.amber, width: 3),
                    ),
                    alignment: Alignment.center,
                    child: Text('$healthScore', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (healthBand != null) Text(healthBand, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        if (trajectory != null)
                          Row(children: [
                            Icon(trajectoryIcon, size: 16, color: trajectoryColor),
                            const SizedBox(width: 4),
                            Text(trajectory.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: trajectoryColor)),
                          ]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (oneLiner != null) ...[
              Text(oneLiner, style: const TextStyle(fontSize: 15, color: Colors.white, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
            ],
            if (trajectoryNote != null && trajectoryNote.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: trajectoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: trajectoryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.insights, size: 18, color: trajectoryColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(trajectoryNote, style: const TextStyle(fontSize: 13, color: Colors.white70))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthCard(Map<String, dynamic> strength) {
    final area = strength['area'] as String? ?? 'Strength';
    final summary = strength['summary'] as String?;
    final evidence = (strength['evidence'] as List<dynamic>?)?.cast<String>() ?? [];
    final howToLeverage = strength['how_to_leverage'] as String?;
    final spiritualIndicator = strength['spiritual_maturity_indicator'] as String?;

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(area, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))),
            ]),
            if (summary != null) ...[const SizedBox(height: 8), Text(summary, style: const TextStyle(color: Colors.white70))],
            if (evidence.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Evidence:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
              ...evidence.map((e) => Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $e', style: const TextStyle(color: Colors.white70, fontSize: 13)))),
            ],
            if (howToLeverage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.lightbulb, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(howToLeverage, style: TextStyle(color: Colors.amber.shade200, fontSize: 13))),
                ]),
              ),
            ],
            if (spiritualIndicator != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.menu_book, color: Colors.purple.shade300, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(spiritualIndicator, style: TextStyle(color: Colors.purple.shade200, fontSize: 13, fontStyle: FontStyle.italic))),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGapCard(Map<String, dynamic> gap) {
    final area = gap['area'] as String? ?? 'Growth Area';
    final summary = gap['summary'] as String?;
    final severity = gap['severity'] as String?;
    final rootCause = gap['root_cause_analysis'] as String?;
    final biblicalPerspective = gap['biblical_perspective'] as String?;
    final growthPathway = gap['growth_pathway'] as Map<String, dynamic>?;

    Color severityColor = Colors.orange;
    if (severity == 'critical') {
      severityColor = Colors.red;
    } else if (severity == 'minor') severityColor = Colors.yellow;

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.trending_up, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(area, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))),
              if (severity != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: severityColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text(severity.toUpperCase(), style: TextStyle(color: severityColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ]),
            if (summary != null) ...[const SizedBox(height: 8), Text(summary, style: const TextStyle(color: Colors.white70))],
            if (rootCause != null) ...[
              const SizedBox(height: 12),
              const Text('Root Cause:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
              const SizedBox(height: 4),
              Text(rootCause, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
            if (biblicalPerspective != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.menu_book, color: Colors.purple.shade300, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(biblicalPerspective, style: TextStyle(color: Colors.purple.shade200, fontSize: 13, fontStyle: FontStyle.italic))),
                ]),
              ),
            ],
            if (growthPathway != null) ...[
              const SizedBox(height: 12),
              const Text('Growth Pathway:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
              ...growthPathway.entries.map((phase) {
                final phaseData = phase.value as Map<String, dynamic>?;
                if (phaseData == null) return const SizedBox.shrink();
                final goal = phaseData['goal'] as String?;
                final activities = (phaseData['activities'] as List<dynamic>?)?.cast<String>() ?? [];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(8)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(phase.key.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade300, fontSize: 11)),
                      if (goal != null) ...[const SizedBox(height: 4), Text(goal, style: const TextStyle(color: Colors.white, fontSize: 13))],
                      if (activities.isNotEmpty) ...activities.map((a) => Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $a', style: const TextStyle(color: Colors.white70, fontSize: 12)))),
                    ]),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConversationGuideCard(Map<String, dynamic> guide) {
    // Premium format: session_1_opening, session_2_growth_areas, session_3_check_in
    final sessionKeys = [
      ('session_1_opening', 'Session 1: Opening'),
      ('session_2_growth_areas', 'Session 2: Growth Areas'),
      ('session_3_check_in', 'Session 3: Check-In'),
    ];
    
    final sessionWidgets = <Widget>[];
    for (final (key, title) in sessionKeys) {
      final session = guide[key] as Map<String, dynamic>?;
      if (session == null) continue;
      
      final theme = session['theme'] as String?;
      final duration = session['duration_minutes'];
      final openingQuestion = session['opening_question'] as String?;
      final keyPoints = session['key_points_to_cover'] as List<dynamic>?;
      final questions = session['questions_to_ask'] as List<dynamic>?;
      final closeWith = session['close_with'] as String?;
      
      sessionWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade300, fontSize: 15))),
                if (duration != null) Text('$duration min', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ]),
              if (theme != null) ...[
                const SizedBox(height: 4),
                Text(theme, style: TextStyle(color: Colors.blue.shade200, fontStyle: FontStyle.italic, fontSize: 13)),
              ],
              if (openingQuestion != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.chat_bubble_outline, size: 16, color: Colors.blue.shade200),
                    const SizedBox(width: 8),
                    Expanded(child: Text('"$openingQuestion"', style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 13))),
                  ]),
                ),
              ],
              if (keyPoints != null && keyPoints.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Key Points:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 12)),
                const SizedBox(height: 6),
                ...keyPoints.take(3).map((kp) {
                  final point = kp is Map ? kp['point'] as String? ?? '' : kp.toString();
                  final talkingPoint = kp is Map ? kp['talking_point'] as String? : null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('• ', style: TextStyle(color: Colors.blue.shade300)),
                        Expanded(child: Text(point, style: const TextStyle(color: Colors.white, fontSize: 13))),
                      ]),
                      if (talkingPoint != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 2),
                          child: Text('"$talkingPoint"', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontStyle: FontStyle.italic)),
                        ),
                    ]),
                  );
                }),
              ],
              if (questions != null && questions.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Questions to Ask:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 12)),
                const SizedBox(height: 6),
                ...questions.take(3).map((q) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('? ', style: TextStyle(color: Colors.amber.shade300, fontWeight: FontWeight.bold)),
                    Expanded(child: Text(q.toString(), style: const TextStyle(color: Colors.white70, fontSize: 13))),
                  ]),
                )),
              ],
              if (closeWith != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.favorite, size: 16, color: Colors.green.shade300),
                    const SizedBox(width: 8),
                    Expanded(child: Text(closeWith, style: TextStyle(color: Colors.green.shade200, fontSize: 12))),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      );
    }
    
    // Fallback for legacy format or if no sessions found
    if (sessionWidgets.isEmpty) {
      final sessions = guide['sessions'] as List<dynamic>? ?? [];
      final topics = guide['key_topics'] as List<dynamic>? ?? [];
      
      return Card(
        color: Colors.grey[900],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sessions.isNotEmpty)
                ...sessions.asMap().entries.map((entry) {
                  final session = entry.value as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Session ${entry.key + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade300)),
                        if (session['goal'] != null) ...[const SizedBox(height: 4), Text(session['goal'].toString(), style: const TextStyle(color: Colors.white70))],
                        if (session['questions'] != null) ...[
                          const SizedBox(height: 8),
                          ...(session['questions'] as List).map((q) => Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $q', style: const TextStyle(color: Colors.white, fontSize: 13)))),
                        ],
                      ]),
                    ),
                  );
                }),
              if (topics.isNotEmpty) ...[
                const Text('Topics to Explore:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: topics.map((t) => Chip(label: Text(t.toString(), style: const TextStyle(fontSize: 12, color: Colors.white)), backgroundColor: Colors.blue.withValues(alpha: 0.2))).toList()),
              ],
              if (sessions.isEmpty && topics.isEmpty)
                const Text('No conversation guide available', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sessionWidgets,
        ),
      ),
    );
  }

  Widget _buildBiblicalKnowledgeCard(Map<String, dynamic> knowledge) {
    final overallPercent = knowledge['overall_percent'];
    final masteryLevel = knowledge['mastery_level'] as String?;
    final byTopicBreakdown = knowledge['by_topic_breakdown'] as List<dynamic>? ?? [];

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (overallPercent != null || masteryLevel != null)
              Row(children: [
                if (overallPercent != null) Text('$overallPercent%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber)),
                if (overallPercent != null && masteryLevel != null) const SizedBox(width: 12),
                if (masteryLevel != null) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: Text(masteryLevel, style: const TextStyle(color: Colors.amber))),
              ]),
            if (byTopicBreakdown.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...byTopicBreakdown.map((topic) {
                final t = topic as Map<String, dynamic>;
                final topicName = t['topic'] as String? ?? 'Topic';
                final scorePercent = t['score_percent'];
                final level = t['level'] as String?;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(flex: 2, child: Text(topicName, style: const TextStyle(color: Colors.white))),
                    if (scorePercent != null) Expanded(child: Text('$scorePercent%', style: TextStyle(color: Colors.grey[400]))),
                    if (level != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _levelColor(level).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)), child: Text(level, style: TextStyle(color: _levelColor(level), fontSize: 11))),
                  ]),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'strong': return Colors.green;
      case 'moderate': return Colors.amber;
      case 'weak': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Widget _buildFormationCard(Map<String, dynamic> formation) {
    // Premium format: category, current_level, detailed_observation, maturity_markers_present/missing, custom_development_plan, mentor_discussion_questions
    final area = formation['category'] as String? ?? formation['area'] as String? ?? 'Insight';
    final level = formation['current_level'] as String? ?? formation['level'] as String?;
    final observation = formation['detailed_observation'] as String? ?? formation['observation'] as String? ?? formation['summary'] as String?;
    final markersPresent = formation['maturity_markers_present'] as List<dynamic>?;
    final markersMissing = formation['maturity_markers_missing'] as List<dynamic>?;
    final customPlan = formation['custom_development_plan'] as Map<String, dynamic>?;
    final mentorQuestions = formation['mentor_discussion_questions'] as List<dynamic>?;
    // Legacy fallback
    final recommendation = formation['recommendation'] as String?;
    final mentorMoves = formation['mentor_moves'] as List<dynamic>?;

    Color levelColor = Colors.grey;
    if (level != null) {
      switch (level.toLowerCase()) {
        case 'flourishing':
        case 'mature':
          levelColor = Colors.green;
          break;
        case 'maturing':
        case 'good':
          levelColor = Colors.lightGreen;
          break;
        case 'stable':
          levelColor = Colors.blue;
          break;
        case 'developing':
        case 'growing':
          levelColor = Colors.orange;
          break;
        case 'beginning':
          levelColor = Colors.red;
          break;
      }
    }

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with area and level
            Row(children: [
              Expanded(child: Text(area, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))),
              if (level != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: levelColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(level, style: TextStyle(color: levelColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ]),
            
            // Observation
            if (observation != null && observation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(observation, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
            ],
            
            // Maturity markers
            if ((markersPresent != null && markersPresent.isNotEmpty) || (markersMissing != null && markersMissing.isNotEmpty)) ...[
              const SizedBox(height: 12),
              if (markersPresent != null && markersPresent.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: markersPresent.take(4).map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green.shade300),
                        const SizedBox(width: 8),
                        Expanded(child: Text(m.toString(), style: TextStyle(color: Colors.green.shade300, fontSize: 12))),
                      ]),
                    ),
                  )).toList(),
                ),
              if (markersMissing != null && markersMissing.isNotEmpty) ...[
                const SizedBox(height: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: markersMissing.take(4).map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        Icon(Icons.radio_button_unchecked, size: 14, color: Colors.orange.shade300),
                        const SizedBox(width: 8),
                        Expanded(child: Text(m.toString(), style: TextStyle(color: Colors.orange.shade300, fontSize: 12))),
                      ]),
                    ),
                  )).toList(),
                ),
              ],
            ],
            
            // Custom development plan
            if (customPlan != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.route, size: 16, color: Colors.purple.shade300),
                    const SizedBox(width: 6),
                    Text('Development Plan', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple.shade200, fontSize: 13)),
                  ]),
                  if (customPlan['immediate_30_days'] != null) ...[
                    const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('30 days: ', style: TextStyle(color: Colors.purple.shade300, fontWeight: FontWeight.w500, fontSize: 12)),
                      Expanded(child: Text(customPlan['immediate_30_days'].toString(), style: TextStyle(color: Colors.purple.shade100, fontSize: 12))),
                    ]),
                  ],
                  if (customPlan['quarter_goal'] != null) ...[
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Quarter: ', style: TextStyle(color: Colors.purple.shade300, fontWeight: FontWeight.w500, fontSize: 12)),
                      Expanded(child: Text(customPlan['quarter_goal'].toString(), style: TextStyle(color: Colors.purple.shade100, fontSize: 12))),
                    ]),
                  ],
                  if (customPlan['year_vision'] != null) ...[
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Year: ', style: TextStyle(color: Colors.purple.shade300, fontWeight: FontWeight.w500, fontSize: 12)),
                      Expanded(child: Text(customPlan['year_vision'].toString(), style: TextStyle(color: Colors.purple.shade100, fontSize: 12))),
                    ]),
                  ],
                ]),
              ),
            ],
            
            // Mentor discussion questions
            if (mentorQuestions != null && mentorQuestions.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Questions to Ask:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
              const SizedBox(height: 8),
              ...mentorQuestions.take(3).map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('? ', style: TextStyle(color: Colors.amber.shade300, fontWeight: FontWeight.bold)),
                  Expanded(child: Text(q.toString(), style: const TextStyle(color: Colors.white70, fontSize: 13))),
                ]),
              )),
            ],
            
            // Legacy fallback: recommendation or mentor_moves
            if (recommendation != null && recommendation.isNotEmpty && customPlan == null && mentorQuestions == null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.lightbulb, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(recommendation, style: TextStyle(color: Colors.amber.shade200, fontSize: 13))),
                ]),
              ),
            ],
            if (mentorMoves != null && mentorMoves.isNotEmpty && mentorQuestions == null) ...[
              const SizedBox(height: 12),
              const Text('Next Steps:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
              const SizedBox(height: 6),
              ...mentorMoves.take(3).map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('→ ', style: TextStyle(color: Colors.amber.shade300)),
                  Expanded(child: Text(m.toString(), style: const TextStyle(color: Colors.white70, fontSize: 13))),
                ]),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
