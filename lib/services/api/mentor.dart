part of '../api_service.dart';

// /    Submissions (Mentor view)                                       /, /    Mentor Profile                                               /, /    Mentor Resources (links only)                                   /
extension MentorApi on ApiService {
  /* ─────────────────────────────────────────────────────────────────── */
  /*  �  Submissions (Mentor view)                                       */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> fetchSubmissionDetail({required String assessmentId}) async {
    final path = '/mentor/assessment/$assessmentId';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 403) throw Exception('Forbidden');
    throw ApiException(r.statusCode, 'fetchSubmissionDetail failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> fetchMentorReportV2Json({required String assessmentId}) async {
    // Backend returns HTML for preview route; we expose a JSON path via /assessments/{id} (scores+mentor_report_v2)
    final path = '/mentor/assessment/$assessmentId';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return data;
    }
    throw ApiException(r.statusCode, 'fetchMentorReportV2Json failed (${r.statusCode})');
  }

  Future<String> fetchMentorReportV2Html({required String assessmentId}) async {
    final path = '/assessments/$assessmentId/mentor-report-v2';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return r.body;
    if (r.statusCode == 404) throw Exception('No report');
    throw ApiException(r.statusCode, 'fetchMentorReportV2Html failed (${r.statusCode})');
  }

  Future<http.Response> downloadMentorReportPdf({required String assessmentId}) async {
    final path = '/assessments/$assessmentId/mentor-report-v2.pdf';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    return r;
  }

  /// Download apprentice's own report as PDF
  Future<http.Response> downloadMyReportPdf({required String assessmentId}) async {
    // Use same endpoint - backend will check authorization
    final path = '/assessments/$assessmentId/mentor-report-v2.pdf';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    return r;
  }

  /// Fetch enhanced full report (premium-only feature) - FOR MENTORS
  /// Returns 403 if user is not premium tier
  /// Returns full AI-enhanced report with deeper insights, resource recommendations, etc.
  Future<Map<String, dynamic>> fetchFullReport({required String draftId}) async {
    final path = '/mentor/submitted-drafts/$draftId/full-report';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    if (r.statusCode == 403) {
      throw PremiumRequiredException('Premium subscription required for full reports');
    }
    throw ApiException(r.statusCode, 'fetchFullReport failed (${r.statusCode})');
  }

  /// Fetch full report for apprentice's own assessment (premium-only)
  /// The [assessmentId] can be either an Assessment.id (from progress/reports)
  /// or an AssessmentDraft.id - the backend handles both.
  /// Returns 403 if apprentice is not premium tier
  /// Returns 404 if assessment not found or not owned by apprentice
  Future<Map<String, dynamic>> fetchMyFullReport({required String assessmentId}) async {
    final path = '/apprentice/my-assessments/$assessmentId/full-report';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    if (r.statusCode == 403) {
      throw PremiumRequiredException('Premium subscription required for full reports');
    }
    if (r.statusCode == 404) {
      throw Exception('Assessment not found');
    }
    throw ApiException(r.statusCode, 'fetchMyFullReport failed (${r.statusCode})');
  }

  /// Fetch full premium report for the current user's own assessment.
  /// Works for any role (apprentice or mentor). Throws [PremiumRequiredException] if not premium.
  Future<Map<String, dynamic>> fetchOwnFullReport({required String assessmentId}) async {
    final path = '/assessments/$assessmentId/my-full-report';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 403) throw PremiumRequiredException('Premium subscription required for full reports');
    if (r.statusCode == 404) throw Exception('Assessment not found');
    throw ApiException(r.statusCode, 'fetchOwnFullReport failed (${r.statusCode})');
  }

  /// Check if the current user has premium subscription
  /// Parses subscription_tier from /users/me endpoint
  /// Premium tiers: mentor_premium, apprentice_premium, mentor_gifted
  Future<bool> isPremiumUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        dev.log('isPremiumUser: No Firebase user');
        return false;
      }
      final profile = await getUserProfile(user.uid);
      final tier = profile['subscription_tier'] as String? ?? 'free';
      // Check for any premium tier (not just "premium")
      const premiumTiers = ['mentor_premium', 'apprentice_premium', 'mentor_gifted'];
      final isPremium = premiumTiers.contains(tier);
      dev.log('isPremiumUser: tier=$tier, isPremium=$isPremium');
      return isPremium;
    } catch (e) {
      dev.log('Error checking premium status: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> emailMentorReportByAssessment({required String assessmentId, required String toEmail, bool includePdf = true}) async {
    final path = '/assessments/$assessmentId/email-report';
    final body = { 'to_email': toEmail, 'include_pdf': includePdf };
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(body));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'emailMentorReportByAssessment failed (${r.statusCode}) ${r.body}');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  �🧑‍🏫  Mentor Profile                                               */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<Map<String, dynamic>> getMyMentorProfile() async {
    const path = '/mentor-profile/me';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'getMyMentorProfile failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> updateMyMentorProfile({
    String? avatarUrl,
    String? roleTitle,
    String? organization,
    String? phone,
    String? bio,
  }) async {
    const path = '/mentor-profile/me';
    final payload = {
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (roleTitle != null) 'role_title': roleTitle,
      if (organization != null) 'organization': organization,
      if (phone != null) 'phone': phone,
      if (bio != null) 'bio': bio,
    };
    final r = await _http.put(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'updateMyMentorProfile failed (${r.statusCode}) ${r.body}');
  }

  /// Returns profiles for all active mentors of the current apprentice.
  Future<List<dynamic>> getAllMentorProfilesForApprentice() async {
    const path = '/mentor-profile/for-apprentice';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'getAllMentorProfilesForApprentice failed (${r.statusCode}) ${r.body}');
  }

  /// Returns the profile for a specific active mentor of the current apprentice.
  Future<Map<String, dynamic>> getMentorProfileForApprentice(String mentorId) async {
    final path = '/mentor-profile/for-apprentice/$mentorId';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'getMentorProfileForApprentice failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> getAssessmentDetail(String assessmentId) async {
    final r = await _http.get(
      Uri.parse('$_base/mentor/assessment/$assessmentId'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'getAssessmentDetail failed (${r.statusCode})');
  }

  /// Get completed assessments with AI scoring results
  Future<List<dynamic>> getCompletedAssessments() async {
    final r = await _http.get(
      Uri.parse('$_base/assessment-drafts/completed'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'getCompletedAssessments failed (${r.statusCode})');
  }

  /// Get detailed assessment results with AI feedback
  Future<Map<String, dynamic>> getAssessmentResults(String assessmentId) async {
    final r = await _http.get(
      Uri.parse('$_base/assessments/$assessmentId'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'getAssessmentResults failed (${r.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  🔗  Mentor Resources (links only)                                   */
  /* ─────────────────────────────────────────────────────────────────── */

  // Apprentice: list shared resources targeted to me
  Future<List<dynamic>> listMySharedResources() async {
    const path = '/apprentice/resources';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'listMySharedResources failed (${r.statusCode}) ${r.body}');
  }

  // Mentor: list my resources (optionally filter by apprentice)
  Future<List<dynamic>> listMentorResources({String? apprenticeId}) async {
    var uri = Uri.parse('$_base/mentor/resources');
    if (apprenticeId != null && apprenticeId.isNotEmpty) {
      uri = uri.replace(queryParameters: {'apprentice_id': apprenticeId});
    }
    final r = await _http.get(uri, headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'listMentorResources failed (${r.statusCode}) ${r.body}');
  }

  // Mentor: create a resource
  Future<Map<String, dynamic>> createMentorResource({
    String? apprenticeId,
    required String title,
    String? description,
    String? linkUrl,
    bool isShared = true,
  }) async {
    const path = '/mentor/resources';
    final payload = {
      if (apprenticeId != null && apprenticeId.isNotEmpty) 'apprentice_id': apprenticeId,
      'title': title,
      if (description != null) 'description': description,
      if (linkUrl != null) 'link_url': linkUrl,
      'is_shared': isShared,
    };
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200 || r.statusCode == 201) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'createMentorResource failed (${r.statusCode}) ${r.body}');
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
    final path = '/mentor/resources/$resourceId';
    final payload = <String, dynamic>{
      if (apprenticeId != null) 'apprentice_id': apprenticeId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (linkUrl != null) 'link_url': linkUrl,
      if (isShared != null) 'is_shared': isShared,
    };
    final r = await _http.patch(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'updateMentorResource failed (${r.statusCode}) ${r.body}');
  }

  // Mentor: delete a resource
  Future<bool> deleteMentorResource(String resourceId) async {
    final path = '/mentor/resources/$resourceId';
    final r = await _http.delete(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return (jsonDecode(r.body) as Map<String, dynamic>)['deleted'] == true;
    throw ApiException(r.statusCode, 'deleteMentorResource failed (${r.statusCode}) ${r.body}');
  }

  Future<List<dynamic>> getSubmittedDrafts({
    String? apprenticeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (apprenticeId != null) queryParams['apprentice_id'] = apprenticeId;
    if (startDate != null) queryParams['start_date'] = startDate.toIso8601String();
    if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();
    
    final uri = Uri.parse('$_base/mentor/submitted-drafts')
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final r = await _http.get(uri, headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'getSubmittedDrafts failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getSubmittedDraft(String draftId) async {
    final r = await _http.get(
      Uri.parse('$_base/mentor/submitted-drafts/$draftId'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'getSubmittedDraft failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getApprenticeProfile(String apprenticeId) async {
    final r = await _http.get(
      Uri.parse('$_base/mentor/my-apprentices/$apprenticeId'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'getApprenticeProfile failed (${r.statusCode})');
  }
}
