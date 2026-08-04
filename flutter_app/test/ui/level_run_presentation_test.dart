import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/sly_quips.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  testWidgets(
    'objective-only Level shows its real number and no fake score target',
    (tester) async {
      await _setPhoneSize(tester);
      final reactions = ValueNotifier<SlyReaction?>(null);
      addTearDown(reactions.dispose);

      await tester.pumpWidget(
        _Harness(
          child: RunTableScreen(
            state: ScoringState(
              rngSeed: 1,
              stage: 1,
              targetOverride: 0,
              handsLeft: 4,
              discardsLeft: 5,
              deckCardsLeft: 43,
            ),
            hand: baseCardSet().take(9).toList(),
            slySpeech: 'Find the Pair before the table closes.',
            slyReaction: reactions,
            stageLabel: 'LEVEL',
            stageValue: 37,
            scoreLabel: 'Level score',
            showScoreTarget: false,
            objectiveText: 'PAIR 0/1',
            levelRules: const <String>[
              'High Card scores 0',
              'THIS HAND · SPADES rank is disabled',
            ],
            compactJokerSlots: true,
            showRunCoins: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('LEVEL'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('hud-level')),
          matching: find.text('37'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Heat score:'), findsNothing);
      expect(find.textContaining('Level score:'), findsNothing);
      expect(find.textContaining('Target:'), findsNothing);
      expect(find.byKey(const Key('level-objective-panel')), findsOneWidget);
      expect(find.text('PAIR 0/1'), findsOneWidget);
      expect(find.byKey(const Key('level-rule-panel')), findsOneWidget);
      expect(find.text('High Card scores 0'), findsOneWidget);
      expect(find.text('THIS HAND · SPADES rank is disabled'), findsOneWidget);
      expect(find.byKey(const ValueKey('level-no-jokers')), findsOneWidget);
      expect(
        find.text('NO JOKERS · THIS TABLE TESTS THE CARDS ALONE'),
        findsOneWidget,
      );
      expect(
        find.text('Find the Pair before the table closes.'),
        findsOneWidget,
      );

      reactions.value = const SlyReaction(
        mood: SlyMood.pair,
        priority: 2,
        expression: SlyExpression.thoughtful,
        speech: 'A Pair. You remembered the assignment.',
        label: 'PAIR',
        motion: SlyMotionProfile.pop,
        hold: Duration(seconds: 1),
        sequence: 1,
        generation: 1,
      );
      await tester.pump();

      expect(
        find.text('A Pair. You remembered the assignment.'),
        findsOneWidget,
      );
      expect(find.text('PAIR 0/1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('score Level uses campaign wording and its authored target', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      _Harness(
        child: RunTableScreen(
          state: ScoringState(
            rngSeed: 10,
            stage: 1,
            stageScore: 215,
            targetOverride: 515,
            handsLeft: 3,
            discardsLeft: 4,
            deckCardsLeft: 43,
          ),
          hand: baseCardSet().take(9).toList(),
          slySpeech: 'Two hand types. One target.',
          stageLabel: 'LEVEL',
          stageValue: 10,
          scoreLabel: 'Level score',
          showScoreTarget: true,
          objectiveText: 'VARIETY 1/2',
          showRunCoins: false,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('hud-level')),
        matching: find.text('10'),
      ),
      findsOneWidget,
    );
    expect(find.text('Level score: 215'), findsOneWidget);
    expect(
      find.textContaining('Target: 515', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Heat score:'), findsNothing);
    expect(find.text('VARIETY 1/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arcade defaults retain the existing Heat score HUD', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      _Harness(
        child: RunTableScreen(
          state: ScoringState(
            rngSeed: 4,
            stage: 4,
            stageScore: 90,
            handsLeft: 2,
            discardsLeft: 3,
            deckCardsLeft: 43,
          ),
          hand: baseCardSet().take(9).toList(),
          slySpeech: 'The target is waiting.',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('HEAT'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('hud-heat')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    expect(find.text('Heat score: 90'), findsOneWidget);
    expect(find.textContaining('Target:'), findsOneWidget);
    expect(find.byKey(const Key('level-objective-panel')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Harness extends StatelessWidget {
  const _Harness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: WildcardTheme.build(),
    home: MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child,
    ),
  );
}

Future<void> _setPhoneSize(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}
