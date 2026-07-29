import '../core/daily_utc_date.dart';
import 'joker_catalog.dart';

/// Progression and collection constants recovered from the shipped v7.1.0
/// Android client (versionCode 45). This file is deliberately UI-agnostic.

enum CosmeticKind { table, theme, sly }

class CosmeticDefinition {
  const CosmeticDefinition({
    required this.id,
    required this.kind,
    required this.name,
    required this.rarity,
    required this.price,
    required this.description,
    this.skin,
  });

  final String id;
  final CosmeticKind kind;
  final String name;
  final JokerRarity rarity;
  final int price;
  final String description;
  final String? skin;

  bool get isDefault => price == 0;
}

const List<CosmeticDefinition> cosmeticCatalog = <CosmeticDefinition>[
  CosmeticDefinition(
    id: 'felt_classic',
    kind: CosmeticKind.table,
    name: 'Classic Casino Felt',
    rarity: JokerRarity.common,
    price: 0,
    description: 'The house green. Always owned.',
  ),
  CosmeticDefinition(
    id: 'felt_neon',
    kind: CosmeticKind.table,
    name: 'Neon Arcade Table',
    rarity: JokerRarity.uncommon,
    price: 250,
    description: 'Electric grid glow under your cards.',
  ),
  CosmeticDefinition(
    id: 'felt_royal',
    kind: CosmeticKind.table,
    name: 'Royal Gold Table',
    rarity: JokerRarity.rare,
    price: 500,
    description: 'Deep burgundy and gold trim. Very fancy.',
  ),
  CosmeticDefinition(
    id: 'felt_void',
    kind: CosmeticKind.table,
    name: 'Void Black Table',
    rarity: JokerRarity.rare,
    price: 650,
    description: 'Bottomless black with a violet event horizon.',
  ),
  CosmeticDefinition(
    id: 'felt_jade',
    kind: CosmeticKind.table,
    name: 'Jade Dragon Table',
    rarity: JokerRarity.uncommon,
    price: 400,
    description: 'Deep jade with a golden shimmer.',
  ),
  CosmeticDefinition(
    id: 'felt_ocean',
    kind: CosmeticKind.table,
    name: 'Deep Ocean Table',
    rarity: JokerRarity.uncommon,
    price: 450,
    description: 'Abyssal blues with a bioluminescent glow.',
  ),
  CosmeticDefinition(
    id: 'felt_crimson',
    kind: CosmeticKind.table,
    name: 'Crimson VIP Table',
    rarity: JokerRarity.rare,
    price: 550,
    description: 'Back-room red. Members only.',
  ),
  CosmeticDefinition(
    id: 'felt_galaxy',
    kind: CosmeticKind.table,
    name: 'Galaxy Table',
    rarity: JokerRarity.wild,
    price: 800,
    description: 'Play your hands on a spiral of stars.',
  ),
  CosmeticDefinition(
    id: 'felt_circuit',
    kind: CosmeticKind.table,
    name: 'Circuit Board Table',
    rarity: JokerRarity.uncommon,
    price: 350,
    description: 'Live PCB traces pulse under the cards.',
  ),
  CosmeticDefinition(
    id: 'felt_sakura',
    kind: CosmeticKind.table,
    name: 'Sakura Table',
    rarity: JokerRarity.rare,
    price: 600,
    description: 'Soft blossom pink with drifting petal light.',
  ),
  CosmeticDefinition(
    id: 'felt_herringbone',
    kind: CosmeticKind.table,
    name: 'Herringbone',
    rarity: JokerRarity.common,
    price: 250,
    description: 'Tailored charcoal felt with a precise card-room weave.',
  ),
  CosmeticDefinition(
    id: 'felt_art_deco',
    kind: CosmeticKind.table,
    name: 'Art-Deco Sunburst',
    rarity: JokerRarity.common,
    price: 350,
    description: 'Midnight blue rays framed in old-casino gold.',
  ),
  CosmeticDefinition(
    id: 'felt_honeycomb',
    kind: CosmeticKind.table,
    name: 'Honeycomb',
    rarity: JokerRarity.uncommon,
    price: 450,
    description: 'Warm amber cells laid across deep aubergine felt.',
  ),
  CosmeticDefinition(
    id: 'felt_tartan',
    kind: CosmeticKind.table,
    name: 'Tartan',
    rarity: JokerRarity.uncommon,
    price: 550,
    description: 'A sharp casino plaid in wine, navy and antique gold.',
  ),
  CosmeticDefinition(
    id: 'felt_circuit_v2',
    kind: CosmeticKind.table,
    name: 'Circuit-Board v2',
    rarity: JokerRarity.rare,
    price: 650,
    description: 'Layered arcade traces route every hand to the jackpot.',
  ),
  CosmeticDefinition(
    id: 'felt_nebula',
    kind: CosmeticKind.table,
    name: 'Nebula Felt',
    rarity: JokerRarity.rare,
    price: 800,
    description: 'A quiet violet cloud scattered with distant card stars.',
  ),
  CosmeticDefinition(
    id: 'felt_midnight_velvet',
    kind: CosmeticKind.table,
    name: 'Midnight Velvet',
    rarity: JokerRarity.rare,
    price: 2200,
    description: 'Blue-black velvet with a restrained royal nap.',
  ),
  CosmeticDefinition(
    id: 'felt_emerald_royale',
    kind: CosmeticKind.table,
    name: 'Emerald Casino Royale',
    rarity: JokerRarity.wild,
    price: 2500,
    description: 'Emerald damask worthy of the highest-stakes room.',
  ),
  CosmeticDefinition(
    id: 'felt_neon_grid',
    kind: CosmeticKind.table,
    name: 'Neon Grid',
    rarity: JokerRarity.wild,
    price: 2750,
    description: 'A crisp synthwave grid in electric cyan and magenta.',
  ),
  CosmeticDefinition(
    id: 'felt_obsidian_marble',
    kind: CosmeticKind.table,
    name: 'Obsidian Marble',
    rarity: JokerRarity.wild,
    price: 3000,
    description: 'Polished black stone cut with fine violet-gold veins.',
  ),
  CosmeticDefinition(
    id: 'theme_default',
    kind: CosmeticKind.theme,
    name: 'Arcade Mint',
    rarity: JokerRarity.common,
    price: 0,
    description: 'The original mint & gold look.',
  ),
  CosmeticDefinition(
    id: 'theme_sunset',
    kind: CosmeticKind.theme,
    name: 'Sunset Strip',
    rarity: JokerRarity.uncommon,
    price: 1000,
    description:
        'Warm coral and amber accents — and a dusk-lit background to match.',
  ),
  CosmeticDefinition(
    id: 'theme_ice',
    kind: CosmeticKind.theme,
    name: 'Ice Casino',
    rarity: JokerRarity.rare,
    price: 1000,
    description:
        'Cool cyan and steel throughout — the whole room freezes over.',
  ),
  CosmeticDefinition(
    id: 'theme_neon_elite',
    kind: CosmeticKind.theme,
    name: 'Neon Arcade Elite',
    rarity: JokerRarity.wild,
    price: 1000,
    description:
        'Premium neon green and neon purple UI, with a full arcade background takeover.',
  ),
  CosmeticDefinition(
    id: 'theme_gold',
    kind: CosmeticKind.theme,
    name: 'Midas Touch',
    rarity: JokerRarity.rare,
    price: 1000,
    description: 'Everything you tap turns gold.',
  ),
  CosmeticDefinition(
    id: 'theme_vapor',
    kind: CosmeticKind.theme,
    name: 'Vaporwave',
    rarity: JokerRarity.rare,
    price: 1000,
    description: 'Hot pink and cyber cyan. A E S T H E T I C.',
  ),
  CosmeticDefinition(
    id: 'theme_blood',
    kind: CosmeticKind.theme,
    name: 'Blood Moon',
    rarity: JokerRarity.uncommon,
    price: 1000,
    description: 'Crimson accents for high-stakes nights.',
  ),
  CosmeticDefinition(
    id: 'theme_cosmic',
    kind: CosmeticKind.theme,
    name: 'Cosmic Wilds',
    rarity: JokerRarity.wild,
    price: 1000,
    description:
        'A dark violet card-cosmos with mint constellations and a neon horizon.',
  ),
  CosmeticDefinition(
    id: 'theme_neon_heist',
    kind: CosmeticKind.theme,
    name: 'Neon Heist',
    rarity: JokerRarity.wild,
    price: 5000,
    description:
        'A premium Sly room: rain, laser grids and the score of the century.',
  ),
  CosmeticDefinition(
    id: 'theme_moonlit_mask',
    kind: CosmeticKind.theme,
    name: 'Moonlit Masquerade',
    rarity: JokerRarity.rare,
    price: 3500,
    description:
        'A premium Sly room of silver moonlight, royal masks and dangerous elegance.',
  ),
  CosmeticDefinition(
    id: 'theme_ember',
    kind: CosmeticKind.theme,
    name: 'Ember Casino',
    rarity: JokerRarity.rare,
    price: 3500,
    description: 'A premium Sly room of obsidian tables and molten gold.',
  ),
  CosmeticDefinition(
    id: 'theme_emerald_throne',
    kind: CosmeticKind.theme,
    name: 'Emerald Throne',
    rarity: JokerRarity.wild,
    price: 5000,
    description:
        'A premium Sly room of ancient jade, jungle mist and a royal throne.',
  ),
  CosmeticDefinition(
    id: 'theme_haunted',
    kind: CosmeticKind.theme,
    name: 'Haunted Carnival',
    rarity: JokerRarity.rare,
    price: 3500,
    description: 'A premium Sly room of ghost lights and crooked card tents.',
  ),
  CosmeticDefinition(
    id: 'theme_clockwork',
    kind: CosmeticKind.theme,
    name: 'Clockwork Royale',
    rarity: JokerRarity.wild,
    price: 5000,
    description:
        'A premium Sly room of brass gears, sapphire clocks and a calculated house edge.',
  ),
  CosmeticDefinition(
    id: 'theme_block_drop',
    kind: CosmeticKind.theme,
    name: 'Block Drop Arcade',
    rarity: JokerRarity.wild,
    price: 1000,
    description:
        'A geometric neon arcade where every falling block raises the stakes.',
  ),
  CosmeticDefinition(
    id: 'theme_abyssal',
    kind: CosmeticKind.theme,
    name: 'Abyssal Jackpot',
    rarity: JokerRarity.rare,
    price: 1000,
    description:
        'A submerged casino cathedral lit by coral, pearls and cold blue luck.',
  ),
  CosmeticDefinition(
    id: 'theme_desert_mirage',
    kind: CosmeticKind.theme,
    name: 'Desert Mirage',
    rarity: JokerRarity.rare,
    price: 1000,
    description:
        'An open-air card palace of turquoise glass, sunlit stone and gold.',
  ),
  CosmeticDefinition(
    id: 'sly_classic',
    kind: CosmeticKind.sly,
    name: 'Sly Classic',
    rarity: JokerRarity.common,
    price: 0,
    description: 'Your smug dealer, as nature intended.',
  ),
  CosmeticDefinition(
    id: 'sly_gold',
    kind: CosmeticKind.sly,
    name: 'Sly Gold Suit',
    rarity: JokerRarity.rare,
    price: 750,
    description: 'Sly in a gold suit. Insufferably rich.',
    skin: 'gold',
  ),
  CosmeticDefinition(
    id: 'sly_shadow',
    kind: CosmeticKind.sly,
    name: 'Sly Shadow',
    rarity: JokerRarity.rare,
    price: 700,
    description: 'A cold, masked version of Sly.',
    skin: 'shadow',
  ),
  CosmeticDefinition(
    id: 'sly_robot',
    kind: CosmeticKind.sly,
    name: 'Sly-2000',
    rarity: JokerRarity.uncommon,
    price: 400,
    description: 'A dealer android. Beep boop, weak hand.',
    skin: 'robot',
  ),
  CosmeticDefinition(
    id: 'sly_king',
    kind: CosmeticKind.sly,
    name: 'King Sly',
    rarity: JokerRarity.rare,
    price: 650,
    description: 'He crowned himself. Nobody argued.',
    skin: 'king',
  ),
  CosmeticDefinition(
    id: 'sly_alien',
    kind: CosmeticKind.sly,
    name: 'Sly From Beyond',
    rarity: JokerRarity.uncommon,
    price: 450,
    description: 'Probing your strategy since 1947.',
    skin: 'alien',
  ),
  CosmeticDefinition(
    id: 'sly_devil',
    kind: CosmeticKind.sly,
    name: 'Sly, Actually',
    rarity: JokerRarity.rare,
    price: 800,
    description: 'The house edge, personified.',
    skin: 'devil',
  ),
  CosmeticDefinition(
    id: 'sly_clown',
    kind: CosmeticKind.sly,
    name: 'Bozo Sly',
    rarity: JokerRarity.uncommon,
    price: 350,
    description: 'Honks when you misplay. (Not really.)',
    skin: 'clown',
  ),
  CosmeticDefinition(
    id: 'sly_block_drop',
    kind: CosmeticKind.sly,
    name: 'Block Drop Sly',
    rarity: JokerRarity.wild,
    price: 5000,
    description:
        'Sly rebuilt in sharp neon pixels for the ultimate high score.',
    skin: 'blockDrop',
  ),
  CosmeticDefinition(
    id: 'sly_abyssal',
    kind: CosmeticKind.sly,
    name: 'Abyssal Sly',
    rarity: JokerRarity.wild,
    price: 5000,
    description: 'The deep-sea dealer who always knows what is below the deck.',
    skin: 'abyssal',
  ),
  CosmeticDefinition(
    id: 'sly_desert',
    kind: CosmeticKind.sly,
    name: 'Mirage Sly',
    rarity: JokerRarity.rare,
    price: 5000,
    description: 'A sunlit card sharp dressed for the palace beyond the dunes.',
    skin: 'desertMirage',
  ),
];

const Set<String> defaultCosmeticIds = <String>{
  'felt_classic',
  'theme_default',
  'sly_classic',
};

CosmeticDefinition? cosmeticById(String id) {
  for (final cosmetic in cosmeticCatalog) {
    if (cosmetic.id == id) return cosmetic;
  }
  return null;
}

const int cosmeticVaultPrice = 1000;
const double cosmeticVaultThemeGate = 0.008;
const Map<JokerRarity, int> cosmeticVaultRarityWeights = <JokerRarity, int>{
  JokerRarity.common: 0,
  JokerRarity.uncommon: 6,
  JokerRarity.rare: 3,
  JokerRarity.wild: 1,
};

int _cosmeticWeight(CosmeticDefinition cosmetic) {
  final weight = cosmeticVaultRarityWeights[cosmetic.rarity] ?? 1;
  // JavaScript uses `(weight || 1)`, so its explicit zero also falls back to 1.
  return weight == 0 ? 1 : weight;
}

/// Exact live rarity odds for the Cosmetic Vault's current unowned pool.
///
/// This mirrors both stages of [rollCosmeticVault]: the theme gate when both
/// sides remain, then the per-item rarity weights within the selected side.
Map<JokerRarity, double> cosmeticVaultEffectiveOdds(
  Iterable<CosmeticDefinition> lockedPool,
) {
  final pool = lockedPool
      .where((cosmetic) => cosmetic.price > 0)
      .toList(growable: false);
  if (pool.isEmpty) return const <JokerRarity, double>{};
  final themes = pool
      .where((cosmetic) => cosmetic.kind == CosmeticKind.theme)
      .toList(growable: false);
  final rest = pool
      .where((cosmetic) => cosmetic.kind != CosmeticKind.theme)
      .toList(growable: false);
  final odds = <JokerRarity, double>{};

  void addPool(List<CosmeticDefinition> source, double poolChance) {
    if (source.isEmpty || poolChance <= 0) return;
    final total = source.fold<int>(
      0,
      (sum, cosmetic) => sum + _cosmeticWeight(cosmetic),
    );
    for (final cosmetic in source) {
      odds[cosmetic.rarity] =
          (odds[cosmetic.rarity] ?? 0) +
          poolChance * _cosmeticWeight(cosmetic) / total;
    }
  }

  if (themes.isNotEmpty && rest.isNotEmpty) {
    addPool(themes, cosmeticVaultThemeGate);
    addPool(rest, 1 - cosmeticVaultThemeGate);
  } else {
    addPool(rest.isNotEmpty ? rest : themes, 1);
  }
  return <JokerRarity, double>{
    for (final rarity in JokerRarity.values)
      if ((odds[rarity] ?? 0) > 0) rarity: odds[rarity]!,
  };
}

/// Exact live reward-kind odds for the Cosmetic Vault's current unowned pool.
///
/// This is kept beside [rollCosmeticVault] so the pre-purchase disclosure
/// cannot drift away from the two-stage theme gate and weighted item draw.
Map<CosmeticKind, double> cosmeticVaultKindOdds(
  Iterable<CosmeticDefinition> lockedPool,
) {
  final pool = lockedPool
      .where((cosmetic) => cosmetic.price > 0)
      .toList(growable: false);
  if (pool.isEmpty) return const <CosmeticKind, double>{};
  final themes = pool
      .where((cosmetic) => cosmetic.kind == CosmeticKind.theme)
      .toList(growable: false);
  final rest = pool
      .where((cosmetic) => cosmetic.kind != CosmeticKind.theme)
      .toList(growable: false);
  final odds = <CosmeticKind, double>{};

  void addPool(List<CosmeticDefinition> source, double poolChance) {
    if (source.isEmpty || poolChance <= 0) return;
    final total = source.fold<int>(
      0,
      (sum, cosmetic) => sum + _cosmeticWeight(cosmetic),
    );
    for (final cosmetic in source) {
      odds[cosmetic.kind] =
          (odds[cosmetic.kind] ?? 0) +
          poolChance * _cosmeticWeight(cosmetic) / total;
    }
  }

  if (themes.isNotEmpty && rest.isNotEmpty) {
    addPool(themes, cosmeticVaultThemeGate);
    addPool(rest, 1 - cosmeticVaultThemeGate);
  } else {
    addPool(rest.isNotEmpty ? rest : themes, 1);
  }
  return <CosmeticKind, double>{
    for (final kind in CosmeticKind.values)
      if ((odds[kind] ?? 0) > 0) kind: odds[kind]!,
  };
}

/// Mirrors the two-random-draw Cosmetic Vault: first the 0.8% UI-theme gate,
/// then a rarity-weighted item draw within the chosen side of the pool.
CosmeticDefinition? rollCosmeticVault(
  List<CosmeticDefinition> lockedPool, {
  required double themeRoll,
  required double itemRoll,
}) {
  final pool = lockedPool
      .where((cosmetic) => cosmetic.price > 0)
      .toList(growable: false);
  if (pool.isEmpty) return null;
  final themes = pool
      .where((cosmetic) => cosmetic.kind == CosmeticKind.theme)
      .toList(growable: false);
  final rest = pool
      .where((cosmetic) => cosmetic.kind != CosmeticKind.theme)
      .toList(growable: false);
  final drawPool = themes.isNotEmpty && rest.isNotEmpty
      ? (themeRoll < cosmeticVaultThemeGate ? themes : rest)
      : (rest.isNotEmpty ? rest : themes);
  final total = drawPool.fold<int>(
    0,
    (sum, cosmetic) => sum + _cosmeticWeight(cosmetic),
  );
  var value = itemRoll.clamp(0.0, 0.9999999999999999) * total;
  for (final cosmetic in drawPool) {
    value -= _cosmeticWeight(cosmetic);
    if (value <= 0) return cosmetic;
  }
  return drawPool.last;
}

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.reward,
  });

  final String id;
  final String name;
  final String description;
  final int reward;
}

const List<AchievementDefinition> achievementCatalog = <AchievementDefinition>[
  AchievementDefinition(
    id: 'first_pair',
    name: 'Pair Programming',
    description: 'Score any Pair-or-better hand.',
    reward: 15,
  ),
  AchievementDefinition(
    id: 'first_flush',
    name: 'Neon Shower',
    description: 'Score a Flush, Straight Flush, or Royal Flush.',
    reward: 25,
  ),
  AchievementDefinition(
    id: 'first_full_house',
    name: 'Packed Table',
    description: 'Score a Full House.',
    reward: 30,
  ),
  AchievementDefinition(
    id: 'first_quad',
    name: 'Four-Lane Jackpot',
    description: 'Score Four of a Kind.',
    reward: 45,
  ),
  AchievementDefinition(
    id: 'heat6',
    name: 'Past The Velvet Rope',
    description: 'Reach Heat 6.',
    reward: 35,
  ),
  AchievementDefinition(
    id: 'five_jokers',
    name: 'Full Marquee',
    description: 'Equip five jokers in one run.',
    reward: 35,
  ),
  AchievementDefinition(
    id: 'sculptor',
    name: 'Deck Surgeon',
    description: 'Destroy five cards in one run.',
    reward: 45,
  ),
  AchievementDefinition(
    id: 'printer',
    name: 'Card Printer',
    description: 'Copy three cards in one run.',
    reward: 40,
  ),
  AchievementDefinition(
    id: 'boosted',
    name: 'Overclocked Hand',
    description: 'Buy three Hand Boosts in one run.',
    reward: 35,
  ),
  AchievementDefinition(
    id: 'wild_joker',
    name: 'Wild Thing',
    description: 'Equip a WILD joker.',
    reward: 60,
  ),
  AchievementDefinition(
    id: 'first_win',
    name: 'Twelve Heat Legend',
    description: 'Clear Heat 12.',
    reward: 200,
  ),
  AchievementDefinition(
    id: 'bankroll',
    name: 'Coin Comet',
    description: 'Hold 500 account coins.',
    reward: 50,
  ),
  AchievementDefinition(
    id: 'first_two_pair',
    name: 'Double Down',
    description: 'Score a Two Pair.',
    reward: 12,
  ),
  AchievementDefinition(
    id: 'first_trips',
    name: "Three's Company",
    description: 'Score Three of a Kind.',
    reward: 18,
  ),
  AchievementDefinition(
    id: 'first_straight',
    name: 'Straight Shooter',
    description: 'Score a Straight.',
    reward: 20,
  ),
  AchievementDefinition(
    id: 'heat3',
    name: 'Warming Up',
    description: 'Reach Heat 3.',
    reward: 20,
  ),
  AchievementDefinition(
    id: 'first_modifier',
    name: 'Feel The Heat',
    description: 'Clear a Heat with a modifier active.',
    reward: 25,
  ),
  AchievementDefinition(
    id: 'first_destroy',
    name: 'Trim The Fat',
    description: 'Destroy a card during a run.',
    reward: 12,
  ),
  AchievementDefinition(
    id: 'heat7',
    name: 'Into The Furnace',
    description: 'Reach Heat 7.',
    reward: 55,
  ),
  AchievementDefinition(
    id: 'score_500_hand',
    name: 'Big Swing',
    description: 'Score 500+ in a single hand.',
    reward: 40,
  ),
  AchievementDefinition(
    id: 'straight_flush',
    name: 'Perfect Signal',
    description: 'Score a Straight Flush or Royal Flush.',
    reward: 50,
  ),
  AchievementDefinition(
    id: 'run_1500',
    name: 'Marathon Runner',
    description: 'Reach 1500 total score in one run.',
    reward: 45,
  ),
  AchievementDefinition(
    id: 'survive_three_mods',
    name: 'Storm Chaser',
    description: 'Clear 3 modified Heats in one run.',
    reward: 45,
  ),
  AchievementDefinition(
    id: 'copy_smith',
    name: 'Duplication Station',
    description: 'Copy five cards in one run.',
    reward: 40,
  ),
  AchievementDefinition(
    id: 'heat10',
    name: 'Double Digits',
    description: 'Reach Heat 10.',
    reward: 90,
  ),
  AchievementDefinition(
    id: 'endless_reach',
    name: 'No Finish Line',
    description: 'Enter Endless (reach Heat 13).',
    reward: 130,
  ),
  AchievementDefinition(
    id: 'score_1500_hand',
    name: 'One-Hand Wonder',
    description: 'Score 1500+ in a single hand.',
    reward: 90,
  ),
  AchievementDefinition(
    id: 'run_6000',
    name: 'Score Machine',
    description: 'Reach 6000 total score in one run.',
    reward: 100,
  ),
  AchievementDefinition(
    id: 'bankroll_2000',
    name: 'High Roller',
    description: 'Hold 2000 account coins.',
    reward: 100,
  ),
  AchievementDefinition(
    id: 'full_wild',
    name: 'Double Wild',
    description: 'Hold two WILD jokers at once.',
    reward: 120,
  ),
  AchievementDefinition(
    id: 'first_enhance',
    name: 'Etched In Neon',
    description: 'Enhance a card with the Enhancer supply.',
    reward: 25,
  ),
  AchievementDefinition(
    id: 'glasswork',
    name: 'Glasswork',
    description: 'Score a hand containing 2+ Glass cards.',
    reward: 60,
  ),
  AchievementDefinition(
    id: 'daily_debut',
    name: 'Regular Customer',
    description: 'Play a Daily Challenge.',
    reward: 30,
  ),
  AchievementDefinition(
    id: 'mission_one',
    name: 'Contract Work',
    description: 'Claim a Weekly Mission reward.',
    reward: 40,
  ),
  AchievementDefinition(
    id: 'titled',
    name: 'Signed Autograph',
    description: 'Wear a title from the Cabinet.',
    reward: 25,
  ),
  AchievementDefinition(
    id: 'couture_5',
    name: 'Dressed To Kill',
    description: 'Own 5 cosmetics.',
    reward: 75,
  ),
  AchievementDefinition(
    id: 'stake_shark',
    name: 'Stake Shark',
    description: 'Turn a profit on a Stake Contract.',
    reward: 50,
  ),
  AchievementDefinition(
    id: 'boost_maniac',
    name: 'Overtuned',
    description: 'Buy 5 Hand Boosts in one run.',
    reward: 60,
  ),
  AchievementDefinition(
    id: 'etched_army',
    name: 'Etched Army',
    description: 'Hold 5 enhanced cards in your deck.',
    reward: 75,
  ),
  AchievementDefinition(
    id: 'monster_hand',
    name: 'Monster Hand',
    description: 'Score 3000+ in a single hand.',
    reward: 150,
  ),
  AchievementDefinition(
    id: 'endless_15',
    name: 'Deep Space',
    description: 'Reach Heat 15.',
    reward: 150,
  ),
  AchievementDefinition(
    id: 'gauntlet_king',
    name: 'Gauntlet Conqueror',
    description: 'Conquer the Gauntlet.',
    reward: 250,
  ),
  AchievementDefinition(
    id: 'veteran_25',
    name: 'House Regular',
    description: 'Play 25 runs.',
    reward: 80,
  ),
  AchievementDefinition(
    id: 'dealer_500',
    name: 'Five Hundred Club',
    description: 'Play 500 hands lifetime.',
    reward: 100,
  ),
];

class ProgressionSnapshot {
  const ProgressionSnapshot({
    this.bestHeat = 0,
    this.bestClearedHeat = 0,
    this.bestScore = 0,
    this.coins = 0,
    this.stage = 0,
    this.stagesCleared = 0,
    this.jokersHeld = 0,
    this.wildJokersHeld = 0,
    this.unlockedJokers = 0,
    this.destroyedCards = 0,
    this.copiedCards = 0,
    this.boostsBought = 0,
    this.bestPlay = 0,
    this.totalScore = 0,
    this.modifiedHeatsCleared = 0,
    this.enhancedCards = 0,
    this.glassDouble = false,
    this.dailyRunPlayed = false,
    this.claimedMissions = 0,
    this.titleEquipped = false,
    this.cosmeticsOwned = 0,
    this.stakePaid = false,
    this.stakeNet = 0,
    this.gauntletWins = 0,
    this.runsPlayed = 0,
    this.handsPlayed = 0,
    this.achievementsEarned = 0,
    this.handTypeCounts = const <String, int>{},
  });

  final int bestHeat;
  final int bestClearedHeat;
  final int bestScore;
  final int coins;
  final int stage;
  final int stagesCleared;
  final int jokersHeld;
  final int wildJokersHeld;
  final int unlockedJokers;
  final int destroyedCards;
  final int copiedCards;
  final int boostsBought;
  final int bestPlay;
  final int totalScore;
  final int modifiedHeatsCleared;
  final int enhancedCards;
  final bool glassDouble;
  final bool dailyRunPlayed;
  final int claimedMissions;
  final bool titleEquipped;
  final int cosmeticsOwned;
  final bool stakePaid;
  final int stakeNet;
  final int gauntletWins;
  final int runsPlayed;
  final int handsPlayed;
  final int achievementsEarned;
  final Map<String, int> handTypeCounts;

  bool hasScored(String handType) => handTypeCounts.containsKey(handType);
}

bool achievementIsDone(String id, ProgressionSnapshot state) {
  switch (id) {
    case 'first_pair':
      return state.handTypeCounts.keys.any((type) => type != 'High Card');
    case 'first_flush':
      return state.handTypeCounts.keys.any((type) => type.contains('Flush'));
    case 'first_full_house':
      return state.hasScored('Full House');
    case 'first_quad':
      return state.hasScored('Four of a Kind');
    case 'heat6':
      return state.bestHeat >= 6 || state.stage >= 6;
    case 'five_jokers':
      return state.jokersHeld >= 5;
    case 'sculptor':
      return state.destroyedCards >= 5;
    case 'printer':
      return state.copiedCards >= 3;
    case 'boosted':
      return state.boostsBought >= 3;
    case 'wild_joker':
      return state.wildJokersHeld >= 1;
    case 'first_win':
      return state.bestClearedHeat >= 12 || state.stagesCleared >= 12;
    case 'bankroll':
      return state.coins >= 500;
    case 'first_two_pair':
      return state.hasScored('Two Pair');
    case 'first_trips':
      return state.hasScored('Three of a Kind');
    case 'first_straight':
      return state.hasScored('Straight');
    case 'heat3':
      return state.bestHeat >= 3 || state.stage >= 3;
    case 'first_modifier':
      return state.modifiedHeatsCleared >= 1;
    case 'first_destroy':
      return state.destroyedCards >= 1;
    case 'heat7':
      return state.bestHeat >= 7 || state.stage >= 7;
    case 'score_500_hand':
      return state.bestPlay >= 500;
    case 'straight_flush':
      return state.hasScored('Straight Flush') ||
          state.hasScored('Royal Flush');
    case 'run_1500':
      return state.totalScore >= 1500;
    case 'survive_three_mods':
      return state.modifiedHeatsCleared >= 3;
    case 'copy_smith':
      return state.copiedCards >= 5;
    case 'heat10':
      return state.bestHeat >= 10 || state.stage >= 10;
    case 'endless_reach':
      return state.bestHeat >= 13 || state.stage >= 13;
    case 'score_1500_hand':
      return state.bestPlay >= 1500;
    case 'run_6000':
      return state.totalScore >= 6000;
    case 'bankroll_2000':
      return state.coins >= 2000;
    case 'full_wild':
      return state.wildJokersHeld >= 2;
    case 'first_enhance':
      return state.enhancedCards >= 1;
    case 'glasswork':
      return state.glassDouble;
    case 'daily_debut':
      return state.dailyRunPlayed;
    case 'mission_one':
      return state.claimedMissions >= 1;
    case 'titled':
      return state.titleEquipped;
    case 'couture_5':
      return state.cosmeticsOwned >= 5;
    case 'stake_shark':
      return state.stakePaid && state.stakeNet > 0;
    case 'boost_maniac':
      return state.boostsBought >= 5;
    case 'etched_army':
      return state.enhancedCards >= 5;
    case 'monster_hand':
      return state.bestPlay >= 3000;
    case 'endless_15':
      return state.bestHeat >= 15 || state.stage >= 15;
    case 'gauntlet_king':
      return state.gauntletWins >= 1;
    case 'veteran_25':
      return state.runsPlayed >= 25;
    case 'dealer_500':
      return state.handsPlayed >= 500;
  }
  return false;
}

class WeeklyContractDefinition {
  const WeeklyContractDefinition({
    required this.id,
    required this.stat,
    required this.target,
    required this.reward,
    required this.name,
    required this.description,
  });

  final String id;
  final String stat;
  final int target;
  final int reward;
  final String name;
  final String description;
}

const List<WeeklyContractDefinition> weeklyContractCatalog =
    <WeeklyContractDefinition>[
      WeeklyContractDefinition(
        id: 'm_heats',
        stat: 'heats',
        target: 35,
        reward: 45,
        name: 'Heat Campaign',
        description: 'Clear 35 Heats across your runs this week.',
      ),
      WeeklyContractDefinition(
        id: 'm_flush',
        stat: 'flush',
        target: 10,
        reward: 45,
        name: 'Flush Hunter',
        description: 'Score 10 Flush-family hands this week.',
      ),
      WeeklyContractDefinition(
        id: 'm_hands',
        stat: 'hands',
        target: 120,
        reward: 40,
        name: 'Grinder',
        description: 'Play 120 hands across several runs this week.',
      ),
      WeeklyContractDefinition(
        id: 'm_wins',
        stat: 'wins',
        target: 2,
        reward: 60,
        name: 'Closer',
        description: 'Win 2 runs (clear Heat 12) this week.',
      ),
      WeeklyContractDefinition(
        id: 'm_pair',
        stat: 'pair',
        target: 30,
        reward: 35,
        name: 'Double Dealer',
        description: 'Score 30 Pair-or-better hands this week.',
      ),
      WeeklyContractDefinition(
        id: 'm_big',
        stat: 'bighand',
        target: 8,
        reward: 50,
        name: 'Heavy Hitter',
        description: 'Score 8 Full House-or-better hands this week.',
      ),
      WeeklyContractDefinition(
        id: 'm_straight',
        stat: 'straight',
        target: 12,
        reward: 45,
        name: 'On The Line',
        description: 'Score 12 Straight-family hands this week.',
      ),
      WeeklyContractDefinition(
        id: 'm_modifiers',
        stat: 'modifiers',
        target: 12,
        reward: 45,
        name: 'Rule Breaker',
        description: 'Clear 12 modified Heats this week.',
      ),
      WeeklyContractDefinition(
        id: 'm_runs',
        stat: 'runs',
        target: 5,
        reward: 40,
        name: 'Five Sessions',
        description: 'Finish 5 non-Daily runs this week.',
      ),
      WeeklyContractDefinition(
        id: 'm_daily',
        stat: 'daily',
        target: 3,
        reward: 45,
        name: 'Daily Regular',
        description: 'Complete a Daily Challenge on 3 days this week.',
      ),
    ];

const int visibleWeeklyContractCount = 5;
const int weeklyRefreshesPerWeek = 1;

int _unsigned32(int value) => value & 0xffffffff;
int _imul32(int left, int right) => _unsigned32(left * right);

int weeklySeed(String key) {
  var hash = 2166136261;
  for (final unit in key.codeUnits) {
    hash = _imul32(hash ^ unit, 16777619);
  }
  return _unsigned32(hash);
}

class _Mulberry32 {
  _Mulberry32(int seed) : _state = _unsigned32(seed);
  int _state;

  double nextDouble() {
    _state = _unsigned32(_state + 0x6d2b79f5);
    var value = _imul32(_state ^ (_state >>> 15), _state | 1);
    value =
        _unsigned32(value + _imul32(value ^ (value >>> 7), value | 61)) ^ value;
    return _unsigned32(value ^ (value >>> 14)) / 4294967296;
  }
}

List<String> shuffledWeeklyContractIds(int seed) {
  final random = _Mulberry32(seed);
  final pool = weeklyContractCatalog.map((mission) => mission.id).toList();
  final result = <String>[];
  while (pool.isNotEmpty) {
    final index = (random.nextDouble() * pool.length).floor();
    result.add(pool.removeAt(index));
  }
  return result;
}

List<String> chooseWeeklyContracts({
  required String weekKey,
  required int rotation,
  Iterable<String> currentIds = const <String>[],
  Iterable<String> claimedIds = const <String>[],
}) {
  final current = currentIds.toSet();
  final claimed = claimedIds.toSet();
  final ordered = shuffledWeeklyContractIds(weeklySeed('$weekKey#$rotation'));
  final groups = <Iterable<String>>[
    ordered.where((id) => !current.contains(id) && !claimed.contains(id)),
    ordered.where((id) => !current.contains(id)),
    ordered.where((id) => !claimed.contains(id)),
    ordered,
  ];
  final result = <String>[];
  for (final group in groups) {
    for (final id in group) {
      if (!result.contains(id)) result.add(id);
      if (result.length == visibleWeeklyContractCount) return result;
    }
  }
  return result;
}

bool weeklyRefreshUsedForWeek({
  required String storedRefreshKey,
  required String weekKey,
}) {
  if (storedRefreshKey == weekKey) return true;
  final legacyDate = DateTime.tryParse(storedRefreshKey);
  return legacyDate != null && isoWeekKey(legacyDate) == weekKey;
}

List<String> refreshedWeeklyContracts({
  required String weekKey,
  required int rotation,
  required Iterable<String> currentIds,
  required Iterable<String> claimedIds,
  Iterable<String> protectedIds = const <String>[],
}) {
  final protected = protectedIds
      .where(
        weeklyContractCatalog.map((mission) => mission.id).toSet().contains,
      )
      .toSet()
      .take(visibleWeeklyContractCount)
      .toList(growable: false);
  final ordered = chooseWeeklyContracts(
    weekKey: weekKey,
    rotation: rotation,
    currentIds: currentIds,
    claimedIds: claimedIds,
  );
  final result = <String>[...protected];
  for (final id in ordered) {
    if (!result.contains(id)) result.add(id);
    if (result.length == visibleWeeklyContractCount) return result;
  }
  for (final id in shuffledWeeklyContractIds(
    weeklySeed('$weekKey#$rotation'),
  )) {
    if (!result.contains(id)) result.add(id);
    if (result.length == visibleWeeklyContractCount) break;
  }
  return result;
}

String isoWeekKey(DateTime localDate) {
  var date = DateTime.utc(localDate.year, localDate.month, localDate.day);
  final isoDay = date.weekday;
  date = date.add(Duration(days: 4 - isoDay));
  final yearStart = DateTime.utc(date.year);
  final week = (((date.difference(yearStart).inDays + 1) / 7).ceil());
  return '${date.year}-W${week.toString().padLeft(2, '0')}';
}

class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
  });
  final String id;
  final String name;
  final String description;
}

const List<BadgeDefinition> badgeCatalog = <BadgeDefinition>[
  BadgeDefinition(
    id: 'b_first',
    name: 'Dealt In',
    description: 'Play your first run.',
  ),
  BadgeDefinition(
    id: 'b_heat6',
    name: 'Warmed Up',
    description: 'Reach Heat 6.',
  ),
  BadgeDefinition(
    id: 'b_win',
    name: 'Champion',
    description: 'Win a run (Heat 12).',
  ),
  BadgeDefinition(
    id: 'b_endless',
    name: 'No Finish Line',
    description: 'Reach Endless (Heat 13).',
  ),
  BadgeDefinition(
    id: 'b_rich',
    name: 'Loaded',
    description: 'Hold 2,000 account coins.',
  ),
  BadgeDefinition(
    id: 'b_score',
    name: 'High Roller',
    description: 'Best run score 5,000+.',
  ),
  BadgeDefinition(
    id: 'b_ach',
    name: 'Decorated',
    description: 'Earn 15 achievements.',
  ),
  BadgeDefinition(
    id: 'b_cos',
    name: 'Fashionista',
    description: 'Own 5 cosmetics.',
  ),
  BadgeDefinition(
    id: 'b_jok',
    name: 'Collector',
    description: 'Unlock 40 jokers.',
  ),
];

bool badgeIsEarned(
  String id,
  ProgressionSnapshot state, {
  bool bankroll2000Achievement = false,
}) {
  switch (id) {
    case 'b_first':
      return state.bestHeat >= 1;
    case 'b_heat6':
      return state.bestHeat >= 6;
    case 'b_win':
      return state.bestClearedHeat >= 12;
    case 'b_endless':
      return state.bestHeat >= 13;
    case 'b_rich':
      return bankroll2000Achievement || state.coins >= 2000;
    case 'b_score':
      return state.bestScore >= 5000;
    case 'b_ach':
      return state.achievementsEarned >= 15;
    case 'b_cos':
      return state.cosmeticsOwned >= 5;
    case 'b_jok':
      return state.unlockedJokers >= 40;
  }
  return false;
}

class TitleDefinition {
  const TitleDefinition({required this.id, required this.name});
  final String id;
  final String name;
}

const List<TitleDefinition> titleCatalog = <TitleDefinition>[
  TitleDefinition(id: 't_rookie', name: 'Rookie'),
  TitleDefinition(id: 't_grinder', name: 'The Grinder'),
  TitleDefinition(id: 't_champ', name: 'House Champion'),
  TitleDefinition(id: 't_endless', name: 'Endless Runner'),
  TitleDefinition(id: 't_whale', name: 'High Roller'),
  TitleDefinition(id: 't_legend', name: 'Neon Legend'),
  TitleDefinition(id: 't_eternal', name: 'Eternal Runner'),
  TitleDefinition(id: 't_house_master', name: 'House Master'),
  TitleDefinition(id: 't_royal_dealer', name: 'Royal Dealer'),
  TitleDefinition(id: 't_vault_keeper', name: 'Vault Keeper'),
  TitleDefinition(id: 't_contract_legend', name: 'Contract Legend'),
];

bool titleIsUnlocked(String id, ProgressionSnapshot state) {
  switch (id) {
    case 't_rookie':
      return true;
    case 't_grinder':
      return state.bestHeat >= 6;
    case 't_champ':
      return state.bestClearedHeat >= 12;
    case 't_endless':
      return state.bestHeat >= 13;
    case 't_whale':
      return state.bestScore >= 5000;
    case 't_legend':
      return state.achievementsEarned >= 20;
    case 't_eternal':
    case 't_house_master':
    case 't_royal_dealer':
    case 't_vault_keeper':
    case 't_contract_legend':
      return false;
  }
  return false;
}

const int starterGiftCoins = 200;
const List<String> tutorialStarterJokerIds = starterJokerIds;
const List<String> tutorialFirstRunJokerIds = <String>['copper', 'polish'];
const int stakeUnlockClearedHeat = 5;
const int gauntletUnlockClearedHeat = 12;

class ProgressionGates {
  const ProgressionGates({
    required this.tutorialDone,
    required this.bestClearedHeat,
    required this.unlockedJokers,
  });

  final bool tutorialDone;
  final int bestClearedHeat;
  final int unlockedJokers;

  bool get dailyChallengeUnlocked => tutorialDone;
  bool get stakeUnlocked => bestClearedHeat >= stakeUnlockClearedHeat;
  bool get gauntletUnlocked => bestClearedHeat >= gauntletUnlockClearedHeat;
}

const int dailyLoginCap = 25;

int dailyLoginRewardForStreak(int streak) {
  if (streak <= 1) return 5;
  if (streak == 2) return 10;
  if (streak == 3) return 15;
  if (streak == 4) return 20;
  return dailyLoginCap;
}

class DailyLoginOffer {
  const DailyLoginOffer({
    required this.available,
    required this.streak,
    required this.reward,
    required this.tomorrowReward,
    required this.dateKey,
  });
  final bool available;
  final int streak;
  final int reward;
  final int tomorrowReward;
  final String dateKey;
}

bool _sameLocalDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

DailyLoginOffer nextDailyLoginOffer({
  required DateTime now,
  DateTime? lastClaim,
  int currentStreak = 0,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final claimedDay = lastClaim == null
      ? null
      : DateTime(lastClaim.year, lastClaim.month, lastClaim.day);
  if (claimedDay != null && !claimedDay.isBefore(today)) {
    return DailyLoginOffer(
      available: false,
      streak: currentStreak,
      reward: dailyLoginRewardForStreak(currentStreak),
      tomorrowReward: dailyLoginRewardForStreak(currentStreak + 1),
      dateKey: calendarDateKey(now),
    );
  }
  final yesterday = today.subtract(const Duration(days: 1));
  final nextStreak = lastClaim != null && _sameLocalDay(lastClaim, yesterday)
      ? currentStreak + 1
      : 1;
  return DailyLoginOffer(
    available: true,
    streak: nextStreak,
    reward: dailyLoginRewardForStreak(nextStreak),
    tomorrowReward: dailyLoginRewardForStreak(nextStreak + 1),
    dateKey: calendarDateKey(now),
  );
}

const bool dailyBoardCoinPrizesActive = false;
const Map<int, int> plannedDailyBoardCoinPrizes = <int, int>{
  1: 300,
  2: 200,
  3: 200,
};

/// Daily Challenge is intentionally isolated from normal collection, mission,
/// achievement, local high-score and Play Games progression in v7.1.0.
bool progressionEnabledForRun({required bool isDailyRun}) => !isDailyRun;
