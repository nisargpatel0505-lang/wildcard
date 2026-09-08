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
  'flushfund',
  'wire',
];

/// Three readable build routes, without consuming any deck/shop/luck RNG.
List<JokerDefinition> astraStarterChoices(int seed) {
  final offset = (seed & 0x7fffffff) % astraStarterJokerIds.length;
  return List<JokerDefinition>.unmodifiable(
    List<JokerDefinition>.generate(
      astraStarterJokerIds.length,
      (index) =>
          jokersById[astraStarterJokerIds[(index + offset) %
              astraStarterJokerIds.length]]!,
    ),
  );
}

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
