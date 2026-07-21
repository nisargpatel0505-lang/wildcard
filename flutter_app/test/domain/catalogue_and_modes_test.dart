import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';

void main() {
  test('Joker catalogue mirrors all 57 shipped definitions', () {
    expect(jokerCatalog, hasLength(57));
    expect(jokerCatalog.map((joker) => joker.id).toSet(), hasLength(57));
    expect(jokerCatalog.map((joker) => joker.name).toSet(), hasLength(57));
    expect(jokerCatalog.where((joker) => joker.starter), hasLength(10));
    expect(
      jokerCatalog.where((joker) => joker.rarity == JokerRarity.common),
      hasLength(17),
    );
    expect(
      jokerCatalog.where((joker) => joker.rarity == JokerRarity.uncommon),
      hasLength(17),
    );
    expect(
      jokerCatalog.where((joker) => joker.rarity == JokerRarity.rare),
      hasLength(16),
    );
    expect(
      jokerCatalog.where((joker) => joker.rarity == JokerRarity.wild),
      hasLength(7),
    );
    expect(
      jokerCatalog.every((joker) => joker.price >= 0 && joker.unlock >= 0),
      isTrue,
    );
  });

  test('rarity-weighted collection costs preserve the 10,875 coin sink', () {
    final paid = jokerCatalog.where((joker) => joker.unlock > 0);
    expect(paid, hasLength(47));
    expect(
      paid.fold<int>(0, (total, joker) => total + joker.collectionUnlockCost),
      10875,
    );
  });

  test('standard and early-Endless modifier cadence is every third Heat', () {
    for (final heat in <int>[1, 2, 4, 5, 7, 8, 10, 11, 13, 14, 16, 17]) {
      final state = ScoringState(rngSeed: 1, stage: heat, endless: heat > 12);
      expect(ModifierSelector(state).assignForCurrentHeat(), isEmpty);
    }
    for (final heat in <int>[3, 6, 9, 15, 18, 21]) {
      final state = ScoringState(rngSeed: 1, stage: heat, endless: heat > 12);
      final selected = ModifierSelector(state).assignForCurrentHeat();
      expect(selected, hasLength(1));
      expect(selected.single.minHeat, lessThanOrEqualTo(heat));
    }
    final boss = ScoringState(rngSeed: 1, stage: 12);
    expect(ModifierSelector(boss).assignForCurrentHeat(), const <HeatModifier>[
      HeatModifier.theHouse,
    ]);
  });

  test('late Endless stacks two distinct modifiers including a hard rule', () {
    final state = ScoringState(rngSeed: 1, stage: 51, endless: true);
    final selected = ModifierSelector(state).assignForCurrentHeat();
    expect(selected, hasLength(2));
    expect(selected.toSet(), hasLength(2));
    expect(selected.any((modifier) => modifier.isHard), isTrue);
  });

  test('Gauntlet modifies all eight Heats and ends with THE HOUSE', () {
    for (var heat = 1; heat < gauntletHeats; heat++) {
      expect(
        ModifierSelector(
          ScoringState(rngSeed: 1, stage: heat, mode: RunMode.gauntlet),
        ).assignForCurrentHeat(),
        hasLength(1),
      );
    }
    expect(
      ModifierSelector(
        ScoringState(rngSeed: 1, stage: gauntletHeats, mode: RunMode.gauntlet),
      ).assignForCurrentHeat(),
      const <HeatModifier>[HeatModifier.theHouse],
    );
  });

  test(
    'targets preserve Normal, modifier, Boss, Endless and Gauntlet curves',
    () {
      expect(ScoringState(rngSeed: 1, stage: 1).target, 90);
      expect(ScoringState(rngSeed: 1, stage: 13, endless: true).target, 2650);
      expect(ScoringState(rngSeed: 1, stage: 20, endless: true).target, 6850);
      expect(ScoringState(rngSeed: 1, stage: 21, endless: true).target, 7485);
      expect(ScoringState(rngSeed: 1, stage: 35, endless: true).target, 23725);
      expect(ScoringState(rngSeed: 1, stage: 36, endless: true).target, 25475);
      expect(ScoringState(rngSeed: 1, stage: 50, endless: true).target, 70975);
      expect(ScoringState(rngSeed: 1, stage: 51, endless: true).target, 75725);
      expect(
        ScoringState(
          rngSeed: 1,
          stage: 12,
          modifier: HeatModifier.theHouse,
        ).target,
        2255,
      );
      expect(
        ScoringState(rngSeed: 1, stage: 3, modifier: HeatModifier.tax).target,
        236,
      );
      expect(
        ScoringState(rngSeed: 1, stage: 8, mode: RunMode.gauntlet).target,
        1104,
      );
    },
  );

  test('difficulty rounds before boss and Daily is always Medium', () {
    expect(
      ScoringState(
        rngSeed: 1,
        stage: 12,
        difficulty: RunDifficulty.easy,
        modifier: HeatModifier.theHouse,
      ).target,
      1692,
    );
    expect(
      ScoringState(
        rngSeed: 1,
        stage: 12,
        modifier: HeatModifier.theHouse,
      ).target,
      2255,
    );
    expect(
      ScoringState(
        rngSeed: 1,
        stage: 12,
        difficulty: RunDifficulty.hard,
        modifier: HeatModifier.theHouse,
      ).target,
      2932,
    );
    expect(
      ScoringState(
        rngSeed: 1,
        stage: 1,
        mode: RunMode.daily,
        difficulty: RunDifficulty.hard,
      ).target,
      90,
    );
  });
}
