part of '../api_service.dart';

// /    Subscriptions                                                  /
extension SubscriptionsApi on ApiService {
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
}
