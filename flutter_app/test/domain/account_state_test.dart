import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/account_state.dart';

void main() {
  test(
    'legacy account migration clamps, filters and preserves unknown fields',
    () {
      const validToken =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final account = AccountState.decode(
        jsonEncode(<String, Object?>{
          '_savedAt': 1234,
          'coins': 150,
          'unlocked': const <String>['copper', 'not-a-joker'],
          'tutorialDone': true,
          'bestHeat': 6,
          'speed': 'fast',
          'pacingVersion': 2,
          'topRuns': const <Object?>[
            <String, Object?>{'score': 10, 'heat': 2},
            <String, Object?>{'score': 100, 'heat': 6},
          ],
          'playerName': 'N!S A-R_123456',
          'purchaseClaims': const <String, Object?>{
            validToken: <String, Object?>{
              'productId': 'coins_250',
              'claimedAt': 99,
            },
            'bad-token': <String, Object?>{
              'productId': 'coins_8500',
              'claimedAt': 100,
            },
          },
          'futureCloudField': <String, Object?>{'keep': true},
        }),
      );

      expect(account.unlockedJokerIds, <String>{'copper'});
      expect(account.starterGiftClaimed, isTrue);
      expect(account.firstRunStarted, isTrue);
      expect(account.bestClearedHeat, 5);
      expect(account.speed, ScoringPace.fast);
      expect(account.topRuns.map((run) => run.score), <int>[100, 10]);
      expect(account.playerName, 'NSAR1234');
      expect(account.purchaseClaims.keys, <String>[validToken]);
      expect(
        jsonDecode(account.encode())['futureCloudField'],
        <String, Object?>{'keep': true},
      );
    },
  );

  test('old pacing defaults Normal and music follows legacy mute', () {
    final account = AccountState.fromJson(<String, Object?>{
      'muted': true,
      'speed': 'fast',
      'pacingVersion': 1,
    });
    expect(account.speed, ScoringPace.normal);
    expect(account.musicOn, isFalse);
  });
}
