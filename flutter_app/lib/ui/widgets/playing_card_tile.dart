import 'package:flutter/material.dart';

import '../../domain/cards.dart';
import '../wildcard_theme.dart';

/// A compact, readable playing card with a non-overlapping touch target.
///
/// The card itself is deliberately STATIC — no idle float, no lift, no scale,
/// no shake. The player asked for the cards to stay put; all scoring feedback
/// comes from the border/glow state and the score chip that floats above,
/// never from moving the card.
class PlayingCardTile extends StatelessWidget {
  const PlayingCardTile({
    required this.card,
    this.onTap,
    this.highlighted = false,
    this.scored = false,
    this.dimmed = false,
    this.width = 48,
    this.height = 86,
    this.scoreChip,
    this.scoreChipColor,
    this.highlightColor,
    this.scoreChipSequence = 0,
    super.key,
  });

  final PlayingCard card;
  final VoidCallback? onTap;

  /// This card is the one scoring right now: it lights up (border + glow).
  final bool highlighted;

  /// This card has already scored earlier in the same hand: it keeps a soft
  /// mint glow so the player can read which cards contributed.
  final bool scored;
  final bool dimmed;

  final double width;
  final double height;

  /// Points this card just contributed, e.g. "+15". Shown as a number that
  /// rises off the card while it scores.
  final String? scoreChip;

  /// Colour of that number: gold when the card itself scores, violet when a
  /// Joker acted on it — the WebView's gold/purple split.
  final Color? scoreChipColor;
  final Color? highlightColor;
  final int scoreChipSequence;

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
        : highlighted || scored
        ? (highlightColor ?? (highlighted ? tokens.gold : tokens.mint))
        : enhancement ?? const Color(0xFFD7CFBD);

    final chip = scoreChip;
    return Semantics(
      button: onTap != null,
      selected: card.selected,
      label:
          '${card.rank.label} of ${card.suit.name}${card.selected ? ', selected' : ''}',
      onTap: onTap,
      child: RepaintBoundary(
        child: ExcludeSemantics(
          child: Opacity(
            opacity: dimmed ? 0.42 : 1,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Static: the card never moves. Only its border/glow changes.
                _cardBody(context, tokens, suit, ink, border),
                if (chip != null && chip.isNotEmpty)
                  Positioned(
                    top: -height * 0.28,
                    child: _RisingScoreChip(
                      key: ValueKey(
                        '${card.uid ?? card.rank.label}-$scoreChipSequence',
                      ),
                      text: chip,
                      color: scoreChipColor ?? const Color(0xFFF7C548),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardBody(
    BuildContext context,
    WildcardThemeTokens tokens,
    String suit,
    Color ink,
    Color border,
  ) {
    final glowing = highlighted || scored || card.selected;
    return SizedBox(
      width: width,
      height: height,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: border,
            width: card.selected || highlighted ? 2.5 : 1.5,
          ),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFCF0), Color(0xFFF0E8D6)],
          ),
          boxShadow: [
            BoxShadow(
              color: border.withValues(alpha: glowing ? 0.42 : 0.16),
              blurRadius: glowing ? 8 : 3,
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
              // Padding scales with the card so narrow hands still breathe
              // instead of crushing the corner glyphs.
              padding: EdgeInsets.fromLTRB(
                width * 0.11,
                width * 0.09,
                width * 0.11,
                width * 0.07,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardCorner(
                    rank: card.rank.label,
                    suit: suit,
                    ink: ink,
                    cardWidth: width,
                  ),
                  // The centre pip used to be a raw Text with height:1 at a
                  // large size, so the glyph's own ascent/descent overflowed
                  // the line box and the card's clip sheared the bottom off —
                  // "half the suit missing". A FittedBox always scales the
                  // whole glyph to fit the space, so it can never clip.
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: width * 0.06),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Text(
                          suit,
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w700,
                          ),
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
                        cardWidth: width,
                      ),
                    ),
                  ),
                ],
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
    required this.cardWidth,
  });

  final String rank;
  final String suit;
  final Color ink;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    // The old corner packed rank and suit into one Text with height 0.82. That
    // negative leading pulled the suit glyph up into the rank, which is what
    // made the faces look unclean. Two explicit lines with their own metrics
    // can never collide, and both scale with the card so a full hand stays
    // readable when the cards get narrow.
    final rankSize = (cardWidth * 0.34).clamp(9.0, 15.0);
    final suitSize = (cardWidth * 0.26).clamp(7.0, 11.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          rank,
          maxLines: 1,
          style: TextStyle(
            color: ink,
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700,
            fontSize: rankSize,
            height: 1.0,
          ),
        ),
        Text(
          suit,
          maxLines: 1,
          style: TextStyle(
            color: ink,
            fontWeight: FontWeight.w700,
            fontSize: suitSize,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

String _suitGlyph(CardSuit suit) => switch (suit) {
  CardSuit.spades => '\u2660',
  CardSuit.hearts => '\u2665',
  CardSuit.clubs => '\u2663',
  CardSuit.diamonds => '\u2666',
};

/// The "+15" number that pops off a card the moment it scores — gold when the
/// card scores, violet when a Joker acted on it.
///
/// This is the WebView's `.proc-chip` / `chipfloat`: big coloured text with a
/// dark outline and glow, NOT a small pill on a black box. The boxed version
/// read as a tiny status label; this reads as a score popping off the card.
class _RisingScoreChip extends StatefulWidget {
  const _RisingScoreChip({required this.text, required this.color, super.key});

  final String text;
  final Color color;

  @override
  State<_RisingScoreChip> createState() => _RisingScoreChipState();
}

class _RisingScoreChipState extends State<_RisingScoreChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_c.value);
          // Pop in with an overshoot, hold so it can be read, then rise + fade.
          final pop = _c.value < 0.22
              ? Curves.easeOutBack.transform(_c.value / 0.22)
              : 1.0;
          return Opacity(
            opacity: (1 - (t < 0.6 ? 0.0 : (t - 0.6) / 0.4)).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -34 * t),
              child: Transform.scale(scale: 0.6 + 0.4 * pop, child: child),
            ),
          );
        },
        child: Text(
          widget.text,
          style: TextStyle(
            color: widget.color,
            fontFamily: 'Bungee',
            fontSize: 22,
            height: 1,
            shadows: [
              const Shadow(color: Color(0xFF07070C), blurRadius: 1),
              const Shadow(
                color: Color(0xE6000000),
                offset: Offset(0, 2),
                blurRadius: 3,
              ),
              Shadow(
                color: widget.color.withValues(alpha: 0.75),
                blurRadius: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
