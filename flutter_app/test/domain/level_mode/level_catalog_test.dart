import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/level_mode/level_catalog.dart';
import 'package:wildcard/domain/level_mode/level_definition.dart';

void main() {
  late String productionSource;
  late Map<String, Object?> productionJson;

  setUpAll(() {
    productionSource = File(LevelCatalog.defaultAssetPath).readAsStringSync();
    productionJson = Map<String, Object?>.from(
      jsonDecode(productionSource) as Map,
    );
  });

  group('production Level Mode catalog', () {
    test('loads all 100 sequential definitions and all 1,460 layouts', () {
      final catalog = LevelCatalog.fromJsonString(productionSource);

      expect(catalog.schemaVersion, 2);
      expect(catalog.levels, hasLength(100));
      expect(
        catalog.levels.map((level) => level.id),
        orderedEquals(<int>[for (var id = 1; id <= 100; id++) id]),
      );
      expect(catalog.layoutCount, 1460);
      expect(catalog.level(1).name, 'First Pair');
      expect(catalog.level(100).objective.targetScore, 5345);
      expect(catalog.level(100).layouts, hasLength(24));
      expect(
        catalog
            .level(100)
            .layouts
            .every((layout) => layout.deckCodes.length == 26),
        isTrue,
      );
    });

    test('objective-only tables never hide an additional score target', () {
      final catalog = LevelCatalog.fromJsonString(productionSource);
      const objectiveOnlyLevels = <int>[
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        32,
        42,
        43,
        44,
        45,
        56,
        57,
        74,
        87,
        93,
      ];

      for (final levelId in objectiveOnlyLevels) {
        expect(
          catalog.level(levelId).objective.targetScore,
          0,
          reason: 'Level $levelId must clear when its stated objective clears',
        );
      }

      final pairChain = catalog.level(11);
      expect(pairChain.description, 'Score three Pairs in four plays.');
      expect(pairChain.objective.requiredCounts, <HandType, int>{
        HandType.pair: 3,
      });

      // Combined challenges that explicitly say "reach the target" retain it.
      expect(catalog.level(10).objective.targetScore, 515);
      expect(catalog.level(82).objective.targetScore, 3300);
    });

    test(
      'validates every referenced Joker against the native 102-Joker catalog',
      () {
        expect(
          () => LevelCatalog.fromJsonString(productionSource),
          returnsNormally,
        );
      },
    );

    test(
      'derives the blocked-card inspector from the exact selected layout',
      () {
        final catalog = LevelCatalog.fromJsonString(productionSource);
        final level95 = catalog.level(95);
        final blocked95 = level95.blockedCardsFor(level95.layouts.first);
        final level100 = catalog.level(100);
        final blocked100 = level100.blockedCardsFor(level100.layouts.first);

        expect(blocked95, hasLength(12));
        expect(blocked95.map((card) => card.rank).toSet(), <CardRank>{
          CardRank.jack,
          CardRank.queen,
          CardRank.king,
        });
        expect(blocked100, hasLength(26));
      },
    );

    test('enforces exact temporary Joker choices without ownership state', () {
      final level = LevelCatalog.fromJsonString(productionSource).level(75);
      final selected = level.jokerOptionIds.take(2).toList();

      expect(level.chooseJokers, 2);
      expect(level.temporaryJokerIds(selected), <String>[
        ...selected,
        level.negativeJokerId!,
      ]);
      expect(
        () => level.temporaryJokerIds(selected.take(1)),
        throwsArgumentError,
      );
      expect(
        () => level.temporaryJokerIds(<String>[selected.first, selected.first]),
        throwsArgumentError,
      );
      expect(
        () => level.temporaryJokerIds(<String>[selected.first, 'copper']),
        throwsArgumentError,
      );
    });
  });

  group('card-code codec', () {
    test('decodes every rank and suit in the compact authored format', () {
      expect(LevelCardCodec.decode('2S').suit, CardSuit.spades);
      expect(LevelCardCodec.decode('10H').rank, CardRank.ten);
      expect(LevelCardCodec.decode('QC').suit, CardSuit.clubs);
      expect(LevelCardCodec.decode('KD').suit, CardSuit.diamonds);
    });

    test('retains the native Ace value of 15', () {
      final ace = LevelCardCodec.decode('AS');
      expect(ace.rank, CardRank.ace);
      expect(ace.value, 15);
      expect(LevelCardCodec.encode(ace), 'AS');
    });

    test('rejects malformed or nonphysical card codes', () {
      for (final code in <String>['1S', '14S', 'TS', 'AHH', 'A♠', '']) {
        expect(() => LevelCardCodec.decode(code), throwsFormatException);
      }
    });
  });

  group('catalog rejection', () {
    Map<String, Object?> fresh() => Map<String, Object?>.from(
      jsonDecode(jsonEncode(productionJson)) as Map,
    );

    List<Object?> levels(Map<String, Object?> json) =>
        json['levels']! as List<Object?>;

    Map<String, Object?> level(Map<String, Object?> json, int index) =>
        Map<String, Object?>.from(levels(json)[index] as Map);

    Map<String, Object?> rules(Map<String, Object?> json, int index) =>
        Map<String, Object?>.from(level(json, index)['rules']! as Map);

    Map<String, Object?> objective(Map<String, Object?> json, int index) =>
        Map<String, Object?>.from(level(json, index)['objective']! as Map);

    List<Object?> layouts(Map<String, Object?> json, int index) =>
        level(json, index)['layouts']! as List<Object?>;

    Map<String, Object?> layout(
      Map<String, Object?> json,
      int levelIndex,
      int layoutIndex,
    ) => Map<String, Object?>.from(
      layouts(json, levelIndex)[layoutIndex] as Map,
    );

    void replaceLevel(
      Map<String, Object?> json,
      int index,
      Map<String, Object?> replacement,
    ) {
      levels(json)[index] = replacement;
    }

    test('rejects unsupported schemas and unexpected fields', () {
      final wrongSchema = fresh()..['schemaVersion'] = 99;
      final unexpected = fresh()..['extra'] = true;

      expect(
        () => LevelCatalog.fromJson(wrongSchema),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('unsupported schema'),
          ),
        ),
      );
      expect(
        () => LevelCatalog.fromJson(unexpected),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('unknown fields'),
          ),
        ),
      );
    });

    test('requires exactly 100 sequential unique level IDs', () {
      final missing = fresh();
      levels(missing).removeLast();
      final duplicate = fresh();
      final second = level(duplicate, 1)..['id'] = 1;
      replaceLevel(duplicate, 1, second);

      expect(() => LevelCatalog.fromJson(missing), throwsFormatException);
      expect(() => LevelCatalog.fromJson(duplicate), throwsFormatException);
    });

    test('rejects a missing native Joker and invalid selection count', () {
      final missingJoker = fresh();
      final first = level(missingJoker, 0)
        ..['fixedJokers'] = <Object?>['not_real'];
      replaceLevel(missingJoker, 0, first);
      final invalidChoice = fresh();
      final choice = level(invalidChoice, 68)..['chooseJokers'] = 7;
      replaceLevel(invalidChoice, 68, choice);

      expect(
        () => LevelCatalog.fromJson(missingJoker),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('missing native Joker'),
          ),
        ),
      );
      expect(() => LevelCatalog.fromJson(invalidChoice), throwsFormatException);
    });

    test('rejects duplicate layout IDs', () {
      final json = fresh();
      final second = layout(json, 0, 1)..['id'] = layout(json, 0, 0)['id'];
      layouts(json, 0)[1] = second;

      expect(
        () => LevelCatalog.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('contains duplicates'),
          ),
        ),
      );
    });

    test('rejects invalid card codes and duplicate physical cards', () {
      final invalid = fresh();
      final invalidLayout = layout(invalid, 0, 0);
      final invalidDeck = invalidLayout['deckOrder']! as List<Object?>;
      invalidDeck[0] = '14S';
      layouts(invalid, 0)[0] = invalidLayout;

      final duplicate = fresh();
      final duplicateLayout = layout(duplicate, 0, 0);
      final duplicateDeck = duplicateLayout['deckOrder']! as List<Object?>;
      duplicateDeck[1] = duplicateDeck[0];
      layouts(duplicate, 0)[0] = duplicateLayout;

      expect(() => LevelCatalog.fromJson(invalid), throwsFormatException);
      expect(
        () => LevelCatalog.fromJson(duplicate),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('contains duplicates'),
          ),
        ),
      );
    });

    test('rejects blocked decks with an incorrect card count', () {
      final json = fresh();
      final partial = layout(json, 40, 0);
      (partial['deckOrder']! as List<Object?>).removeLast();
      layouts(json, 40)[0] = partial;

      expect(
        () => LevelCatalog.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('blocked deck has'),
          ),
        ),
      );
    });

    test('rejects a deck smaller than its opening hand', () {
      final json = fresh();
      final changedLevel = level(json, 47);
      final changedRules = rules(json, 47)..['hand_size'] = 27;
      changedLevel['rules'] = changedRules;
      replaceLevel(json, 47, changedLevel);

      expect(
        () => LevelCatalog.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('smaller than opening hand'),
          ),
        ),
      );
    });

    test('rejects invalid hands, discards, and targets', () {
      final invalidHands = fresh();
      final handsLevel = level(invalidHands, 0);
      handsLevel['rules'] = rules(invalidHands, 0)..['hands'] = 0;
      replaceLevel(invalidHands, 0, handsLevel);

      final invalidDiscards = fresh();
      final discardsLevel = level(invalidDiscards, 0);
      discardsLevel['rules'] = rules(invalidDiscards, 0)..['discards'] = -1;
      replaceLevel(invalidDiscards, 0, discardsLevel);

      final invalidTarget = fresh();
      final targetLevel = level(invalidTarget, 0);
      targetLevel['objective'] = objective(invalidTarget, 0)
        ..['target_score'] = -1;
      replaceLevel(invalidTarget, 0, targetLevel);

      expect(() => LevelCatalog.fromJson(invalidHands), throwsFormatException);
      expect(
        () => LevelCatalog.fromJson(invalidDiscards),
        throwsFormatException,
      );
      expect(() => LevelCatalog.fromJson(invalidTarget), throwsFormatException);
    });
  });
}
