import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/ui/screens/boot_loading_screen.dart';
import 'package:wildcard/ui/wildcard_theme.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('SpaceGrotesk')
          ..addFont(rootBundle.load('assets/fonts/space-grotesk-400.ttf'))
          ..addFont(rootBundle.load('assets/fonts/space-grotesk-700.ttf')))
        .load();
  });

  for (final size in [const Size(320, 568), const Size(393, 873)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('loader fits $size at text $scale with a visible bar', (
        tester,
      ) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = size;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(
          MaterialApp(home: Builder(builder: (context) => const SizedBox())),
        );
        final context = tester.element(find.byType(SizedBox).first);
        await tester.runAsync(() async {
          await Future.wait([
            precacheImage(
              const AssetImage('assets/art/wildcard-logo-v692.webp'),
              context,
            ),
            precacheImage(
              AssetImage(
                WildcardThemeTokens.forId(
                  WildcardThemeId.classic,
                ).backgroundAssetFor(WildcardUiSurface.loading)!,
              ),
              context,
            ),
          ]);
        });
        final progress = ValueNotifier<BootProgress>(
          const BootProgress(.84, 'Setting Sly’s table…'),
        );
        addTearDown(progress.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: WildcardTheme.build(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: RepaintBoundary(
                key: const Key('boot-visual-capture'),
                child: BootLoadingScreen(
                  progress: progress,
                  visualProgress: const AlwaysStoppedAnimation(.58),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('58%'), findsOneWidget);
        final logo = tester.getRect(find.byKey(const Key('boot-logo-image')));
        final panel = tester.getRect(
          find.byKey(const Key('boot-progress-panel')),
        );
        expect(logo.bottom, lessThan(panel.top));
        expect(panel.left, greaterThanOrEqualTo(24));
        expect(panel.right, lessThanOrEqualTo(size.width - 24));
        expect(panel.bottom, lessThanOrEqualTo(size.height));
        expect(
          tester
              .getSize(find.byKey(const Key('boot-segmented-progress')))
              .height,
          16,
        );
        await expectLater(
          find.byKey(const Key('boot-visual-capture')),
          matchesGoldenFile(
            'goldens/boot/loading-${size.width.toInt()}-${scale.toStringAsFixed(1)}.png',
          ),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
