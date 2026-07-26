import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/ui/widgets/wildcard_background.dart';
import 'package:wildcard/ui/wildcard_theme.dart';

void main() {
  group('expanded WILDCARD themes', () {
    test('all three new themes point at their dedicated room artwork', () {
      expect(WildcardThemeId.values, hasLength(17));

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
