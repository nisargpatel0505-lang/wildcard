import 'package:flutter/material.dart';

import '../../domain/cards.dart';
import '../wildcard_theme.dart';

/// A compact, readable playing card with a non-overlapping touch target.
class PlayingCardTile extends StatelessWidget {
  const PlayingCardTile({
    required this.card,
    this.onTap,
    this.highlighted = false,
    this.width = 48,
    this.height = 86,
    super.key,
  });

  final PlayingCard card;
  final VoidCallback? onTap;
  final bool highlighted;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final suit = _suitGlyph(card.suit);
    final ink = card.suit.isRed
        ? const Color(0xFFD33A35)
        : const Color(0xFF18191D);
    final enhancement = switch (card.enhancement) {
      CardEnhancement.gild => tokens.gold,
      CardEnhancement.neon => tokens.mint,
      CardEnhancement.glass => const Color(0xFF94E8FF),
      CardEnhancement.wildsuit => tokens.wild,
      null => null,
    };
    final border = card.selected
        ? tokens.coral
        : highlighted
        ? tokens.mint
        : enhancement ?? const Color(0xFFD7CFBD);

    return Semantics(
      button: onTap != null,
      selected: card.selected,
      label:
          '${card.rank.label} of ${card.suit.name}${card.selected ? ', selected' : ''}',
      onTap: onTap,
      child: RepaintBoundary(
        child: ExcludeSemantics(
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            offset: card.selected ? const Offset(0, -0.10) : Offset.zero,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              scale: highlighted ? 1.025 : 1,
              child: SizedBox(
                width: width,
                height: height,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: border,
                      width: card.selected ? 2.5 : 1.5,
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFFCF0), Color(0xFFF0E8D6)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: border.withValues(
                          alpha: highlighted || card.selected ? 0.42 : 0.16,
                        ),
                        blurRadius: highlighted || card.selected ? 8 : 3,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(5, 4, 5, 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CardCorner(
                              rank: card.rank.label,
                              suit: suit,
                              ink: ink,
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  suit,
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: width * 0.43,
                                    height: 1,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: RotatedBox(
                                quarterTurns: 2,
                                child: _CardCorner(
                                  rank: card.rank.label,
                                  suit: suit,
                                  ink: ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _CardCorner extends StatelessWidget {
  const _CardCorner({
    required this.rank,
    required this.suit,
    required this.ink,
  });

  final String rank;
  final String suit;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: rank),
          TextSpan(text: '\n$suit', style: const TextStyle(fontSize: 10)),
        ],
      ),
      maxLines: 2,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: ink,
        fontFamily: 'SpaceGrotesk',
        fontWeight: FontWeight.w700,
        fontSize: 13,
        height: 0.82,
      ),
    );
  }
}

String _suitGlyph(CardSuit suit) => switch (suit) {
  CardSuit.spades => '\u2660',
  CardSuit.hearts => '\u2665',
  CardSuit.clubs => '\u2663',
  CardSuit.diamonds => '\u2666',
};
