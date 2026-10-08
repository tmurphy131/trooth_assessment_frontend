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
import '../models/prayer_entry.dart';
import '../models/trivia_session.dart';

part 'api/users_mentorship.dart';
part 'api/mentor.dart';
part 'api/assessments.dart';
part 'api/invites_agreements.dart';
part 'api/spiritual_gifts.dart';
part 'api/account_support.dart';
part 'api/subscriptions.dart';
part 'api/trivia.dart';
part 'api/prayer_journal.dart';

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

}
