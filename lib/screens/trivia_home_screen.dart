import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'trivia_setup_screen.dart';
import 'trivia_challenge_list_screen.dart';
import 'trivia_leaderboard_screen.dart';

class TriviaHomeScreen extends StatefulWidget {
  const TriviaHomeScreen({super.key});

  @override
  State<TriviaHomeScreen> createState() => _TriviaHomeScreenState();
}

class _TriviaHomeScreenState extends State<TriviaHomeScreen> {
  final _api = ApiService();
  int _activeChallengeCount = 0;
  Map<String, dynamic>? _topBadge;

  @override
  void initState() {
    super.initState();
    _loadChallengeCount();
    _loadTopBadge();
  }

  Future<void> _loadChallengeCount() async {
    try {
      final challenges = await _api.triviaListChallenges();
      final active = challenges.where((c) {
        final status = c['status'] as String? ?? '';
        return status == 'pending' || status == 'active';
      }).length;
      if (mounted) setState(() => _activeChallengeCount = active);
    } catch (_) {}
  }

  Future<void> _loadTopBadge() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final profile = await _api.triviaGetProfile(uid);
      final badges = (profile['badges'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      if (badges.isEmpty) return;
      badges.sort((a, b) =>
          (b['streak_at_earn'] as int? ?? 0).compareTo(a['streak_at_earn'] as int? ?? 0));
      if (mounted) setState(() => _topBadge = badges.first);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        title: const Text(
          'Trivia',
          style: TextStyle(
            color: Color(0xFFFFD700),
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFFFFD700)),
            onPressed: _showHowToPlay,
            tooltip: 'How to Play',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLaunchBanner(),
            if (_topBadge != null) ...[
              const SizedBox(height: 16),
              _buildTopBadgeBanner(_topBadge!),
            ],
            const SizedBox(height: 24),
            const Text(
              'Choose a Mode',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 14),
            _buildModeCard(
              title: 'Single Player',
              subtitle: 'Answer as many questions as you can without getting one wrong. Build your streak and climb the leaderboard.',
              icon: Icons.person,
              accentColor: const Color(0xFFFFD700),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TriviaSetupScreen(mode: TriviaMode.single),
                ),
              ).then((_) {
              _loadChallengeCount();
              _loadTopBadge();
            }),
            ),
            const SizedBox(height: 14),
            _buildModeCard(
              title: 'Multiplayer',
              subtitle: 'Challenge any T[root]H user by email. Answer the same questions turn-by-turn and see who knows their Bible best.',
              icon: Icons.people,
              accentColor: Colors.blueAccent,
              badge: _activeChallengeCount > 0 ? _activeChallengeCount : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TriviaChallengeListScreen()),
              ).then((_) => _loadChallengeCount()),
            ),
            const SizedBox(height: 24),
            _buildLeaderboardRow(),
          ],
        ),
      ),
    );
  }

  String _badgeEmoji(String badgeType) {
    const map = {
      'faithful_disciple': '🙏',
      'scripture_scholar': '📖',
      'bible_champion': '🏆',
      'wisdom_seeker': '🔭',
      'the_apostle': '✝️',
    };
    return map[badgeType] ?? '🎖️';
  }

  Widget _buildTopBadgeBanner(Map<String, dynamic> badge) {
    final displayName = badge['badge_display_name'] as String? ?? badge['badge_type'] as String? ?? 'Badge';
    final streak = badge['streak_at_earn'] as int? ?? 0;
    final emoji = _badgeEmoji(badge['badge_type'] as String? ?? '');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Top Badge',
                  style: TextStyle(color: Colors.white38, fontFamily: 'Poppins', fontSize: 10),
                ),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
            ),
            child: Text(
              '$streak streak',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaunchBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A00), Color(0xFF2A2000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '60-Day Launch Competition',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Top 3 players on the Challenger leaderboard win merch prizes — see the leaderboard for live standings.',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'Poppins',
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _prizeChip('🥇', '1st', '100% off merch'),
              const SizedBox(width: 8),
              _prizeChip('🥈', '2nd', '50% off merch'),
              const SizedBox(width: 8),
              _prizeChip('🥉', '3rd', '25% off merch'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _prizeChip(String emoji, String place, String prize) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            Text(
              place,
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            Text(
              prize,
              style: const TextStyle(
                color: Colors.white54,
                fontFamily: 'Poppins',
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    int? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                children: [
                  Center(child: Icon(icon, color: accentColor, size: 28)),
                  if (badge != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : badge.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: accentColor,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardRow() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TriviaLeaderboardScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.leaderboard, color: Color(0xFFFFD700), size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'View Leaderboard',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  void _showHowToPlay() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'How to Play',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 20),
            _rulesSection('Single Player', _singlePlayerRules),
            const SizedBox(height: 20),
            _rulesSection('Multiplayer', _multiplayerRules),
            const SizedBox(height: 20),
            _rulesSection('General', _generalRules),
          ],
        ),
      ),
    );
  }

  Widget _rulesSection(String title, List<String> rules) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        ...rules.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Color(0xFFFFD700), fontSize: 14)),
                Expanded(
                  child: Text(
                    r,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static const _singlePlayerRules = [
    'Choose a category and difficulty before each game.',
    'Answer as many questions as possible without getting one wrong — one wrong answer ends the game.',
    'You have 30 seconds per question. The timer starts the moment the question appears and cannot be paused.',
    'At 5 seconds remaining, the countdown pulses to warn you.',
    'A wrong answer triggers a screen shake. If you have a grace token, a "Use Grace Token?" prompt appears for 10 seconds — tap it to survive with your streak fully intact.',
    'Score = correct answers × your current streak multiplier (multiplier increases every 5 correct in a row, up to 5×).',
    'Earn 1 grace token every 10 correct answers. Tokens expire when the game ends and cannot be purchased or transferred.',
    'Only your personal best score appears on the leaderboard — not every game.',
    'Earn a badge for every 10 questions correct in a single game (10, 20, 30…).',
  ];

  static const _multiplayerRules = [
    'Challenge any T[root]H user by their account email address.',
    'You choose the category, difficulty, and number of questions (20, 25, or 30).',
    'Existing mentors/apprentices appear at the top for a quick challenge — no email needed.',
    'The challenged player must accept or decline — they have 7 days before the challenge expires.',
    'Both players answer the same questions independently. After both answer a question, the result is revealed.',
    'The next question unlocks only once both players have answered the current one.',
    'The player with the most points wins; ties are broken by total time used (faster wins).',
    'You have 30 seconds per question — timer starts when you open each question.',
    'Grace tokens do not apply in multiplayer.',
    'You may nudge your opponent once per day if they have not taken their turn yet.',
    'A challenge that sits with no activity for 7 days is automatically voided.',
  ];

  static const _generalRules = [
    'All questions are multiple choice — some are True/False.',
    'Questions are designed to challenge you — even plausible-sounding wrong answers are intentionally tricky.',
    'Scores and badges are permanent and visible on your profile.',
    'The 60-Day Launch Competition: top 3 players on the Challenger difficulty leaderboard (all categories, best score per player) win merch prizes.',
  ];
}
