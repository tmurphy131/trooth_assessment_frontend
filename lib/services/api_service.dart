// lib/services/api_service.dart
//
// HTTP client for the T[root]H Discipleship backend.
// Every request goes through [_ApiClient], which owns the cross-cutting work:
// fresh Firebase ID token + Authorization header, one retry on 401, a 20 s
// timeout, NetworkException for transport failures, and debug-only logging.
// Endpoint methods below only build the request and interpret the response.
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mentor_note.dart';

/// Exception thrown when a premium-only feature is accessed without subscription
class PremiumRequiredException implements Exception {
  final String message;
  PremiumRequiredException(this.message);
  @override
  String toString() => message;
}

/// Thrown when the backend can't be reached or doesn't answer in time.
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => message;
}

/// The backend answered with an error status.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => message;
}

/// Sends every request: auth, retry on 401, timeout, errors and logging.
class _ApiClient {
  _ApiClient(this.client, {required this.authorization, required this.canRetryAuth});

  http.Client client;

  /// Current `Authorization` header value (refreshing the token if it's close
  /// to expiry, or always when [force] is set). Null when signed out.
  Future<String?> Function({bool force}) authorization;

  /// Whether a 401 is worth retrying with a force-refreshed token.
  bool Function() canRetryAuth;

  /// Called after any successful write, so cached reads can be dropped.
  void Function()? onMutation;

  static const _timeout = Duration(seconds: 20);

  Future<http.Response> _send(String method, Uri url, Map<String, String>? headers, Object? body) async {
    final requestHeaders = {...?headers};

    Future<http.Response> attempt({bool force = false}) async {
      final auth = await authorization(force: force);
      if (auth != null) {
        requestHeaders['Authorization'] = auth;
      } else {
        requestHeaders.remove('Authorization');
      }
      try {
        final request = switch (method) {
          'GET' => client.get(url, headers: requestHeaders),
          'POST' => client.post(url, headers: requestHeaders, body: body),
          'PUT' => client.put(url, headers: requestHeaders, body: body),
          'PATCH' => client.patch(url, headers: requestHeaders, body: body),
          'DELETE' => client.delete(url, headers: requestHeaders, body: body),
          _ => throw ArgumentError('Unsupported method $method'),
        };
        return await request.timeout(_timeout);
      } on TimeoutException {
        throw NetworkException('The server took too long to respond. Please try again.');
      } on http.ClientException {
        throw NetworkException('Could not reach the server. Check your connection and try again.');
      }
    }

    var response = await attempt();
    // An expired or revoked token gets a 401 before the handler runs, so a
    // single retry with a fresh token is safe even for POSTs.
    if (response.statusCode == 401 && canRetryAuth()) {
      response = await attempt(force: true);
    }
    _log(method, url, response);
    if (method != 'GET' && response.statusCode >= 200 && response.statusCode < 300) {
      onMutation?.call();
    }
    return response;
  }

  void _log(String method, Uri url, http.Response r) {
    if (!kDebugMode) return;
    final preview = r.body.length > 200 ? '${r.body.substring(0, 200)}…' : r.body;
    dev.log('$method ${url.path} → ${r.statusCode} $preview', name: 'API');
  }

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) => _send('GET', url, headers, null);
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) =>
      _send('POST', url, headers, body);
  Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body}) =>
      _send('PUT', url, headers, body);
  Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body}) =>
      _send('PATCH', url, headers, body);
  Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body}) =>
      _send('DELETE', url, headers, body);
}

/// Backend URL, chosen at build time:
/// `flutter build ipa --dart-define=API_BASE_URL=https://trooth-discipleship-api.onlyblv.com/`
/// Defaults to dev so local `flutter run` never hits prod.
const String _defaultBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://trooth-discipleship-api-dev.onlyblv.com/',
);

class ApiService {
  /* ── Singleton ────────────────────────────────────────────────────── */
  factory ApiService() => _instance;
  ApiService._internal();
  static final ApiService _instance = ApiService._internal();

  /* ── Config ───────────────────────────────────────────────────────── */
  /// Override for e2e / staging builds before the first call:
  /// `ApiService().baseUrlOverride = 'https://api.prod.trooth.app';`
  String? baseUrlOverride;

  late final _ApiClient _http = _ApiClient(
    http.Client(),
    authorization: _authorization,
    canRetryAuth: _isSignedIn,
  )..onMutation = clearCache;

  static String? _currentUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null; // Firebase not initialized (e.g. unit tests)
    }
  }

  static bool _isSignedIn() => _currentUid() != null;

  /* ── Read cache ───────────────────────────────────────────────────── */
  // Short-lived cache for a few reads that several screens request in a row
  // (subscription status, profile, published templates). Bodies are cached
  // as text and decoded per caller, so no caller can mutate another's data.
  // Concurrent requests share one in-flight call. Any successful write and
  // sign-out clear it; failures are never cached.
  final _cache = <String, ({DateTime expires, Future<String> body})>{};

  Future<String> _cachedBody(String key, Duration ttl, Future<String> Function() fetch) {
    final cacheKey = '${_currentUid()}|$key';
    final hit = _cache[cacheKey];
    if (hit != null && hit.expires.isAfter(DateTime.now())) return hit.body;
    final body = fetch();
    _cache[cacheKey] = (expires: DateTime.now().add(ttl), body: body);
    body.catchError((_) {
      if (identical(_cache[cacheKey]?.body, body)) _cache.remove(cacheKey);
      return '';
    });
    return body;
  }

  /// Drops every cached read (call on sign-out; writes do it automatically).
  void clearCache() => _cache.clear();

  /// Swap the underlying client in tests (e.g. `MockClient`).
  @visibleForTesting
  set httpClient(http.Client client) => _http.client = client;

  /// Replace token handling in tests.
  @visibleForTesting
  void setAuthForTesting({
    required Future<String?> Function({bool force}) authorization,
    bool Function()? canRetryAuth,
  }) {
    _http.authorization = authorization;
    _http.canRetryAuth = canRetryAuth ?? () => true;
  }
  String get _base => baseUrlOverride ?? _defaultBaseUrl;
  String get baseUrl => _base;

  /// Firebase ID token for requests. [_ApiClient] keeps it fresh; it's only
  /// assigned directly in tests.
  String? bearerToken;
  DateTime? _tokenExpiry; // cached expiry for smarter refresh

  Map<String, String> _headers() => const {'Content-Type': 'application/json'};

  Future<String?> _authorization({bool force = false}) async {
    await _ensureFreshToken(force: force);
    return bearerToken == null ? null : 'Bearer $bearerToken';
  }

  /// Refreshes the cached token when there is none, its expiry is unknown,
  /// it expires within 2 minutes, or [force] is set.
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

      final result = await user.getIdTokenResult(force);
      final token = result.token;
      if (token != null && token.isNotEmpty) {
        bearerToken = token;
        _tokenExpiry = result.expirationTime; // may be null on some platforms
      }
    } catch (e) {
      if (kDebugMode) dev.log('Token refresh failed: $e', name: 'API');
    }
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  🩺  Health                                                         */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<String> ping() async {
    final r = await _http.get(Uri.parse('$_base/'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body)['message'] as String;
    throw ApiException(r.statusCode, 'Ping failed (${r.statusCode})');
  }

  Future<Map<String, dynamic>> healthCheck() async {
    const tag = 'API-healthCheck';
    try {
      final r = await _http.get(Uri.parse('$_base/health'), headers: _headers());
      if (r.statusCode == 200) return jsonDecode(r.body);
      throw ApiException(r.statusCode, 'Health check failed (${r.statusCode})');
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

  /* ─────────────────────────────────────────────────────────────────── */
  /*  💳  Subscriptions                                                  */
  /* ─────────────────────────────────────────────────────────────────── */

  /// Get current user's subscription status
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    const path = '/subscriptions/status';
    final body = await _cachedBody(path, const Duration(seconds: 60), () async {
      final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
      if (r.statusCode == 200) return r.body;
      throw ApiException(r.statusCode, 'getSubscriptionStatus failed (${r.statusCode}) ${r.body}');
    });
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// Restore subscription from RevenueCat (sync with backend)
  /// [syncData] optional map of entitlement info from RevenueCat SDK
  Future<Map<String, dynamic>> restoreSubscription({Map<String, dynamic>? syncData}) async {
    const path = '/subscriptions/restore';
    if (syncData != null) {
      final r = await _http.post(
        Uri.parse('$_base$path'),
        headers: _headers(),
        body: jsonEncode(syncData),
      );
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
      throw ApiException(r.statusCode, 'restoreSubscription failed (${r.statusCode}) ${r.body}');
    } else {
      final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
      throw ApiException(r.statusCode, 'restoreSubscription failed (${r.statusCode}) ${r.body}');
    }
  }

  /* ── Mentor Gift Seats ────────────────────────────────────────────── */

  /// Get list of gift seats created by the current mentor
  Future<List<dynamic>> getMentorGiftSeats() async {
    const path = '/mentor/seats';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as List<dynamic>;
    throw ApiException(r.statusCode, 'getMentorGiftSeats failed (${r.statusCode}) ${r.body}');
  }

  /// Create a gift seat for an apprentice (legacy - use confirmGiftSeatPurchase for IAP)
  Future<Map<String, dynamic>> createMentorGiftSeat({
    required String apprenticeEmail,
    String? apprenticeName,
  }) async {
    const path = '/mentor/seats';
    final body = {
      'apprentice_email': apprenticeEmail,
      if (apprenticeName != null) 'apprentice_name': apprenticeName,
    };
    final r = await _http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode == 200 || r.statusCode == 201) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    if (r.statusCode == 403) {
      throw PremiumRequiredException('You need a premium subscription to gift seats to apprentices.');
    }
    if (r.statusCode == 400) {
      final msg = jsonDecode(r.body)['detail'] ?? 'Invalid request';
      throw Exception(msg);
    }
    throw ApiException(r.statusCode, 'createMentorGiftSeat failed (${r.statusCode}) ${r.body}');
  }

  /// Confirm a gift seat purchase from RevenueCat IAP
  /// This creates or retrieves a seat tied to the RevenueCat subscription
  Future<Map<String, dynamic>> confirmGiftSeatPurchase({
    required String subscriptionId,
    required String productId,
    String? platform,
    String? apprenticeEmail,
    String? apprenticeName,
    String? apprenticeId,
  }) async {
    const path = '/mentor/seats/purchase';
    final body = {
      'subscription_id': subscriptionId,
      'product_id': productId,
      if (platform != null) 'platform': platform,
      if (apprenticeEmail != null) 'apprentice_email': apprenticeEmail,
      if (apprenticeName != null) 'apprentice_name': apprenticeName,
      if (apprenticeId != null) 'apprentice_id': apprenticeId,
    };
    final r = await _http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode == 200 || r.statusCode == 201) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    if (r.statusCode == 403) {
      throw PremiumRequiredException('You need an active subscription to purchase gift seats.');
    }
    if (r.statusCode == 400) {
      final msg = jsonDecode(r.body)['detail'] ?? 'Invalid purchase request';
      throw Exception(msg);
    }
    throw ApiException(r.statusCode, 'confirmGiftSeatPurchase failed (${r.statusCode}) ${r.body}');
  }

  /// Revoke a gift seat
  Future<void> revokeMentorGiftSeat(String seatId) async {
    final path = '/mentor/seats/$seatId/revoke';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200 || r.statusCode == 204) return;
    throw ApiException(r.statusCode, 'revokeMentorGiftSeat failed (${r.statusCode}) ${r.body}');
  }

  /// Assign an unassigned gift seat to an apprentice
  Future<Map<String, dynamic>> assignMentorGiftSeat({
    required String seatId,
    String? apprenticeId,
    String? apprenticeEmail,
    String? apprenticeName,
  }) async {
    final path = '/mentor/seats/$seatId/assign';
    final body = {
      if (apprenticeId != null) 'apprentice_id': apprenticeId,
      if (apprenticeEmail != null) 'apprentice_email': apprenticeEmail,
      if (apprenticeName != null) 'apprentice_name': apprenticeName,
    };
    final r = await _http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'assignMentorGiftSeat failed (${r.statusCode}) ${r.body}');
  }

  /// Get details of a specific gift seat
  Future<Map<String, dynamic>> getMentorGiftSeatDetails(String seatId) async {
    final path = '/mentor/seats/$seatId';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'getMentorGiftSeatDetails failed (${r.statusCode}) ${r.body}');
  }

  /* ── Apprentice Subscription ──────────────────────────────────────── */

  /// Get apprentice's subscription source (e.g., gifted by mentor)
  Future<Map<String, dynamic>> getApprenticeSubscriptionSource() async {
    const path = '/apprentice/subscription-source';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return {}; // No gifted subscription
    throw ApiException(r.statusCode, 'getApprenticeSubscriptionSource failed (${r.statusCode}) ${r.body}');
  }

  /* ─────────────────────────────────────────────────────────────────── */
  /*  🎮  Trivia                                                          */
  /* ─────────────────────────────────────────────────────────────────── */

  Future<List<Map<String, dynamic>>> triviaDrawQuestions({
    required String category,
    required String difficulty,
    int count = 20,
  }) async {
    final path = '/trivia/questions/draw?category=${Uri.encodeQueryComponent(category)}&difficulty=$difficulty&count=$count';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(r.body));
    throw ApiException(r.statusCode, 'triviaDrawQuestions failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> triviaSubmitSingleGame(Map<String, dynamic> payload) async {
    const path = '/trivia/single/submit';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'triviaSubmitSingleGame failed (${r.statusCode}) ${r.body}');
  }

  Future<List<Map<String, dynamic>>> triviaGetLeaderboard({
    String? category,
    String? difficulty,
    int limit = 50,
  }) async {
    final params = <String>[];
    if (category != null) params.add('category=$category');
    if (difficulty != null) params.add('difficulty=$difficulty');
    params.add('limit=$limit');
    final path = '/trivia/leaderboard?${params.join('&')}';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(r.body));
    throw ApiException(r.statusCode, 'triviaGetLeaderboard failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> triviaCreateChallenge(Map<String, dynamic> payload) async {
    const path = '/trivia/challenges';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'triviaCreateChallenge failed (${r.statusCode}) ${r.body}');
  }

  Future<List<Map<String, dynamic>>> triviaListChallenges() async {
    const path = '/trivia/challenges';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(r.body));
    throw ApiException(r.statusCode, 'triviaListChallenges failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> triviaGetChallenge(String challengeId) async {
    final path = '/trivia/challenges/$challengeId';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'triviaGetChallenge failed (${r.statusCode}) ${r.body}');
  }

  Future<void> triviaAcceptChallenge(String challengeId) async {
    final path = '/trivia/challenges/$challengeId/accept';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode != 200) throw ApiException(r.statusCode, 'triviaAcceptChallenge failed (${r.statusCode}) ${r.body}');
  }

  Future<void> triviaDeclineChallenge(String challengeId) async {
    final path = '/trivia/challenges/$challengeId/decline';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode != 200) throw ApiException(r.statusCode, 'triviaDeclineChallenge failed (${r.statusCode}) ${r.body}');
  }

  Future<void> triviaCancelChallenge(String challengeId) async {
    final path = '/trivia/challenges/$challengeId';
    final r = await _http.delete(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode != 200) throw ApiException(r.statusCode, 'triviaCancelChallenge failed (${r.statusCode}) ${r.body}');
  }

  Future<void> triviaForfeitChallenge(String challengeId) async {
    final path = '/trivia/challenges/$challengeId/forfeit';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode != 200) throw ApiException(r.statusCode, 'triviaForfeitChallenge failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> triviaSubmitChallengeAnswer(
    String challengeId,
    Map<String, dynamic> answer,
  ) async {
    final path = '/trivia/challenges/$challengeId/answer';
    final payload = {'answer': answer};
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers(), body: jsonEncode(payload));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'triviaSubmitChallengeAnswer failed (${r.statusCode}) ${r.body}');
  }

  Future<void> triviaNudge(String challengeId) async {
    final path = '/trivia/challenges/$challengeId/nudge';
    final r = await _http.post(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode != 200) throw ApiException(r.statusCode, 'triviaNudge failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> triviaGetProfile(String userId) async {
    final path = '/trivia/profile/$userId';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'triviaGetProfile failed (${r.statusCode}) ${r.body}');
  }

  Future<Map<String, dynamic>> triviaGetConnections() async {
    const path = '/trivia/connections';
    final r = await _http.get(Uri.parse('$_base$path'), headers: _headers());
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    throw ApiException(r.statusCode, 'triviaGetConnections failed (${r.statusCode}) ${r.body}');
  }
}
