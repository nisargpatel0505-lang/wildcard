import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/cards.dart';
import '../domain/game_rules.dart';
import '../domain/scoring_engine.dart';
import 'game_models.dart';

@immutable
class ScorePresentationBeat {
  const ScorePresentationBeat({
    required this.start,
    required this.duration,
    required this.frame,
  });

  final Duration start;
  final Duration duration;
  final ScoringPresentation frame;

  ScoreEvent get event => frame.activeEvent!;
}

@immutable
class ScoringTimelinePlan {
  const ScoringTimelinePlan({
    required this.initial,
    required this.beats,
    required this.finaleStart,
    required this.finale,
  });

  final ScoringPresentation initial;
  final List<ScorePresentationBeat> beats;
  final Duration finaleStart;
  final ScoringPresentation finale;
}

/// Converts one already-authoritative [ScoreResult] into visual-only frames.
///
/// This class never rolls RNG, changes the score or touches durable state. It
/// mirrors the WebView's presentation mathematics so every intermediate value
/// is truthful:
///
/// `base + round(raw rank × rankScale)`, then `round(value × multiplier)`.
class ScoringTimelineBuilder {
  const ScoringTimelineBuilder();

  ScoringTimelinePlan build({
    required List<PlayingCard> handSnapshot,
    required List<PlayingCard> playedCards,
    required ScoreResult result,
    required ScoringPacing pacing,
  }) {
    final snapshot = List<PlayingCard>.unmodifiable(handSnapshot);
    final cardIds = <String>[
      for (var index = 0; index < playedCards.length; index++)
        playedCards[index].uid ?? 'played-$index',
    ];
    final scoringCardIds = <String>{
      for (var index = 0; index < result.scoringFlags.length; index++)
        if (result.scoringFlags[index] && index < cardIds.length)
          cardIds[index],
    };
    final settled = <String>{};
    var rawRank = 0;
    var valuePoints = result.base;
    var multiplier = baseMultiplier;
    var total = (valuePoints * multiplier).round();
    var sequence = 0;
    var cursor = pacing.leadIn;
    final beats = <ScorePresentationBeat>[];
    final fast = pacing == ScoringPacing.fast;

    ScoringPresentation frameFor(
      ScoreEvent event, {
      required String label,
      required ScoreChipStyle style,
      required Duration duration,
    }) {
      final cardIndex = event.cardIndex;
      final cardId =
          cardIndex != null && cardIndex >= 0 && cardIndex < cardIds.length
          ? cardIds[cardIndex]
          : null;
      final jokerIndex = event.jokerIndex != null && event.jokerIndex! >= 0
          ? event.jokerIndex
          : null;
      return ScoringPresentation(
        result: result,
        handSnapshot: snapshot,
        activeEvent: event,
        activeCardId: cardId,
        activeJokerIndex: jokerIndex,
        label: label,
        visibleRawRank: rawRank,
        visibleValuePoints: valuePoints,
        visibleMultiplier: multiplier,
        visibleTotal: total,
        scoringCardIds: scoringCardIds,
        settledCardIds: Set<String>.unmodifiable(settled),
        sequence: ++sequence,
        chipStyle: style,
        phase: ScorePresentationPhase.beat,
      );
    }

    void addBeat(
      ScoreEvent event, {
      required String label,
      required ScoreChipStyle style,
      required Duration duration,
      required Duration onsetGap,
    }) {
      final frame = frameFor(
        event,
        label: label,
        style: style,
        duration: duration,
      );
      beats.add(
        ScorePresentationBeat(start: cursor, duration: duration, frame: frame),
      );
      if (frame.activeCardId case final id?) settled.add(id);
      cursor += onsetGap;
    }

    for (final event in result.events) {
      if (event.type == ScoreEventType.seven) {
        addBeat(
          event,
          label: 'ROLLING…',
          style: ScoreChipStyle.suspense,
          duration: Duration(milliseconds: fast ? 430 : 720),
          onsetGap: Duration(milliseconds: fast ? 430 : 850),
        );
        rawRank += event.amount.round();
        valuePoints = result.base + (rawRank * rankScale).round();
        total = (valuePoints * multiplier).round();
        addBeat(
          event,
          label: event.hit == true
              ? 'JACKPOT +${event.amount.round()}!'
              : 'MISS',
          style: event.hit == true
              ? ScoreChipStyle.jackpot
              : ScoreChipStyle.miss,
          duration: Duration(milliseconds: fast ? 470 : 760),
          onsetGap: Duration(milliseconds: fast ? 330 : 592),
        );
        continue;
      }

      if (_isRankSide(event.type)) {
        rawRank += event.amount.round();
        valuePoints = result.base + (rawRank * rankScale).round();
      }
      if (event.multiplier case final next?) multiplier = next;
      total = (valuePoints * multiplier).round();

      final joker = event.jokerIndex != null && event.jokerIndex! >= 0;
      final style = switch (event.type) {
        ScoreEventType.card => ScoreChipStyle.card,
        ScoreEventType.rankJoker ||
        ScoreEventType.retrigger => ScoreChipStyle.joker,
        ScoreEventType.mult ||
        ScoreEventType.xMult when joker => ScoreChipStyle.multiplier,
        ScoreEventType.mult || ScoreEventType.xMult => ScoreChipStyle.modifier,
        ScoreEventType.seven => ScoreChipStyle.suspense,
      };
      final gap = joker ? pacing.jokerBeat : pacing.cardBeat;
      addBeat(
        event,
        label: _labelFor(event),
        style: style,
        duration: Duration(milliseconds: fast ? 470 : 720),
        onsetGap: gap,
      );
    }

    // The timeline must land on the engine's exact result even if a future
    // presentation event is informational and carries no arithmetic amount.
    final finale = ScoringPresentation(
      result: result,
      handSnapshot: snapshot,
      visibleRawRank: result.rankSum,
      visibleValuePoints: result.valuePoints,
      visibleMultiplier: result.multiplier,
      visibleTotal: result.total,
      scoringCardIds: scoringCardIds,
      settledCardIds: Set<String>.unmodifiable(settled),
      sequence: ++sequence,
      phase: ScorePresentationPhase.finale,
      finalScoreVisible: true,
      complete: true,
    );

    return ScoringTimelinePlan(
      initial: ScoringPresentation(
        result: result,
        handSnapshot: snapshot,
        visibleValuePoints: result.base,
        visibleMultiplier: baseMultiplier,
        visibleTotal: (result.base * baseMultiplier).round(),
        scoringCardIds: scoringCardIds,
        phase: ScorePresentationPhase.leadIn,
      ),
      beats: List<ScorePresentationBeat>.unmodifiable(beats),
      finaleStart: cursor,
      finale: finale,
    );
  }

  static bool _isRankSide(ScoreEventType type) =>
      type == ScoreEventType.card ||
      type == ScoreEventType.rankJoker ||
      type == ScoreEventType.retrigger;

  static String _labelFor(ScoreEvent event) {
    final label = event.label?.trim();
    if (label != null && label.isNotEmpty) {
      return switch (event.type) {
        ScoreEventType.rankJoker => label.toUpperCase(),
        ScoreEventType.mult when !label.toUpperCase().contains('NEON') =>
          label.toUpperCase(),
        _ => label,
      };
    }
    return event.hit == true
        ? 'JACKPOT +${event.amount.round()}!'
        : event.hit == false
        ? 'MISS'
        : event.amount == 0
        ? '0'
        : '+${event.amount}';
  }
}

typedef ScoreBeatCallback =
    void Function(ScorePresentationBeat beat, int ordinal);

/// Narrow presentation notifier used by the table's animated regions.
///
/// [GameController] still owns the committed state, but it no longer broadcasts
/// a whole-game notification for every scoring beat.
class ScoringTimelineController extends ValueNotifier<ScoringPresentation> {
  ScoringTimelineController() : super(const ScoringPresentation());

  int _generation = 0;

  Future<void> play({
    required ScoringTimelinePlan plan,
    required ScoringWait wait,
    ScoreBeatCallback? onBeat,
  }) async {
    final generation = ++_generation;
    value = plan.initial;
    var elapsed = Duration.zero;
    for (var ordinal = 0; ordinal < plan.beats.length; ordinal++) {
      final beat = plan.beats[ordinal];
      final delay = beat.start - elapsed;
      if (delay > Duration.zero) await wait(delay);
      if (generation != _generation) return;
      value = beat.frame;
      try {
        onBeat?.call(beat, ordinal);
      } catch (_) {
        // Sound, haptics and reactions are decorative and cannot stop scoring.
      }
      elapsed = beat.start;
    }
    final finaleDelay = plan.finaleStart - elapsed;
    if (finaleDelay > Duration.zero) await wait(finaleDelay);
    if (generation == _generation) value = plan.finale;
  }

  void clear() {
    _generation++;
    value = const ScoringPresentation();
  }
}
