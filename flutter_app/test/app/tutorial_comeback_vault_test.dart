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
}
