import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:wildcard/domain/astra_progression.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/joker_catalog.dart';

/// Study only: calls the real vault roll/duplicate protection; no app changes.
void main(List<String> args) {
  final count = int.parse(args.isEmpty ? '1000' : args.first);
  if (count < 1 || count > 10000) throw ArgumentError('1..10000 paths');
  final output = args.length > 1 ? args[1] : 'build/astra-collection.json';
  final rows = <Map<String, Object?>>[];
  for (final strategy in ['wood_first', 'three_wood_one_gold', 'gold_first']) {
    for (var index = 0; index < count; index++) {
      final random = math.Random(20260905 + index);
      final owned = starterJokerIds.toSet();
      var wood = 0, gold = 0, astraCost = 0, playCost = 0;
      final checkpoints = <String, Object?>{};
      int? firstWildAt, firstWildCost;
      while (owned.length < jokerCatalog.length) {
        final locked = jokerCatalog.where((j) => !owned.contains(j.id)).toList();
        final canWood = jokerChests[JokerChestTier.wood]!.effectiveOdds(locked).isNotEmpty;
        final canGold = jokerChests[JokerChestTier.gold]!.effectiveOdds(locked).isNotEmpty;
        var tier = switch (strategy) {
          'wood_first' => canWood ? JokerChestTier.wood : JokerChestTier.gold,
          'gold_first' => canGold ? JokerChestTier.gold : JokerChestTier.wood,
          _ => (wood + gold) % 4 == 3 && canGold ? JokerChestTier.gold : JokerChestTier.wood,
        };
        if (tier == JokerChestTier.wood && !canWood) tier = JokerChestTier.gold;
        if (tier == JokerChestTier.gold && !canGold) tier = JokerChestTier.wood;
        final chest = jokerChests[tier]!;
        final reward = chest.roll(locked, rarityRoll: random.nextDouble(), itemRoll: random.nextDouble());
        if (reward == null || owned.contains(reward.id)) throw StateError('Invalid duplicate/empty vault');
        astraCost += tier == JokerChestTier.wood ? astraWoodVaultPrice(owned.length) : astraGoldVaultPrice;
        playCost += chest.basePrice;
        tier == JokerChestTier.wood ? wood++ : gold++;
        owned.add(reward.id);
        if (reward.rarity == JokerRarity.wild && firstWildAt == null) {
          firstWildAt = wood + gold;
          firstWildCost = astraCost;
        }
        if ([15, 25, 40, 60, 80, jokerCatalog.length].contains(owned.length)) {
          checkpoints['${owned.length}'] = {'astraCost': astraCost, 'playCost': playCost, 'wood': wood, 'gold': gold};
        }
      }
      rows.add({'strategy': strategy, 'seed': 20260905 + index, 'wood': wood, 'gold': gold,
        'astraCost': astraCost, 'playCost': playCost, 'firstWildAt': firstWildAt,
        'firstWildCost': firstWildCost, 'checkpoints': checkpoints});
    }
  }
  final data = <String, Object?>{
    'sourceCommit': '700372f', 'pathsPerStrategy': count,
    'method': 'Actual JokerChestDefinition.roll; deterministic sampling of the same probability law, not the production secure RNG. Starts with ten tutorial discoveries; excludes all other free Joker gifts and cosmetic spending.',
    'catalogue': [for (final j in jokerCatalog) {'id': j.id, 'name': j.name, 'rarity': j.rarity.name, 'starter': starterJokerIds.contains(j.id)}],
    'rows': rows,
  };
  File(output).parent.createSync(recursive: true);
  File(output).writeAsStringSync(jsonEncode(data));
  stdout.writeln('Collection study: ${rows.length} paths; ${jokerCatalog.length} public Jokers; no duplicates or empty rewards. Saved $output');
}
