import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:wildcard/app/app_controller.dart';
import 'package:wildcard/core/app_constants.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/services/billing_service.dart';
import 'package:wildcard/services/firebase_service.dart';

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cloud extends FirebaseService {
  String uid = 'player';
  int version = 7;
  int serverTime = 700;
  String raw = _account().encode();
  String run = '';
  int clientStamp = 0;
  bool noAds = false;
  bool loseNextResponse = false;
  Completer<void>? hold;
  Completer<void>? entered;
  VoidCallback? beforeReturningFulfillment;
  final delivered = <String>{};
  final metadata = <String, dynamic>{};
  int calls = 0;
  int active = 0;
  int maxActive = 0;
  int signOutCalls = 0;
  @override
  Future<void> signOut() async {
    signOutCalls++;
    uid = 'signed-out';
  }

  _Cloud restartClient() => _Cloud()
    ..uid = uid
    ..version = version
    ..serverTime = serverTime
    ..raw = raw
    ..run = run
    ..clientStamp = clientStamp
    ..noAds = noAds
    ..delivered.addAll(delivered)
    ..metadata.addAll(metadata);
  @override
  bool get signedIn => true;
  @override
  User? get user => _User(uid);
  Map<String, dynamic> snapshot() => {
    'exists': true,
    'fromCache': false,
    'accountJson': raw,
    'runJson': run,
    'progressVersion': version,
    'saveVersion': version,
    'serverUpdatedAt': serverTime,
    'clientSavedAt': clientStamp,
    'billingAdjustmentApplied': 0,
    'billingAdjustmentTotal': 0,
    ...metadata,
  };
  @override
  Future<Map<String, dynamic>> readSecureCloudSave() async => snapshot();
  @override
  Future<Map<String, dynamic>> writeSecureCloudSave({
    required String accountJson,
    required String runJson,
    required int clientSavedAt,
    required int expectedProgressVersion,
    required int billingAdjustmentApplied,
  }) async {
    if (expectedProgressVersion != version) {
      throw StateError('stale cloud version');
    }
    final account = jsonDecode(accountJson) as Map<String, dynamic>;
    account.remove('purchaseClaims');
    account.remove('noAds');
    raw = jsonEncode(account);
    run = runJson;
    clientStamp = clientSavedAt;
    version++;
    serverTime += 100;
    metadata.clear();
    return snapshot();
  }

  @override
  Future<Map<String, dynamic>> fulfillPlayPurchase({
    required String productId,
    required String purchaseToken,
    required int expectedProgressVersion,
  }) async {
    calls++;
    active++;
    if (active > maxActive) maxActive = active;
    entered?.complete();
    entered = null;
    await hold?.future;
    if (expectedProgressVersion != version) {
      throw StateError('stale fulfillment');
    }
    final already = delivered.contains(purchaseToken);
    final delta = already ? 0 : AppConstants.playCoinGrants[productId] ?? 0;
    if (!already) {
      final base = version;
      final account = jsonDecode(raw) as Map<String, dynamic>;
      account['coins'] = (account['coins'] as int) + delta;
      raw = jsonEncode(account);
      version++;
      serverTime += 100;
      delivered.add(purchaseToken);
      metadata.addAll({
        'lastBillingTokenHash': _hash(purchaseToken),
        'lastBillingCoinDelta': delta,
        'lastBillingBaseProgressVersion': base,
      });
    }
    if (productId == 'remove_ads') noAds = true;
    final result = {
      'fulfilled': true,
      'alreadyDelivered': already,
      'coinDelta': delta,
      if (productId == 'remove_ads') 'noAds': true,
      ...snapshot(),
    };
    beforeReturningFulfillment?.call();
    active--;
    if (loseNextResponse) {
      loseNextResponse = false;
      throw StateError('response lost after server commit');
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> getPlayEntitlements() async => {
    'authoritative': true,
    'noAds': noAds,
    'purchases': <Object>[],
    'billing': {
      'coinAdjustmentTotal': 0,
      'billingAdjustmentApplied': 99,
      'progressVersion': version + 99,
    },
  };
}

class _FailingStore extends InMemorySharedPreferencesStore {
  _FailingStore(super.data) : super.withData();
  bool failAccount = false;
  String? rejectKey;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if ((failAccount && key == 'flutter.${AppConstants.legacyAccountKey}') ||
        key == rejectKey) {
      return false;
    }
    return super.setValue(type, key, value);
  }
}

AccountState _account({bool noAds = false}) => AccountState(
  coins: 100,
  noAds: noAds,
  tutorialDone: true,
  starterGiftClaimed: true,
  musicOn: false,
  muted: true,
);
Map<String, Object> _seed({bool noAds = false}) => {
  AppConstants.legacyAccountKey: _account(noAds: noAds).encode(),
  AppConstants.cloudOwnerKey: 'player',
  AppConstants.migrationMarkerKey: true,
};
String _hash(String token) =>
    (token == 'second-purchase-token' ? 'b' : 'a') * 64;
VerifiedPlayPurchase _purchase({
  String id = 'coins_250',
  String token = 'first-purchase-token',
}) => VerifiedPlayPurchase(
  productId: id,
  purchaseToken: token,
  tokenHash: _hash(token),
  grant: const {},
  recovered: false,
  purchaseDetails: PurchaseDetails(
    productID: id,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: token,
      source: 'google_play',
    ),
    transactionDate: null,
    status: PurchaseStatus.purchased,
  ),
);
Future<AppController> _app(_Cloud cloud) async {
  final app = await AppController.bootstrap(firebaseService: cloud);
  app.cloudState = CloudLinkState.ready;
  app.cloudProgressVersion = cloud.version;
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues(_seed());
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'authoritative Remove Ads revocation applies without advancing save cursors',
    () async {
      SharedPreferences.setMockInitialValues(_seed(noAds: true));
      final app = await _app(_Cloud());
      addTearDown(app.dispose);
      await app.restorePlayEntitlements();
      expect(app.account.noAds, false);
      expect(app.ads.forcedAdsRemoved, false);
      expect(app.cloudProgressVersion, 7);
      expect(app.billingAdjustmentApplied, 0);
    },
  );

  test('startup/foreign owner cannot mutate a wallet for a receipt', () async {
    final cloud = _Cloud();
    final app = await _app(cloud);
    addTearDown(app.dispose);
    app.cloudState = CloudLinkState.connecting;
    expect(await app.billing.persistVerifiedGrant!(_purchase()), false);
    app.cloudState = CloudLinkState.ready;
    cloud.uid = 'other';
    expect(await app.billing.persistVerifiedGrant!(_purchase()), false);
    expect(app.account.coins, 100);
    expect(cloud.calls, 0);
  });

  test(
    'atomic grant preserves earnings made while fulfillment is in flight',
    () async {
      final cloud = _Cloud()
        ..hold = Completer<void>()
        ..entered = Completer<void>();
      final app = await _app(cloud);
      addTearDown(app.dispose);
      final entered = cloud.entered!.future;
      final pending = app.billing.persistVerifiedGrant!(_purchase());
      await entered;
      await app.mutateAccount((a) => a.coins += 20, syncCloud: false);
      expect(await app.cloudSaveNow(), false);
      cloud.hold!.complete();
      expect(await pending, true);
      expect(app.account.coins, 370);
      expect(await app.cloudSaveNow(), true);
      expect((jsonDecode(cloud.raw) as Map)['coins'], 370);
    },
  );

  test(
    'different receipts serialize and repeats never add the same coins again',
    () async {
      final cloud = _Cloud();
      final app = await _app(cloud);
      addTearDown(app.dispose);
      expect(
        await Future.wait([
          app.billing.persistVerifiedGrant!(_purchase()),
          app.billing.persistVerifiedGrant!(
            _purchase(token: 'second-purchase-token'),
          ),
        ]),
        [true, true],
      );
      expect(cloud.maxActive, 1);
      expect(app.account.coins, 600);
      expect(await app.billing.persistVerifiedGrant!(_purchase()), true);
      expect(app.account.coins, 600);
    },
  );

  for (final id in ['coins_250', 'remove_ads']) {
    test(
      'lost $id response recovers after restart without erasing local earnings',
      () async {
        var cloud = _Cloud()..loseNextResponse = true;
        var app = await _app(cloud);
        await expectLater(
          app.billing.persistVerifiedGrant!(_purchase(id: id)),
          throwsStateError,
        );
        await app.mutateAccount((a) => a.coins += 20, syncCloud: false);
        expect(await app.cloudSaveNow(), false);
        app.dispose();
        cloud = cloud.restartClient();
        app = await _app(cloud);
        addTearDown(app.dispose);
        await app.reconcileCloudAccount(announce: false);
        expect(app.account.coins, id == 'coins_250' ? 370 : 120);
        if (id == 'remove_ads') {
          expect(app.account.noAds, true);
          expect(app.ads.forcedAdsRemoved, true);
        }
        expect(
          await app.billing.persistVerifiedGrant!(_purchase(id: id)),
          true,
        );
        expect(app.account.coins, id == 'coins_250' ? 370 : 120);
      },
    );
  }

  test(
    'ambiguous other-device change keeps the phone save and recovery journal',
    () async {
      final cloud = _Cloud()..loseNextResponse = true;
      final app = await _app(cloud);
      addTearDown(app.dispose);
      await expectLater(
        app.billing.persistVerifiedGrant!(_purchase()),
        throwsStateError,
      );
      await app.mutateAccount((a) => a.coins += 20, syncCloud: false);
      cloud.version++;
      cloud.metadata.clear();
      await expectLater(
        app.reconcileCloudAccount(announce: false),
        throwsStateError,
      );
      expect(app.account.coins, 120);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('flutter_billing_recovery_v2:player'), true);
    },
  );

  test(
    'local grant disk failure leaves server money recoverable and unclaimed locally',
    () async {
      final initial = {
        for (final entry in _seed().entries)
          'flutter.${entry.key}': entry.value,
      };
      final store = _FailingStore(initial);
      SharedPreferencesStorePlatform.instance = store;
      final cloud = _Cloud()
        ..beforeReturningFulfillment = () => store.failAccount = true;
      final app = await _app(cloud);
      addTearDown(app.dispose);
      await expectLater(
        app.billing.persistVerifiedGrant!(_purchase()),
        throwsStateError,
      );
      expect(app.account.coins, 100);
      expect(app.account.purchaseClaims, isEmpty);
      expect((jsonDecode(cloud.raw) as Map)['coins'], 350);
      store.failAccount = false;
      cloud.beforeReturningFulfillment = null;
      await app.reconcileCloudAccount(announce: false);
      expect(app.account.coins, 350);
    },
  );

  for (final id in ['coins_250', 'remove_ads']) {
    test(
      'durable $id grant survives later cursor failure without double delivery',
      () async {
        final store = _FailingStore({
          for (final entry in _seed().entries)
            'flutter.${entry.key}': entry.value,
        });
        SharedPreferencesStorePlatform.instance = store;
        final cloud = _Cloud()
          ..beforeReturningFulfillment = () {
            store.rejectKey = 'flutter.flutter_cloud_v1:player:progressVersion';
          };
        final app = await _app(cloud);
        addTearDown(app.dispose);
        await expectLater(
          app.billing.persistVerifiedGrant!(_purchase(id: id)),
          throwsStateError,
        );
        expect(app.account.coins, id == 'coins_250' ? 350 : 100);
        expect(
          app.account.purchaseClaims,
          contains(_hash('first-purchase-token')),
        );
        if (id == 'remove_ads') expect(app.ads.forcedAdsRemoved, true);
        store.rejectKey = null;
        cloud.beforeReturningFulfillment = null;
        await app.reconcileCloudAccount(announce: false);
        expect(app.account.coins, id == 'coins_250' ? 350 : 100);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('flutter_billing_recovery_v2:player'), false);
      },
    );
  }

  test(
    'sign-out waits until in-flight fulfillment is durably installed',
    () async {
      final cloud = _Cloud()
        ..hold = Completer<void>()
        ..entered = Completer<void>();
      final app = await _app(cloud);
      addTearDown(app.dispose);
      final entered = cloud.entered!.future;
      final delivery = app.billing.persistVerifiedGrant!(_purchase());
      await entered;
      final signingOut = app.signOut();
      final lateDelivery = app.billing.persistVerifiedGrant!(
        _purchase(token: 'late-restore-token'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cloud.signOutCalls, 0);
      cloud.hold!.complete();
      expect(await delivery, true);
      expect(await lateDelivery, false);
      await signingOut;
      expect(cloud.signOutCalls, 1);
      expect(app.account.coins, 350);
    },
  );
}
