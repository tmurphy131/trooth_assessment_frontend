part of 'apprentice_report_screen.dart';

// Widget builders for _ApprenticeReportScreenState. State and logic live in apprentice_report_screen.dart.
extension _ApprenticeReportScreenStateWidgets on _ApprenticeReportScreenState {
  Widget _generatingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.amber, strokeWidth: 3),
            const SizedBox(height: 24),
            const Text(
              'Generating your report...',
              style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Our AI is analyzing your assessment. This usually takes 15–30 seconds.',
              style: TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
          
          // Mentor's Shared Notes
          if (_sharedNotes.isNotEmpty) ...[
            _buildMentorNotesSection(),
            const SizedBox(height: 16),
          ],
          
          // Completion Date
          if (completedAt != null) ...[
            _buildCompletedAtSection(completedAt),
            const SizedBox(height: 16),
          ],

          // Premium upsell — shown when backend confirmed 403 (not premium)
          if (_showPremiumUpsell)
            _buildPremiumUpsellCard(),

          const SizedBox(height: 24),
        ],
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
                    color: Colors.black.withValues(alpha: 0.3),
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
                              color: _getLevelColor(level).withValues(alpha: 0.2),
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

  Widget _buildMentorNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.note_alt_outlined, color: troothGold, size: 20),
            const SizedBox(width: 8),
            Text(
              'Notes from Your Mentor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: troothGold,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._sharedNotes.map((note) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: troothGold.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatNoteDate(note.displayTimestamp),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
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
}
