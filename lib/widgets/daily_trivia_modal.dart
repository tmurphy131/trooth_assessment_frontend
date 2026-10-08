import 'package:flutter/material.dart';

import '../models/daily_trivia.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/errors.dart';
import 'daily_streak_view.dart';

/// Opens the daily question modal (backend/app spec 002). It never opens on
/// its own: the dashboard pill, notification taps, the profile card and the
/// Trivia card call [open].
class DailyTriviaPrompt {
  static bool _showing = false;

  /// Bumped whenever today's question is answered, so the pill and cards refresh.
  static final answered = ValueNotifier<int>(0);

  static Future<void> open(BuildContext context, {DailyToday? initial}) async {
    if (_showing) return;
    _showing = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => DailyTriviaModal(initial: initial),
      );
    } finally {
      _showing = false;
    }
  }
}

/// Today's question with its category and level, then the result and streak.
class DailyTriviaModal extends StatefulWidget {
  const DailyTriviaModal({super.key, this.initial, this.today});

  /// Already-loaded data (e.g. from the dashboard pill); otherwise it loads.
  final DailyToday? initial;

  /// Passed to the streak view; injectable for tests.
  final DateTime? today;

  @override
  State<DailyTriviaModal> createState() => _DailyTriviaModalState();
}

class _DailyTriviaModalState extends State<DailyTriviaModal> {
  final _api = ApiService();
  DailyToday? _data;
  DailyAnswerOutcome? _outcome;
  bool _loading = false;
  String? _submitting;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _data = widget.initial;
    if (_data == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.dailyTriviaToday();
      if (!mounted) return;
      setState(() {
        _data = data;
        _outcome = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _answer(String option) async {
    final data = _data;
    if (data == null || _submitting != null) return;
    setState(() {
      _submitting = option;
      _error = null;
      _notice = null;
    });
    try {
      final outcome = await _api.dailyTriviaAnswer(questionDate: data.question.date, option: option);
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _submitting = null;
      });
      DailyTriviaPrompt.answered.value++;
    } on DailyQuestionExpiredException catch (e) {
      if (!mounted) return;
      setState(() {
        _notice = e.toString();
        _submitting = null;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _submitting = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF121212),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: kPrimaryGold.withValues(alpha: 0.5)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _titleRow(),
                ..._body(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleRow() {
    return Row(
      children: [
        Expanded(
          child: Text('Daily Question',
              style: TextStyle(color: kPrimaryGold, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 20)),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  List<Widget> _body() {
    final data = _data;
    if (data == null) {
      if (_loading) {
        return const [
          Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
        ];
      }
      return [
        const SizedBox(height: 12),
        Text(_error ?? 'Something went wrong. Please try again.',
            style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 14)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _load, child: const Text('Try again')),
      ];
    }

    final question = _outcome?.question ?? data.question;
    final answer = _outcome?.answer ?? data.answer;
    final streak = _outcome?.streak ?? data.streak;
    return [
      if (_notice != null) ...[
        Text(_notice!, style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 13)),
        const SizedBox(height: 8),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip(question.categoryLabel, Icons.menu_book_outlined),
          _chip(question.difficultyLabel, Icons.signal_cellular_alt),
        ],
      ),
      const SizedBox(height: 14),
      Text(question.text,
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 17)),
      const SizedBox(height: 14),
      for (final entry in question.options.entries) ...[
        _OptionButton(
          letter: entry.key,
          text: entry.value,
          state: _optionState(entry.key, answer),
          busy: _submitting == entry.key,
          onTap: answer == null && _submitting == null && !_loading ? () => _answer(entry.key) : null,
        ),
        const SizedBox(height: 10),
      ],
      if (_error != null) ...[
        Text(_error!, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Poppins', fontSize: 13)),
        const SizedBox(height: 8),
      ],
      if (answer != null) ...[
        _resultBanner(answer, question),
        ..._outcomeNotes(),
        const Divider(color: Colors.white24, height: 28),
        DailyStreakView(streak: streak, today: widget.today),
      ] else
        Text(
          streak.current > 0
              ? '🔥 ${streak.current}-day streak. Answer to keep it going.'
              : 'Answer today to start a streak. 45 days in a row earns merch discounts.',
          style: const TextStyle(color: Colors.white60, fontFamily: 'Poppins', fontSize: 13),
        ),
    ];
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kPrimaryGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimaryGold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kPrimaryGold),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: kPrimaryGold, fontFamily: 'Poppins', fontSize: 12)),
        ],
      ),
    );
  }

  _OptionState _optionState(String letter, DailyAnswerResult? answer) {
    if (answer == null) return _OptionState.idle;
    if (letter == answer.correctOption) return _OptionState.correct;
    if (letter == answer.selected) return _OptionState.wrong;
    return _OptionState.dimmed;
  }

  Widget _resultBanner(DailyAnswerResult answer, DailyQuestion question) {
    final text = answer.correct
        ? '✅ Correct!'
        : 'Not quite. The answer was "${question.options[answer.correctOption] ?? answer.correctOption}". '
            'Your streak still counts.';
    return Text(text,
        style: TextStyle(
          color: answer.correct ? kPrimaryGold : Colors.white,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ));
  }

  List<Widget> _outcomeNotes() {
    final o = _outcome;
    if (o == null) return const [];
    final notes = <String>[
      if (o.streakReset) 'Your streak restarted. Day 1 starts now.',
      if (o.freezesUsed == 1) '❄️ A streak freeze covered the day you missed.',
      if (o.freezesUsed > 1) '❄️ ${o.freezesUsed} streak freezes covered the days you missed.',
      if (o.freezeEarned) '❄️ You earned a streak freeze.',
      if (o.newReward != null)
        '🎉 ${o.newReward!.tier} days in a row! ${o.newReward!.percent}% off merch. '
            'Your code is on its way by email and notification.',
    ];
    return [
      for (final n in notes) ...[
        const SizedBox(height: 8),
        Text(n, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13)),
      ],
    ];
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.letter,
    required this.text,
    required this.state,
    required this.busy,
    required this.onTap,
  });

  final String letter;
  final String text;
  final _OptionState state;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gold = kPrimaryGold;
    final (Color bg, Color border, Color fg) = switch (state) {
      _OptionState.idle => (const Color(0xFF1C1C1E), Colors.white24, Colors.white),
      _OptionState.correct => (gold, gold, Colors.black),
      _OptionState.wrong => (Colors.redAccent.withValues(alpha: 0.2), Colors.redAccent, Colors.white),
      _OptionState.dimmed => (const Color(0xFF1C1C1E), Colors.white10, Colors.white38),
    };
    final suffix = switch (state) {
      _OptionState.correct => ', correct answer',
      _OptionState.wrong => ', your answer, incorrect',
      _ => '',
    };
    return Semantics(
      button: onTap != null,
      label: '${letter.toUpperCase()}: $text$suffix',
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Text('${letter.toUpperCase()}.',
                      style: TextStyle(color: fg, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(text, style: TextStyle(color: fg, fontFamily: 'Poppins', fontSize: 15)),
                  ),
                  if (busy)
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg)),
                  if (state == _OptionState.correct) Icon(Icons.check_circle, color: fg, size: 20),
                  if (state == _OptionState.wrong) Icon(Icons.cancel, color: fg, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
