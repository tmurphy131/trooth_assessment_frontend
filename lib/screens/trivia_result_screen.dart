import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'trivia_setup_screen.dart';
import 'trivia_leaderboard_screen.dart';

class TriviaResultScreen extends StatefulWidget {
  final int score;
  final int streakLength;
  final int correctCount;
  final String category;
  final String difficulty;
  final List<Map<String, dynamic>> answers;
  final int graceTokensUsed;

  const TriviaResultScreen({
    super.key,
    required this.score,
    required this.streakLength,
    required this.correctCount,
    required this.category,
    required this.difficulty,
    required this.answers,
    required this.graceTokensUsed,
  });

  @override
  State<TriviaResultScreen> createState() => _TriviaResultScreenState();
}

class _TriviaResultScreenState extends State<TriviaResultScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _result;
  bool _isSubmitting = true;
  String? _error;
  late AnimationController _celebrationController;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _submit();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      final result = await ApiService().triviaSubmitSingleGame({
        'category': widget.category,
        'difficulty': widget.difficulty,
        'answers': widget.answers,
        'grace_tokens_used': widget.graceTokensUsed,
      });
      if (mounted) {
        setState(() {
          _result = result;
          _isSubmitting = false;
        });
        if (result['is_new_high_score'] == true) {
          _celebrationController.forward();
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isSubmitting
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFFFD700)),
                    SizedBox(height: 16),
                    Text('Saving your score...', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                  ],
                ),
              )
            : _buildResults(),
      ),
    );
  }

  Widget _buildResults() {
    final isHighScore = _result?['is_new_high_score'] == true;
    final rank = _result?['leaderboard_rank'] as int?;
    final badges = (_result?['badges_earned'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isHighScore) ...[
            const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 56),
            const SizedBox(height: 8),
            const Text(
              'New Personal Best!',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ] else ...[
            const Icon(Icons.check_circle_outline, color: Colors.white70, size: 48),
            const SizedBox(height: 8),
            const Text(
              'Game Over',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
          const SizedBox(height: 28),
          _statRow('Score', widget.score.toString()),
          _statRow('Correct Answers', widget.correctCount.toString()),
          _statRow('Best Streak', '${widget.streakLength} in a row'),
          if (widget.graceTokensUsed > 0)
            _statRow('Grace Tokens Used', widget.graceTokensUsed.toString()),
          if (rank != null)
            _statRow('Leaderboard Rank', '#$rank'),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text('Note: Score may not have saved (${{_error}})', style: const TextStyle(color: Colors.redAccent, fontFamily: 'Poppins', fontSize: 12)),
          ],
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Badges Earned',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ...badges.map((b) => _buildBadgeCard(b)),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Home', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TriviaSetupScreen(mode: TriviaMode.single),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Play Again',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TriviaLeaderboardScreen()),
            ),
            child: const Text(
              'View Leaderboard',
              style: TextStyle(color: Color(0xFFFFD700), fontFamily: 'Poppins'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge) {
    final name = (badge['badge_display_name'] as String? ?? '').replaceAll('_', ' ');
    final streak = badge['streak_at_earn'] as int? ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A00), Color(0xFF2A2000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.military_tech, color: Color(0xFFFFD700), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$streak correct in a row!',
                  style: const TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
