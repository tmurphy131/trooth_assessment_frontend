// lib/services/subscription_service.dart
//
// Manages subscription state and RevenueCat integration for T[root]H
// Handles:
// • RevenueCat SDK initialization and purchase management
// • Subscription status from backend API
// • Gift seat redemption for apprentices
// • Premium feature gating
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'api_service.dart';

/// Subscription tier enum matching backend SubscriptionTier
enum SubscriptionTier {
  free,
  mentorPremium,
  apprenticePremium,
  mentorGifted,
}

/// Platform where subscription was purchased
enum SubscriptionPlatform {
  apple,
  google,
  gifted,
  adminGranted,
}

/// Subscription status model
class SubscriptionStatus {
  final SubscriptionTier tier;
  final bool isPremium;
  final DateTime? expiresAt;
  final SubscriptionPlatform? platform;
  final String? giftedByMentorId;
  final String? giftedByMentorName;
  final int? availableSeats; // For mentors: how many seats they can gift
  final int? usedSeats;      // For mentors: how many seats are in use
  // Mentor apprentice limits
  final bool canAddApprentices;
  final int? maxApprentices;  // null = unlimited
  final int currentApprenticeCount;
  final bool isGrandfathered;

  SubscriptionStatus({
    required this.tier,
    required this.isPremium,
    this.expiresAt,
    this.platform,
    this.giftedByMentorId,
    this.giftedByMentorName,
    this.availableSeats,
    this.usedSeats,
    this.canAddApprentices = true,
    this.maxApprentices,
    this.currentApprenticeCount = 0,
    this.isGrandfathered = false,
  });

  factory SubscriptionStatus.free() => SubscriptionStatus(
    tier: SubscriptionTier.free,
    isPremium: false,
  );

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final tierStr = json['subscription_tier'] as String? ?? 'free';
    final platformStr = json['subscription_platform'] as String?;
    
    SubscriptionTier tier;
    switch (tierStr) {
      case 'mentor_premium':
        tier = SubscriptionTier.mentorPremium;
        break;
      case 'apprentice_premium':
        tier = SubscriptionTier.apprenticePremium;
        break;
      case 'mentor_gifted':
        tier = SubscriptionTier.mentorGifted;
        break;
      default:
        tier = SubscriptionTier.free;
    }

    SubscriptionPlatform? platform;
    if (platformStr != null) {
      switch (platformStr) {
        case 'apple':
          platform = SubscriptionPlatform.apple;
          break;
        case 'google':
          platform = SubscriptionPlatform.google;
          break;
        case 'gifted':
          platform = SubscriptionPlatform.gifted;
          break;
        case 'admin_granted':
          platform = SubscriptionPlatform.adminGranted;
          break;
      }
    }

    return SubscriptionStatus(
      tier: tier,
      isPremium: json['has_premium'] as bool? ?? json['is_premium'] as bool? ?? false,
      expiresAt: json['subscription_expires_at'] != null 
        ? DateTime.tryParse(json['subscription_expires_at'] as String)
        : null,
      platform: platform,
      giftedByMentorId: json['gifted_by_mentor_id'] as String?,
      giftedByMentorName: json['gifted_by_mentor_name'] as String?,
      availableSeats: json['available_seats'] as int?,
      usedSeats: json['used_seats'] as int?,
      // Mentor apprentice limits
      canAddApprentices: json['can_add_apprentices'] as bool? ?? true,
      maxApprentices: json['max_apprentices'] as int?,
      currentApprenticeCount: json['current_apprentice_count'] as int? ?? 0,
      isGrandfathered: json['is_grandfathered'] as bool? ?? false,
    );
  }

  /// Check if user can access premium features
  bool get canAccessPremium => isPremium;

  /// Check if mentor has unlimited apprentices (premium or grandfathered)
  bool get hasUnlimitedApprentices => maxApprentices == null;
  
  /// Check if a specific apprentice index is accessible (0-based index)
  /// For free mentors without grandfathering, only index 0 (first apprentice) is accessible
  bool canAccessApprentice(int index) {
    if (isPremium || isGrandfathered) return true;
    return index == 0; // Free mentors can only access first apprentice
  }

  /// Check if subscription is about to expire (within 7 days)
  bool get isExpiringSoon {
    if (expiresAt == null) return false;
    return expiresAt!.difference(DateTime.now()).inDays <= 7;
  }

  /// Get human-readable tier name
  String get tierDisplayName {
    switch (tier) {
      case SubscriptionTier.mentorPremium:
        return 'Mentor Premium';
      case SubscriptionTier.apprenticePremium:
        return 'Apprentice Premium';
      case SubscriptionTier.mentorGifted:
        return 'Gifted by Mentor';
      case SubscriptionTier.free:
        return 'Free';
    }
  }
}

/// Gift seat model for mentors
class MentorGiftSeat {
  final String id;
  final String? apprenticeEmail;
  final String? apprenticeName;
  final String? apprenticeId;
  final String? redemptionCode;
  final bool isActive;
  final DateTime? redeemedAt;
  final DateTime createdAt;

  MentorGiftSeat({
    required this.id,
    this.apprenticeEmail,
    this.apprenticeName,
    this.apprenticeId,
    this.redemptionCode,
    required this.isActive,
    this.redeemedAt,
    required this.createdAt,
  });

  factory MentorGiftSeat.fromJson(Map<String, dynamic> json) {
    return MentorGiftSeat(
      id: json['id'] as String,
      apprenticeEmail: json['apprentice_email'] as String?,
      apprenticeName: json['apprentice_name'] as String?,
      apprenticeId: json['apprentice_id'] as String?,
      redemptionCode: json['redemption_code'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      redeemedAt: json['redeemed_at'] != null 
        ? DateTime.tryParse(json['redeemed_at'] as String)
        : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isRedeemed => redeemedAt != null;
  
  /// Display name: apprentice name, email, or "Unassigned"
  String get displayName => apprenticeName ?? apprenticeEmail ?? 'Unassigned';
}

/// Subscription Service - Singleton
class SubscriptionService extends ChangeNotifier {
  /* ── Singleton ────────────────────────────────────────────────────── */
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();
  static final SubscriptionService _instance = SubscriptionService._internal();

  /* ── State ────────────────────────────────────────────────────────── */
  final ApiService _api = ApiService();
  SubscriptionStatus _status = SubscriptionStatus.free();
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  // RevenueCat configuration
  // TEMPORARY: Hardcoded API key for TestFlight testing
  // TODO: Replace with String.fromEnvironment before App Store release
  static const String _revenueCatAppleApiKey = 'appl_lCFeOlOIrgjWmFfbnOpfChlwIzX';
  static const String _revenueCatGoogleApiKey = String.fromEnvironment(
    'REVENUECAT_GOOGLE_KEY',
    defaultValue: '',
  );

  /* ── Getters ──────────────────────────────────────────────────────── */
  SubscriptionStatus get status => _status;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPremium => _status.isPremium;
  SubscriptionTier get tier => _status.tier;

  /* ── Initialization ───────────────────────────────────────────────── */
  
  /// Initialize RevenueCat SDK and fetch subscription status
  /// Call this after user authentication
  Future<void> initialize(String userId) async {
    if (_isInitialized) return;
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Configure RevenueCat with platform-specific API key
      final apiKey = defaultTargetPlatform == TargetPlatform.iOS
          ? _revenueCatAppleApiKey
          : _revenueCatGoogleApiKey;

      // Log API key status (masked for security)
      final keyPrefix = apiKey.isNotEmpty ? apiKey.substring(0, 10) : 'EMPTY';
      dev.log('SubscriptionService: API key status: $keyPrefix... (length=${apiKey.length})');
      
      // Skip RevenueCat if keys not configured (empty string from missing env var)
      if (apiKey.isNotEmpty) {
        await Purchases.configure(
          PurchasesConfiguration(apiKey)..appUserID = userId,
        );
        dev.log('SubscriptionService: RevenueCat configured for user $userId');
        
        // Verify offerings can be fetched
        try {
          final offerings = await Purchases.getOfferings();
          final count = offerings.current?.availablePackages.length ?? 0;
          dev.log('SubscriptionService: Offerings loaded, $count packages available');
          for (final pkg in offerings.current?.availablePackages ?? []) {
            dev.log('SubscriptionService: Package: ${pkg.storeProduct.identifier} - ${pkg.storeProduct.priceString}');
          }
        } catch (e) {
          dev.log('SubscriptionService: Failed to fetch offerings during init: $e');
        }
      } else {
        dev.log('SubscriptionService: RevenueCat API key is EMPTY! '
            'Build must use --dart-define=REVENUECAT_APPLE_KEY=xxx');
      }

      // Fetch subscription status from backend
      await refreshStatus();

      _isInitialized = true;
    } catch (e) {
      _error = 'Failed to initialize subscription service: $e';
      dev.log('SubscriptionService: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh subscription status from backend API
  Future<void> refreshStatus() async {
    try {
      _isLoading = true;
      notifyListeners();

      final data = await _api.getSubscriptionStatus();
      dev.log('SubscriptionService: Raw API response: $data');
      dev.log('SubscriptionService: has_premium in response: ${data['has_premium']}');
      _status = SubscriptionStatus.fromJson(data);
      _error = null;
      
      dev.log('SubscriptionService: Status refreshed - tier=${_status.tier}, isPremium=${_status.isPremium}, isGrandfathered=${_status.isGrandfathered}');
    } catch (e) {
      _error = 'Failed to fetch subscription status: $e';
      dev.log('SubscriptionService: $_error');
      // Keep existing status on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /* ── Purchase Flow ────────────────────────────────────────────────── */

  /// Get available subscription offerings from RevenueCat
  /// Includes retry logic for sandbox/TestFlight testing
  Future<Offerings?> getOfferings({int retryCount = 3}) async {
    for (int attempt = 1; attempt <= retryCount; attempt++) {
      try {
        dev.log('SubscriptionService: Fetching offerings (attempt $attempt/$retryCount)...');
        
        // Check if SDK is configured
        final isConfigured = await Purchases.isConfigured;
        dev.log('SubscriptionService: SDK configured: $isConfigured');
        
        if (!isConfigured) {
          dev.log('SubscriptionService: ERROR - SDK not configured!');
          return null;
        }
        
        // Sync purchases first to ensure customer state is current
        try {
          await Purchases.syncPurchases();
          dev.log('SubscriptionService: Purchases synced');
        } catch (e) {
          dev.log('SubscriptionService: syncPurchases failed (non-fatal): $e');
        }
        
        // Invalidate customer info cache
        try {
          await Purchases.invalidateCustomerInfoCache();
          dev.log('SubscriptionService: Customer info cache invalidated');
        } catch (e) {
          dev.log('SubscriptionService: invalidateCache failed (non-fatal): $e');
        }
        
        // Log customer info for debugging
        try {
          final customerInfo = await Purchases.getCustomerInfo();
          dev.log('SubscriptionService: Customer ID: ${customerInfo.originalAppUserId}');
          dev.log('SubscriptionService: Active entitlements: ${customerInfo.entitlements.active.keys.toList()}');
          dev.log('SubscriptionService: Active subscriptions: ${customerInfo.activeSubscriptions.toList()}');
        } catch (e) {
          dev.log('SubscriptionService: getCustomerInfo failed: $e');
        }
        
        final offerings = await Purchases.getOfferings();
        
        // Detailed logging
        dev.log('SubscriptionService: Offerings fetched. Has current: ${offerings.current != null}');
        dev.log('SubscriptionService: All offering keys: ${offerings.all.keys.toList()}');
        
        if (offerings.current != null) {
          dev.log('SubscriptionService: Current offering ID: ${offerings.current!.identifier}');
          dev.log('SubscriptionService: Available packages: ${offerings.current!.availablePackages.length}');
          for (final pkg in offerings.current!.availablePackages) {
            dev.log('SubscriptionService: - Package: ${pkg.identifier} / ${pkg.storeProduct.identifier} @ ${pkg.storeProduct.priceString}');
          }
          return offerings;
        } else {
          dev.log('SubscriptionService: WARNING - No current offering on attempt $attempt');
          
          // Try to get "default" offering by name if current is null
          if (offerings.all.containsKey('default')) {
            dev.log('SubscriptionService: Found "default" offering by key!');
            // Create a synthetic Offerings object with default as current
            return offerings;
          }
          
          // If no current offering, wait and retry (sandbox can be slow)
          if (attempt < retryCount) {
            dev.log('SubscriptionService: Waiting 3s before retry...');
            await Future.delayed(Duration(seconds: 3));
          }
        }
      } catch (e) {
        dev.log('SubscriptionService: Error on attempt $attempt: $e');
        if (attempt < retryCount) {
          await Future.delayed(Duration(seconds: 3));
        }
      }
    }
    
    dev.log('SubscriptionService: Failed to get offerings after $retryCount attempts');
    return null;
  }

  /// Purchase a subscription package
  Future<bool> purchasePackage(Package package) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await Purchases.purchasePackage(package);
      
      // Check if purchase granted premium entitlement
      if (result.entitlements.active.containsKey('premium')) {
        // Notify backend to sync subscription
        await _api.restoreSubscription();
        await refreshStatus();
        return true;
      }
      
      return false;
    } catch (e) {
      if (e is PurchasesErrorCode) {
        if (e == PurchasesErrorCode.purchaseCancelledError) {
          dev.log('SubscriptionService: Purchase cancelled by user');
          return false;
        }
      }
      _error = 'Purchase failed: $e';
      dev.log('SubscriptionService: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Restore previous purchases
  Future<bool> restorePurchases() async {
    try {
      _isLoading = true;
      notifyListeners();

      await Purchases.restorePurchases();
      
      // Sync with backend
      await _api.restoreSubscription();
      await refreshStatus();
      
      return _status.isPremium;
    } catch (e) {
      _error = 'Restore failed: $e';
      dev.log('SubscriptionService: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /* ── Gift Seats (Mentor Features) ─────────────────────────────────── */

  /// Purchase a gift seat subscription via RevenueCat
  /// Optionally assign to an apprentice by email or ID
  /// Returns the created seat if successful, null if cancelled/failed
  Future<MentorGiftSeat?> purchaseGiftSeat({
    String? apprenticeEmail,
    String? apprenticeName,
    String? apprenticeId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get gift seat offering from RevenueCat
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        _error = 'No subscription offerings available';
        return null;
      }

      // Debug: Log all available offerings and packages
      dev.log('SubscriptionService: Available offerings: ${offerings.all.keys.toList()}');
      for (final entry in offerings.all.entries) {
        dev.log('SubscriptionService: Offering "${entry.key}" packages: ${entry.value.availablePackages.map((p) => p.storeProduct.identifier).toList()}');
      }

      // Find the gift seat package
      // RevenueCat organizes products into offerings - look for gift_seat package
      Package? giftSeatPackage;
      
      // Check for a dedicated gift seats offering
      final giftOffering = offerings.getOffering('mentor_gift_seats');
      if (giftOffering != null && giftOffering.monthly != null) {
        giftSeatPackage = giftOffering.monthly;
      } else {
        // Fallback: look in ALL offerings for a product containing 'gift_seat'
        for (final offering in offerings.all.values) {
          for (final pkg in offering.availablePackages) {
            if (pkg.storeProduct.identifier.toLowerCase().contains('gift_seat')) {
              giftSeatPackage = pkg;
              break;
            }
          }
          if (giftSeatPackage != null) break;
        }
      }

      if (giftSeatPackage == null) {
        _error = 'Gift seat subscription not found. Please contact support.';
        dev.log('SubscriptionService: Could not find gift_seat product in any offering');
        return null;
      }

      dev.log('SubscriptionService: Purchasing gift seat package: ${giftSeatPackage.storeProduct.identifier}');

      // Purchase the gift seat subscription
      final result = await Purchases.purchasePackage(giftSeatPackage);
      
      // Debug: Log all entitlements after purchase
      dev.log('SubscriptionService: Purchase result - active entitlements: ${result.entitlements.active.keys.toList()}');
      for (final entry in result.entitlements.active.entries) {
        final e = entry.value;
        dev.log('SubscriptionService: Entitlement "${entry.key}": productId=${e.productIdentifier}, store=${e.store}');
      }
      
      // Get the transaction/subscription ID from non-subscription transactions
      // For consumables/non-consumables, we can use the product ID + timestamp as identifier
      // For subscriptions, use the latest transaction ID from the CustomerInfo
      String subscriptionId;
      
      // Try to get from active entitlements first (for the gift_seat product)
      String? foundId;
      for (final entry in result.entitlements.active.entries) {
        final entitlement = entry.value;
        // Check if this entitlement is for the gift seat product
        if (entitlement.productIdentifier.toLowerCase().contains('gift_seat')) {
          // Use the identifier which is typically the transaction/subscription ID
          foundId = entitlement.identifier;
          dev.log('SubscriptionService: Found gift_seat entitlement with id: $foundId');
          break;
        }
      }
      
      // If no entitlement found (webhook may create it), generate a unique ID
      // based on user + timestamp to allow backend to track
      if (foundId == null || foundId.isEmpty) {
        // Use product ID + current timestamp as a unique identifier
        // The webhook will update this with the real subscription ID
        foundId = '${giftSeatPackage.storeProduct.identifier}_${DateTime.now().millisecondsSinceEpoch}';
        dev.log('SubscriptionService: No entitlement found, using generated id: $foundId');
      }
      subscriptionId = foundId;

      // Always confirm purchase with backend - this creates the seat
      dev.log('SubscriptionService: Confirming gift seat purchase with backend...');
      try {
        final seatData = await _api.confirmGiftSeatPurchase(
          subscriptionId: subscriptionId,
          productId: giftSeatPackage.storeProduct.identifier,
          apprenticeEmail: apprenticeEmail,
          apprenticeName: apprenticeName,
          apprenticeId: apprenticeId,
        );
        dev.log('SubscriptionService: Gift seat created successfully: ${seatData['seat_id']}');
        
        await refreshStatus();
        return MentorGiftSeat.fromJson(seatData);
      } catch (e) {
        // Backend confirmation failed - but purchase was successful
        // Wait for webhook to create the seat, then refresh
        dev.log('SubscriptionService: Backend confirmation failed ($e), waiting for webhook...');
        await Future.delayed(const Duration(seconds: 3));
        await refreshStatus();
        _error = null;
        
        // Return null but indicate success - seat should appear in list via webhook
        return null;
      }
    } catch (e) {
      if (e is PurchasesErrorCode) {
        if (e == PurchasesErrorCode.purchaseCancelledError) {
          dev.log('SubscriptionService: Gift seat purchase cancelled by user');
          _error = null; // Not an error
          return null;
        }
      }
      _error = 'Failed to purchase gift seat: $e';
      dev.log('SubscriptionService: $_error');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get list of gift seats created by this mentor
  Future<List<MentorGiftSeat>> getGiftSeats() async {
    try {
      final data = await _api.getMentorGiftSeats();
      return (data as List)
          .map((e) => MentorGiftSeat.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      dev.log('SubscriptionService: Failed to get gift seats: $e');
      return [];
    }
  }

  /// Create a new gift seat for an apprentice
  Future<MentorGiftSeat?> createGiftSeat({
    required String apprenticeEmail,
    String? apprenticeName,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final data = await _api.createMentorGiftSeat(
        apprenticeEmail: apprenticeEmail,
        apprenticeName: apprenticeName,
      );
      
      await refreshStatus(); // Update available seats count
      return MentorGiftSeat.fromJson(data);
    } catch (e) {
      _error = 'Failed to create gift seat: $e';
      dev.log('SubscriptionService: $_error');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Revoke a gift seat
  Future<bool> revokeGiftSeat(String seatId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _api.revokeMentorGiftSeat(seatId);
      await refreshStatus();
      return true;
    } catch (e) {
      _error = 'Failed to revoke gift seat: $e';
      dev.log('SubscriptionService: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /* ── Gift Redemption (Apprentice Features) ────────────────────────── */

  /// Check if apprentice has been gifted premium by a mentor
  Future<Map<String, dynamic>?> checkGiftedStatus() async {
    try {
      return await _api.getApprenticeSubscriptionSource();
    } catch (e) {
      dev.log('SubscriptionService: Failed to check gifted status: $e');
      return null;
    }
  }

  /* ── Utility Methods ──────────────────────────────────────────────── */

  /// Check if a specific assessment is accessible
  /// Free assessments (master_trooth, spiritual_gifts) are always accessible
  bool canAccessAssessment(Map<String, dynamic> template) {
    // Check if template is marked as locked
    final isLocked = template['is_locked'] as bool? ?? true;
    
    // If not locked, anyone can access
    if (!isLocked) return true;
    
    // If locked, need premium
    return isPremium;
  }

  /// Clear subscription state (call on logout)
  void clear() {
    _status = SubscriptionStatus.free();
    _isInitialized = false;
    _error = null;
    notifyListeners();
  }
}
