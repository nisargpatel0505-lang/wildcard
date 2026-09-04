import 'dart:convert';
import 'dart:io';

import 'package:wildcard/domain/astra_progression.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/simulation.dart';

/// Bounded, single-process matched-seed experiment. Example:
/// dart run tool/astra_economy_compare.dart --runs=6 --out=build/astra-economy.json
/// No remote services, real purchases, parallel bots or presentation waits.
void main(List<String> arguments) {
  final countArg = arguments
      .where((arg) => arg.startsWith('--runs='))
      .firstOrNull;
  final runs = int.tryParse(countArg?.split('=').last ?? '') ?? 6;
  if (runs < 1 || runs > 100) throw ArgumentError('--runs must be 1..100');
  final outArg = arguments.where((arg) => arg.startsWith('--out=')).firstOrNull;
  final output =
      outArg?.substring('--out='.length) ?? 'build/astra-economy.json';
  const harness = WildcardSimulationHarness();
  final cells = <Map<String, Object?>>[];
  final started = DateTime.now();

  for (final difficulty in <RunDifficulty>[
    RunDifficulty.medium,
    RunDifficulty.hard,
  ]) {
    for (final strategy in <SimulationStrategy>[
      SimulationStrategy.handRanking,
      SimulationStrategy.adaptive,
    ]) {
      for (final full in <bool>[false, true]) {
        // Hard is a mastery check, not another four beginner cohorts.
        if (difficulty == RunDifficulty.hard &&
            (strategy != SimulationStrategy.adaptive || !full)) {
          continue;
        }
        for (final astra in <bool>[false, true]) {
          final results = <SimulatedRunResult>[];
          for (var index = 0; index < runs; index++) {
            final seed = 0xA5700600 + index;
            final starter = astra ? astraStarterChoices(seed).first.id : null;
            final batch = harness.runBatch(
              SimulationConfig(
                runs: 1,
                firstSeed: seed,
                strategy: strategy,
                difficulty: difficulty,
                initialJokers: starter == null
                    ? const <String>[]
                    : <String>[starter],
                allJokersUnlocked: full,
                discoveredJokerIds: full ? null : starterJokerIds,
                astraEconomy: astra,
              ),
            );
            results.add(batch.results.single);
          }
          double average(num Function(SimulatedRunResult result) read) =>
              results.fold<num>(0, (sum, result) => sum + read(result)) / runs;
          int earned(SimulatedRunResult result) =>
              List.generate(
                result.heatsCleared,
                (index) => astra
                    ? astraAccountReward(index + 1)
                    : accountReward(index + 1),
              ).fold<int>(0, (sum, reward) => sum + reward) +
              (result.won ? standardCompletionBonus : 0);
          final income = average(earned);
          final wood = astra
              ? astraWoodVaultPrice(full ? jokerCatalog.length : 10)
              : jokerChests[JokerChestTier.wood]!.basePrice;
          final cell = <String, Object?>{
            'candidate': astra ? 'Astra' : 'Play 8.5.3 baseline',
            'strategy': strategy.name,
            'collection': full ? 'full' : '10 starters',
            'difficulty': difficulty.name,
            'runs': runs,
            'wins': results.where((result) => result.won).length,
            'meanHeatsCleared': average((result) => result.heatsCleared),
            'meanAccountCoinsEarned': income,
            'meanJokersBought': average((result) => result.jokersBought),
            'meanAffordableOffersAtFirstShop': average(
              (result) => result.firstShopAffordableOffers,
            ),
            'meanFreeRerollsUsed': average((result) => result.freeRerollsUsed),
            'meanJokerTriggerEvents': average(
              (result) => result.jokerTriggerEvents,
            ),
            'meanHands': average((result) => result.handsPlayed),
            'woodPrice': wood,
            'runsPerWoodFromRunIncomeOnly': income > 0 ? wood / income : null,
            'invariantFailures': results
                .expand((result) => result.invariantFailures)
                .toList(),
            'rawRuns': results
                .map(
                  (result) => <String, Object?>{
                    ...result.toJson(),
                    'accountCoinsEarned': earned(result),
                  },
                )
                .toList(),
          };
          cells.add(cell);
          stdout.writeln(
            jsonEncode(Map<String, Object?>.from(cell)..remove('rawRuns')),
          );
        }
      }
    }
  }

  final report = <String, Object?>{
    'baseline': 'Play release 8.5.3+72, commit 33fa0ab',
    'seedBase': 0xA5700600,
    'runsPerCell': runs,
    'elapsedSeconds': DateTime.now().difference(started).inMilliseconds / 1000,
    'limits': <String>[
      'Small directional sample; this is not a human retention prediction.',
      'Both candidates use the real Dart scorer and seeded domain harness.',
      'Free baseline models an ordinary run after the first guided run.',
      'Astra rotates all three draft routes equally over multiples of 3 seeds; '
          'it does not assume a perfect human draft choice.',
      'handRanking is a simple poker-ranking policy; adaptive plans discards, '
          'Joker synergy and supplies. Neither is a measured human skill tier.',
      'No ad, login, purchase, mission, journey or stake income is counted.',
      'Shop RNG changes with an extra offer; deck and luck streams stay separate.',
      'Full-collection vault metric is a price comparison, not a useful purchase '
          'for an already complete account. Cosmetics and mastery are separate.',
    ],
    'cells': cells,
  };
  final file = File(output)..parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln('Report: ${file.absolute.path}');
  if (cells.any((cell) => (cell['invariantFailures'] as List).isNotEmpty)) {
    exitCode = 1;
  }
}
