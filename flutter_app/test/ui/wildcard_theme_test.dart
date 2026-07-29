import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/ui/widgets/wildcard_background.dart';
import 'package:wildcard/ui/wildcard_theme.dart';

void main() {
  group('expanded WILDCARD themes', () {
    test('four kingdom themes resolve distinct home and gameplay artwork', () {
      const packs = <WildcardThemeId, (String gameplay, String home)>{
        WildcardThemeId.heartsKingdom: (
          'assets/art/backgrounds/wildcard-kingdom-hearts-gameplay.webp',
          'assets/art/backgrounds/wildcard-theme-hearts-kingdom-home.webp',
        ),
        WildcardThemeId.spadesKingdom: (
          'assets/art/backgrounds/wildcard-kingdom-spades-gameplay.webp',
          'assets/art/backgrounds/wildcard-theme-spades-kingdom-home.webp',
        ),
        WildcardThemeId.diamondsKingdom: (
          'assets/art/backgrounds/wildcard-kingdom-diamonds-gameplay.webp',
          'assets/art/backgrounds/wildcard-theme-diamonds-kingdom-home.webp',
        ),
        WildcardThemeId.clubsKingdom: (
          'assets/art/backgrounds/wildcard-kingdom-clubs-gameplay.webp',
          'assets/art/backgrounds/wildcard-theme-clubs-kingdom-home.webp',
        ),
      };

      for (final entry in packs.entries) {
        final tokens = WildcardThemeTokens.forId(entry.key);
        expect(tokens.homeBackgroundAsset, entry.value.$2);
        expect(tokens.gameplayBackgroundAsset, entry.value.$1);
        expect(
          tokens.backgroundAssetFor(WildcardUiSurface.home),
          entry.value.$2,
        );
        expect(
          tokens.backgroundAssetFor(WildcardUiSurface.normalGameplay),
          entry.value.$1,
        );
      }
    });

    test('themes without gameplay art safely reuse their home background', () {
      final tokens = WildcardThemeTokens.forId(WildcardThemeId.classic);
      expect(tokens.gameplayBackgroundAsset, isNull);
      expect(
        tokens.backgroundAssetFor(WildcardUiSurface.normalGameplay),
        tokens.homeBackgroundAsset,
      );
    });

    test('all three new themes point at their dedicated room artwork', () {
      expect(WildcardThemeId.values, hasLength(21));

      expect(
        WildcardThemeTokens.forId(
          WildcardThemeId.blockDropArcade,
        ).homeBackgroundAsset,
        'assets/art/backgrounds/wildcard-theme-block-drop-arcade.webp',
      );
      expect(
        WildcardThemeTokens.forId(
          WildcardThemeId.abyssalJackpot,
        ).homeBackgroundAsset,
        'assets/art/backgrounds/wildcard-theme-abyssal-jackpot.webp',
      );
      expect(
        WildcardThemeTokens.forId(
          WildcardThemeId.desertMirage,
        ).homeBackgroundAsset,
        'assets/art/backgrounds/wildcard-theme-desert-mirage.webp',
      );
    });

    test('new rooms use three visibly distinct UI palettes', () {
      final themes = <WildcardThemeTokens>[
        WildcardThemeTokens.forId(WildcardThemeId.blockDropArcade),
        WildcardThemeTokens.forId(WildcardThemeId.abyssalJackpot),
        WildcardThemeTokens.forId(WildcardThemeId.desertMirage),
      ];

      expect(themes.map((theme) => theme.ink).toSet(), hasLength(3));
      expect(themes.map((theme) => theme.felt).toSet(), hasLength(3));
      expect(themes.map((theme) => theme.mint).toSet(), hasLength(3));
      expect(themes.map((theme) => theme.gold).toSet(), hasLength(3));
      expect(themes.map((theme) => theme.panel).toSet(), hasLength(3));
    });

    for (final theme in <WildcardThemeId>[
      WildcardThemeId.blockDropArcade,
      WildcardThemeId.abyssalJackpot,
      WildcardThemeId.desertMirage,
      WildcardThemeId.heartsKingdom,
      WildcardThemeId.spadesKingdom,
      WildcardThemeId.diamondsKingdom,
      WildcardThemeId.clubsKingdom,
    ]) {
      testWidgets('${theme.name} room renders at 320x568', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        addTearDown(() {
          tester.view.resetDevicePixelRatio();
          tester.view.resetPhysicalSize();
        });

        final tokens = WildcardThemeTokens.forId(theme);
        await tester.pumpWidget(
          MaterialApp(
            theme: WildcardTheme.build(themeId: theme),
            home: const WildcardBackground(
              child: Center(child: Text('WILDCARD')),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('WILDCARD'), findsOneWidget);
        expect(
          find.byKey(
            ValueKey(
              'wildcard-static-background-${tokens.homeBackgroundAsset}',
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
