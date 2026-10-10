part of 'mentor_submission_detail_screen.dart';

// Widget builders for _MentorSubmissionDetailScreenState. State and logic live in mentor_submission_detail_screen.dart.
extension _MentorSubmissionDetailScreenStateWidgets on _MentorSubmissionDetailScreenState {
  Widget _footerActions(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _emailReport, 
                icon: const Icon(Icons.mail_outline, color: Colors.white70), 
                label: const Text('Email report', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _showExportOptions, 
                icon: const Icon(Icons.ios_share, color: Colors.black), 
                label: const Text('Export PDF', style: TextStyle(color: Colors.black)),
                style: FilledButton.styleFrom(backgroundColor: Colors.amber),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _answersTab() {
    final d = _detail; if (d == null) return const SizedBox.shrink();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: d.questions.length,
      itemBuilder: (context, i) {
        final q = d.questions[i];
        if (q.type == 'mc' || q.type == 'multiple_choice') {
          return _mcTile(q);
        } else {
          return _openTile(q);
        }
      },
    );
  }

  Widget _mcTile(QuestionItem q) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(q.text, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...q.options.map((o) {
            final chosen = (q.chosenOptionId != null && q.chosenOptionId == o.id) || (q.apprenticeAnswer != null && q.apprenticeAnswer!.trim().toLowerCase() == o.text.trim().toLowerCase());
            final correct = o.isCorrect;
            final leading = Icon(chosen ? Icons.radio_button_checked : Icons.radio_button_off, color: chosen ? Colors.blue : null);
            final trailing = correct ? const _Badge(text: 'Correct') : (chosen && !correct ? const _Badge(text: 'Chosen') : null);
            final style = TextStyle(color: chosen && !correct ? Colors.red : null, fontWeight: chosen ? FontWeight.w600 : FontWeight.w400);
            return ListTile(leading: leading, title: Text(o.text, style: style), trailing: trailing);
          }),
          if (q.options.any((o) => o.isCorrect) && (q.chosenOptionId == null || !q.options.any((o) => o.id == q.chosenOptionId)))
            const Padding(padding: EdgeInsets.only(top: 4), child: Text('Correct answer shown above.', style: TextStyle(color: Colors.grey))),
        ]),
      ),
    );
  }

  Widget _openTile(QuestionItem q) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(q.text, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SelectableText(q.apprenticeAnswer ?? '(no answer)'),
          if (q.rubric != null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              if (q.rubric!.understanding != null) Chip(label: Text('Understanding: ${q.rubric!.understanding}')),
              if (q.rubric!.practice != null) Chip(label: Text('Practice: ${q.rubric!.practice}')),
              if (q.rubric!.gospelCenteredness != null) Chip(label: Text('Gospel: ${q.rubric!.gospelCenteredness}')),
              if (q.rubric!.humility != null) Chip(label: Text('Humility: ${q.rubric!.humility}')),
              if (q.rubric!.teachability != null) Chip(label: Text('Teachability: ${q.rubric!.teachability}')),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _reportTab() {
    // If still loading, show loading state
    if (_checkingPremium) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: troothGold),
            const SizedBox(height: 16),
            Text(
              'Loading report...',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Always show the simplified reactive report as default
    // with a button to view premium report
    return _buildSimplifiedReportTab();
  }

  /// Build the simplified report view - navigates to the full interactive simplified screen
  Widget _buildSimplifiedReportTab() {
    final r = _report; 
    if (r == null) return const SizedBox.shrink();
    
    return RefreshIndicator(
      onRefresh: () async { await _load(); },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Premium Full Report Button - prominent at top
          _buildPremiumReportButton(),
          const SizedBox(height: 16),
          
          // Health Score Card (styled nicely)
          _buildHealthScoreCard(r),
          const SizedBox(height: 16),

          // Urgent Flags (if any)
          if (r.flags.red.isNotEmpty) ...[
            _buildUrgentFlag(r.flags.red.first),
            const SizedBox(height: 16),
          ],

          // Priority Action Card
          _buildPriorityActionCard(r),
          const SizedBox(height: 16),

          // Top Strengths & Gaps in nice cards
          _buildStrengthsGapsSection(r),
          const SizedBox(height: 24),

          // Expandable Sections
          _buildExpandableKnowledgeSection(r),
          const SizedBox(height: 12),
          
          _buildExpandableInsightsSection(r),
          const SizedBox(height: 12),
          
          _buildExpandablePlanSection(r),
          const SizedBox(height: 24),

          // Conversation Starter Card
          if (r.conversationStarters.isNotEmpty) ...[
            _buildConversationStarterCard(r),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildPremiumReportButton() {
    final isLoading = _loadingFullReport;
    final isPremium = _isPremium;
    final hasFullReport = _fullReport != null;
    
    return GestureDetector(
      onTap: isLoading ? null : _onPremiumReportTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPremium 
              ? [Colors.amber.shade700, Colors.amber.shade500]
              : [Colors.grey[800]!, Colors.grey[700]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPremium ? Colors.amber.shade300 : Colors.grey[600]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading 
                ? const SizedBox(
                    width: 24, 
                    height: 24, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    Icons.auto_awesome,
                    color: isPremium ? Colors.white : Colors.amber,
                    size: 24,
                  ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isPremium ? 'View Full Premium Report' : 'Unlock Premium Report',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      if (!isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPremium 
                      ? (hasFullReport ? 'Deep analysis, growth pathways & conversation guides' : 'Tap to generate AI-powered insights')
                      : 'Get deeper insights, growth pathways & personalized guides',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _premiumFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildHealthScoreCard(MentorReportV2 r) {
    final overallPercent = r.snapshot.healthScore;
    final band = r.snapshot.knowledgeBand;
    final bandColor = _getBandColor(band);
    final bandIcon = _getBandIcon(band);

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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Health Score', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${overallPercent.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: bandColor),
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
              child: Text(band, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentFlag(String flag) {
    return Card(
      color: Colors.red.shade900.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade700),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red.shade300, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Urgent Attention', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade300)),
                  const SizedBox(height: 4),
                  Text(flag, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityActionCard(MentorReportV2 r) {
    final action = r.snapshot.topGaps.isNotEmpty ? r.snapshot.topGaps.first : 'Continue current growth path';
    
    return Card(
      color: Colors.amber.shade900.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade700),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.flag, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Priority Focus', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                  const SizedBox(height: 4),
                  Text(action, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthsGapsSection(MentorReportV2 r) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Card(
            color: Colors.green.shade900.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.thumb_up, color: Colors.green.shade300, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text('Strengths', overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade300)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...r.snapshot.topStrengths.take(3).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•', style: TextStyle(color: Colors.green.shade300)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            color: Colors.orange.shade900.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: Colors.orange.shade300, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text('Growth Areas', overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade300)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...r.snapshot.topGaps.take(3).map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•', style: TextStyle(color: Colors.orange.shade300)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(g, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Card(
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
                  Icon(icon, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16))),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildConversationStarterCard(MentorReportV2 r) {
    final starter = r.conversationStarters.isNotEmpty ? r.conversationStarters.first : null;
    if (starter == null) return const SizedBox.shrink();
    
    return Card(
      color: Colors.blue.shade900.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade700),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: Colors.blue.shade300, size: 20),
                const SizedBox(width: 8),
                Text('Conversation Starter', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade300)),
              ],
            ),
            const SizedBox(height: 12),
            Text('"$starter"', style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 15)),
            if (r.conversationStarters.length > 1) ...[
              const SizedBox(height: 8),
              Text('+ ${r.conversationStarters.length - 1} more', style: TextStyle(color: Colors.blue.shade300, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _notesTab() {
    if (_notesLoading) {
      return Center(child: CircularProgressIndicator(color: troothGold));
    }

    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_add_outlined, color: Colors.grey[600], size: 64),
            const SizedBox(height: 16),
            Text('No notes yet', style: TextStyle(color: Colors.grey[500], fontSize: 18)),
            const SizedBox(height: 8),
            Text('Tap the + button to add your first note', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotes,
      color: troothGold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MentorNoteCard(
              note: note,
              onEdit: () => _editNote(note),
              onDelete: () => _deleteNote(note),
              currentUserId: FirebaseAuth.instance.currentUser?.uid,
            ),
          );
        },
      ),
    );
  }
}
