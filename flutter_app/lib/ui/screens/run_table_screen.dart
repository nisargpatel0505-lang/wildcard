import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/cards.dart';
import '../../domain/game_rules.dart';
import '../../domain/joker_catalog.dart';
import '../../domain/scoring_engine.dart';
import '../../domain/sly_quips.dart';
import '../../game/game_models.dart';
import '../responsive_metrics.dart';
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
    this.scoringTimeline,
    this.slyReaction,
    this.activeScoreEvent,
    this.liveRank,
    this.liveMultiplier,
    this.liveTotal,
    this.highlightedHandIndex,
    this.scoredCardIds = const <String>{},
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
  final ValueListenable<ScoringPresentation>? scoringTimeline;
  final ValueListenable<SlyReaction?>? slyReaction;

  /// The domain event currently being paced by the controller.
  final ScoreEvent? activeScoreEvent;

  /// Running equation values during scoring. When present these are shown
  /// instead of the final result so VALUE/MULTIPLIER/SCORE visibly climb as
  /// each card and Joker resolves.
  final int? liveRank;
  final double? liveMultiplier;
  final int? liveTotal;

  /// Optional controller-resolved visible indices. A scoring event's card
  /// index can refer to the played-card subset rather than the current hand,
  /// so callers may explicitly map it before rendering.
  final int? highlightedHandIndex;

  /// Card uids that have already scored this hand; they render lifted.
  final Set<String> scoredCardIds;

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
        energy: state.stageScore / math.max(1, state.target),
        modifierActive: state.hasAnyModifier,
        houseActive: state.hasBossModifier,
        child: SafeArea(
          minimum: const EdgeInsets.only(bottom: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final responsive = WildcardResponsiveMetrics.from(
                constraints.biggest,
              );
              final contentWidth = responsive.contentMaxWidth.isFinite
                  ? math.min(constraints.maxWidth, responsive.contentMaxWidth)
                  : constraints.maxWidth;
              final metrics = _RunMetrics.from(
                Size(contentWidth, constraints.maxHeight),
              );
              final legacyPresentation = ScoringPresentation(
                result: score,
                activeEvent: activeScoreEvent,
                activeJokerIndex: highlightedJokerIndex,
                visibleValuePoints: liveRank ?? score?.valuePoints ?? 0,
                visibleMultiplier:
                    liveMultiplier ?? score?.multiplier ?? baseMultiplier,
                visibleTotal: liveTotal ?? score?.total ?? 0,
                settledCardIds: scoredCardIds,
                phase: activeScoreEvent == null
                    ? ScorePresentationPhase.idle
                    : ScorePresentationPhase.beat,
              );

              Widget withPresentation(
                Widget Function(ScoringPresentation presentation) builder,
              ) {
                final timeline = scoringTimeline;
                if (timeline == null) return builder(legacyPresentation);
                return ValueListenableBuilder<ScoringPresentation>(
                  valueListenable: timeline,
                  builder: (context, presentation, _) => builder(presentation),
                );
              }

              Widget slyHeader() {
                final reactions = slyReaction;
                if (reactions == null) {
                  return _SlyHeader(
                    speech: slySpeech,
                    expression: slyExpression,
                    skin: slySkin,
                    height: metrics.slyHeight,
                  );
                }
                return ValueListenableBuilder<SlyReaction?>(
                  valueListenable: reactions,
                  builder: (context, reaction, _) => _SlyHeader(
                    speech: reaction?.speech ?? slySpeech,
                    expression: reaction?.expression ?? slyExpression,
                    skin: slySkin,
                    height: metrics.slyHeight,
                    reaction: reaction,
                  ),
                );
              }

              return SingleChildScrollView(
                key: const Key('run-table-scroll'),
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.pagePadding,
                  vertical: metrics.outerGap,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: Column(
                      children: [
                        slyHeader(),
                        SizedBox(height: metrics.outerGap),
                        _HeatHud(
                          state: state,
                          stakeText: stakeText,
                          compact: metrics.compact,
                        ),
                        SizedBox(height: metrics.outerGap),
                        withPresentation(
                          (presentation) => _TargetPanel(
                            state: state,
                            compact: metrics.compact,
                            stageScoreOverride:
                                presentation.isActive && !presentation.complete
                                ? state.stageScore + presentation.visibleTotal
                                : null,
                          ),
                        ),
                        if (state.hasAnyModifier) ...[
                          SizedBox(height: metrics.outerGap),
                          _ModifierPanel(
                            state: state,
                            compact: metrics.compact,
                          ),
                        ],
                        SizedBox(height: metrics.outerGap),
                        withPresentation(
                          (presentation) => _JokerSection(
                            state: state,
                            activeEvent: presentation.activeEvent,
                            highlightedJokerIndex:
                                presentation.activeJokerIndex,
                            summary: presentation.label.isEmpty
                                ? jokerSummary
                                : presentation.label,
                            presentationSequence: presentation.sequence,
                            cardHeight: metrics.jokerHeight,
                            onInspect: onInspectJoker,
                          ),
                        ),
                        SizedBox(height: metrics.outerGap),
                        withPresentation((presentation) {
                          final displayHand =
                              presentation.handSnapshot.isNotEmpty
                              ? presentation.handSnapshot
                              : hand;
                          return _ScoreEquation(
                            state: state,
                            hand: displayHand,
                            score: presentation.result ?? score,
                            compact: metrics.compact,
                            liveRank: presentation.isActive
                                ? presentation.visibleValuePoints
                                : liveRank,
                            liveMultiplier: presentation.isActive
                                ? presentation.visibleMultiplier
                                : liveMultiplier,
                            liveTotal: presentation.isActive
                                ? presentation.visibleTotal
                                : liveTotal,
                          );
                        }),
                        SizedBox(height: metrics.outerGap),
                        withPresentation((presentation) {
                          final displayHand =
                              presentation.handSnapshot.isNotEmpty
                              ? presentation.handSnapshot
                              : hand;
                          final activeId = presentation.activeCardId;
                          final activeIndex = activeId == null
                              ? highlightedHandIndex
                              : displayHand.indexWhere(
                                  (card) => card.uid == activeId,
                                );
                          return _TableArea(
                            tableFeltId: tableFeltId,
                            hand: displayHand,
                            activeEvent:
                                presentation.activeEvent ?? activeScoreEvent,
                            highlightedHandIndex:
                                activeIndex == null || activeIndex < 0
                                ? null
                                : activeIndex,
                            scoredCardIds: presentation.isActive
                                ? presentation.settledCardIds
                                : scoredCardIds,
                            scoringCardIds: presentation.scoringCardIds,
                            presentationSequence: presentation.sequence,
                            chipLabel: presentation.label,
                            chipStyle: presentation.chipStyle,
                            selectedCount: displayHand
                                .where((card) => card.selected)
                                .length,
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
                          );
                        }),
                      ],
                    ),
                  ),
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
    this.reaction,
  });

  final String speech;
  final SlyExpression expression;
  final SlySkin skin;
  final double height;
  final SlyReaction? reaction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final reactionColor = _slyReactionColor(tokens, reaction?.mood);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SlyReactionMotion(
            key: ValueKey('sly-reaction-${reaction?.sequence ?? 0}'),
            profile: reaction?.motion ?? SlyMotionProfile.none,
            child: Container(
              width: height,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: tokens.panelStrong,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: reactionColor, width: 2.4),
                boxShadow: [
                  BoxShadow(
                    color: reactionColor.withValues(
                      alpha: reaction == null ? 0.16 : 0.48,
                    ),
                    blurRadius: reaction == null ? 5 : 14,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: SlySprite(
                  key: ValueKey('sly-face-${expression.name}'),
                  expression: expression,
                  skin: skin,
                  size: height - 4,
                  borderRadius: 10,
                ),
              ),
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 170),
                child: Text(
                  speech,
                  key: ValueKey(
                    'sly-speech-${reaction?.sequence ?? 0}-$speech',
                  ),
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
          ),
        ],
      ),
    );
  }
}

class _SlyReactionMotion extends StatefulWidget {
  const _SlyReactionMotion({
    required this.profile,
    required this.child,
    super.key,
  });

  final SlyMotionProfile profile;
  final Widget child;

  @override
  State<_SlyReactionMotion> createState() => _SlyReactionMotionState();
}

class _SlyReactionMotionState extends State<_SlyReactionMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!disabled && widget.profile != SlyMotionProfile.none) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile == SlyMotionProfile.none) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final envelope = math.sin(t * math.pi) * (1 - t * 0.25);
        final (offset, angle, scale) = switch (widget.profile) {
          SlyMotionProfile.pop => (
            Offset(0, -5 * envelope),
            0.0,
            1 + 0.075 * envelope,
          ),
          SlyMotionProfile.rock => (
            Offset(0, -3 * envelope),
            math.sin(t * math.pi * 2.4) * 0.055 * (1 - t),
            1 + 0.055 * envelope,
          ),
          SlyMotionProfile.tremble => (
            Offset(
              math.sin(t * math.pi * 9) * 3.2 * (1 - t),
              math.cos(t * math.pi * 7) * 1.4 * (1 - t),
            ),
            math.sin(t * math.pi * 7) * 0.025 * (1 - t),
            1.0,
          ),
          SlyMotionProfile.none => (Offset.zero, 0.0, 1.0),
        };
        return Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
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
  const _TargetPanel({
    required this.state,
    required this.compact,
    this.stageScoreOverride,
  });

  final ScoringState state;
  final bool compact;
  final int? stageScoreOverride;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final target = math.max(1, state.target);
    final stageScore = stageScoreOverride ?? state.stageScore;
    final progress = (stageScore / target).clamp(0.0, 1.0).toDouble();
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
                  'Heat score: ${_formatNumber(stageScore)}',
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
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700,
              fontSize: compact ? 10 : 11,
              letterSpacing: 0.4,
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
    required this.presentationSequence,
    required this.cardHeight,
    required this.onInspect,
  });

  final ScoringState state;
  final ScoreEvent? activeEvent;
  final int? highlightedJokerIndex;
  final String? summary;
  final int presentationSequence;
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
                          triggerLabel: activeJoker == index ? summary : null,
                          triggerSequence: presentationSequence,
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
    this.liveRank,
    this.liveMultiplier,
    this.liveTotal,
  });

  final ScoringState state;
  final List<PlayingCard> hand;
  final ScoreResult? score;
  final bool compact;

  /// Running values while a hand is being scored. The controller already
  /// computes these beat by beat; before this they were thrown away and the
  /// equation jumped straight to the final total, so scoring looked static.
  final int? liveRank;
  final double? liveMultiplier;
  final int? liveTotal;

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
                  value: _formatNumber(liveRank ?? score?.valuePoints ?? 0),
                  label: 'VALUE',
                  color: tokens.cream,
                  compact: compact,
                ),
              ),
              _EquationOperator('\u00d7', compact: compact),
              Expanded(
                child: _EquationValue(
                  value: (liveMultiplier ?? score?.multiplier ?? baseMultiplier)
                      .toStringAsFixed(2),
                  label: 'MULTIPLIER',
                  color: tokens.mint,
                  compact: compact,
                ),
              ),
              _EquationOperator('=', compact: compact),
              Expanded(
                child: _EquationValue(
                  value: _formatNumber(liveTotal ?? score?.total ?? 0),
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

/// Equation figure that visibly reacts when it changes.
///
/// The controller was already stepping VALUE/MULTIPLIER/SCORE through each
/// beat, but the text simply swapped between numbers with no motion, which
/// reads as "nothing happened". Every change now punches the figure and
/// flashes it toward white before settling.
class _EquationValue extends StatefulWidget {
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
  State<_EquationValue> createState() => _EquationValueState();
}

class _EquationValueState extends State<_EquationValue>
    with SingleTickerProviderStateMixin {
  // The number rolls up to its new value over ~520ms — slow enough to read the
  // SCORE climbing rather than snapping. Kept just under the card beat so each
  // step finishes before the next begins.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );

  double? _fromNum;
  double? _toNum;
  bool _decimal = false;

  static double? _parse(String value) =>
      double.tryParse(value.replaceAll(',', ''));

  @override
  void initState() {
    super.initState();
    _toNum = _parse(widget.value);
    _fromNum = _toNum;
    _decimal = widget.value.contains('.');
  }

  @override
  void didUpdateWidget(covariant _EquationValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      _fromNum = disabled ? _parse(widget.value) : _toNum;
      _toNum = _parse(widget.value);
      _decimal = widget.value.contains('.');
      if (!disabled) _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  String _display(double t) {
    final from = _fromNum, to = _toNum;
    if (from == null || to == null) return widget.value;
    final current = from + (to - from) * t;
    if (_decimal) return current.toStringAsFixed(2);
    return _formatNumber(current.round());
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final compact = widget.compact;
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: AnimatedBuilder(
            animation: _pop,
            builder: (context, _) {
              final t = Curves.easeOutCubic.transform(_pop.value);
              // Swell and settle while the number rolls up.
              final scale = 1 + 0.18 * (1 - t) * (1 - t);
              final glow = (1 - t).clamp(0.0, 1.0);
              return Transform.scale(
                scale: scale,
                child: Text(
                  _display(t),
                  style: TextStyle(
                    color: Color.lerp(color, Colors.white, glow * 0.85),
                    fontFamily: 'Bungee',
                    fontSize: compact ? 23 : 28,
                    height: 1,
                    shadows: glow <= 0.02
                        ? null
                        : [
                            Shadow(
                              color: color.withValues(alpha: glow),
                              blurRadius: 16 * glow,
                            ),
                          ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 3),
        Text(
          widget.label,
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
    required this.scoredCardIds,
    required this.scoringCardIds,
    required this.presentationSequence,
    required this.chipLabel,
    required this.chipStyle,
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
  final Set<String> scoredCardIds;
  final Set<String> scoringCardIds;
  final int presentationSequence;
  final String chipLabel;
  final ScoreChipStyle chipStyle;
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
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // The whole hand must be visible in one look. Divide the
                      // real width across the cards instead of using a fixed
                      // card size in a horizontal scroller.
                      const outerPadding = 4.0;
                      final gap = compact ? 3.0 : 4.0;
                      final available =
                          constraints.maxWidth - (outerPadding * 2);
                      final count = hand.length;
                      final fitted = (available - gap * (count - 1)) / count;
                      // Below this the rank stops being legible; only then do
                      // we fall back to scrolling (very large hands only).
                      const minReadable = 27.0;
                      final tileWidth = fitted.clamp(minReadable, cardWidth);
                      final tileHeight = (cardHeight * (tileWidth / cardWidth))
                          .clamp(cardHeight * 0.66, cardHeight);
                      final scrolls = fitted < minReadable;
                      final tiles = <Widget>[
                        for (var index = 0; index < count; index++) ...[
                          if (index > 0) SizedBox(width: gap),
                          // Keyed by card identity: a genuinely new card deals
                          // in with the staggered drop, while sorts and refills
                          // of existing cards never re-animate.
                          _DealIn(
                            key: ValueKey(
                              'deal-${hand[index].uid ?? 'slot-$index'}',
                            ),
                            index: index,
                            child: PlayingCardTile(
                              key: ValueKey(
                                'hand-card-${hand[index].uid ?? 'slot-$index'}',
                              ),
                              card: hand[index],
                              width: tileWidth,
                              height: tileHeight,
                              highlighted:
                                  (highlightedHandIndex ??
                                      activeEvent?.cardIndex) ==
                                  index,
                              // Already scored earlier this hand: settled glow.
                              scored:
                                  hand[index].uid != null &&
                                  scoredCardIds.contains(hand[index].uid),
                              dimmed:
                                  scoringCardIds.isNotEmpty &&
                                  hand[index].selected &&
                                  !scoringCardIds.contains(hand[index].uid),
                              // Points this card just contributed, so scoring is
                              // visible on the card itself and not only in the
                              // equation panel.
                              scoreChip:
                                  (highlightedHandIndex ??
                                              activeEvent?.cardIndex) ==
                                          index &&
                                      activeEvent != null &&
                                      chipLabel.isNotEmpty
                                  ? chipLabel
                                  : null,
                              // Gold when the card itself scores; violet when a
                              // Joker acted on it (the WebView's colour split).
                              scoreChipColor: _chipColorForStyle(
                                context,
                                chipStyle,
                              ),
                              highlightColor: _chipColorForStyle(
                                context,
                                chipStyle,
                              ),
                              scoreChipSequence: presentationSequence,
                              onTap: busy || onToggleCard == null
                                  ? null
                                  : () => onToggleCard!(index),
                            ),
                          ),
                        ],
                      ];
                      final row = Row(
                        key: const Key('playing-card-row'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: tiles,
                      );
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(
                          outerPadding,
                          9,
                          outerPadding,
                          2,
                        ),
                        child: scrolls
                            ? SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: row,
                              )
                            : Center(child: row),
                      );
                    },
                  ),
          ),
          SizedBox(height: compact ? 5 : 7),
          Row(
            children: [
              // Discard on the left (red), Play Hand on the right (green) — the
              // "go" action sits on the dominant side.
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
                  fontFamily: 'SpaceGrotesk',
                  showIconFrame: false,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: WildcardButton(
                  label: 'Play Hand',
                  onPressed: canAct ? onPlay : null,
                  variant: WildcardButtonVariant.success,
                  minHeight: compact ? 47 : 51,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 7,
                  ),
                  textAlign: TextAlign.center,
                  fontSize: compact ? 11 : 12,
                  fontFamily: 'SpaceGrotesk',
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
              fontFamily: 'SpaceGrotesk',
              showIconFrame: false,
            ),
          ),
          // The hand now scales to fit in one look, so the old "swipe sideways"
          // hint would be actively misleading. Keep only the selection limit.
          const SizedBox(height: 4),
          Text(
            'Select up to $maxSelected cards',
            style: TextStyle(
              color: tokens.creamDim.withValues(alpha: 0.78),
              fontSize: 8,
              height: 1,
            ),
          ),
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
                            fontFamily: 'SpaceGrotesk',
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 0.4,
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

/// Deals a newly-drawn card onto the table: a short staggered drop-and-fade,
/// the WebView's `@keyframes deal`. The wrapper is keyed by card uid, so it
/// fires exactly once per physical card — sorting or refilling the rest of the
/// hand never re-deals them.
class _DealIn extends StatefulWidget {
  const _DealIn({required this.index, required this.child, super.key});

  final int index;
  final Widget child;

  @override
  State<_DealIn> createState() => _DealInState();
}

class _DealInState extends State<_DealIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disabled) {
      _c.value = 1;
      return;
    }
    // ~55ms between cards: enough to read as dealing one at a time, short
    // enough that a full nine-card hand still lands in about half a second.
    final wait = 55 * widget.index.clamp(0, 12);
    if (wait == 0) {
      _c.forward();
    } else {
      _delay = Timer(Duration(milliseconds: wait), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        if (t >= 1) return child!;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, -16 * (1 - t)),
            child: child,
          ),
        );
      },
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
    final responsive = WildcardResponsiveMetrics.from(size);
    final compact = responsive.isCompact;
    final veryShort = responsive.isVeryShort;
    return _RunMetrics(
      pagePadding: responsive.pagePadding,
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
      // Cards are taller within the same width for a truer card shape and to
      // give the centre pip room to breathe. Width is unchanged so a full hand
      // still fits across without scrolling.
      cardWidth: compact ? 46 : 50,
      cardHeight: compact ? 94 : 104,
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

Color _chipColorForStyle(BuildContext context, ScoreChipStyle style) =>
    switch (style) {
      ScoreChipStyle.card || ScoreChipStyle.jackpot => const Color(0xFFF7C548),
      ScoreChipStyle.joker ||
      ScoreChipStyle.multiplier => context.wildcard.violet,
      ScoreChipStyle.modifier => context.wildcard.mint,
      ScoreChipStyle.suspense => context.wildcard.creamDim,
      ScoreChipStyle.miss => context.wildcard.coral,
    };

Color _slyReactionColor(WildcardThemeTokens tokens, SlyMood? mood) =>
    switch (mood) {
      SlyMood.sevenMiss || SlyMood.scared || SlyMood.clutch => tokens.coral,
      SlyMood.unbelievable ||
      SlyMood.quads ||
      SlyMood.straightFlush ||
      SlyMood.royalFlush ||
      SlyMood.sevenHit => tokens.gold,
      SlyMood.impressed ||
      SlyMood.fullHouse ||
      SlyMood.straight ||
      SlyMood.flush => tokens.mint,
      SlyMood.laughing || SlyMood.highCard => tokens.wild,
      _ => tokens.violet,
    };

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
