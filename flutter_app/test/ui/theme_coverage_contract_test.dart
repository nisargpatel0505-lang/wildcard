import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/ui/widgets/wildcard_background.dart';
import 'package:wildcard/ui/wildcard_theme.dart';

void main() {
  group('equipped UI theme coverage contract', () {
    test(
      'every player-facing surface has an explicit palette/backdrop spec',
      () {
        expect(
          WildcardThemeCoverage.surfaces.keys.toSet(),
          WildcardUiSurface.values.toSet(),
        );
        expect(
          WildcardThemeCoverage.surfaces.values.every(
            (spec) => spec.usesThemePalette,
          ),
          isTrue,
          reason:
              'No surface may opt out of the equipped palette. Sly and table '
              'skins remain independent presentation layers.',
        );
      },
    );

    test(
      'every non-overlay surface resolves an authored backdrop strategy',
      () {
        for (final theme in WildcardThemeId.values) {
          final tokens = WildcardThemeTokens.forId(theme);
          for (final surface in WildcardUiSurface.values) {
            final role = WildcardThemeCoverage.forSurface(surface).backdrop;
            final asset = tokens.backgroundAssetFor(surface);
            if (role == WildcardBackdropRole.none ||
                role == WildcardBackdropRole.runSetup) {
              expect(asset, isNull, reason: '${theme.name}/${surface.name}');
            } else {
              expect(
                asset,
                isNotEmpty,
                reason: '${theme.name}/${surface.name}',
              );
            }
          }
        }
      },
    );

    test('shared Material surfaces are derived from the equipped palette', () {
      final classicTokens = WildcardThemeTokens.forId(WildcardThemeId.classic);
      final vaporTokens = WildcardThemeTokens.forId(WildcardThemeId.vaporwave);
      final classic = WildcardTheme.build(themeId: WildcardThemeId.classic);
      final vapor = WildcardTheme.build(themeId: WildcardThemeId.vaporwave);

      expect(classic.dialogTheme.backgroundColor, classicTokens.surfaceStrong);
      expect(vapor.dialogTheme.backgroundColor, vaporTokens.surfaceStrong);
      expect(
        classic.dialogTheme.backgroundColor,
        isNot(vapor.dialogTheme.backgroundColor),
      );
      expect(classic.inputDecorationTheme.fillColor, classicTokens.fieldFill);
      expect(vapor.inputDecorationTheme.fillColor, vaporTokens.fieldFill);
      expect(classic.scaffoldBackgroundColor, classicTokens.pageBackground);
      expect(vapor.scaffoldBackgroundColor, vaporTokens.pageBackground);
      expect(
        classic.snackBarTheme.backgroundColor,
        classicTokens.surfaceStrong,
      );
      expect(vapor.snackBarTheme.backgroundColor, vaporTokens.surfaceStrong);
    });

    test('every palette preserves readable text and control contrast', () {
      for (final theme in WildcardThemeId.values) {
        final tokens = WildcardThemeTokens.forId(theme);
        expect(
          _contrast(tokens.cream, tokens.surfaceStrong),
          greaterThanOrEqualTo(4.5),
          reason: '${theme.name} body text',
        );
        expect(
          _contrast(tokens.onPrimaryAccent, tokens.mint),
          greaterThanOrEqualTo(3),
          reason: '${theme.name} primary control',
        );
        expect(
          _contrast(tokens.onSecondaryAccent, tokens.gold),
          greaterThanOrEqualTo(3),
          reason: '${theme.name} secondary control',
        );
      }
    });

    for (final surface in WildcardUiSurface.values.where(
      (surface) =>
          WildcardThemeCoverage.forSurface(surface).backdrop !=
          WildcardBackdropRole.none,
    )) {
      testWidgets('${surface.name} binds to the equipped theme', (
        tester,
      ) async {
        const themeId = WildcardThemeId.vaporwave;
        final tokens = WildcardThemeTokens.forId(themeId);
        await tester.pumpWidget(
          MaterialApp(
            theme: WildcardTheme.build(themeId: themeId),
            home: WildcardBackground(
              surface: surface,
              child: const SizedBox.expand(),
            ),
          ),
        );
        await tester.pump();

        final background = tester.widget<ColoredBox>(
          find.byKey(ValueKey('wildcard-surface-${surface.name}')),
        );
        expect(background.color, tokens.pageBackground);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

double _contrast(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + .05) / (darker + .05);
}
