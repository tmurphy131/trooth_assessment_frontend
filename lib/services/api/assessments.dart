part of '../api_service.dart';

// /    Assessment Drafts (for Apprentices)                            /, /    Templates                                                      /, /    Progress (Featured  Reports)                                  /, /    Master TrootH (self)                                         /, /    Generic Assessments (self)                                     /, /    Mentor endpoints for assessments                              /, /    Questions                                                       /
extension AssessmentsApi on ApiService {
  /* ─────────────────────────────────────────────────────────────────── */
  /*  📝  Assessment Drafts (for Apprentices)                            */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> startDraft(String templateId) async {
    final r = await _http.post(
      Uri.parse('$_base/assessment-drafts/start?template_id=$templateId'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'startDraft failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getDraft() async {
    final r = await _http.get(
      Uri.parse('$_base/assessment-drafts'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'getDraft failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> updateDraft(Map<String, dynamic> payload, {String? draftId}) async {
    
    // Use specific draft ID endpoint if provided, otherwise use the legacy endpoint
    final endpoint = draftId != null ? '/assessment-drafts/$draftId' : '/assessment-drafts';
    
    final r = await _http.patch(
      Uri.parse('$_base$endpoint'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'updateDraft failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> submitDraft({String? draftId, String? templateId}) async {
    String path = '/assessment-drafts/submit';
    final qp = <String, String>{};
    if (draftId != null && draftId.isNotEmpty) qp['draft_id'] = draftId;
    if (templateId != null && templateId.isNotEmpty) qp['template_id'] = templateId;
    if (qp.isNotEmpty) {
      final query = qp.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');
      path = '$path?$query';
    }
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'submitDraft failed (${r.statusCode})');
  }

  Future<List<dynamic>> getMentorOwnAssessments() async {
    const path = '/assessments/self';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'getMentorOwnAssessments failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> getAssessmentStatus(String assessmentId) async {
    final path = '/assessments/$assessmentId/status';
    final r = await _http.get(
      Uri.parse('$_base$path'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'getAssessmentStatus failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> resumeDraft() async {
    final r = await _http.get(
      Uri.parse('$_base/assessment-drafts/resume'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'resumeDraft failed (${r.statusCode})');
  }

  Future<List<dynamic>> getSubmittedAssessments(String apprenticeId) async {
    final r = await _http.get(
      Uri.parse('$_base/assessment-drafts/submitted-assessments/$apprenticeId'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'getSubmittedAssessments failed (${r.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  📋  Templates                                                      */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<List<dynamic>> getPublishedTemplates() async {
    final body = await _cachedBody('/templates/published', const Duration(minutes: 5), () async {
      final r = await _http.get(
        Uri.parse('$_base/templates/published'),
        headers: _headers(),
      );
      if (r.statusCode == 200) return r.body;
      throw ApiException(r.statusCode, 'getPublishedTemplates failed (${r.statusCode})');
    });
    return jsonDecode(body) as List<dynamic>;
  }

  // Admin Template Management
  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> payload) async {
    const tag = 'API-createTemplate';
    try {
      
      
      final uri = Uri.parse('$_base/admin/templates');
      final headers = _headers();
      final body = jsonEncode(payload);
      
      
      final r = await _http.post(uri, headers: headers, body: body);
      
      if (r.statusCode == 200) return jsonDecode(r.body);
      throw ApiException(r.statusCode, 'createTemplate failed (${r.statusCode})');
    } catch (e) {
      print('❌ $tag Network Error Details: $e');
      if (e.toString().contains('Failed to fetch')) {
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateTemplate(String templateId, Map<String, dynamic> payload) async {
    const tag = 'API-updateTemplate';
    try {
      
      
      final uri = Uri.parse('$_base/admin/templates/$templateId');
      final headers = _headers();
      final body = jsonEncode(payload);
      
      
      final r = await _http.put(uri, headers: headers, body: body);
      
      if (r.statusCode == 200) return jsonDecode(r.body);
      throw ApiException(r.statusCode, 'updateTemplate failed (${r.statusCode})');
    } catch (e) {
      print('❌ $tag Network Error Details: $e');
      rethrow;
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    const tag = 'API-deleteTemplate';
    try {
      
      
      final uri = Uri.parse('$_base/admin/templates/$templateId');
      final headers = _headers();
      
      
      final r = await _http.delete(uri, headers: headers);
      
      if (r.statusCode == 200) return;
      throw ApiException(r.statusCode, 'deleteTemplate failed (${r.statusCode})');
    } catch (e) {
      print('❌ $tag Network Error Details: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getAllTemplates() async {
    const tag = 'API-getAllTemplates';
    try {
      final r = await _http.get(
        Uri.parse('$_base/admin/templates'),
        headers: _headers(),
      );
      if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
      throw ApiException(r.statusCode, 'getAllTemplates failed (${r.statusCode})');
    } catch (e) {
      print('❌ $tag Network Error: $e');
      rethrow;
    }
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  📈  Progress (Featured + Reports)                                  */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> getProgressMasterLatest() async {
    const path = '/progress/master/latest';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return <String, dynamic>{}; // treat as empty state
    throw ApiException(r.statusCode, 'progressMasterLatest failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getProgressGiftsLatest() async {
    const path = '/progress/spiritual-gifts/latest';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return <String, dynamic>{};
    throw ApiException(r.statusCode, 'progressGiftsLatest failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getProgressReports({int limit = 20, String? cursor}) async {
    final qp = {
      'limit': limit.toString(),
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final uri = Uri.parse('$_base/progress/reports').replace(queryParameters: qp);
    final r = await _http.get(uri, headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'progressReports failed (${r.statusCode})');
  }

  /// Get simplified report for apprentice's own assessment
  Future<Map<String, dynamic>> getMySimplifiedReport(String assessmentId) async {
    final r = await _http.get(
      Uri.parse('$_base/progress/reports/$assessmentId/simplified'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'getMySimplifiedReport failed (${r.statusCode})');
  }

  /// Delete an assessment report (apprentice only)
  Future<void> deleteAssessmentReport(String assessmentId) async {
    final r = await _http.delete(
      Uri.parse('$_base/progress/reports/$assessmentId'),
      headers: _headers(),
    );
    if (r.statusCode == 204 || r.statusCode == 200) return;
    throw ApiException(r.statusCode, 'deleteAssessmentReport failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getTemplate(String templateId) async {
    final r = await _http.get(
      Uri.parse('$_base/admin/templates/$templateId'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'getTemplate failed (${r.statusCode})');
  }

  Future<void> addQuestionToTemplate(String templateId, String questionId, int order) async {
    final payload = {'question_id': questionId, 'order': order};
    final r = await _http.post(
      Uri.parse('$_base/admin/templates/$templateId/questions'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (r.statusCode != 200) {
      throw ApiException(r.statusCode, 'addQuestionToTemplate failed (${r.statusCode})');
    }
  }

  Future<void> removeQuestionFromTemplate(String templateId, String questionId) async {
    final r = await _http.delete(
      Uri.parse('$_base/admin/templates/$templateId/questions/$questionId'),
      headers: _headers(),
    );
    if (r.statusCode != 200) {
      throw ApiException(r.statusCode, 'removeQuestionFromTemplate failed (${r.statusCode})');
    }
  }

  Future<Map<String, dynamic>> cloneTemplate(String templateId) async {
    final r = await _http.post(
      Uri.parse('$_base/admin/templates/$templateId/clone'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'cloneTemplate failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> publishTemplate(String templateId) async {
    final r = await _http.post(
      Uri.parse('$_base/admin/templates/$templateId/publish'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'publishTemplate failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> unpublishTemplate(String templateId) async {
    final r = await _http.post(
      Uri.parse('$_base/admin/templates/$templateId/unpublish'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'unpublishTemplate failed (${r.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  ⭐  Master T[root]H (self)                                         */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> getMasterTroothLatest() async {
    const path = '/assessments/master-trooth/latest';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {};
    throw ApiException(r.statusCode, 'getMasterTroothLatest failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> getMasterTroothHistory({String? cursor, int? limit}) async {
    final qp = <String, String>{};
    if (cursor != null) qp['cursor'] = cursor;
    if (limit != null) qp['limit'] = limit.toString();
    const base = '/assessments/master-trooth/history';
    final uri = Uri.parse('$_base$base').replace(queryParameters: qp.isEmpty ? null : qp);
    final r = await _http.get(uri, headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {'items': [], 'next_cursor': null};
    throw ApiException(r.statusCode, 'getMasterTroothHistory failed (${r.statusCode}) ${r.body}');
  }

  Future<bool> emailMyMasterTroothReport({String? assessmentId, String? toEmail, bool includePdf = true, bool includeHtml = false}) async {
    const path = '/assessments/master-trooth/email-report';
    final payload = <String, dynamic>{
      if (assessmentId != null) 'assessment_id': assessmentId,
      'to_email': toEmail ?? FirebaseAuth.instance.currentUser?.email ?? '',
      'include_pdf': includePdf,
      'include_html': includeHtml,
    };
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return true;
    if (r.statusCode == 429) throw Exception('RATE_LIMIT: ${r.body}');
    if (r.statusCode == 404) throw Exception('Submission not found');
    throw ApiException(r.statusCode, 'emailMyMasterTroothReport failed (${r.statusCode}) ${r.body}');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  📦  Generic Assessments (self)                                     */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> getGenericLatest(String templateId) async {
    final path = '/templates/$templateId/latest';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {};
    throw ApiException(r.statusCode, 'getGenericLatest failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> getGenericHistory(String templateId, {String? cursor, int? limit}) async {
    final qp = <String, String>{};
    if (cursor != null) qp['cursor'] = cursor;
    if (limit != null) qp['limit'] = limit.toString();
    final base = '/templates/$templateId/history';
    final uri = Uri.parse('$_base$base').replace(queryParameters: qp.isEmpty ? null : qp);
    final r = await _http.get(uri, headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {'items': [], 'next_cursor': null};
    throw ApiException(r.statusCode, 'getGenericHistory failed (${r.statusCode}) ${r.body}');
  }

  Future<bool> emailMyGenericReport(String templateId, {String? assessmentId, String? toEmail, bool includePdf = true, bool includeHtml = false}) async {
    final path = '/templates/$templateId/email-report';
    final payload = <String, dynamic>{
      if (assessmentId != null) 'assessment_id': assessmentId,
      'to_email': toEmail ?? FirebaseAuth.instance.currentUser?.email ?? '',
      'include_pdf': includePdf,
      'include_html': includeHtml,
    };
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return true;
    if (r.statusCode == 429) throw Exception('RATE_LIMIT: ${r.body}');
    if (r.statusCode == 404) throw Exception('Submission not found');
    throw ApiException(r.statusCode, 'emailMyGenericReport failed (${r.statusCode}) ${r.body}');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  🧑‍🏫  Mentor endpoints for assessments                              */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> mentorGetMasterTroothLatest(String apprenticeId) async {
    final path = '/assessments/master-trooth/$apprenticeId/latest';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {};
    throw ApiException(r.statusCode, 'mentorGetMasterTroothLatest failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> mentorGetMasterTroothHistory(String apprenticeId, {String? cursor, int? limit}) async {
    final qp = <String,String>{};
    if (cursor != null) qp['cursor'] = cursor;
    if (limit != null) qp['limit'] = limit.toString();
    final base = '/assessments/master-trooth/$apprenticeId/history';
    final uri = Uri.parse('$_base$base').replace(queryParameters: qp.isEmpty ? null : qp);
    final r = await _http.get(uri, headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {'items': [], 'next_cursor': null};
    throw ApiException(r.statusCode, 'mentorGetMasterTroothHistory failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> mentorGetGenericLatest(String templateId, String apprenticeId) async {
    final path = '/templates/$templateId/$apprenticeId/latest';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {};
    throw ApiException(r.statusCode, 'mentorGetGenericLatest failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> mentorGetGenericHistory(String templateId, String apprenticeId, {String? cursor, int? limit}) async {
    final qp = <String,String>{};
    if (cursor != null) qp['cursor'] = cursor;
    if (limit != null) qp['limit'] = limit.toString();
    final base = '/templates/$templateId/$apprenticeId/history';
    final uri = Uri.parse('$_base$base').replace(queryParameters: qp.isEmpty ? null : qp);
    final r = await _http.get(uri, headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {'items': [], 'next_cursor': null};
    throw ApiException(r.statusCode, 'mentorGetGenericHistory failed (${r.statusCode}) ${r.body}');
  }

  Future<bool> mentorEmailGenericReport(String templateId, String apprenticeId, {String? assessmentId, bool includePdf = true, bool includeHtml = false}) async {
    final path = '/templates/$templateId/$apprenticeId/email-report';
    final payload = <String, dynamic>{
      if (assessmentId != null) 'assessment_id': assessmentId,
      'include_pdf': includePdf,
      'include_html': includeHtml,
    };
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return true;
    if (r.statusCode == 429) throw Exception('RATE_LIMIT: ${r.body}');
    if (r.statusCode == 404) throw Exception('Submission not found');
    throw ApiException(r.statusCode, 'mentorEmailGenericReport failed (${r.statusCode}) ${r.body}');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  📋  Questions                                                       */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> createQuestion(Map<String, dynamic> payload) async {
    const tag = 'API-createQuestion';
    try {
      
      
      final uri = Uri.parse('$_base/question/questions');
      final headers = _headers();
      final body = jsonEncode(payload);
      
      final r = await _http.post(uri, headers: headers, body: body);
      
      if (r.statusCode == 200) return jsonDecode(r.body);
      throw ApiException(r.statusCode, 'createQuestion failed (${r.statusCode})');
    } catch (e) {
      print('❌ $tag Network Error Details: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateQuestion(String questionId, Map<String, dynamic> payload) async {
    const tag = 'API-updateQuestion';
    try {
      
      
      final uri = Uri.parse('$_base/question/questions/$questionId');
      final headers = _headers();
      final body = jsonEncode(payload);
      
      final r = await _http.put(uri, headers: headers, body: body);
      
      if (r.statusCode == 200) return jsonDecode(r.body);
      throw ApiException(r.statusCode, 'updateQuestion failed (${r.statusCode})');
    } catch (e) {
      print('❌ $tag Network Error Details: $e');
      rethrow;
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    const tag = 'API-deleteQuestion';
    try {
      
      
      final uri = Uri.parse('$_base/question/questions/$questionId');
      final headers = _headers();
      
      final r = await _http.delete(uri, headers: headers);
      
      if (r.statusCode == 200) return;
      throw ApiException(r.statusCode, 'deleteQuestion failed (${r.statusCode})');
    } catch (e) {
      print('❌ $tag Network Error Details: $e');
      rethrow;
    }
  }
}
