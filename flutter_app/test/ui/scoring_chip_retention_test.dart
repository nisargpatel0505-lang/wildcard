import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/scoring_engine.dart';
import 'package:wildcard/game/game_models.dart';
import 'package:wildcard/ui/screens/run_table_screen.dart';
import 'package:wildcard/ui/wildcard_theme.dart';

void main() {
  testWidgets('overlapping score beats keep both card labels visible', (
    tester,
  ) async {
    const hand = <PlayingCard>[
      PlayingCard(
        uid: 'ace',
        rank: CardRank.ace,
        suit: CardSuit.spades,
        selected: true,
      ),
      PlayingCard(
        uid: 'king',
        rank: CardRank.king,
        suit: CardSuit.hearts,
        selected: true,
      ),
    ];
    final timeline = ValueNotifier<ScoringPresentation>(
      const ScoringPresentation(
        handSnapshot: hand,
        activeEvent: ScoreEvent(
          type: ScoreEventType.rankJoker,
          cardIndex: 1,
          amount: 5,
          label: 'PAIR TRAINER +5',
        ),
        activeCardId: 'king',
        label: 'PAIR TRAINER +5',
        activeChips: <ScoreVisualChip>[
          ScoreVisualChip(
            sequence: 1,
            cardId: 'ace',
            label: '+15',
            style: ScoreChipStyle.card,
            start: Duration(milliseconds: 333),
            duration: Duration(milliseconds: 720),
          ),
          ScoreVisualChip(
            sequence: 2,
            cardId: 'king',
            label: 'PAIR TRAINER +5',
            style: ScoreChipStyle.joker,
            start: Duration(milliseconds: 740),
            duration: Duration(milliseconds: 720),
          ),
        ],
        sequence: 2,
        phase: ScorePresentationPhase.beat,
      ),
    );
    addTearDown(timeline.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: RunTableScreen(
          state: ScoringState(rngSeed: 1),
          hand: hand,
          slySpeech: 'Count the cards.',
          scoringTimeline: timeline,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('+15'), findsOneWidget);
    expect(find.text('PAIR TRAINER +5'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
