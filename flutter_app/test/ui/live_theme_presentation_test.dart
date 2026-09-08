import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildcard/app/app_controller.dart';
import 'package:wildcard/app/screens/shop_hub_screen.dart';
import 'package:wildcard/ui/widgets/live_theme_atmosphere.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

const themes = <WildcardThemeId>[
  WildcardThemeId.midnightObservatory,
  WildcardThemeId.jadeConservatory,
  WildcardThemeId.neonAfterhours,
  WildcardThemeId.crimsonTheatre,
];

void main() {
  setUpAll(() async {
    await (FontLoader('SpaceGrotesk')
          ..addFont(rootBundle.load('assets/fonts/space-grotesk-400.ttf'))
          ..addFont(rootBundle.load('assets/fonts/space-grotesk-700.ttf')))
        .load();
    await (FontLoader(
      'Bungee',
    )..addFont(rootBundle.load('assets/fonts/bungee-regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final theme in themes) {
    testWidgets(
      '${theme.name} home is readable and includes native atmosphere',
      (tester) async {
        _phone(tester);
        await _precache(tester, [
          WildcardThemeTokens.forId(theme).homeBackgroundAsset,
          'assets/art/wildcard-logo-v692.webp',
        ]);
        await tester.pumpWidget(
          MaterialApp(
            theme: WildcardTheme.build(themeId: theme),
            home: RepaintBoundary(
              key: const Key('theme-capture'),
              child: WildcardHomeScreen(
                coins: 4209,
                bestHeat: 21,
                astraGoalTitle: 'Build your first engine',
                astraGoalDescription:
                    'Choose a starter. Make your next hand count.',
                astraGoalReward: '+40 coins',
                astraGoalProgress: .6,
                astraGoalProgressLabel: '2 / 3',
                onNewRun: () {},
                onJokerUnlocks: () {},
                onShop: () {},
                onCabinet: () {},
                onWeeklyMissions: () {},
                onSettings: () {},
                onMore: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('ASTRA'), findsNothing);
        expect(find.byType(LiveThemeAtmosphere), findsOneWidget);
        await expectLater(
          find.byKey(const Key('theme-capture')),
          matchesGoldenFile('goldens/live-themes/${theme.name}-home.png'),
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'theme studio exposes all four free choices without coin spending',
    (tester) async {
      _phone(tester);
      await _precache(
        tester,
        themes
            .map((id) => WildcardThemeTokens.forId(id).homeBackgroundAsset)
            .toList(),
      );
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final app = (await tester.runAsync(() => AppController.bootstrap()))!;
      addTearDown(app.dispose);
      await tester.runAsync(
        () => app.mutateAccount((a) => a.coins = 120, syncCloud: false),
      );
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: app,
          builder: (context, _) => MaterialApp(
            theme: WildcardTheme.build(
              themeId: resolveWildcardThemeId(app.account.equipped.theme),
            ),
            home: RepaintBoundary(
              key: const Key('studio-capture'),
              child: ShopHubScreen(controller: app),
            ),
          ),
        ),
      );
      await tester.tap(find.text('WARDROBE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      for (final id in [
        'theme_midnight_observatory',
        'theme_jade_conservatory',
        'theme_neon_afterhours',
        'theme_crimson_theatre',
      ]) {
        final button = find.byKey(ValueKey('equip-$id'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(app.account.equipped.theme, id);
        expect(app.account.coins, 120);
        final tokens = WildcardThemeTokens.forId(resolveWildcardThemeId(id));
        final header = tester.widget<Container>(
          find.byKey(const ValueKey('page-navigation-backing')),
        );
        final tabs = tester.widget<ColoredBox>(
          find.byKey(const ValueKey('shop-tabs-backing')),
        );
        expect(header.color, tabs.color);
        // Even a white highlight in the artwork cannot wash out small labels.
        final backing = Color.alphaBlend(header.color!, Colors.white);
        final contrast =
            (tokens.creamDim.computeLuminance() + .05) /
            (backing.computeLuminance() + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
        expect(tester.takeException(), isNull);
      }
      await tester.drag(find.byType(ListView).last, const Offset(0, 2000));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byKey(const Key('studio-capture')),
        matchesGoldenFile('goldens/live-themes/theme-studio.png'),
      );
      await tester.tap(find.text('Tables'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('studio-theme_midnight_observatory')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'live painter pauses for reduced motion, background and hidden route',
    (tester) async {
      _phone(tester);
      Widget harness({bool reduced = false, bool ticker = true}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(393, 873),
            disableAnimations: reduced,
          ),
          child: TickerMode(
            enabled: ticker,
            child: const LiveThemeAtmosphere(
              style: WildcardLiveBackdrop.observatory,
              primary: Colors.cyan,
              secondary: Colors.amber,
              runInWidgetTests: true,
            ),
          ),
        ),
      );
      double phase() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<LiveThemePainter>()
          .single
          .phase
          .value;
      await tester.pumpWidget(harness());
      await tester.pump(const Duration(milliseconds: 100));
      final start = phase();
      await tester.pump(const Duration(seconds: 1));
      expect(phase(), isNot(start));
      await tester.pumpWidget(harness(reduced: true));
      final reduced = phase();
      await tester.pump(const Duration(seconds: 1));
      expect(phase(), reduced);
      await tester.pumpWidget(harness());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final paused = phase();
      await tester.pump(const Duration(seconds: 1));
      expect(phase(), paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(harness(ticker: false));
      final hidden = phase();
      await tester.pump(const Duration(seconds: 1));
      expect(phase(), hidden);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

void _phone(WidgetTester tester) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(393, 873);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

Future<void> _precache(WidgetTester tester, List<String> assets) async {
  await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  final context = tester.element(find.byType(SizedBox).first);
  await tester.runAsync(() async {
    for (final asset in assets) {
      await precacheImage(AssetImage(asset), context);
      await precacheImage(ResizeImage(AssetImage(asset), width: 393), context);
      await precacheImage(ResizeImage(AssetImage(asset), width: 400), context);
    }
  });
}
