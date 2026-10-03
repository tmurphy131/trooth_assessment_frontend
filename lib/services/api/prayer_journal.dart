part of '../api_service.dart';

// /    Prayer Journal                                                /
extension PrayerJournalApi on ApiService {
  /* ─────────────────────────────────────────────────────────────────── */
  /*  🙏  Prayer Journal                                                */
  /* ─────────────────────────────────────────────────────────────────── */

  /// [status] is 'active' or 'answered'; [category] is a PrayerCategory name.
  Future<List<PrayerEntry>> getPrayerEntries({String? status, String? category}) async {
    final uri = Uri.parse('$_base/prayer-journal/entries').replace(queryParameters: {
      if (status != null) 'status': status,
      if (category != null) 'category': category,
    });
    final r = await _http.get(uri, headers: _headers());
    if (r.statusCode == 200) return _decodePrayerEntries(r.body);
    throw ApiException(r.statusCode, 'getPrayerEntries failed (${r.statusCode}) ${r.body}');
  }

  Future<PrayerEntry> createPrayerEntry(PrayerEntry entry) async {
    final r = await _http.post(Uri.parse('$_base/prayer-journal/entries'),
        headers: _headers(), body: jsonEncode(entry.toJson()));
    if (r.statusCode == 200) return PrayerEntry.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    throw ApiException(r.statusCode, 'createPrayerEntry failed (${r.statusCode}) ${r.body}');
  }

  Future<PrayerEntry> updatePrayerEntry(PrayerEntry entry) async {
    final r = await _http.patch(Uri.parse('$_base/prayer-journal/entries/${entry.id}'),
        headers: _headers(), body: jsonEncode(entry.toJson()));
    if (r.statusCode == 200) return PrayerEntry.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    throw ApiException(r.statusCode, 'updatePrayerEntry failed (${r.statusCode}) ${r.body}');
  }

  Future<void> deletePrayerEntry(String id) async {
    final r = await _http.delete(Uri.parse('$_base/prayer-journal/entries/$id'), headers: _headers());
    if (r.statusCode == 204 || r.statusCode == 200) return;
    throw ApiException(r.statusCode, 'deletePrayerEntry failed (${r.statusCode}) ${r.body}');
  }

  Future<PrayerEntry> markPrayerAnswered(String id, {String? answerNote}) async {
    final note = answerNote?.trim();
    final r = await _http.post(Uri.parse('$_base/prayer-journal/entries/$id/answered'),
        headers: _headers(), body: jsonEncode({'answer_note': (note == null || note.isEmpty) ? null : note}));
    if (r.statusCode == 200) return PrayerEntry.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    throw ApiException(r.statusCode, 'markPrayerAnswered failed (${r.statusCode}) ${r.body}');
  }

  Future<PrayerEntry> unmarkPrayerAnswered(String id) async {
    final r = await _http.delete(Uri.parse('$_base/prayer-journal/entries/$id/answered'), headers: _headers());
    if (r.statusCode == 200) return PrayerEntry.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    throw ApiException(r.statusCode, 'unmarkPrayerAnswered failed (${r.statusCode}) ${r.body}');
  }

  /// Entries an apprentice has shared with the signed-in mentor.
  Future<List<PrayerEntry>> mentorGetSharedPrayerEntries(String apprenticeId) async {
    final r = await _http.get(Uri.parse('$_base/prayer-journal/mentor/apprentices/$apprenticeId/entries'),
        headers: _headers());
    if (r.statusCode == 200) return _decodePrayerEntries(r.body);
    throw ApiException(r.statusCode, 'mentorGetSharedPrayerEntries failed (${r.statusCode}) ${r.body}');
  }

  List<PrayerEntry> _decodePrayerEntries(String body) => (jsonDecode(body) as List)
      .map((e) => PrayerEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}
