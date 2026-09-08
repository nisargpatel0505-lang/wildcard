import 'dart:math' as math;

import 'game_rules.dart';
import 'joker_catalog.dart';

/// Opt-in experiment shipped in a separate application package.
const bool astraEnabled = bool.fromEnvironment('WILDCARD_ASTRA_BUILD');

/// The approved Astra presentation and progression now ship in WILDCARD.
/// Keep this separate from [astraEnabled], which isolates experimental builds
/// from production services, package identity, purchases and paid entitlements.
const bool astraExperienceEnabled = true;

const List<String> astraStarterJokerIds = <String>[
  'polish',
  'uniform',
  'fulltable',
];

/// The three hand-building routes used by the approved opening draft.
/// These are starter roles, not a replacement for collection rarity/effects.
enum StarterEngine { pairs, suits, straights }

const Map<StarterEngine, List<String>> _engineStarterIds = {
  StarterEngine.pairs: [
    'polish',
    'trainer',
    'frequency_meter',
    'tailor',
    'two_faced',
    'understudy',
    'twin_study',
    'alchemist',
  ],
  StarterEngine.suits: [
    'uniform',
    'presser',
    'flushfund',
    'inktrade',
    'pocketflush',
    'color_wash',
    'prism_lens',
    'ice_pick',
    'union_boss',
    'gravedigger',
    'rose_tint',
    'monochrome',
    'suit_swap',
  ],
  StarterEngine.straights: [
    'fulltable',
    'wire',
    'shortcut',
    'gap_filler',
    'cheat',
  ],
};

/// Ordered, public and available candidates for a single engine. The public
/// starter set is always available, including during new-save onboarding.
/// Generic support Jokers stay in run shops; they do not pretend to define a
/// Pair/Suit/Straight route. No locked or developer Joker can enter a draft.
List<JokerDefinition> starterEnginePool(
  StarterEngine engine, {
  Iterable<String> unlockedJokerIds = const <String>[],
}) {
  final owned = unlockedJokerIds.toSet();
  final publicById = {for (final joker in jokerCatalog) joker.id: joker};
  return List<JokerDefinition>.unmodifiable([
    for (final id in _engineStarterIds[engine]!)
      if (publicById[id] case final joker?)
        if (joker.starter || owned.contains(id)) joker,
  ]);
}

bool canUseAstraStarter(String id, Iterable<String> unlockedJokerIds) =>
    StarterEngine.values.any(
      (engine) => starterEnginePool(
        engine,
        unlockedJokerIds: unlockedJokerIds,
      ).any((joker) => joker.id == id),
    );

/// A random first candidate per engine. Every list can then be cycled without
/// further RNG. This local RNG is deliberately separate from all gameplay
/// streams: browsing the draft never rerolls the deal, shops or Joker luck.
List<List<JokerDefinition>> astraStarterDraft(
  int seed, {
  Iterable<String> unlockedJokerIds = const <String>[],
}) => List<List<JokerDefinition>>.unmodifiable([
  for (final engine in StarterEngine.values)
    (() {
      final pool = starterEnginePool(
        engine,
        unlockedJokerIds: unlockedJokerIds,
      );
      final offset = math.Random(
        (seed & 0x7fffffff) ^ ((engine.index + 1) * 0x45d9f3b),
      ).nextInt(pool.length);
      return List<JokerDefinition>.unmodifiable([
        ...pool.skip(offset),
        ...pool.take(offset),
      ]);
    })(),
]);

List<JokerDefinition> astraStarterChoices(
  int seed, {
  Iterable<String> unlockedJokerIds = const <String>[],
}) => List<JokerDefinition>.unmodifiable([
  for (final pool in astraStarterDraft(
    seed,
    unlockedJokerIds: unlockedJokerIds,
  ))
    pool.first,
]);

bool usesAstraEconomy(RunMode mode, {bool enabled = astraExperienceEnabled}) =>
    enabled && mode == RunMode.normal;

/// Earned on clear, never for restarting or abandoning. A Normal clear pays
/// 102 before its one-time 20-coin completion bonus. Endless stays at 13 per
/// Heat: extrapolating the three-Heat bands indefinitely would make total
/// currency grow quadratically in run length.
int astraAccountReward(int heat) =>
    heat < 1 ? 0 : 4 + 3 * ((heat - 1) ~/ 3).clamp(0, 3);

/// Account rewards are shared by Normal and Gauntlet, while Daily remains a
/// fixed-seed score challenge with its existing mission/achievement rewards.
int modeAccountReward(RunMode mode, int heat) => mode == RunMode.daily
    ? 0
    : astraExperienceEnabled
    ? astraAccountReward(heat)
    : accountReward(heat);

int modeCompletionBonus(RunMode mode) => switch (mode) {
  RunMode.daily => 0,
  RunMode.gauntlet => 10,
  RunMode.normal => astraExperienceEnabled ? 20 : 10,
};

/// Optional run-end advertising shares the five-placement daily allowance.
/// It can match a short run's earnings, but never doubles an entire deep run.
int astraRunAdBonus(int baseCoins) => baseCoins.clamp(0, 25);

/// The first shop can buy a second Joker even after a slow clear. This is run
/// money, not account money, and expires when the run ends.
int astraRunReward(int heat) => runReward(heat) + (heat <= 3 ? 3 : 0);

bool astraOpeningShop(int heat, {bool endless = false}) =>
    !endless && heat >= 1 && heat <= 3;

int astraWoodVaultPrice(int unlockedCount) => unlockedCount < 15 ? 60 : 100;
const int astraGoldVaultPrice = 300;
