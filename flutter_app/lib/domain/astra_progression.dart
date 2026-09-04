import 'game_rules.dart';
import 'joker_catalog.dart';

/// Opt-in experiment shipped in a separate application package.
const bool astraEnabled = bool.fromEnvironment('WILDCARD_ASTRA_BUILD');

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

bool usesAstraEconomy(RunMode mode, {bool enabled = astraEnabled}) =>
    enabled && mode == RunMode.normal;

/// Earned on clear, never for restarting or abandoning. Three Heat checkpoints
/// add a small milestone; a completed run pays 104 before the win bonus.
int astraAccountReward(int heat) => heat < 1 ? 0 : 8 + (heat % 3 == 0 ? 2 : 0);

/// The first shop can buy a second Joker even after a slow clear. This is run
/// money, not account money, and expires when the run ends.
int astraRunReward(int heat) => runReward(heat) + (heat <= 3 ? 3 : 0);

bool astraOpeningShop(int heat, {bool endless = false}) =>
    !endless && heat >= 1 && heat <= 3;

int astraWoodVaultPrice(int unlockedCount) => unlockedCount < 15 ? 60 : 100;
const int astraGoldVaultPrice = 300;
