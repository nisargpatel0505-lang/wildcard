import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/app/screens/astra_journey_screen.dart';
import 'package:wildcard/app/screens/mode_picker_screen.dart';
import 'package:wildcard/core/daily_utc_date.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/domain/astra_journey.dart';
import 'package:wildcard/domain/astra_progression.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  // Astra presentation is now the official default. The offline-build flag
  // must not be necessary to exercise the public home and starter draft.
  if (!astraExperienceEnabled) return;

  for (final size in [
    const Size(320, 568),
    const Size(375, 812),
    const Size(393, 873),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('official Astra home actions work at $size / text $scale', (
        tester,
      ) async {
        _phone(tester, size);
        final actions = <String>[];
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
              onAstraJourney: () => actions.add('journey'),
              onNewRun: () => actions.add('play'),
              onJokerUnlocks: () => actions.add('vault'),
              onShop: () => actions.add('shop'),
              onCabinet: () => actions.add('cabinet'),
              onWeeklyMissions: () => actions.add('missions'),
              onSettings: () => actions.add('settings'),
              onMore: () => actions.add('more'),
              onDailyReward: () => actions.add('daily'),
            ),
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            astraEnabled ? 'ASTRA 6  /  FIELD TEST' : 'WILDCARD  /  ASTRA',
          ),
          findsOneWidget,
        );
        if (!astraEnabled) {
          expect(find.textContaining('Local field test'), findsNothing);
          expect(find.textContaining('no real purchases'), findsNothing);
        }
        for (final action in <(String, Finder)>[
          ('play', find.byKey(const Key('astra-primary-play'))),
          ('journey', find.byKey(const Key('astra-journey-entry'))),
          ('daily', _button('Daily reward +25 coins')),
          ('vault', _button('Vault')),
          ('shop', _button('Wardrobe & Shop')),
          ('cabinet', _button('Cabinet')),
          ('missions', _button('Missions')),
          ('settings', find.text('Settings')),
          ('more', find.text('More')),
        ]) {
          await tester.ensureVisible(action.$2);
          await tester.pumpAndSettle();
          expect(action.$2.hitTestable(), findsOneWidget);
          final rect = tester.getRect(action.$2);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          await tester.tap(action.$2);
          await tester.pumpAndSettle();
          expect(actions.last, action.$1);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('free starter draft fits $size / text $scale', (
        tester,
      ) async {
        _phone(tester, size);
        RunLaunchRequest? launch;
        await tester.pumpWidget(
          _harness(
            ModePickerScreen(
              account: AccountState(tutorialDone: true, coins: 0),
              onLaunch: (value) => launch = value,
              onOpenTutorial: () async {},
            ),
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();
        for (final id in astraStarterJokerIds) {
          final choice = find.byKey(ValueKey('astra-starter-$id'));
          // ListView builds the draft rows lazily on the smallest phones.
          // Scroll as a player does instead of assuming every row is mounted.
          await tester.drag(find.byType(ListView), const Offset(0, 3000));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(choice, 120);
          await tester.pumpAndSettle();
          await tester.tap(choice);
          await tester.pumpAndSettle();
          final deal = find.byKey(const Key('astra-deal-run'));
          expect(deal.hitTestable(), findsOneWidget);
          expect(tester.getRect(deal).bottom, lessThanOrEqualTo(size.height));
          await tester.tap(deal);
          expect(launch?.startJokerId, id);
          expect(launch?.mode, RunMode.normal);
          expect(launch?.stake, 0);
        }
        expect(find.text('WILDCARD ARCADE'), findsNothing);
        expect(find.byKey(const Key('open-arcade-mode')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('saved run primary action resumes without starting a new run', (
    tester,
  ) async {
    _phone(tester, const Size(375, 812));
    var resumes = 0;
    var starts = 0;
    await tester.pumpWidget(
      _harness(
        WildcardHomeScreen(
          hasSavedRun: true,
          onResume: () => resumes++,
          onNewRun: () => starts++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final resume = find.byKey(const Key('astra-primary-play'));
    expect(tester.widget<WildcardButton>(resume).label, 'Continue Run');
    await tester.ensureVisible(resume);
    await tester.tap(resume);
    expect(resumes, 1);
    expect(starts, 0);
    await tester.ensureVisible(find.text('Choose a new run'));
    await tester.tap(find.text('Choose a new run'));
    expect(starts, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tutorial must finish before first run and daily are enabled', (
    tester,
  ) async {
    _phone(tester, const Size(375, 812));
    final account = AccountState(coins: 0);
    var tutorialCalls = 0;
    RunLaunchRequest? launch;
    await tester.pumpWidget(
      _harness(
        ModePickerScreen(
          account: account,
          onLaunch: (value) => launch = value,
          onOpenTutorial: () async {
            tutorialCalls++;
            account.tutorialDone = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final deal = find.byKey(const Key('astra-deal-run'));
    expect(tester.widget<WildcardButton>(deal).onPressed, isNull);
    expect(_modeChip(tester, 'Daily').onSelected, isNull);
    expect(_modeChip(tester, 'Gauntlet').onSelected, isNull);
    final tutorial = _button('Play Tutorial');
    await tester.ensureVisible(tutorial);
    await tester.tap(tutorial);
    await tester.pumpAndSettle();
    expect(tutorialCalls, 1);
    expect(tutorial, findsNothing);
    expect(tester.widget<WildcardButton>(deal).onPressed, isNotNull);
    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(_modeChip(tester, 'Daily').onSelected, isNotNull);
    await tester.tap(deal);
    expect(launch?.mode, RunMode.normal);
    expect(launch?.startJokerId, isIn(astraStarterJokerIds));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Daily and unlocked Gauntlet launch with their fixed rules', (
    tester,
  ) async {
    _phone(tester, const Size(375, 812));
    RunLaunchRequest? launch;
    await tester.pumpWidget(
      _harness(
        ModePickerScreen(
          account: AccountState(
            tutorialDone: true,
            bestClearedHeat: 12,
            coins: 0,
          ),
          onLaunch: (value) => launch = value,
          onOpenTutorial: () async {},
        ),
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();
    for (final mode in [
      ('Daily', RunMode.daily),
      ('Gauntlet', RunMode.gauntlet),
    ]) {
      expect(_modeChip(tester, mode.$1).onSelected, isNotNull);
      await tester.ensureVisible(find.text(mode.$1));
      await tester.tap(find.text(mode.$1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('astra-starter-polish')), findsNothing);
      await tester.tap(find.byKey(const Key('astra-deal-run')));
      expect(launch?.mode, mode.$2);
      expect(launch?.difficulty, RunDifficulty.medium);
      expect(launch?.stake, 0);
      expect(launch?.startJokerId, isNull);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('used Daily attempt is locked until next UTC day', (
    tester,
  ) async {
    _phone(tester, const Size(375, 812));
    await tester.pumpWidget(
      _harness(
        ModePickerScreen(
          account: AccountState(
            tutorialDone: true,
            dailyRunDate: dailyUtcDateKey(),
            unknownFields: {dailyRunDateUtcMarkerKey: true},
          ),
          onLaunch: (_) {},
          onOpenTutorial: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_modeChip(tester, 'Daily').onSelected, isNull);
    expect(_modeChip(tester, 'Normal').onSelected, isNotNull);
    expect(tester.takeException(), isNull);
  });

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

Finder _button(String label) => find.byWidgetPredicate(
  (widget) => widget is WildcardButton && widget.label == label,
);

ChoiceChip _modeChip(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(
      find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)),
    );

Widget _harness(Widget child, {double textScale = 1}) => MaterialApp(
  theme: WildcardTheme.build(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: true,
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  ),
  home: child,
);
