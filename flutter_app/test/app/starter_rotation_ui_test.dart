import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/app/screens/mode_picker_screen.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/domain/astra_progression.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  for (final width in [320.0, 393.0]) {
    testWidgets('each engine cycles owned starters and launches at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 873);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final owned = {
        ...starterJokerIds,
        'wire',
        'shortcut',
        'flushfund',
        'trainer',
      };
      final draft = astraStarterDraft(71, unlockedJokerIds: owned);
      RunLaunchRequest? launch;
      await tester.pumpWidget(
        MaterialApp(
          theme: WildcardTheme.build(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: ModePickerScreen(
            starterDraftSeed: 71,
            account: AccountState(tutorialDone: true, unlockedJokerIds: owned),
            onLaunch: (request) => launch = request,
            onOpenTutorial: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final engine in StarterEngine.values) {
        final next = find.byKey(ValueKey('starter-next-${engine.name}'));
        final previous = find.byKey(
          ValueKey('starter-previous-${engine.name}'),
        );
        final pool = draft[engine.index];
        await tester.drag(find.byType(ListView), const Offset(0, 3000));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(next, 120);
        await tester.pumpAndSettle();
        final rect = tester.getRect(next);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        for (var index = 1; index <= pool.length; index++) {
          await tester.drag(find.byType(ListView), const Offset(0, 3000));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(next, 100);
          await tester.pumpAndSettle();
          await tester.tap(next);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('astra-deal-run')));
          expect(launch?.startJokerId, pool[index % pool.length].id);
        }
        await tester.drag(find.byType(ListView), const Offset(0, 3000));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(previous, 100);
        await tester.pumpAndSettle();
        await tester.tap(previous);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('astra-deal-run')));
        expect(launch?.startJokerId, pool.last.id);
        expect(launch?.stake, 0);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
