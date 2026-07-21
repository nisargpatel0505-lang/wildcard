import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/legacy_save_schema.dart';

void main() {
  test('schema inventories include v7.1 additions and billing state', () {
    expect(
      legacyAccountSaveFields,
      containsAll(<String>{
        'purchaseClaims',
        'rewardClaims',
        'noAds',
        'missionSet',
      }),
    );
    expect(
      legacyRunSaveFields,
      containsAll(<String>{
        'difficulty',
        'supplyPurchaseLedger',
        'modIds',
        'pendingTransition',
        'rngCounters',
      }),
    );
  });

  test('v6.9 save defaults to Medium and migrates supply counts', () {
    final encoded = jsonEncode(<String, Object?>{
      'v': 1,
      'phase': 'shop',
      'telemetryMode': 'normal',
      'rngSeed': 123,
      'stage': 8,
      'hand': const <Object?>[],
      'cards': const <Object?>[],
      'jokerIds': const <String>['copper'],
      'modId': 'tax',
      'supplyPurchaseCounts': const <String, int>{'scalpel': 2},
      'futureServerField': 'preserve-me',
    });
    final save = LegacyRunSave.decode(encoded);
    expect(save.phase, LegacyRunPhase.shop);
    expect(save.difficulty, RunDifficulty.medium);
    expect(save.modifiers, const <HeatModifier>[HeatModifier.tax]);
    expect(save.supplyLedger.count(SupplyId.scalpel), 2);
    expect(save.supplyLedger.surcharge(SupplyId.scalpel), 10);
    expect(save.toScoringState().cards, hasLength(minimumDeckSize));
    expect(
      jsonDecode(save.encodePreservingUnknowns())['futureServerField'],
      'preserve-me',
    );
  });

  test('v7 stacked modifiers restore and Daily ignores leaked Hard mode', () {
    final save = LegacyRunSave.decode(
      jsonEncode(<String, Object?>{
        'v': 1,
        'phase': 'game',
        'telemetryMode': 'daily',
        'difficulty': 'hard',
        'rngSeed': 123,
        'stage': 51,
        'endless': true,
        'hand': const <Object?>[],
        'cards': const <Object?>[],
        'modIds': const <String>['blackout', 'echo', 'unknown-future-mod'],
        'supplyPurchaseLedger': const <Object?>[
          <String, Object?>{'id': 'boost', 'stage': 21, 'step': 10},
        ],
      }),
    );
    expect(save.difficulty, RunDifficulty.medium);
    expect(save.modifiers, const <HeatModifier>[
      HeatModifier.nullField,
      HeatModifier.echoChamber,
    ]);
    expect(save.supplyLedger.surcharge(SupplyId.boost), 10);
    expect(save.toScoringState().target, 75725);
  });
}
