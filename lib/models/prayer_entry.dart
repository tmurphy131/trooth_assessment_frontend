import 'package:flutter/material.dart';

enum PrayerCategory {
  praise('Praise', Icons.celebration_outlined),
  confession('Confession', Icons.healing_outlined),
  thanksgiving('Thanksgiving', Icons.volunteer_activism_outlined),
  request('Request', Icons.front_hand_outlined),
  intercession('Intercession', Icons.people_outline);

  const PrayerCategory(this.label, this.icon);
  final String label;
  final IconData icon;

  static PrayerCategory fromApi(String? value) =>
      PrayerCategory.values.firstWhere((c) => c.name == value, orElse: () => PrayerCategory.request);
}

class PrayerEntry {
  final String id;
  final String title;
  final String? body;
  final PrayerCategory category;
  final String? prayingFor;
  final String? scriptureRef;
  final bool sharedWithMentor;
  final DateTime? answeredAt;
  final String? answerNote;
  final DateTime createdAt;

  const PrayerEntry({
    required this.id,
    required this.title,
    this.body,
    this.category = PrayerCategory.request,
    this.prayingFor,
    this.scriptureRef,
    this.sharedWithMentor = false,
    this.answeredAt,
    this.answerNote,
    required this.createdAt,
  });

  bool get isAnswered => answeredAt != null;

  factory PrayerEntry.fromJson(Map<String, dynamic> json) => PrayerEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String?,
        category: PrayerCategory.fromApi(json['category'] as String?),
        prayingFor: json['praying_for'] as String?,
        scriptureRef: json['scripture_ref'] as String?,
        sharedWithMentor: json['shared_with_mentor'] as bool? ?? false,
        answeredAt: _parseUtc(json['answered_at']),
        answerNote: json['answer_note'] as String?,
        createdAt: _parseUtc(json['created_at']) ?? DateTime.now(),
      );

  /// Body for create/update. Empty optional fields are sent as null so they clear.
  Map<String, dynamic> toJson() => {
        'title': title,
        'body': _blankToNull(body),
        'category': category.name,
        'praying_for': _blankToNull(prayingFor),
        'scripture_ref': _blankToNull(scriptureRef),
        'shared_with_mentor': sharedWithMentor,
      };

  static String? _blankToNull(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  // The backend stores naive UTC datetimes; treat a missing offset as UTC.
  static DateTime? _parseUtc(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final hasZone = value.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(value);
    return DateTime.tryParse(hasZone ? value : '${value}Z')?.toLocal();
  }
}
