import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class TriviaChallengeDetailScreen extends StatefulWidget {
  final String challengeId;

  const TriviaChallengeDetailScreen({super.key, required this.challengeId});

  @override
  State<TriviaChallengeDetailScreen> createState() => _TriviaChallengeDetailScreenState();
}

class _TriviaChallengeDetailScreenState extends State<TriviaChallengeDetailScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  Map<String, dynamic>? _challenge;
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  // Answer timer
  static const _questionSeconds = 30;
  int _timeLeft = _questionSeconds;
  Timer? _answerTimer;
  int _answerStartMs = 0;
  bool _isAnswering = false;
  String? _selectedOption;
  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.25)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _load();
    // Poll every 10 seconds when waiting on opponent
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _shouldPoll()) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _answerTimer?.cancel();
    _shakeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  bool _shouldPoll() {
    final status = _challenge?['status'] as String?;
    final isMyTurn = _challenge?['is_my_turn'] as bool? ?? false;
    return status == 'active' && !isMyTurn;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _api.triviaGetChallenge(widget.challengeId);
      if (mounted) {
        final wasMyTurn = _challenge?['is_my_turn'] as bool? ?? false;
        final isNowMyTurn = data['is_my_turn'] as bool? ?? false;
        setState(() {
          _challenge = data;
          _isLoading = false;
          // If it just became our turn, start answering mode
          if (!wasMyTurn && isNowMyTurn && !_isAnswering) {
            _startAnswering();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _startAnswering() {
    _selectedOption = null;
    _timeLeft = _questionSeconds;
    _answerStartMs = DateTime.now().millisecondsSinceEpoch;
    _isAnswering = true;

    _answerTimer?.cancel();
    _answerTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) {
          t.cancel();
          _submitAnswer(null); // time up = wrong
        }
      });
    });
  }

  void _stopAnswering() {
    _answerTimer?.cancel();
    _isAnswering = false;
  }

  Future<void> _submitAnswer(String? selected) async {
    _stopAnswering();
    final timeUsedMs = DateTime.now().millisecondsSinceEpoch - _answerStartMs;
    final questions = _currentQuestions;
    if (questions.isEmpty) return;

    final currentIdx = _challenge?['current_question_index'] as int? ?? 0;
    final qState = questions.firstWhere(
      (q) => (q['question_index'] as int?) == currentIdx,
      orElse: () => questions.last,
    );
    final questionId = qState['question']['id'] as int?;
    if (questionId == null) return;

    setState(() => _selectedOption = selected);

    try {
      await _api.triviaSubmitChallengeAnswer(widget.challengeId, {
        'question_id': questionId,
        'selected': selected ?? '',
        'time_used_ms': timeUsedMs,
      });
      await _load(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit answer: $e'), backgroundColor: Colors.redAccent),
        );
        _startAnswering(); // allow retry
      }
    }
  }

  Future<void> _nudge() async {
    try {
      await _api.triviaNudge(widget.challengeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nudge sent!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('once per day') ? 'You can only nudge once per day.' : 'Failed to nudge: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _acceptChallenge() async {
    try {
      await _api.triviaAcceptChallenge(widget.challengeId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _declineChallenge() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Decline Challenge?', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        content: const Text('Are you sure you want to decline?', style: TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Decline', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.triviaDeclineChallenge(widget.challengeId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _currentQuestions {
    final qs = _challenge?['questions'] as List?;
    if (qs == null) return [];
    return qs.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        title: const Text(
          'Challenge',
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFFFFD700)), onPressed: () => _load()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
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

  Widget _buildContent() {
    final c = _challenge!;
    final status = c['status'] as String? ?? '';
    final myRole = c['my_role'] as String? ?? '';
    final isMyTurn = c['is_my_turn'] as bool? ?? false;
    final challengerName = c['challenger_name'] as String? ?? '';
    final challengedName = c['challenged_name'] as String? ?? '';
    final challengerScore = c['challenger_score'] as int? ?? 0;
    final challengedScore = c['challenged_score'] as int? ?? 0;
    final currentQIdx = c['current_question_index'] as int? ?? 0;
    final numQ = c['num_questions'] as int? ?? 0;
    final questions = _currentQuestions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — players + scores
          _buildScoreHeader(challengerName, challengedName, challengerScore, challengedScore, myRole),
          const SizedBox(height: 16),

          // Status / progress
          _buildProgressBar(currentQIdx, numQ),
          const SizedBox(height: 20),

          // Pending state — accept/decline
          if (status == 'pending' && myRole == 'challenged') ...[
            _buildAcceptDeclineCard(challengerName),
          ] else if (status == 'pending') ...[
            _waitingCard('Waiting for ${challengedName} to accept the challenge.'),
          ] else if (status == 'active') ...[
            if (isMyTurn || _isAnswering)
              _buildAnswerSection(questions, currentQIdx)
            else
              _buildWaitingSection(challengedName, challengerName, myRole),
          ] else if (status == 'complete') ...[
            _buildResultSection(c),
          ] else if (status == 'declined') ...[
            _buildSimpleCard('Challenge Declined', '${challengedName} declined this challenge.', Colors.redAccent),
          ] else if (status == 'expired') ...[
            _buildSimpleCard('Challenge Expired', 'This challenge expired due to inactivity.', Colors.grey),
          ],

          const SizedBox(height: 24),

          // Revealed questions history
          if (questions.isNotEmpty) ...[
            const Text('Question History', style: TextStyle(color: Color(0xFFFFD700), fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            ...questions.where((q) => q['revealed'] == true).map((q) => _buildRevealedQuestion(q, myRole)),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreHeader(String challenger, String challenged, int cScore, int dScore, String myRole) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  challenger,
                  style: TextStyle(
                    color: myRole == 'challenger' ? const Color(0xFFFFD700) : Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (myRole == 'challenger')
                  const Text('(you)', style: TextStyle(color: Colors.white38, fontFamily: 'Poppins', fontSize: 10)),
                const SizedBox(height: 6),
                Text(
                  cScore.toString(),
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 28),
                ),
              ],
            ),
          ),
          const Text('vs', style: TextStyle(color: Colors.white38, fontFamily: 'Poppins', fontSize: 14)),
          Expanded(
            child: Column(
              children: [
                Text(
                  challenged,
                  style: TextStyle(
                    color: myRole == 'challenged' ? const Color(0xFFFFD700) : Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (myRole == 'challenged')
                  const Text('(you)', style: TextStyle(color: Colors.white38, fontFamily: 'Poppins', fontSize: 10)),
                const SizedBox(height: 6),
                Text(
                  dScore.toString(),
                  style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 28),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(int current, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Question $current / $total', style: const TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? current / total : 0,
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildAcceptDeclineCard(String challengerName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 36),
          const SizedBox(height: 10),
          Text(
            '$challengerName challenged you!',
            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _declineChallenge,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Decline', style: TextStyle(color: Colors.redAccent, fontFamily: 'Poppins')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _acceptChallenge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Accept', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerSection(List<Map<String, dynamic>> questions, int currentIdx) {
    // Find current question state
    final qState = questions.firstWhere(
      (q) => (q['question_index'] as int?) == currentIdx,
      orElse: () => <String, dynamic>{},
    );

    if (qState.isEmpty) {
      // My answer already submitted — waiting for opponent reveal
      return _waitingCard('Your answer has been submitted. Waiting for your opponent…');
    }

    final myAnswer = qState['my_answer'] as String?;
    if (myAnswer != null) {
      return _waitingCard('Your answer has been submitted. Waiting for your opponent…');
    }

    final q = qState['question'] as Map<String, dynamic>? ?? {};
    final questionText = q['question_text'] as String? ?? '';
    final isPulsing = _timeLeft <= 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timer row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: isPulsing ? _pulseAnim.value : 1.0,
                child: Text(
                  _timeLeft.toString(),
                  style: TextStyle(
                    color: isPulsing ? Colors.redAccent : const Color(0xFFFFD700),
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text('seconds', style: TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        // Question card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Text(
            questionText,
            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 15, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        // Options
        ..._buildAnswerOptions(q),
      ],
    );
  }

  List<Widget> _buildAnswerOptions(Map<String, dynamic> q) {
    final opts = <Widget>[];
    final labels = ['a', 'b', 'c', 'd'];
    final names = ['A', 'B', 'C', 'D'];
    for (var i = 0; i < labels.length; i++) {
      final val = q['option_${labels[i]}'] as String?;
      if (val == null || val.isEmpty) continue;
      final key = labels[i];
      final label = '${names[i]}. $val';
      final selected = _selectedOption == key;

      opts.add(
        GestureDetector(
          onTap: _selectedOption != null ? null : () {
            HapticFeedback.selectionClick();
            setState(() => _selectedOption = key);
            _submitAnswer(key);
          },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFD700).withOpacity(0.15) : Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? const Color(0xFFFFD700) : Colors.grey[800]!,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFFFFD700) : Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }
    return opts;
  }

  Widget _buildWaitingSection(String challengedName, String challengerName, String myRole) {
    final opponentName = myRole == 'challenger' ? challengedName : challengerName;
    return Column(
      children: [
        _waitingCard('Waiting for $opponentName to answer…'),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _nudge,
            icon: const Icon(Icons.notifications_active, size: 16),
            label: const Text('Nudge Opponent', style: TextStyle(fontFamily: 'Poppins')),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white38),
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection(Map<String, dynamic> c) {
    final winnerId = c['winner_id'] as String?;
    final myRole = c['my_role'] as String? ?? '';
    final challengerId = c['challenger_id'] as String? ?? '';
    final challengedId = c['challenged_id'] as String? ?? '';
    final myId = myRole == 'challenger' ? challengerId : challengedId;

    String resultLabel;
    Color resultColor;
    IconData resultIcon;

    if (winnerId == null) {
      resultLabel = 'It\'s a Tie!';
      resultColor = Colors.blueAccent;
      resultIcon = Icons.handshake;
    } else if (winnerId == myId) {
      resultLabel = 'You Won! 🎉';
      resultColor = const Color(0xFFFFD700);
      resultIcon = Icons.emoji_events;
    } else {
      resultLabel = 'You Lost';
      resultColor = Colors.redAccent;
      resultIcon = Icons.sports_score;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: resultColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: resultColor.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Icon(resultIcon, color: resultColor, size: 40),
          const SizedBox(height: 10),
          Text(
            resultLabel,
            style: TextStyle(color: resultColor, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ],
      ),
    );
  }

  Widget _waitingCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),
          const CircularProgressIndicator(color: Color(0xFFFFD700), strokeWidth: 2),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 13, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleCard(String title, String message, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: color, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildRevealedQuestion(Map<String, dynamic> qState, String myRole) {
    final q = qState['question'] as Map<String, dynamic>? ?? {};
    final questionText = q['question_text'] as String? ?? '';
    final myAnswer = qState['my_answer'] as String?;
    final opponentAnswer = qState['opponent_answer'] as String?;
    final myCorrect = qState['my_correct'] as bool?;
    final opponentCorrect = qState['opponent_correct'] as bool?;
    final idx = qState['question_index'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q${idx + 1}. $questionText',
            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _answerChip('You', myAnswer ?? '—', myCorrect),
              const SizedBox(width: 8),
              _answerChip('Opponent', opponentAnswer ?? '—', opponentCorrect),
            ],
          ),
        ],
      ),
    );
  }

  Widget _answerChip(String label, String answer, bool? correct) {
    final color = correct == null ? Colors.white38 : correct ? Colors.greenAccent : Colors.redAccent;
    final icon = correct == null ? Icons.hourglass_empty : correct ? Icons.check_circle : Icons.cancel;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white38, fontFamily: 'Poppins', fontSize: 10)),
                  Text(answer.toUpperCase(), style: TextStyle(color: color, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
