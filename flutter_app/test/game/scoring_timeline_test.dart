import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/scoring_engine.dart';
import 'package:wildcard/game/game_models.dart';
import 'package:wildcard/game/scoring_timeline.dart';

void main() {
  const hand = <PlayingCard>[
    PlayingCard(
      uid: 'ace-spades',
      rank: CardRank.ace,
      suit: CardSuit.spades,
      selected: true,
    ),
    PlayingCard(
      uid: 'king-hearts',
      rank: CardRank.king,
      suit: CardSuit.hearts,
      selected: true,
    ),
    PlayingCard(
      uid: 'kicker-clubs',
      rank: CardRank.two,
      suit: CardSuit.clubs,
      selected: true,
    ),
  ];

  test('Normal adds a fixed readable result hold while Fast is unchanged', () {
    expect(ScoringPacing.normal.leadIn, const Duration(milliseconds: 333));
    expect(ScoringPacing.normal.cardBeat, const Duration(milliseconds: 407));
    expect(ScoringPacing.normal.jokerBeat, const Duration(milliseconds: 666));
    expect(ScoringPacing.normal.resultHold, const Duration(milliseconds: 1400));
    expect(
      ScoringPacing.normal.transitionHold,
      const Duration(milliseconds: 600),
    );

    expect(ScoringPacing.fast.leadIn, const Duration(milliseconds: 187));
    expect(ScoringPacing.fast.cardBeat, const Duration(milliseconds: 229));
    expect(ScoringPacing.fast.jokerBeat, const Duration(milliseconds: 270));
    expect(ScoringPacing.fast.resultHold, const Duration(milliseconds: 620));
    expect(
      ScoringPacing.fast.transitionHold,
      const Duration(milliseconds: 320),
    );
  });

  test('timeline exposes truthful WebView equation and exact finale', () {
    const result = ScoreResult(
      handType: HandType.pair,
      base: 20,
      rankSum: 15,
      rankScore: 9,
      valuePoints: 29,
      multiplier: 3,
      total: 87,
      perCard: <int>[10, 0, 0],
      scoringFlags: <bool>[true, true, false],
      events: <ScoreEvent>[
        ScoreEvent(
          type: ScoreEventType.card,
          cardIndex: 0,
          amount: 10,
          label: '+10',
        ),
        ScoreEvent(
          type: ScoreEventType.rankJoker,
          cardIndex: 1,
          jokerIndex: 0,
          amount: 5,
          label: 'PAIR TRAINER +5',
        ),
        ScoreEvent(
          type: ScoreEventType.mult,
          jokerIndex: 1,
          multiplier: 1.5,
          label: '+0.40 MULT',
        ),
        ScoreEvent(
          type: ScoreEventType.xMult,
          jokerIndex: 2,
          multiplier: 3,
          label: '×2 MULT',
        ),
      ],
    );

    final plan = const ScoringTimelineBuilder().build(
      handSnapshot: hand,
      playedCards: hand,
      result: result,
      pacing: ScoringPacing.normal,
    );

    expect(plan.initial.visibleValuePoints, 20);
    expect(plan.initial.visibleMultiplier, baseMultiplier);
    expect(plan.initial.visibleTotal, 22);
    expect(plan.initial.handSnapshot.map((card) => card.uid), <String>[
      'ace-spades',
      'king-hearts',
      'kicker-clubs',
    ]);
    expect(plan.initial.scoringCardIds, <String>{'ace-spades', 'king-hearts'});

    expect(plan.beats[0].frame.visibleRawRank, 10);
    expect(plan.beats[0].frame.visibleValuePoints, 26);
    expect(plan.beats[0].frame.visibleTotal, 29);
    expect(plan.beats[0].frame.chipStyle, ScoreChipStyle.card);
    expect(plan.beats[0].frame.activeChips.map((chip) => chip.cardId), <String>[
      'ace-spades',
    ]);

    expect(plan.beats[1].frame.visibleRawRank, 15);
    expect(plan.beats[1].frame.visibleValuePoints, 29);
    expect(plan.beats[1].frame.visibleTotal, 32);
    expect(plan.beats[1].frame.chipStyle, ScoreChipStyle.joker);
    expect(
      plan.beats[1].frame.activeChips.map((chip) => chip.cardId),
      <String>['ace-spades', 'king-hearts'],
      reason:
          'The first gold number must keep rising while the next purple Joker number appears.',
    );

    expect(plan.beats[2].frame.visibleMultiplier, 1.5);
    expect(plan.beats[2].frame.visibleTotal, 44);
    expect(
      plan.beats[2].frame.activeChips.map((chip) => chip.cardId),
      <String>['king-hearts'],
      reason: 'Expired card chips leave the retained presentation set.',
    );
    expect(plan.beats[3].frame.visibleMultiplier, 3);
    expect(plan.beats[3].frame.visibleTotal, 87);

    expect(plan.finale.visibleValuePoints, result.valuePoints);
    expect(plan.finale.visibleMultiplier, result.multiplier);
    expect(plan.finale.visibleTotal, result.total);
    expect(plan.finale.finalScoreVisible, isTrue);
    expect(plan.finale.complete, isTrue);
  });

  test('normal timing overlaps effects while preserving readable onsets', () {
    const result = ScoreResult(
      handType: HandType.highCard,
      base: 5,
      rankSum: 15,
      rankScore: 9,
      valuePoints: 14,
      multiplier: 1.1,
      total: 15,
      perCard: <int>[15],
      scoringFlags: <bool>[true],
      events: <ScoreEvent>[
        ScoreEvent(
          type: ScoreEventType.card,
          cardIndex: 0,
          amount: 15,
          label: '+15',
        ),
        ScoreEvent(
          type: ScoreEventType.rankJoker,
          cardIndex: 0,
          jokerIndex: 0,
          amount: 0,
          label: 'BLOCKED',
        ),
      ],
    );
    final plan = const ScoringTimelineBuilder().build(
      handSnapshot: hand,
      playedCards: hand,
      result: result,
      pacing: ScoringPacing.normal,
    );

    expect(plan.beats[0].start, ScoringPacing.normal.leadIn);
    expect(
      plan.beats[1].start - plan.beats[0].start,
      ScoringPacing.normal.cardBeat,
    );
    expect(
      plan.beats[0].duration,
      greaterThan(ScoringPacing.normal.cardBeat),
      reason: 'The card effect may overlap the next onset without serial lag.',
    );
  });

  test('only a zero-rank beat is muted on a modifier-suppressed card', () {
    const result = ScoreResult(
      handType: HandType.highCard,
      base: 5,
      rankSum: 0,
      rankScore: 0,
      valuePoints: 5,
      multiplier: 1.3,
      total: 7,
      perCard: <int>[0],
      scoringFlags: <bool>[false],
      events: <ScoreEvent>[
        ScoreEvent(
          type: ScoreEventType.card,
          cardIndex: 0,
          amount: 0,
          label: '+0',
        ),
        ScoreEvent(
          type: ScoreEventType.mult,
          cardIndex: 0,
          amount: .2,
          multiplier: 1.3,
          label: 'NEON +0.20',
        ),
      ],
    );
    final plan = const ScoringTimelineBuilder().build(
      handSnapshot: hand,
      playedCards: hand,
      result: result,
      pacing: ScoringPacing.normal,
    );

    expect(plan.beats.first.frame.activeChips.single.muted, isTrue);
    expect(plan.beats.last.frame.activeChips.last.muted, isFalse);
  });

  test('Lucky Seven has a suspense beat before a truthful outcome', () {
    const result = ScoreResult(
      handType: HandType.highCard,
      base: 5,
      rankSum: 77,
      rankScore: 46,
      valuePoints: 51,
      multiplier: 1.1,
      total: 56,
      perCard: <int>[0],
      scoringFlags: <bool>[true],
      events: <ScoreEvent>[
        ScoreEvent(
          type: ScoreEventType.seven,
          cardIndex: 0,
          jokerIndex: 0,
          amount: 77,
          hit: true,
        ),
      ],
    );
    final plan = const ScoringTimelineBuilder().build(
      handSnapshot: hand,
      playedCards: hand,
      result: result,
      pacing: ScoringPacing.fast,
    );

    expect(plan.beats, hasLength(2));
    expect(plan.beats.first.frame.label, contains('ROLLING'));
    expect(plan.beats.first.frame.chipStyle, ScoreChipStyle.suspense);
    expect(plan.beats.last.frame.label, contains('JACKPOT'));
    expect(plan.beats.last.frame.chipStyle, ScoreChipStyle.jackpot);
    expect(plan.finale.visibleTotal, 56);
  });

  test('presentation callbacks cannot strand timeline completion', () async {
    const result = ScoreResult(
      handType: HandType.highCard,
      base: 5,
      rankSum: 10,
      rankScore: 6,
      valuePoints: 11,
      multiplier: 1.1,
      total: 12,
      perCard: <int>[10],
      scoringFlags: <bool>[true],
      events: <ScoreEvent>[
        ScoreEvent(type: ScoreEventType.card, cardIndex: 0, amount: 10),
      ],
    );
    final plan = const ScoringTimelineBuilder().build(
      handSnapshot: hand,
      playedCards: hand,
      result: result,
      pacing: ScoringPacing.fast,
    );
    final timeline = ScoringTimelineController();
    var waits = 0;
    await timeline.play(
      plan: plan,
      wait: (_) async => waits++,
      onBeat: (_, _) => throw StateError('optional presentation failed'),
    );

    expect(waits, greaterThanOrEqualTo(2));
    expect(timeline.value.complete, isTrue);
    expect(timeline.value.visibleTotal, result.total);
    timeline.dispose();
  });
}
