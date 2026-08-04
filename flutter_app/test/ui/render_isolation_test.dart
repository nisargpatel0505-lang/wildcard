import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/cards.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  testWidgets('full-screen static art is isolated from live content', (
    tester,
  ) async {
    const liveContentKey = ValueKey('live-background-content');
    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: const SizedBox(
          width: 360,
          height: 800,
          child: WildcardBackground(child: SizedBox(key: liveContentKey)),
        ),
      ),
    );

    final staticBoundary = find.byWidgetPredicate(
      (widget) =>
          widget is RepaintBoundary &&
          widget.key is ValueKey<String> &&
          ((widget.key! as ValueKey<String>).value).startsWith(
            'wildcard-static-background-',
          ),
    );
    expect(staticBoundary, findsOneWidget);
    expect(
      find.ancestor(of: find.byKey(liveContentKey), matching: staticBoundary),
      findsNothing,
    );
  });

  testWidgets('cards and compact Jokers own local repaint boundaries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: Scaffold(
          body: Column(
            children: [
              const PlayingCardTile(
                card: PlayingCard(rank: CardRank.ace, suit: CardSuit.spades),
              ),
              CompactJokerCard(joker: jokerCatalog.first),
            ],
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(PlayingCardTile),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(CompactJokerCard),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Sly atlas cache targets the physical display size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Center(child: SlySprite(size: 96))),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    final resized = image.image as ResizeImage;
    expect(resized.width, 720);
    expect(resized.height, 720);
  });
}
