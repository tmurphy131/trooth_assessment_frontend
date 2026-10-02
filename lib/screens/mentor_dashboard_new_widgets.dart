part of 'mentor_dashboard_new.dart';

// Widget builders for _MentorDashboardNewState. State and logic live in mentor_dashboard_new.dart.
extension _MentorDashboardNewStateWidgets on _MentorDashboardNewState {
  Widget _buildApprenticesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: const Text(
                'My Apprentices',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              )),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MentorSpiritualGiftsScreen()),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome, color: Colors.amber),
                    tooltip: 'Spiritual Gifts',
                  ),
                  // Resources button removed; Resources now accessible via main tab bar
                  IconButton(
                    key: inviteButtonKey,
                    onPressed: _navigateToInviteApprentices,
                    icon: const Icon(Icons.person_add_alt_1, color: Colors.amber),
                    tooltip: 'Invite Apprentice',
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TemplateManagementScreen(user: user),
                        ),
                      );
                    },
                    icon: const Icon(Icons.assignment_outlined, color: Colors.amber),
                    tooltip: 'Manage Templates',
                  ),
                  IconButton(
                    onPressed: _loadApprentices,
                    icon: const Icon(Icons.refresh, color: Colors.amber),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingApprentices
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
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontFamily: 'Poppins',
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadApprentices,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _apprentices.isEmpty
                        ? _buildEmptyApprenticesState()
                        : ListView.builder(
                            itemCount: _apprentices.length,
                            itemBuilder: (context, index) {
                              // Bounds check to prevent RangeError during list updates
                              if (index >= _apprentices.length) {
                                return const SizedBox.shrink();
                              }
                              return _buildApprenticeCard(_apprentices[index], index);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalApprentices = _apprentices.length;
    final allAssessments = _completedAssessmentsByApprentice.values.expand((x) => x).toList();
    final totalCompletedAssessments = allAssessments.length;
    // Calculate average score
    double averageScore = 0.0;
    if (allAssessments.isNotEmpty) {
      final scores = <double>[];
      for (final a in allAssessments) {
        final raw = (a as Map)['scores']?['overall_score'];
        double v;
        if (raw is num) {
          v = raw.toDouble();
        } else if (raw is String) v = double.tryParse(raw) ?? 0.0;
        else v = 0.0;
        if (v.isFinite) scores.add(v);
      }
      if (scores.isNotEmpty) {
        final sum = scores.fold<double>(0.0, (p, c) => p + c);
        averageScore = (sum / scores.length).clamp(0.0, 10.0);
      }
    }

    return Row(
      key: statsRowKey,
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.people,
            title: 'Active\nApprentices',
            value: totalApprentices.toString(),
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.assignment_turned_in,
            title: 'Completed\nAssessments',
            value: totalCompletedAssessments.toString(),
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.trending_up,
            title: 'Average\nScore',
            value: '${(averageScore * 10).toStringAsFixed(1)}%',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        // Reduce horizontal padding by 1px on each side to gain ~2px inner width
        padding: const EdgeInsets.fromLTRB(15, 16, 15, 16),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
                fontFamily: 'Poppins',
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyApprenticesState() {
    return Center(
      child: Card(
        elevation: 2,
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                'No apprentices yet',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start mentoring by inviting apprentices to your program',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _navigateToInviteApprentices(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Invite Apprentices',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApprenticeCard(Map<String, dynamic> apprentice, int index) {
    final name = apprentice['name'] ?? 'Unknown';
    final email = apprentice['email'] ?? '';
    final apprenticeId = apprentice['id'] as String;
    
    // Check if this apprentice is accessible based on subscription
    final isAccessible = _subscriptionService.status.canAccessApprentice(index);
    
    // If not accessible, show locked card
    if (!isAccessible) {
      return _buildLockedApprenticeCard(name, email, index);
    }
    
    return Card(
      elevation: 2,
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.person,
            color: Colors.amber,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        subtitle: Text(
          email,
          style: TextStyle(
            color: Colors.grey[400],
            fontFamily: 'Poppins',
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
          color: Colors.grey[800],
          onSelected: (value) async {
            switch (value) {
              case 'profile':
                await _showApprenticeProfile(apprenticeId);
                break;
              case 'assessments':
                await _showApprenticeAssessments(apprenticeId);
                break;
              case 'meeting':
                await _showMeetingInfo(apprenticeId, email, name);
                break;
              case 'agreement':
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MentorAgreementsScreen()),
                );
                break;
              case 'gift_premium':
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MentorGiftSeatsScreen()),
                );
                if (result == true) {
                  _loadSubscriptionData();
                }
                break;
              case 'terminate':
                await _showTerminateDialog(apprenticeId, name);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('View Profile', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'assessments',
              child: Row(
                children: [
                  Icon(Icons.assignment, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('View Assessments', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'meeting',
              child: Row(
                children: [
                  Icon(Icons.event, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Meeting Info', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'agreement',
              child: Row(
                children: [
                  Icon(Icons.description, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Manage Agreement', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            if (_subscriptionService.isPremium)
              const PopupMenuItem(
                value: 'gift_premium',
                child: Row(
                  children: [
                    Icon(Icons.card_giftcard, color: Color(0xFFFFD700)),
                    SizedBox(width: 8),
                    Text('Gift Premium', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'terminate',
              child: Row(
                children: [
                  Icon(Icons.stop_circle, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Terminate', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedApprenticeCard(String name, String email, int index) {
    return Card(
      elevation: 2,
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _showUpgradeForApprenticesDialog,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Dimmed content
            Opacity(
              opacity: 0.4,
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.person, color: Colors.grey),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                subtitle: Text(
                  email,
                  style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Lock overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, color: Colors.black, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Upgrade',
                            style: TextStyle(
                              color: Colors.black,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildMyAssessmentsSection() {
    final loading = _isLoadingMentorAssessments || _isLoadingMentorDrafts;
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2)),
      );
    }
    if (_mentorOwnDrafts.isEmpty && _mentorOwnAssessments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No assessments yet — tap "Take One" to start.',
          style: TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 13),
        ),
      );
    }

    final draftCards = _mentorOwnDrafts.map((draft) {
      final answers = draft['answers'] as Map<String, dynamic>? ?? {};
      final questions = draft['questions'] as List<dynamic>? ?? [];
      final answeredCount = answers.length;
      final totalCount = questions.length;
      final draftId = draft['id']?.toString();
      return InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AssessmentScreen(draftId: draftId),
            ),
          );
          _loadMentorOwnDrafts();
          _loadMentorOwnAssessments();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.edit_note, color: Colors.lightBlueAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('In Progress', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(
                      totalCount > 0 ? '$answeredCount of $totalCount answered' : '$answeredCount answered',
                      style: const TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.4)),
                ),
                child: const Text('Continue', style: TextStyle(color: Colors.lightBlueAccent, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Delete draft',
                onPressed: () => _confirmDeleteMentorDraft(draftId),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
              ),
            ],
          ),
        ),
      );
    }).toList();

    final completedCards = _mentorOwnAssessments.map((assessment) {
      final scores = assessment['scores'] as Map<String, dynamic>? ?? {};
      final overallScore = scores['overall_score'];
      final createdAt = assessment['created_at'] as String?;
      String dateLabel = '';
      if (createdAt != null) {
        try {
          final dt = DateTime.parse(createdAt).toLocal();
          dateLabel = '${dt.month}/${dt.day}/${dt.year}';
        } catch (_) {
          dateLabel = createdAt;
        }
      }
      final assessmentId = assessment['id']?.toString() ?? '';
      return InkWell(
        onTap: assessmentId.isEmpty ? null : () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ApprenticeReportScreen(
              assessmentId: assessmentId,
              title: 'My Assessment Report',
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Icon(Icons.assignment_turned_in, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(assessment['template_name'] as String? ?? 'Assessment', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14)),
                    if (dateLabel.isNotEmpty)
                      Text(dateLabel, style: const TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 12)),
                  ],
                ),
              ),
              if (overallScore != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$overallScore%',
                    style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                )
              else
                const Text('Processing...', style: TextStyle(color: Colors.white60, fontFamily: 'Poppins', fontSize: 12)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
            ],
          ),
        ),
      );
    }).toList();

    return Column(children: [...draftCards, ...completedCards]);
  }

  Widget _buildAssessmentsTab() {
    // For free mentors, only show assessments for the first apprentice
    final status = _subscriptionService.status;
    final accessibleApprentices = (!status.isPremium && !status.isGrandfathered)
        ? (_apprentices.isNotEmpty ? [_apprentices.first] : <Map<String, dynamic>>[])
        : _apprentices;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── My Assessments section ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: const Text(
                'MY ASSESSMENTS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  fontFamily: 'Poppins',
                ),
              )),
              ElevatedButton.icon(
                onPressed: _startSelfAssessment,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Take One', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(child: _buildMyAssessmentsSection()),
          ),
          const Divider(color: Colors.white12, height: 24),
          // ── Apprentice Assessments section ─────────────────────────────
          const Text(
            'Assessment Results',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildApprenticeFilter()),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _reloadAssessments,
              icon: const Icon(Icons.refresh, color: Colors.amber),
              tooltip: 'Refresh',
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingAssessments
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  )
                : _completedAssessmentsByApprentice.isEmpty
                    ? _buildEmptyAssessmentsState()
                    : ListView(
                        children: (_selectedApprenticeId == '_all'
                                ? accessibleApprentices
                                : accessibleApprentices.where((a) => a['id'] == _selectedApprenticeId).toList())
                            .map((apprentice) {
                          final apprenticeId = apprentice['id'] as String;
                          final assessments = _completedAssessmentsByApprentice[apprenticeId] ?? [];
                          if (assessments.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  '${apprentice['name'] ?? 'Unknown'} (${apprentice['email'] ?? ''})',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                              ...assessments.map((assessment) => _buildCompletedAssessmentCard(assessment)),
                            ],
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAssessmentsState() {
    return Center(
      child: Card(
        elevation: 2,
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 64,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                'No assessments submitted yet',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Assessment submissions from your apprentices will appear here',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedAssessmentCard(Map<String, dynamic> assessment) {
    final scores = assessment['scores'] as Map<String, dynamic>? ?? {};
    // Normalize overall score to a 0..10 double if possible
    double overall10;
    try {
      final raw = scores['overall_score'];
      if (raw is num) {
        overall10 = raw.toDouble();
      } else if (raw is String) {
        overall10 = double.tryParse(raw) ?? 0.0;
      } else {
        overall10 = 0.0;
      }
    } catch (_) {
      overall10 = 0.0;
    }
    if (!overall10.isFinite) overall10 = 0.0;
    final overallPct = (overall10 * 10).clamp(0, 100).round();
    final createdAt = assessment['created_at'] as String?;
    final apprenticeName = assessment['apprentice_name'] ?? assessment['apprentice']?['name'] ?? 'Unknown Apprentice';
    final apprenticeId = assessment['apprentice_id'] ?? assessment['apprentice']?['id'] ?? '';
    final assessmentId = assessment['id']?.toString() ?? assessment['assessment_id']?.toString() ?? '';
    final templateName = assessment['template_name'] ?? assessment['template']?['name'] ?? assessment['category'] ?? 'Assessment';
    
    return Card(
      elevation: 2,
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getScoreColor(overallPct).withValues(alpha: 0.2), // Percent 0..100
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.analytics,
            color: _getScoreColor(overallPct),
          ),
        ),
        title: Text(
          templateName.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              apprenticeName.toString(),
              style: TextStyle(
                color: Colors.grey[400],
                fontFamily: 'Poppins',
                fontSize: 13,
              ),
            ),
            Text(
              'Overall Score: ${overall10.toStringAsFixed(1)}/10',
              style: TextStyle(
                color: _getScoreColor(overallPct),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            if (scores.containsKey('category_scores'))
              Text(
                _buildCategoryScoresSummary(scores['category_scores'] as Map<String, dynamic>),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              ),
            if (createdAt != null)
              Text(
                _formatDateString(createdAt),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[600],
          size: 16,
        ),
        onTap: () {
          // If this submission is for Spiritual Gifts, route to the dedicated gifts screen
          if (isSpiritualGiftsAssessment(assessment)) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MentorSpiritualGiftsScreen(
                  initialApprenticeId: apprenticeId?.toString().isEmpty == false ? apprenticeId.toString() : null,
                  initialApprenticeName: apprenticeName?.toString(),
                ),
              ),
            );
            return;
          }

          // Navigate to mentor submission detail screen with real IDs
          if (assessmentId.isNotEmpty) {
            Navigator.of(context).pushNamed(
              '/mentor/submissions/$assessmentId',
              arguments: {
                'apprenticeName': apprenticeName,
                'apprenticeId': apprenticeId,
              },
            );
          } else {
            _showAssessmentResults(assessment); // fallback to legacy view
          }
        },
      ),
    );
  }
}
