import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/level_mode/level_catalog.dart';
import 'package:wildcard/domain/level_mode/level_definition.dart';
import 'package:wildcard/domain/level_mode/level_objective_engine.dart';
import 'package:wildcard/domain/scoring_engine.dart';
import 'package:wildcard/game/game_controller.dart';
import 'package:wildcard/game/game_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LevelCatalog catalog;
  setUpAll(() {
    catalog = LevelCatalog.fromJsonString(
      File(LevelCatalog.defaultAssetPath).readAsStringSync(),
    );
  });

  group('LevelObjectiveProgress', () {
    test('target score must be reached', () {
      final objective = _objective(targetScore: 100);
      final progress = LevelObjectiveProgress();

      progress.record(
        objective: objective,
        handType: HandType.highCard,
        score: 99,
      );
      expect(progress.isComplete(objective, dynamicTarget: 100), isFalse);
      progress.record(
        objective: objective,
        handType: HandType.highCard,
        score: 1,
      );
      expect(progress.isComplete(objective, dynamicTarget: 100), isTrue);
    });

    test('required hand counts must each be met', () {
      final objective = _objective(
        requiredCounts: const <HandType, int>{
          HandType.pair: 2,
          HandType.twoPair: 1,
        },
      );
      final progress = LevelObjectiveProgress();

      _record(progress, objective, HandType.pair);
      _record(progress, objective, HandType.twoPair);
      expect(progress.isComplete(objective, dynamicTarget: 0), isFalse);
      _record(progress, objective, HandType.pair);
      expect(progress.isComplete(objective, dynamicTarget: 0), isTrue);
    });

    test('required hand sequence is exact and ordered', () {
      final objective = _objective(
        requiredSequence: const <HandType>[
          HandType.pair,
          HandType.twoPair,
          HandType.straight,
        ],
      );
      final correct = LevelObjectiveProgress();
      for (final hand in objective.requiredSequence) {
        _record(correct, objective, hand);
      }
      expect(correct.isComplete(objective, dynamicTarget: 0), isTrue);

      final wrongFirstHand = LevelObjectiveProgress();
      _record(wrongFirstHand, objective, HandType.highCard);
      for (final hand in objective.requiredSequence) {
        _record(wrongFirstHand, objective, hand);
      }
      expect(
        wrongFirstHand.isComplete(objective, dynamicTarget: 0),
        isFalse,
        reason: 'an extra wrong hand means the authored order was not exact',
      );
    });

    test('minimum hand-type variety counts distinct types only', () {
      final objective = _objective(minVariety: 3);
      final progress = LevelObjectiveProgress();
      _record(progress, objective, HandType.pair);
      _record(progress, objective, HandType.pair);
      _record(progress, objective, HandType.twoPair);
      expect(progress.isComplete(objective, dynamicTarget: 0), isFalse);
      _record(progress, objective, HandType.flush);
      expect(progress.isComplete(objective, dynamicTarget: 0), isTrue);
    });

    test('forbidden hands permanently invalidate the attempt', () {
      final objective = _objective(
        targetScore: 10,
        forbiddenTypes: const <HandType>{HandType.highCard},
      );
      final progress = LevelObjectiveProgress();
      _record(progress, objective, HandType.highCard, score: 20);
      _record(progress, objective, HandType.pair, score: 20);

      expect(progress.forbiddenViolated, isTrue);
      expect(progress.isComplete(objective, dynamicTarget: 10), isFalse);
      expect(
        progress.progressText(objective, dynamicTarget: 10),
        contains('FORBIDDEN HAND'),
      );
    });

    test(
      'Pair-or-better and Trips-or-better quality gates use native order',
      () {
        final pairPlus = _objective(
          minQuality: HandType.pair,
          minQualityCount: 2,
        );
        final pairProgress = LevelObjectiveProgress();
        _record(pairProgress, pairPlus, HandType.highCard);
        _record(pairProgress, pairPlus, HandType.pair);
        expect(pairProgress.isComplete(pairPlus, dynamicTarget: 0), isFalse);
        _record(pairProgress, pairPlus, HandType.flush);
        expect(pairProgress.isComplete(pairPlus, dynamicTarget: 0), isTrue);

        final tripsPlus = _objective(
          minQuality: HandType.threeOfAKind,
          minQualityCount: 2,
        );
        final tripsProgress = LevelObjectiveProgress();
        _record(tripsProgress, tripsPlus, HandType.twoPair);
        _record(tripsProgress, tripsPlus, HandType.threeOfAKind);
        expect(tripsProgress.isComplete(tripsPlus, dynamicTarget: 0), isFalse);
        _record(tripsProgress, tripsPlus, HandType.straight);
        expect(tripsProgress.isComplete(tripsPlus, dynamicTarget: 0), isTrue);
      },
    );

    test('premium-hand requirement counts distinct qualifying types', () {
      final objective = _objective(
        minTypesFrom: const <HandType>{
          HandType.straight,
          HandType.flush,
          HandType.fullHouse,
          HandType.fourOfAKind,
          HandType.straightFlush,
          HandType.royalFlush,
        },
        minTypesFromCount: 2,
      );
      final progress = LevelObjectiveProgress();
      _record(progress, objective, HandType.straight);
      _record(progress, objective, HandType.straight);
      expect(progress.isComplete(objective, dynamicTarget: 0), isFalse);
      _record(progress, objective, HandType.flush);
      expect(progress.isComplete(objective, dynamicTarget: 0), isTrue);
    });

    test('cumulative checkpoints apply to the corresponding scoring hand', () {
      final objective = _objective(
        targetScore: 100,
        checkpoints: const <int>[25, 60, 100],
      );
      final success = LevelObjectiveProgress();
      _record(success, objective, HandType.pair, score: 25);
      _record(success, objective, HandType.twoPair, score: 35);
      _record(success, objective, HandType.straight, score: 40);
      expect(success.checkpointViolated, isFalse);
      expect(success.isComplete(objective, dynamicTarget: 100), isTrue);

      final missed = LevelObjectiveProgress();
      _record(missed, objective, HandType.pair, score: 24);
      _record(missed, objective, HandType.flush, score: 200);
      expect(missed.checkpointViolated, isTrue);
      expect(missed.isComplete(objective, dynamicTarget: 100), isFalse);
    });

    test('combined objective requires every condition simultaneously', () {
      final objective = _objective(
        targetScore: 100,
        requiredCounts: const <HandType, int>{HandType.pair: 1},
        requiredSequence: const <HandType>[HandType.pair, HandType.straight],
        minVariety: 2,
        forbiddenTypes: const <HandType>{HandType.highCard},
        minQualityCount: 2,
        minQuality: HandType.pair,
        minTypesFrom: const <HandType>{HandType.straight, HandType.flush},
        minTypesFromCount: 1,
        checkpoints: const <int>[40, 100],
      );
      final progress = LevelObjectiveProgress();
      _record(progress, objective, HandType.pair, score: 40);
      expect(progress.isComplete(objective, dynamicTarget: 100), isFalse);
      _record(progress, objective, HandType.straight, score: 60);
      expect(progress.isComplete(objective, dynamicTarget: 100), isTrue);
    });

    test('objective progress round-trips through the durable JSON form', () {
      final objective = _objective(
        targetScore: 100,
        requiredSequence: const <HandType>[HandType.pair, HandType.straight],
        checkpoints: const <int>[30, 100],
      );
      final progress = LevelObjectiveProgress();
      _record(progress, objective, HandType.pair, score: 30);

      final restored = LevelObjectiveProgress.fromJson(
        jsonDecode(jsonEncode(progress.toJson())),
      );
      expect(restored.totalScore, 30);
      expect(restored.handCounts, <HandType, int>{HandType.pair: 1});
      expect(restored.handHistory, <HandType>[HandType.pair]);
      expect(restored.sequenceIndex, 1);
      expect(restored.checkpointViolated, isFalse);
    });

    test(
      'broken exact-order state is durable and old saves remain compatible',
      () {
        final objective = _objective(
          requiredSequence: const <HandType>[HandType.pair, HandType.straight],
        );
        final broken = LevelObjectiveProgress();
        _record(broken, objective, HandType.highCard);
        expect(broken.sequenceViolated, isTrue);

        final encoded = broken.toJson();
        final restored = LevelObjectiveProgress.fromJson(
          jsonDecode(jsonEncode(encoded)),
        );
        expect(restored.sequenceViolated, isTrue);
        expect(
          restored.progressText(objective, dynamicTarget: 0),
          contains('ORDER BROKEN'),
        );

        final legacy = Map<String, Object?>.from(encoded)
          ..remove('sequenceViolated');
        expect(
          LevelObjectiveProgress.fromJson(legacy).sequenceViolated,
          isFalse,
        );
      },
    );
  });

  group('Level GameController integration', () {
    test(
      'ScoringState owns mutable hand levels without changing Arcade scores',
      () {
        const cards = <PlayingCard>[
          PlayingCard(rank: CardRank.ace, suit: CardSuit.spades),
          PlayingCard(rank: CardRank.ace, suit: CardSuit.hearts),
        ];
        final source = Map<HandType, int>.unmodifiable(<HandType, int>{
          HandType.pair: 2,
        });
        final copiedState = ScoringState(rngSeed: 1, handLevels: source);
        final mutableState = ScoringState(
          rngSeed: 1,
          handLevels: <HandType, int>{HandType.pair: 2},
        );

        expect(
          WildcardScoringEngine(copiedState).scoreHand(cards).total,
          WildcardScoringEngine(mutableState).scoreHand(cards).total,
        );
        expect(() => copiedState.handLevels.clear(), returnsNormally);
        copiedState.handLevels[HandType.flush] = 1;
        expect(source, <HandType, int>{HandType.pair: 2});
      },
    );

    test('rejects a locked level through the direct controller API', () async {
      final attempt = _attempt(catalog.level(2));
      await expectLater(
        GameController.startNew(
          config: _config(attempt, highestUnlockedLevel: 1),
          callbacks: _Harness().callbacks,
          wait: _noWait,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('locked'),
          ),
        ),
      );
    });

    test(
      'cleared levels remain replayable and failed levels allow retry',
      () async {
        final level2 = _attempt(catalog.level(2));
        final replay = await GameController.startNew(
          config: _config(
            level2,
            highestUnlockedLevel: 1,
            clearedLevelIds: const <int>{2},
            runId: 'replay-cleared',
          ),
          callbacks: _Harness().callbacks,
          wait: _noWait,
        );
        addTearDown(replay.dispose);
        expect(replay.isLevelMode, isTrue);
        expect(replay.levelAttempt!.levelId, 2);

        final attempt = _attempt(catalog.level(1));
        final failedHarness = _Harness();
        final failed = await GameController.startNew(
          config: _config(attempt, runId: 'failed-attempt'),
          callbacks: failedHarness.callbacks,
          wait: _noWait,
        );
        addTearDown(failed.dispose);
        failed.state.handsLeft = 1;
        await failed.toggleCard(failed.hand.first.uid!);
        await failed.playSelected();
        expect(failed.endReason, RunEndReason.levelFailed);

        final retryHarness = _Harness();
        final retry = await GameController.startNew(
          config: _config(attempt, runId: 'retry-attempt'),
          callbacks: retryHarness.callbacks,
          wait: _noWait,
        );
        addTearDown(retry.dispose);
        expect(retry.phase, RunPhase.game);
        expect(retry.levelAttempt!.levelId, 1);
        expect(retryHarness.mutations.single.coinDelta, 0);
        expect(
          retryHarness.mutations.single.kind,
          AccountMutationKind.levelAttemptStarted,
        );
      },
    );

    test('Level 11 clears immediately when the third Pair scores', () async {
      final level = catalog.level(11);
      final harness = _Harness();
      final game = await GameController.startNew(
        config: _config(
          _attempt(level),
          highestUnlockedLevel: 11,
          runId: 'pair-chain-objective-clear',
        ),
        callbacks: harness.callbacks,
        wait: _noWait,
      );
      addTearDown(game.dispose);

      expect(level.objective.targetScore, 0);
      await _playPairOfRank(game, CardRank.two);
      expect(game.phase, RunPhase.game);
      await _playPairOfRank(game, CardRank.three);
      expect(game.phase, RunPhase.game);
      expect(game.levelProgress!.handCounts[HandType.pair], 2);

      await _playPairOfRank(game, CardRank.four);

      expect(game.totalScore, lessThan(145));
      expect(game.levelProgress!.handCounts[HandType.pair], 3);
      expect(game.phase, RunPhase.ended);
      expect(game.endReason, RunEndReason.levelCleared);
      expect(harness.clears, 1);
    });

    test('uses the exact authored layout and fixed temporary Jokers', () async {
      final level = catalog.level(64);
      final layout = level.layouts.first;
      final attempt = _attempt(level, layout: layout);
      final game = await GameController.startNew(
        config: _config(attempt, highestUnlockedLevel: 64),
        callbacks: _Harness().callbacks,
        wait: _noWait,
      );
      addTearDown(game.dispose);

      expect(game.levelAttempt!.layoutId, layout.id);
      expect(
        game.heatDeck.map(LevelCardCodec.encode),
        orderedEquals(layout.deckCodes),
      );
      expect(
        game.hand.map(LevelCardCodec.encode).toSet(),
        layout.deckCodes.take(level.rules.handSize).toSet(),
      );
      expect(game.state.jokerIds, level.fixedJokerIds);
      expect(game.state.rngSeed, layout.seed);
    });

    test(
      'Level attempts ignore injected stake and start boost fields',
      () async {
        final level = catalog.level(1);
        final attempt = _attempt(level);
        final game = await GameController.startNew(
          config: GameRunConfig(
            rngSeed: 999999,
            runId: 'level-no-arcade-entry',
            unlockedJokerIds: const <String>{'trainer'},
            startBoostJokerId: 'trainer',
            startBoostCost: 30,
            stake: 200,
            levelAttempt: attempt,
            highestUnlockedLevel: 1,
          ),
          callbacks: _Harness().callbacks,
          wait: _noWait,
        );
        addTearDown(game.dispose);

        expect(game.state.rngSeed, attempt.rngSeed);
        expect(game.state.jokerIds, attempt.temporaryJokerIds);
        expect(game.startBoostJoker, isNull);
        expect(game.startBoostCost, 0);
        expect(game.stake, 0);
      },
    );

    test(
      'temporary Jokers bypass ownership but never enter account mutations',
      () async {
        final level = catalog.level(65);
        final attempt = _attempt(level);
        final harness = _Harness();
        final game = await GameController.startNew(
          config: _config(
            attempt,
            highestUnlockedLevel: 65,
            unlockedJokerIds: const <String>{},
          ),
          callbacks: harness.callbacks,
          wait: _noWait,
        );
        addTearDown(game.dispose);

        expect(game.unlockedJokerIds, isEmpty);
        expect(game.state.jokerIds, level.fixedJokerIds);
        expect((await game.abandon()).ok, isTrue);
        expect(
          harness.mutations.map((mutation) => mutation.kind),
          <AccountMutationKind>[
            AccountMutationKind.levelAttemptStarted,
            AccountMutationKind.levelAttemptFinished,
          ],
        );
        expect(
          harness.mutations.every((mutation) => mutation.coinDelta == 0),
          isTrue,
        );
        expect(
          harness.mutations.every((mutation) => mutation.jokerIds.isEmpty),
          isTrue,
        );
      },
    );

    test(
      'discard target tax updates and persists the exact dynamic target',
      () async {
        final level = catalog.level(28);
        final attempt = _attempt(level);
        final harness = _Harness();
        final game = await GameController.startNew(
          config: _config(attempt, highestUnlockedLevel: 28),
          callbacks: harness.callbacks,
          wait: _noWait,
        );
        addTearDown(game.dispose);
        final originalTarget = game.target;

        await game.toggleCard(game.hand.first.uid!);
        expect((await game.discardSelected()).ok, isTrue);
        expect(game.levelDiscardsUsed, 1);
        expect(game.target, originalTarget + level.rules.discardTargetTax);

        final resumed = await GameController.resume(
          encoded: harness.writes.last,
          callbacks: _Harness().callbacks,
          levelAttempt: attempt,
          wait: _noWait,
        );
        addTearDown(resumed.dispose);
        expect(resumed.target, game.target);
        expect(resumed.levelDiscardsUsed, 1);
      },
    );

    test(
      'Joker blackout rotates one blocked Joker each scoring hand',
      () async {
        final level = catalog.level(77);
        final game = await GameController.startNew(
          config: _config(_attempt(level), highestUnlockedLevel: 77),
          callbacks: _Harness().callbacks,
          wait: _noWait,
        );
        addTearDown(game.dispose);
        expect(game.state.jokerIds, hasLength(3));
        expect(game.state.blockedJokerIds, <String>{game.state.jokerIds[0]});

        await _playOneCard(game);
        expect(game.phase, RunPhase.game);
        expect(game.state.blockedJokerIds, <String>{game.state.jokerIds[1]});
      },
    );

    test(
      'fading Jokers stay blocked for the remainder of the attempt',
      () async {
        final level = catalog.level(98);
        final game = await GameController.startNew(
          config: _config(_attempt(level), highestUnlockedLevel: 98),
          callbacks: _Harness().callbacks,
          wait: _noWait,
        );
        addTearDown(game.dispose);
        expect(game.state.blockedJokerIds, isEmpty);

        await _playOneCard(game);
        expect(game.levelFadedJokerIds, <String>{game.state.jokerIds[0]});
        expect(game.state.blockedJokerIds, contains(game.state.jokerIds[0]));
        await _playOneCard(game);
        expect(game.levelFadedJokerIds, <String>{
          game.state.jokerIds[0],
          game.state.jokerIds[1],
        });
        expect(
          game.state.blockedJokerIds,
          containsAll(game.levelFadedJokerIds),
        );
      },
    );

    test(
      'Scorched Ranks removes every remaining card sharing a played rank',
      () async {
        final level = catalog.level(86);
        final game = await GameController.startNew(
          config: _config(_attempt(level), highestUnlockedLevel: 86),
          callbacks: _Harness().callbacks,
          wait: _noWait,
        );
        addTearDown(game.dispose);
        final card = game.hand.first;
        final rank = card.rank;
        expect(
          game.state.cards.where((candidate) => candidate.rank == rank).length,
          greaterThan(1),
        );

        await game.toggleCard(card.uid!);
        await game.playSelected();
        expect(
          game.state.cards.where((candidate) => candidate.rank == rank),
          isEmpty,
        );
        expect(game.hand.where((candidate) => candidate.rank == rank), isEmpty);
        expect(
          game.drawPile.where((candidate) => candidate.rank == rank),
          isEmpty,
        );
      },
    );

    test(
      'layout reference and complete mutable attempt state survive resume',
      () async {
        final level = catalog.level(100);
        final layout = level.layouts.first;
        final attempt = _attempt(level, layout: layout);
        final harness = _Harness();
        final game = await GameController.startNew(
          config: _config(attempt, highestUnlockedLevel: 100),
          callbacks: harness.callbacks,
          wait: _noWait,
        );
        addTearDown(game.dispose);
        expect(game.levelDisabledSuit, CardSuit.spades);
        await _playOneCard(game);
        expect(game.levelDisabledSuit, CardSuit.hearts);

        final encoded = harness.writes.last;
        final reference = GameController.levelResumeReference(encoded)!;
        expect(reference.levelId, 100);
        expect(reference.layoutId, layout.id);
        expect(reference.temporaryJokerIds, attempt.temporaryJokerIds);

        final resumed = await GameController.resume(
          encoded: encoded,
          callbacks: _Harness().callbacks,
          levelAttempt: attempt,
          wait: _noWait,
        );
        addTearDown(resumed.dispose);
        expect(resumed.levelAttempt!.layoutId, layout.id);
        expect(resumed.levelDisabledSuit, game.levelDisabledSuit);
        expect(resumed.levelDynamicTarget, game.levelDynamicTarget);
        expect(resumed.levelProgress!.toJson(), game.levelProgress!.toJson());
        expect(
          resumed.hand.map(LevelCardCodec.encode),
          orderedEquals(game.hand.map(LevelCardCodec.encode)),
        );
        expect(
          resumed.drawPile.map(LevelCardCodec.encode),
          orderedEquals(game.drawPile.map(LevelCardCodec.encode)),
        );
        expect(
          resumed.heatDeck.map(LevelCardCodec.encode),
          orderedEquals(game.heatDeck.map(LevelCardCodec.encode)),
        );

        final otherLayoutAttempt = _attempt(level, layout: level.layouts[1]);
        await expectLater(
          GameController.resume(
            encoded: encoded,
            callbacks: _Harness().callbacks,
            levelAttempt: otherLayoutAttempt,
            wait: _noWait,
          ),
          throwsFormatException,
        );
      },
    );

    test('pre-deal checkpoint resumes the exact opening state', () async {
      final level = catalog.level(100);
      final attempt = _attempt(level);
      final harness = _Harness();
      final game = await GameController.startNew(
        config: _config(attempt, highestUnlockedLevel: 100),
        callbacks: harness.callbacks,
        wait: _noWait,
      );
      addTearDown(game.dispose);

      expect(harness.checkpoints.take(2), <RunCheckpoint>[
        RunCheckpoint.runStarted,
        RunCheckpoint.selectionChanged,
      ]);
      final resumed = await GameController.resume(
        encoded: harness.writes.first,
        callbacks: _Harness().callbacks,
        levelAttempt: attempt,
        wait: _noWait,
      );
      addTearDown(resumed.dispose);

      expect(
        resumed.hand.map(LevelCardCodec.encode),
        orderedEquals(game.hand.map(LevelCardCodec.encode)),
      );
      expect(
        resumed.drawPile.map(LevelCardCodec.encode),
        orderedEquals(game.drawPile.map(LevelCardCodec.encode)),
      );
      expect(resumed.state.deckCardsLeft, resumed.drawPile.length);
    });
  });
}

LevelObjective _objective({
  int targetScore = 0,
  Map<HandType, int> requiredCounts = const <HandType, int>{},
  List<HandType> requiredSequence = const <HandType>[],
  int minVariety = 0,
  Set<HandType> forbiddenTypes = const <HandType>{},
  int minQualityCount = 0,
  HandType minQuality = HandType.pair,
  Set<HandType> minTypesFrom = const <HandType>{},
  int minTypesFromCount = 0,
  List<int> checkpoints = const <int>[],
}) => LevelObjective(
  targetScore: targetScore,
  requiredCounts: requiredCounts,
  requiredSequence: requiredSequence,
  minVariety: minVariety,
  forbiddenTypes: forbiddenTypes,
  minQualityCount: minQualityCount,
  minQuality: minQuality,
  minTypesFrom: minTypesFrom,
  minTypesFromCount: minTypesFromCount,
  checkpoints: checkpoints,
);

void _record(
  LevelObjectiveProgress progress,
  LevelObjective objective,
  HandType type, {
  int score = 0,
}) => progress.record(objective: objective, handType: type, score: score);

LevelAttemptConfig _attempt(LevelDefinition level, {LevelLayout? layout}) {
  final selectedLayout = layout ?? level.layouts.first;
  return LevelAttemptConfig.fromSelection(
    level: level,
    layout: selectedLayout,
    selectedJokerIds: selectedLayout.recommendedJokerIds.where(
      level.jokerOptionIds.contains,
    ),
  );
}

GameRunConfig _config(
  LevelAttemptConfig attempt, {
  int? highestUnlockedLevel,
  Set<int> clearedLevelIds = const <int>{},
  Set<String> unlockedJokerIds = const <String>{},
  String? runId,
}) => GameRunConfig(
  rngSeed: 42000 + attempt.levelId,
  runId: runId ?? 'level-${attempt.levelId}',
  unlockedJokerIds: unlockedJokerIds,
  levelAttempt: attempt,
  highestUnlockedLevel: highestUnlockedLevel ?? attempt.levelId,
  clearedLevelIds: clearedLevelIds,
);

Future<void> _playOneCard(GameController game) async {
  await game.toggleCard(game.hand.first.uid!);
  final result = await game.playSelected();
  expect(result.ok, isTrue, reason: result.message);
}

Future<void> _playPairOfRank(GameController game, CardRank rank) async {
  final pair = game.hand
      .where((card) => card.rank == rank)
      .take(2)
      .toList(growable: false);
  expect(pair, hasLength(2), reason: 'authored Level 11 layout lost $rank');
  for (final card in pair) {
    await game.toggleCard(card.uid!);
  }
  final result = await game.playSelected();
  expect(result.ok, isTrue, reason: result.message);
}

Future<void> _noWait(Duration _) async {}

class _Harness {
  final List<String> writes = <String>[];
  final List<RunCheckpoint> checkpoints = <RunCheckpoint>[];
  final List<AccountMutation> mutations = <AccountMutation>[];
  var clears = 0;

  late final GamePersistenceCallbacks callbacks = GamePersistenceCallbacks(
    writeRun: (encoded, checkpoint) async {
      writes.add(encoded);
      checkpoints.add(checkpoint);
    },
    clearRun: () async {
      clears++;
    },
    mutateAccount: (mutation) async {
      mutations.add(mutation);
      return true;
    },
  );
}
