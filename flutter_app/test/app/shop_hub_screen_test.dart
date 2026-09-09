import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildcard/app/app_controller.dart';
import 'package:wildcard/app/screens/shop_hub_screen.dart';
import 'package:wildcard/core/build_options.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  testWidgets('shop explains paid instant bonuses and owner separation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 873);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final app = (await tester.runAsync(() => AppController.bootstrap()))!;
    addTearDown(app.dispose);
    await tester.runAsync(
      () => app.mutateAccount((account) {
        account.coins = 420;
        account.noAds = true;
      }, syncCloud: false),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: ShopHubScreen(controller: app),
      ),
    );
    // TabBarView keeps the neighbouring wardrobe close enough to build its
    // ambient Sly ticker, so use bounded pumps throughout this presentation
    // test instead of waiting for every animation to stop.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ACCOUNT WALLET'), findsOneWidget);
    expect(find.byType(WildcardCoinIcon), findsWidgets);
    expect(
      tester
          .widgetList<RunCoinBadge>(find.byType(RunCoinBadge))
          .where((badge) => badge.coins == 420 && badge.account),
      isNotEmpty,
    );
    expect(
      find.textContaining('CLAIM +25 COINS'),
      ownerPhoneNoAdsBuild ? findsNothing : findsOneWidget,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -1600));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('FORCED ADS REMOVED'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('WARDROBE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('MAKE THE TABLE YOURS'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('studio-theme_midnight_observatory')),
      findsOneWidget,
    );
    await tester.tap(find.text('Tables'));
    await tester.pump();
    expect(find.byType(CoinPrice), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
