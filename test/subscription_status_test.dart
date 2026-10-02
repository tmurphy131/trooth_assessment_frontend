import 'package:flutter_test/flutter_test.dart';
import 'package:trooth_assessment/services/subscription_service.dart';

void main() {
  group('SubscriptionStatus.fromJson', () {
    test('defaults to free when fields are missing', () {
      final s = SubscriptionStatus.fromJson({});
      expect(s.tier, SubscriptionTier.free);
      expect(s.isPremium, isFalse);
      expect(s.platform, isNull);
      expect(s.canAddApprentices, isTrue);
      expect(s.isGrandfathered, isFalse);
    });

    test('parses a premium mentor', () {
      final s = SubscriptionStatus.fromJson({
        'subscription_tier': 'mentor_premium',
        'has_premium': true,
        'subscription_platform': 'apple',
        'subscription_expires_at': '2030-01-01T00:00:00Z',
      });
      expect(s.tier, SubscriptionTier.mentorPremium);
      expect(s.isPremium, isTrue);
      expect(s.platform, SubscriptionPlatform.apple);
      expect(s.expiresAt, DateTime.utc(2030));
    });

    test('falls back to is_premium when has_premium is absent', () {
      final s = SubscriptionStatus.fromJson({'is_premium': true});
      expect(s.isPremium, isTrue);
    });

    test('parses gifted and admin-granted tiers', () {
      expect(SubscriptionStatus.fromJson({'subscription_tier': 'mentor_gifted'}).tier, SubscriptionTier.mentorGifted);
      expect(
        SubscriptionStatus.fromJson({'subscription_platform': 'admin_granted'}).platform,
        SubscriptionPlatform.adminGranted,
      );
    });

    test('unknown tier and platform degrade safely', () {
      final s = SubscriptionStatus.fromJson({'subscription_tier': 'platinum', 'subscription_platform': 'web'});
      expect(s.tier, SubscriptionTier.free);
      expect(s.platform, isNull);
    });

    test('bad expiry date does not throw', () {
      expect(SubscriptionStatus.fromJson({'subscription_expires_at': 'not a date'}).expiresAt, isNull);
    });
  });

  group('canAccessApprentice', () {
    test('free mentor sees only the first apprentice', () {
      final s = SubscriptionStatus.fromJson({'subscription_tier': 'free'});
      expect(s.canAccessApprentice(0), isTrue);
      expect(s.canAccessApprentice(1), isFalse);
    });

    test('premium mentor sees all apprentices', () {
      final s = SubscriptionStatus.fromJson({'subscription_tier': 'mentor_premium', 'has_premium': true});
      expect(s.canAccessApprentice(5), isTrue);
    });

    test('grandfathered free mentor sees all apprentices', () {
      final s = SubscriptionStatus.fromJson({'is_grandfathered': true});
      expect(s.canAccessApprentice(5), isTrue);
    });
  });
}
