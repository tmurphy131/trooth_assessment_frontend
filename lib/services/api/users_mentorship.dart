part of '../api_service.dart';

// /    Users                                                          /, /    Assessments                                                    /, /    Mentorship (Apprentice)                                        /, /    Mentor ↔ Apprentice                                            /
extension UsersApi on ApiService {
  /* ─────────────────────────────────────────────────────────────────── */
  /*  👤  Users                                                          */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<void> createUser({
  required String uid, // Firebase UID (may be ignored by backend schema)
  required String email,
  required String role, // mentor | apprentice
  String? displayName,  // full name; backend actually requires 'name'
  }) async {
    final effectiveName = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : (email.contains('@') ? email.split('@').first : email);

    final payload = {
      // Backend Pydantic model UserCreate requires: name, email, role
      // Extra fields (like id) are ignored; we still send Firebase UID for potential future use.
      'id': uid,
      'name': effectiveName,
      'email': email,
      'role': role,
    };

    // NOTE: Backend route is defined with a trailing slash (@router.post("/")) under prefix '/users'.
    // Calling '/users' triggers an automatic 307 redirect to '/users/'. We call the canonical path directly.
    const path = '/users/';
    final r = await _http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    // Accept 200 OK or 201 Created (some deployments may return 201)
    if (r.statusCode == 307 || r.statusCode == 308) {
      // Unexpected redirect even with trailing slash; surface detail for diagnosis.
      throw ApiException(r.statusCode, 'createUser unexpected redirect (${r.statusCode}) location=${r.headers['location']}');
    }
    if (r.statusCode != 200 && r.statusCode != 201) {
      // Include body snippet for easier debugging of 422 validation errors
      throw ApiException(r.statusCode, 'createUser failed (${r.statusCode}) body=${r.body}');
    }
  }

  Future<void> assignApprentice({
    required String mentorId,
    required String apprenticeId,
  }) async {
    final p = {'mentor_id': mentorId, 'apprentice_id': apprenticeId};

    final r = await _http.post(
      Uri.parse('$_base/users/assign-apprentice'),
      headers: _headers(),
      body: jsonEncode(p),
    );
    if (r.statusCode != 200) {
      throw ApiException(r.statusCode, 'assignApprentice failed (${r.statusCode})');
    }
  }

  Future<Map<String, dynamic>> getUserProfile(String uid) async {
    final body = await _cachedBody('/users/$uid', const Duration(minutes: 5), () => _fetchUserProfile(uid));
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<String> _fetchUserProfile(String uid) async {
    final primary = await _http.get(
      Uri.parse('$_base/users/$uid'),
      headers: _headers(),
    );
    if (primary.statusCode == 200) return primary.body;
    if (primary.statusCode == 404) {
      // Fallback to /users/me (some deployments may restrict direct ID lookups)
      final me = await _http.get(
        Uri.parse('$_base/users/me'),
        headers: _headers(),
      );
      if (me.statusCode == 200) return me.body;
      throw ApiException(me.statusCode, 'getUserProfile failed 404 primary; fallback /users/me => ${me.statusCode}');
    }
    throw ApiException(primary.statusCode, 'getUserProfile failed (${primary.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  📊  Assessments                                                    */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> createAssessment(
      Map<String, dynamic> payload) async {
    final r = await _http.post(
      Uri.parse('$_base/assessments'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'createAssessment failed (${r.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  🤝  Mentorship (Apprentice)                                        */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> getMentorStatus() async {
    const path = '/apprentice/mentor/status';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'getMentorStatus failed (${r.statusCode}) ${r.body}');
  }

  Future<List<dynamic>> listPendingAgreements() async {
    const path = '/apprentice/agreements/pending';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'listPendingAgreements failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> revokeMentor({required String mentorId, String? reason}) async {
    const path = '/apprentice/mentor/revoke';
    final payload = <String, dynamic>{'mentor_id': mentorId};
    if (reason != null && reason.trim().isNotEmpty) payload['reason'] = reason.trim();
    final r = await _http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 409) throw Exception('Cannot revoke: pending agreement (409)');
    throw ApiException(r.statusCode, 'revokeMentor failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> saveAssessmentDraft(
      Map<String, dynamic> payload) async {
    final r = await _http.post(
      Uri.parse('$_base/assessment-drafts'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'saveAssessmentDraft failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getCurrentDraft() async {
    final r = await _http.get(
      Uri.parse('$_base/assessment-drafts'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'getCurrentDraft failed (${r.statusCode})');
  }

  Future<List<dynamic>> getAllDrafts() async {
    await _ensureFreshToken(); // Ensure fresh token
    final r = await _http.get(
      Uri.parse('$_base/assessment-drafts/list'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'getAllDrafts failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getDraftById(String draftId) async {
    final r = await _http.get(
      Uri.parse('$_base/assessment-drafts/$draftId'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'getDraftById failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> deleteDraft(String draftId) async {
    await _ensureFreshToken(); // Ensure fresh token
    final r = await _http.delete(
      Uri.parse('$_base/assessment-drafts/$draftId'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'deleteDraft failed (${r.statusCode})');
  }

  Future<List<dynamic>> getQuestions() async {
    final r = await _http.get(
      Uri.parse('$_base/question/questions'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'getQuestions failed (${r.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  🤝  Mentor ↔ Apprentice                                            */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<List<dynamic>> listApprentices() async {
    final r = await _http.get(
      Uri.parse('$_base/mentor/my-apprentices'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'listApprentices failed (${r.statusCode})');
  }

  Future<List<dynamic>> listInactiveApprentices() async {
    final r = await _http.get(Uri.parse('$_base/mentor/inactive-apprentices'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'listInactiveApprentices failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getApprenticeDraft(String apprenticeId) async {
    final r = await _http.get(
      Uri.parse('$_base/mentor/apprentice/$apprenticeId/draft'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'getApprenticeDraft failed (${r.statusCode})');
  }

  Future<List<dynamic>> getApprenticeSubmittedAssessments(String apprenticeId, {
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    int skip = 0,
    int limit = 10,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (category != null) queryParams['category'] = category;
    if (startDate != null) queryParams['start_date'] = startDate.toIso8601String();
    if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();
    
    final uri = Uri.parse('$_base/mentor/apprentice/$apprenticeId/submitted-assessments')
        .replace(queryParameters: queryParams);
    final r = await _http.get(uri, headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'getApprenticeSubmittedAssessments failed (${r.statusCode})');
  }
}
