import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/app/screens/arcade_mode_picker_screen.dart';
import 'package:wildcard/app/screens/arcade_run_screen.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/domain/arcade_rules.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/game/arcade_controller.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  for (final size in const <Size>[Size(320, 568), Size(393, 873)]) {
    testWidgets('Arcade table fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });
      final controller = ArcadeController.start(
        ArcadeRunConfig(
          length: ArcadeRunLength.sprint8,
          rngSeed: 12,
          discoveredJokerIds: const <String>{},
          initialDeck: <PlayingCard>[
            const PlayingCard(rank: CardRank.ace, suit: CardSuit.spades),
            const PlayingCard(rank: CardRank.king, suit: CardSuit.spades),
            const PlayingCard(rank: CardRank.queen, suit: CardSuit.spades),
            const PlayingCard(rank: CardRank.jack, suit: CardSuit.hearts),
            const PlayingCard(rank: CardRank.ten, suit: CardSuit.diamonds),
          ],
        ),
        wait: (_) async {},
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: WildcardTheme.build(themeId: WildcardThemeId.vaporwave),
          home: ArcadeRunScreen(controller: controller),
        ),
      );
      await tester.pump();

      expect(find.text('ARCADE · ROUND 1'), findsOneWidget);
      expect(find.byType(PlayingCardTile), findsNWidgets(5));
      expect(find.byKey(const Key('arcade-score-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Arcade picker exposes three launch modes and locked challenge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 873);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(themeId: WildcardThemeId.bloodMoon),
        home: ArcadeModePickerScreen(
          account: AccountState(
            tutorialDone: true,
            bestClearedHeat: ArcadeRules.challengeUnlockHeat - 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('8-ROUND SPRINT'), findsOneWidget);
    expect(find.text('15-ROUND ARCADE'), findsOneWidget);
    expect(find.text('ENDLESS ARCADE'), findsOneWidget);
    expect(find.text('30-ROUND CHALLENGE'), findsOneWidget);
    expect(find.textContaining('Locked — clear Heat 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
