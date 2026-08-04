import 'cards.dart';
import 'game_rules.dart';

class DeckIntegrityResult {
  const DeckIntegrityResult({
    required this.changed,
    required this.removed,
    required this.restored,
    required this.copiedCount,
    required this.enhancedCount,
    required this.destroyedCount,
  });

  final bool changed;
  final int removed;
  final int restored;
  final int copiedCount;
  final int enhancedCount;
  final int destroyedCount;
}

/// Applies the recovered v7.1.0 deck invariants in place.
///
/// Dart construction already rejects invalid ranks and suits. This function
/// enforces the remaining migration rules: two exact copies maximum, duplicate
/// cards are marked copied, copied cards cannot retain enhancements, and a
/// damaged/legacy deck is restored to at least 24 distinct cards.
DeckIntegrityResult normalizeDeckIntegrity(
  List<PlayingCard> cards, {
  int shatteredCount = 0,
}) {
  final cleaned = <PlayingCard>[];
  final exactCounts = <String, int>{};
  var removed = 0;
  var changed = false;

  for (final raw in cards) {
    final key = _cardKey(raw.rank, raw.suit);
    final seen = exactCounts[key] ?? 0;
    if (seen >= maximumExactCardCopies) {
      removed++;
      changed = true;
      continue;
    }
    var card = raw;
    if (card.copied && card.enhancement != null) {
      card = card.copyWith(clearEnhancement: true);
      changed = true;
    }
    if (seen > 0) {
      if (!card.copied || card.enhancement != null) changed = true;
      card = card.copyWith(copied: true, clearEnhancement: true);
    }
    exactCounts[key] = seen + 1;
    cleaned.add(card);
  }

  var restored = 0;
  if (cleaned.length < minimumDeckSize) {
    for (final base in baseCardSet()) {
      if (cleaned.length >= minimumDeckSize) break;
      final key = _cardKey(base.rank, base.suit);
      if ((exactCounts[key] ?? 0) > 0) continue;
      cleaned.add(base);
      exactCounts[key] = 1;
      restored++;
      changed = true;
    }
  }

  if (changed) {
    cards
      ..clear()
      ..addAll(cleaned);
  }
  final effective = changed ? cleaned : cards;
  final copied = effective.where((card) => card.copied).length;
  final enhanced = effective.where((card) => card.enhancement != null).length;
  final destroyed = (52 + copied - shatteredCount - effective.length)
      .clamp(0, 1 << 31)
      .toInt();
  return DeckIntegrityResult(
    changed: changed,
    removed: removed,
    restored: restored,
    copiedCount: copied,
    enhancedCount: enhanced,
    destroyedCount: destroyed,
  );
}

int exactCardCount(
  List<PlayingCard> cards,
  CardRank rank,
  CardSuit suit, {
  int ignoreIndex = -1,
}) {
  var total = 0;
  for (var index = 0; index < cards.length; index++) {
    if (index != ignoreIndex &&
        cards[index].rank == rank &&
        cards[index].suit == suit) {
      total++;
    }
  }
  return total;
}

bool canCopyCard(List<PlayingCard> deck, PlayingCard card) =>
    card.enhancement == null &&
    !card.copied &&
    exactCardCount(deck, card.rank, card.suit) < maximumExactCardCopies;

bool canEnhanceCard(PlayingCard card) => !card.copied;

bool canDyeCard(List<PlayingCard> deck, int cardIndex, CardSuit targetSuit) {
  final card = deck[cardIndex];
  return targetSuit != card.suit &&
      exactCardCount(deck, card.rank, targetSuit, ignoreIndex: cardIndex) <
          maximumExactCardCopies;
}

String _cardKey(CardRank rank, CardSuit suit) => '${rank.label}|${suit.symbol}';
