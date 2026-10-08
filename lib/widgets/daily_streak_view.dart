import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/daily_trivia.dart';
import '../theme.dart';

const _freezeBlue = Color(0xFF7FC8F8);
const _dim = Color(0xFF3A3A3C);

/// Daily trivia streak: flame count, a week row (under 7 days) or the month
/// calendar (7+), progress to the next reward, and the active reward code.
class DailyStreakView extends StatelessWidget {
  const DailyStreakView({super.key, required this.streak, this.today});

  final DailyStreak streak;

  /// Defaults to the device's today; injectable for tests.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final now = today ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const SizedBox(height: 14),
        streak.showMonth
            ? _MonthCalendar(calendar: streak.calendar, today: day)
            : _WeekRow(calendar: streak.calendar, today: day),
        const SizedBox(height: 14),
        _milestone(),
        if (streak.reward != null) ...[
          const SizedBox(height: 14),
          _RewardCard(reward: streak.reward!),
        ],
      ],
    );
  }

  Widget _header() {
    final days = streak.current == 1 ? 'day' : 'days';
    return Row(
      children: [
        const Text('🔥', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${streak.current} $days in a row',
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18)),
              Text('Best: ${streak.longest}',
                  style: const TextStyle(color: Colors.white60, fontFamily: 'Poppins', fontSize: 12)),
            ],
          ),
        ),
        Tooltip(
          message: 'Streak freezes cover a missed day. You earn one every 15 days (up to ${streak.maxFreezes}).',
          triggerMode: TooltipTriggerMode.tap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.ac_unit, color: _freezeBlue, size: 20),
                const SizedBox(width: 4),
                Text('${streak.freezes}/${streak.maxFreezes}',
                    semanticsLabel: '${streak.freezes} of ${streak.maxFreezes} streak freezes',
                    style: const TextStyle(color: _freezeBlue, fontFamily: 'Poppins', fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _milestone() {
    final next = streak.nextMilestone;
    if (next == null) {
      return const Text("🏆 You've earned the top streak reward. Keep it going!",
          style: TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 13));
    }
    final reward = streak.perfectRun
        ? '${next.percent}% off merch (${next.percentIfPerfect}% if every answer is right)'
        : '${next.percent}% off merch';
    final progress = (streak.current / next.tier).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${streak.current}/${next.tier} days → $reward',
            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: _dim,
            valueColor: AlwaysStoppedAnimation(kPrimaryGold),
            semanticsLabel: 'Progress to the ${next.tier}-day reward, ${next.daysRemaining} days to go',
          ),
        ),
      ],
    );
  }
}

/// One day dot. Correct = gold with a check, wrong = gold ring, freeze = blue
/// snowflake, unanswered = empty (today outlined).
class _DayDot extends StatelessWidget {
  const _DayDot({required this.date, required this.status, required this.isToday, required this.isFuture, this.label});

  final DateTime date;
  final DayStatus? status;
  final bool isToday;
  final bool isFuture;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final gold = kPrimaryGold;
    final Widget inner;
    final BoxDecoration decoration;
    switch (status) {
      case DayStatus.correct:
        decoration = BoxDecoration(color: gold, shape: BoxShape.circle);
        inner = label != null
            ? Text(label!, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12))
            : const Icon(Icons.check, color: Colors.black, size: 18);
      case DayStatus.wrong:
        decoration = BoxDecoration(
            color: gold.withValues(alpha: 0.25), shape: BoxShape.circle, border: Border.all(color: gold, width: 2));
        inner = Text(label ?? '•', style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 12));
      case DayStatus.freeze:
        decoration = BoxDecoration(
            color: _freezeBlue.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: _freezeBlue));
        inner = const Icon(Icons.ac_unit, color: _freezeBlue, size: 16);
      case null:
        decoration = BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: isToday ? Colors.white : _dim, width: isToday ? 2 : 1),
        );
        inner = Text(label ?? '',
            style: TextStyle(color: isFuture ? Colors.white30 : Colors.white70, fontSize: 12));
    }
    final what = switch (status) {
      DayStatus.correct => 'answered correctly',
      DayStatus.wrong => 'answered',
      DayStatus.freeze => 'covered by a streak freeze',
      null => isFuture ? 'upcoming' : 'not answered',
    };
    return Semantics(
      label: '${DateFormat('EEEE, MMMM d').format(date)}: $what${isToday ? ', today' : ''}',
      excludeSemantics: true,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: decoration,
        child: inner,
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.calendar, required this.today});

  final Map<DateTime, DayStatus> calendar;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final monday = today.subtract(Duration(days: today.weekday - DateTime.monday));
    final days = [for (var i = 0; i < 7; i++) DateTime(monday.year, monday.month, monday.day + i)];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final d in days)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Text(DateFormat('E').format(d).substring(0, 1),
                    style: const TextStyle(color: Colors.white60, fontFamily: 'Poppins', fontSize: 12)),
              ),
              const SizedBox(height: 6),
              _DayDot(date: d, status: calendar[d], isToday: d == today, isFuture: d.isAfter(today)),
            ],
          ),
      ],
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.calendar, required this.today});

  final Map<DateTime, DayStatus> calendar;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(today.year, today.month, 1);
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    final leading = first.weekday - DateTime.monday;
    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        Builder(builder: (_) {
          final d = DateTime(today.year, today.month, day);
          return Center(
            child: _DayDot(
                date: d, status: calendar[d], isToday: d == today, isFuture: d.isAfter(today), label: '$day'),
          );
        }),
    ];
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(DateFormat('MMMM yyyy').format(today),
            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Row(
            children: [
              for (final w in weekdays)
                Expanded(
                  child: Center(
                    child: Text(w, style: const TextStyle(color: Colors.white60, fontFamily: 'Poppins', fontSize: 12)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          children: cells,
        ),
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.reward});

  final DailyReward reward;

  @override
  Widget build(BuildContext context) {
    final gold = kPrimaryGold;
    final pending = reward.status == DailyRewardStatus.pending || reward.code == null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1505),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🎁 ${reward.percent}% off merch — ${reward.tier}-day streak${reward.perfect ? ' (perfect run!)' : ''}',
              style: TextStyle(color: gold, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          if (pending)
            const Text("Your code is being created. It'll arrive by email and notification shortly.",
                style: TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 13))
          else ...[
            Row(
              children: [
                Expanded(
                  child: SelectableText(reward.code!,
                      style: TextStyle(
                          color: gold, fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                ),
                IconButton(
                  icon: Icon(Icons.copy, color: gold),
                  tooltip: 'Copy code',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: reward.code!));
                    if (!context.mounted) return;
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Code copied')));
                  },
                ),
              ],
            ),
            if (reward.expiresAt != null)
              Text('One-time use. Expires ${DateFormat.yMMMMd().format(reward.expiresAt!)}. '
                  'A bigger milestone replaces it if unused.',
                  style: const TextStyle(color: Colors.white60, fontFamily: 'Poppins', fontSize: 12)),
            if (reward.shopUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(reward.shopUrl), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.storefront),
                  label: const Text('Shop merch'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
