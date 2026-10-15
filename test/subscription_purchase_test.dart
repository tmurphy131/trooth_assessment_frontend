import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:trooth_assessment/services/api_service.dart';
import 'package:trooth_assessment/services/subscription_service.dart';

Map<String, dynamic> _packageJson(String id, String productId, String offering) => {
      'identifier': id,
      'packageType': 'MONTHLY',
      'product': {
        'identifier': productId,
        'description': 'desc',
        'title': 'title',
        'price': 4.99,
        'priceString': r'$4.99',
        'currencyCode': 'USD',
      },
      'presentedOfferingContext': {'offeringIdentifier': offering},
    };

Package _package(String id, String productId, {String offering = 'default'}) =>
    Package.fromJson(_packageJson(id, productId, offering));

Map<String, dynamic> _entitlement(String id, String productId) => {
      'identifier': id,
      'isActive': true,
      'willRenew': true,
      'latestPurchaseDate': '2026-10-15T00:00:00Z',
      'originalPurchaseDate': '2026-10-15T00:00:00Z',
      'productIdentifier': productId,
      'isSandbox': true,
      'store': 'APP_STORE',
      'periodType': 'NORMAL',
      'ownershipType': 'PURCHASED',
      'expirationDate': '2026-11-15T00:00:00Z',
    };

PurchaseResult _result({Map<String, dynamic> active = const {}}) => PurchaseResult(
      CustomerInfo.fromJson({
        'entitlements': {'all': active, 'active': active},
        'allPurchaseDates': <String, dynamic>{},
        'activeSubscriptions': <String>[],
        'allPurchasedProductIdentifiers': <String>[],
        'nonSubscriptionTransactions': <dynamic>[],
        'firstSeen': '2026-10-15T00:00:00Z',
        'originalAppUserId': 'uid-1',
        'allExpirationDates': <String, dynamic>{},
        'requestDate': '2026-10-15T00:00:00Z',
      }),
      StoreTransaction.fromJson({
        'transactionIdentifier': 'tx-1',
        'productIdentifier': 'trooth_premium_monthly',
        'purchaseDate': '2026-10-15T00:00:00Z',
      }),
    );

PlatformException _storeError(PurchasesErrorCode code) =>
    PlatformException(code: code.index.toString(), message: 'store said no');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final api = ApiService();
  final service = SubscriptionService();
  final defaultPurchaseFn = SubscriptionService.purchaseFn;
  final requestedPaths = <String>[];
  late List<PurchaseParams> captured;

  setUp(() {
    api.setAuthForTesting(authorization: ({bool force = false}) async => null, canRetryAuth: () => false);
    api.clearCache();
    requestedPaths.clear();
    captured = [];
    api.httpClient = MockClient((req) async {
      requestedPaths.add(req.url.path);
      if (req.url.path.endsWith('/subscriptions/status')) {
        return http.Response(jsonEncode({'subscription_tier': 'premium', 'has_premium': true}), 200);
      }
      return http.Response(jsonEncode({'success': true}), 200);
    });
    service.clear();
  });

  tearDown(() {
    SubscriptionService.purchaseFn = defaultPurchaseFn;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('purchases_flutter'), null);
  });

  void stubPurchase(Future<PurchaseResult> Function() body) {
    SubscriptionService.purchaseFn = (params) {
      captured.add(params);
      return body();
    };
  }

  group('purchasePackage', () {
    final monthly = _package(r'$rc_monthly', 'trooth_premium_monthly');

    test('premium entitlement returns true and syncs to backend', () async {
      stubPurchase(() async => _result(active: {'premium': _entitlement('premium', 'trooth_premium_monthly')}));

      expect(await service.purchasePackage(monthly), isTrue);
      expect(requestedPaths, contains(endsWith('/subscriptions/restore')));
      expect(service.error, isNull);
      expect(service.isLoading, isFalse);
    });

    test('no entitlement returns false without syncing', () async {
      stubPurchase(() async => _result());

      expect(await service.purchasePackage(monthly), isFalse);
      expect(requestedPaths, isEmpty);
      expect(service.isLoading, isFalse);
    });

    test('user cancel returns false with no error', () async {
      stubPurchase(() async => throw _storeError(PurchasesErrorCode.purchaseCancelledError));

      expect(await service.purchasePackage(monthly), isFalse);
      expect(service.error, isNull);
      expect(service.isLoading, isFalse);
    });

    test('store error returns false and sets a Purchase failed error', () async {
      stubPurchase(() async => throw _storeError(PurchasesErrorCode.storeProblemError));

      expect(await service.purchasePackage(monthly), isFalse);
      expect(service.error, startsWith('Purchase failed:'));
      expect(service.isLoading, isFalse);
    });

    test('passes the given package to PurchaseParams', () async {
      stubPurchase(() async => _result());

      await service.purchasePackage(monthly);
      expect(captured, hasLength(1));
      expect(captured.single.package?.identifier, r'$rc_monthly');
      expect(captured.single.package?.storeProduct.identifier, 'trooth_premium_monthly');
    });
  });

  group('purchaseGiftSeat', () {
    test('passes the mentor_gift_seats package to PurchaseParams', () async {
      final gift = _packageJson(r'$rc_monthly', 'trooth_gift_seat_monthly', 'mentor_gift_seats');
      final premium = _packageJson(r'$rc_monthly', 'trooth_premium_monthly', 'default');
      Map<String, dynamic> offering(String id, Map<String, dynamic> pkg) => {
            'identifier': id,
            'serverDescription': id,
            'metadata': <String, Object>{},
            'availablePackages': [pkg],
            'monthly': pkg,
          };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('purchases_flutter'), (call) async {
        if (call.method == 'getOfferings') {
          return {
            'current': offering('default', premium),
            'all': {'default': offering('default', premium), 'mentor_gift_seats': offering('mentor_gift_seats', gift)},
          };
        }
        return null;
      });
      // Cancel after capturing, so the test stops before the webhook wait.
      stubPurchase(() async => throw _storeError(PurchasesErrorCode.purchaseCancelledError));

      expect(await service.purchaseGiftSeat(apprenticeEmail: 'a@example.com'), isNull);
      expect(captured, hasLength(1));
      expect(captured.single.package?.storeProduct.identifier, 'trooth_gift_seat_monthly');
      expect(captured.single.package?.presentedOfferingContext.offeringIdentifier, 'mentor_gift_seats');
      expect(service.error, isNull);
      expect(service.isLoading, isFalse);
    });
  });
}
