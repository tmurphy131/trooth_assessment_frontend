part of '../api_service.dart';

// /    Spiritual Gifts Assessment                                    /
extension SpiritualGiftsApi on ApiService {
  /* ─────────────────────────────────────────────────────────────────── */
  /*  🌟  Spiritual Gifts Assessment                                    */
  /* ─────────────────────────────────────────────────────────────────── */

  static const String _spiritualGiftsTemplateKey = 'spiritual_gifts_v1';

  Future<Map<String, dynamic>> getSpiritualGiftsQuestions() async {
    const path = '/assessments/spiritual-gifts/questions';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'getSpiritualGiftsQuestions failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> submitSpiritualGifts(Map<String, int> answers) async {
    // Backend router prefix is /assessments/spiritual-gifts
    const path = '/assessments/spiritual-gifts/submit';
    final payload = { 'template_key': _spiritualGiftsTemplateKey, 'answers': answers };
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'submitSpiritualGifts failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> getSpiritualGiftsLatest() async {
    const path = '/assessments/spiritual-gifts/latest';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return _normalizeSpiritualGiftsResult(data);
    }
    if (r.statusCode == 404) return {}; // no submission yet
    throw ApiException(r.statusCode, 'getSpiritualGiftsLatest failed (${r.statusCode}) ${r.body}');
  }

  /// Fetch a specific spiritual gifts assessment by ID.
  Future<Map<String, dynamic>> getSpiritualGiftsById(String assessmentId) async {
    final path = '/assessments/spiritual-gifts/by-id/$assessmentId';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return _normalizeSpiritualGiftsResult(data);
    }
    if (r.statusCode == 404) return {};
    throw ApiException(r.statusCode, 'getSpiritualGiftsById failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> mentorGetApprenticeSpiritualGiftsLatest(String apprenticeId) async {
    final path = '/assessments/spiritual-gifts/$apprenticeId/latest';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return _normalizeSpiritualGiftsResult(data);
    }
    if (r.statusCode == 404) return {}; // none yet
    throw ApiException(r.statusCode, 'mentorGetApprenticeSpiritualGiftsLatest failed (${r.statusCode}) ${r.body}');
  }

  Map<String, dynamic> _normalizeSpiritualGiftsResult(Map<String, dynamic> data) {
    // If backend already supplies the full contract, return early.
  final hasTruncated = data.containsKey('top_gifts_truncated');
  final hasExpanded = data.containsKey('top_gifts_expanded');

    // Accept legacy shape with 'top_gifts' + 'scores'
    if (!hasTruncated || !hasExpanded) {
      final List<dynamic> scores = (data['all_scores'] ?? data['scores'] ?? []) as List<dynamic>;
      final List<dynamic> tops = (data['top_gifts'] ?? []) as List<dynamic>;
      // Build deterministic ordering by score desc then gift asc
      List<Map<String, dynamic>> all = scores.cast<Map<String, dynamic>>();
      if (all.isEmpty && tops.isNotEmpty) {
        // If only tops exist, treat as all (fallback)
        all = tops.cast<Map<String, dynamic>>();
      }
      all.sort((a,b){
        final sa = (a['score'] ?? 0) as num;
        final sb = (b['score'] ?? 0) as num;
        if (sb.compareTo(sa) != 0) return sb.compareTo(sa);
        final ga = (a['gift'] ?? a['gift_name'] ?? a['name'] ?? '').toString();
        final gb = (b['gift'] ?? b['gift_name'] ?? b['name'] ?? '').toString();
        return ga.compareTo(gb);
      });
      // Determine top truncated (first 3) and expanded (ties at 3rd)
      final truncated = all.take(3).toList();
      int? thirdScore = truncated.length == 3 ? (truncated[2]['score'] ?? 0) as int : null;
      final expanded = thirdScore == null ? truncated : all.where((m) => (m['score'] ?? 0) >= thirdScore).toList();
      data['top_gifts_truncated'] = truncated;
      data['top_gifts_expanded'] = expanded;
      if (!data.containsKey('rank_meta') && thirdScore != null) {
        data['rank_meta'] = { 'third_place_score': thirdScore };
      }
      if (!data.containsKey('all_scores')) {
        data['all_scores'] = all;
      }
    }
    return data;
  }

  Future<Map<String, dynamic>> mentorGetApprenticeSpiritualGiftsHistory(String apprenticeId, {String? cursor, int? limit}) async {
    final qp = <String,String>{};
    if (cursor != null) qp['cursor'] = cursor;
    if (limit != null) qp['limit'] = limit.toString();
    final base = '/assessments/spiritual-gifts/$apprenticeId/history';
    final uri = Uri.parse('$_base$base').replace(queryParameters: qp.isEmpty ? null : qp);
    final r = await _http.get(uri, headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'mentorGetApprenticeSpiritualGiftsHistory failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> getSpiritualGiftsHistory({String? cursor, int? limit}) async {
    final qp = <String,String>{};
    if (cursor != null) qp['cursor'] = cursor;
    if (limit != null) qp['limit'] = limit.toString();
    const base = '/assessments/spiritual-gifts/history';
    final uri = Uri.parse('$_base$base').replace(queryParameters: qp.isEmpty ? null : qp);
    final r = await _http.get(uri, headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {'items': [], 'next_cursor': null};
    throw ApiException(r.statusCode, 'getSpiritualGiftsHistory failed (${r.statusCode}) ${r.body}');
  }

  Future<bool> emailMySpiritualGiftsReport() async {
    const path = '/assessments/spiritual-gifts/email-report';
    // Backend expects a JSON body: { to_email, optional assessment_id, include_pdf, include_html }
  final email = FirebaseAuth.instance.currentUser?.email; // may be null; still attempt
    final payload = {
      'to_email': email ?? '',
      'include_pdf': true,
      'include_html': false,
    };
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return true;
    if (r.statusCode == 429) {
      throw Exception('RATE_LIMIT: ${r.body}');
    }
    throw ApiException(r.statusCode, 'emailMySpiritualGiftsReport failed (${r.statusCode}) ${r.body}');
  }

  Future<bool> emailMySpiritualGiftsReportForSubmission(String submissionId) async {
    const path = '/assessments/spiritual-gifts/email-report';
    final payload = {
      'assessment_id': submissionId,
  'to_email': FirebaseAuth.instance.currentUser?.email ?? '',
      'include_pdf': true,
      'include_html': false,
    };
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return true;
    if (r.statusCode == 404) {
      throw Exception('Submission not found');
    }
    if (r.statusCode == 429) {
      throw Exception('RATE_LIMIT: ${r.body}');
    }
    throw ApiException(r.statusCode, 'emailMySpiritualGiftsReportForSubmission failed (${r.statusCode}) ${r.body}');
  }

  Future<bool> mentorEmailSpiritualGiftsReport(String apprenticeId, {String? toEmail}) async {
    final path = '/assessments/spiritual-gifts/$apprenticeId/email-report';
    // Use provided email or current user's email from Firebase
    final email = toEmail ?? FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.isEmpty) {
      throw Exception('No email address available for sending report');
    }
    final body = {
      'to_email': email,
      'include_pdf': true,
      'include_html': false,
    };
    final r = await _http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode == 200) return true;
    if (r.statusCode == 429) {
      throw Exception('RATE_LIMIT: ${r.body}');
    }
    throw ApiException(r.statusCode, 'mentorEmailSpiritualGiftsReport failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> getSpiritualGiftsTemplateMetadata() async {
    const path = '/spiritual-gifts/template/metadata';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'getSpiritualGiftsTemplateMetadata failed (${r.statusCode}) ${r.body}');
  }

  Future<List<Map<String, dynamic>>> getSpiritualGiftsDefinitions() async {
    const path = '/spiritual-gifts/definitions';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) {
      final decoded = jsonDecode(r.body);
      if (decoded is List) {
        return decoded.map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v))).cast<Map<String,dynamic>>().toList();
      }
      if (decoded is Map && decoded['items'] is List) {
        return (decoded['items'] as List).map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v))).cast<Map<String,dynamic>>().toList();
      }
      throw Exception('Unexpected definitions payload shape');
    }
    if (r.statusCode == 404) return [];
    throw ApiException(r.statusCode, 'getSpiritualGiftsDefinitions failed (${r.statusCode}) ${r.body}');
  }
}
