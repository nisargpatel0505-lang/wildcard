import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/arcade_house_rules.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/scoring_engine.dart';
import 'package:wildcard/game/game_controller.dart';
import 'package:wildcard/game/game_models.dart';

void main() {
  group('Arcade House Rules', () {
    test('rank suppression and visible labels use the same rule', () {
      final face = _card(CardRank.king, CardSuit.spades);
      final number = _card(CardRank.ten, CardSuit.hearts);
      final state = ScoringState(
        rngSeed: 1,
        houseRule: ArcadeHouseRule.paupersTable,
      );

      expect(state.cardRankSuppressed(face), isTrue);
      expect(state.cardRankSuppressionLabel(face), "Paupers' Table");
      expect(state.cardRankSuppressed(number), isFalse);

      state.houseRule = ArcadeHouseRule.royalCourt;
      expect(state.cardRankSuppressed(face), isFalse);
      expect(state.cardRankSuppressed(number), isTrue);
    });

    test('Colour Blind and Suit Carousel are deterministic', () {
      final red = _card(CardRank.ten, CardSuit.hearts);
      final black = _card(CardRank.ten, CardSuit.spades);
      final state = ScoringState(
        rngSeed: 2,
        houseRule: ArcadeHouseRule.colourBlind,
      );
      expect(state.cardRankSuppressed(red), isFalse);
      expect(state.cardRankSuppressed(black), isTrue);
      state.stage = 2;
      expect(state.cardRankSuppressed(red), isTrue);
      expect(state.cardRankSuppressed(black), isFalse);

      state
        ..houseRule = ArcadeHouseRule.suitCarousel
        ..handsPlayedThisStage = 0;
      expect(state.cardRankSuppressed(black), isTrue);
      state.handsPlayedThisStage = 1;
      expect(state.cardRankSuppressed(red), isTrue);
    });

    test('Echo Table applies readable repeat decay', () {
      final state = ScoringState(rngSeed: 3);
      final cards = <PlayingCard>[
        _card(CardRank.ace, CardSuit.spades),
        _card(CardRank.ace, CardSuit.hearts),
      ];
      final classic = WildcardScoringEngine(state).scoreHand(cards);
      final echo = WildcardScoringEngine(
        state,
        levelOverride: LevelScoringOverride(
          previousHandCounts: const <HandType, int>{HandType.pair: 1},
          repeatDecay: .35,
          ruleLabel: 'HOUSE RULE',
          useLegacyJokerEffects: false,
        ),
      ).scoreHand(cards);

      expect(echo.total, (classic.total * .65).round());
      expect(
        echo.events.any(
          (event) => event.label?.contains('REPEAT DECAY') == true,
        ),
        isTrue,
      );
    });

    test('Modifier Marathon produces an eligible modifier from Heat 1', () {
      final state = ScoringState(
        rngSeed: 4,
        houseRule: ArcadeHouseRule.modifierMarathon,
      );
      ModifierSelector(state).assignForCurrentHeat();
      expect(state.modifiers, hasLength(1));
      expect(state.modifiers.single.isBoss, isFalse);
    });

    test('a House Rule alone does not activate modifier Jokers', () async {
      final game = await GameController.startNew(
        config: const GameRunConfig(
          rngSeed: 41,
          houseRule: ArcadeHouseRule.paupersTable,
          initialJokerIds: <String>['survivor'],
          unlockedJokerIds: <String>{'survivor'},
        ),
        callbacks: GamePersistenceCallbacks.memoryOnly(),
        wait: (_) async {},
      );
      final cards = <PlayingCard>[
        _card(CardRank.ten, CardSuit.spades),
        _card(CardRank.ten, CardSuit.hearts),
      ];
      final withRuleOnly = game.scoringEngine.scoreHand(cards);
      game.state.jokerIds.clear();
      final baseline = game.scoringEngine.scoreHand(cards);
      expect(withRuleOnly.total, baseline.total);

      game.state
        ..jokerIds.add('survivor')
        ..modifiers.add(HeatModifier.cold);
      final withRealModifier = game.scoringEngine.scoreHand(cards);
      expect(withRealModifier.total, greaterThan(baseline.total));
      game.dispose();
    });

    test('House Rule survives active-run save and resume', () async {
      String? encoded;
      final callbacks = GamePersistenceCallbacks(
        writeRun: (value, _) async => encoded = value,
        clearRun: () async {},
        mutateAccount: (_) async => true,
      );
      final game = await GameController.startNew(
        config: const GameRunConfig(
          rngSeed: 55,
          houseRule: ArcadeHouseRule.discardDuty,
        ),
        callbacks: callbacks,
        wait: (_) async {},
      );
      expect(game.leaderboardEligible, isFalse);
      expect(encoded, isNotNull);
      expect(jsonDecode(encoded!)['houseRuleId'], 'discard_duty');

      final resumed = await GameController.resume(
        encoded: encoded!,
        callbacks: callbacks,
        wait: (_) async {},
      );
      expect(resumed.state.houseRule, ArcadeHouseRule.discardDuty);
      expect(resumed.leaderboardEligible, isFalse);

      final oldCheckpoint = jsonDecode(encoded!) as Map<String, Object?>
        ..remove('leaderboardEligible');
      final oldResume = await GameController.resume(
        encoded: jsonEncode(oldCheckpoint),
        callbacks: callbacks,
        wait: (_) async {},
      );
      expect(oldResume.state.houseRule, ArcadeHouseRule.discardDuty);
      expect(oldResume.leaderboardEligible, isFalse);
      game.dispose();
      resumed.dispose();
      oldResume.dispose();
    });

    test('Daily and Gauntlet reject House Rules', () async {
      for (final mode in <RunMode>[RunMode.daily, RunMode.gauntlet]) {
        await expectLater(
          GameController.startNew(
            config: GameRunConfig(
              rngSeed: 1,
              mode: mode,
              houseRule: ArcadeHouseRule.echoTable,
            ),
            callbacks: GamePersistenceCallbacks.memoryOnly(),
            wait: (_) async {},
          ),
          throwsArgumentError,
        );
      }
    });
  });
}

PlayingCard _card(CardRank rank, CardSuit suit) =>
    PlayingCard(rank: rank, suit: suit, uid: '${rank.name}-${suit.name}');
