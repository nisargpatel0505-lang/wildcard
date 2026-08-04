import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/random_streams.dart';

void main() {
  test('Daily FNV seed and deck stream match the shipped JavaScript', () {
    final seed = dailySeed('2026-07-21');
    expect(seed, 1050154179);
    expect(
      <double>[
        for (var index = 0; index < 4; index++)
          seededRandomAt(seed, RandomStream.deck, index),
      ],
      closeToList(const <double>[
        0.4434243848081678,
        0.1767403802368790,
        0.3984191913623363,
        0.8490090884733945,
      ]),
    );
  });

  test('all five v7.1 RNG streams match phone JavaScript vectors', () {
    final seed = dailySeed('2026-07-21');
    final vectors = <RandomStream, List<double>>{
      RandomStream.deck: <double>[
        0.4434243848081678,
        0.1767403802368790,
        0.3984191913623363,
      ],
      RandomStream.shop: <double>[
        0.9751788722351193,
        0.5170152462087572,
        0.7984631333965808,
      ],
      RandomStream.modifiers: <double>[
        0.2644482748582959,
        0.02727142721414566,
        0.6051058028824627,
      ],
      RandomStream.luck: <double>[
        0.8195852923672646,
        0.7415293923113495,
        0.8848833166994154,
      ],
      RandomStream.boss: <double>[
        0.8124491472262889,
        0.7383114139083773,
        0.18112715962342918,
      ],
    };
    for (final entry in vectors.entries) {
      expect(
        <double>[
          for (var index = 0; index < entry.value.length; index++)
            seededRandomAt(seed, entry.key, index),
        ],
        closeToList(entry.value),
        reason: entry.key.legacyName,
      );
    }
  });

  test('streams advance independently and survive a JSON round trip', () {
    final counters = RandomCounters();
    final seed = dailySeed('2026-07-21');
    final firstDeck = counters.next(RandomStream.deck, seed);
    final firstLuck = counters.next(RandomStream.luck, seed);
    final restored = RandomCounters.fromJson(counters.toJson());

    expect(counters[RandomStream.deck], 1);
    expect(counters[RandomStream.luck], 1);
    expect(firstDeck, seededRandomAt(seed, RandomStream.deck, 0));
    expect(firstLuck, seededRandomAt(seed, RandomStream.luck, 0));
    expect(
      restored.next(RandomStream.deck, seed),
      seededRandomAt(seed, RandomStream.deck, 1),
    );
    expect(restored[RandomStream.luck], 1);
  });
}

Matcher closeToList(List<double> expected) => predicate<List<double>>((actual) {
  if (actual.length != expected.length) return false;
  for (var index = 0; index < actual.length; index++) {
    if ((actual[index] - expected[index]).abs() > 1e-15) return false;
  }
  return true;
}, 'matches the JavaScript uint32 RNG vector');
