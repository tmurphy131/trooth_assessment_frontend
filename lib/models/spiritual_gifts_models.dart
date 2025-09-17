// lib/models/spiritual_gifts_models.dart
// Strongly-typed models for Spiritual Gifts assessment flows.
// Keeps UI code clean and provides future-proofing if backend evolves.

import 'dart:convert';
import 'dart:math';

/// Represents a single scored gift.
class GiftScore {
  final String giftSlug;          // normalized slug (e.g. 'leadership')
  final String? displayName;      // original display / gift name
  final double rawScore;          // raw numeric score (0-12)
  final double normalized;        // rawScore / 12.0 (0.0 - 1.0)
  final int rank;                 // 1 = highest
  final String? description;      // optional description / definition summary
  final bool isTieAtThird;        // helper flag (set later if needed)

  GiftScore({
    required this.giftSlug,
    this.displayName,
    required this.rawScore,
    required this.normalized,
    required this.rank,
    this.description,
    this.isTieAtThird = false,
  });

  /// Legacy / generic factory (kept for backward compatibility if old shape persists)
  factory GiftScore.fromJson(Map<String, dynamic> json) {
    final raw = (json['raw_score'] ?? json['rawScore'] ?? json['score'] ?? 0).toDouble();
    final giftName = json['display_name'] as String? ?? json['displayName'] as String? ??
        json['gift'] as String? ?? json['gift_name'] as String? ?? json['giftSlug'] as String? ?? 'Unknown';
    return GiftScore(
      giftSlug: _slugify(giftName),
      displayName: giftName,
      rawScore: raw,
      normalized: (json['normalized'] ?? json['normalized_score'] ?? json['score_normalized']) != null
          ? (json['normalized'] ?? json['normalized_score'] ?? json['score_normalized']).toDouble()
          : (raw / 12.0),
      rank: (json['rank'] ?? 0) is int ? (json['rank'] ?? 0) as int : int.tryParse('${json['rank']}') ?? 0,
      description: json['description'] as String?,
    );
  }

  GiftScore copyWith({bool? isTieAtThird, int? rank}) => GiftScore(
        giftSlug: giftSlug,
        displayName: displayName,
        rawScore: rawScore,
        normalized: normalized,
        rank: rank ?? this.rank,
        description: description,
        isTieAtThird: isTieAtThird ?? this.isTieAtThird,
      );

  Map<String, dynamic> toJson() => {
        'gift_slug': giftSlug,
        if (displayName != null) 'display_name': displayName,
        'raw_score': rawScore,
        'normalized': normalized,
        'rank': rank,
        if (description != null) 'description': description,
        if (isTieAtThird) 'tie_at_third': true,
      };
}

/// Summary/metadata about a submission.
class SpiritualGiftsResult {
  final String submissionId;
  final String userId;
  final int templateVersion;
  final DateTime submittedAt;
  final List<GiftScore> gifts;               // full ordered list (score desc)
  final List<GiftScore> topGifts;            // truncated top 3
  final List<GiftScore> topGiftsExpanded;    // expanded (includes ties at 3rd)
  final int? thirdPlaceScore;                // from rank_meta if provided
  final Map<String, dynamic>? raw;           // original payload

  SpiritualGiftsResult({
    required this.submissionId,
    required this.userId,
    required this.templateVersion,
    required this.submittedAt,
    required this.gifts,
    required this.topGifts,
    required this.topGiftsExpanded,
    this.thirdPlaceScore,
    this.raw,
  });

  factory SpiritualGiftsResult.fromJson(Map<String, dynamic> json) {
    // Detect new backend shape first (preferred): all_scores + top_gifts_truncated + top_gifts_expanded
    final bool newShape = json.containsKey('all_scores');

    List<GiftScore> fullOrdered;
    List<GiftScore> truncated;
    List<GiftScore> expanded;
    int? thirdScore;

    if (newShape) {
      final rawScores = (json['all_scores'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((m) {
            final giftName = m['gift'] as String? ?? 'Unknown';
            final score = (m['score'] ?? 0).toDouble();
            return GiftScore(
              giftSlug: _slugify(giftName),
              displayName: giftName,
              rawScore: score,
              normalized: score / 12.0,
              rank: 0, // temp, will assign after sort
              description: (m['definition'] ?? m['description']) as String?,
            );
          })
          .toList();
      // Sort (score DESC, display ASC) deterministically
      rawScores.sort((a, b) {
        final c = b.rawScore.compareTo(a.rawScore);
        if (c != 0) return c;
        return (a.displayName ?? a.giftSlug).compareTo(b.displayName ?? b.giftSlug);
      });
      // Assign rank (1-based) with stable ordering; equal scores produce distinct ranks but we can still mark ties later
      for (var i = 0; i < rawScores.length; i++) {
        rawScores[i] = rawScores[i].copyWith(rank: i + 1);
      }
      fullOrdered = rawScores;

      final truncList = (json['top_gifts_truncated'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((m) {
            final name = m['gift'] as String? ?? 'Unknown';
            final score = (m['score'] ?? 0).toDouble();
            return GiftScore(
              giftSlug: _slugify(name),
              displayName: name,
              rawScore: score,
              normalized: score / 12.0,
              rank: 0,
            );
          })
          .toList();
      truncated = _mergeWithFull(truncList, fullOrdered);

      final expList = (json['top_gifts_expanded'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((m) {
            final name = m['gift'] as String? ?? 'Unknown';
            final score = (m['score'] ?? 0).toDouble();
            return GiftScore(
              giftSlug: _slugify(name),
              displayName: name,
              rawScore: score,
              normalized: score / 12.0,
              rank: 0,
            );
          })
          .toList();
      expanded = _mergeWithFull(expList, fullOrdered);

      thirdScore = (json['rank_meta'] is Map && json['rank_meta']['third_place_score'] != null)
          ? (json['rank_meta']['third_place_score'] as num).toInt()
          : null;

      if (thirdScore != null) {
        // Mark ties outside truncated that share third place
        final tieScore = thirdScore.toDouble();
        final truncatedScores = truncated.map((g) => g.rawScore).toList();
        final minTrunc = truncatedScores.isEmpty ? double.infinity : truncatedScores.reduce(min);
        expanded = expanded
            .map((g) => (g.rawScore == tieScore && g.rawScore == minTrunc && !truncated.contains(g))
                ? g.copyWith(isTieAtThird: true)
                : g)
            .toList();
      }
    } else {
      // Fallback legacy shape (gifts + top_gifts)
      final allGiftMaps = (json['gifts'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      var allGiftScores = allGiftMaps.map(GiftScore.fromJson).toList();
      // If ranks missing, derive from score
      if (allGiftScores.any((g) => g.rank == 0)) {
        allGiftScores.sort((a, b) {
          final c = b.rawScore.compareTo(a.rawScore);
          if (c != 0) return c;
            return (a.displayName ?? a.giftSlug).compareTo(b.displayName ?? b.giftSlug);
        });
        for (var i = 0; i < allGiftScores.length; i++) {
          allGiftScores[i] = allGiftScores[i].copyWith(rank: i + 1);
        }
      }
      fullOrdered = allGiftScores;
      truncated = (json['top_gifts'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GiftScore.fromJson)
          .toList();
      if (truncated.isEmpty) truncated = fullOrdered.take(3).toList();
      expanded = truncated; // legacy: no separate expansion concept
    }

    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v.toUtc();
      if (v is String) return DateTime.tryParse(v)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    return SpiritualGiftsResult(
      submissionId: json['submission_id'] as String? ?? json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['apprentice_id'] as String? ?? json['uid'] as String? ?? '',
      templateVersion: (json['template_version'] ?? json['version'] ?? json['scores']?['version'] ?? 0) as int,
      submittedAt: parseDate(json['submitted_at'] ?? json['created_at']),
      gifts: fullOrdered,
      topGifts: truncated,
      topGiftsExpanded: expanded,
      thirdPlaceScore: thirdScore,
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'submission_id': submissionId,
        'user_id': userId,
        'template_version': templateVersion,
        'submitted_at': submittedAt.toUtc().toIso8601String(),
        'gifts': gifts.map((g) => g.toJson()).toList(),
        'top_gifts_truncated': topGifts.map((g) => g.toJson()).toList(),
        'top_gifts_expanded': topGiftsExpanded.map((g) => g.toJson()).toList(),
        if (thirdPlaceScore != null) 'rank_meta': { 'third_place_score': thirdPlaceScore },
      };
}

/// Paginated history response wrapper.
class SpiritualGiftsHistoryPage {
  final List<SpiritualGiftsResult> items;
  final String? nextCursor;
  final bool hasMore;
  final Map<String, dynamic>? raw;

  SpiritualGiftsHistoryPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    this.raw,
  });

  factory SpiritualGiftsHistoryPage.fromJson(Map<String, dynamic> json) {
    // Example backend shape:
    // { "items": [ { ...result... }, ... ], "next_cursor": "abc", "has_more": true }
    final items = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SpiritualGiftsResult.fromJson)
        .toList();
    return SpiritualGiftsHistoryPage(
      items: items,
      nextCursor: json['next_cursor'] as String? ?? json['cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? (json['next_cursor'] != null),
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'next_cursor': nextCursor,
        'has_more': hasMore,
      };
}

/// Convenience parser helpers so calling code stays concise.
class SpiritualGiftsParsers {
  static SpiritualGiftsResult? parseLatest(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    return SpiritualGiftsResult.fromJson(json);
  }

  static SpiritualGiftsHistoryPage parseHistory(Map<String, dynamic> json) =>
      SpiritualGiftsHistoryPage.fromJson(json);
}

/// Debug utility to pretty print a result (not used in production UI directly)
String prettyPrintSpiritualGifts(SpiritualGiftsResult r) {
  final map = r.toJson();
  return const JsonEncoder.withIndent('  ').convert(map);
}

// ----------------- Internal helpers -----------------

String _slugify(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9\s&]+"), '')
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'\s+'), '-');
}

List<GiftScore> _mergeWithFull(List<GiftScore> partial, List<GiftScore> full) {
  if (partial.isEmpty) return partial;
  final bySlug = { for (final g in full) g.giftSlug: g };
  return partial.map((p) => bySlug[p.giftSlug] ?? p).toList();
}
