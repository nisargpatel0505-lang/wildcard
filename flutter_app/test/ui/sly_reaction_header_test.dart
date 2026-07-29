import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/domain/sly_quips.dart';
import 'package:wildcard/ui/screens/run_table_screen.dart';
import 'package:wildcard/ui/widgets/sly_sprite.dart';
import 'package:wildcard/ui/wildcard_theme.dart';

void main() {
  testWidgets(
    'premium Sly keeps equipped skin while its mood reaction changes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final reactions = ValueNotifier<SlyReaction?>(
        const SlyReaction(
          mood: SlyMood.pair,
          priority: 2,
          expression: SlyExpression.thoughtful,
          speech: 'A Pair keeps you breathing.',
          label: 'PAIR',
          motion: SlyMotionProfile.pop,
          hold: Duration(seconds: 1),
          sequence: 1,
          generation: 1,
        ),
      );
      addTearDown(reactions.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: WildcardTheme.build(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: RunTableScreen(
            state: ScoringState(rngSeed: 9),
            hand: baseCardSet().take(9).toList(),
            slySpeech: 'Deal.',
            slySkin: SlySkin.devil,
            slyReaction: reactions,
          ),
        ),
      );
      await tester.pump();

      const faceKey = Key('sly-face');
      final faceState = tester.state(find.byKey(faceKey));
      expect(find.byKey(const Key('sly-header-panel')), findsOneWidget);
      expect(find.text('PAIR'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('sly-skin-frame-devil')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('sly-premium-reaction-thoughtful')),
        findsOneWidget,
      );
      _expectOnlySlyAsset(tester, slySkinSpriteAsset);

      reactions.value = const SlyReaction(
        mood: SlyMood.fullHouse,
        priority: 4,
        expression: SlyExpression.shocked,
        speech: 'Full House. The table is getting crowded.',
        label: 'FULL HOUSE',
        motion: SlyMotionProfile.rock,
        hold: Duration(seconds: 5),
        sequence: 2,
        generation: 1,
      );
      await tester.pump();

      expect(identical(faceState, tester.state(find.byKey(faceKey))), isTrue);
      expect(find.text('FULL HOUSE'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('sly-skin-frame-devil')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('sly-premium-reaction-shocked')),
        findsOneWidget,
      );
      _expectOnlySlyAsset(tester, slySkinSpriteAsset);

      reactions.value = const SlyReaction(
        mood: SlyMood.heatFail,
        priority: 5,
        expression: SlyExpression.laughing,
        speech: 'No plays left. The target held.',
        label: 'TARGET HELD',
        motion: SlyMotionProfile.rock,
        hold: Duration(seconds: 4),
        sequence: 3,
        generation: 1,
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('sly-premium-reaction-laughing')),
        findsOneWidget,
      );
      _expectOnlySlyAsset(tester, slySkinSpriteAsset);

      reactions.value = const SlyReaction(
        mood: SlyMood.clear,
        priority: 5,
        expression: SlyExpression.triumphant,
        speech: 'Heat cleared. The next target is worse.',
        label: 'HEAT CLEAR',
        motion: SlyMotionProfile.pop,
        hold: Duration(seconds: 4),
        sequence: 4,
        generation: 1,
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('sly-premium-reaction-triumphant')),
        findsOneWidget,
      );
      _expectOnlySlyAsset(tester, slySkinSpriteAsset);

      reactions.value = null;
      await tester.pump();
      expect(
        find.byKey(const ValueKey('sly-skin-frame-devil')),
        findsOneWidget,
      );
      _expectOnlySlyAsset(tester, slySkinSpriteAsset);
      expect(
        find.byKey(const ValueKey('sly-premium-reaction-triumphant')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('classic Sly still uses authored facial-expression frames', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SlySprite(
            expression: SlyExpression.shocked,
            skin: SlySkin.classic,
            reactionActive: true,
            animate: false,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('sly-expression-frame-shocked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('sly-premium-reaction-shocked')),
      findsNothing,
    );
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image is ResizeImage
        ? (image.image as ResizeImage).imageProvider
        : image.image;
    expect(provider, isA<AssetImage>());
    expect((provider as AssetImage).assetName, slyExpressionSpriteAsset);
  });

  for (final themedSkin in <(SlySkin, String, String)>[
    (SlySkin.blockDrop, 'blockDrop', slyBlockDropExpressionSpriteAsset),
    (SlySkin.abyssal, 'abyssal', slyAbyssalExpressionSpriteAsset),
    (SlySkin.desertMirage, 'desertMirage', slyDesertExpressionSpriteAsset),
    (SlySkin.hearts, 'hearts', slyHeartsExpressionSpriteAsset),
    (SlySkin.spades, 'spades', slySpadesExpressionSpriteAsset),
    (SlySkin.diamonds, 'diamonds', slyDiamondsExpressionSpriteAsset),
    (SlySkin.clubs, 'clubs', slyClubsExpressionSpriteAsset),
  ]) {
    testWidgets(
      '${themedSkin.$2} Sly uses its matching authored expression atlas',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SlySprite(
                expression: SlyExpression.shocked,
                skin: themedSkin.$1,
                reactionActive: true,
                animate: false,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(
            ValueKey('sly-themed-expression-frame-${themedSkin.$2}-shocked'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('sly-premium-reaction-shocked')),
          findsNothing,
        );
        final image = tester.widget<Image>(find.byType(Image));
        final provider = image.image is ResizeImage
            ? (image.image as ResizeImage).imageProvider
            : image.image;
        expect(provider, isA<AssetImage>());
        expect((provider as AssetImage).assetName, themedSkin.$3);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

void _expectOnlySlyAsset(WidgetTester tester, String expected) {
  final image = tester.widget<Image>(
    find.descendant(
      of: find.byKey(const Key('sly-face')),
      matching: find.byType(Image),
    ),
  );
  final provider = image.image is ResizeImage
      ? (image.image as ResizeImage).imageProvider
      : image.image;
  expect(provider, isA<AssetImage>());
  expect((provider as AssetImage).assetName, expected);
}
