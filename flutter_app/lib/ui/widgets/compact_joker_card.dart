import 'package:flutter/material.dart';

import '../../domain/joker_catalog.dart';
import '../../domain/scoring_engine.dart';
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
    this.triggerEventType,
    this.triggerSequence = 0,
    this.onTap,
    this.height = 58,
    super.key,
  });

  final JokerDefinition? joker;
  final bool blocked;
  final bool highlighted;
  final String? triggerLabel;
  final ScoreEventType? triggerEventType;
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
    final additiveProc = highlighted && triggerEventType == ScoreEventType.mult;
    final multiplicativeProc =
        highlighted && triggerEventType == ScoreEventType.xMult;
    final procAccent = additiveProc
        ? tokens.mint
        : multiplicativeProc
        ? tokens.wild
        : accent;
    final procKind = additiveProc
        ? 'additive'
        : multiplicativeProc
        ? 'multiplicative'
        : 'joker';
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      liveRegion: highlighted && label?.isNotEmpty == true,
      label:
          '${joker!.name}. ${joker!.description}'
          '${blocked ? '. Blocked' : ''}'
          '${highlighted && label?.isNotEmpty == true ? '. Triggered $label' : ''}',
      onTap: onTap,
      child: RepaintBoundary(
        child: ExcludeSemantics(
          // The short spring marks the active card without shifting the row.
          child: SpringValue(
            target: highlighted ? 1.035 : 1,
            stiffness: 340,
            damping: 0.42,
            builder: (context, scale, child) => Transform.translate(
              offset: Offset(0, highlighted ? -2 : 0),
              child: Transform.scale(scale: scale, child: child),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: highlighted ? procAccent : accent,
                  width: highlighted ? 2.2 : 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(
                      tokens.panel,
                      procAccent,
                      highlighted ? 0.3 : 0.09,
                    )!,
                    tokens.panelStrong,
                  ],
                ),
                boxShadow: highlighted
                    ? [
                        BoxShadow(
                          color: procAccent.withValues(alpha: 0.3),
                          blurRadius: 7,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  joker!.name.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: highlighted ? procAccent : accent,
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
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 140),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              child:
                                  highlighted &&
                                      label != null &&
                                      label.isNotEmpty
                                  ? Container(
                                      key: ValueKey(
                                        'joker-proc-$procKind-$triggerSequence',
                                      ),
                                      width: double.infinity,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: procAccent.withValues(
                                          alpha: 0.16,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: procAccent.withValues(
                                            alpha: 0.76,
                                          ),
                                        ),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          label,
                                          key: ValueKey(
                                            'joker-proc-label-$triggerSequence-$label',
                                          ),
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: procAccent,
                                            fontFamily: 'SpaceGrotesk',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            letterSpacing: 0.25,
                                            height: 1,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Text(
                                      blocked
                                          ? 'Blocked this Heat'
                                          : joker!.description,
                                      key: const ValueKey('joker-description'),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: tokens.creamDim,
                                        fontSize: 8,
                                        height: 1.12,
                                      ),
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
