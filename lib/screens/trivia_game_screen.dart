import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'trivia_result_screen.dart';
import '../services/api_service.dart';

class TriviaGameScreen extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final String category;
  final String difficulty;

  const TriviaGameScreen({
    super.key,
    required this.questions,
    required this.category,
    required this.difficulty,
  });

  @override
  State<TriviaGameScreen> createState() => _TriviaGameScreenState();
}

class _TriviaGameScreenState extends State<TriviaGameScreen>
    with TickerProviderStateMixin {
  // Game state
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;
  int _correctCount = 0;
  int _graceTokens = 0;
  int _graceTokensUsed = 0;
  final List<Map<String, dynamic>> _answers = [];
  late List<Map<String, dynamic>> _questions;
  bool _isFetchingMore = false;
  final Set<int> _seenIds = {};

  // Timer
  static const _questionSeconds = 30;
  int _timeLeft = _questionSeconds;
  Timer? _timer;
  int _questionStartMs = 0;

  // Animation controllers
  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late AnimationController _fadeInController;
  late Animation<double> _shakeAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeInAnim;

  // Grace token state
  bool _showGracePrompt = false;
  Timer? _graceTimer;
  int _graceCountdown = 10;

  String? _selectedOption;
  bool _answered = false;

  @override
  void initState() {
    super.initState();

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

    _questions = List.from(widget.questions);
    for (final q in _questions) {
      _seenIds.add(q['id'] as int);
    }
    _startQuestion();
  }

  Future<void> _fetchMoreQuestions() async {
    if (_isFetchingMore) return;
    _isFetchingMore = true;
    try {
      final more = await ApiService().triviaDrawQuestions(
        category: widget.category,
        difficulty: widget.difficulty,
        count: 50,
      );
      final fresh = more.where((q) => !_seenIds.contains(q['id'] as int)).toList();
      if (mounted && fresh.isNotEmpty) {
        setState(() {
          for (final q in fresh) {
            _seenIds.add(q['id'] as int);
          }
          _questions.addAll(fresh);
        });
      }
    } catch (_) {
      // Silently fail — game ends naturally if pool is exhausted
    } finally {
      _isFetchingMore = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _graceTimer?.cancel();
    _shakeController.dispose();
    _pulseController.dispose();
    _fadeInController.dispose();
    super.dispose();
  }

  void _startQuestion() {
    _selectedOption = null;
    _answered = false;
    _showGracePrompt = false;
    _timeLeft = _questionSeconds;
    _questionStartMs = DateTime.now().millisecondsSinceEpoch;
    _fadeInController.forward(from: 0);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) {
          t.cancel();
          _handleTimeUp();
        }
      });
    });
  }

  void _handleTimeUp() {
    if (_answered) return;
    _onAnswer(null); // treat as wrong
  }

  int get _multiplier {
    if (_streak < 5) return 1;
    if (_streak < 10) return 2;
    if (_streak < 15) return 3;
    if (_streak < 20) return 4;
    return 5;
  }

  void _onAnswer(String? option) {
    if (_answered) return;
    _timer?.cancel();

    final q = _questions[_currentIndex];
    final correct = q['correct_option'] as String? ?? q['correct'] as String?;
    final isCorrect = option != null && option == correct;
    final timeUsedMs = DateTime.now().millisecondsSinceEpoch - _questionStartMs;

    _answers.add({
      'question_id': q['id'],
      'selected': option ?? '',
      'time_used_ms': timeUsedMs,
    });

    setState(() {
      _answered = true;
      _selectedOption = option;
    });

    if (isCorrect) {
      _streak++;
      _correctCount++;
      _score += 100 * _multiplier;
      // Grant a grace token every 10 correct answers
      if (_correctCount % 10 == 0) _graceTokens++;

      // Brief pause to show result, then advance
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        _nextQuestion();
      });
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);

      if (_graceTokens > 0) {
        setState(() { _showGracePrompt = true; _graceCountdown = 10; });
        _graceTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted) { t.cancel(); return; }
          setState(() => _graceCountdown--);
          if (_graceCountdown <= 0) {
            t.cancel();
            if (_showGracePrompt) _endGame();
          }
        });
      } else {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _endGame();
        });
      }
    }
  }

  void _useGraceToken() {
    _graceTimer?.cancel();
    // Remove the wrong answer that triggered this grace prompt so the backend
    // doesn't see it when computing the final score — streak must be preserved.
    if (_answers.isNotEmpty) _answers.removeLast();
    setState(() {
      _showGracePrompt = false;
      _graceTokens--;
      _graceTokensUsed++;
      _answered = false;
      _selectedOption = null;
    });
    // Restart the timer on the same question
    _startQuestion();
  }

  void _nextQuestion() {
    final nextIndex = _currentIndex + 1;

    // Pre-fetch more questions when 10 remain
    if (_questions.length - nextIndex <= 10) {
      _fetchMoreQuestions();
    }

    if (nextIndex >= _questions.length) {
      // Pool temporarily exhausted — wait briefly for fetch then retry
      if (_isFetchingMore) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _nextQuestion();
        });
      } else {
        _endGame();
      }
      return;
    }

    setState(() => _currentIndex = nextIndex);
    _startQuestion();
  }

  void _endGame() {
    _timer?.cancel();
    _graceTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TriviaResultScreen(
          score: _score,
          streakLength: _streak,
          correctCount: _correctCount,
          category: widget.category,
          difficulty: widget.difficulty,
          answers: _answers,
          graceTokensUsed: _graceTokensUsed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_currentIndex];
    final options = _buildOptions(q);
    final isPulsing = _timeLeft <= 5;

    return WillPopScope(
      onWillPop: () async {
        final leave = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Leave game?', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
            content: const Text(
              'Your current game progress will be lost.',
              style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave', style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        );
        return leave == true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeInAnim,
            child: Column(
              children: [
                _buildHeader(isPulsing),
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildQuestionCard(q),
                          const SizedBox(height: 20),
                          ...options.map((o) => _buildOptionButton(o.$1, o.$2, q)),
                          const Spacer(),
                          if (_showGracePrompt) _buildGracePrompt(),
                          const SizedBox(height: 20),
                        ],
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

  void _confirmQuit() {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Quit game?', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        content: const Text(
          'Your score will be saved and you\'ll be taken to the results screen.',
          style: TextStyle(color: Colors.white70, fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Playing')),
          TextButton(
            onPressed: () { Navigator.pop(context, true); _endGame(); },
            child: const Text('Quit', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isPulsing) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      color: Colors.black,
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _confirmQuit,
                child: const Icon(Icons.close, color: Colors.white54, size: 22),
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
                    _score.toString(),
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
                  const Text('seconds', style: TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 10)),
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
                        _streak.toString(),
                        style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 22),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _multiplierColor(_multiplier),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_multiplier}x',
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
              Text(
                'Q${_currentIndex + 1}',
                style: const TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 11),
              ),
              if (_graceTokens > 0)
                Row(
                  children: [
                    const Icon(Icons.shield, color: Colors.greenAccent, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      '$_graceTokens grace token${_graceTokens > 1 ? 's' : ''}',
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

  Widget _buildQuestionCard(Map<String, dynamic> q) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Text(
        q['question_text'] as String? ?? '',
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

  List<(String, String)> _buildOptions(Map<String, dynamic> q) {
    final opts = <(String, String)>[];
    final labels = ['a', 'b', 'c', 'd'];
    final names = ['A', 'B', 'C', 'D'];
    for (var i = 0; i < labels.length; i++) {
      final val = q['option_${labels[i]}'] as String?;
      if (val != null && val.isNotEmpty) {
        opts.add((labels[i], '${names[i]}. $val'));
      }
    }
    return opts;
  }

  Widget _buildOptionButton(String key, String label, Map<String, dynamic> q) {
    final correct = q['correct_option'] as String? ?? q['correct'] as String?;
    Color bg = Colors.grey[900]!;
    Color border = Colors.grey[800]!;
    Color textColor = Colors.white;

    if (_answered) {
      if (key == correct) {
        bg = Colors.green.withOpacity(0.2);
        border = Colors.green;
        textColor = Colors.greenAccent;
      } else if (key == _selectedOption) {
        bg = Colors.red.withOpacity(0.2);
        border = Colors.redAccent;
        textColor = Colors.redAccent;
      }
    } else if (key == _selectedOption) {
      bg = const Color(0xFFFFD700).withOpacity(0.15);
      border = const Color(0xFFFFD700);
    }

    return GestureDetector(
      onTap: _answered ? null : () => _onAnswer(key),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.15),
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
            'Survive this wrong answer — streak preserved!',
            style: TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _useGraceToken,
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
                '$_graceCountdown',
                style: TextStyle(
                  color: _graceCountdown <= 3 ? Colors.redAccent : Colors.white54,
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
