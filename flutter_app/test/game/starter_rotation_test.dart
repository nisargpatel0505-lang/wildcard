import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/astra_progression.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/random_streams.dart';
import 'package:wildcard/game/game_controller.dart';
import 'package:wildcard/game/game_models.dart';

void main() {
  final allPublic = jokerCatalog.map((joker) => joker.id).toSet();

  test(
    'one random available candidate per distinct engine, stable per seed',
    () {
      final seen = {
        for (final engine in StarterEngine.values) engine: <String>{},
      };
      for (var seed = 0; seed < 200; seed++) {
        final draft = astraStarterDraft(seed, unlockedJokerIds: allPublic);
        final again = astraStarterDraft(seed, unlockedJokerIds: allPublic);
        final firstIds = draft.map((pool) => pool.first.id).toSet();
        expect(firstIds, hasLength(3));
        for (final engine in StarterEngine.values) {
          final pool = draft[engine.index];
          expect(
            pool.map((joker) => joker.id),
            again[engine.index].map((joker) => joker.id),
          );
          expect(
            pool.map((joker) => joker.id).toSet(),
            starterEnginePool(
              engine,
              unlockedJokerIds: allPublic,
            ).map((joker) => joker.id).toSet(),
          );
          seen[engine]!.add(pool.first.id);
        }
      }
      for (final engine in StarterEngine.values) {
        expect(seen[engine]!.length, greaterThan(1));
      }
    },
  );

  test(
    'new players never borrow locked cards; unlocking expands only its lane',
    () {
      final fresh = astraStarterDraft(91);
      for (final pool in fresh) {
        expect(pool, isNotEmpty);
        expect(pool.every((joker) => joker.starter), isTrue);
      }
      final owned = {
        ...starterJokerIds,
        'wire',
        'flushfund',
        'trainer',
        'devx20',
      };
      final draft = astraStarterDraft(91, unlockedJokerIds: owned);
      expect(draft[0].map((joker) => joker.id), contains('trainer'));
      expect(draft[1].map((joker) => joker.id), contains('flushfund'));
      expect(draft[2].map((joker) => joker.id), contains('wire'));
      expect(
        draft.expand((pool) => pool).any((joker) => joker.id == 'devx20'),
        false,
      );
      expect(
        owned,
        contains('devx20'),
      ); // Browsing never rewrites account state.
      expect(canUseAstraStarter('wire', const []), isFalse);
      expect(canUseAstraStarter('wire', owned), isTrue);
      expect(canUseAstraStarter('devx20', owned), isFalse);
      expect(canUseAstraStarter('unknown', owned), isFalse);
    },
  );

  test(
    'direct start refuses locked, developer and off-engine starter injection',
    () async {
      for (final id in ['wire', 'devx20', 'unknown', 'copper']) {
        final run = await GameController.startNew(
          config: GameRunConfig(
            rngSeed: 1827,
            startBoostJokerId: id,
            unlockedJokerIds: {...starterJokerIds, 'devx20'},
          ),
          callbacks: GamePersistenceCallbacks.memoryOnly(),
          wait: (_) async {},
        );
        expect(run.state.jokerIds, isEmpty, reason: id);
        expect(run.startBoostCost, 0);
        run.dispose();
      }
    },
  );

  test(
    'unlocked engine starters are free and preserve all opening RNG streams',
    () async {
      GameController? reference;
      final ids = astraStarterDraft(
        27,
        unlockedJokerIds: allPublic,
      ).expand((pool) => pool).map((joker) => joker.id);
      for (final id in ids) {
        final run = await GameController.startNew(
          config: GameRunConfig(
            rngSeed: 1827,
            startBoostJokerId: id,
            startBoostCost: 999,
            unlockedJokerIds: allPublic,
          ),
          callbacks: GamePersistenceCallbacks.memoryOnly(),
          wait: (_) async {},
        );
        expect(run.state.jokerIds, [id]);
        expect(run.startBoostCost, 0);
        expect(run.unlockedJokerIds, allPublic);
        reference ??= run;
        expect(
          run.hand.map((card) => card.toJson()),
          reference.hand.map((card) => card.toJson()),
        );
        for (final stream in RandomStream.values) {
          expect(
            run.state.rngCounters[stream],
            reference.state.rngCounters[stream],
          );
        }
        if (!identical(run, reference)) run.dispose();
      }
      reference?.dispose();
    },
  );

  test(
    'Gauntlet starter remains paid, Daily still has no draft additions',
    () async {
      final gauntlet = await GameController.startNew(
        config: GameRunConfig(
          mode: RunMode.gauntlet,
          rngSeed: 81,
          startBoostJokerId: 'wire',
          startBoostCost: 10,
          unlockedJokerIds: {'wire'},
        ),
        callbacks: GamePersistenceCallbacks.memoryOnly(),
        wait: (_) async {},
      );
      expect(gauntlet.startBoostCost, 10);
      gauntlet.dispose();
      final daily = await GameController.startNew(
        config: GameRunConfig(
          mode: RunMode.daily,
          rngSeed: 81,
          dailyDate: '2026-09-08',
        ),
        callbacks: GamePersistenceCallbacks.memoryOnly(),
        wait: (_) async {},
      );
      expect(daily.state.jokerIds, isEmpty);
      daily.dispose();
    },
  );
}
