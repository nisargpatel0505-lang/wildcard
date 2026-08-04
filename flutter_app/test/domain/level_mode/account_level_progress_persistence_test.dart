import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildcard/core/app_constants.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/services/local_save_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Level Mode account persistence', () {
    test('new and pre-Level-Mode saves start with only Level 1 unlocked', () {
      final fresh = AccountState();
      final migrated = AccountState.decode(
        jsonEncode(<String, Object?>{
          'coins': 275,
          'futureField': <String, Object?>{'preserved': true},
        }),
      );

      for (final account in <AccountState>[fresh, migrated]) {
        expect(account.highestUnlockedLevel, 1);
        expect(account.clearedLevelIds, isEmpty);
        expect(account.levelBestScores, isEmpty);
        expect(account.levelAttempts, isEmpty);
      }
      expect(migrated.coins, 275);
      expect(jsonDecode(migrated.encode())['futureField'], <String, Object?>{
        'preserved': true,
      });
    });

    test(
      'round trip persists typed progress and repairs the cleared frontier',
      () {
        final decoded = AccountState.fromJson(<String, Object?>{
          'highestUnlockedLevel': 2,
          'clearedLevelIds': <Object?>[1, 4, 4, 0, 101, '5'],
          'levelBestScores': <String, Object?>{
            '1': 90,
            '4': 640,
            'bad': 9999,
            '101': 1,
          },
          'levelAttempts': <String, Object?>{'1': 2, '4': 7, '5': -3},
        });

        expect(decoded.highestUnlockedLevel, 6);
        expect(decoded.clearedLevelIds, <int>{1, 4, 5});
        expect(decoded.levelBestScores, <int, int>{1: 90, 4: 640});
        expect(decoded.levelAttempts, <int, int>{1: 2, 4: 7});

        final roundTrip = AccountState.decode(decoded.encode());
        expect(roundTrip.highestUnlockedLevel, 6);
        expect(roundTrip.clearedLevelIds, <int>{1, 4, 5});
        expect(roundTrip.levelBestScores, <int, int>{1: 90, 4: 640});
        expect(roundTrip.levelAttempts, <int, int>{1: 2, 4: 7});
      },
    );

    test('clearing Level 100 keeps the unlock frontier capped at 100', () {
      final account = AccountState(
        highestUnlockedLevel: 1,
        clearedLevelIds: <int>{100},
      );

      expect(account.highestUnlockedLevel, 100);
      expect(account.clearedLevelIds, <int>{100});
    });

    test('cloud-style merges never regress any Level Mode progress', () {
      final installedCloud = AccountState(
        highestUnlockedLevel: 5,
        clearedLevelIds: <int>{1, 2, 3, 4},
        levelBestScores: <int, int>{1: 80, 4: 450},
        levelAttempts: <int, int>{1: 1, 4: 3},
      );
      final phone = AccountState(
        highestUnlockedLevel: 8,
        clearedLevelIds: <int>{1, 2, 3, 4, 5, 6, 7},
        levelBestScores: <int, int>{1: 70, 4: 700, 7: 1200},
        levelAttempts: <int, int>{1: 4, 4: 2, 7: 6},
      );

      expect(installedCloud.mergeLevelProgressFrom(phone), isTrue);
      expect(installedCloud.highestUnlockedLevel, 8);
      expect(installedCloud.clearedLevelIds, <int>{1, 2, 3, 4, 5, 6, 7});
      expect(installedCloud.levelBestScores, <int, int>{
        1: 80,
        4: 700,
        7: 1200,
      });
      expect(installedCloud.levelAttempts, <int, int>{1: 4, 4: 3, 7: 6});

      final stale = AccountState(
        highestUnlockedLevel: 2,
        clearedLevelIds: <int>{1},
        levelBestScores: <int, int>{1: 1},
        levelAttempts: <int, int>{1: 1},
      );
      expect(installedCloud.mergeLevelProgressFrom(stale), isFalse);
      expect(installedCloud.highestUnlockedLevel, 8);
      expect(installedCloud.levelBestScores[4], 700);
      expect(installedCloud.levelAttempts[4], 3);
    });

    test(
      'local repository reads old saves and writes migrated fields',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          AppConstants.legacyAccountKey: jsonEncode(<String, Object?>{
            '_savedAt': 10,
            'coins': 50,
          }),
        });
        final repository = await LocalSaveRepository.open();

        final account = repository.decodeAccountState();
        expect(account, isNotNull);
        expect(account!.highestUnlockedLevel, 1);
        account.highestUnlockedLevel = 3;
        account.clearedLevelIds.addAll(<int>{1, 2});
        account.levelBestScores[2] = 250;
        account.levelAttempts[2] = 4;
        await repository.writeAccountState(account, savedAtOverride: 20);

        final persisted = repository.decodeAccountState();
        expect(persisted!.savedAt, 20);
        expect(persisted.highestUnlockedLevel, 3);
        expect(persisted.clearedLevelIds, <int>{1, 2});
        expect(persisted.levelBestScores, <int, int>{2: 250});
        expect(persisted.levelAttempts, <int, int>{2: 4});
      },
    );
  });
}
