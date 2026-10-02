part of '../api_service.dart';

// /                       ACCOUNT DELETION                              /, /                       MENTOR NOTES                                  /, /    Push Notifications                                             /, /    Support                                                        /
extension AccountSupportApi on ApiService {
  /* ─────────────────────────────────────────────────────────────────── */
  /*                       ACCOUNT DELETION                              */
  /* ─────────────────────────────────────────────────────────────────── */

  /// Get a summary of what will be deleted when the account is closed.
  /// Returns counts of all associated data so the user understands the impact.
  Future<Map<String, dynamic>> getAccountDeletionSummary() async {
    const path = '/users/me/deletion-summary';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'getAccountDeletionSummary failed (${r.statusCode}) ${r.body}');
  }

  /// Permanently delete the current user's account and all associated data.
  /// This is IRREVERSIBLE. Requires confirmationText to be exactly "DELETE".
  Future<Map<String, dynamic>> closeAccount({required String confirmationText}) async {
    const path = '/users/me/close-account';
    final body = {'confirmation_text': confirmationText};
    final r = await _http.delete(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'closeAccount failed (${r.statusCode}) ${r.body}');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*                       MENTOR NOTES                                  */
  /* ─────────────────────────────────────────────────────────────────── */

  /// Create a new mentor note on an assessment.
  /// [assessmentId] - The assessment this note is for.
  /// [content] - The note text (required).
  /// [followUpPlan] - Optional follow-up plan text.
  /// [isPrivate] - If true (default), only the mentor can see. If false, shared with apprentice.
  Future<Map<String, dynamic>> createMentorNote({
    required String assessmentId,
    required String content,
    String? followUpPlan,
    bool isPrivate = true,
  }) async {
    const path = '/mentor-notes/';
    final body = {
      'assessment_id': assessmentId,
      'content': content,
      if (followUpPlan != null) 'follow_up_plan': followUpPlan,
      'is_private': isPrivate,
    };
    final r = await _http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'createMentorNote failed (${r.statusCode}) ${r.body}');
  }

  /// Get all mentor notes for a specific assessment (mentor view).
  /// Returns all notes including private ones since this is for the mentor.
  Future<List<MentorNote>> getMentorNotesForAssessment(String assessmentId) async {
    final path = '/mentor-notes/assessment/$assessmentId';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) {
      final decoded = jsonDecode(r.body);
      if (decoded is List) {
        return decoded.map((e) => MentorNote.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    }
    if (r.statusCode == 404) return [];
    throw ApiException(r.statusCode, 'getMentorNotesForAssessment failed (${r.statusCode}) ${r.body}');
  }

  /// Update an existing mentor note.
  /// Only the fields provided will be updated.
  Future<Map<String, dynamic>> updateMentorNote({
    required String noteId,
    String? content,
    String? followUpPlan,
    bool? isPrivate,
  }) async {
    final path = '/mentor-notes/$noteId';
    final body = <String, dynamic>{};
    if (content != null) body['content'] = content;
    if (followUpPlan != null) body['follow_up_plan'] = followUpPlan;
    if (isPrivate != null) body['is_private'] = isPrivate;
    final r = await _http.patch(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'updateMentorNote failed (${r.statusCode}) ${r.body}');
  }

  /// Delete a mentor note.
  /// Only the mentor who created the note can delete it.
  Future<void> deleteMentorNote(String noteId) async {
    final path = '/mentor-notes/$noteId';
    final r = await _http.delete(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 204 || r.statusCode == 200) return;
    throw ApiException(r.statusCode, 'deleteMentorNote failed (${r.statusCode}) ${r.body}');
  }

  /// Get shared notes for an assessment (apprentice view).
  /// Only returns notes where is_private=false.
  Future<List<MentorNote>> getSharedNotesForAssessment(String assessmentId) async {
    final path = '/mentor-notes/shared/assessment/$assessmentId';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) {
      final decoded = jsonDecode(r.body);
      if (decoded is List) {
        return decoded.map((e) => MentorNote.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    }
    if (r.statusCode == 404) return [];
    throw ApiException(r.statusCode, 'getSharedNotesForAssessment failed (${r.statusCode}) ${r.body}');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  �  Push Notifications                                             */
  /* ─────────────────────────────────────────────────────────────────── */

  /// Register a device for push notifications.
  /// [fcmToken] is the Firebase Cloud Messaging token.
  /// [platform] is 'ios', 'android', or 'web'.
  Future<Map<String, dynamic>> registerDevice({
    required String fcmToken,
    required String platform,
    String? deviceModel,
  }) async {
    final path = '/push-notifications/register-device';
    final body = {
      'fcm_token': fcmToken,
      'platform': platform,
      if (deviceModel != null) 'device_model': deviceModel,
    };
    final r = await _http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'registerDevice failed (${r.statusCode}) ${r.body}');
  }

  /// Unregister a device from push notifications.
  /// Call this when the user logs out.
  Future<void> unregisterDevice({required String fcmToken}) async {
    const tag = 'API-unregisterDevice';
    final path = '/push-notifications/unregister-device';
    final body = {'fcm_token': fcmToken};
    final r = await _http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode == 200 || r.statusCode == 204) return;
    // Don't throw on 404 - token might already be unregistered
    if (r.statusCode == 404) {
      dev.log('$tag: Token not found (already unregistered)');
      return;
    }
    throw ApiException(r.statusCode, 'unregisterDevice failed (${r.statusCode}) ${r.body}');
  }

  /// Get list of registered devices for the current user.
  Future<List<Map<String, dynamic>>> getMyDevices() async {
    final path = '/push-notifications/my-devices';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) {
      final decoded = jsonDecode(r.body);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    }
    throw ApiException(r.statusCode, 'getMyDevices failed (${r.statusCode}) ${r.body}');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  �📧  Support                                                        */
  /* ─────────────────────────────────────────────────────────────────── */

  /// Submit a support request. Works for both authenticated and unauthenticated users.
  /// If authenticated, user_id will be included automatically by the backend.
  Future<Map<String, dynamic>> submitSupportRequest({
    required String name,
    required String email,
    required String topic,
    required String message,
    String? deviceInfo,
  }) async {
    
    // Try to get token if available, but don't require it
    try {
    } catch (_) {
      // Support works without auth
    }
    
    final path = '/support/submit';
    final body = {
      'name': name,
      'email': email,
      'topic': topic,
      'message': message,
      'source': 'app',
      if (deviceInfo != null) 'device_info': deviceInfo,
    };
    final r = await _http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode == 200) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    if (r.statusCode == 429) {
      throw Exception('Too many requests. Please try again later.');
    }
    throw ApiException(r.statusCode, 'submitSupportRequest failed (${r.statusCode}) ${r.body}');
  }
}
