import 'package:flutter/material.dart';

import '../models/daily_trivia.dart';
import '../services/api_service.dart';
import 'daily_trivia_modal.dart';

/// Profile entry point for the daily question: shows the streak and opens the
/// modal (today's question, what was answered, and the streak view).
class DailyTriviaProfileCard extends StatefulWidget {
  const DailyTriviaProfileCard({super.key});

  @override
  State<DailyTriviaProfileCard> createState() => _DailyTriviaProfileCardState();
}

class _DailyTriviaProfileCardState extends State<DailyTriviaProfileCard> {
  DailyStreak? _streak;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final streak = await ApiService().dailyTriviaStreak();
      if (mounted) setState(() => _streak = streak);
    } catch (e) {
      debugPrint('⚠️ Daily streak load failed: $e');
    }
  }

  Future<void> _open() async {
    await DailyTriviaPrompt.open(context);
    if (mounted) _load();
  }

  String get _subtitle {
    final s = _streak;
    if (s == null) return "See today's question and your streak";
    final days = s.current == 1 ? 'day' : 'days';
    final streak = s.current > 0 ? '🔥 ${s.current} $days in a row' : 'No streak yet';
    final today = s.answeredToday ? "answered today" : "today's question is waiting";
    return '$streak · $today';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_fire_department, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Question & Streak',
                    style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle,
                    style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 13),
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
}
