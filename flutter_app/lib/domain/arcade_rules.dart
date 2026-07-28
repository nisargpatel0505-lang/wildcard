import 'dart:math' as math;

import 'cards.dart';
import 'game_rules.dart';
import 'scoring_engine.dart';

/// The deliberately small first-release Arcade catalogue.
///
/// Thirty rounds is kept as a visible progression reward rather than crowding
/// the initial choice with four immediately available run lengths.
enum ArcadeRunLength {
  sprint8('8-Round Sprint', 8, 'A two-to-four minute burst.'),
  standard15('15-Round Arcade', 15, 'The standard five-to-eight minute run.'),
  challenge30('30-Round Challenge', 30, 'A longer unlocked challenge.'),
  endless('Endless Arcade', null, 'Keep dealing until one target beats you.');

  const ArcadeRunLength(this.displayName, this.roundLimit, this.description);

  final String displayName;
  final int? roundLimit;
  final String description;

  bool get isEndless => roundLimit == null;
}

enum ArcadeHandType {
  highCard('High Card', HandType.highCard),
  pair('Pair', HandType.pair),
  threeOfAKind('Three of a Kind', HandType.threeOfAKind),
  straight('3-Card Straight', HandType.straight),
  flush('3-Card Flush', HandType.flush),
  straightFlush('3-Card Straight Flush', HandType.straightFlush);

  const ArcadeHandType(this.displayName, this.authoritativeType);

  final String displayName;
  final HandType authoritativeType;
}

class ArcadeHandEvaluation {
  const ArcadeHandEvaluation({required this.type, required this.scoringCards});

  final ArcadeHandType type;
  final Set<PlayingCard> scoringCards;

  /// Feeds the resolved three-card shape into the existing scoring engine.
  ///
  /// This preserves all authoritative rank, enhancement and Joker maths while
  /// keeping three-card recognition completely isolated from normal poker.
  AnalyzedHand get authoritative =>
      AnalyzedHand(type: type.authoritativeType, scoringCards: scoringCards);
}

abstract final class ArcadeRules {
  static const int dealtCards = 5;
  static const int selectedCards = 3;
  static const int shopCadence = 3;
  static const int challengeUnlockHeat = 12;
  static const Set<int> endlessMilestones = <int>{25, 50, 75, 100};

  static bool canScoreSelection(int count) => count == selectedCards;

  /// A one-play target curve for rapid rounds.
  ///
  /// The opening target is reachable by a useful High Card. It rises linearly
  /// through the standard run, then accelerates in two readable steps so
  /// Endless cannot flatten into a solved build.
  static int targetForRound(int round) {
    final safeRound = math.max(1, round);
    final after15 = math.max(0, safeRound - 15);
    final after30 = math.max(0, safeRound - 30);
    return 15 + (safeRound - 1) * 4 + after15 * 3 + after30 * 6;
  }

  static bool opensShopAfter(int clearedRound) =>
      clearedRound > 0 && clearedRound % shopCadence == 0;

  static bool completesAfter(ArcadeRunLength length, int clearedRound) {
    final limit = length.roundLimit;
    return limit != null && clearedRound >= limit;
  }

  static int? milestoneAfter(int clearedRound) =>
      endlessMilestones.contains(clearedRound) ? clearedRound : null;

  static ArcadeHandEvaluation evaluate(
    List<PlayingCard> cards, {
    Set<String> activeJokerIds = const <String>{},
  }) {
    if (cards.length != selectedCards) {
      throw ArgumentError.value(
        cards.length,
        'cards',
        'Arcade hands must contain exactly three cards',
      );
    }
    int evaluationValue(PlayingCard card) =>
        activeJokerIds.contains('alchemist') && card.rank == CardRank.two
        ? CardRank.ace.value
        : card.rank.value;
    final counts = <int, int>{};
    for (final card in cards) {
      final value = evaluationValue(card);
      counts[value] = (counts[value] ?? 0) + 1;
    }
    if (activeJokerIds.contains('understudy')) {
      final highest = cards.map(evaluationValue).reduce(math.max);
      counts[highest] = (counts[highest] ?? 0) + 1;
    }
    final groups = counts.values.toList()..sort((a, b) => b.compareTo(a));
    final suitCounts = <CardSuit, int>{};
    var wildSuitCards = 0;
    for (final card in cards) {
      if (card.enhancement == CardEnhancement.wildsuit) {
        wildSuitCards++;
      } else {
        suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
      }
    }
    final bestSuitCount = suitCounts.values.fold<int>(0, math.max);
    final flush =
        bestSuitCount +
            wildSuitCards +
            (activeJokerIds.contains('suit_swap') ? 1 : 0) >=
        selectedCards;
    final straight = _isThreeCardStraight(
      cards.map(evaluationValue).toSet().toList(),
      allowSingleGap: activeJokerIds.contains('gap_filler'),
    );

    if (straight && flush) {
      return ArcadeHandEvaluation(
        type: ArcadeHandType.straightFlush,
        scoringCards: cards.toSet(),
      );
    }
    if (groups.first >= 3) {
      final tripValue = counts.entries
          .firstWhere((entry) => entry.value == groups.first)
          .key;
      return ArcadeHandEvaluation(
        type: ArcadeHandType.threeOfAKind,
        scoringCards: cards
            .where((card) => evaluationValue(card) == tripValue)
            .toSet(),
      );
    }
    if (straight) {
      return ArcadeHandEvaluation(
        type: ArcadeHandType.straight,
        scoringCards: cards.toSet(),
      );
    }
    if (flush) {
      return ArcadeHandEvaluation(
        type: ArcadeHandType.flush,
        scoringCards: cards.toSet(),
      );
    }
    if (groups.first == 2) {
      final pairValue = counts.entries
          .firstWhere((entry) => entry.value == 2)
          .key;
      return ArcadeHandEvaluation(
        type: ArcadeHandType.pair,
        scoringCards: cards
            .where((card) => evaluationValue(card) == pairValue)
            .toSet(),
      );
    }
    var highest = cards.first;
    for (final card in cards.skip(1)) {
      if (card.rank.value > highest.rank.value) highest = card;
    }
    return ArcadeHandEvaluation(
      type: ArcadeHandType.highCard,
      scoringCards: <PlayingCard>{highest},
    );
  }

  static bool _isThreeCardStraight(
    List<int> values, {
    bool allowSingleGap = false,
  }) {
    if (values.length != selectedCards) return false;
    final high = values.map((value) => value == 15 ? 14 : value).toList()
      ..sort();
    if (_consecutive(high) || (allowSingleGap && _singleGap(high))) return true;
    if (!values.contains(15)) return false;
    final lowAce = values.map((value) => value == 15 ? 1 : value).toList()
      ..sort();
    return _consecutive(lowAce) || (allowSingleGap && _singleGap(lowAce));
  }

  static bool _consecutive(List<int> ordered) =>
      ordered[1] - ordered[0] == 1 && ordered[2] - ordered[1] == 1;

  static bool _singleGap(List<int> ordered) {
    final differences = <int>[ordered[1] - ordered[0], ordered[2] - ordered[1]];
    return differences.where((difference) => difference == 2).length == 1 &&
        differences.every((difference) => difference == 1 || difference == 2);
  }
}
