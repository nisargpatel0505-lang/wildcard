import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildcard/app/app_controller.dart';
import 'package:wildcard/app/screens/vault_screen.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/game/game_models.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  testWidgets('an interrupted first-loss reward remains visible in the Vault', (
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
    await tester.runAsync(app.completeTutorial);
    await tester.runAsync(
      () => app.gamePersistenceCallbacks().mutateAccount(
        const AccountMutation(
          claimId: 'tutorial-vault-recovery',
          kind: AccountMutationKind.runFinished,
          runMode: RunMode.normal,
          won: false,
          stagesCleared: 0,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: VaultScreen(controller: app),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('tutorial-comeback-vault')), findsOneWidget);
    expect(
      find.byKey(const Key('open-tutorial-comeback-vault')),
      findsOneWidget,
    );
    expect(find.textContaining('free, non-duplicate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cosmetic Vault discloses live kind odds at 320x568', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final app = (await tester.runAsync(() => AppController.bootstrap()))!;
    addTearDown(app.dispose);
    await tester.runAsync(
      () => app.mutateAccount((account) {
        account.tutorialDone = true;
        account.coins = 2000;
      }, syncCloud: false),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: VaultScreen(controller: app),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('joker-section-vaults')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('COSMETIC VAULT'),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('UI theme 0.8%'), findsOneWidget);
    expect(find.textContaining('Cosmetics only'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
