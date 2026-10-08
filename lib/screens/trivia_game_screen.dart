import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'trivia_result_screen.dart';
import '../models/trivia_session.dart';
import '../services/api_service.dart';
import '../utils/errors.dart';

/// Single-player game driven by a server session (backend spec 001).
///
/// The server grades and times every answer. This screen only renders the
/// latest [TriviaSessionState] and sends one answer per question. Both
/// countdowns are deadlines on the real clock, so leaving the app doesn't
/// pause them; they're re-checked as soon as the app returns.
class TriviaGameScreen extends StatefulWidget {
  final TriviaSessionState initialState;
  final String category;
  final String difficulty;

  /// Clock override for widget tests.
  @visibleForTesting
  final DateTime Function()? now;

  const TriviaGameScreen({
    super.key,
    required this.initialState,
    required this.category,
    required this.difficulty,
    this.now,
  });

  @override
  State<TriviaGameScreen> createState() => _TriviaGameScreenState();
}

class _TriviaGameScreenState extends State<TriviaGameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _api = ApiService();

  late TriviaSessionState _state;
  TriviaSessionQuestion? _question;     // the question on screen (kept while feedback shows)
  TriviaLastAnswer? _feedback;          // grading of the answer just sent
  String? _picked;
  ({int questionId, String? selected})? _lastSent;
  DateTime? _questionDeadline;
  DateTime? _graceDeadline;
  int _frozenSecondsLeft = 0;           // shown once the player has answered
  bool _busy = false;
  bool _done = false;
  Timer? _ticker;

  // Animation controllers
  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late AnimationController _fadeInController;
  late Animation<double> _shakeAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeInAnim;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(_shakeController);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeInAnim = CurvedAnimation(parent: _fadeInController, curve: Curves.easeIn);

    _apply(widget.initialState);
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _shakeController.dispose();
    _pulseController.dispose();
    _fadeInController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Time kept running while we were away: act on any deadline that passed
    if (state == AppLifecycleState.resumed) _tick();
  }

  // ---------- State ----------

  /// Show [s]: next question, grace prompt, or results. Call inside setState.
  void _apply(TriviaSessionState s) {
    _state = s;
    switch (s.status) {
      case TriviaSessionStatus.active:
        _question = s.question;
        _feedback = null;
        _picked = null;
        _graceDeadline = null;
        _questionDeadline = _now().add(Duration(milliseconds: s.timeLimitMs));
        _fadeInController.forward(from: 0);
      case TriviaSessionStatus.awaitingGrace:
        _questionDeadline = null;
        _graceDeadline = _now().add(Duration(milliseconds: s.graceExpiresInMs ?? 10000));
      case TriviaSessionStatus.finished:
        _questionDeadline = null;
        _graceDeadline = null;
        final result = s.result;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (result != null) {
            _showResults(result);
          } else {
            _finishAndShowResults();
          }
        });
    }
  }

  int _secondsLeft(DateTime? deadline) {
    if (deadline == null) return 0;
    final ms = deadline.difference(_now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  bool get _awaitingAnswer =>
      _state.status == TriviaSessionStatus.active && _feedback == null && !_busy && !_done;

  void _tick() {
    if (!mounted || _done || _busy) return;
    final now = _now();
    if (_awaitingAnswer && _questionDeadline != null && !now.isBefore(_questionDeadline!)) {
      _submit(null); // time's up (also when we come back from the background)
      return;
    }
    if (_state.status == TriviaSessionStatus.awaitingGrace &&
        _graceDeadline != null &&
        !now.isBefore(_graceDeadline!)) {
      _decideGrace(false);
      return;
    }
    setState(() {}); // repaint countdowns
  }

  // ---------- Actions ----------

  Future<void> _submit(String? letter) async {
    final q = _question;
    if (q == null || !_awaitingAnswer) return;
    setState(() {
      _busy = true;
      _picked = letter;
      _frozenSecondsLeft = _secondsLeft(_questionDeadline);
      _questionDeadline = null;
    });
    _lastSent = (questionId: q.id, selected: letter);

    final res = await _call(() => _api.triviaAnswerSingle(_state.sessionId, questionId: q.id, selected: letter));
    if (!mounted || res == null) return;

    final answer = res.lastAnswer;
    setState(() {
      _busy = false;
      _feedback = answer;
      _state = res;
      if (res.status == TriviaSessionStatus.awaitingGrace) _apply(res); // grace countdown starts now
    });
    if (answer != null && !answer.correct) {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);
    }
    if (res.status == TriviaSessionStatus.awaitingGrace) return;

    // Brief pause to show the result, then move on
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted || _done) return;
    setState(() => _apply(res));
  }

  Future<void> _decideGrace(bool use) async {
    if (_busy || _done || _state.status != TriviaSessionStatus.awaitingGrace) return;
    setState(() {
      _busy = true;
      _graceDeadline = null;
    });
    final res = await _call(() => _api.triviaGraceSingle(_state.sessionId, use: use));
    if (!mounted || res == null) return;
    setState(() {
      _busy = false;
      _apply(res);
    });
  }

  /// Runs a session request: one automatic retry, then Retry/Leave.
  /// 409 (our view is stale) re-syncs; 404 leaves.
  Future<TriviaSessionState?> _call(Future<TriviaSessionState> Function() request) async {
    try {
      return await _withRetry(request);
    } on ApiException catch (e) {
      if (e.statusCode == 409) return _resync();
      if (e.statusCode == 404) {
        _exitWithMessage(e);
        return null;
      }
      return _connectionProblem(e, request);
    } catch (e) {
      return _connectionProblem(e, request);
    }
  }

  Future<T> _withRetry<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on NetworkException {
      return await request();
    } on ApiException catch (e) {
      if (e.isServerError) return await request();
      rethrow;
    }
  }

  /// Our view is out of date (game over or grace pending). Re-sending the last
  /// answer makes the server replay its current state, whatever it is.
  Future<TriviaSessionState?> _resync() async {
    final last = _lastSent;
    if (last != null) {
      try {
        return await _withRetry(() => _api.triviaAnswerSingle(
              _state.sessionId,
              questionId: last.questionId,
              selected: last.selected,
            ));
      } catch (_) {
        // Fall through: end the game and show what was saved
      }
    }
    await _finishAndShowResults();
    return null;
  }

  Future<TriviaSessionState?> _connectionProblem(
    Object error,
    Future<TriviaSessionState> Function() request,
  ) async {
    if (!mounted) return null;
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Connection problem', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        content: Text(friendlyError(error), style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Leave', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Retry')),
        ],
      ),
    );
    if (!mounted) return null;
    if (retry == true) return _call(request);
    await _finishAndShowResults();
    return null;
  }

  void _exitWithMessage(Object error) {
    if (!mounted) return;
    _done = true;
    _ticker?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(error))));
    Navigator.of(context).pop();
  }

  /// End the game on the server (idempotent) and show the saved result.
  Future<void> _finishAndShowResults() async {
    if (_done) return;
    _done = true;
    _ticker?.cancel();
    try {
      final result = await _withRetry(() => _api.triviaFinishSingle(_state.sessionId));
      if (!mounted) return;
      _showResults(result, force: true);
    } catch (e) {
      // The server closes the game on its own once the question expires
      if (!mounted) return;
      _exitWithMessage(e);
    }
  }

  void _showResults(Map<String, dynamic> result, {bool force = false}) {
    if (_done && !force) return;
    _done = true;
    _ticker?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TriviaResultScreen(
          result: result,
          category: widget.category,
          difficulty: widget.difficulty,
        ),
      ),
    );
  }

  Future<void> _confirmQuit() async {
    if (_done) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Quit game?', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        content: const Text(
          'Your game will end and your score so far will be saved.',
          style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep Playing')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Quit', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (leave == true && mounted) await _finishAndShowResults();
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final q = _question;
    final answered = _feedback != null || _busy;
    final secondsLeft = answered ? _frozenSecondsLeft : _secondsLeft(_questionDeadline);
    final isPulsing = !answered && _state.status == TriviaSessionStatus.active && secondsLeft <= 5;

    return PopScope(
      canPop: _done,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmQuit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: q == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
              : FadeTransition(
                  opacity: _fadeInAnim,
                  child: Column(
                    children: [
                      _buildHeader(isPulsing, secondsLeft),
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _shakeAnim,
                          builder: (context, child) {
                            final shake = sin(_shakeAnim.value * pi * 6) * 12;
                            return Transform.translate(
                              offset: Offset(shake, 0),
                              child: child,
                            );
                          },
                          // Scrolls on short screens / large text so the grace prompt is
                          // always reachable; otherwise it sits at the bottom as before.
                          child: LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                child: IntrinsicHeight(
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 20),
                                      _buildQuestionCard(q),
                                      const SizedBox(height: 20),
                                      ..._buildOptions(q).map((o) => _buildOptionButton(o.$1, o.$2)),
                                      const Spacer(),
                                      if (_state.status == TriviaSessionStatus.awaitingGrace) _buildGracePrompt(),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isPulsing, int secondsLeft) {
    final multiplier = _state.multiplier;
    final graceTokens = _state.graceTokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      color: Colors.black,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Quit game',
                onPressed: _confirmQuit,
                icon: const Icon(Icons.close, color: Colors.white70, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Score
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Score', style: TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 11)),
                  Text(
                    _state.score.toString(),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                ],
              ),
              // Timer
              Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Transform.scale(
                      scale: isPulsing ? _pulseAnim.value : 1.0,
                      child: Text(
                        secondsLeft.toString(),
                        style: TextStyle(
                          color: isPulsing ? Colors.redAccent : const Color(0xFFFFD700),
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          fontSize: 36,
                        ),
                      ),
                    ),
                  ),
                  const Text('seconds', style: TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 11)),
                ],
              ),
              // Streak + multiplier
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Streak', style: TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 11)),
                  Row(
                    children: [
                      Text(
                        _state.streak.toString(),
                        style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 22),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _multiplierColor(multiplier),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${multiplier}x',
                          style: const TextStyle(
                            color: Colors.black,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(
                'Q${(_question?.index ?? 0) + 1}',
                style: const TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 11),
              )),
              if (graceTokens > 0)
                Row(
                  children: [
                    const Icon(Icons.shield, color: Colors.greenAccent, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      '$graceTokens grace token${graceTokens > 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Poppins', fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(TriviaSessionQuestion q) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Text(
        q.text,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 16,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  List<(String, String)> _buildOptions(TriviaSessionQuestion q) {
    return [
      for (final entry in q.options.entries) (entry.key, '${entry.key.toUpperCase()}. ${entry.value}'),
    ];
  }

  Widget _buildOptionButton(String key, String label) {
    final feedback = _feedback;
    Color bg = Colors.grey[900]!;
    Color border = Colors.grey[800]!;
    Color textColor = Colors.white;

    if (feedback != null) {
      if (key == feedback.correctOption) {
        bg = Colors.green.withValues(alpha: 0.2);
        border = Colors.green;
        textColor = Colors.greenAccent;
      } else if (key == _picked) {
        bg = Colors.red.withValues(alpha: 0.2);
        border = Colors.redAccent;
        textColor = Colors.redAccent;
      }
    } else if (key == _picked) {
      bg = const Color(0xFFFFD700).withValues(alpha: 0.15);
      border = const Color(0xFFFFD700);
    }

    return GestureDetector(
      onTap: _awaitingAnswer ? () => _submit(key) : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildGracePrompt() {
    final graceLeft = _secondsLeft(_graceDeadline);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield, color: Colors.greenAccent, size: 18),
              SizedBox(width: 6),
              Text(
                'Use Grace Token?',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Keep your streak and move on to the next question.',
            style: TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _busy ? null : () => _decideGrace(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'Use Token',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$graceLeft',
                style: TextStyle(
                  color: graceLeft <= 3 ? Colors.redAccent : Colors.white54,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _multiplierColor(int m) {
    switch (m) {
      case 1: return Colors.grey;
      case 2: return Colors.blueAccent;
      case 3: return Colors.purpleAccent;
      case 4: return Colors.orangeAccent;
      default: return const Color(0xFFFFD700);
    }
  }
}
