part of 'apprentice_dashboard_new.dart';

// Widget builders for _ApprenticeDashboardNewState. State and logic live in apprentice_dashboard_new.dart.
extension _ApprenticeDashboardNewStateWidgets on _ApprenticeDashboardNewState {
  Widget _buildWelcomeCard() {
    return Card(
      key: welcomeCardKey,
      elevation: 4,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.person, color: Colors.amber, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome back, ${_deriveDisplayName()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '#getrooted',
                    style: TextStyle(
                      color: Colors.amber[300],
                      fontSize: 11,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriviaTile() {
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const TriviaHomeScreen()))
          .then((_) => _loadTriviaPendingCount()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(Icons.quiz, color: Color(0xFFFFD700), size: 22),
                  ),
                  if (_triviaPendingCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _triviaPendingCount > 9
                              ? '9+'
                              : '$_triviaPendingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bible Trivia',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _triviaPendingCount > 0
                        ? '$_triviaPendingCount challenge${_triviaPendingCount > 1 ? 's' : ''} waiting for you'
                        : 'Test your knowledge & challenge others',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontFamily: 'Poppins',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    Key? cardKey,
  }) {
    return Card(
      key: cardKey,
      elevation: 2,
      color: Colors.grey[850],
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentAssessments() {
    // Draft assessments section - fills remaining space
    return Column(
      key: recentAssessmentsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Draft Assessments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            SizedBox(
              height: 28,
              width: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: _loadAssessments,
                icon: const Icon(Icons.refresh, color: Colors.amber, size: 18),
                tooltip: 'Refresh',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.amber,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                _error!,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontFamily: 'Poppins',
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else if (_assessments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: _buildEmptyStateCompact(),
          )
        else
          ..._assessments.map(_buildAssessmentCardCompact),
      ],
    );
  }

  Widget _buildEmptyStateCompact() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 24, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No drafts yet',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: _startNewAssessment,
                  child: Text(
                    'Start a new assessment →',
                    style: TextStyle(
                      color: Colors.amber[300],
                      fontSize: 11,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentCardCompact(Map<String, dynamic> assessment) {
    final title = _resolveDraftTitle(assessment);
    final assessmentId = assessment['id'] as String?;
    final updatedAt = assessment['updated_at'] as String?;
    final createdAt = assessment['created_at'] as String?;
    String timeInfo = '';
    try {
      final ts = updatedAt ?? createdAt;
      if (ts != null) {
        timeInfo = _relativeTime(DateTime.parse(ts).toLocal());
      }
    } catch (_) {}

    final cardContent = Card(
      elevation: 1,
      color: Colors.grey[850],
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _navigateToAssessment(assessment),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.edit_note,
                  color: Colors.amber,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (timeInfo.isNotEmpty)
                      Text(
                        timeInfo,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                          fontFamily: 'Poppins',
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
    );

    // Wrap with Dismissible for swipe-to-delete
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Dismissible(
          key: Key(assessmentId ?? title),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await _showDeleteConfirmationDialog(assessmentId, title);
          },
          background: Container(
            decoration: BoxDecoration(
              color: Colors.red[700],
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.close, color: Colors.white, size: 24),
                SizedBox(height: 2),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          child: cardContent,
        ),
      ),
    );
  }

  Widget? _buildTrailingBadge(bool isMaster, bool isLocked, bool canAccess) {
    if (!canAccess) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
        ),
        child: const Text(
          'PREMIUM',
          style: TextStyle(
            color: Colors.amber,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
      );
    }
    if (isMaster) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'OFFICIAL',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
      );
    }
    return null;
  }
}
