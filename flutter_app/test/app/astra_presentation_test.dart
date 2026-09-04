import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/app/screens/astra_journey_screen.dart';
import 'package:wildcard/app/screens/mode_picker_screen.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/domain/astra_journey.dart';
import 'package:wildcard/domain/astra_progression.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  // The baseline suite checks the Play presentation with this flag disabled.
  // Run this suite with --dart-define=WILDCARD_ASTRA_BUILD=true.
  if (!astraEnabled) return;

  for (final size in [const Size(320, 568), const Size(393, 873)]) {
    testWidgets('Astra home keeps actions reachable at $size', (tester) async {
      _phone(tester, size);
      var journeyOpened = false;
      await tester.pumpWidget(
        _harness(
          WildcardHomeScreen(
            coins: 120,
            bestHeat: 6,
            dailyRewardAvailable: true,
            dailyRewardLabel: 'Daily reward +25 coins',
            astraGoalTitle: 'Make it click',
            astraGoalDescription:
                'Clear Heat 3. Your first Vault is within reach.',
            astraGoalReward: '+40 coins',
            astraGoalProgress: 1,
            astraGoalProgressLabel: '3 / 3',
            astraGoalReady: true,
            onAstraJourney: () => journeyOpened = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ASTRA 6  /  FIELD TEST'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('astra-journey-entry')));
      await tester.tap(find.byKey(const Key('astra-journey-entry')));
      expect(journeyOpened, isTrue);
      await tester.ensureVisible(find.text('Settings'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'zero-coin account can choose and launch each strategic starter',
    (tester) async {
      _phone(tester, const Size(393, 873));
      RunLaunchRequest? launch;
      await tester.pumpWidget(
        _harness(
          ModePickerScreen(
            account: AccountState(tutorialDone: true, coins: 0),
            onLaunch: (value) => launch = value,
            onOpenTutorial: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final id in astraStarterJokerIds) {
        final choice = find.byKey(ValueKey('astra-starter-$id'));
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        final deal = find.byKey(const Key('astra-deal-run'));
        expect(tester.getRect(deal).bottom, lessThanOrEqualTo(873));
        await tester.tap(deal);
        expect(launch?.startJokerId, id);
        expect(launch?.mode, RunMode.normal);
        expect(launch?.stake, 0);
      }
      expect(find.textContaining('contract'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('milestone claim blocks repeated delivery while saving', (
    tester,
  ) async {
    _phone(tester, const Size(393, 873));
    final delivery = Completer<int>();
    var calls = 0;
    await tester.pumpWidget(
      _harness(
        AstraJourneyScreen(
          steps: const [
            AstraJourneyStep(
              id: 'first_heat',
              title: 'Find your opening',
              description: 'Clear Heat 1 with your free starter.',
              current: 1,
              target: 1,
              rewardCoins: 20,
              claimed: false,
            ),
          ],
          onClaim: (_) {
            calls++;
            return delivery.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final claim = find.byKey(const ValueKey('astra-claim-first_heat'));
    await tester.tap(claim);
    await tester.pump();
    final popScope = find.byWidgetPredicate((widget) => widget is PopScope);
    expect(tester.widget<PopScope>(popScope).canPop, isFalse);
    await tester.tap(claim);
    expect(calls, 1);
    delivery.complete(20);
    await tester.pumpAndSettle();
    expect(tester.widget<PopScope>(popScope).canPop, isTrue);
    expect(claim, findsNothing);
    expect(find.text('CLAIMED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _phone(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

Widget _harness(Widget child) => MaterialApp(
  theme: WildcardTheme.build(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: child,
);
