import 'package:flutter/material.dart';
import '../models/spiritual_gifts_models.dart';
import '../widgets/version_badge.dart';
import '../data/spiritual_gift_definitions.dart';

/// Reusable full spiritual gifts report view.
/// Provides top gifts (with tie handling), full ranked list, and optional actions/footer.
/// Not a Scaffold; parent supplies scroll container.
class SpiritualGiftsReportView extends StatelessWidget {
  final SpiritualGiftsResult result;
  final bool showHeader; // show title + version badge
  final bool compactHeader; // smaller header style (mentor inline card style)
  final Widget? actions; // optional actions section (email/history buttons)
  final EdgeInsets padding;
  final bool showDescriptionsInTop; // whether to show first sentence description in top gift cards
  final bool emphasizeThirdPlace; // highlight tie boundary chips
  final bool dense; // slightly tighter spacing for embedding

  const SpiritualGiftsReportView({
    super.key,
    required this.result,
    this.showHeader = true,
    this.compactHeader = false,
    this.actions,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 40),
    this.showDescriptionsInTop = true,
    this.emphasizeThirdPlace = true,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final truncated = result.topGifts;
    final expanded = result.topGiftsExpanded;
    final hasTies = expanded.length > truncated.length;
    final tieExtras = hasTies ? expanded.where((e) => !truncated.any((t) => t.giftSlug == e.giftSlug)).toList() : const <GiftScore>[];
    final thirdScore = result.thirdPlaceScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Spiritual Gifts Results',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontSize: compactHeader ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              VersionBadge(versionLabel: 'v${result.templateVersion}')
            ],
          ),
          SizedBox(height: dense ? 14 : 20),
        ],
        // Top gifts section
        Row(
          children: [
            const Text('Top Gifts', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.bold)),
            if (hasTies && emphasizeThirdPlace) ...[
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
          hasTies
              ? 'Your top three gifts are shown. Because multiple gifts share the 3rd-place score (${thirdScore ?? '-'}), they are all included below.'
              : 'Your top three gifts by raw score (0–12 scale).',
          style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 12, fontFamily: 'Poppins'),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: truncated.map((g) {
            final desc = g.description ?? kCanonicalSpiritualGiftDefinitions[g.giftSlug]?['desc'];
            final giftForCard = (desc != null && g.description == null)
                ? GiftScore(
                    giftSlug: g.giftSlug,
                    displayName: g.displayName,
                    rawScore: g.rawScore,
                    normalized: g.normalized,
                    rank: g.rank,
                    description: desc,
                    isTieAtThird: g.isTieAtThird,
                  )
                : g;
            return _TopGiftCard(gift: giftForCard, showDescription: showDescriptionsInTop);
          }).toList(),
        ),
        if (hasTies) ...[
          const SizedBox(height: 18),
          Text(
            'Also tied at 3rd place (score ${thirdScore ?? '-'})',
            style: TextStyle(color: Colors.amber[300], fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tieExtras.map((g) => _TieChip(gift: g)).toList(),
          ),
        ],
        SizedBox(height: dense ? 24 : 32),
        const Text('Full Ranked List', style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Sorted by raw score (0–12). Gifts sharing the 3rd-place score are marked.', style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12, fontFamily: 'Poppins')),
        const SizedBox(height: 10),
        _Legend(thirdPlaceScore: thirdScore),
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
            itemCount: result.gifts.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[800]),
            itemBuilder: (context, i) {
              final g = result.gifts[i];
              final bool isTop = g.rank <= 3;
              final bool isTiedThird = !isTop && thirdScore != null && g.rawScore == thirdScore;
              return InkWell(
                onTap: () => _showGiftDetail(context, g),
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
                        child: Text('${g.rank}', style: TextStyle(color: isTop ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(g.displayName ?? _humanize(g.giftSlug), style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                                ),
                                if (isTop) const _Chip(label: 'Top 3', color: Colors.amber, darkText: true),
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
        ),
        if (actions != null) ...[
          SizedBox(height: dense ? 24 : 40),
          actions!,
        ]
      ],
    );
  }

  void _showGiftDetail(BuildContext context, GiftScore g) {
    // Backfill description if absent
    final desc = g.description ?? kCanonicalSpiritualGiftDefinitions[g.giftSlug]?['desc'];
    final enriched = desc == null ? g : g.copyWith(); // reuse object if still null
    // Pass description through sheet (giftScore already holds it but sheet uses gift.description)
    final giftForSheet = (desc != null && g.description == null)
        ? GiftScore(
            giftSlug: g.giftSlug,
            displayName: g.displayName,
            rawScore: g.rawScore,
            normalized: g.normalized,
            rank: g.rank,
            description: desc,
            isTieAtThird: g.isTieAtThird,
          )
        : enriched;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _GiftDetailSheet(gift: giftForSheet),
    );
  }

  static String _humanize(String slug) => slug.split('_').map((e) => e.isEmpty ? e : e[0].toUpperCase() + e.substring(1)).join(' ');
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
          Text(_humanize(gift.displayName ?? gift.giftSlug), style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text('${gift.rawScore.toStringAsFixed(gift.rawScore % 1 == 0 ? 0 : 1)}/12', style: TextStyle(color: Colors.amber[200], fontSize: 11, fontFamily: 'Poppins')),
        ],
      ),
    );
  }
  static String _humanize(String slugOrName) { if (slugOrName.contains(' ')) return slugOrName; return slugOrName.split('_').map((e)=> e.isEmpty? e : e[0].toUpperCase()+e.substring(1)).join(' ');}  
}

class _TopGiftCard extends StatelessWidget {
  final GiftScore gift;
  final bool showDescription;
  const _TopGiftCard({required this.gift, required this.showDescription});
  @override
  Widget build(BuildContext context) {
    final firstSentence = showDescription ? _extractFirstSentence(gift.description) : null;
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
                child: Text('#${gift.rank}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.6)),
                ),
                child: Text('${gift.rawScore.toStringAsFixed(gift.rawScore % 1 == 0 ? 0 : 1)}/12', style: const TextStyle(color: Colors.amber, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(gift.displayName ?? _humanize(gift.giftSlug), style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 15)),
          if (firstSentence != null) ...[
            const SizedBox(height: 6),
            Text(firstSentence, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontFamily: 'Poppins', height: 1.3), maxLines: 3, overflow: TextOverflow.ellipsis),
          ]
        ],
      ),
    );
  }
  static String _humanize(String slug) => slug.split('_').map((e)=> e.isEmpty? e : e[0].toUpperCase()+e.substring(1)).join(' ');
  static String? _extractFirstSentence(String? text) { if (text==null) return null; final trimmed = text.trim(); if (trimmed.isEmpty) return null; final idx = trimmed.indexOf('.'); if (idx==-1 || idx>180) { return trimmed.length>180? trimmed.substring(0,177).trimRight()+'…': trimmed; } return trimmed.substring(0, idx+1);}  
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
            child: Container(width: 48, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
          ),
          Text(gift.displayName ?? _humanize(gift.giftSlug), style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text('Rank #${gift.rank} • ${(gift.normalized * 100).toStringAsFixed(1)}%  (Raw ${gift.rawScore.toStringAsFixed(2)})', style: TextStyle(color: Colors.grey[400], fontFamily: 'Poppins')),
          const SizedBox(height: 16),
          Text(gift.description ?? 'No description provided for this gift yet.', style: TextStyle(color: Colors.grey[300], height: 1.35, fontFamily: 'Poppins')),
          const SizedBox(height: 30),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.close),
              label: const Text('Close', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
  static String _humanize(String slug) => slug.split('_').map((e)=> e.isEmpty? e : e[0].toUpperCase()+e.substring(1)).join(' ');
}

class _Chip extends StatelessWidget {
  final String label; final Color color; final bool darkText; final Color? outline; const _Chip({required this.label, required this.color, this.darkText=false, this.outline});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12), border: outline!=null? Border.all(color: outline!, width: 1): null),
      child: Text(label, style: TextStyle(fontSize: 10, fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: darkText? Colors.black : Colors.amber)),
    );
  }
}

class _Legend extends StatelessWidget {
  final int? thirdPlaceScore; const _Legend({this.thirdPlaceScore});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _Chip(label: 'Top 3', color: Colors.amber, darkText: true),
        const SizedBox(width: 8),
        _Chip(label: 'Tied 3rd', color: Colors.amber.withOpacity(0.15), outline: Colors.amber.withOpacity(0.6)),
        const SizedBox(width: 8),
        if (thirdPlaceScore != null)
          Text('3rd place score: $thirdPlaceScore', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontFamily: 'Poppins')),
      ],
    );
  }
}
