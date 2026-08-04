import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../core/app_constants.dart';
import 'firebase_service.dart';

enum BillingState { idle, loading, ready, unavailable }

class VerifiedPlayPurchase {
  const VerifiedPlayPurchase({
    required this.productId,
    required this.purchaseToken,
    required this.tokenHash,
    required this.grant,
    required this.purchaseDetails,
    required this.recovered,
  });

  final String productId;
  final String purchaseToken;
  final String tokenHash;
  final Map<String, dynamic> grant;
  final PurchaseDetails purchaseDetails;
  final bool recovered;

  bool get removesAds => productId == 'remove_ads';
  int get coinAmount => AppConstants.playCoinGrants[productId] ?? 0;
}

typedef PersistVerifiedGrant =
    Future<bool> Function(VerifiedPlayPurchase purchase);

/// Google Play Billing is never treated as its own payment authority. Every
/// token is verified by Firebase, persisted into the local/cloud recovery
/// claim by [persistVerifiedGrant], marked delivered server-side, and only then
/// consumed or acknowledged with Google Play.
class BillingService extends ChangeNotifier {
  BillingService(this._firebase);

  final FirebaseService _firebase;
  InAppPurchase? _billingInstance;
  InAppPurchase get _billing => _billingInstance ??= InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  BillingState _state = BillingState.idle;
  Map<String, ProductDetails> _products = const {};
  Set<String> _notFoundProductIds = const {};
  final Set<String> _processingTokens = <String>{};
  final List<VerifiedPlayPurchase> _waitingForPersistence = [];
  Object? _lastError;
  PersistVerifiedGrant? persistVerifiedGrant;

  BillingState get state => _state;
  Map<String, ProductDetails> get products => Map.unmodifiable(_products);
  Set<String> get notFoundProductIds => Set.unmodifiable(_notFoundProductIds);
  Object? get lastError => _lastError;
  bool get ready => _state == BillingState.ready;
  bool get hasCompleteCatalog =>
      AppConstants.playProductIds.every(_products.containsKey);

  Future<bool> initializeAfterPrivacyAcceptance() async {
    if (ready) return true;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _state = BillingState.unavailable;
      notifyListeners();
      return false;
    }
    _state = BillingState.loading;
    _lastError = null;
    notifyListeners();
    try {
      _subscription ??= _billing.purchaseStream.listen(
        _onPurchaseUpdates,
        onError: (Object error) {
          _lastError = error;
          notifyListeners();
        },
      );
      if (!await _billing.isAvailable()) {
        _state = BillingState.unavailable;
        notifyListeners();
        return false;
      }
      final response = await _billing.queryProductDetails(
        AppConstants.playProductIds,
      );
      _products = {
        for (final product in response.productDetails) product.id: product,
      };
      _notFoundProductIds = response.notFoundIDs.toSet();
      _lastError = response.error;
      _state = BillingState.ready;
      notifyListeners();
      if (_firebase.signedIn) unawaited(recoverUnfinishedPurchases());
      return true;
    } catch (error) {
      _lastError = error;
      _state = BillingState.unavailable;
      notifyListeners();
      return false;
    }
  }

  Future<bool> buy(String productId) async {
    if (!ready) throw StateError('Google Play Billing is unavailable.');
    if (!_firebase.signedIn) {
      throw StateError('Sign in with Google before purchasing.');
    }
    final product = _products[productId];
    if (product == null || !AppConstants.playProductIds.contains(productId)) {
      throw StateError('This Play product is unavailable.');
    }
    final accountId = obfuscatedAccountId(
      FirebaseAuth.instance.currentUser!.uid,
    );
    final param = GooglePlayPurchaseParam(
      productDetails: product,
      applicationUserName: accountId,
    );
    if (productId == 'remove_ads') {
      return _billing.buyNonConsumable(purchaseParam: param);
    }
    return _billing.buyConsumable(purchaseParam: param, autoConsume: false);
  }

  Future<void> restorePurchases() async {
    if (!_firebase.signedIn) {
      throw StateError('Sign in with Google before restoring purchases.');
    }
    final accountId = obfuscatedAccountId(
      FirebaseAuth.instance.currentUser!.uid,
    );
    await _billing.restorePurchases(applicationUserName: accountId);
    await recoverUnfinishedPurchases();
  }

  Future<Map<String, dynamic>> restoreServerEntitlements() {
    return _firebase.getPlayEntitlements();
  }

  Future<void> recoverUnfinishedPurchases() async {
    if (!ready || !_firebase.signedIn) return;
    final addition = _billing
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final accountId = obfuscatedAccountId(
      FirebaseAuth.instance.currentUser!.uid,
    );
    final response = await addition.queryPastPurchases(
      applicationUserName: accountId,
    );
    if (response.error != null) _lastError = response.error;
    await _onPurchaseUpdates(response.pastPurchases, recovered: true);
  }

  Future<void> retryPendingDelivery() async {
    if (persistVerifiedGrant == null) return;
    final copy = List<VerifiedPlayPurchase>.from(_waitingForPersistence);
    _waitingForPersistence.clear();
    for (final purchase in copy) {
      await _persistThenFinish(purchase);
    }
  }

  Future<void> _onPurchaseUpdates(
    List<PurchaseDetails> updates, {
    bool recovered = false,
  }) async {
    for (final purchase in updates) {
      if (!AppConstants.playProductIds.contains(purchase.productID)) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          continue;
        case PurchaseStatus.error:
          _lastError = purchase.error;
          notifyListeners();
        case PurchaseStatus.canceled:
          continue;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyPurchase(
            purchase,
            recovered: recovered || purchase.status == PurchaseStatus.restored,
          );
      }
    }
  }

  Future<void> _verifyPurchase(
    PurchaseDetails purchase, {
    required bool recovered,
  }) async {
    if (!_firebase.signedIn) return;
    final token = purchase.verificationData.serverVerificationData;
    if (token.length < 16 || !_processingTokens.add(token)) return;
    try {
      final result = await _firebase.verifyPlayPurchase(
        productId: purchase.productID,
        purchaseToken: token,
      );
      if (result['valid'] != true ||
          result['productId'] != purchase.productID) {
        throw StateError('Firebase rejected the Play purchase.');
      }
      final delivered = result['delivered'] == true;
      final grantValue = result['grant'];
      final verified = VerifiedPlayPurchase(
        productId: purchase.productID,
        purchaseToken: token,
        tokenHash:
            (result['tokenHash'] as String?) ??
            sha256.convert(utf8.encode(token)).toString(),
        grant: grantValue is Map
            ? Map<String, dynamic>.from(grantValue)
            : const <String, dynamic>{},
        purchaseDetails: purchase,
        recovered: recovered,
      );
      if (delivered) {
        await _finishWithPlay(verified);
      } else {
        await _persistThenFinish(verified);
      }
    } catch (error) {
      _lastError = error;
      notifyListeners();
    } finally {
      _processingTokens.remove(token);
    }
  }

  Future<void> _persistThenFinish(VerifiedPlayPurchase purchase) async {
    final persist = persistVerifiedGrant;
    if (persist == null) {
      if (!_waitingForPersistence.any(
        (item) => item.tokenHash == purchase.tokenHash,
      )) {
        _waitingForPersistence.add(purchase);
      }
      return;
    }
    if (!await persist(purchase)) {
      if (!_waitingForPersistence.any(
        (item) => item.tokenHash == purchase.tokenHash,
      )) {
        _waitingForPersistence.add(purchase);
      }
      return;
    }
    await _firebase.markPlayPurchaseDelivered(
      productId: purchase.productId,
      purchaseToken: purchase.purchaseToken,
    );
    await _finishWithPlay(purchase);
  }

  Future<void> _finishWithPlay(VerifiedPlayPurchase purchase) async {
    if (purchase.productId != 'remove_ads') {
      final addition = _billing
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      await addition.consumePurchase(purchase.purchaseDetails);
    }
    if (purchase.purchaseDetails.pendingCompletePurchase) {
      await _billing.completePurchase(purchase.purchaseDetails);
    }
  }

  @visibleForTesting
  static String obfuscatedAccountId(String uid) {
    final hash = md5.convert(utf8.encode(uid)).toString();
    return '${hash.substring(0, 8)}-${hash.substring(8, 12)}-'
        '3${hash.substring(13, 16)}-8${hash.substring(17, 20)}-'
        '${hash.substring(20, 32)}';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
