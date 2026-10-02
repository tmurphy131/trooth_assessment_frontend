part of '../api_service.dart';

// /    Invites                                                        /, /    Categories                                                     /
extension InvitesAgreementsApi on ApiService {
  /* ─────────────────────────────────────────────────────────────────── */
  /*  ✉️  Invites                                                        */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<void> sendInvite(Map<String, dynamic> payload) async {
    final r = await _http.post(
      Uri.parse('$_base/invitations/invite-apprentice'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (r.statusCode != 200) {
      throw ApiException(r.statusCode, 'sendInvite failed (${r.statusCode})');
    }
  }

  Future<List<dynamic>> getPendingInvites() async {
    final r = await _http.get(
      Uri.parse('$_base/invitations/pending-invites'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'getPendingInvites failed (${r.statusCode})');
  }

  Future<void> revokeInvite(String invitationId) async {
    final r = await _http.delete(
      Uri.parse('$_base/invitations/revoke-invite/$invitationId'),
      headers: _headers(),
    );
    if (r.statusCode != 200) {
      throw ApiException(r.statusCode, 'revokeInvite failed (${r.statusCode})');
    }
  }

  Future<Map<String, dynamic>> validateInviteToken(String token) async {
    final r = await _http.get(
      Uri.parse('$_base/invitations/validate-token/$token'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'validateInviteToken failed (${r.statusCode})');
  }

  Future<void> acceptInvite(Map<String, dynamic> payload) async {
    final r = await _http.post(
      Uri.parse('$_base/invitations/accept-invite'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (r.statusCode != 200) {
      throw ApiException(r.statusCode, 'acceptInvite failed (${r.statusCode})');
    }
  }

  Future<List<dynamic>> getApprenticeInvites(String email) async {
    final r = await _http.get(
      Uri.parse('$_base/invitations/apprentice-invites?email=${Uri.encodeQueryComponent(email)}'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'getApprenticeInvites failed (${r.statusCode})');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  🏷️  Categories                                                     */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<List<Map<String, dynamic>>> getCategories() async {
    final r = await _http.get(
      Uri.parse('$_base/categories/'),
      headers: _headers(),
    );
    if (r.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(r.body));
    throw ApiException(r.statusCode, 'getCategories failed (${r.statusCode}): ${r.body}');
  }

  Future<Map<String, dynamic>> createCategory(String name) async {
    final body = {'name': name};
    final r = await _http.post(
      Uri.parse('$_base/categories/'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'createCategory failed (${r.statusCode}): ${r.body}');
  }

  Future<void> deleteCategory(String categoryId) async {
    final r = await _http.delete(
      Uri.parse('$_base/categories/$categoryId'),
      headers: _headers(),
    );
    if (r.statusCode != 200) throw ApiException(r.statusCode, 'deleteCategory failed (${r.statusCode}): ${r.body}');
  }

  // ───────────────────────────────────────────────────────────────────
  //  🤝 Agreements
  // ───────────────────────────────────────────────────────────────────

  Future<List<dynamic>> listAgreementTemplates() async {
    final r = await _http.get(Uri.parse('$_base/agreements/templates'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'listAgreementTemplates failed (${r.statusCode})');
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
    final payload = {
      'template_version': templateVersion,
      'apprentice_email': apprenticeEmail,
      if (apprenticeName != null && apprenticeName.trim().isNotEmpty) 'apprentice_name': apprenticeName.trim(),
      'apprentice_is_minor': apprenticeIsMinor,
      'parent_required': parentRequired,
      if (parentEmail != null) 'parent_email': parentEmail,
      'fields': fields,
    };
    final r = await _http.post(Uri.parse('$_base/agreements'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'createAgreement failed (${r.statusCode})');
  }

  Future<List<dynamic>> listAgreements({int skip = 0, int limit = 50}) async {
    final uri = Uri.parse('$_base/agreements?skip=$skip&limit=$limit');
    final r = await _http.get(uri, headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'listAgreements failed (${r.statusCode})');
  }

  Future<List<dynamic>> listMyAgreements({int skip = 0, int limit = 50}) async {
    final uri = Uri.parse('$_base/agreements/my?skip=$skip&limit=$limit');
    final r = await _http.get(uri, headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'listMyAgreements failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> submitAgreement(String agreementId) async {
    final path = '/agreements/$agreementId/submit';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'submitAgreement failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> getAgreement(String agreementId) async {
    final path = '/agreements/$agreementId';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'getAgreement failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> apprenticeSignAgreement({
    required String agreementId,
    required String typedName,
  }) async {
    final path = '/agreements/$agreementId/sign/apprentice';
    final payload = { 'typed_name': typedName };
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'apprenticeSignAgreement failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> parentSignAgreement({
    required String agreementId,
    required String typedName,
  }) async {
    final path = '/agreements/$agreementId/sign/parent';
    final payload = { 'typed_name': typedName };
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'parentSignAgreement failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> resendParentToken({
    required String agreementId,
    String? reason,
  }) async {
    final path = '/agreements/$agreementId/resend/parent-token';
    final payload = { if (reason != null) 'reason': reason };
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body);
    if (r.statusCode == 429) {
      final remaining = r.headers['x-rate-limit-remaining'];
      final reset = r.headers['x-rate-limit-reset'];
      throw Exception('Rate limit: too many resends.${remaining != null ? ' Remaining: $remaining' : ''}${reset != null ? ' Reset: $reset' : ''}');
    }
    throw ApiException(r.statusCode, 'resendParentToken failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> revokeAgreement(String agreementId) async {
    final path = '/agreements/$agreementId/revoke';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'revokeAgreement failed (${r.statusCode})');
  }

    Future<Map<String, dynamic>> updateAgreementFields(String agreementId, Map<String, dynamic> partialFields) async {
      final path = '/agreements/$agreementId/fields';
      final r = await _http.patch(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(partialFields));
      if (r.statusCode == 200) return jsonDecode(r.body);
      throw ApiException(r.statusCode, 'updateAgreementFields failed (${r.statusCode})');
    }
  
  /// Apprentice requests mentor to resend parent link (no token generation here)
  Future<Map<String, dynamic>> requestParentResendRequest(String agreementId, {String? reason}) async {
    final path = '/agreements/$agreementId/request-resend-parent';
    final payload = <String, dynamic>{ if (reason != null && reason.isNotEmpty) 'reason': reason };
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body);
    if (r.statusCode == 409) throw Exception('Not awaiting parent signature');
    if (r.statusCode == 429) throw Exception('Too many requests; try later');
    throw ApiException(r.statusCode, 'requestParentResendRequest failed (${r.statusCode})');
  }
  Future<Map<String, dynamic>> terminateApprenticeship(String apprenticeId, String reason) async {
    final path = '/mentor/apprentice/$apprenticeId/terminate';
    // Debug instrumentation
    // (Will print once per attempt; safe for temporary troubleshooting.)
    // Shows token presence but not the token value.
    print('[terminateApprenticeship] path=$path reasonLen=${reason.length} tokenSet=${bearerToken != null}');
    http.Response r;
    try {
      r = await _http.post(
        Uri.parse('$_base$path'),
        headers: _headers(),
        body: jsonEncode({ 'reason': reason }),
      );
    } catch (e) {
      print('[terminateApprenticeship][network_error] $e');
      rethrow;
    }
    if (r.statusCode == 200) return jsonDecode(r.body);
    print('[terminateApprenticeship][failure] code=${r.statusCode} body=${r.body}');
    throw ApiException(r.statusCode, 'terminateApprenticeship failed (${r.statusCode}) ${r.body}');
  }

  /// Apprentice meeting reschedule request (emails mentor)
  Future<Map<String, dynamic>> requestMeetingReschedule(String agreementId, {String? reason, List<String>? proposals}) async {
    final path = '/agreements/$agreementId/request-reschedule';
    final payload = <String, dynamic>{
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (proposals != null && proposals.isNotEmpty) 'proposals': proposals,
    };
    // Add a lightweight correlation id to trace in server logs.
    final correlationId = 'resched-${DateTime.now().millisecondsSinceEpoch}-${(1000 + (DateTime.now().microsecondsSinceEpoch % 8999))}';
    final headers = _headers();
    headers['x-correlation-id'] = correlationId;
    http.Response r;
    try {
      r = await _http.post(Uri.parse('$_base$path'), headers: headers, body: jsonEncode(payload));
    } catch (e) {
      // Network / transport error – expose correlation id for cross-reference
      throw Exception('requestMeetingReschedule network error correlation=$correlationId err=$e');
    }
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
    throw ApiException(r.statusCode, 'requestMeetingReschedule failed status=${r.statusCode} correlation=$correlationId body=$snippet');
  }

  Future<Map<String, dynamic>> reinstateApprenticeship(String apprenticeId, {String? reason}) async {
    final path = '/mentor/apprentice/$apprenticeId/reinstate';
    final payload = reason == null ? null : { 'reason': reason };
    final r = await _http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: payload == null ? null : jsonEncode(payload),
    );
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'reinstateApprenticeship failed (${r.statusCode}) ${r.body}');
  }

  // ───────────────────────────────────────────────────────────────────
  //  🔔 Notifications (Mentor)
  // ───────────────────────────────────────────────────────────────────
  Future<List<dynamic>> mentorNotifications() async {
    final path = '/mentor/notifications';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'mentorNotifications failed (${r.statusCode}): ${r.body}');
  }

  Future<List<dynamic>> mentorNotificationsHistory() async {
    const tag = 'API-mentorNotificationsHistory';
    final path = '/mentor/notifications/history';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    if (r.statusCode == 404) {
      // Deployed backend likely not updated yet with history endpoint.
      // Fail soft: treat as empty history so UI still works.
      dev.log('$tag endpoint missing on server (404). Returning empty list fallback.');
      return const [];
    }
    throw ApiException(r.statusCode, 'mentorNotificationsHistory failed (${r.statusCode}): ${r.body}');
  }

  Future<Map<String, dynamic>> dismissNotification(String notificationId) async {
    const tag = 'API-dismissNotification';
    final path = '/mentor/notifications/$notificationId/dismiss';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
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
    throw ApiException(r.statusCode, 'dismissNotification failed (${r.statusCode}): ${r.body}');
  }

  Future<int> dismissAllNotifications() async {
    const path = '/mentor/notifications/dismiss-all';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      return (body['dismissed'] ?? 0) as int;
    }
    throw ApiException(r.statusCode, 'dismissAllNotifications failed (${r.statusCode}): ${r.body}');
  }

  // Mentor respond to a reschedule request
  Future<Map<String, dynamic>> respondReschedule(String agreementId, {
    required String decision, // accepted | declined | proposed
    String? selectedTime,
    String? note,
  }) async {
    final path = '/agreements/$agreementId/reschedule/respond';
    final payload = <String, dynamic>{
      'decision': decision,
      if (selectedTime != null && selectedTime.isNotEmpty) 'selected_time': selectedTime,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body);
    throw ApiException(r.statusCode, 'respondReschedule failed (${r.statusCode}): ${r.body}');
  }
}
