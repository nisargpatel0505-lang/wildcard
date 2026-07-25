import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/app/screens/mode_picker_screen.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  testWidgets('Choose Run uses the quiet static poker setup room', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: ModePickerScreen(
          account: AccountState(tutorialDone: true),
          onLaunch: (_) {},
          onOpenTutorial: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final background = tester.widget<WildcardBackground>(
      find.byType(WildcardBackground),
    );
    expect(background.room, WildcardRoom.runSetup);
    expect(find.text('CHOOSE RUN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
