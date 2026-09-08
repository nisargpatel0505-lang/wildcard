import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildcard/app/app_controller.dart';
import 'package:wildcard/app/screens/settings_screen.dart';
import 'package:wildcard/core/app_constants.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/services/firebase_service.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

class _CloudUser implements User {
  @override
  String get uid => 'existing-player';
  @override
  String? get displayName => 'Existing player';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnavailableCloud extends FirebaseService {
  _UnavailableCloud(this.failure, {this.initializeSucceeds = true});
  final Object failure;
  final bool initializeSucceeds;
  int reads = 0;
  int writes = 0;
  int signOutCalls = 0;

  @override
  bool get initialized => initializeSucceeds;
  @override
  bool get signedIn => true;
  @override
  User? get user => _CloudUser();
  @override
  Object? get initializationError => initializeSucceeds ? null : failure;
  @override
  Future<bool> initializeAfterPrivacyAcceptance() async => initializeSucceeds;
  @override
  Future<Map<String, dynamic>> readSecureCloudSave() async {
    reads++;
    throw failure;
  }

  @override
  Future<Map<String, dynamic>> writeSecureCloudSave({
    required String accountJson,
    required String runJson,
    required int clientSavedAt,
    required int expectedProgressVersion,
    required int billingAdjustmentApplied,
  }) async {
    writes++;
    throw StateError('A failed cloud read must never be followed by an upload');
  }

  @override
  Future<void> signOut() async => signOutCalls++;
}

const _run = '{"v":1,"phase":"game","hand":[],"stage":7,"rngSeed":123}';

void _seedSave({bool privacyAccepted = true}) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    AppConstants.legacyAccountKey: AccountState(
      coins: 4204,
      noAds: true,
      bestHeat: 21,
      bestClearedHeat: 20,
      tutorialDone: true,
      starterGiftClaimed: true,
      musicOn: false,
      muted: true,
    ).encode(),
    AppConstants.legacyRunKey: _run,
    AppConstants.cloudOwnerKey: 'existing-player',
    AppConstants.migrationMarkerKey: true,
    if (privacyAccepted)
      AppConstants.privacyAcceptedKey: jsonEncode(<String, Object?>{
        'version': AppConstants.privacyPolicyVersion,
        'acceptedAt': 1788500000000,
      }),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    // Cloud is faked; other Android SDKs stay unavailable in this unit test.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    _seedSave();
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final code in <String>['unauthenticated', 'unavailable']) {
    test(
      'automatic $code cloud failure leaves a playable local account',
      () async {
        final error = FirebaseFunctionsException(
          code: code,
          message: 'Rejected',
        );
        final cloud = _UnavailableCloud(error);
        final app = await AppController.bootstrap(firebaseService: cloud);
        addTearDown(app.dispose);
        // This joins the same unawaited startup operation launched by bootstrap.
        await app.startConsentGatedServices();
        expect(app.bootState, AppBootState.ready);
        expect(app.cloudState, CloudLinkState.offline);
        expect(
          app.cloudStatus,
          'Phone save safe — cloud connection unavailable',
        );
        expect(app.cloudError, same(error));
        expect(app.signedIn, isTrue);
        expect(app.account.coins, 4204);
        expect(app.account.noAds, isTrue);
        expect(app.account.bestHeat, 21);
        expect(app.activeRunJson, _run);
        expect(cloud.reads, 1);
        expect(cloud.writes, 0);
        expect(cloud.signOutCalls, 0);
        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.getString(AppConstants.cloudOwnerKey),
          'existing-player',
        );
        expect(preferences.getString(AppConstants.legacyRunKey), _run);
        expect(
          AccountState.decode(
            preferences.getString(AppConstants.legacyAccountKey)!,
          ).coins,
          4204,
        );

        // An explicit retry still raises the error for the existing Settings UI.
        await expectLater(
          app.reconcileCloudAccount(announce: true),
          throwsA(same(error)),
        );
        expect(cloud.reads, 2);
        expect(cloud.writes, 0);
        expect(app.account.coins, 4204);
        expect(app.activeRunJson, _run);
      },
    );
  }

  test(
    'unavailable Firebase initialization reports offline without reading cloud',
    () async {
      final cloud = _UnavailableCloud(
        StateError('SDK unavailable'),
        initializeSucceeds: false,
      );
      final app = await AppController.bootstrap(firebaseService: cloud);
      addTearDown(app.dispose);
      await app.startConsentGatedServices();
      expect(app.bootState, AppBootState.ready);
      expect(app.cloudState, CloudLinkState.offline);
      expect(app.account.coins, 4204);
      expect(app.activeRunJson, _run);
      expect(cloud.reads, 0);
      expect(cloud.signOutCalls, 0);
    },
  );

  testWidgets(
    'Back Up Now retries the cloud read and surfaces rejection without losing progress',
    (tester) async {
      debugDefaultTargetPlatformOverride = null;
      _seedSave(privacyAccepted: false);
      PackageInfo.setMockInitialValues(
        appName: 'WILDCARD',
        packageName: 'com.nisarg.wildcard',
        version: '9.1.0',
        buildNumber: '74',
        buildSignature: 'test',
      );
      final cloud = _UnavailableCloud(
        FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'Rejected',
        ),
      );
      final app = await AppController.bootstrap(firebaseService: cloud);
      addTearDown(app.dispose);
      app.cloudState = CloudLinkState.offline;
      app.cloudStatus = 'Phone save safe — cloud connection unavailable';
      await tester.pumpWidget(
        MaterialApp(
          theme: WildcardTheme.build(),
          home: SettingsScreen(controller: app),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('BACK UP NOW'),
        350,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('BACK UP NOW'));
      await tester.pumpAndSettle();
      expect(cloud.reads, 1);
      expect(cloud.writes, 0);
      expect(cloud.signOutCalls, 0);
      expect(app.account.coins, 4204);
      expect(app.activeRunJson, _run);
      expect(tester.takeException(), isNull);
    },
  );
}
