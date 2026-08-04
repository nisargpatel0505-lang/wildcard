import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/long_term_progression.dart';

void main() {
  test('eight badge families expose one sequential objective each', () {
    expect(LongTermFamily.values, hasLength(8));
    expect(
      tieredAchievementCatalog.map((item) => item.id).toSet(),
      hasLength(41),
    );
    for (final family in LongTermFamily.values) {
      final tiers = longTermFamilyTiers(family);
      expect(tiers.length, greaterThanOrEqualTo(5));
      expect(
        tiers.map((tier) => tier.threshold).toList(),
        orderedEquals(tiers.map((tier) => tier.threshold).toList()..sort()),
      );
      expect(
        visibleLongTermTier(family, const <String, Object?>{}),
        same(tiers.first),
      );
    }
  });

  test('Endless uses the exact 1/5/10/25/50/100 track', () {
    expect(
      longTermFamilyTiers(LongTermFamily.endless).map((tier) => tier.threshold),
      <int>[1, 5, 10, 25, 50, 100],
    );
  });

  test('final Joker milestone tracks the active public catalogue', () {
    final finalTier = longTermFamilyTiers(LongTermFamily.jokerDiscovery).last;
    expect(jokerCatalog, hasLength(activePublicJokerCount));
    expect(finalTier.id, 'tier_jokers_100');
    expect(finalTier.threshold, activePublicJokerCount);
    expect(finalTier.description, contains('$activePublicJokerCount'));
  });

  test('completed future tiers remain locked behind manual earlier claims', () {
    const progress = LongTermProgressSnapshot(endlessEntries: 100);
    final tiers = longTermFamilyTiers(LongTermFamily.endless);
    final claimed = <String, Object?>{};

    expect(
      longTermAchievementClaimable(tiers.first, progress, claimed),
      isTrue,
    );
    expect(longTermAchievementClaimable(tiers[1], progress, claimed), isFalse);

    claimed[tiers.first.id] = true;
    expect(longTermAchievementClaimable(tiers[1], progress, claimed), isTrue);
    expect(
      visibleLongTermTier(LongTermFamily.endless, claimed),
      same(tiers[1]),
    );
  });

  test('major tiers award titles without inflating the coin budget', () {
    final titles = tieredAchievementCatalog
        .where((definition) => definition.rewardTitleId != null)
        .toList();
    expect(titles, hasLength(5));
    expect(titles.every((definition) => definition.rewardCoins == 0), isTrue);
    expect(
      tieredAchievementCatalog.fold<int>(
        0,
        (sum, definition) => sum + definition.rewardCoins,
      ),
      lessThanOrEqualTo(700),
    );
  });
}
