import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';

void main() {
  test('Joker catalogue mirrors all 102 public definitions', () {
    expect(jokerCatalog, hasLength(102));
    expect(jokerCatalog.map((joker) => joker.id).toSet(), hasLength(102));
    expect(jokerCatalog.map((joker) => joker.name).toSet(), hasLength(102));
    expect(
      jokerCatalog.map((joker) => joker.effect).toSet(),
      hasLength(102),
      reason: 'every public Joker must own one distinct gameplay effect',
    );
    final starters = jokerCatalog.where((joker) => joker.starter).toList();
    expect(starters, hasLength(10));
    expect(
      <JokerRarity, int>{
        for (final rarity in JokerRarity.values)
          rarity: jokerCatalog.where((joker) => joker.rarity == rarity).length,
      },
      const <JokerRarity, int>{
        JokerRarity.common: 36,
        JokerRarity.uncommon: 36,
        JokerRarity.rare: 23,
        JokerRarity.wild: 7,
      },
    );
    expect(
      <JokerRarity, int>{
        for (final rarity in JokerRarity.values)
          rarity: starters.where((joker) => joker.rarity == rarity).length,
      },
      const <JokerRarity, int>{
        JokerRarity.common: 8,
        JokerRarity.uncommon: 0,
        JokerRarity.rare: 2,
        JokerRarity.wild: 0,
      },
    );
    expect(
      jokerCatalog.every((joker) => joker.price >= 0 && joker.unlock >= 0),
      isTrue,
    );
    expect(jokersById['copper']!.rarity, JokerRarity.common);
    expect(jokersById['presser']!.rarity, JokerRarity.common);
    expect(jokersById['polish']!.rarity, JokerRarity.rare);
    expect(jokersById['roller']!.rarity, JokerRarity.rare);
    expect(
      jokersById['warm_up']!.rarity.index,
      greaterThanOrEqualTo(JokerRarity.uncommon.index),
    );
    expect(
      jokersById['marathoner']!.rarity.index,
      greaterThanOrEqualTo(JokerRarity.uncommon.index),
    );
    for (final joker in jokerCatalog) {
      final (minimum, maximum) = switch (joker.rarity) {
        JokerRarity.common => (4, 6),
        JokerRarity.uncommon => (5, 7),
        JokerRarity.rare => (6, 8),
        JokerRarity.wild => (10, 12),
      };
      expect(
        joker.price,
        inInclusiveRange(minimum, maximum),
        reason: '${joker.id} must stay inside its measured rarity price band',
      );
    }
  });

  test('rarity-weighted collection costs cover all 92 paid Jokers', () {
    final paid = jokerCatalog.where((joker) => joker.unlock > 0);
    expect(paid, hasLength(92));
    expect(
      paid.fold<int>(0, (total, joker) => total + joker.collectionUnlockCost),
      18035,
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
      1353,
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
