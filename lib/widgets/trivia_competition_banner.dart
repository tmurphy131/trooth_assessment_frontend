import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

const _gold = Color(0xFFFFD700);

/// Leaderboard competition banner for the Trivia home screen.
///
/// Driven entirely by `GET /trivia/competition`: counts down to the start while
/// upcoming, shows live standings + a countdown to the end while active, and
/// shows the winners podium (plus the viewer's prize code, if they won) once
/// ended. Countdowns use the server clock so a wrong device clock can't skew them.
class TriviaCompetitionBanner extends StatefulWidget {
  final Map<String, dynamic> competition;

  /// Called when a countdown reaches zero so the parent can refetch.
  final VoidCallback onPhaseChanged;

  const TriviaCompetitionBanner({
    super.key,
    required this.competition,
    required this.onPhaseChanged,
  });

  @override
  State<TriviaCompetitionBanner> createState() => _TriviaCompetitionBannerState();
}

class _TriviaCompetitionBannerState extends State<TriviaCompetitionBanner> {
  Timer? _tick;
  Duration _clockOffset = Duration.zero;
  bool _phaseChangeFired = false;

  Map<String, dynamic> get _c => widget.competition;
  String get _status => _c['status'] as String? ?? 'upcoming';

  @override
  void initState() {
    super.initState();
    _syncClock();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!_phaseChangeFired && _status != 'ended' && _remaining() <= Duration.zero) {
        _phaseChangeFired = true;
        widget.onPhaseChanged();
      }
    });
  }

  @override
  void didUpdateWidget(covariant TriviaCompetitionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.competition != widget.competition) {
      _syncClock();
      _phaseChangeFired = false;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _syncClock() {
    final serverNow = DateTime.tryParse(_c['server_now'] as String? ?? '');
    _clockOffset = serverNow == null ? Duration.zero : serverNow.difference(DateTime.now());
  }

  DateTime? _date(String key) => DateTime.tryParse(_c[key] as String? ?? '')?.toLocal();

  Duration _remaining() {
    final target = _status == 'upcoming' ? _date('starts_at') : _date('ends_at');
    if (target == null) return Duration.zero;
    final left = target.difference(DateTime.now().add(_clockOffset));
    return left.isNegative ? Duration.zero : left;
  }

  @override
  Widget build(BuildContext context) {
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
        border: Border.all(color: _gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 8),
          ...switch (_status) {
            'active' => _activeBody(),
            'ended' => _endedBody(),
            _ => _upcomingBody(),
          },
        ],
      ),
    );
  }

  Widget _header() {
    final label = switch (_status) {
      'active' => 'LIVE',
      'ended' => 'FINAL',
      _ => 'COMING SOON',
    };
    return Row(
      children: [
        const Icon(Icons.emoji_events, color: _gold, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _c['name'] as String? ?? 'Trivia Competition',
            style: const TextStyle(
              color: _gold,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (_status == 'active' ? Colors.redAccent : _gold).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: _status == 'active' ? Colors.redAccent : _gold,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Upcoming ----------

  List<Widget> _upcomingBody() {
    final start = _date('starts_at');
    final end = _date('ends_at');
    final range = (start != null && end != null)
        ? '${DateFormat.MMMd().format(start)} – ${DateFormat.MMMd().format(end.subtract(const Duration(seconds: 1)))}'
        : '';
    return [
      _bodyText('Top 3 players on the Challenger leaderboard win ONLY BLV merch. $range'),
      const SizedBox(height: 12),
      _countdown('Starts in'),
      const SizedBox(height: 12),
      _prizeChips(),
    ];
  }

  // ---------- Active ----------

  List<Widget> _activeBody() {
    final standings = (_c['standings'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final myRank = _c['my_rank'] as int?;
    final myScore = _c['my_score'] as int?;
    final eligible = _c['is_eligible'] as bool? ?? true;

    return [
      _bodyText('Best Challenger score per player, all categories. Top 3 win merch.'),
      const SizedBox(height: 12),
      _countdown('Ends in'),
      const SizedBox(height: 12),
      if (standings.isEmpty)
        _bodyText('No scores yet. Play Single Player on Challenger to take the lead!')
      else
        ...standings.take(3).map((s) => _standingRow(
              rank: s['rank'] as int? ?? 0,
              name: s['display_name'] as String? ?? 'Player',
              score: s['score'] as int? ?? 0,
            )),
      const SizedBox(height: 8),
      if (!eligible)
        _bodyText('Staff and test accounts can play but are not eligible for prizes.')
      else if (myRank != null)
        Text(
          'Your rank: #$myRank · ${NumberFormat.decimalPattern().format(myScore ?? 0)} pts',
          style: const TextStyle(
            color: _gold,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        )
      else
        _bodyText('You are not on the board yet. Play Single Player on Challenger difficulty.'),
      const SizedBox(height: 12),
      _prizeChips(),
    ];
  }

  // ---------- Ended ----------

  List<Widget> _endedBody() {
    final winners = (_c['winners'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final finalized = _c['finalized'] as bool? ?? false;
    final myPrize = _c['my_prize'] as Map<String, dynamic>?;

    if (winners.isEmpty) {
      return [
        _bodyText(finalized
            ? 'The competition has ended. Thanks to everyone who played!'
            : 'The competition has ended. Winners are being finalized. Check back soon!'),
      ];
    }

    return [
      _bodyText('The competition is over. Congratulations to our winners!'),
      const SizedBox(height: 12),
      ...winners.map((w) => _standingRow(
            rank: w['place'] as int? ?? 0,
            name: w['display_name'] as String? ?? 'Player',
            score: w['score'] as int? ?? 0,
            highlight: w['is_me'] as bool? ?? false,
          )),
      if (myPrize != null) ...[
        const SizedBox(height: 12),
        _myPrizeCard(myPrize),
      ],
    ];
  }

  Widget _myPrizeCard(Map<String, dynamic> prize) {
    final code = prize['discount_code'] as String? ?? '';
    final expires = DateTime.tryParse(prize['code_expires_at'] as String? ?? '')?.toLocal();
    final shopUrl = prize['shop_url'] as String? ?? 'https://shop.onlyblv.com';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You won! 🎉',
            style: TextStyle(color: _gold, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          _bodyText('${prize['label'] ?? 'Merch prize'}. We also emailed you this code.'),
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label: 'Prize code $code. Tap to copy.',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _copyCode(code),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _gold.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        code,
                        style: const TextStyle(
                          color: _gold,
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const Icon(Icons.copy, color: _gold, size: 18),
                  ],
                ),
              ),
            ),
          ),
          if (expires != null) ...[
            const SizedBox(height: 6),
            Text(
              'One-time use · expires ${DateFormat.yMMMd().format(expires)}',
              style: const TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => launchUrl(Uri.parse(shopUrl), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Shop Now', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prize code copied!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ---------- Shared pieces ----------

  Widget _bodyText(String text) => Text(
        text,
        style: const TextStyle(color: Colors.white70, fontFamily: 'Poppins', fontSize: 12, height: 1.4),
      );

  Widget _countdown(String label) {
    final left = _remaining();
    final days = left.inDays;
    final hours = left.inHours % 24;
    final minutes = left.inMinutes % 60;
    final seconds = left.inSeconds % 60;
    final semanticsLabel = '$label $days days, $hours hours, $minutes minutes';

    Widget unit(int value, String suffix) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _gold.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Text(
                  value.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  suffix,
                  style: const TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 10),
                ),
              ],
            ),
          ),
        );

    // One coarse label for screen readers instead of announcing every tick
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: _gold,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              unit(days, 'days'),
              const SizedBox(width: 6),
              unit(hours, 'hrs'),
              const SizedBox(width: 6),
              unit(minutes, 'min'),
              const SizedBox(width: 6),
              unit(seconds, 'sec'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _standingRow({required int rank, required String name, required int score, bool highlight = false}) {
    const medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? _gold.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: highlight ? Border.all(color: _gold.withValues(alpha: 0.6)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(medals[rank] ?? '#$rank', style: const TextStyle(fontSize: 16, color: Colors.white70)),
          ),
          Expanded(
            child: Text(
              highlight ? '$name (you)' : name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13),
            ),
          ),
          Text(
            NumberFormat.decimalPattern().format(score),
            style: const TextStyle(color: _gold, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _prizeChips() {
    final prizes = (_c['prizes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    const medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    const places = {1: '1st', 2: '2nd', 3: '3rd'};
    return Row(
      children: [
        for (final (i, p) in prizes.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _gold.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(medals[p['place']] ?? '🏆', style: const TextStyle(fontSize: 16)),
                  Text(
                    places[p['place']] ?? '#${p['place']}',
                    style: const TextStyle(
                      color: _gold,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    p['place'] == 1 ? 'Any item free' : '\$${p['amount']} off',
                    style: const TextStyle(color: Colors.white54, fontFamily: 'Poppins', fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
