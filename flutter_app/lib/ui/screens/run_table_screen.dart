import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/cards.dart';
import '../../domain/game_rules.dart';
import '../../domain/joker_catalog.dart';
import '../../domain/scoring_engine.dart';
import '../widgets/compact_joker_card.dart';
import '../widgets/playing_card_tile.dart';
import '../widgets/sly_sprite.dart';
import '../widgets/table_felt_surface.dart';
import '../widgets/wildcard_background.dart';
import '../widgets/wildcard_button.dart';
import '../wildcard_theme.dart';

/// Callback-driven phone table for an active WILDCARD run.
///
/// Domain objects are read directly, while all mutations remain outside the
/// widget. A controller advances [activeScoreEvent] to softly highlight the
/// card or Joker being resolved without running an animation queue in the UI.
class RunTableScreen extends StatelessWidget {
  const RunTableScreen({
    required this.state,
    required this.hand,
    required this.slySpeech,
    this.score,
    this.activeScoreEvent,
    this.highlightedHandIndex,
    this.highlightedJokerIndex,
    this.slyExpression = SlyExpression.idle,
    this.slySkin = SlySkin.classic,
    this.stakeText,
    this.jokerSummary,
    this.sortLabel = 'Rank',
    this.busy = false,
    this.backgroundRoom,
    this.backgroundAsset,
    this.tableFeltId = 'felt_classic',
    this.onToggleCard,
    this.onInspectJoker,
    this.onOpenHands,
    this.onOpenDeck,
    this.onSortCards,
    this.onPlay,
    this.onDiscard,
    this.onAbandon,
    super.key,
  });

  final ScoringState state;
  final List<PlayingCard> hand;
  final String slySpeech;
  final ScoreResult? score;

  /// The domain event currently being paced by the controller.
  final ScoreEvent? activeScoreEvent;

  /// Optional controller-resolved visible indices. A scoring event's card
  /// index can refer to the played-card subset rather than the current hand,
  /// so callers may explicitly map it before rendering.
  final int? highlightedHandIndex;
  final int? highlightedJokerIndex;
  final SlyExpression slyExpression;
  final SlySkin slySkin;
  final String? stakeText;
  final String? jokerSummary;
  final String sortLabel;
  final bool busy;
  final WildcardRoom? backgroundRoom;
  final String? backgroundAsset;
  final String tableFeltId;

  final ValueChanged<int>? onToggleCard;
  final ValueChanged<JokerDefinition>? onInspectJoker;
  final VoidCallback? onOpenHands;
  final VoidCallback? onOpenDeck;
  final VoidCallback? onSortCards;
  final VoidCallback? onPlay;
  final VoidCallback? onDiscard;
  final VoidCallback? onAbandon;

  @override
  Widget build(BuildContext context) {
    final selectedCount = hand.where((card) => card.selected).length;
    final room =
        backgroundRoom ??
        (state.hasBossModifier
            ? WildcardRoom.house
            : state.endless
            ? WildcardRoom.endless
            : WildcardRoom.themedHome);
    return Scaffold(
      backgroundColor: const Color(0xFF080414),
      body: WildcardBackground(
        room: room,
        asset: backgroundAsset,
        tintStrength: 0.78,
        child: SafeArea(
          minimum: const EdgeInsets.only(bottom: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metrics = _RunMetrics.from(constraints.biggest);
              return SingleChildScrollView(
                key: const Key('run-table-scroll'),
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.pagePadding,
                  vertical: metrics.outerGap,
                ),
                child: Column(
                  children: [
                    _SlyHeader(
                      speech: slySpeech,
                      expression: slyExpression,
                      skin: slySkin,
                      height: metrics.slyHeight,
                    ),
                    SizedBox(height: metrics.outerGap),
                    _HeatHud(
                      state: state,
                      stakeText: stakeText,
                      compact: metrics.compact,
                    ),
                    SizedBox(height: metrics.outerGap),
                    _TargetPanel(state: state, compact: metrics.compact),
                    if (state.hasAnyModifier) ...[
                      SizedBox(height: metrics.outerGap),
                      _ModifierPanel(state: state, compact: metrics.compact),
                    ],
                    SizedBox(height: metrics.outerGap),
                    _JokerSection(
                      state: state,
                      activeEvent: activeScoreEvent,
                      highlightedJokerIndex: highlightedJokerIndex,
                      summary: jokerSummary,
                      cardHeight: metrics.jokerHeight,
                      onInspect: onInspectJoker,
                    ),
                    SizedBox(height: metrics.outerGap),
                    _ScoreEquation(
                      state: state,
                      hand: hand,
                      score: score,
                      compact: metrics.compact,
                    ),
                    SizedBox(height: metrics.outerGap),
                    _TableArea(
                      tableFeltId: tableFeltId,
                      hand: hand,
                      activeEvent: activeScoreEvent,
                      highlightedHandIndex: highlightedHandIndex,
                      selectedCount: selectedCount,
                      maxSelected: state.effectiveMaxSelect,
                      sortLabel: sortLabel,
                      compact: metrics.compact,
                      cardWidth: metrics.cardWidth,
                      cardHeight: metrics.cardHeight,
                      busy: busy,
                      onToggleCard: onToggleCard,
                      onOpenHands: onOpenHands,
                      onOpenDeck: onOpenDeck,
                      onSortCards: onSortCards,
                      onPlay: onPlay,
                      onDiscard: onDiscard,
                      onAbandon: onAbandon,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SlyHeader extends StatelessWidget {
  const _SlyHeader({
    required this.speech,
    required this.expression,
    required this.skin,
    required this.height,
  });

  final String speech;
  final SlyExpression expression;
  final SlySkin skin;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: height,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: tokens.panelStrong,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: tokens.violet, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: SlySprite(
              expression: expression,
              skin: skin,
              size: height - 4,
              borderRadius: 10,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF6EFDF),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFE3D8C1)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                speech,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF242329),
                  fontSize: height < 72 ? 12 : 14,
                  height: 1.23,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeatHud extends StatelessWidget {
  const _HeatHud({
    required this.state,
    required this.stakeText,
    required this.compact,
  });

  final ScoringState state;
  final String? stakeText;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cells = <(String, String, _HudAccent)>[
      ('HEAT', '${state.stage}', _HudAccent.cream),
      ('PLAYS', '${state.handsLeft}', _HudAccent.coral),
      ('DISCARDS', '${state.discardsLeft}', _HudAccent.coral),
      ('DECK', '${state.deckCardsLeft}', _HudAccent.violet),
      ('RUN COINS', '${state.runCoins}', _HudAccent.gold),
      if (stakeText != null && stakeText!.trim().isNotEmpty)
        ('STAKED', stakeText!, _HudAccent.gold),
    ];
    return SizedBox(
      height: compact ? 48 : 57,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < cells.length; index++) ...[
            if (index > 0) const SizedBox(width: 3),
            Expanded(
              child: _HudCell(
                label: cells[index].$1,
                value: cells[index].$2,
                accent: cells[index].$3,
                compact: compact,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _HudAccent { cream, coral, violet, gold }

class _HudCell extends StatelessWidget {
  const _HudCell({
    required this.label,
    required this.value,
    required this.accent,
    required this.compact,
  });

  final String label;
  final String value;
  final _HudAccent accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final color = switch (accent) {
      _HudAccent.cream => tokens.cream,
      _HudAccent.coral => tokens.coral,
      _HudAccent.violet => tokens.violet,
      _HudAccent.gold => tokens.gold,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.panel.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: tokens.line.withValues(alpha: 0.82)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                color: tokens.creamDim,
                fontSize: compact ? 7.5 : 8.5,
                height: 1,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontFamily: 'Bungee',
                  fontSize: compact ? 17 : 20,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetPanel extends StatelessWidget {
  const _TargetPanel({required this.state, required this.compact});

  final ScoringState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final target = math.max(1, state.target);
    final progress = (state.stageScore / target).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: EdgeInsets.fromLTRB(10, compact ? 7 : 9, 10, compact ? 7 : 9),
      decoration: BoxDecoration(
        color: tokens.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: tokens.line.withValues(alpha: 0.9)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Heat score: ${_formatNumber(state.stageScore)}',
                  style: TextStyle(
                    color: tokens.cream,
                    fontSize: compact ? 11 : 13,
                    height: 1,
                  ),
                ),
              ),
              Text.rich(
                TextSpan(
                  text: 'Target: ',
                  children: [
                    TextSpan(
                      text: _formatNumber(target),
                      style: TextStyle(
                        color: tokens.gold,
                        fontFamily: 'Bungee',
                      ),
                    ),
                  ],
                ),
                style: TextStyle(
                  color: tokens.creamDim,
                  fontSize: compact ? 11 : 13,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: LinearProgressIndicator(
              minHeight: compact ? 8 : 10,
              value: progress,
              color: progress >= 1 ? tokens.gold : tokens.mint,
              backgroundColor: const Color(0xC805110E),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModifierPanel extends StatelessWidget {
  const _ModifierPanel({required this.state, required this.compact});

  final ScoringState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final modifiers = state.modifiers;
    final title = modifiers.map((modifier) => modifier.displayName).join(' + ');
    final descriptions = modifiers
        .map((modifier) => modifier.description)
        .join('  ');
    final blocked = state.blockedJokerIds
        .map((id) => jokersById[id]?.name ?? id)
        .join(', ');
    final detail = blocked.isEmpty
        ? descriptions
        : '$descriptions  Blocked: $blocked.';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 7 : 9),
      decoration: BoxDecoration(
        color: const Color(0xE02B1037),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: state.hasBossModifier ? tokens.gold : tokens.coral,
          width: state.hasBossModifier ? 2 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MODIFIER ACTIVE  \u00b7  ${title.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: state.hasBossModifier ? tokens.gold : tokens.coral,
              fontFamily: 'Bungee',
              fontSize: compact ? 8.5 : 9.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.cream,
              fontSize: compact ? 9 : 10,
              height: 1.18,
            ),
          ),
        ],
      ),
    );
  }
}

class _JokerSection extends StatelessWidget {
  const _JokerSection({
    required this.state,
    required this.activeEvent,
    required this.highlightedJokerIndex,
    required this.summary,
    required this.cardHeight,
    required this.onInspect,
  });

  final ScoringState state;
  final ScoreEvent? activeEvent;
  final int? highlightedJokerIndex;
  final String? summary;
  final double cardHeight;
  final ValueChanged<JokerDefinition>? onInspect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final activeJoker = highlightedJokerIndex ?? activeEvent?.jokerIndex;
    return Column(
      children: [
        Row(
          children: [
            Text(
              'JOKERS',
              style: TextStyle(
                color: tokens.mint,
                fontFamily: 'Bungee',
                fontSize: 10,
                height: 1,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                summary ??
                    (activeEvent?.label?.isNotEmpty == true
                        ? activeEvent!.label!
                        : '${state.jokerIds.length} of $maxJokers equipped'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: tokens.creamDim,
                  fontSize: 9,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 5.0;
            final width = (constraints.maxWidth - gap * 2) / 3;
            return Wrap(
              alignment: WrapAlignment.center,
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var index = 0; index < maxJokers; index++)
                  SizedBox(
                    width: width,
                    child: Builder(
                      builder: (context) {
                        final id = index < state.jokerIds.length
                            ? state.jokerIds[index]
                            : null;
                        final joker = id == null ? null : jokersById[id];
                        return CompactJokerCard(
                          key: ValueKey('run-joker-${id ?? index}'),
                          joker: joker,
                          blocked:
                              id != null && state.blockedJokerIds.contains(id),
                          highlighted: activeJoker == index,
                          triggerLabel: activeJoker == index
                              ? activeEvent?.label
                              : null,
                          height: cardHeight,
                          onTap: joker == null || onInspect == null
                              ? null
                              : () => onInspect!(joker),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ScoreEquation extends StatelessWidget {
  const _ScoreEquation({
    required this.state,
    required this.hand,
    required this.score,
    required this.compact,
  });

  final ScoringState state;
  final List<PlayingCard> hand;
  final ScoreResult? score;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final selected = hand.where((card) => card.selected).length;
    final label = score == null
        ? 'SELECT UP TO ${state.effectiveMaxSelect} CARDS'
        : '${score!.handType.legacyName.toUpperCase()} \u00b7 ${score!.scoringCount} CARDS SCORE';
    return Container(
      padding: EdgeInsets.fromLTRB(9, compact ? 6 : 7, 9, compact ? 7 : 9),
      decoration: BoxDecoration(
        color: tokens.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: tokens.line.withValues(alpha: 0.9)),
      ),
      child: Column(
        children: [
          Text(
            score == null && selected > 0 ? '$selected SELECTED' : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.gold,
              fontSize: compact ? 8.5 : 9.5,
              height: 1,
              letterSpacing: 0.35,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _EquationValue(
                  value: _formatNumber(score?.valuePoints ?? 0),
                  label: 'VALUE',
                  color: tokens.cream,
                  compact: compact,
                ),
              ),
              _EquationOperator('\u00d7', compact: compact),
              Expanded(
                child: _EquationValue(
                  value: (score?.multiplier ?? baseMultiplier).toStringAsFixed(
                    2,
                  ),
                  label: 'MULTIPLIER',
                  color: tokens.mint,
                  compact: compact,
                ),
              ),
              _EquationOperator('=', compact: compact),
              Expanded(
                child: _EquationValue(
                  value: _formatNumber(score?.total ?? 0),
                  label: 'SCORE',
                  color: tokens.gold,
                  compact: compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EquationValue extends StatelessWidget {
  const _EquationValue({
    required this.value,
    required this.label,
    required this.color,
    required this.compact,
  });

  final String value;
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontFamily: 'Bungee',
              fontSize: compact ? 23 : 28,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: context.wildcard.creamDim,
            fontSize: compact ? 7.5 : 8.5,
            height: 1,
            letterSpacing: 0.25,
          ),
        ),
      ],
    );
  }
}

class _EquationOperator extends StatelessWidget {
  const _EquationOperator(this.value, {required this.compact});

  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        value,
        style: TextStyle(
          color: context.wildcard.creamDim,
          fontFamily: 'Bungee',
          fontSize: compact ? 17 : 20,
        ),
      ),
    );
  }
}

class _TableArea extends StatelessWidget {
  const _TableArea({
    required this.tableFeltId,
    required this.hand,
    required this.activeEvent,
    required this.highlightedHandIndex,
    required this.selectedCount,
    required this.maxSelected,
    required this.sortLabel,
    required this.compact,
    required this.cardWidth,
    required this.cardHeight,
    required this.busy,
    required this.onToggleCard,
    required this.onOpenHands,
    required this.onOpenDeck,
    required this.onSortCards,
    required this.onPlay,
    required this.onDiscard,
    required this.onAbandon,
  });

  final String tableFeltId;
  final List<PlayingCard> hand;
  final ScoreEvent? activeEvent;
  final int? highlightedHandIndex;
  final int selectedCount;
  final int maxSelected;
  final String sortLabel;
  final bool compact;
  final double cardWidth;
  final double cardHeight;
  final bool busy;
  final ValueChanged<int>? onToggleCard;
  final VoidCallback? onOpenHands;
  final VoidCallback? onOpenDeck;
  final VoidCallback? onSortCards;
  final VoidCallback? onPlay;
  final VoidCallback? onDiscard;
  final VoidCallback? onAbandon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final canAct = !busy && selectedCount > 0;
    return TableFeltSurface(
      feltId: tableFeltId,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(6, 7, 6, compact ? 7 : 9),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _TableControl(
                  label: 'HANDS',
                  icon: const Text('\u2660'),
                  onTap: busy ? null : onOpenHands,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _TableControl(
                  label: 'DECK',
                  icon: const Icon(Icons.style_outlined, size: 15),
                  onTap: busy ? null : onOpenDeck,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _TableControl(
                  label: 'SORT: ${sortLabel.toUpperCase()}',
                  onTap: busy ? null : onSortCards,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 5 : 7),
          SizedBox(
            height: cardHeight + 12,
            child: hand.isEmpty
                ? Center(
                    child: Text(
                      'DEALING\u2026',
                      style: TextStyle(
                        color: tokens.creamDim,
                        fontFamily: 'Bungee',
                        fontSize: 11,
                      ),
                    ),
                  )
                : ListView.separated(
                    key: const Key('playing-card-row'),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(2, 9, 8, 2),
                    itemCount: hand.length,
                    separatorBuilder: (context, index) =>
                        SizedBox(width: compact ? 4 : 5),
                    itemBuilder: (context, index) {
                      final card = hand[index];
                      return PlayingCardTile(
                        key: ValueKey('hand-card-$index'),
                        card: card,
                        width: cardWidth,
                        height: cardHeight,
                        highlighted:
                            (highlightedHandIndex ?? activeEvent?.cardIndex) ==
                            index,
                        onTap: busy || onToggleCard == null
                            ? null
                            : () => onToggleCard!(index),
                      );
                    },
                  ),
          ),
          SizedBox(height: compact ? 5 : 7),
          Row(
            children: [
              Expanded(
                child: WildcardButton(
                  label: 'Play Hand',
                  onPressed: canAct ? onPlay : null,
                  variant: WildcardButtonVariant.secondary,
                  minHeight: compact ? 47 : 51,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 7,
                  ),
                  textAlign: TextAlign.center,
                  fontSize: compact ? 11 : 12,
                  showIconFrame: false,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: WildcardButton(
                  label: 'Discard ($selectedCount)',
                  onPressed: canAct ? onDiscard : null,
                  variant: WildcardButtonVariant.danger,
                  minHeight: compact ? 47 : 51,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 7,
                  ),
                  textAlign: TextAlign.center,
                  fontSize: compact ? 10.5 : 11.5,
                  showIconFrame: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: 132,
            child: WildcardButton(
              label: 'Abandon',
              onPressed: busy ? null : onAbandon,
              variant: WildcardButtonVariant.ghost,
              minHeight: 44,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              textAlign: TextAlign.center,
              fontSize: 9.5,
              showIconFrame: false,
            ),
          ),
          if (hand.length * (cardWidth + 4) > 300) ...[
            const SizedBox(height: 4),
            Text(
              'Swipe cards sideways \u00b7 select up to $maxSelected',
              style: TextStyle(
                color: tokens.creamDim.withValues(alpha: 0.78),
                fontSize: 7.5,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TableControl extends StatelessWidget {
  const _TableControl({required this.label, this.icon, required this.onTap});

  final String label;
  final Widget? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: SizedBox(
        height: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.panel.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.line),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(9),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      IconTheme(
                        data: IconThemeData(color: tokens.cream, size: 14),
                        child: DefaultTextStyle(
                          style: TextStyle(color: tokens.cream, fontSize: 13),
                          child: icon!,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(
                            color: tokens.cream,
                            fontFamily: 'Bungee',
                            fontSize: 8.5,
                            height: 1,
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
    );
  }
}

class _RunMetrics {
  const _RunMetrics({
    required this.pagePadding,
    required this.outerGap,
    required this.slyHeight,
    required this.jokerHeight,
    required this.cardWidth,
    required this.cardHeight,
    required this.compact,
  });

  factory _RunMetrics.from(Size size) {
    final compact = size.width < 340 || size.height < 650;
    final veryShort = size.height < 600;
    return _RunMetrics(
      pagePadding: compact ? 6 : 9,
      outerGap: veryShort
          ? 4
          : compact
          ? 5
          : 7,
      slyHeight: veryShort
          ? 64
          : compact
          ? 70
          : 82,
      jokerHeight: veryShort
          ? 53
          : compact
          ? 57
          : 63,
      cardWidth: compact ? 46 : 50,
      cardHeight: compact ? 80 : 88,
      compact: compact,
    );
  }

  final double pagePadding;
  final double outerGap;
  final double slyHeight;
  final double jokerHeight;
  final double cardWidth;
  final double cardHeight;
  final bool compact;
}

String _formatNumber(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final output = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) output.write(',');
    output.write(digits[index]);
  }
  return '${negative ? '-' : ''}$output';
}
