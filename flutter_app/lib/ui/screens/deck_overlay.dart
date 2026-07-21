import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/cards.dart';
import '../wildcard_theme.dart';

/// Full-screen modal deck matrix with every rank and suit visible at once.
///
/// [allHeatCards] is the complete Heat deck, [liveDrawCards] is the draw pile,
/// and [currentHand] is displayed in the summary. Ace uses the domain's real
/// rank identity (value 15), avoiding the legacy value-14 omission.
class DeckOverlay extends StatelessWidget {
  const DeckOverlay({
    required this.allHeatCards,
    required this.liveDrawCards,
    this.currentHand = const <PlayingCard>[],
    this.title = 'This Heat\'s Deck',
    this.onClose,
    super.key,
  });

  final List<PlayingCard> allHeatCards;
  final List<PlayingCard> liveDrawCards;
  final List<PlayingCard> currentHand;
  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final total = allHeatCards.length;
    final live = liveDrawCards.length;
    final played = math.max(0, total - live - currentHand.length);
    final totalCounts = _counts(allHeatCards);
    final liveCounts = _counts(liveDrawCards);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      scopesRoute: true,
      namesRoute: true,
      label: title,
      onDismiss: onClose,
      child: Material(
        color: Colors.transparent,
        child: ColoredBox(
          color: const Color(0xC9000308),
          child: SafeArea(
            minimum: const EdgeInsets.all(6),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [tokens.panel, tokens.panelStrong],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: tokens.violet, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xB8000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title.toUpperCase(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.gold,
                                  fontFamily: 'Bungee',
                                  fontSize: 18,
                                  height: 1.08,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _CloseButton(onPressed: onClose),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Every rank is visible. Bright = live draw, dim = already out, split = some copies remain.',
                          style: TextStyle(
                            color: tokens.creamDim,
                            fontSize: 11,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 9),
                        _DeckSummary(
                          live: live,
                          inHand: currentHand.length,
                          played: played,
                        ),
                        const SizedBox(height: 10),
                        _DeckMatrix(
                          totalCounts: totalCounts,
                          liveCounts: liveCounts,
                        ),
                        const SizedBox(height: 10),
                        const _DeckLegend(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Semantics(
      button: true,
      label: 'Close deck',
      onTap: onPressed,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.panelStrong,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.line),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(11),
                child: Icon(Icons.close_rounded, color: tokens.cream, size: 23),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeckSummary extends StatelessWidget {
  const _DeckSummary({
    required this.live,
    required this.inHand,
    required this.played,
  });

  final int live;
  final int inHand;
  final int played;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCell(value: '$live', label: 'LIVE'),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _SummaryCell(value: '$inHand', label: 'IN HAND'),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _SummaryCell(value: '$played', label: 'PLAYED / OUT'),
        ),
      ],
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xA8051413),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: tokens.mint,
              fontFamily: 'Bungee',
              fontSize: 14,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(color: tokens.creamDim, fontSize: 9, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeckMatrix extends StatelessWidget {
  const _DeckMatrix({required this.totalCounts, required this.liveCounts});

  final Map<(CardSuit, CardRank), int> totalCounts;
  final Map<(CardSuit, CardRank), int> liveCounts;

  static const _suits = <CardSuit>[
    CardSuit.spades,
    CardSuit.hearts,
    CardSuit.diamonds,
    CardSuit.clubs,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 1.5;
        const suitWidth = 22.0;
        final cardWidth = math.max(
          16.0,
          (constraints.maxWidth - suitWidth - gap * 13) / 13,
        );
        final cellHeight = cardWidth.clamp(24.0, 34.0).toDouble();
        return Column(
          children: [
            Row(
              children: [
                const SizedBox(width: suitWidth),
                for (final rank in CardRank.values) ...[
                  if (rank != CardRank.two) const SizedBox(width: gap),
                  SizedBox(
                    width: cardWidth,
                    height: 20,
                    child: Center(
                      child: FittedBox(
                        child: Text(
                          rank.label,
                          style: TextStyle(
                            color: context.wildcard.gold,
                            fontFamily: 'Bungee',
                            fontSize: 9,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            for (var suitIndex = 0; suitIndex < _suits.length; suitIndex++) ...[
              if (suitIndex > 0) const SizedBox(height: 3),
              _DeckSuitRow(
                suit: _suits[suitIndex],
                cardWidth: cardWidth,
                cellHeight: cellHeight,
                totalCounts: totalCounts,
                liveCounts: liveCounts,
                gap: gap,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DeckSuitRow extends StatelessWidget {
  const _DeckSuitRow({
    required this.suit,
    required this.cardWidth,
    required this.cellHeight,
    required this.totalCounts,
    required this.liveCounts,
    required this.gap,
  });

  final CardSuit suit;
  final double cardWidth;
  final double cellHeight;
  final Map<(CardSuit, CardRank), int> totalCounts;
  final Map<(CardSuit, CardRank), int> liveCounts;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final red = suit == CardSuit.hearts || suit == CardSuit.diamonds;
    final ink = red ? const Color(0xFFD83A36) : const Color(0xFF15171B);
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: cellHeight,
          child: Center(
            child: Text(
              _suitGlyph(suit),
              style: TextStyle(
                color: red ? context.wildcard.coral : context.wildcard.cream,
                fontSize: 15,
                height: 1,
              ),
            ),
          ),
        ),
        for (final rank in CardRank.values) ...[
          if (rank != CardRank.two) SizedBox(width: gap),
          _DeckCell(
            key: ValueKey('deck-cell-${suit.name}-${rank.name}'),
            rank: rank,
            suit: suit,
            width: cardWidth,
            height: cellHeight,
            ink: ink,
            total: totalCounts[(suit, rank)] ?? 0,
            live: liveCounts[(suit, rank)] ?? 0,
          ),
        ],
      ],
    );
  }
}

class _DeckCell extends StatelessWidget {
  const _DeckCell({
    required this.rank,
    required this.suit,
    required this.width,
    required this.height,
    required this.ink,
    required this.total,
    required this.live,
    super.key,
  });

  final CardRank rank;
  final CardSuit suit;
  final double width;
  final double height;
  final Color ink;
  final int total;
  final int live;

  @override
  Widget build(BuildContext context) {
    final dead = live == 0;
    final partial = live > 0 && live < total;
    final cardColor = dead
        ? const Color(0xFF323138)
        : partial
        ? const Color(0xFFF2E8CC)
        : const Color(0xFFFFFCF0);
    return Semantics(
      label: '${rank.label} of ${suit.name}, $live of $total live',
      child: ExcludeSemantics(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: dead
                  ? context.wildcard.line.withValues(alpha: 0.38)
                  : context.wildcard.mint.withValues(alpha: 0.68),
            ),
            gradient: partial
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [cardColor, const Color(0xFF69646B)],
                  )
                : null,
            color: partial ? null : cardColor,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    rank.label,
                    style: TextStyle(
                      color: dead ? const Color(0xFF8B8790) : ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      height: 1,
                    ),
                  ),
                ),
              ),
              if (total > 1)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 1.5,
                      vertical: 0.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xD8000000),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '$live/$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 6.5,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckLegend extends StatelessWidget {
  const _DeckLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 5,
      children: const [
        _LegendItem(color: Color(0xFFFFFCF0), label: 'Live'),
        _LegendItem(color: Color(0xFFF2E8CC), label: 'Some copies live'),
        _LegendItem(color: Color(0xFF323138), label: 'Already out'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: context.wildcard.line),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: context.wildcard.creamDim,
            fontSize: 10,
            height: 1,
          ),
        ),
      ],
    );
  }
}

Map<(CardSuit, CardRank), int> _counts(Iterable<PlayingCard> cards) {
  final result = <(CardSuit, CardRank), int>{};
  for (final card in cards) {
    final key = (card.suit, card.rank);
    result[key] = (result[key] ?? 0) + 1;
  }
  return result;
}

String _suitGlyph(CardSuit suit) => switch (suit) {
  CardSuit.spades => '\u2660',
  CardSuit.hearts => '\u2665',
  CardSuit.clubs => '\u2663',
  CardSuit.diamonds => '\u2666',
};
