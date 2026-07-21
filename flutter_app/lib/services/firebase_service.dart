import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/app_constants.dart';
import '../firebase_options.dart';

class FirebaseService extends ChangeNotifier {
  bool _initializing = false;
  bool _initialized = false;
  Object? _initializationError;
  GoogleSignIn? _googleSignIn;
  FirebaseFunctions? _functions;
  StreamSubscription<User?>? _authSubscription;

  bool get initialized => _initialized;
  bool get initializing => _initializing;
  Object? get initializationError => _initializationError;
  User? get user => _initialized ? FirebaseAuth.instance.currentUser : null;
  bool get signedIn => user != null;

  Future<bool> initializeAfterPrivacyAcceptance() async {
    if (_initialized) return true;
    if (_initializing) {
      while (_initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return _initialized;
    }

    _initializing = true;
    _initializationError = null;
    notifyListeners();
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        throw UnsupportedError(
          'The first Flutter release is configured for Android Firebase only.',
        );
      }

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      try {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
        );
      } on FirebaseException {
        // Local guest play must remain available if a sideload cannot obtain an
        // App Check token. Protected callables will still fail closed.
      }

      _functions = FirebaseFunctions.instanceFor(
        region: AppConstants.firebaseRegion,
      );
      _googleSignIn = GoogleSignIn.instance;
      await _googleSignIn!.initialize();
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
        notifyListeners();
      });
      _initialized = true;
      return true;
    } catch (error) {
      _initializationError = error;
      return false;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    _requireInitialized();
    final account = await _googleSignIn!.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google did not return an ID token.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    await FirebaseAuth.instance.signOut();
    try {
      await _googleSignIn?.disconnect();
    } catch (_) {
      // Firebase sign-out is authoritative; chooser cleanup can retry later.
    }
  }

  Future<Map<String, dynamic>> readSecureCloudSave() =>
      _call('readSecureCloudSave');

  Future<Map<String, dynamic>> writeSecureCloudSave({
    required String accountJson,
    required String runJson,
    required int clientSavedAt,
    required int expectedProgressVersion,
    required int billingAdjustmentApplied,
  }) {
    if (accountJson.length > 150000 || runJson.length > 150000) {
      throw const FormatException('Cloud save is too large');
    }
    return _call(
      'writeSecureCloudSave',
      data: <String, Object>{
        'accountJson': accountJson,
        'runJson': runJson,
        'clientSavedAt': clientSavedAt,
        'expectedProgressVersion': expectedProgressVersion,
        'billingAdjustmentApplied': billingAdjustmentApplied,
      },
    );
  }

  Future<Map<String, dynamic>> submitDailyScore({
    required String name,
    required int score,
    required String idempotencyKey,
  }) {
    final cleanName = name.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
    if (cleanName.isEmpty ||
        cleanName.length > 8 ||
        score <= 0 ||
        score > 10000000) {
      throw const FormatException('Invalid Daily Board submission');
    }
    // Run claim IDs contain ':' separators, while the protected callable only
    // accepts URL-safe idempotency keys. Hashing keeps retries deterministic,
    // meets the backend's 16–80 character contract and avoids exposing a local
    // run identifier outside the device.
    final submissionKey = dailySubmissionKey(idempotencyKey);
    return _call(
      'submitDailyScore',
      data: <String, Object>{
        'name': cleanName,
        'score': score,
        'idempotencyKey': submissionKey,
      },
      limitedUseAppCheckToken: true,
    );
  }

  static String dailySubmissionKey(String claimId) {
    final normalized = claimId.trim();
    if (normalized.isEmpty || normalized.length > 96) {
      throw const FormatException('Invalid Daily Board claim');
    }
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  Future<Map<String, dynamic>> deleteMyAccount() => _call(
    'deleteMyAccount',
    data: const <String, Object>{'confirm': 'DELETE'},
    limitedUseAppCheckToken: true,
  );

  Future<Map<String, dynamic>> verifyPlayPurchase({
    required String productId,
    required String purchaseToken,
  }) => _purchaseCall('verifyPlayPurchase', productId, purchaseToken);

  Future<Map<String, dynamic>> markPlayPurchaseDelivered({
    required String productId,
    required String purchaseToken,
  }) => _purchaseCall('markPlayPurchaseDelivered', productId, purchaseToken);

  Future<Map<String, dynamic>> getPlayEntitlements() =>
      _call('getPlayEntitlements');

  Future<Map<String, dynamic>> _purchaseCall(
    String callable,
    String productId,
    String purchaseToken,
  ) {
    if (!AppConstants.playProductIds.contains(productId) ||
        purchaseToken.length < 16 ||
        purchaseToken.length > 4096) {
      throw const FormatException('Invalid Play purchase');
    }
    return _call(
      callable,
      data: <String, Object>{
        'packageName': AppConstants.androidPackageName,
        'productId': productId,
        'purchaseToken': purchaseToken,
      },
    );
  }

  Future<Map<String, dynamic>> _call(
    String name, {
    Map<String, Object> data = const {},
    bool limitedUseAppCheckToken = false,
  }) async {
    _requireSignedIn();
    final callable = _functions!.httpsCallable(
      name,
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 30),
        limitedUseAppCheckToken: limitedUseAppCheckToken,
      ),
    );
    final result = await callable.call<Map<String, dynamic>>(data);
    return Map<String, dynamic>.from(result.data);
  }

  void _requireInitialized() {
    if (!_initialized || _functions == null || _googleSignIn == null) {
      throw StateError('Firebase has not been initialized.');
    }
  }

  void _requireSignedIn() {
    _requireInitialized();
    if (FirebaseAuth.instance.currentUser == null) {
      throw StateError('Sign in with Google first.');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
