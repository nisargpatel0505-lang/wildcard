import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:wildcard/app/app_controller.dart';
import 'package:wildcard/core/app_constants.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/domain/astra_journey.dart';
import 'package:wildcard/domain/astra_progression.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/progression_catalog.dart';
import 'package:wildcard/game/game_controller.dart';
import 'package:wildcard/game/game_models.dart';
import 'package:wildcard/services/local_save_repository.dart';

const _migrationChannel = MethodChannel('com.nisarg.wildcard/save_migration');
const _purchaseHash =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

class _FailingWriteStore extends InMemorySharedPreferencesStore {
  _FailingWriteStore(super.data) : super.withData();

  String? rejectNextKey;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == rejectNextKey) {
      rejectNextKey = null;
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

// This fixture uses the official v8.5.3 wire keys, independently of current
// AccountState.encode(). Coin balance includes an already-delivered coin pack.
Map<String, Object?> _officialAccount() => <String, Object?>{
  '_savedAt': 1788600000000,
  'coins': 1876,
  'unlocked': <String>[...tutorialStarterJokerIds, 'wire', 'allin'],
  'tutorialDone': true,
  'starterGiftClaimed': true,
  'firstRunStarted': true,
  'firstLossCoached': true,
  'tutorialChestClaimed': true,
  'bestHeat': 7,
  'bestClearedHeat': 6,
  'bestScore': 8192,
  'topRuns': <Object?>[
    <String, Object?>{'score': 8192, 'heat': 7},
  ],
  'noAds': true,
  'purchaseClaims': <String, Object?>{
    _purchaseHash: <String, Object?>{
      'productId': 'coins_600',
      'claimedAt': 1788500000000,
    },
  },
  'rewardClaims': <String>['official-run-001:heat-6'],
  'cosmeticsOwned': <String>['felt_royal', 'theme_cosmic', 'sly_shadow'],
  'equipped': <String, Object?>{
    'table': 'felt_royal',
    'theme': 'theme_cosmic',
    'sly': 'sly_shadow',
  },
  'achievements': <String, Object?>{'first_win': 1},
  'achievementClaimed': <String, Object?>{'first_win': 1},
  'stats': <String, Object?>{'runs': 9, 'wins': 0, 'gWins': 0, 'hands': 34},
  'speed': 'normal',
  'pacingVersion': 2,
  'musicOn': false,
  'muted': true,
  'serverFutureMetadata': <String, Object?>{'revision': 4},
};

String _officialRun() {
  const ranks = <String>[
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    'J',
    'Q',
    'K',
    'A',
  ];
  const suits = <String>['♠', '♥', '♣', '♦'];
  final cards = <Map<String, Object?>>[
    for (var suit = 0; suit < suits.length; suit++)
      for (var rank = 0; rank < ranks.length; rank++)
        <String, Object?>{
          'rank': ranks[rank],
          'value': rank == 12 ? 15 : rank + 2,
          'suit': suits[suit],
          'red': suit == 1 || suit == 3,
          'uid': 'official-card-$suit-$rank',
        },
  ];
  return jsonEncode(<String, Object?>{
    'v': 1,
    '_savedAt': 1788600000000,
    'phase': 'game',
    'runId': 'official-run-001',
    'telemetryMode': 'normal',
    'difficulty': 'medium',
    'rngSeed': 9931,
    'rngCounters': <String, int>{
      'deck': 153,
      'shop': 12,
      'mods': 2,
      'luck': 9,
      'boss': 0,
    },
    'stage': 7,
    'stagesCleared': 6,
    'stageScore': 120,
    'handsLeft': 3,
    'discardsLeft': 2,
    'runCoins': 27,
    'jokerIds': <String>['copper', 'polish', 'wire'],
    'cards': cards,
    'hand': <Object?>[
      <String, Object?>{...cards[12], 'selected': true},
      ...cards.sublist(0, 8),
    ],
    'deck': cards
        .where(
          (card) =>
              card['uid'] != cards[12]['uid'] &&
              !cards.sublist(0, 8).any((held) => held['uid'] == card['uid']),
        )
        .toList(),
    'heatDeck': cards,
    'totalScore': 4800,
    'accountEarned': 21,
    'stake': 50,
    'stakePaid': false,
    'startBoostJoker': 'polish',
    'startBoostCost': 30,
    'supplyPurchaseLedger': <Object?>[
      <String, Object?>{'id': 'scalpel', 'stage': 3, 'step': 5},
    ],
    'futureRunMetadata': <String, Object?>{'preserve': true},
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_migrationChannel, null);
  });

  test(
    'official identity enables Astra experience without offline isolation',
    () {
      expect(astraEnabled, isFalse);
      expect(astraExperienceEnabled, isTrue);
      expect(AppConstants.androidPackageName, 'com.nisarg.wildcard');
    },
  );

  test(
    'official account upgrade preserves earned and paid progression',
    () async {
      final original = _officialAccount();
      final runJson = _officialRun();
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.legacyAccountKey: jsonEncode(original),
        AppConstants.legacyRunKey: runJson,
        AppConstants.migrationMarkerKey: true,
        AppConstants.cloudOwnerKey: 'official-player-uid',
      });
      final app = await AppController.bootstrap(releaseBuild: true);
      addTearDown(app.dispose);
      await app.persistAccount();

      final preferences = await SharedPreferences.getInstance();
      final reloaded = AccountState.decode(
        preferences.getString(AppConstants.legacyAccountKey)!,
      );
      expect(reloaded.coins, 1876);
      expect(reloaded.noAds, isTrue);
      expect(reloaded.purchaseClaims[_purchaseHash]!.productId, 'coins_600');
      expect(reloaded.rewardClaims, contains('official-run-001:heat-6'));
      expect(
        reloaded.unlockedJokerIds,
        containsAll(original['unlocked']! as List),
      );
      expect(
        reloaded.cosmeticsOwned,
        containsAll(original['cosmeticsOwned']! as List),
      );
      expect(reloaded.equipped.toJson(), original['equipped']);
      expect(reloaded.tutorialDone, isTrue);
      expect(reloaded.starterGiftClaimed, isTrue);
      expect(reloaded.tutorialChestClaimed, isTrue);
      expect(reloaded.bestScore, 8192);
      expect(reloaded.bestClearedHeat, 6);
      expect(reloaded.stats.runs, 9);
      expect(reloaded.stats.hands, 34);
      expect(reloaded.achievementClaimed['first_win'], 1);
      expect(reloaded.unknownFields['serverFutureMetadata'], <String, Object?>{
        'revision': 4,
      });
      expect(
        preferences.getString(AppConstants.cloudOwnerKey),
        'official-player-uid',
      );
      expect(app.activeRunJson, runJson);
      expect(preferences.getString(AppConstants.legacyRunKey), runJson);
    },
  );

  test(
    'new Journey rewards are once-only across an official upgrade and reload',
    () async {
      final original = _officialAccount()
        ..[astraJourneyClaimKey] = <String>['first_heat'];
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.legacyAccountKey: jsonEncode(original),
        AppConstants.migrationMarkerKey: true,
      });
      final app = await AppController.bootstrap(releaseBuild: true);
      addTearDown(app.dispose);
      expect(await app.claimAstraMilestone('first_heat'), 0);
      final awards = await Future.wait(<Future<int>>[
        app.claimAstraMilestone('first_build'),
        app.claimAstraMilestone('first_build'),
      ]);
      expect(awards.reduce((a, b) => a + b), 40);
      expect(app.account.coins, 1916);

      final restored = await AppController.bootstrap(releaseBuild: true);
      addTearDown(restored.dispose);
      expect(await restored.claimAstraMilestone('first_build'), 0);
      expect(restored.account.coins, 1916);
      expect(
        restored.account.unknownFields[astraJourneyClaimKey],
        unorderedEquals(<String>['first_heat', 'first_build']),
      );
      expect(restored.account.noAds, isTrue);
      expect(restored.account.purchaseClaims, contains(_purchaseHash));
    },
  );

  test(
    'pre-Astra active run resumes with cards, RNG and paid commitments intact',
    () async {
      final raw = jsonDecode(_officialRun()) as Map<String, dynamic>;
      final game = await GameController.resume(
        encoded: jsonEncode(raw),
        callbacks: GamePersistenceCallbacks.memoryOnly(),
        unlockedJokerIds: <String>{...tutorialStarterJokerIds, 'wire', 'allin'},
        wait: (_) async {},
      );
      addTearDown(game.dispose);
      final restored = game.toLegacyJson();
      for (final key in <String>[
        'runId',
        'rngSeed',
        'rngCounters',
        'stage',
        'stagesCleared',
        'stageScore',
        'handsLeft',
        'discardsLeft',
        'runCoins',
        'jokerIds',
        'hand',
        'deck',
        'totalScore',
        'accountEarned',
        'stake',
        'stakePaid',
        'startBoostJoker',
        'startBoostCost',
        'futureRunMetadata',
      ]) {
        expect(restored[key], raw[key], reason: 'Upgrade must preserve $key');
      }
      expect(game.supplyLedger.surcharge(SupplyId.scalpel), 5);
    },
  );

  test(
    'Capacitor migration keeps privacy and owner and never overwrites Flutter data',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final accountJson = jsonEncode(_officialAccount());
      final runJson = _officialRun();
      final privacyJson = jsonEncode(<String, Object?>{
        'version': AppConstants.privacyPolicyVersion,
        'acceptedAt': 1788500000000,
      });
      var reads = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_migrationChannel, (call) async {
            expect(call.method, 'readLegacyPreferences');
            reads++;
            return <String, Object?>{
              AppConstants.legacyAccountKey: accountJson,
              AppConstants.legacyRunKey: runJson,
              AppConstants.privacyAcceptedKey: privacyJson,
              AppConstants.cloudOwnerKey: 'official-player-uid',
            };
          });
      final repository = await LocalSaveRepository.open();
      final result = await repository.migrateLegacySaveIfNeeded();
      expect(result.succeeded, isTrue);
      expect(result.copiedKeys, hasLength(4));
      expect(repository.accountJson, accountJson);
      expect(repository.runJson, runJson);
      expect(repository.privacyAccepted, isTrue);
      expect(repository.cloudOwner, 'official-player-uid');
      final newer = AccountState.decode(accountJson)..coins = 1900;
      await repository.writeAccountJson(newer.encode());
      expect((await repository.migrateLegacySaveIfNeeded()).attempted, isFalse);
      expect(reads, 1);
      expect(AccountState.decode(repository.accountJson!).coins, 1900);

      // Interrupted migrations are retryable without replacing already-saved data.
      await repository.remove(AppConstants.migrationMarkerKey);
      expect(
        (await repository.migrateLegacySaveIfNeeded()).copiedKeys,
        isEmpty,
      );
      expect(AccountState.decode(repository.accountJson!).coins, 1900);
    },
  );

  test(
    'upgrade backup retains exact original bytes once, outside cloud payload',
    () async {
      final accountJson = jsonEncode(_officialAccount());
      final runJson = _officialRun();
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.legacyAccountKey: accountJson,
        AppConstants.legacyRunKey: runJson,
        AppConstants.migrationMarkerKey: true,
        AppConstants.cloudOwnerKey: 'official-player-uid',
      });
      final repository = await LocalSaveRepository.open();
      expect(await repository.backupBeforeAstraUpgrade(), isTrue);
      final backup = repository.readString(
        LocalSaveRepository.preAstraUpgradeBackupKey,
      )!;
      final values =
          (jsonDecode(backup) as Map<String, dynamic>)['values'] as Map;
      expect(values[AppConstants.legacyAccountKey], accountJson);
      expect(values[AppConstants.legacyRunKey], runJson);
      expect(values[AppConstants.cloudOwnerKey], 'official-player-uid');

      await repository.writeAccountJson(
        (AccountState.decode(accountJson)..coins = 1).encode(),
      );
      expect(await repository.backupBeforeAstraUpgrade(), isFalse);
      expect(
        repository.readString(LocalSaveRepository.preAstraUpgradeBackupKey),
        backup,
      );
      expect(
        repository.accountJson,
        isNot(contains('flutter_pre_astra_upgrade')),
      );
      await repository.clearPlayerData();
      expect(
        repository.readString(LocalSaveRepository.preAstraUpgradeBackupKey),
        isNull,
      );
    },
  );

  test(
    'upgrade backup captures native legacy values before their first import',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final accountJson = jsonEncode(_officialAccount());
      final runJson = _officialRun();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            _migrationChannel,
            (_) async => <String, Object?>{
              AppConstants.legacyAccountKey: accountJson,
              AppConstants.legacyRunKey: runJson,
            },
          );
      final repository = await LocalSaveRepository.open();
      expect(await repository.backupBeforeAstraUpgrade(), isTrue);
      expect(repository.accountJson, isNull);
      final snapshot =
          jsonDecode(
                repository.readString(
                  LocalSaveRepository.preAstraUpgradeBackupKey,
                )!,
              )
              as Map<String, dynamic>;
      final values = snapshot['values'] as Map;
      expect(values[AppConstants.legacyAccountKey], accountJson);
      expect(values[AppConstants.legacyRunKey], runJson);
      await repository.migrateLegacySaveIfNeeded();
      expect(repository.accountJson, accountJson);
    },
  );

  test('fresh install does not create an empty backup', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final repository = await LocalSaveRepository.open();
    expect(await repository.backupBeforeAstraUpgrade(), isFalse);
    expect(
      repository.readString(LocalSaveRepository.preAstraUpgradeBackupKey),
      isNull,
    );
  });

  test(
    'failed upgrade backup leaves source and marker unchanged and can retry',
    () async {
      final accountJson = jsonEncode(_officialAccount());
      final store =
          _FailingWriteStore(<String, Object>{
              'flutter.${AppConstants.legacyAccountKey}': accountJson,
              'flutter.${AppConstants.migrationMarkerKey}': true,
            })
            ..rejectNextKey =
                'flutter.${LocalSaveRepository.preAstraUpgradeBackupKey}';
      SharedPreferencesStorePlatform.instance = store;
      final repository = await LocalSaveRepository.open();
      await expectLater(
        repository.backupBeforeAstraUpgrade(),
        throwsStateError,
      );
      expect(repository.accountJson, accountJson);
      expect(
        repository.readString(LocalSaveRepository.preAstraUpgradeBackupKey),
        isNull,
      );
      expect(await repository.backupBeforeAstraUpgrade(), isTrue);
    },
  );

  test(
    'failed reward write rolls back claim and coins before a once-only retry',
    () async {
      final store = _FailingWriteStore(<String, Object>{
        'flutter.${AppConstants.legacyAccountKey}': jsonEncode(
          _officialAccount(),
        ),
        'flutter.${AppConstants.migrationMarkerKey}': true,
      });
      SharedPreferencesStorePlatform.instance = store;
      final app = await AppController.bootstrap(releaseBuild: true);
      addTearDown(app.dispose);
      final before = app.account.coins;
      final callbacks = app.gamePersistenceCallbacks();
      const reward = AccountMutation(
        claimId: 'official-upgrade-failure:heat-7',
        kind: AccountMutationKind.heatReward,
        coinDelta: 10,
      );
      store.rejectNextKey = 'flutter.${AppConstants.legacyAccountKey}';
      await expectLater(callbacks.mutateAccount(reward), throwsStateError);
      expect(app.account.coins, before);
      expect(app.account.rewardClaims, isNot(contains(reward.claimId)));
      final repository = await LocalSaveRepository.open();
      final persistedAfterFailure = AccountState.decode(
        repository.accountJson!,
      );
      expect(persistedAfterFailure.coins, before);
      expect(
        persistedAfterFailure.rewardClaims,
        isNot(contains(reward.claimId)),
      );
      expect(await callbacks.mutateAccount(reward), isTrue);
      expect(await callbacks.mutateAccount(reward), isTrue);
      expect(app.account.coins, before + 10);
      final restored = await AppController.bootstrap(releaseBuild: true);
      addTearDown(restored.dispose);
      expect(restored.account.coins, before + 10);
      expect(
        restored.account.rewardClaims.where((claim) => claim == reward.claimId),
        hasLength(1),
      );
    },
  );
}
