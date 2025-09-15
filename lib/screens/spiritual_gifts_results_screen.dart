import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import '../models/spiritual_gifts_models.dart';
import '../services/api_service.dart';
import '../widgets/version_badge.dart';
import '../utils/haptics.dart';
import '../ui/ui_constants.dart';
import 'spiritual_gifts_definitions_screen.dart';

/// Displays a Spiritual Gifts result (either freshly submitted or fetched latest).
/// Expects either a pre-parsed result OR will fetch latest on init.
class SpiritualGiftsResultsScreen extends StatefulWidget {
  final Map<String, dynamic>? rawResult; // optional raw JSON from submit
  const SpiritualGiftsResultsScreen({super.key, this.rawResult});

  @override
  State<SpiritualGiftsResultsScreen> createState() => _SpiritualGiftsResultsScreenState();
}

class _SpiritualGiftsResultsScreenState extends State<SpiritualGiftsResultsScreen> {
  final _api = ApiService();
  SpiritualGiftsResult? _result;
  bool _loading = true;
  String? _error;
  bool _emailingSelf = false; // loading state for self email
  DateTime? _retryAt; // rate limit next allowed
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (widget.rawResult != null) {
        _result = SpiritualGiftsResult.fromJson(widget.rawResult!);
        setState(() => _loading = false);
        return;
      }
      final json = await _api.getSpiritualGiftsLatest();
      if (json.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No spiritual gifts assessment found yet. Take the assessment first.';
        });
        return;
      }
      _result = SpiritualGiftsResult.fromJson(json);
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load results: $e';
      });
    }
  }

  Future<void> _handleEmailSelf() async {
    if (_emailingSelf) return;
    if (_retryAt != null && DateTime.now().isBefore(_retryAt!)) {
      _snack('Please wait ${_remainingSeconds()}s before retrying.', error: true);
      return;
    }
    setState(() => _emailingSelf = true);
    try {
      await _api.emailMySpiritualGiftsReport();
      _snack('Email requested. Check your inbox.');
      Haptics.success();
    } catch (e) {
      if (e.toString().contains('RATE_LIMIT')) {
        // Attempt to parse retry_after_seconds=### from error string
        final reg = RegExp(r'retry_after_seconds[=:\s]+(\d+)');
        final m = reg.firstMatch(e.toString());
        if (m != null) {
          final secs = int.tryParse(m.group(1)!);
          if (secs != null) {
            _retryAt = DateTime.now().add(Duration(seconds: secs));
            _startTicker();
          }
        }
      }
      final msg = e.toString().contains('RATE_LIMIT')
          ? 'Rate limit reached. ${_retryAt != null ? 'Wait ${_remainingSeconds()}s.' : 'Try again later.'}'
          : 'Failed to email report: $e';
      _snack(msg, error: true);
    } finally {
      if (mounted) setState(() => _emailingSelf = false);
    }
  }

  void _startTicker() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_retryAt == null) {
        t.cancel();
        return;
      }
      if (DateTime.now().isAfter(_retryAt!)) {
        setState(() => _retryAt = null);
        t.cancel();
      } else {
        setState(() {}); // refresh countdown text
      }
    });
  }

  String _remainingSeconds() {
    if (_retryAt == null) return '0';
    final diff = _retryAt!.difference(DateTime.now());
    final secs = diff.inSeconds;
    return secs < 0 ? '0' : secs.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Spiritual Gifts Results', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Center(
                child: Semantics(
                  label: 'Assessment template version ${_result!.templateVersion}',
                  child: VersionBadge(versionLabel: 'v${_result!.templateVersion}'),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return _LoadingSkeleton();
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _init);
    }
    if (_result == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: _init,
      backgroundColor: Colors.grey[900],
      color: Colors.amber,
      child: ListView(
  padding: const EdgeInsets.fromLTRB(UISpace.s16, UISpace.s16, UISpace.s16, UISpace.s40),
        children: [
          _TopGiftsSection(
            truncated: _result!.topGifts,
            expanded: _result!.topGiftsExpanded,
            thirdPlaceScore: _result!.thirdPlaceScore,
          ),
          const SizedBox(height: UISpace.s28),
          _AllGiftsSection(
            gifts: _result!.gifts,
            thirdPlaceScore: _result!.thirdPlaceScore,
          ),
          const SizedBox(height: UISpace.s40),
          _ActionsSection(
            onEmail: _handleEmailSelf,
            emailing: _emailingSelf,
            onHistory: _openHistory,
            onDefinitions: _showDefinitions,
            cooldownSeconds: _retryAt != null ? _retryAt!.difference(DateTime.now()).inSeconds.clamp(0, 9999) : 0,
          ),
        ],
      ),
    );
  }

  void _openHistory() {
    _snack('History view coming soon...');
  }

  void _showDefinitions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SpiritualGiftsDefinitionsScreen()),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: error ? Colors.redAccent : Colors.grey[800],
    ));
  }
}

class _TopGiftsSection extends StatelessWidget {
  final List<GiftScore> truncated;          // always up to 3
  final List<GiftScore> expanded;           // may include ties beyond truncated
  final int? thirdPlaceScore;               // score used for tie boundary
  const _TopGiftsSection({required this.truncated, required this.expanded, this.thirdPlaceScore});

  bool get _hasTies => expanded.length > truncated.length;

  @override
  Widget build(BuildContext context) {
    final tieExtras = _hasTies ? expanded.where((e) => !truncated.any((t) => t.giftSlug == e.giftSlug)).toList() : const <GiftScore>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Top Gifts',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                )),
            if (_hasTies) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text('Tie at 3rd', style: TextStyle(color: Colors.amber[200], fontSize: 11, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ]
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _hasTies
              ? 'Your top three gifts are shown. Because multiple gifts share the 3rd-place score (${thirdPlaceScore ?? '-'}), they are all included below.'
              : 'Your top three gifts by raw score (0–12 scale).',
          style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 12, fontFamily: 'Poppins', height: 1.3),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: truncated.map((g) => _TopGiftCard(gift: g)).toList(),
        ),
        if (_hasTies) ...[
          const SizedBox(height: 18),
          Text(
            'Also tied at 3rd place (score ${thirdPlaceScore ?? '-'})',
            style: TextStyle(color: Colors.amber[300], fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tieExtras.map((g) => _TieChip(gift: g)).toList(),
          ),
        ]
      ],
    );
  }
}

class _TieChip extends StatelessWidget {
  final GiftScore gift;
  const _TieChip({required this.gift});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_half, size: 14, color: Colors.amber),
          const SizedBox(width: 6),
          Text(
            _humanize(gift.displayName ?? gift.giftSlug),
            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Text('${gift.rawScore.toStringAsFixed(gift.rawScore % 1 == 0 ? 0 : 1)}/12', style: TextStyle(color: Colors.amber[200], fontSize: 11, fontFamily: 'Poppins')),
        ],
      ),
    );
  }

  static String _humanize(String slugOrName) {
    // If already spaced (has space or / or &) keep; else slug transform
    if (slugOrName.contains(' ')) return slugOrName;
    return slugOrName
        .split('_')
        .map((e) => e.isEmpty ? e : e[0].toUpperCase() + e.substring(1))
        .join(' ');
  }
}

class _TopGiftCard extends StatelessWidget {
  final GiftScore gift;
  const _TopGiftCard({required this.gift});

  @override
  Widget build(BuildContext context) {
    final firstSentence = _extractFirstSentence(gift.description);
    return Container(
      width: MediaQuery.of(context).size.width / 2 - 28,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.amber.withOpacity(0.25),
                child: Text(
                  '#${gift.rank}',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.6)),
                ),
                child: Text(
                  '${gift.rawScore.toStringAsFixed(gift.rawScore % 1 == 0 ? 0 : 1)}/12',
                  style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            gift.displayName ?? _humanize(gift.giftSlug),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          if (firstSentence != null) ...[
            const SizedBox(height: 6),
            Text(
              firstSentence,
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 12,
                fontFamily: 'Poppins',
                height: 1.3,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ]
        ],
      ),
    );
  }

  static String _humanize(String slug) => slug
      .split('_')
      .map((e) => e.isEmpty ? e : e[0].toUpperCase() + e.substring(1))
      .join(' ');

  static String? _extractFirstSentence(String? text) {
    if (text == null) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final idx = trimmed.indexOf('.');
    if (idx == -1 || idx > 180) {
      // If no period or period very late (definition short), take up to 180 chars
      return trimmed.length > 180 ? trimmed.substring(0, 177).trimRight() + '…' : trimmed;
    }
    return trimmed.substring(0, idx + 1);
  }
}

class _AllGiftsSection extends StatelessWidget {
  final List<GiftScore> gifts;
  final int? thirdPlaceScore;
  const _AllGiftsSection({required this.gifts, this.thirdPlaceScore});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Full Ranked List',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
        const SizedBox(height: 6),
        Text(
          'Sorted by raw score (0–12). Gifts sharing the 3rd-place score are marked.',
          style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 10),
        _Legend(thirdPlaceScore: thirdPlaceScore),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[850]!),
          ),
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: gifts.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[800]),
            itemBuilder: (context, i) {
              final g = gifts[i];
              final bool isTop = g.rank <= 3;
              final bool isTiedThird = !isTop && thirdPlaceScore != null && g.rawScore == thirdPlaceScore;
              return InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.grey[900],
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => _GiftDetailSheet(gift: g),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: isTop
                            ? Colors.amber
                            : isTiedThird
                                ? Colors.amber.withOpacity(0.6)
                                : Colors.transparent,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isTop ? Colors.amber : Colors.grey[800],
                        child: Text(
                          '${g.rank}',
                          style: TextStyle(
                            color: isTop ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    g.displayName ?? _humanize(g.giftSlug),
                                    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (isTop) _Chip(label: 'Top 3', color: Colors.amber, darkText: true),
                                if (isTiedThird) _Chip(label: 'Tied 3rd', color: Colors.amber.withOpacity(0.15), outline: Colors.amber.withOpacity(0.6)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Score: ${g.rawScore.toStringAsFixed(g.rawScore % 1 == 0 ? 0 : 1)}  •  ${(g.normalized * 100).toStringAsFixed(1)}%',
                              style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins', fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }

  static String _humanize(String slug) => slug
      .split('_')
      .map((e) => e.isEmpty ? e : e[0].toUpperCase() + e.substring(1))
      .join(' ');
}

class _GiftDetailSheet extends StatelessWidget {
  final GiftScore gift;
  const _GiftDetailSheet({required this.gift});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            gift.displayName ?? _humanize(gift.giftSlug),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rank #${gift.rank} • ${(gift.normalized * 100).toStringAsFixed(1)}%  (Raw ${gift.rawScore.toStringAsFixed(2)})',
            style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 16),
          Text(
            gift.description ?? 'No description provided for this gift yet.',
            style: TextStyle(color: Colors.grey[300], height: 1.35, fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 30),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.close),
              label: const Text('Close', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  static String _humanize(String slug) => slug
      .split('_')
      .map((e) => e.isEmpty ? e : e[0].toUpperCase() + e.substring(1))
      .join(' ');
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool darkText;
  final Color? outline;
  const _Chip({required this.label, required this.color, this.darkText = false, this.outline});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: outline != null ? Border.all(color: outline!, width: 1) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          color: darkText ? Colors.black : Colors.amber,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final int? thirdPlaceScore;
  const _Legend({this.thirdPlaceScore});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(label: 'Top 3', color: Colors.amber, darkText: true),
        const SizedBox(width: 8),
        _Chip(label: 'Tied 3rd', color: Colors.amber.withOpacity(0.15), outline: Colors.amber.withOpacity(0.6)),
        const SizedBox(width: 8),
        if (thirdPlaceScore != null)
          Text('3rd place score: $thirdPlaceScore', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontFamily: 'Poppins')),
      ],
    );
  }
}

class _ActionsSection extends StatelessWidget {
  final VoidCallback onEmail;
  final bool emailing;
  final VoidCallback onHistory;
  final VoidCallback onDefinitions;
  final int cooldownSeconds; // remaining cooldown
  const _ActionsSection({required this.onEmail, required this.onHistory, required this.onDefinitions, this.emailing = false, this.cooldownSeconds = 0});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Actions', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: emailing ? null : onEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: emailing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                    : const Icon(Icons.email_outlined),
                label: Semantics(
                  label: emailing ? 'Sending email report' : 'Email my spiritual gifts report',
                  excludeSemantics: true,
                  child: Text(
                    emailing
                        ? 'Sending...'
                        : cooldownSeconds > 0
                            ? 'Wait ${cooldownSeconds}s'
                            : 'Email Me',
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onHistory,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: const BorderSide(color: Colors.amber),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.history),
                label: Semantics(
                  label: 'View my submission history',
                  excludeSemantics: true,
                  child: Text('History', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDefinitions,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[700]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.menu_book_outlined, color: Colors.white),
                label: Semantics(
                  label: 'Open spiritual gifts definitions',
                  excludeSemantics: true,
                  child: Text('Gift Definitions', style: TextStyle(fontFamily: 'Poppins')),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Retry', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading skeleton while results fetch.
class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.grey[800]!;
    final highlight = Colors.grey[700]!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(UISpace.s16, UISpace.s16, UISpace.s16, UISpace.s40),
      children: [
        _sectionHeaderSkeleton(baseColor, highlight, width: 140),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: List.generate(3, (i) => _topCardSkeleton(baseColor, highlight, context)).toList(),
        ),
        const SizedBox(height: 32),
        _sectionHeaderSkeleton(baseColor, highlight, width: 170),
        const SizedBox(height: 12),
        _legendSkeleton(baseColor, highlight),
        const SizedBox(height: 16),
        _listSkeleton(baseColor, highlight, itemCount: 6),
        const SizedBox(height: 40),
        _sectionHeaderSkeleton(baseColor, highlight, width: 100),
        const SizedBox(height: 20),
        _actionsSkeleton(baseColor, highlight),
      ],
    );
  }

  Widget _sectionHeaderSkeleton(Color base, Color highlight, {double width = 120}) {
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: 22,
        width: width,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _topCardSkeleton(Color base, Color highlight, BuildContext context) {
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: MediaQuery.of(context).size.width / 2 - 28,
        height: 140,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.grey[850], shape: BoxShape.circle)),
                const Spacer(),
                Container(width: 50, height: 20, decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(8)),),
              ],
            ),
            const SizedBox(height: 12),
            Container(width: 90, height: 14, decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container(width: double.infinity, height: 10, decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
            Container(width: double.infinity, height: 10, decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(4))),
          ],
        ),
      ),
    );
  }

  Widget _legendSkeleton(Color base, Color highlight) {
    return Row(
      children: [
        ...List.generate(2, (i) => Padding(
          padding: EdgeInsets.only(right: i==1?0:8),
          child: Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            child: Container(width: 60, height: 22, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(12))),
          ),
        )),
        const SizedBox(width: 8),
        Shimmer.fromColors(
          baseColor: base,
            highlightColor: highlight,
          child: Container(width: 110, height: 12, color: base),
        ),
      ],
    );
  }

  Widget _listSkeleton(Color base, Color highlight, {int itemCount = 6}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: Column(
        children: List.generate(itemCount, (i) => Column(
          children: [
            if (i>0) Divider(height:1,color: Colors.grey[850]),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Shimmer.fromColors(
                    baseColor: base,
                    highlightColor: highlight,
                    child: Container(width: 40, height: 40, decoration: BoxDecoration(color: base, shape: BoxShape.circle)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: 140, height: 14, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4)))),
                        const SizedBox(height: 8),
                        Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: 100, height: 10, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4)))),
                      ],
                    ),
                  ),
                  Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: Container(width: 20, height: 20, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(4)))),
                ],
              ),
            )
          ],
        )),
      ),
    );
  }

  Widget _actionsSkeleton(Color base, Color highlight) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Shimmer.fromColors(
                baseColor: base,
                highlightColor: highlight,
                child: Container(height: 48, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Shimmer.fromColors(
                baseColor: base,
                highlightColor: highlight,
                child: Container(height: 48, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Shimmer.fromColors(
                baseColor: base,
                highlightColor: highlight,
                child: Container(height: 48, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        )
      ],
    );
  }
}
