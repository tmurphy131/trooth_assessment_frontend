import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'trivia_setup_screen.dart';
import 'trivia_challenge_detail_screen.dart';

class TriviaChallengeListScreen extends StatefulWidget {
  const TriviaChallengeListScreen({super.key});

  @override
  State<TriviaChallengeListScreen> createState() => _TriviaChallengeListScreenState();
}

class _TriviaChallengeListScreenState extends State<TriviaChallengeListScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _challenges = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final challenges = await _api.triviaListChallenges();
      if (mounted) setState(() { _challenges = challenges; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _cancelChallenge(Map<String, dynamic> c) async {
    final status = c['status'] as String? ?? '';
    final isFinished = status == 'complete' || status == 'cancelled';
    final label = isFinished ? 'Remove' : 'Cancel';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('$label challenge?', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        content: Text(
          isFinished
              ? 'This will remove the challenge from your list.'
              : 'This will cancel the challenge for both players.',
          style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(label, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.triviaCancelChallenge(c['id'] as String);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        title: const Text(
          'Challenges',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFFD700)),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TriviaSetupScreen(mode: TriviaMode.multiplayer)),
        ).then((_) => _load()),
        backgroundColor: const Color(0xFFFFD700),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('New Challenge', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_challenges.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline, color: Colors.white38, size: 56),
              const SizedBox(height: 16),
              const Text(
                'No challenges yet',
                style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Challenge a friend or teammate to a Bible trivia match!',
                style: TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Sort: action needed first, then pending, then complete/expired
    final sorted = [..._challenges]..sort((a, b) {
      int _priority(Map<String, dynamic> c) {
        if (c['is_my_turn'] == true) return 0;
        final s = c['status'] as String? ?? '';
        if (s == 'pending') return 1;
        if (s == 'active') return 2;
        return 3;
      }
      return _priority(a).compareTo(_priority(b));
    });

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFFFFD700),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: sorted.length,
        itemBuilder: (_, i) => _buildChallengeCard(sorted[i]),
      ),
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> c) {
    final status = c['status'] as String? ?? '';
    final isMyTurn = c['is_my_turn'] == true;
    final myRole = c['my_role'] as String? ?? '';
    final challengerName = c['challenger_name'] as String? ?? '';
    final challengedName = c['challenged_name'] as String? ?? '';
    final category = _formatCategory(c['category'] as String? ?? '');
    final difficulty = _capitalize(c['difficulty'] as String? ?? '');
    final numQ = c['num_questions'] as int? ?? 0;
    final cScore = c['challenger_score'] as int? ?? 0;
    final dScore = c['challenged_score'] as int? ?? 0;

    String opponentName = myRole == 'challenger' ? challengedName : challengerName;

    final (statusLabel, statusColor) = _statusInfo(status, isMyTurn, myRole);

    return Dismissible(
      key: ValueKey(c['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('Cancel', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 11)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _cancelChallenge(c);
        return false; // _load() inside _cancelChallenge handles the list refresh
      },
      child: GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TriviaChallengeDetailScreen(challengeId: c['id'] as String),
        ),
      ).then((_) => _load()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMyTurn ? const Color(0xFFFFD700).withOpacity(0.5) : Colors.grey[800]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'vs $opponentName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _tag(category),
                const SizedBox(width: 6),
                _tag(difficulty),
                const SizedBox(width: 6),
                _tag('$numQ Qs'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.sports_score, color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$cScore — $dScore',
                  style: const TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 12),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
              ],
            ),
          ],
        ),
      ),
    ));
  }

  (String, Color) _statusInfo(String status, bool isMyTurn, String myRole) {
    if (status == 'pending') {
      return myRole == 'challenged'
          ? ('Accept/Decline', Colors.orangeAccent)
          : ('Waiting for Accept', Colors.white54);
    }
    if (status == 'active') {
      return isMyTurn ? ('Your Turn', const Color(0xFFFFD700)) : ('Their Turn', Colors.blueAccent);
    }
    if (status == 'complete') return ('Complete', Colors.greenAccent);
    if (status == 'declined') return ('Declined', Colors.redAccent);
    if (status == 'expired') return ('Expired', Colors.grey);
    return (status, Colors.white54);
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white60, fontFamily: 'Poppins', fontSize: 11),
      ),
    );
  }

  String _formatCategory(String s) {
    switch (s) {
      case 'old_testament': return 'Old Testament';
      case 'new_testament': return 'New Testament';
      case 'theology_doctrine': return 'Theology';
      case 'discipleship_living': return 'Discipleship';
      case 'random': return 'Random';
      default: return s;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
