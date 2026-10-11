part of 'apprentice_report_screen.dart';

// Premium report sections for _ApprenticeReportScreenState.
extension _ApprenticeReportPremiumWidgets on _ApprenticeReportScreenState {
  Widget _buildPremiumUpsellCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade900.withValues(alpha: 0.25), Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade700, width: 1.2),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber.shade400, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Full AI Report',
                style: TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Premium', style: TextStyle(color: Colors.black, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Unlock a deeper analysis of your assessment results:',
            style: TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 13),
          ),
          const SizedBox(height: 10),
          _buildUpsellFeatureRow(Icons.analytics_outlined, 'Detailed AI Analysis of every answer'),
          _buildUpsellFeatureRow(Icons.psychology_outlined, 'Deep Spiritual Insights'),
          _buildUpsellFeatureRow(Icons.menu_book_outlined, 'Personalized Resource Recommendations'),
          _buildUpsellFeatureRow(Icons.trending_up, 'Growth Trends across assessments'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
              icon: const Icon(Icons.lock_open, size: 18),
              label: const Text('Upgrade to Premium', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpsellFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber.shade300, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 12))),
        ],
      ),
    );
  }

  /// Premium full report view for premium apprentices
  Widget _premiumContentView() {
    final report = _fullReport!;
    
    // Extract sections from the premium report
    final strengthsDeepDive = report['strengths_deep_dive'] as List<dynamic>?;
    final gapsDeepDive = report['gaps_deep_dive'] as List<dynamic>?;
    final execSummary = report['executive_summary'] as Map<String, dynamic>?;
    final biblicalKnowledge = report['biblical_knowledge_analysis'] as Map<String, dynamic>?;
    final spiritualFormation = report['spiritual_formation_insights'] as List<dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium badge header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade100, Colors.amber.shade50],
              ),
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
                      Text(
                        'Premium Report',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                      Row(
                        children: [
                          if (_fullReportCached)
                            Row(
                              children: [
                                Icon(Icons.cached, size: 12, color: Colors.amber.shade700),
                                const SizedBox(width: 4),
                                Text('Instant load', style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
                              ],
                            ),
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
            _buildPremiumSectionHeader('Executive Summary', Icons.summarize),
            const SizedBox(height: 12),
            _buildExecutiveSummary(execSummary),
            const SizedBox(height: 20),
          ],

          // Strengths Deep Dive
          if (strengthsDeepDive != null && strengthsDeepDive.isNotEmpty) ...[
            _buildPremiumSectionHeader('Your Strengths', Icons.thumb_up),
            const SizedBox(height: 12),
            ...strengthsDeepDive.map((s) => _buildStrengthDeepDiveCard(s as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],

          // Gaps Deep Dive (with growth pathways)
          if (gapsDeepDive != null && gapsDeepDive.isNotEmpty) ...[
            _buildPremiumSectionHeader('Growth Opportunities', Icons.trending_up),
            const SizedBox(height: 12),
            ...gapsDeepDive.map((g) => _buildGapDeepDiveCard(g as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],

          // Biblical Knowledge Deep Dive
          if (biblicalKnowledge != null) ...[
            _buildPremiumSectionHeader('Biblical Knowledge', Icons.menu_book),
            const SizedBox(height: 12),
            _buildBiblicalKnowledgeSection(biblicalKnowledge),
            const SizedBox(height: 20),
          ],

          // Spiritual Formation Insights
          if (spiritualFormation != null && spiritualFormation.isNotEmpty) ...[
            _buildPremiumSectionHeader('Spiritual Formation', Icons.self_improvement),
            const SizedBox(height: 12),
            ...spiritualFormation.map((s) => _buildSpiritualFormationCard(s as Map<String, dynamic>)),
            const SizedBox(height: 20),
          ],

          // Mentor's Shared Notes (still show these for premium users)
          if (_sharedNotes.isNotEmpty) ...[
            _buildMentorNotesSection(),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPremiumSectionHeader(String title, IconData icon) {
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

  Widget _buildExecutiveSummary(Map<String, dynamic> summary) {
    // Backend returns: health_score, health_band, one_liner, trajectory, trajectory_note
    final healthScore = summary['health_score'] as int?;
    final healthBand = summary['health_band'] as String?;
    final oneLiner = summary['one_liner'] as String?;
    final trajectory = summary['trajectory'] as String?;
    final trajectoryNote = summary['trajectory_note'] as String?;
    
    // For trajectory icons
    IconData trajectoryIcon = Icons.trending_flat;
    Color trajectoryColor = Colors.grey;
    if (trajectory == 'upward') {
      trajectoryIcon = Icons.trending_up;
      trajectoryColor = Colors.green;
    } else if (trajectory == 'downward') {
      trajectoryIcon = Icons.trending_down;
      trajectoryColor = Colors.red;
    }

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Health Score with band
            if (healthScore != null) ...[
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getScoreColor(healthScore).withValues(alpha: 0.2),
                      border: Border.all(color: _getScoreColor(healthScore), width: 3),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$healthScore',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(healthScore),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (healthBand != null)
                          Text(
                            healthBand,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (trajectory != null)
                          Row(
                            children: [
                              Icon(trajectoryIcon, size: 16, color: trajectoryColor),
                              const SizedBox(width: 4),
                              Text(
                                trajectory.toUpperCase(),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: trajectoryColor),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            // One-liner summary
            if (oneLiner != null) ...[
              Text(
                oneLiner,
                style: const TextStyle(fontSize: 15, color: Colors.white, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
            ],
            // Trajectory note
            if (trajectoryNote != null && trajectoryNote.isNotEmpty) ...[
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
                    Expanded(
                      child: Text(
                        trajectoryNote,
                        style: TextStyle(fontSize: 13, color: Colors.white70),
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

  Widget _buildStrengthDeepDiveCard(Map<String, dynamic> strength) {
    // Support AI-generated fields: area, summary, evidence, spiritual_maturity_indicator, how_to_leverage, celebration_talking_point
    final name = strength['area'] ?? strength['name'] ?? strength['strength'] ?? 'Strength';
    final description = strength['summary'] ?? strength['description'] as String?;
    final evidence = strength['evidence'] as List<dynamic>? ?? [];
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
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white))),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ],
            if (evidence.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Evidence:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
              ...evidence.take(3).map((e) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text('• $e', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              )),
            ],
            if (howToLeverage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: Colors.green.shade400),
                    const SizedBox(width: 6),
                    Expanded(child: Text(howToLeverage, style: TextStyle(fontSize: 12, color: Colors.green.shade300))),
                  ],
                ),
              ),
            ],
            if (spiritualIndicator != null) ...[  
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_stories, size: 16, color: Colors.purple.shade300),
                    const SizedBox(width: 6),
                    Expanded(child: Text(spiritualIndicator, style: TextStyle(fontSize: 12, color: Colors.purple.shade200, fontStyle: FontStyle.italic))),
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
    // Support AI-generated fields: area, summary, severity, root_cause_analysis, evidence, biblical_perspective, why_it_matters, growth_pathway
    final name = gap['area'] ?? gap['name'] ?? gap['gap'] ?? 'Growth Area';
    final description = gap['summary'] ?? gap['description'] as String?;
    final severity = gap['severity'] as String?;
    final biblicalPerspective = gap['biblical_perspective'] as String?;
    final whyItMatters = gap['why_it_matters'] as String?;
    final evidence = gap['evidence'] as List<dynamic>? ?? [];
    final currentState = gap['current_state'] as String?;
    final growthPathway = gap['growth_pathway'] as Map<String, dynamic>? ?? gap['pathway'] as Map<String, dynamic>?;
    final resources = gap['resources'] as List<dynamic>? ?? [];

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.orange.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white))),
                if (severity != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: severity == 'high' ? Colors.red.withValues(alpha: 0.2) :
                             severity == 'moderate' ? Colors.orange.withValues(alpha: 0.2) : Colors.yellow.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      severity,
                      style: TextStyle(
                        fontSize: 11,
                        color: severity == 'high' ? Colors.red.shade300 :
                               severity == 'moderate' ? Colors.orange.shade300 : Colors.yellow.shade300,
                      ),
                    ),
                  ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ],
            if (evidence.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Evidence:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
              ...evidence.take(3).map((e) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text('• $e', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              )),
            ],
            if (biblicalPerspective != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.menu_book, size: 16, color: Colors.purple.shade300),
                    const SizedBox(width: 6),
                    Expanded(child: Text(biblicalPerspective, style: TextStyle(fontSize: 12, color: Colors.purple.shade200))),
                  ],
                ),
              ),
            ],
            if (whyItMatters != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Why It Matters:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(whyItMatters, style: TextStyle(fontSize: 12, color: Colors.amber.shade200)),
                  ],
                ),
              ),
            ],
            if (currentState != null) ...[
              const SizedBox(height: 8),
              Text('Current State: $currentState', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
            ],
            if (growthPathway != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Growth Pathway:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
                    const SizedBox(height: 4),
                    // Support AI format (phase_1_weeks_1_4) and legacy format
                    if (growthPathway['phase_1_weeks_1_4'] != null)
                      _buildPhaseSection('Weeks 1-4', growthPathway['phase_1_weeks_1_4'] as Map<String, dynamic>),
                    if (growthPathway['phase_2_weeks_5_8'] != null)
                      _buildPhaseSection('Weeks 5-8', growthPathway['phase_2_weeks_5_8'] as Map<String, dynamic>),
                    if (growthPathway['phase_3_weeks_9_12'] != null)
                      _buildPhaseSection('Weeks 9-12', growthPathway['phase_3_weeks_9_12'] as Map<String, dynamic>),
                    // Legacy format fallback
                    if (growthPathway['immediate'] != null)
                      Text('• Immediate: ${growthPathway['immediate']}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    if (growthPathway['short_term'] != null)
                      Text('• Short-term: ${growthPathway['short_term']}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    if (growthPathway['long_term'] != null)
                      Text('• Long-term: ${growthPathway['long_term']}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
            ],
            if (resources.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Suggested Resources:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
              ...resources.take(3).map((r) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text('• $r', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              )),
            ],
          ],
        ),
      ),
    );
  }

  /// Build a phase section for growth pathway (e.g. "Weeks 1-4")
  Widget _buildPhaseSection(String phaseName, Map<String, dynamic> phase) {
    final goal = phase['goal'] as String?;
    final activities = phase['activities'] as List<dynamic>? ?? [];
    final successMetric = phase['success_metric'] as String?;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📅 $phaseName', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
          if (goal != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text('Goal: $goal', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white70)),
            ),
          if (activities.isNotEmpty)
            ...activities.map((a) => Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text('• $a', style: const TextStyle(fontSize: 11, color: Colors.white70)),
            )),
          if (successMetric != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text('✓ Success: $successMetric', style: TextStyle(fontSize: 11, color: Colors.green.shade400)),
            ),
        ],
      ),
    );
  }

  Widget _buildBiblicalKnowledgeSection(Map<String, dynamic> knowledge) {
    // Legacy format
    final topicBreakdown = knowledge['topic_breakdown'] as List<dynamic>? ?? [];
    final weakAreas = knowledge['weak_areas'] as List<dynamic>? ?? [];
    final studyPlan = knowledge['study_plan'] as Map<String, dynamic>?;
    
    // AI format
    final overallPercent = knowledge['overall_percent'];
    final masteryLevel = knowledge['mastery_level'] as String?;
    final byTopicBreakdown = knowledge['by_topic_breakdown'] as List<dynamic>? ?? [];
    final readingPlan = knowledge['recommended_bible_reading_plan'] as Map<String, dynamic>?;
    
    // Use AI format if available, else legacy
    final topics = byTopicBreakdown.isNotEmpty ? byTopicBreakdown : topicBreakdown;

    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI format: overall score
            if (overallPercent != null || masteryLevel != null) ...[
              Row(
                children: [
                  if (overallPercent != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$overallPercent%',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue.shade300),
                      ),
                    ),
                  if (masteryLevel != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(masteryLevel, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white70)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (topics.isNotEmpty) ...[
              const Text('Topic Performance:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              ...topics.take(5).map((topic) {
                if (topic is Map) {
                  final name = topic['topic'] ?? topic['name'] ?? 'Topic';
                  // Support AI format (score_percent) and legacy (score, percent)
                  final score = topic['score_percent'] ?? topic['score'] ?? topic['percent'] ?? 0;
                  final level = topic['level'] as String?;
                  final affirmation = topic['affirmation'] as String?;
                  final studyPrescription = topic['study_prescription'] as String?;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade700),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(name.toString(), style: const TextStyle(fontSize: 13, color: Colors.white70))),
                            Row(
                              children: [
                                Text('$score%', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                                if (level != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: level == 'Strong' ? Colors.green.withValues(alpha: 0.2) :
                                             level == 'Weak' ? Colors.red.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      level,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: level == 'Strong' ? Colors.green.shade300 :
                                               level == 'Weak' ? Colors.red.shade300 : Colors.orange.shade300,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: (score as num) / 100,
                          backgroundColor: Colors.grey.shade800,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            score >= 70 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red),
                          ),
                        ),
                        if (affirmation != null) ...[
                          const SizedBox(height: 6),
                          Text('✓ $affirmation', style: TextStyle(fontSize: 11, color: Colors.green.shade400)),
                        ],
                        if (studyPrescription != null) ...[
                          const SizedBox(height: 6),
                          Text('📚 $studyPrescription', style: TextStyle(fontSize: 11, color: Colors.blue.shade300)),
                        ],
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
            // Bible reading plan (AI format)
            if (readingPlan != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.menu_book, size: 18, color: Colors.purple.shade300),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Recommended: ${readingPlan['name'] ?? "Bible Reading Plan"}',
                              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple.shade200)),
                        ),
                      ],
                    ),
                    if (readingPlan['description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(readingPlan['description'], style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                    if (readingPlan['why_this_plan'] != null) ...[
                      const SizedBox(height: 4),
                      Text('Why: ${readingPlan['why_this_plan']}', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade400)),
                    ],
                  ],
                ),
              ),
            ],
            if (weakAreas.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Areas to Strengthen:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              ...weakAreas.take(3).map((area) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade600),
                    const SizedBox(width: 8),
                    Expanded(child: Text(area.toString(), style: const TextStyle(fontSize: 13, color: Colors.white70))),
                  ],
                ),
              )),
            ],
            if (studyPlan != null) ...[
              const SizedBox(height: 12),
              const Text('Recommended Study Plan:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: studyPlan.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  )).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpiritualFormationCard(Map<String, dynamic> insight) {
    // Support AI format and legacy format
    final area = insight['category'] ?? insight['area'] ?? 'Spiritual Life';
    final currentLevel = insight['current_level'] as String?;
    final detailedObservation = insight['detailed_observation'] ?? insight['observation'] as String?;
    final maturityPresent = insight['maturity_markers_present'] as List<dynamic>? ?? [];
    final maturityMissing = insight['maturity_markers_missing'] as List<dynamic>? ?? [];
    final customPlan = insight['custom_development_plan'] as Map<String, dynamic>?;
    final suggestions = insight['suggestions'] as List<dynamic>? ?? [];

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.spa, color: Colors.purple.shade400, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(area.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white))),
                if (currentLevel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(currentLevel, style: TextStyle(fontSize: 11, color: Colors.purple.shade300)),
                  ),
              ],
            ),
            if (detailedObservation != null) ...[
              const SizedBox(height: 8),
              Text(detailedObservation, style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ],
            // Maturity markers
            if (maturityPresent.isNotEmpty || maturityMissing.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (maturityPresent.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('✓ Present', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.green.shade400)),
                          ...maturityPresent.map((m) => Text('  • $m', style: const TextStyle(fontSize: 11, color: Colors.white70))),
                        ],
                      ),
                    ),
                  if (maturityMissing.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('○ Missing', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.orange.shade400)),
                          ...maturityMissing.map((m) => Text('  • $m', style: const TextStyle(fontSize: 11, color: Colors.white70))),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            // Custom development plan
            if (customPlan != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Development Plan:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
                    if (customPlan['immediate_30_days'] != null)
                      Text('📅 30 days: ${customPlan['immediate_30_days']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    if (customPlan['quarter_goal'] != null)
                      Text('📅 Quarter: ${customPlan['quarter_goal']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    if (customPlan['year_vision'] != null)
                      Text('📅 Year: ${customPlan['year_vision']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
            ],
            // Legacy suggestions
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Suggestions:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
              ...suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text('• $s', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              )),
            ],
          ],
        ),
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
      color: Colors.red[900]!.withValues(alpha: 0.3),
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
      color: Colors.amber.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.withValues(alpha: 0.5), width: 1),
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
                  color: Colors.black.withValues(alpha: 0.3),
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
}
