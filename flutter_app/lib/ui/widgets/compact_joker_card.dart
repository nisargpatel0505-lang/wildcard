import 'package:flutter/material.dart';

import '../../domain/joker_catalog.dart';
import '../wildcard_theme.dart';
import 'springy.dart';

/// Compact two-row-compatible Joker surface.
///
/// [highlighted] is driven by the controller's current [ScoreEvent]. The only
/// effect is a short colour wash and tiny scale change, keeping scoring cheap
/// on mid-range phones.
class CompactJokerCard extends StatelessWidget {
  const CompactJokerCard({
    this.joker,
    this.blocked = false,
    this.highlighted = false,
    this.triggerLabel,
    this.triggerSequence = 0,
    this.onTap,
    this.height = 58,
    super.key,
  });

  final JokerDefinition? joker;
  final bool blocked;
  final bool highlighted;
  final String? triggerLabel;
  final int triggerSequence;
  final VoidCallback? onTap;
  final double height;

  Color _rarityColor(WildcardThemeTokens tokens) => switch (joker?.rarity) {
    JokerRarity.common => tokens.gold,
    JokerRarity.uncommon => tokens.mint,
    JokerRarity.rare => tokens.rare,
    JokerRarity.wild => tokens.wild,
    null => tokens.line,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final accent = _rarityColor(tokens);
    if (joker == null) {
      return Semantics(
        label: 'Empty Joker slot',
        child: RepaintBoundary(
          child: ExcludeSemantics(
            child: SizedBox(
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.panel.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: tokens.violet.withValues(alpha: 0.55),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+',
                    style: TextStyle(
                      color: tokens.line,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final label = triggerLabel?.trim();
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label:
          '${joker!.name}. ${joker!.description}${blocked ? '. Blocked' : ''}',
      onTap: onTap,
      child: RepaintBoundary(
        child: ExcludeSemantics(
          // A Joker proc springs up and settles with overshoot rather than
          // easing to a dead stop, so it reads as a punch when it fires.
          child: SpringValue(
            target: highlighted ? 1.055 : 1,
            stiffness: 340,
            damping: 0.42,
            builder: (context, scale, child) => Transform.translate(
              offset: Offset(0, highlighted ? -3 : 0),
              child: Transform.scale(scale: scale, child: child),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: highlighted ? tokens.cream : accent,
                  width: highlighted ? 2.2 : 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(
                      tokens.panel,
                      accent,
                      highlighted ? 0.26 : 0.09,
                    )!,
                    tokens.panelStrong,
                  ],
                ),
                boxShadow: highlighted
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.32),
                          blurRadius: 9,
                        ),
                      ]
                    : const [],
              ),
              clipBehavior: Clip.antiAlias,
              child: Opacity(
                opacity: blocked ? 0.38 : 1,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      joker!.name.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      // Bungee at 8.5px is an all-caps display
                                      // face crushed too small to read. Space
                                      // Grotesk bold stays legible at this size.
                                      style: TextStyle(
                                        color: accent,
                                        fontFamily: 'SpaceGrotesk',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 9.5,
                                        letterSpacing: 0.3,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                  if (blocked)
                                    Icon(
                                      Icons.block_rounded,
                                      size: 12,
                                      color: tokens.coral,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Expanded(
                                child: Text(
                                  blocked
                                      ? 'Blocked this Heat'
                                      : joker!.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: tokens.creamDim,
                                    fontSize: 8,
                                    height: 1.12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (highlighted && label != null && label.isNotEmpty)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Text(
                                label,
                                key: ValueKey(
                                  'joker-proc-$triggerSequence-$label',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: accent,
                                  fontFamily: 'Bungee',
                                  fontSize: 9,
                                  letterSpacing: 0.2,
                                  height: 1,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xFF05060A),
                                      offset: Offset(0, 2),
                                      blurRadius: 2,
                                    ),
                                    Shadow(
                                      color: Color(0xE6000000),
                                      blurRadius: 5,
                                    ),
                                  ],
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
    );
  }
}
