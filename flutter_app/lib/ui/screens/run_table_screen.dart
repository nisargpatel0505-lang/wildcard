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
    this.guidedFirstRun = false,
    this.guideStep = 0,
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
  final bool guidedFirstRun;
  final int guideStep;

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
      backgroundColor: context.wildcard.pageBackground,
      body: WildcardBackground(
        room: room,
        surface: room == WildcardRoom.themedHome
            ? WildcardUiSurface.normalGameplay
            : null,
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
                label: activeScoreEvent?.label ?? '',
                visibleValuePoints: liveRank ?? score?.valuePoints ?? 0,
                visibleMultiplier:
                    liveMultiplier ?? score?.multiplier ?? baseMultiplier,
                visibleTotal: liveTotal ?? score?.total ?? 0,
                settledCardIds: scoredCardIds,
                sequence: activeScoreEvent == null ? 0 : 1,
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
                        SizedBox(
                          height: metrics.outerGap + metrics.playfieldDrop,
                        ),
                        if (guidedFirstRun) ...[
                          _FirstRunCoach(step: guideStep),
                          SizedBox(height: metrics.outerGap),
                        ],
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
                            activeEvent: presentation.activeEvent,
                            procLabel: presentation.label,
                            presentationSequence: presentation.sequence,
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
                            state: state,
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
                            activeChips: presentation.activeChips,
                            presentationSequence: presentation.sequence,
                            chipLabel: presentation.label,
                            chipStyle: presentation.chipStyle,
                            selectedCount: displayHand
                                .where((card) => card.selected)
                                .length,
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
    final currentReaction = reaction;
    final reactionColor = _slyReactionColor(tokens, currentReaction?.mood);
    final active = currentReaction != null;
    final sequence = currentReaction?.sequence ?? 0;
    return SizedBox(
      height: height,
      child: _SlyReactionMotion(
        profile: currentReaction?.motion ?? SlyMotionProfile.none,
        sequence: sequence,
        child: Semantics(
          container: true,
          liveRegion: active,
          child: AnimatedContainer(
            key: const Key('sly-header-panel'),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                reactionColor.withValues(alpha: active ? 0.17 : 0.05),
                tokens.panelStrong,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: reactionColor.withValues(alpha: active ? 0.95 : 0.56),
                width: active ? 2.0 : 1.25,
              ),
              boxShadow: [
                BoxShadow(
                  color: reactionColor.withValues(alpha: active ? 0.42 : 0.14),
                  blurRadius: active ? 17 : 7,
                  spreadRadius: active ? -1 : -3,
                ),
                const BoxShadow(
                  color: Color(0x8A000000),
                  blurRadius: 11,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: height - 6,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: tokens.panelStrong,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: reactionColor.withValues(
                        alpha: active ? 0.74 : 0.28,
                      ),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SlySprite(
                    key: const Key('sly-face'),
                    expression: expression,
                    skin: skin,
                    reactionActive: active,
                    size: height - 10,
                    borderRadius: 9,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: height < 72 ? 9 : 12,
                      vertical: height < 72 ? 5 : 7,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? reactionColor.withValues(alpha: 0.11)
                          : tokens.cream.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: active
                            ? reactionColor.withValues(alpha: 0.48)
                            : tokens.line.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (active) ...[
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              key: ValueKey('sly-reaction-badge-$sequence'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: reactionColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: reactionColor.withValues(alpha: 0.78),
                                ),
                              ),
                              child: Text(
                                currentReaction.label,
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: TextStyle(
                                  color: reactionColor,
                                  fontSize: height < 72 ? 8.5 : 9.5,
                                  height: 1.15,
                                  letterSpacing: 0.85,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 170),
                            child: Text(
                              speech,
                              key: ValueKey('sly-speech-$sequence-$speech'),
                              maxLines: active ? 2 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.cream,
                                fontSize: height < 72 ? 11.5 : 13.5,
                                height: 1.18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
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
    );
  }
}

class _SlyReactionMotion extends StatefulWidget {
  const _SlyReactionMotion({
    required this.profile,
    required this.sequence,
    required this.child,
  });

  final SlyMotionProfile profile;
  final int sequence;
  final Widget child;

  @override
  State<_SlyReactionMotion> createState() => _SlyReactionMotionState();
}

class _SlyReactionMotionState extends State<_SlyReactionMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
    value: 1,
  );

  bool get _animationsDisabled =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _play() {
    if (_animationsDisabled || widget.profile == SlyMotionProfile.none) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _play();
  }

  @override
  void didUpdateWidget(covariant _SlyReactionMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sequence != widget.sequence ||
        oldWidget.profile != widget.profile) {
      _play();
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
        final envelope = math.sin(t * math.pi) * (1 - t * 0.18);
        final (offset, angle, scale) = switch (widget.profile) {
          SlyMotionProfile.pop => (
            Offset(0, -7 * envelope),
            0.0,
            1 + 0.026 * envelope,
          ),
          SlyMotionProfile.rock => (
            Offset(0, -4 * envelope),
            math.sin(t * math.pi * 2.8) * 0.018 * (1 - t),
            1 + 0.02 * envelope,
          ),
          SlyMotionProfile.tremble => (
            Offset(
              math.sin(t * math.pi * 10) * 5.2 * (1 - t),
              math.cos(t * math.pi * 8) * 2.1 * (1 - t),
            ),
            math.sin(t * math.pi * 8) * 0.014 * (1 - t),
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
              backgroundColor: tokens.disabledFill,
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
        color: Color.alphaBlend(
          (state.hasBossModifier ? tokens.gold : tokens.violet).withValues(
            alpha: .14,
          ),
          tokens.surfaceStrong,
        ),
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
    final eventLabel = activeEvent?.label?.trim();
    final fallbackLabel = summary?.trim();
    final triggerLabel = eventLabel?.isNotEmpty == true
        ? eventLabel
        : fallbackLabel?.isNotEmpty == true
        ? fallbackLabel
        : null;
    final activeJokerDefinition =
        activeJoker != null &&
            activeJoker >= 0 &&
            activeJoker < state.jokerIds.length
        ? jokersById[state.jokerIds[activeJoker]]
        : null;
    final activeSummary = activeJokerDefinition != null && triggerLabel != null
        ? '${activeJokerDefinition.name} \u00b7 $triggerLabel'
        : null;
    return Column(
      children: [
        Row(
          children: [
            Text(
              'JOKERS',
              style: TextStyle(
                color: tokens.mint,
                fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700,
                fontSize: 10,
                height: 1,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                activeSummary ??
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
                        final modifierStatus = joker == null
                            ? JokerModifierStatus.active
                            : jokerModifierStatus(state, joker);
                        return CompactJokerCard(
                          key: ValueKey('run-joker-${id ?? index}'),
                          joker: joker,
                          blocked: modifierStatus.blocked,
                          multiplierSuppressed:
                              modifierStatus.multiplierSuppressed,
                          redundant: modifierStatus.redundant,
                          modifierStatusLabel: modifierStatus.label,
                          highlighted: activeJoker == index,
                          triggerLabel: activeJoker == index
                              ? triggerLabel
                              : null,
                          triggerEventType: activeJoker == index
                              ? activeEvent?.type
                              : null,
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

class _FirstRunCoach extends StatelessWidget {
  const _FirstRunCoach({required this.step});

  final int step;

  static const _lessons = <(String, String)>[
    (
      'YOUR FIRST HAND',
      'Select cards that form a Pair or better, then check the live Value × Multiplier preview.',
    ),
    (
      'READ THE ENGINE',
      'Copper Chip adds safe Mult. Pair Polisher rewards Pair-or-better hands. Make the effects agree.',
    ),
    (
      'DISCARD WITH A PLAN',
      'Throw away cards that do not help your next Pair, Straight or Flush. They stay out this Heat.',
    ),
    (
      'THE FIRST SHOP',
      'Buy one Joker that strengthens the same plan. Coins you keep earn interest after a clear.',
    ),
    (
      'KEEP THE PACE',
      'Compare the target with Plays remaining. A focused engine beats unrelated bonuses.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final index = math.max(0, math.min(_lessons.length - 1, step));
    final lesson = _lessons[index];
    final tokens = context.wildcard;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Sly coaching. ${lesson.$1}. ${lesson.$2}',
      child: Container(
        key: Key('first-run-coach-$index'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.panelStrong.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tokens.gold.withValues(alpha: 0.9)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.school_rounded, color: tokens.gold, size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SLY · ${lesson.$1}',
                    style: TextStyle(
                      color: tokens.gold,
                      fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.5,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lesson.$2,
                    style: TextStyle(
                      color: tokens.cream,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      height: 1.22,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    this.activeEvent,
    this.procLabel,
    this.presentationSequence = 0,
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
  final ScoreEvent? activeEvent;
  final String? procLabel;
  final int presentationSequence;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final selected = hand.where((card) => card.selected).length;
    final procKind = switch (activeEvent?.type) {
      ScoreEventType.mult when (activeEvent?.jokerIndex ?? -1) >= 0 =>
        _MultiplierProcKind.additive,
      ScoreEventType.xMult when (activeEvent?.jokerIndex ?? -1) >= 0 =>
        _MultiplierProcKind.multiplicative,
      _ => null,
    };
    final exactProcLabel = procKind == null
        ? null
        : activeEvent?.label?.trim().isNotEmpty == true
        ? activeEvent!.label!.trim()
        : procLabel?.trim().isNotEmpty == true
        ? procLabel!.trim()
        : null;
    final multiplierColor = switch (procKind) {
      _MultiplierProcKind.additive => tokens.mint,
      _MultiplierProcKind.multiplicative => tokens.wild,
      null => tokens.mint,
    };
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
                  color: multiplierColor,
                  compact: compact,
                  procLabel: exactProcLabel,
                  procKind: procKind,
                  procSequence: presentationSequence,
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
    this.procLabel,
    this.procKind,
    this.procSequence = 0,
  });

  final String value;
  final String label;
  final Color color;
  final bool compact;
  final String? procLabel;
  final _MultiplierProcKind? procKind;
  final int procSequence;

  @override
  State<_EquationValue> createState() => _EquationValueState();
}

class _EquationValueState extends State<_EquationValue>
    with SingleTickerProviderStateMixin {
  // The number rolls up over ~520ms so SCORE visibly climbs. Card beats can
  // overlap that window; a restart therefore begins at the interpolated number
  // already on screen instead of snapping to the previous target.
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

  double? _currentNumber() {
    final from = _fromNum;
    final to = _toNum;
    if (from == null || to == null) return to;
    final t = Curves.easeOutCubic.transform(_pop.value);
    return from + (to - from) * t;
  }

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
      final next = _parse(widget.value);
      _fromNum = disabled ? next : _currentNumber();
      _toNum = next;
      _decimal = widget.value.contains('.');
      if (disabled) {
        _pop.value = 1;
      } else {
        _pop.forward(from: 0);
      }
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
    final procKind = widget.procKind;
    final procLabel = widget.procLabel;
    final procActive = procKind != null && procLabel?.isNotEmpty == true;
    final procName = procKind?.name;
    return SizedBox(
      height: compact ? 42 : 48,
      child: Semantics(
        excludeSemantics: true,
        liveRegion: procActive,
        label: procActive
            ? 'Multiplier ${widget.value}. Joker triggered $procLabel'
            : '${widget.label} ${widget.value}',
        child: AnimatedContainer(
          key: ValueKey('equation-${widget.label.toLowerCase()}-cell'),
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: procActive ? color.withValues(alpha: 0.13) : null,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: procActive
                  ? color.withValues(alpha: 0.72)
                  : Colors.transparent,
            ),
          ),
          child: Column(
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
                        key: ValueKey(
                          'equation-${widget.label.toLowerCase()}-value',
                        ),
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
                                    blurRadius: 10 * glow,
                                  ),
                                ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: compact ? 12 : 13,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: procActive
                      ? SizedBox(
                          key: ValueKey(
                            'equation-proc-$procName-${widget.procSequence}',
                          ),
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              procLabel!,
                              maxLines: 1,
                              style: TextStyle(
                                color: color,
                                fontFamily: 'SpaceGrotesk',
                                fontWeight: FontWeight.w700,
                                fontSize: compact ? 9.5 : 10.5,
                                height: 1,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          widget.label,
                          key: ValueKey('equation-label-${widget.label}'),
                          maxLines: 1,
                          style: TextStyle(
                            color: context.wildcard.creamDim,
                            fontSize: compact ? 7.5 : 8.5,
                            height: 1,
                            letterSpacing: 0.25,
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

enum _MultiplierProcKind { additive, multiplicative }

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
    required this.state,
    required this.tableFeltId,
    required this.hand,
    required this.activeEvent,
    required this.highlightedHandIndex,
    required this.scoredCardIds,
    required this.scoringCardIds,
    required this.activeChips,
    required this.presentationSequence,
    required this.chipLabel,
    required this.chipStyle,
    required this.selectedCount,
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

  final ScoringState state;
  final String tableFeltId;
  final List<PlayingCard> hand;
  final ScoreEvent? activeEvent;
  final int? highlightedHandIndex;
  final Set<String> scoredCardIds;
  final Set<String> scoringCardIds;
  final List<ScoreVisualChip> activeChips;
  final int presentationSequence;
  final String chipLabel;
  final ScoreChipStyle chipStyle;
  final int selectedCount;
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
                      // Match the WebView's readable fan: full-size cards with
                      // a broad visible rank strip, rather than crushing nine
                      // cards into ~35 dp slivers. Cards themselves remain
                      // completely static; only their z-order overlaps.
                      const outerPadding = 4.0;
                      final available =
                          constraints.maxWidth - (outerPadding * 2);
                      final count = hand.length;
                      final tileWidth = math.min(cardWidth, available);
                      final tileHeight = cardHeight;
                      final naturalStep = count <= 1
                          ? 0.0
                          : (available - tileWidth) / (count - 1);
                      // At least 28 dp of each rank strip remains exposed, so
                      // neighbouring selections have a forgiving target.
                      final step = count <= 1
                          ? 0.0
                          : naturalStep.clamp(28.0, tileWidth + 4);
                      final handWidth = count <= 1
                          ? tileWidth
                          : tileWidth + step * (count - 1);
                      final stack = SizedBox(
                        key: const Key('playing-card-row'),
                        width: handWidth,
                        height: tileHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (var index = 0; index < count; index++)
                              Positioned(
                                left: index * step,
                                top: 0,
                                child: Builder(
                                  builder: (context) {
                                    final card = hand[index];
                                    final rankSuppressed = state
                                        .cardRankSuppressed(card);
                                    final selectionDisabled =
                                        !card.selected &&
                                        selectedCount >=
                                            state.effectiveMaxSelect;
                                    final enhancementSuppressed =
                                        state.hasModifier(
                                          HeatModifier.nullField,
                                        ) &&
                                        (card.enhancement ==
                                                CardEnhancement.neon ||
                                            card.enhancement ==
                                                CardEnhancement.glass);
                                    ScoreVisualChip? retainedChip;
                                    for (final chip in activeChips) {
                                      if (chip.cardId == card.uid) {
                                        retainedChip = chip;
                                      }
                                    }
                                    final active =
                                        (highlightedHandIndex ??
                                            activeEvent?.cardIndex) ==
                                        index;
                                    final fallbackChip =
                                        retainedChip == null &&
                                        active &&
                                        activeEvent != null &&
                                        chipLabel.isNotEmpty;
                                    final visibleStyle =
                                        retainedChip?.style ?? chipStyle;
                                    final mutedChip =
                                        retainedChip?.muted ??
                                        (fallbackChip &&
                                            activeEvent?.type ==
                                                ScoreEventType.card &&
                                            activeEvent?.amount == 0);
                                    return PlayingCardTile(
                                      key: ValueKey(
                                        'hand-card-${card.uid ?? 'slot-$index'}',
                                      ),
                                      card: card,
                                      width: tileWidth,
                                      height: tileHeight,
                                      highlighted: active,
                                      scored:
                                          card.uid != null &&
                                          scoredCardIds.contains(card.uid),
                                      dimmed:
                                          scoringCardIds.isNotEmpty &&
                                          card.selected &&
                                          !scoringCardIds.contains(card.uid),
                                      rankSuppressed: rankSuppressed,
                                      rankSuppressionLabel: state
                                          .cardRankSuppressionLabel(card),
                                      enhancementSuppressed:
                                          enhancementSuppressed,
                                      selectionDisabled: selectionDisabled,
                                      scoreChip:
                                          retainedChip?.label ??
                                          (fallbackChip ? chipLabel : null),
                                      scoreChipColor: mutedChip
                                          ? tokens.creamDim
                                          : _chipColorForStyle(
                                              context,
                                              visibleStyle,
                                            ),
                                      highlightColor: _chipColorForStyle(
                                        context,
                                        chipStyle,
                                      ),
                                      scoreChipSequence:
                                          retainedChip?.sequence ??
                                          presentationSequence,
                                      liftWhenSelected: !busy,
                                      onTap:
                                          busy ||
                                              selectionDisabled ||
                                              onToggleCard == null
                                          ? null
                                          : () => onToggleCard!(index),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(
                          outerPadding,
                          9,
                          outerPadding,
                          2,
                        ),
                        child: handWidth > available
                            ? SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const ClampingScrollPhysics(),
                                child: stack,
                              )
                            : Center(child: stack),
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

/// Responsive measurements for the compact, static phone table.
///
class _RunMetrics {
  const _RunMetrics({
    required this.pagePadding,
    required this.outerGap,
    required this.slyHeight,
    required this.jokerHeight,
    required this.playfieldDrop,
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
          ? 60
          : compact
          ? 72
          : 86,
      // Spend the otherwise-empty lower part of tall phone screens between the
      // Joker engine and the playfield. The capped formula scales smoothly
      // across phones, while short devices keep a compact, scroll-safe layout.
      playfieldDrop: veryShort
          ? 0
          : ((size.height - 720) * 0.4)
                .clamp(compact ? 6.0 : 10.0, 58.0)
                .toDouble(),
      // Full-size overlapping cards keep ranks readable without making the
      // felt consume the lower half of the phone.
      cardWidth: compact ? 46 : 50,
      cardHeight: compact ? 86 : 92,
      compact: compact,
    );
  }

  final double pagePadding;
  final double outerGap;
  final double slyHeight;
  final double jokerHeight;
  final double playfieldDrop;
  final double cardWidth;
  final double cardHeight;
  final bool compact;
}

Color _chipColorForStyle(BuildContext context, ScoreChipStyle style) =>
    switch (style) {
      ScoreChipStyle.card || ScoreChipStyle.jackpot => context.wildcard.gold,
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
