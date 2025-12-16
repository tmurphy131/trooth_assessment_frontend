// lib/services/api_service.dart
//
// Centralised HTTP wrapper for the T[root]H Assessment backend.
// • Singleton with shared Firebase-ID-token (bearerToken)
// • dev.log() output around **every** HTTP transaction
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:developer' as dev;                  //  ← logging
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Default dev URL
/// • Android emulator → 10.0.2.2
/// • iOS sim / Flutter Web → use host machine IP for Docker
/// • Host machine → localhost or 127.0.0.1
const String _devBaseUrl = 'https://trooth-assessment-dev.onlyblv.com';

class ApiService {
  /* ── Singleton ────────────────────────────────────────────────────── */
  factory ApiService() => _instance;
  ApiService._internal();
  static final ApiService _instance = ApiService._internal();

  /* ── Config ───────────────────────────────────────────────────────── */
  /// Override for e2e / staging builds before the first call:
  /// `ApiService().baseUrlOverride = 'https://api.prod.trooth.app';`
  String? baseUrlOverride;
  String get _base => baseUrlOverride ?? _devBaseUrl;

  /// Set after Firebase sign-in:
  /// `ApiService().bearerToken = await user.getIdToken();`
  String? bearerToken;
  DateTime? _tokenExpiry; // cached expiry for smarter refresh

  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
      if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
    };
    // (Token value intentionally not logged for security.)
    if (bearerToken == null) {
      dev.log('Headers without auth token');
    }
    return headers;
  }

  // Helper method to refresh token only when needed (Option C optimization)
  // Refresh conditions:
  // • No token yet
  // • Expiry unknown
  // • Expiring within next 2 minutes
  // Reduces per-call forced refresh overhead from Option B.
  Future<void> _ensureFreshToken({bool force = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return; // nothing to do if not signed in

      final now = DateTime.now();
      final needsRefresh = force ||
          bearerToken == null ||
          _tokenExpiry == null ||
          _tokenExpiry!.isBefore(now.add(const Duration(minutes: 2)));

      if (!needsRefresh) return; // still fresh

      // Use non-forced refresh first; if still null attempt forced
      final result = await user.getIdTokenResult(!force && needsRefresh ? false : true);
      final token = result.token;
      if (token != null && token.isNotEmpty) {
        bearerToken = token;
        _tokenExpiry = result.expirationTime; // may be null on some platforms
  dev.log('Token refreshed (exp: ${_tokenExpiry?.toIso8601String()})');
      }
    } catch (e) {
      print('❌ Error refreshing token: $e');
    }
  }

  /* ── tiny helpers for uniform log lines ───────────────────────────── */
  void _logReq(String tag, String verb, String path, [Object? body]) =>
      dev.log('$tag: $verb $path${body != null ? ' body=${jsonEncode(body)}' : ''}');

  void _logRes(String tag, http.Response r) {
    final preview = r.body.length > 100 ? '${r.body.substring(0, 100)}...' : r.body;
    dev.log('$tag: ${r.statusCode} ${r.reasonPhrase} → $preview');
    
    // Also print to console for debugging
    print('🌐 $tag: ${r.statusCode} ${r.reasonPhrase} → $preview');
    if (r.statusCode >= 400) {
      print('❌ Error response: ${r.body}');
    }
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  🩺  Health                                                         */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<String> ping() async {
    const tag = 'API-ping';
    _logReq(tag, 'GET', '/');
    final r = await http.get(Uri.parse('$_base/'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body)['message'] as String;
    throw Exception('Ping failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> healthCheck() async {
    const tag = 'API-healthCheck';
    try {
      _logReq(tag, 'GET', '/health');
      final r = await http.get(Uri.parse('$_base/health'), headers: _headers());
      _logRes(tag, r);
      if (r.statusCode == 200) return jsonDecode(r.body);
      throw Exception('Health check failed (${r.statusCode})');
    } catch (e) {
      print('❌ $tag Network Error: $e');
      throw Exception('Health check network error: $e');
    }
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  👤  Users                                                          */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<void> createUser({
  required String uid, // Firebase UID (may be ignored by backend schema)
  required String email,
  required String role, // mentor | apprentice
  String? displayName,  // full name; backend actually requires 'name'
  }) async {
    const tag = 'API-createUser';
  await _ensureFreshToken();
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
    _logReq(tag, 'POST', path, payload);
    final r = await http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    _logRes(tag, r);
    // Accept 200 OK or 201 Created (some deployments may return 201)
    if (r.statusCode == 307 || r.statusCode == 308) {
      // Unexpected redirect even with trailing slash; surface detail for diagnosis.
      throw Exception('createUser unexpected redirect (${r.statusCode}) location=${r.headers['location']}');
    }
    if (r.statusCode != 200 && r.statusCode != 201) {
      // Include body snippet for easier debugging of 422 validation errors
      throw Exception('createUser failed (${r.statusCode}) body=${r.body}');
    }
  }

  Future<void> assignApprentice({
    required String mentorId,
    required String apprenticeId,
  }) async {
    const tag = 'API-assignApprentice';
  await _ensureFreshToken();
    final p = {'mentor_id': mentorId, 'apprentice_id': apprenticeId};

    _logReq(tag, 'POST', '/users/assign-apprentice', p);
    final r = await http.post(
      Uri.parse('$_base/users/assign-apprentice'),
      headers: _headers(),
      body: jsonEncode(p),
    );
    _logRes(tag, r);
    if (r.statusCode != 200) {
      throw Exception('assignApprentice failed (${r.statusCode})');
    }
  }

  Future<Map<String, dynamic>> getUserProfile(String uid) async {
    const tag = 'API-getUserProfile';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/users/$uid');
    final primary = await http.get(
      Uri.parse('$_base/users/$uid'),
      headers: _headers(),
    );
    _logRes(tag, primary);
    if (primary.statusCode == 200) return jsonDecode(primary.body);
    if (primary.statusCode == 404) {
      // Fallback to /users/me (some deployments may restrict direct ID lookups)
      _logReq(tag, 'GET', '/users/me');
      final me = await http.get(
        Uri.parse('$_base/users/me'),
        headers: _headers(),
      );
      _logRes(tag, me);
      if (me.statusCode == 200) return jsonDecode(me.body);
      throw Exception('getUserProfile failed 404 primary; fallback /users/me => ${me.statusCode}');
    }
    throw Exception('getUserProfile failed (${primary.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  📊  Assessments                                                    */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> createAssessment(
      Map<String, dynamic> payload) async {
    const tag = 'API-createAsmt';
  await _ensureFreshToken();
    _logReq(tag, 'POST', '/assessments', payload);
    final r = await http.post(
      Uri.parse('$_base/assessments'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('createAssessment failed (${r.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  🤝  Mentorship (Apprentice)                                        */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> getMentorStatus() async {
    const tag = 'API-getMentorStatus';
    await _ensureFreshToken();
    const path = '/apprentice/mentor/status';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('getMentorStatus failed (${r.statusCode}) ${r.body}');
  }

  Future<List<dynamic>> listPendingAgreements() async {
    const tag = 'API-listPendingAgreements';
    await _ensureFreshToken();
    const path = '/apprentice/agreements/pending';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('listPendingAgreements failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> revokeMentor({String? reason}) async {
    const tag = 'API-revokeMentor';
    await _ensureFreshToken();
    const path = '/apprentice/mentor/revoke';
    final payload = reason == null || reason.trim().isEmpty ? {} : { 'reason': reason.trim() };
    _logReq(tag, 'POST', path, payload);
    final r = await http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    // Surface 409 specially
    if (r.statusCode == 409) {
      throw Exception('Cannot revoke: pending agreement (409)');
    }
    throw Exception('revokeMentor failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> saveAssessmentDraft(
      Map<String, dynamic> payload) async {
    const tag = 'API-saveDraft';
    await _ensureFreshToken();
    _logReq(tag, 'POST', '/assessment-drafts', payload);
    final r = await http.post(
      Uri.parse('$_base/assessment-drafts'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('saveAssessmentDraft failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getCurrentDraft() async {
    const tag = 'API-getCurrentDraft';
    await _ensureFreshToken();
    _logReq(tag, 'GET', '/assessment-drafts');
    final r = await http.get(
      Uri.parse('$_base/assessment-drafts'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('getCurrentDraft failed (${r.statusCode})');
  }

  Future<List<dynamic>> getAllDrafts() async {
    await _ensureFreshToken(); // Ensure fresh token
    const tag = 'API-getAllDrafts';
    _logReq(tag, 'GET', '/assessment-drafts/list');
    final r = await http.get(
      Uri.parse('$_base/assessment-drafts/list'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('getAllDrafts failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getDraftById(String draftId) async {
    const tag = 'API-getDraftById';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/assessment-drafts/$draftId');
    final r = await http.get(
      Uri.parse('$_base/assessment-drafts/$draftId'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('getDraftById failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> deleteDraft(String draftId) async {
    await _ensureFreshToken(); // Ensure fresh token
    const tag = 'API-deleteDraft';
    _logReq(tag, 'DELETE', '/assessment-drafts/$draftId');
    final r = await http.delete(
      Uri.parse('$_base/assessment-drafts/$draftId'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('deleteDraft failed (${r.statusCode})');
  }

  Future<List<dynamic>> getQuestions() async {
    const tag = 'API-getQuestions';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/question/questions');
    final r = await http.get(
      Uri.parse('$_base/question/questions'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('getQuestions failed (${r.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  🤝  Mentor ↔ Apprentice                                            */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<List<dynamic>> listApprentices() async {
    const tag = 'API-listApprentices';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/mentor/my-apprentices');
    final r = await http.get(
      Uri.parse('$_base/mentor/my-apprentices'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('listApprentices failed (${r.statusCode})');
  }

  Future<List<dynamic>> listInactiveApprentices() async {
    const tag = 'API-listInactiveApprentices';
    await _ensureFreshToken();
    _logReq(tag, 'GET', '/mentor/inactive-apprentices');
    final r = await http.get(Uri.parse('$_base/mentor/inactive-apprentices'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('listInactiveApprentices failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getApprenticeDraft(String apprenticeId) async {
    const tag = 'API-getApprenticeDraft';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/mentor/apprentice/$apprenticeId/draft');
    final r = await http.get(
      Uri.parse('$_base/mentor/apprentice/$apprenticeId/draft'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('getApprenticeDraft failed (${r.statusCode})');
  }

  Future<List<dynamic>> getApprenticeSubmittedAssessments(String apprenticeId, {
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    int skip = 0,
    int limit = 10,
  }) async {
    const tag = 'API-getApprenticeSubmittedAssessments';
  await _ensureFreshToken();
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (category != null) queryParams['category'] = category;
    if (startDate != null) queryParams['start_date'] = startDate.toIso8601String();
    if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();
    
    final uri = Uri.parse('$_base/mentor/apprentice/$apprenticeId/submitted-assessments')
        .replace(queryParameters: queryParams);
    _logReq(tag, 'GET', uri.path);
    final r = await http.get(uri, headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('getApprenticeSubmittedAssessments failed (${r.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  �  Submissions (Mentor view)                                       */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> fetchSubmissionDetail({required String assessmentId}) async {
    const tag = 'API-fetchSubmissionDetail';
    await _ensureFreshToken();
    final path = '/mentor/assessment/$assessmentId';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 403) throw Exception('Forbidden');
    throw Exception('fetchSubmissionDetail failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> fetchMentorReportV2Json({required String assessmentId}) async {
    // Backend returns HTML for preview route; we expose a JSON path via /assessments/{id} (scores+mentor_report_v2)
    const tag = 'API-fetchMentorReportV2Json';
    await _ensureFreshToken();
    final path = '/mentor/assessment/$assessmentId';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return data;
    }
    throw Exception('fetchMentorReportV2Json failed (${r.statusCode})');
  }

  Future<String> fetchMentorReportV2Html({required String assessmentId}) async {
    const tag = 'API-fetchMentorReportV2Html';
    await _ensureFreshToken();
    final path = '/assessments/$assessmentId/mentor-report-v2';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return r.body;
    if (r.statusCode == 404) throw Exception('No report');
    throw Exception('fetchMentorReportV2Html failed (${r.statusCode})');
  }

  Future<http.Response> downloadMentorReportPdf({required String assessmentId}) async {
    const tag = 'API-downloadMentorReportPdf';
    await _ensureFreshToken();
    final path = '/assessments/$assessmentId/mentor-report-v2.pdf';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    return r;
  }

  Future<Map<String, dynamic>> emailMentorReportByAssessment({required String assessmentId, required String toEmail, bool includePdf = true}) async {
    const tag = 'API-emailMentorReportByAssessment';
    await _ensureFreshToken();
    final path = '/assessments/$assessmentId/email-report';
    final body = { 'to_email': toEmail, 'include_pdf': includePdf };
    _logReq(tag, 'POST', path, body);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(body));
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('emailMentorReportByAssessment failed (${r.statusCode}) ${r.body}');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  �🧑‍🏫  Mentor Profile                                               */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> getMyMentorProfile() async {
    const tag = 'API-getMyMentorProfile';
    await _ensureFreshToken();
    const path = '/mentor-profile/me';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('getMyMentorProfile failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> updateMyMentorProfile({
    String? avatarUrl,
    String? roleTitle,
    String? organization,
    String? phone,
    String? bio,
  }) async {
    const tag = 'API-updateMyMentorProfile';
    await _ensureFreshToken();
    const path = '/mentor-profile/me';
    final payload = {
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (roleTitle != null) 'role_title': roleTitle,
      if (organization != null) 'organization': organization,
      if (phone != null) 'phone': phone,
      if (bio != null) 'bio': bio,
    };
    _logReq(tag, 'PUT', path, payload);
    final r = await http.put(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('updateMyMentorProfile failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> getActiveMentorProfileForApprentice() async {
    const tag = 'API-getMentorProfileForApprentice';
    await _ensureFreshToken();
    const path = '/mentor-profile/for-apprentice';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('getMentorProfileForApprentice failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> getAssessmentDetail(String assessmentId) async {
    const tag = 'API-getAssessmentDetail';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/mentor/assessment/$assessmentId');
    final r = await http.get(
      Uri.parse('$_base/mentor/assessment/$assessmentId'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('getAssessmentDetail failed (${r.statusCode})');
  }

  /// Get completed assessments with AI scoring results
  Future<List<dynamic>> getCompletedAssessments() async {
    const tag = 'API-getCompletedAssessments';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/assessment-drafts/completed');
    final r = await http.get(
      Uri.parse('$_base/assessment-drafts/completed'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('getCompletedAssessments failed (${r.statusCode})');
  }

  /// Get detailed assessment results with AI feedback
  Future<Map<String, dynamic>> getAssessmentResults(String assessmentId) async {
    const tag = 'API-getAssessmentResults';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/assessments/$assessmentId');
    final r = await http.get(
      Uri.parse('$_base/assessments/$assessmentId'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('getAssessmentResults failed (${r.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  🔗  Mentor Resources (links only)                                   */
  /* ─────────────────────────────────────────────────────────────────── */

  // Apprentice: list shared resources targeted to me
  Future<List<dynamic>> listMySharedResources() async {
    const tag = 'API-listMySharedResources';
    await _ensureFreshToken();
    const path = '/apprentice/resources';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('listMySharedResources failed (${r.statusCode}) ${r.body}');
  }

  // Mentor: list my resources (optionally filter by apprentice)
  Future<List<dynamic>> listMentorResources({String? apprenticeId}) async {
    const tag = 'API-listMentorResources';
    await _ensureFreshToken();
    var uri = Uri.parse('$_base/mentor/resources');
    if (apprenticeId != null && apprenticeId.isNotEmpty) {
      uri = uri.replace(queryParameters: {'apprentice_id': apprenticeId});
    }
    _logReq(tag, 'GET', uri.path + (uri.query.isNotEmpty ? '?'+uri.query : ''));
    final r = await http.get(uri, headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('listMentorResources failed (${r.statusCode}) ${r.body}');
  }

  // Mentor: create a resource
  Future<Map<String, dynamic>> createMentorResource({
    String? apprenticeId,
    required String title,
    String? description,
    String? linkUrl,
    bool isShared = true,
  }) async {
    const tag = 'API-createMentorResource';
    await _ensureFreshToken();
    const path = '/mentor/resources';
    final payload = {
      if (apprenticeId != null && apprenticeId.isNotEmpty) 'apprentice_id': apprenticeId,
      'title': title,
      if (description != null) 'description': description,
      if (linkUrl != null) 'link_url': linkUrl,
      'is_shared': isShared,
    };
    _logReq(tag, 'POST', path, payload);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    _logRes(tag, r);
    if (r.statusCode == 200 || r.statusCode == 201) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('createMentorResource failed (${r.statusCode}) ${r.body}');
  }

  // Mentor: update a resource
  Future<Map<String, dynamic>> updateMentorResource({
    required String resourceId,
    String? apprenticeId,
    String? title,
    String? description,
    String? linkUrl,
    bool? isShared,
  }) async {
    const tag = 'API-updateMentorResource';
    await _ensureFreshToken();
    final path = '/mentor/resources/$resourceId';
    final payload = <String, dynamic>{
      if (apprenticeId != null) 'apprentice_id': apprenticeId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (linkUrl != null) 'link_url': linkUrl,
      if (isShared != null) 'is_shared': isShared,
    };
    _logReq(tag, 'PATCH', path, payload);
    final r = await http.patch(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('updateMentorResource failed (${r.statusCode}) ${r.body}');
  }

  // Mentor: delete a resource
  Future<bool> deleteMentorResource(String resourceId) async {
    const tag = 'API-deleteMentorResource';
    await _ensureFreshToken();
    final path = '/mentor/resources/$resourceId';
    _logReq(tag, 'DELETE', path);
    final r = await http.delete(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return (jsonDecode(r.body) as Map<String, dynamic>)['deleted'] == true;
    throw Exception('deleteMentorResource failed (${r.statusCode}) ${r.body}');
  }

  Future<List<dynamic>> getSubmittedDrafts({
    String? apprenticeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    const tag = 'API-getSubmittedDrafts';
  await _ensureFreshToken();
    final queryParams = <String, String>{};
    if (apprenticeId != null) queryParams['apprentice_id'] = apprenticeId;
    if (startDate != null) queryParams['start_date'] = startDate.toIso8601String();
    if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();
    
    final uri = Uri.parse('$_base/mentor/submitted-drafts')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    _logReq(tag, 'GET', uri.path);
    final r = await http.get(uri, headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('getSubmittedDrafts failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getSubmittedDraft(String draftId) async {
    const tag = 'API-getSubmittedDraft';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/mentor/submitted-drafts/$draftId');
    final r = await http.get(
      Uri.parse('$_base/mentor/submitted-drafts/$draftId'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('getSubmittedDraft failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getApprenticeProfile(String apprenticeId) async {
    const tag = 'API-getApprenticeProfile';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/mentor/my-apprentices/$apprenticeId');
    final r = await http.get(
      Uri.parse('$_base/mentor/my-apprentices/$apprenticeId'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('getApprenticeProfile failed (${r.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  📝  Assessment Drafts (for Apprentices)                            */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> startDraft(String templateId) async {
    const tag = 'API-startDraft';
  await _ensureFreshToken();
    _logReq(tag, 'POST', '/assessment-drafts/start?template_id=$templateId', {});
    final r = await http.post(
      Uri.parse('$_base/assessment-drafts/start?template_id=$templateId'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('startDraft failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getDraft() async {
    const tag = 'API-getDraft';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/assessment-drafts');
    final r = await http.get(
      Uri.parse('$_base/assessment-drafts'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('getDraft failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> updateDraft(Map<String, dynamic> payload, {String? draftId}) async {
    const tag = 'API-updateDraft';
    await _ensureFreshToken();
    
    // Use specific draft ID endpoint if provided, otherwise use the legacy endpoint
    final endpoint = draftId != null ? '/assessment-drafts/$draftId' : '/assessment-drafts';
    
    _logReq(tag, 'PATCH', endpoint, payload);
    final r = await http.patch(
      Uri.parse('$_base$endpoint'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('updateDraft failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> submitDraft({String? draftId, String? templateId}) async {
    const tag = 'API-submitDraft';
    await _ensureFreshToken();
    String path = '/assessment-drafts/submit';
    final qp = <String, String>{};
    if (draftId != null && draftId.isNotEmpty) qp['draft_id'] = draftId;
    if (templateId != null && templateId.isNotEmpty) qp['template_id'] = templateId;
    if (qp.isNotEmpty) {
      final query = qp.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
      path = '$path?$query';
    }
    _logReq(tag, 'POST', path);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('submitDraft failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getAssessmentStatus(String assessmentId) async {
    const tag = 'API-getAssessmentStatus';
    await _ensureFreshToken();
    final path = '/assessments/$assessmentId/status';
    _logReq(tag, 'GET', path);
    final r = await http.get(
      Uri.parse('$_base$path'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('getAssessmentStatus failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> resumeDraft() async {
    const tag = 'API-resumeDraft';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/assessment-drafts/resume');
    final r = await http.get(
      Uri.parse('$_base/assessment-drafts/resume'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('resumeDraft failed (${r.statusCode})');
  }

  Future<List<dynamic>> getSubmittedAssessments(String apprenticeId) async {
    const tag = 'API-getSubmittedAssessments';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/assessment-drafts/submitted-assessments/$apprenticeId');
    final r = await http.get(
      Uri.parse('$_base/assessment-drafts/submitted-assessments/$apprenticeId'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('getSubmittedAssessments failed (${r.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  📋  Templates                                                      */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<List<dynamic>> getPublishedTemplates() async {
    const tag = 'API-getPublishedTemplates';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/templates/published');
    final r = await http.get(
      Uri.parse('$_base/templates/published'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('getPublishedTemplates failed (${r.statusCode})');
  }

  // Admin Template Management
  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> payload) async {
    const tag = 'API-createTemplate';
    try {
  await _ensureFreshToken();
      print('🔍 $tag Starting request...');
      print('🔍 Base URL: $_base');
      print('🔍 Full URL: $_base/admin/templates');
      print('🔍 Payload: $payload');
      
      _logReq(tag, 'POST', '/admin/templates', payload);
      
      final uri = Uri.parse('$_base/admin/templates');
      final headers = _headers();
      final body = jsonEncode(payload);
      
      print('🔍 URI: $uri');
      print('🔍 Headers: $headers');
      print('🔍 Body: $body');
      
      final r = await http.post(uri, headers: headers, body: body);
      
      print('🔍 Response received');
      _logRes(tag, r);
      if (r.statusCode == 200) return jsonDecode(r.body);
      throw Exception('createTemplate failed (${r.statusCode})');
    } catch (e) {
      print('❌ $tag Network Error Details: $e');
      print('❌ $tag Error Type: ${e.runtimeType}');
      if (e.toString().contains('Failed to fetch')) {
        print('❌ This is likely a CORS or network connectivity issue');
        print('❌ Try opening http://127.0.0.1:8000/admin/templates in browser');
      }
      throw Exception('createTemplate network error: $e');
    }
  }

  Future<Map<String, dynamic>> updateTemplate(String templateId, Map<String, dynamic> payload) async {
    const tag = 'API-updateTemplate';
    try {
  await _ensureFreshToken();
      print('🔍 $tag Starting request...');
      print('🔍 Template ID: $templateId');
      print('🔍 Full URL: $_base/admin/templates/$templateId');
      print('🔍 Payload: $payload');
      
      _logReq(tag, 'PUT', '/admin/templates/$templateId', payload);
      
      final uri = Uri.parse('$_base/admin/templates/$templateId');
      final headers = _headers();
      final body = jsonEncode(payload);
      
      print('🔍 URI: $uri');
      print('🔍 Headers: $headers');
      print('🔍 Body: $body');
      
      final r = await http.put(uri, headers: headers, body: body);
      
      print('🔍 Response received');
      _logRes(tag, r);
      if (r.statusCode == 200) return jsonDecode(r.body);
      throw Exception('updateTemplate failed (${r.statusCode})');
    } catch (e) {
      print('❌ $tag Network Error Details: $e');
      print('❌ $tag Error Type: ${e.runtimeType}');
      throw Exception('updateTemplate network error: $e');
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    const tag = 'API-deleteTemplate';
    try {
  await _ensureFreshToken();
      print('🔍 $tag Starting request...');
      print('🔍 Template ID: $templateId');
      print('🔍 Full URL: $_base/admin/templates/$templateId');
      
      _logReq(tag, 'DELETE', '/admin/templates/$templateId');
      
      final uri = Uri.parse('$_base/admin/templates/$templateId');
      final headers = _headers();
      
      print('🔍 URI: $uri');
      print('🔍 Headers: $headers');
      
      final r = await http.delete(uri, headers: headers);
      
      print('🔍 Response received');
      _logRes(tag, r);
      if (r.statusCode == 200) return;
      throw Exception('deleteTemplate failed (${r.statusCode})');
    } catch (e) {
      print('❌ $tag Network Error Details: $e');
      print('❌ $tag Error Type: ${e.runtimeType}');
      throw Exception('deleteTemplate network error: $e');
    }
  }

  Future<List<dynamic>> getAllTemplates() async {
    const tag = 'API-getAllTemplates';
    try {
  await _ensureFreshToken();
      _logReq(tag, 'GET', '/admin/templates');
      final r = await http.get(
        Uri.parse('$_base/admin/templates'),
        headers: _headers(),
      );
      _logRes(tag, r);
      if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
      throw Exception('getAllTemplates failed (${r.statusCode})');
    } catch (e) {
      print('❌ $tag Network Error: $e');
      throw Exception('getAllTemplates network error: $e');
    }
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  📈  Progress (Featured + Reports)                                  */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> getProgressMasterLatest() async {
    const tag = 'API-progressMasterLatest';
    await _ensureFreshToken();
    const path = '/progress/master/latest';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return <String, dynamic>{}; // treat as empty state
    throw Exception('progressMasterLatest failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getProgressGiftsLatest() async {
    const tag = 'API-progressGiftsLatest';
    await _ensureFreshToken();
    const path = '/progress/spiritual-gifts/latest';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return <String, dynamic>{};
    throw Exception('progressGiftsLatest failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getProgressReports({int limit = 20, String? cursor}) async {
    const tag = 'API-progressReports';
    await _ensureFreshToken();
    final qp = {
      'limit': limit.toString(),
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final uri = Uri.parse('$_base/progress/reports').replace(queryParameters: qp);
    _logReq(tag, 'GET', uri.toString());
    final r = await http.get(uri, headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('progressReports failed (${r.statusCode})');
  }

  /// Get simplified report for apprentice's own assessment
  Future<Map<String, dynamic>> getMySimplifiedReport(String assessmentId) async {
    const tag = 'API-getMySimplifiedReport';
    await _ensureFreshToken();
    _logReq(tag, 'GET', '/progress/reports/$assessmentId/simplified');
    final r = await http.get(
      Uri.parse('$_base/progress/reports/$assessmentId/simplified'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('getMySimplifiedReport failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getTemplate(String templateId) async {
    const tag = 'API-getTemplate';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/admin/templates/$templateId');
    final r = await http.get(
      Uri.parse('$_base/admin/templates/$templateId'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('getTemplate failed (${r.statusCode})');
  }

  Future<void> addQuestionToTemplate(String templateId, String questionId, int order) async {
    const tag = 'API-addQuestionToTemplate';
  await _ensureFreshToken();
    final payload = {'question_id': questionId, 'order': order};
    _logReq(tag, 'POST', '/admin/templates/$templateId/questions', payload);
    final r = await http.post(
      Uri.parse('$_base/admin/templates/$templateId/questions'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    _logRes(tag, r);
    if (r.statusCode != 200) {
      throw Exception('addQuestionToTemplate failed (${r.statusCode})');
    }
  }

  Future<void> removeQuestionFromTemplate(String templateId, String questionId) async {
    const tag = 'API-removeQuestionFromTemplate';
  await _ensureFreshToken();
    _logReq(tag, 'DELETE', '/admin/templates/$templateId/questions/$questionId');
    final r = await http.delete(
      Uri.parse('$_base/admin/templates/$templateId/questions/$questionId'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode != 200) {
      throw Exception('removeQuestionFromTemplate failed (${r.statusCode})');
    }
  }

  Future<Map<String, dynamic>> cloneTemplate(String templateId) async {
    const tag = 'API-cloneTemplate';
  await _ensureFreshToken();
    _logReq(tag, 'POST', '/admin/templates/$templateId/clone');
    final r = await http.post(
      Uri.parse('$_base/admin/templates/$templateId/clone'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('cloneTemplate failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> publishTemplate(String templateId) async {
    const tag = 'API-publishTemplate';
  await _ensureFreshToken();
    _logReq(tag, 'POST', '/admin/templates/$templateId/publish');
    final r = await http.post(
      Uri.parse('$_base/admin/templates/$templateId/publish'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('publishTemplate failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> unpublishTemplate(String templateId) async {
    const tag = 'API-unpublishTemplate';
  await _ensureFreshToken();
    _logReq(tag, 'POST', '/admin/templates/$templateId/unpublish');
    final r = await http.post(
      Uri.parse('$_base/admin/templates/$templateId/unpublish'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('unpublishTemplate failed (${r.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  ⭐  Master T[root]H (self)                                         */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> getMasterTroothLatest() async {
    const tag = 'API-masterLatest';
    await _ensureFreshToken();
    const path = '/assessments/master-trooth/latest';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {};
    throw Exception('getMasterTroothLatest failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> getMasterTroothHistory({String? cursor, int? limit}) async {
    const tag = 'API-masterHistory';
    await _ensureFreshToken();
    final qp = <String, String>{};
    if (cursor != null) qp['cursor'] = cursor;
    if (limit != null) qp['limit'] = limit.toString();
    const base = '/assessments/master-trooth/history';
    final uri = Uri.parse('$_base$base').replace(queryParameters: qp.isEmpty ? null : qp);
    _logReq(tag, 'GET', uri.path + (uri.query.isNotEmpty ? '?'+uri.query : ''));
    final r = await http.get(uri, headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {'items': [], 'next_cursor': null};
    throw Exception('getMasterTroothHistory failed (${r.statusCode}) ${r.body}');
  }

  Future<bool> emailMyMasterTroothReport({String? assessmentId, String? toEmail, bool includePdf = true, bool includeHtml = false}) async {
    const tag = 'API-masterEmailReport';
    await _ensureFreshToken();
    const path = '/assessments/master-trooth/email-report';
    final payload = <String, dynamic>{
      if (assessmentId != null) 'assessment_id': assessmentId,
      'to_email': toEmail ?? FirebaseAuth.instance.currentUser?.email ?? '',
      'include_pdf': includePdf,
      'include_html': includeHtml,
    };
    _logReq(tag, 'POST', path, payload);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    _logRes(tag, r);
    if (r.statusCode == 200) return true;
    if (r.statusCode == 429) throw Exception('RATE_LIMIT: ${r.body}');
    if (r.statusCode == 404) throw Exception('Submission not found');
    throw Exception('emailMyMasterTroothReport failed (${r.statusCode}) ${r.body}');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  📦  Generic Assessments (self)                                     */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> getGenericLatest(String templateId) async {
    const tag = 'API-genericLatest';
    await _ensureFreshToken();
    final path = '/templates/$templateId/latest';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {};
    throw Exception('getGenericLatest failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> getGenericHistory(String templateId, {String? cursor, int? limit}) async {
    const tag = 'API-genericHistory';
    await _ensureFreshToken();
    final qp = <String, String>{};
    if (cursor != null) qp['cursor'] = cursor;
    if (limit != null) qp['limit'] = limit.toString();
    final base = '/templates/$templateId/history';
    final uri = Uri.parse('$_base$base').replace(queryParameters: qp.isEmpty ? null : qp);
    _logReq(tag, 'GET', uri.path + (uri.query.isNotEmpty ? '?'+uri.query : ''));
    final r = await http.get(uri, headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {'items': [], 'next_cursor': null};
    throw Exception('getGenericHistory failed (${r.statusCode}) ${r.body}');
  }

  Future<bool> emailMyGenericReport(String templateId, {String? assessmentId, String? toEmail, bool includePdf = true, bool includeHtml = false}) async {
    const tag = 'API-genericEmailReport';
    await _ensureFreshToken();
    final path = '/templates/$templateId/email-report';
    final payload = <String, dynamic>{
      if (assessmentId != null) 'assessment_id': assessmentId,
      'to_email': toEmail ?? FirebaseAuth.instance.currentUser?.email ?? '',
      'include_pdf': includePdf,
      'include_html': includeHtml,
    };
    _logReq(tag, 'POST', path, payload);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    _logRes(tag, r);
    if (r.statusCode == 200) return true;
    if (r.statusCode == 429) throw Exception('RATE_LIMIT: ${r.body}');
    if (r.statusCode == 404) throw Exception('Submission not found');
    throw Exception('emailMyGenericReport failed (${r.statusCode}) ${r.body}');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  🧑‍🏫  Mentor endpoints for assessments                              */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> mentorGetMasterTroothLatest(String apprenticeId) async {
    const tag = 'API-mentorMasterLatest';
    await _ensureFreshToken();
    final path = '/assessments/master-trooth/$apprenticeId/latest';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {};
    throw Exception('mentorGetMasterTroothLatest failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> mentorGetMasterTroothHistory(String apprenticeId, {String? cursor, int? limit}) async {
    const tag = 'API-mentorMasterHistory';
    await _ensureFreshToken();
    final qp = <String,String>{};
    if (cursor != null) qp['cursor'] = cursor;
    if (limit != null) qp['limit'] = limit.toString();
    final base = '/assessments/master-trooth/$apprenticeId/history';
    final uri = Uri.parse('$_base$base').replace(queryParameters: qp.isEmpty ? null : qp);
    _logReq(tag, 'GET', uri.path + (uri.query.isNotEmpty ? '?'+uri.query : ''));
    final r = await http.get(uri, headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {'items': [], 'next_cursor': null};
    throw Exception('mentorGetMasterTroothHistory failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> mentorGetGenericLatest(String templateId, String apprenticeId) async {
    const tag = 'API-mentorGenericLatest';
    await _ensureFreshToken();
    final path = '/templates/$templateId/$apprenticeId/latest';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {};
    throw Exception('mentorGetGenericLatest failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> mentorGetGenericHistory(String templateId, String apprenticeId, {String? cursor, int? limit}) async {
    const tag = 'API-mentorGenericHistory';
    await _ensureFreshToken();
    final qp = <String,String>{};
    if (cursor != null) qp['cursor'] = cursor;
    if (limit != null) qp['limit'] = limit.toString();
    final base = '/templates/$templateId/$apprenticeId/history';
    final uri = Uri.parse('$_base$base').replace(queryParameters: qp.isEmpty ? null : qp);
    _logReq(tag, 'GET', uri.path + (uri.query.isNotEmpty ? '?'+uri.query : ''));
    final r = await http.get(uri, headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {'items': [], 'next_cursor': null};
    throw Exception('mentorGetGenericHistory failed (${r.statusCode}) ${r.body}');
  }

  Future<bool> mentorEmailGenericReport(String templateId, String apprenticeId, {String? assessmentId, bool includePdf = true, bool includeHtml = false}) async {
    const tag = 'API-mentorGenericEmail';
    await _ensureFreshToken();
    final path = '/templates/$templateId/$apprenticeId/email-report';
    final payload = <String, dynamic>{
      if (assessmentId != null) 'assessment_id': assessmentId,
      'include_pdf': includePdf,
      'include_html': includeHtml,
    };
    _logReq(tag, 'POST', path, payload);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    _logRes(tag, r);
    if (r.statusCode == 200) return true;
    if (r.statusCode == 429) throw Exception('RATE_LIMIT: ${r.body}');
    if (r.statusCode == 404) throw Exception('Submission not found');
    throw Exception('mentorEmailGenericReport failed (${r.statusCode}) ${r.body}');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  📋  Questions                                                       */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> createQuestion(Map<String, dynamic> payload) async {
    const tag = 'API-createQuestion';
    try {
  await _ensureFreshToken();
      print('🔍 $tag Starting request...');
      print('🔍 Payload: $payload');
      
      _logReq(tag, 'POST', '/question/questions', payload);
      
      final uri = Uri.parse('$_base/question/questions');
      final headers = _headers();
      final body = jsonEncode(payload);
      
      final r = await http.post(uri, headers: headers, body: body);
      
      print('🔍 Response received');
      _logRes(tag, r);
      if (r.statusCode == 200) return jsonDecode(r.body);
      throw Exception('createQuestion failed (${r.statusCode})');
    } catch (e) {
      print('❌ $tag Network Error Details: $e');
      throw Exception('createQuestion network error: $e');
    }
  }

  Future<Map<String, dynamic>> updateQuestion(String questionId, Map<String, dynamic> payload) async {
    const tag = 'API-updateQuestion';
    try {
  await _ensureFreshToken();
      print('🔍 $tag Starting request...');
      print('🔍 Question ID: $questionId');
      print('🔍 Payload: $payload');
      
      _logReq(tag, 'PUT', '/question/questions/$questionId', payload);
      
      final uri = Uri.parse('$_base/question/questions/$questionId');
      final headers = _headers();
      final body = jsonEncode(payload);
      
      final r = await http.put(uri, headers: headers, body: body);
      
      print('🔍 Response received');
      _logRes(tag, r);
      if (r.statusCode == 200) return jsonDecode(r.body);
      throw Exception('updateQuestion failed (${r.statusCode})');
    } catch (e) {
      print('❌ $tag Network Error Details: $e');
      throw Exception('updateQuestion network error: $e');
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    const tag = 'API-deleteQuestion';
    try {
  await _ensureFreshToken();
      print('🔍 $tag Starting request...');
      print('🔍 Question ID: $questionId');
      
      _logReq(tag, 'DELETE', '/question/questions/$questionId');
      
      final uri = Uri.parse('$_base/question/questions/$questionId');
      final headers = _headers();
      
      final r = await http.delete(uri, headers: headers);
      
      print('🔍 Response received');
      _logRes(tag, r);
      if (r.statusCode == 200) return;
      throw Exception('deleteQuestion failed (${r.statusCode})');
    } catch (e) {
      print('❌ $tag Network Error Details: $e');
      throw Exception('deleteQuestion network error: $e');
    }
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  ✉️  Invites                                                        */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<void> sendInvite(Map<String, dynamic> payload) async {
    const tag = 'API-sendInvite';
  await _ensureFreshToken();
    _logReq(tag, 'POST', '/invitations/invite-apprentice', payload);
    final r = await http.post(
      Uri.parse('$_base/invitations/invite-apprentice'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    _logRes(tag, r);
    if (r.statusCode != 200) {
      throw Exception('sendInvite failed (${r.statusCode})');
    }
  }

  Future<List<dynamic>> getPendingInvites() async {
    const tag = 'API-getPendingInvites';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/invitations/pending-invites');
    final r = await http.get(
      Uri.parse('$_base/invitations/pending-invites'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('getPendingInvites failed (${r.statusCode})');
  }

  Future<void> revokeInvite(String invitationId) async {
    const tag = 'API-revokeInvite';
  await _ensureFreshToken();
    _logReq(tag, 'DELETE', '/invitations/revoke-invite/$invitationId');
    final r = await http.delete(
      Uri.parse('$_base/invitations/revoke-invite/$invitationId'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode != 200) {
      throw Exception('revokeInvite failed (${r.statusCode})');
    }
  }

  Future<Map<String, dynamic>> validateInviteToken(String token) async {
    const tag = 'API-validateInviteToken';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/invitations/validate-token/$token');
    final r = await http.get(
      Uri.parse('$_base/invitations/validate-token/$token'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('validateInviteToken failed (${r.statusCode})');
  }

  Future<void> acceptInvite(Map<String, dynamic> payload) async {
    const tag = 'API-acceptInvite';
  await _ensureFreshToken();
    _logReq(tag, 'POST', '/invitations/accept-invite', payload);
    final r = await http.post(
      Uri.parse('$_base/invitations/accept-invite'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    _logRes(tag, r);
    if (r.statusCode != 200) {
      throw Exception('acceptInvite failed (${r.statusCode})');
    }
  }

  Future<List<dynamic>> getApprenticeInvites(String email) async {
    const tag = 'API-getApprenticeInvites';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/invitations/apprentice-invites?email=$email');
    final r = await http.get(
      Uri.parse('$_base/invitations/apprentice-invites?email=$email'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('getApprenticeInvites failed (${r.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  🏷️  Categories                                                     */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<List<Map<String, dynamic>>> getCategories() async {
    const tag = 'API-getCategories';
  await _ensureFreshToken();
    _logReq(tag, 'GET', '/categories/');
    final r = await http.get(
      Uri.parse('$_base/categories/'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(r.body));
    throw Exception('getCategories failed (${r.statusCode}): ${r.body}');
  }

  Future<Map<String, dynamic>> createCategory(String name) async {
    const tag = 'API-createCategory';
  await _ensureFreshToken();
    final body = {'name': name};
    _logReq(tag, 'POST', '/categories/', body);
    final r = await http.post(
      Uri.parse('$_base/categories/'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('createCategory failed (${r.statusCode}): ${r.body}');
  }

  Future<void> deleteCategory(String categoryId) async {
    const tag = 'API-deleteCategory';
  await _ensureFreshToken();
    _logReq(tag, 'DELETE', '/categories/$categoryId');
    final r = await http.delete(
      Uri.parse('$_base/categories/$categoryId'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode != 200) throw Exception('deleteCategory failed (${r.statusCode}): ${r.body}');
  }

  // ───────────────────────────────────────────────────────────────────
  //  🤝 Agreements
  // ───────────────────────────────────────────────────────────────────

  Future<List<dynamic>> listAgreementTemplates() async {
    const tag = 'API-agreementTemplates';
    await _ensureFreshToken();
    _logReq(tag, 'GET', '/agreements/templates');
    final r = await http.get(Uri.parse('$_base/agreements/templates'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('listAgreementTemplates failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> createAgreement({
    required int templateVersion,
    required String apprenticeEmail,
    String? apprenticeName,
    required Map<String, dynamic> fields,
    bool apprenticeIsMinor = false,
    bool parentRequired = false,
    String? parentEmail,
  }) async {
    const tag = 'API-createAgreement';
    await _ensureFreshToken();
    final payload = {
      'template_version': templateVersion,
      'apprentice_email': apprenticeEmail,
      if (apprenticeName != null && apprenticeName.trim().isNotEmpty) 'apprentice_name': apprenticeName.trim(),
      'apprentice_is_minor': apprenticeIsMinor,
      'parent_required': parentRequired,
      if (parentEmail != null) 'parent_email': parentEmail,
      'fields': fields,
    };
    _logReq(tag, 'POST', '/agreements', payload);
    final r = await http.post(Uri.parse('$_base/agreements'), headers: _headers(), body: jsonEncode(payload));
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('createAgreement failed (${r.statusCode})');
  }

  Future<List<dynamic>> listAgreements({int skip = 0, int limit = 50}) async {
    const tag = 'API-listAgreements';
    await _ensureFreshToken();
    final uri = Uri.parse('$_base/agreements?skip=$skip&limit=$limit');
    _logReq(tag, 'GET', uri.path);
    final r = await http.get(uri, headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('listAgreements failed (${r.statusCode})');
  }

  Future<List<dynamic>> listMyAgreements({int skip = 0, int limit = 50}) async {
    const tag = 'API-listMyAgreements';
    await _ensureFreshToken();
    final uri = Uri.parse('$_base/agreements/my?skip=$skip&limit=$limit');
    _logReq(tag, 'GET', uri.path);
    final r = await http.get(uri, headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('listMyAgreements failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> submitAgreement(String agreementId) async {
    const tag = 'API-submitAgreement';
    await _ensureFreshToken();
    final path = '/agreements/$agreementId/submit';
    _logReq(tag, 'POST', path);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('submitAgreement failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getAgreement(String agreementId) async {
    const tag = 'API-getAgreement';
    await _ensureFreshToken();
    final path = '/agreements/$agreementId';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('getAgreement failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> apprenticeSignAgreement({
    required String agreementId,
    required String typedName,
  }) async {
    const tag = 'API-apprenticeSign';
    await _ensureFreshToken();
    final path = '/agreements/$agreementId/sign/apprentice';
    final payload = { 'typed_name': typedName };
    _logReq(tag, 'POST', path, payload);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('apprenticeSignAgreement failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> parentSignAgreement({
    required String agreementId,
    required String typedName,
  }) async {
    const tag = 'API-parentSign';
    await _ensureFreshToken();
    final path = '/agreements/$agreementId/sign/parent';
    final payload = { 'typed_name': typedName };
    _logReq(tag, 'POST', path, payload);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('parentSignAgreement failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> resendParentToken({
    required String agreementId,
    String? reason,
  }) async {
    const tag = 'API-resendParentToken';
    await _ensureFreshToken();
    final path = '/agreements/$agreementId/resend/parent-token';
    final payload = { if (reason != null) 'reason': reason };
    _logReq(tag, 'POST', path, payload.isEmpty ? null : payload);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    if (r.statusCode == 429) {
      final remaining = r.headers['x-rate-limit-remaining'];
      final reset = r.headers['x-rate-limit-reset'];
      throw Exception('Rate limit: too many resends.${remaining != null ? ' Remaining: $remaining' : ''}${reset != null ? ' Reset: $reset' : ''}');
    }
    throw Exception('resendParentToken failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> revokeAgreement(String agreementId) async {
    const tag = 'API-revokeAgreement';
    await _ensureFreshToken();
    final path = '/agreements/$agreementId/revoke';
    _logReq(tag, 'POST', path);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('revokeAgreement failed (${r.statusCode})');
  }

    Future<Map<String, dynamic>> updateAgreementFields(String agreementId, Map<String, dynamic> partialFields) async {
      const tag = 'API-updateAgreementFields';
      await _ensureFreshToken();
      final path = '/agreements/$agreementId/fields';
      _logReq(tag, 'PATCH', path, partialFields);
      final r = await http.patch(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(partialFields));
      _logRes(tag, r);
      if (r.statusCode == 200) return jsonDecode(r.body);
      throw Exception('updateAgreementFields failed (${r.statusCode})');
    }
  
  /// Apprentice requests mentor to resend parent link (no token generation here)
  Future<Map<String, dynamic>> requestParentResendRequest(String agreementId, {String? reason}) async {
    const tag = 'API-requestParentResendRequest';
    await _ensureFreshToken();
    final path = '/agreements/$agreementId/request-resend-parent';
    final payload = <String, dynamic>{ if (reason != null && reason.isNotEmpty) 'reason': reason };
    _logReq(tag, 'POST', path, payload.isEmpty ? null : payload);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    if (r.statusCode == 409) throw Exception('Not awaiting parent signature');
    if (r.statusCode == 429) throw Exception('Too many requests; try later');
    throw Exception('requestParentResendRequest failed (${r.statusCode})');
  }
  Future<Map<String, dynamic>> terminateApprenticeship(String apprenticeId, String reason) async {
    const tag = 'API-terminateApprenticeship';
    await _ensureFreshToken();
    final path = '/mentor/apprentice/$apprenticeId/terminate';
    // Debug instrumentation
    // (Will print once per attempt; safe for temporary troubleshooting.)
    // Shows token presence but not the token value.
    print('[terminateApprenticeship] path=$path reasonLen=${reason.length} tokenSet=${bearerToken != null}');
    _logReq(tag, 'POST', path, { 'reason': reason });
    http.Response r;
    try {
      r = await http.post(
        Uri.parse('$_base$path'),
        headers: _headers(),
        body: jsonEncode({ 'reason': reason }),
      );
    } catch (e) {
      print('[terminateApprenticeship][network_error] $e');
      rethrow;
    }
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    print('[terminateApprenticeship][failure] code=${r.statusCode} body=${r.body}');
    throw Exception('terminateApprenticeship failed (${r.statusCode}) ${r.body}');
  }

  /// Apprentice meeting reschedule request (emails mentor)
  Future<Map<String, dynamic>> requestMeetingReschedule(String agreementId, {String? reason, List<String>? proposals}) async {
    const tag = 'API-requestMeetingReschedule';
    await _ensureFreshToken();
    final path = '/agreements/$agreementId/request-reschedule';
    final payload = <String, dynamic>{
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (proposals != null && proposals.isNotEmpty) 'proposals': proposals,
    };
    // Add a lightweight correlation id to trace in server logs.
    final correlationId = 'resched-${DateTime.now().millisecondsSinceEpoch}-${(1000 + (DateTime.now().microsecondsSinceEpoch % 8999))}';
    final headers = _headers();
    headers['x-correlation-id'] = correlationId;
    _logReq(tag, 'POST', path, payload.isEmpty ? null : payload);
    http.Response r;
    try {
      r = await http.post(Uri.parse('$_base$path'), headers: headers, body: jsonEncode(payload));
    } catch (e) {
      // Network / transport error – expose correlation id for cross-reference
      throw Exception('requestMeetingReschedule network error correlation=$correlationId err=$e');
    }
    _logRes(tag, r);
    if (r.statusCode == 200) {
      try {
        return jsonDecode(r.body) as Map<String,dynamic>;
      } catch (e) {
        throw Exception('requestMeetingReschedule parse error status=200 correlation=$correlationId bodyPreview=${r.body.substring(0, r.body.length > 180 ? 180 : r.body.length)} err=$e');
      }
    }
    if (r.statusCode == 409) {
      throw Exception('Agreement inactive (409) correlation=$correlationId');
    }
    // Provide status + compact body snippet for faster debugging.
    final snippet = r.body.isEmpty ? '<empty>' : r.body.substring(0, r.body.length > 300 ? 300 : r.body.length);
    throw Exception('requestMeetingReschedule failed status=${r.statusCode} correlation=$correlationId body=$snippet');
  }

  Future<Map<String, dynamic>> reinstateApprenticeship(String apprenticeId, {String? reason}) async {
    const tag = 'API-reinstateApprenticeship';
    await _ensureFreshToken();
    final path = '/mentor/apprentice/$apprenticeId/reinstate';
    final payload = reason == null ? null : { 'reason': reason };
    _logReq(tag, 'POST', path, payload);
    final r = await http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: payload == null ? null : jsonEncode(payload),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('reinstateApprenticeship failed (${r.statusCode}) ${r.body}');
  }

  // ───────────────────────────────────────────────────────────────────
  //  🔔 Notifications (Mentor)
  // ───────────────────────────────────────────────────────────────────
  Future<List<dynamic>> mentorNotifications() async {
    const tag = 'API-mentorNotifications';
    await _ensureFreshToken();
    final path = '/mentor/notifications';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('mentorNotifications failed (${r.statusCode}): ${r.body}');
  }

  Future<List<dynamic>> mentorNotificationsHistory() async {
    const tag = 'API-mentorNotificationsHistory';
    await _ensureFreshToken();
    final path = '/mentor/notifications/history';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    if (r.statusCode == 404) {
      // Deployed backend likely not updated yet with history endpoint.
      // Fail soft: treat as empty history so UI still works.
      dev.log('$tag endpoint missing on server (404). Returning empty list fallback.');
      return const [];
    }
    throw Exception('mentorNotificationsHistory failed (${r.statusCode}): ${r.body}');
  }

  Future<Map<String, dynamic>> dismissNotification(String notificationId) async {
    const tag = 'API-dismissNotification';
    await _ensureFreshToken();
    final path = '/mentor/notifications/$notificationId/dismiss';
    _logReq(tag, 'POST', path);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) {
      // Distinguish between endpoint missing vs domain notification not found.
      // Server-side function returns detail "Notification not found" when route exists.
      // Generic {"detail":"Not Found"} means path missing in deployed build.
      try {
        final body = jsonDecode(r.body);
        if (body is Map && body['detail'] == 'Not Found') {
          dev.log('$tag endpoint missing (404). Simulating client-side dismiss.');
          // Simulate successful dismissal so UI removes the item.
          return {'id': notificationId, 'is_read': true};
        }
      } catch (_) {}
    }
    throw Exception('dismissNotification failed (${r.statusCode}): ${r.body}');
  }

  Future<int> dismissAllNotifications() async {
    const tag = 'API-dismissAllNotifications';
    await _ensureFreshToken();
    const path = '/mentor/notifications/dismiss-all';
    _logReq(tag, 'POST', path);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      return (body['dismissed'] ?? 0) as int;
    }
    throw Exception('dismissAllNotifications failed (${r.statusCode}): ${r.body}');
  }

  // Mentor respond to a reschedule request
  Future<Map<String, dynamic>> respondReschedule(String agreementId, {
    required String decision, // accepted | declined | proposed
    String? selectedTime,
    String? note,
  }) async {
    const tag = 'API-respondReschedule';
    await _ensureFreshToken();
    final path = '/agreements/$agreementId/reschedule/respond';
    final payload = <String, dynamic>{
      'decision': decision,
      if (selectedTime != null && selectedTime.isNotEmpty) 'selected_time': selectedTime,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    _logReq(tag, 'POST', path, payload);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('respondReschedule failed (${r.statusCode}): ${r.body}');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  🌟  Spiritual Gifts Assessment                                    */
  /* ─────────────────────────────────────────────────────────────────── */

  static const String _spiritualGiftsTemplateKey = 'spiritual_gifts_v1';

  Future<Map<String, dynamic>> getSpiritualGiftsQuestions() async {
    const tag = 'API-getSpiritualGiftsQuestions';
    await _ensureFreshToken();
    const path = '/assessments/spiritual-gifts/questions';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('getSpiritualGiftsQuestions failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> submitSpiritualGifts(Map<String, int> answers) async {
    const tag = 'API-submitSpiritualGifts';
    await _ensureFreshToken();
    // Backend router prefix is /assessments/spiritual-gifts
    const path = '/assessments/spiritual-gifts/submit';
    final payload = { 'template_key': _spiritualGiftsTemplateKey, 'answers': answers };
    _logReq(tag, 'POST', path, payload);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('submitSpiritualGifts failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> getSpiritualGiftsLatest() async {
    const tag = 'API-getSpiritualGiftsLatest';
    await _ensureFreshToken();
    const path = '/assessments/spiritual-gifts/latest';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return _normalizeSpiritualGiftsResult(data);
    }
    if (r.statusCode == 404) return {}; // no submission yet
    throw Exception('getSpiritualGiftsLatest failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> mentorGetApprenticeSpiritualGiftsLatest(String apprenticeId) async {
    const tag = 'API-mentorGetApprenticeSpiritualGiftsLatest';
    await _ensureFreshToken();
    final path = '/assessments/spiritual-gifts/$apprenticeId/latest';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return _normalizeSpiritualGiftsResult(data);
    }
    if (r.statusCode == 404) return {}; // none yet
    throw Exception('mentorGetApprenticeSpiritualGiftsLatest failed (${r.statusCode}) ${r.body}');
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
    const tag = 'API-mentorGetApprenticeSpiritualGiftsHistory';
    await _ensureFreshToken();
    final qp = <String,String>{};
    if (cursor != null) qp['cursor'] = cursor;
    if (limit != null) qp['limit'] = limit.toString();
    final base = '/assessments/spiritual-gifts/$apprenticeId/history';
    final uri = Uri.parse('$_base$base').replace(queryParameters: qp.isEmpty ? null : qp);
    _logReq(tag, 'GET', uri.path + (uri.query.isNotEmpty ? '?'+uri.query : ''));
    final r = await http.get(uri, headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('mentorGetApprenticeSpiritualGiftsHistory failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> getSpiritualGiftsHistory({String? cursor, int? limit}) async {
    const tag = 'API-getSpiritualGiftsHistory';
    await _ensureFreshToken();
    final qp = <String,String>{};
    if (cursor != null) qp['cursor'] = cursor;
    if (limit != null) qp['limit'] = limit.toString();
    const base = '/assessments/spiritual-gifts/history';
    final uri = Uri.parse('$_base$base').replace(queryParameters: qp.isEmpty ? null : qp);
    _logReq(tag, 'GET', uri.path + (uri.query.isNotEmpty ? '?'+uri.query : ''));
    final r = await http.get(uri, headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {'items': [], 'next_cursor': null};
    throw Exception('getSpiritualGiftsHistory failed (${r.statusCode}) ${r.body}');
  }

  Future<bool> emailMySpiritualGiftsReport() async {
    const tag = 'API-emailMySpiritualGiftsReport';
    await _ensureFreshToken();
    const path = '/assessments/spiritual-gifts/email-report';
    // Backend expects a JSON body: { to_email, optional assessment_id, include_pdf, include_html }
  final email = FirebaseAuth.instance.currentUser?.email; // may be null; still attempt
    final payload = {
      'to_email': email ?? '',
      'include_pdf': true,
      'include_html': false,
    };
    _logReq(tag, 'POST', path, payload);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    _logRes(tag, r);
    if (r.statusCode == 200) return true;
    if (r.statusCode == 429) {
      throw Exception('RATE_LIMIT: ${r.body}');
    }
    throw Exception('emailMySpiritualGiftsReport failed (${r.statusCode}) ${r.body}');
  }

  Future<bool> emailMySpiritualGiftsReportForSubmission(String submissionId) async {
    const tag = 'API-emailMySpiritualGiftsReportForSubmission';
    await _ensureFreshToken();
    const path = '/assessments/spiritual-gifts/email-report';
    final payload = {
      'assessment_id': submissionId,
  'to_email': FirebaseAuth.instance.currentUser?.email ?? '',
      'include_pdf': true,
      'include_html': false,
    };
    _logReq(tag, 'POST', path, payload);
    final r = await http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    _logRes(tag, r);
    if (r.statusCode == 200) return true;
    if (r.statusCode == 404) {
      throw Exception('Submission not found');
    }
    if (r.statusCode == 429) {
      throw Exception('RATE_LIMIT: ${r.body}');
    }
    throw Exception('emailMySpiritualGiftsReportForSubmission failed (${r.statusCode}) ${r.body}');
  }

  Future<bool> mentorEmailSpiritualGiftsReport(String apprenticeId, {String? toEmail}) async {
    const tag = 'API-mentorEmailSpiritualGiftsReport';
    await _ensureFreshToken();
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
    _logReq(tag, 'POST', path, body);
    final r = await http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return true;
    if (r.statusCode == 429) {
      throw Exception('RATE_LIMIT: ${r.body}');
    }
    throw Exception('mentorEmailSpiritualGiftsReport failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> getSpiritualGiftsTemplateMetadata() async {
    const tag = 'API-getSpiritualGiftsTemplateMetadata';
    await _ensureFreshToken();
    const path = '/spiritual-gifts/template/metadata';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw Exception('getSpiritualGiftsTemplateMetadata failed (${r.statusCode}) ${r.body}');
  }

  Future<List<Map<String, dynamic>>> getSpiritualGiftsDefinitions() async {
    const tag = 'API-getSpiritualGiftsDefinitions';
    await _ensureFreshToken();
    const path = '/spiritual-gifts/definitions';
    _logReq(tag, 'GET', path);
    final r = await http.get(Uri.parse('$_base$path'), headers: _headers());
    _logRes(tag, r);
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
    throw Exception('getSpiritualGiftsDefinitions failed (${r.statusCode}) ${r.body}');
  }
}