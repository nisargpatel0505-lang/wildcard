import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/game_rules.dart';

void main() {
  group("v8.5 Sly's Contract curve", () {
    test('uses the exact audited monotonic payout curve', () {
      expect(stakePayoutPerHundred, const <int>[
        0,
        20,
        35,
        45,
        55,
        70,
        82,
        92,
        100,
        105,
        110,
        115,
        150,
      ]);
      for (var heat = 1; heat < stakePayoutPerHundred.length; heat++) {
        expect(
          stakePayoutPerHundred[heat],
          greaterThan(stakePayoutPerHundred[heat - 1]),
          reason: 'More cleared Heats must always return more coins',
        );
      }
      expect(
        stakePayoutPerHundred[12] - stakePayoutPerHundred[9],
        45,
        reason: 'The late tail must stay flatter than the old 85-point leak',
      );
      expect(stakeHardMaximum, 200);
    });

    test('improves early protection and preserves a completion premium', () {
      const oldCurve = <int>[
        0,
        5,
        10,
        18,
        28,
        40,
        55,
        72,
        92,
        115,
        140,
        170,
        200,
      ];
      for (var heat = 1; heat <= 8; heat++) {
        expect(stakePayoutPerHundred[heat], greaterThan(oldCurve[heat]));
      }
      expect(stakePayoutPerHundred[12], 150);
      expect(
        stakePayoutPerHundred[12] - stakePayoutPerHundred[11],
        35,
        reason: 'A full clear must remain meaningfully better than a near miss',
      );
    });

    test('returns the exact disclosed per-100 table on every difficulty', () {
      const expected = <RunDifficulty, List<int>>{
        RunDifficulty.easy: <int>[
          0,
          16,
          28,
          36,
          44,
          56,
          66,
          74,
          80,
          84,
          88,
          92,
          120,
        ],
        RunDifficulty.medium: <int>[
          0,
          18,
          32,
          41,
          51,
          64,
          75,
          85,
          92,
          97,
          101,
          106,
          138,
        ],
        RunDifficulty.hard: <int>[
          0,
          20,
          35,
          45,
          55,
          70,
          82,
          92,
          100,
          105,
          110,
          115,
          150,
        ],
      };
      for (final entry in expected.entries) {
        expect(<int>[
          for (var heat = 0; heat <= 12; heat++)
            stakePayout(100, heat, difficulty: entry.key),
        ], entry.value);
      }
    });

    test('keeps scoring targets independent from the stake rebalance', () {
      expect(RunDifficulty.easy.targetMultiplier, 0.60);
      expect(RunDifficulty.medium.targetMultiplier, 1.00);
      expect(RunDifficulty.hard.targetMultiplier, 1.30);
      expect(RunDifficulty.easy.stakeMultiplier, 0.80);
      expect(RunDifficulty.medium.stakeMultiplier, 0.92);
      expect(RunDifficulty.hard.stakeMultiplier, 1.00);
    });

    test('fixed audited cohorts remain inside the intended EV bands', () {
      const histograms = <RunDifficulty, Map<String, List<int>>>{
        RunDifficulty.easy: <String, List<int>>{
          'new_weak': <int>[0, 0, 0, 0, 0, 0, 2, 5, 23, 6, 17, 42, 5],
          'mid': <int>[0, 0, 0, 0, 0, 0, 1, 0, 4, 4, 5, 63, 23],
          'skilled_late': <int>[0, 0, 0, 0, 0, 0, 0, 0, 9, 0, 7, 29, 55],
        },
        RunDifficulty.medium: <String, List<int>>{
          'new_weak': <int>[0, 0, 1, 0, 1, 13, 10, 20, 41, 9, 3, 2, 0],
          'mid': <int>[0, 0, 0, 0, 0, 0, 2, 7, 45, 16, 19, 10, 1],
          'skilled_late': <int>[0, 0, 0, 0, 0, 2, 4, 9, 14, 12, 12, 21, 26],
        },
        RunDifficulty.hard: <String, List<int>>{
          'new_weak': <int>[0, 0, 2, 3, 9, 22, 15, 27, 19, 3, 0, 0, 0],
          'mid': <int>[0, 0, 1, 0, 1, 3, 8, 17, 55, 11, 1, 3, 0],
          'skilled_late': <int>[0, 0, 0, 0, 0, 7, 8, 14, 19, 8, 10, 20, 14],
        },
      };
      const bands = <String, (double, double)>{
        'new_weak': (0.80, 0.90),
        'mid': (0.95, 1.00),
        'skilled_late': (1.03, 1.08),
      };

      for (final difficultyEntry in histograms.entries) {
        for (final profileEntry in difficultyEntry.value.entries) {
          final ev = _grossEv(profileEntry.value, difficultyEntry.key);
          final band = bands[profileEntry.key]!;
          expect(
            ev,
            inInclusiveRange(band.$1, band.$2),
            reason:
                '${difficultyEntry.key.name}/${profileEntry.key} EV '
                '${ev.toStringAsFixed(4)} left its audited band',
          );
        }
      }
    });
  });
}

double _grossEv(List<int> heatsClearedCounts, RunDifficulty difficulty) {
  final runs = heatsClearedCounts.fold<int>(0, (sum, count) => sum + count);
  final totalPayout = <int>[
    for (var heat = 0; heat < heatsClearedCounts.length; heat++)
      stakePayout(100, heat, difficulty: difficulty) * heatsClearedCounts[heat],
  ].fold<int>(0, (sum, payout) => sum + payout);
  return totalPayout / (runs * 100);
}
