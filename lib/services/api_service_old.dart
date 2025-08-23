// lib/services/api_service.dart
//
// Centralised HTTP wrapper for the T[root]H Assessment API.
// ─────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Change this to your deployed URL later.
/// • Android emulator → 10.0.2.2
/// • iOS sim / Flutter web → localhost
const String _devBaseUrl = 'http://localhost:8000';

class ApiService {
  ApiService({this.baseUrl = _devBaseUrl});

  /// If you’re using Firebase Auth, pass the ID token in [bearerToken].
  final String baseUrl;
  String? bearerToken;

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
      };

  // ───────────────────────────────────────────────────────────
  //  🩺  Health
  // ───────────────────────────────────────────────────────────

  Future<String> ping() async {
    final res = await http.get(Uri.parse('$baseUrl/'), headers: _headers());
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['message'] as String;
    }
    throw Exception('Ping failed: ${res.statusCode}');
  }

  // ───────────────────────────────────────────────────────────
  //  👤  Users
  // ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createUser({
    required String id,
    required String email,
    required String role, // 'mentor' | 'apprentice'
    String? displayName,
  }) async {
    final body = {
      'id': id,
      'email': email,
      'role': role,
      if (displayName != null) 'display_name': displayName,
    };
    final res = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('createUser failed: ${res.statusCode}');
  }

  Future<void> assignApprentice({
    required String mentorId,
    required String apprenticeId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/assign-apprentice'),
      headers: _headers(),
      body: jsonEncode({
        'mentor_id': mentorId,
        'apprentice_id': apprenticeId,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('assignApprentice failed: ${res.statusCode}');
    }
  }

  // ───────────────────────────────────────────────────────────
  //  📊  Assessments
  // ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createAssessment(
      Map<String, dynamic> assessmentPayload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/assessments'),
      headers: _headers(),
      body: jsonEncode(assessmentPayload),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('createAssessment failed: ${res.statusCode}');
  }

  // ───────────────────────────────────────────────────────────
  //  ✍🏽  Draft Assessments
  // ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> saveAssessmentDraft(
      Map<String, dynamic> draftPayload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/assessment_draft'),
      headers: _headers(),
      body: jsonEncode(draftPayload),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('saveAssessmentDraft failed: ${res.statusCode}');
  }

  // ───────────────────────────────────────────────────────────
  //  🤝  Mentor ↔ Apprentice
  // ───────────────────────────────────────────────────────────

  Future<List<dynamic>> listApprentices() async {
    final res = await http.get(
      Uri.parse('$baseUrl/mentor/my-apprentices'),
      headers: _headers(),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('listApprentices failed: ${res.statusCode}');
  }

  // ───────────────────────────────────────────────────────────
  //  ✉️  Invites
  // ───────────────────────────────────────────────────────────

  Future<void> sendInvite(Map<String, dynamic> invitePayload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/invite'),
      headers: _headers(),
      body: jsonEncode(invitePayload),
    );
    if (res.statusCode != 200) {
      throw Exception('sendInvite failed: ${res.statusCode}');
    }
  }
}
