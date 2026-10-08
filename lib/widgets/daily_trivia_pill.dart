import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_trivia.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'daily_trivia_modal.dart';

/// Small floating "🔥 12 · Daily question" button for the dashboards. Shown
/// only while today's question is unanswered; tapping it opens the modal. On
/// the first view of the day a speech bubble says the question is ready, then
/// fades. It never opens anything on its own.
class DailyTriviaPill extends StatefulWidget {
  const DailyTriviaPill({super.key, this.nudgeFor = const Duration(seconds: 4)});

  /// How long the "question is ready" bubble stays up.
  final Duration nudgeFor;

  @override
  State<DailyTriviaPill> createState() => _DailyTriviaPillState();
}

class _DailyTriviaPillState extends State<DailyTriviaPill> with WidgetsBindingObserver {
  static const _nudgePrefix = 'daily_trivia_nudged_';

  DailyToday? _today;
  bool _nudge = false;
  Timer? _nudgeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DailyTriviaPrompt.answered.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DailyTriviaPrompt.answered.removeListener(_load);
    _nudgeTimer?.cancel();
    super.dispose();
  }

  // A new day may have started while the app was in the background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final today = await ApiService().dailyTriviaToday();
      if (!mounted) return;
      setState(() => _today = today);
      if (today.answer == null) await _maybeNudge(today.question.date);
    } catch (e) {
      debugPrint('⚠️ Daily question pill hidden: $e');
      if (mounted) setState(() => _today = null);
    }
  }

  Future<void> _maybeNudge(DateTime date) async {
    final key = '$_nudgePrefix${isoDate(date)}';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) == true) return;
    for (final old in prefs.getKeys().where((k) => k.startsWith(_nudgePrefix) && k != key).toList()) {
      await prefs.remove(old);
    }
    await prefs.setBool(key, true);
    if (!mounted) return;
    setState(() => _nudge = true);
    _nudgeTimer?.cancel();
    _nudgeTimer = Timer(widget.nudgeFor, () {
      if (mounted) setState(() => _nudge = false);
    });
  }

  Future<void> _open() async {
    _nudgeTimer?.cancel();
    setState(() => _nudge = false);
    await DailyTriviaPrompt.open(context, initial: _today);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    if (today == null || today.answer != null) return const SizedBox.shrink();

    final streak = today.streak.current;
    final label = streak > 0 ? '🔥 $streak · Daily question' : '📖 Daily question';
    final gold = kPrimaryGold;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: IgnorePointer(
            ignoring: !_nudge,
            child: AnimatedOpacity(
              opacity: _nudge ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: GestureDetector(
                onTap: _open,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: gold.withValues(alpha: 0.6)),
                  ),
                  child: Text("Today's question is ready!",
                      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13)),
                ),
              ),
            ),
          ),
        ),
        Tooltip(
          message: "Answer today's daily question",
          child: Material(
            color: gold,
            elevation: 6,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: _open,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.black, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
