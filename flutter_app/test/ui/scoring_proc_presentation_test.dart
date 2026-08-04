import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/scoring_engine.dart';
import 'package:wildcard/game/game_models.dart';
import 'package:wildcard/ui/screens/run_table_screen.dart';
import 'package:wildcard/ui/wildcard_theme.dart';

void main() {
  const hand = <PlayingCard>[
    PlayingCard(
      uid: 'ace-spades',
      rank: CardRank.ace,
      suit: CardSuit.spades,
      selected: true,
    ),
  ];

  Future<void> pumpTable(
    WidgetTester tester,
    ValueNotifier<ScoringPresentation> timeline,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: RunTableScreen(
          state: ScoringState(
            rngSeed: 1,
            jokerIds: const <String>['uniform', 'allin'],
          ),
          hand: hand,
          slySpeech: 'Read the table.',
          scoringTimeline: timeline,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'additive and xMult Joker beats show exact distinct proc labels then clear',
    (tester) async {
      final timeline = ValueNotifier<ScoringPresentation>(
        const ScoringPresentation(
          handSnapshot: hand,
          activeEvent: ScoreEvent(
            type: ScoreEventType.mult,
            jokerIndex: 0,
            label: '+0.50 Mult',
            multiplier: 1.6,
          ),
          activeJokerIndex: 0,
          label: '+0.50 Mult',
          visibleValuePoints: 20,
          visibleMultiplier: 1.6,
          visibleTotal: 32,
          sequence: 11,
          phase: ScorePresentationPhase.beat,
        ),
      );
      addTearDown(timeline.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpTable(tester, timeline);

      expect(
        find.byKey(const ValueKey('joker-proc-additive-11')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('equation-proc-additive-11')),
        findsOneWidget,
      );
      expect(find.text('Suit Uniform · +0.50 Mult'), findsOneWidget);
      expect(find.text('+0.50 Mult'), findsWidgets);
      final additiveCell = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('equation-multiplier-cell')),
      );
      final activeCellSize = tester.getSize(
        find.byKey(const ValueKey('equation-multiplier-cell')),
      );
      final additiveBorder =
          (additiveCell.decoration! as BoxDecoration).border!.top.color;

      timeline.value = const ScoringPresentation(
        handSnapshot: hand,
        activeEvent: ScoreEvent(
          type: ScoreEventType.xMult,
          jokerIndex: 1,
          label: '×4',
          multiplier: 6.4,
        ),
        activeJokerIndex: 1,
        label: '×4',
        visibleValuePoints: 20,
        visibleMultiplier: 6.4,
        visibleTotal: 128,
        sequence: 12,
        phase: ScorePresentationPhase.beat,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));

      expect(
        find.byKey(const ValueKey('joker-proc-multiplicative-12')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('equation-proc-multiplicative-12')),
        findsOneWidget,
      );
      expect(find.text('All In · ×4'), findsOneWidget);
      expect(find.text('×4'), findsWidgets);
      final multiplicativeCell = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('equation-multiplier-cell')),
      );
      final multiplicativeBorder =
          (multiplicativeCell.decoration! as BoxDecoration).border!.top.color;
      expect(multiplicativeBorder, isNot(additiveBorder));

      timeline.value = const ScoringPresentation(
        handSnapshot: hand,
        visibleValuePoints: 20,
        visibleMultiplier: 6.4,
        visibleTotal: 128,
        sequence: 13,
        phase: ScorePresentationPhase.finale,
        finalScoreVisible: true,
        complete: true,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));

      expect(
        find.byKey(const ValueKey('joker-proc-multiplicative-12')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('equation-proc-multiplicative-12')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('equation-label-MULTIPLIER')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('equation-multiplier-cell')))
            .height,
        activeCellSize.height,
        reason: 'A Joker proc must not make the table below it jump.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy direct events use the same additive and xMult treatment',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 568));
      final state = ScoringState(
        rngSeed: 2,
        jokerIds: const <String>['uniform', 'allin'],
      );

      Future<void> pumpDirect(ScoreEvent? event, double multiplier) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: WildcardTheme.build(),
            home: RunTableScreen(
              state: state,
              hand: hand,
              slySpeech: 'Read the table.',
              activeScoreEvent: event,
              liveRank: 20,
              liveMultiplier: multiplier,
              liveTotal: (20 * multiplier).round(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
      }

      await pumpDirect(
        const ScoreEvent(
          type: ScoreEventType.mult,
          jokerIndex: 0,
          label: '+0.50 Mult',
          multiplier: 1.6,
        ),
        1.6,
      );
      expect(
        find.byKey(const ValueKey('joker-proc-additive-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('equation-proc-additive-1')),
        findsOneWidget,
      );

      await pumpDirect(
        const ScoreEvent(
          type: ScoreEventType.xMult,
          jokerIndex: 1,
          label: '×4',
          multiplier: 6.4,
        ),
        6.4,
      );
      expect(
        find.byKey(const ValueKey('joker-proc-multiplicative-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('equation-proc-multiplicative-1')),
        findsOneWidget,
      );

      await pumpDirect(null, 6.4);
      expect(
        find.byKey(const ValueKey('joker-proc-multiplicative-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('equation-proc-multiplicative-1')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a restarted equation roll continues from its displayed value', (
    tester,
  ) async {
    final timeline = ValueNotifier<ScoringPresentation>(
      const ScoringPresentation(
        handSnapshot: hand,
        visibleMultiplier: 1.1,
        phase: ScorePresentationPhase.beat,
      ),
    );
    addTearDown(timeline.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpTable(tester, timeline);

    timeline.value = const ScoringPresentation(
      handSnapshot: hand,
      visibleMultiplier: 3.1,
      sequence: 1,
      phase: ScorePresentationPhase.beat,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final multiplierFinder = find.byKey(
      const ValueKey('equation-multiplier-value'),
    );
    final beforeRestart = double.parse(
      tester.widget<Text>(multiplierFinder).data!,
    );
    expect(beforeRestart, greaterThan(1.1));
    expect(beforeRestart, lessThan(3.1));

    timeline.value = const ScoringPresentation(
      handSnapshot: hand,
      visibleMultiplier: 4.1,
      sequence: 2,
      phase: ScorePresentationPhase.beat,
    );
    await tester.pump();

    final afterRestart = double.parse(
      tester.widget<Text>(multiplierFinder).data!,
    );
    expect(
      afterRestart,
      closeTo(beforeRestart, 0.05),
      reason: 'A new beat must continue from the number currently on screen.',
    );

    await tester.pump(const Duration(milliseconds: 520));
    expect(
      double.parse(tester.widget<Text>(multiplierFinder).data!),
      closeTo(4.1, 0.01),
    );
    expect(tester.takeException(), isNull);
  });
}
