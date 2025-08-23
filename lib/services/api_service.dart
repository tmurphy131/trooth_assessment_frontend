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
const String _devBaseUrl = 'http://192.168.1.161:8000';

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

  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
      if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
    };
    
    // Debug headers
    if (bearerToken != null) {
      print('🔑 API Headers with token: ${bearerToken?.substring(0, 20)}...');
      print('🔑 Full token length: ${bearerToken?.length}');
    } else {
      print('⚠️ API Headers without token');
    }
    
    return headers;
  }

  // Helper method to refresh token before API calls
  Future<void> _ensureFreshToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        final token = await user.getIdToken(true); // Force refresh
        bearerToken = token;
        if (token != null && token.isNotEmpty) {
          print('🔄 Refreshed token: ${token.substring(0, 20)}...');
        }
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
    required String uid,
    required String email,
    required String role, // mentor | apprentice
    String? displayName,
  }) async {
    const tag = 'API-createUser';
    final payload = {
      'id': uid,
      'email': email,
      'role': role,
      if (displayName != null) 'display_name': displayName,
    };

    _logReq(tag, 'POST', '/users', payload);
    final r = await http.post(
      Uri.parse('$_base/users'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    _logRes(tag, r);
    if (r.statusCode != 200) {
      throw Exception('createUser failed (${r.statusCode})');
    }
  }

  Future<void> assignApprentice({
    required String mentorId,
    required String apprenticeId,
  }) async {
    const tag = 'API-assignApprentice';
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
    _logReq(tag, 'GET', '/users/$uid');
    final r = await http.get(
      Uri.parse('$_base/users/$uid'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('getUserProfile failed (${r.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  📊  Assessments                                                    */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> createAssessment(
      Map<String, dynamic> payload) async {
    const tag = 'API-createAsmt';
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
    _logReq(tag, 'GET', '/mentor/my-apprentices');
    final r = await http.get(
      Uri.parse('$_base/mentor/my-apprentices'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw Exception('listApprentices failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getApprenticeDraft(String apprenticeId) async {
    const tag = 'API-getApprenticeDraft';
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

  Future<Map<String, dynamic>> getAssessmentDetail(String assessmentId) async {
    const tag = 'API-getAssessmentDetail';
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
    _logReq(tag, 'GET', '/assessments/$assessmentId');
    final r = await http.get(
      Uri.parse('$_base/assessments/$assessmentId'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('getAssessmentResults failed (${r.statusCode})');
  }

  Future<List<dynamic>> getSubmittedDrafts({
    String? apprenticeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    const tag = 'API-getSubmittedDrafts';
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

  Future<Map<String, dynamic>> submitDraft() async {
    const tag = 'API-submitDraft';
    await _ensureFreshToken();
    _logReq(tag, 'POST', '/assessment-drafts/submit');
    final r = await http.post(
      Uri.parse('$_base/assessment-drafts/submit'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw Exception('submitDraft failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> resumeDraft() async {
    const tag = 'API-resumeDraft';
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

  Future<Map<String, dynamic>> getTemplate(String templateId) async {
    const tag = 'API-getTemplate';
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
  /*  📋  Questions                                                       */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> createQuestion(Map<String, dynamic> payload) async {
    const tag = 'API-createQuestion';
    try {
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
    _logReq(tag, 'DELETE', '/categories/$categoryId');
    final r = await http.delete(
      Uri.parse('$_base/categories/$categoryId'),
      headers: _headers(),
    );
    _logRes(tag, r);
    if (r.statusCode != 200) throw Exception('deleteCategory failed (${r.statusCode}): ${r.body}');
  }
}
