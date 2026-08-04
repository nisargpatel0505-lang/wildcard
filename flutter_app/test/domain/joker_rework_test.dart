import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/scoring_engine.dart';
import 'package:wildcard/game/game_controller.dart';
import 'package:wildcard/game/game_models.dart';

void main() {
  group('Arcade Joker rework', () {
    test('retired ownership migrates to active replacements', () {
      final account = AccountState.fromJson(<String, Object?>{
        'unlocked': <String>['warm_up', 'cold_adapter', 'quartet'],
      });
      expect(
        account.unlockedJokerIds,
        containsAll(<String>['opening_act', 'survivor', 'fulltable']),
      );
      expect(
        account.unlockedJokerIds.any(retiredJokerReplacementIds.containsKey),
        isFalse,
      );
    });

    test('Suit Presser is Mult in Arcade but keeps Level rank behaviour', () {
      final card = _card(CardRank.ten, CardSuit.hearts);
      final arcadeState = ScoringState(
        rngSeed: 1,
        jokerIds: <String>['presser'],
      );
      final arcade = WildcardScoringEngine(
        arcadeState,
      ).scoreHand(<PlayingCard>[card]);
      expect(arcade.rankSum, 10);
      expect(arcade.multiplier, closeTo(1.25, .0001));

      final levelState = ScoringState(
        rngSeed: 1,
        jokerIds: <String>['presser'],
        legacyJokerEffects: true,
      );
      final level = WildcardScoringEngine(
        levelState,
        levelOverride: LevelScoringOverride(),
      ).scoreHand(<PlayingCard>[card]);
      expect(level.rankSum, 14);
      expect(level.multiplier, closeTo(baseMultiplier, .0001));
    });

    test('legacy Levels retain Rarity Hunter and Blood Money behaviour', () {
      ScoreResult score({
        required List<String> jokers,
        required bool legacy,
        int runCoins = 0,
      }) {
        final state = ScoringState(
          rngSeed: 11,
          jokerIds: jokers,
          runCoins: runCoins,
          legacyJokerEffects: legacy,
        );
        return WildcardScoringEngine(
          state,
          levelOverride: legacy ? LevelScoringOverride() : null,
        ).scoreHand(<PlayingCard>[_card(CardRank.eight, CardSuit.spades)]);
      }

      final arcadeRarity = score(
        jokers: <String>['rarity_hunter', 'overclock'],
        legacy: false,
      );
      final legacyRarity = score(
        jokers: <String>['rarity_hunter', 'overclock'],
        legacy: true,
      );
      expect(_jokerFactor(arcadeRarity, 0), closeTo(1.25, .0001));
      expect(_jokerFactor(legacyRarity, 0), closeTo(1.25 * 1.25, .0001));

      final arcadeBlood = score(jokers: <String>['blood_money'], legacy: false);
      final legacyBlood = score(jokers: <String>['blood_money'], legacy: true);
      expect(
        arcadeBlood.events.where((event) => event.type == ScoreEventType.xMult),
        isEmpty,
      );
      expect(_jokerFactor(legacyBlood, 0), closeTo(1.8, .0001));
    });

    test('legacy rank Jokers stay active under multiplier jammers', () {
      JokerModifierStatus status(
        String id,
        HeatModifier modifier, {
        required bool legacy,
      }) => jokerModifierStatus(
        ScoringState(
          rngSeed: 12,
          modifier: modifier,
          legacyJokerEffects: legacy,
        ),
        jokersById[id]!,
      );

      for (final id in <String>['presser', 'retainer', 'union_boss']) {
        expect(
          status(id, HeatModifier.nullField, legacy: true).state,
          JokerModifierVisualState.active,
          reason: '$id retains a rank effect in authored Levels',
        );
        expect(
          status(id, HeatModifier.nullField, legacy: false).state,
          JokerModifierVisualState.multiplierSuppressed,
          reason: '$id is a multiplier effect in Arcade',
        );
      }
      for (final id in <String>[
        'even',
        'inktrade',
        'triple3',
        'number_station',
        'gravedigger',
        'odd_job',
        'prime_time',
        'kingpin',
        'closer',
        'cheat',
      ]) {
        expect(
          status(id, HeatModifier.deadAir, legacy: true).state,
          JokerModifierVisualState.active,
          reason: '$id retains a non-multiplier effect in authored Levels',
        );
        expect(
          status(id, HeatModifier.deadAir, legacy: false).state,
          JokerModifierVisualState.multiplierSuppressed,
          reason: '$id is a multiplier effect in Arcade',
        );
      }

      expect(
        status('polish', HeatModifier.deadAir, legacy: true).state,
        JokerModifierVisualState.multiplierSuppressed,
        reason: 'genuine legacy multiplier effects remain classified',
      );
    });

    test('low cards and red cards visibly retrigger', () {
      final low = WildcardScoringEngine(
        ScoringState(rngSeed: 2, jokerIds: <String>['lowball']),
      ).scoreHand(<PlayingCard>[_card(CardRank.six, CardSuit.clubs)]);
      expect(low.rankSum, 12);
      expect(
        low.events.where((event) => event.type == ScoreEventType.retrigger),
        hasLength(1),
      );

      final rose =
          WildcardScoringEngine(
            ScoringState(rngSeed: 2, jokerIds: <String>['rose_tint']),
          ).scoreHand(<PlayingCard>[
            _card(CardRank.ten, CardSuit.hearts),
            _card(CardRank.ten, CardSuit.spades),
          ]);
      expect(rose.rankSum, 20);
      expect(
        rose.events.any((event) => event.label == 'ROSE TINT · BLACK 0'),
        isTrue,
      );
    });

    test('shape and deck-building Jokers now have bounded triggers', () {
      final even =
          WildcardScoringEngine(
            ScoringState(rngSeed: 3, jokerIds: <String>['even']),
          ).scoreHand(<PlayingCard>[
            _card(CardRank.two, CardSuit.spades),
            _card(CardRank.four, CardSuit.hearts),
            _card(CardRank.six, CardSuit.clubs),
          ]);
      expect(even.multiplier, closeTo(baseMultiplier * 1.5, .0001));

      final cut = ScoringState(
        rngSeed: 4,
        jokerIds: <String>['guillotine'],
        cards: baseCardSet().take(32).toList(),
      );
      final guillotine = WildcardScoringEngine(
        cut,
      ).scoreHand(<PlayingCard>[_card(CardRank.ace, CardSuit.spades)]);
      expect(
        guillotine.multiplier,
        closeTo(baseMultiplier * 1.15 * 1.15 * 1.15 * 1.15, .001),
      );
    });

    test('Ace Magnet copies at most one scoring Ace per Heat', () async {
      final game = await GameController.startNew(
        config: const GameRunConfig(
          rngSeed: 9,
          unlockedJokerIds: <String>{'acemag'},
          initialJokerIds: <String>['acemag'],
        ),
        callbacks: GamePersistenceCallbacks.memoryOnly(),
        wait: (_) async {},
      );
      final ace = game.state.cards.firstWhere(
        (card) => card.rank == CardRank.ace,
      );
      game.hand
        ..clear()
        ..add(ace);
      game.drawPile.clear();
      await game.toggleCard(ace.uid!);
      await game.playSelected();

      expect(
        game.state.cards.where(
          (card) => card.rank == ace.rank && card.suit == ace.suit,
        ),
        hasLength(2),
      );
      expect(game.state.jokerState['ace_magnet_heat'], 1);
      game.dispose();
    });

    test('Ace Magnet announces only a copy the controller can perform', () {
      final state = ScoringState(rngSeed: 13, jokerIds: <String>['acemag']);
      final ace = state.cards.firstWhere(
        (card) => card.rank == CardRank.ace && card.suit == CardSuit.spades,
      );
      final engine = WildcardScoringEngine(state);
      final before = state.cards.length;

      final preview = engine.scoreHand(<PlayingCard>[ace]);
      final committed = engine.scoreHand(<PlayingCard>[ace], commit: true);
      expect(
        preview.events.any(
          (event) => event.label?.contains('ACE COPIED') == true,
        ),
        isFalse,
      );
      expect(
        committed.events.where(
          (event) => event.label == 'ACE MAGNET · ACE COPIED',
        ),
        hasLength(1),
      );
      expect(state.cards, hasLength(before), reason: 'the scorer stays pure');

      state.jokerState['ace_magnet_heat'] = 1;
      expect(
        engine
            .scoreHand(<PlayingCard>[ace], commit: true)
            .events
            .any((event) => event.label?.contains('ACE COPIED') == true),
        isFalse,
      );

      final suppressedState = ScoringState(
        rngSeed: 14,
        modifier: HeatModifier.heartless,
        jokerIds: <String>['acemag'],
      );
      final suppressedAce = suppressedState.cards.firstWhere(
        (card) => card.rank == CardRank.ace && card.suit == CardSuit.hearts,
      );
      expect(
        WildcardScoringEngine(suppressedState)
            .scoreHand(<PlayingCard>[suppressedAce], commit: true)
            .events
            .any((event) => event.label?.contains('ACE COPIED') == true),
        isFalse,
      );

      final cappedState = ScoringState(
        rngSeed: 15,
        jokerIds: <String>['acemag'],
      );
      final cappedAce = cappedState.cards.firstWhere(
        (card) => card.rank == CardRank.ace && card.suit == CardSuit.spades,
      );
      cappedState.cards.add(cappedAce.copyWith(copied: true));
      expect(
        WildcardScoringEngine(cappedState)
            .scoreHand(<PlayingCard>[cappedAce], commit: true)
            .events
            .any((event) => event.label?.contains('ACE COPIED') == true),
        isFalse,
      );
    });

    test('rank-zero score events name every active suppression cause', () {
      const card = PlayingCard(
        rank: CardRank.eight,
        suit: CardSuit.spades,
        copied: true,
      );
      final result = WildcardScoringEngine(
        ScoringState(
          rngSeed: 16,
          modifierStack: const <HeatModifier>[
            HeatModifier.frostbite,
            HeatModifier.counterfeit,
          ],
        ),
      ).scoreHand(const <PlayingCard>[card]);

      expect(
        result.events.any(
          (event) => event.label == 'FROSTBITE + COUNTERFEIT · 0',
        ),
        isTrue,
      );
    });
  });
}

double _jokerFactor(ScoreResult result, int jokerIndex) => result.events
    .singleWhere(
      (event) =>
          event.type == ScoreEventType.xMult && event.jokerIndex == jokerIndex,
    )
    .amount
    .toDouble();

PlayingCard _card(CardRank rank, CardSuit suit) =>
    PlayingCard(rank: rank, suit: suit, uid: '${rank.name}-${suit.name}');
