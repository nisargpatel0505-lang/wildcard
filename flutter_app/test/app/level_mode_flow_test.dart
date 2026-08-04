import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/app/screens/level_brief_screen.dart';
import 'package:wildcard/app/screens/level_select_screen.dart';
import 'package:wildcard/app/screens/mode_picker_screen.dart';
import 'package:wildcard/app/screens/run_type_picker_screen.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/domain/level_mode/level_catalog.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  late LevelCatalog catalog;

  setUpAll(() {
    catalog = LevelCatalog.fromJsonString(
      File('assets/data/levels-v8.5.2.generated.json').readAsStringSync(),
    );
  });

  testWidgets('New Run offers Levels and the existing Arcade picker', (
    tester,
  ) async {
    var levelsOpened = 0;
    var arcadeOpened = 0;
    await tester.pumpWidget(
      _Harness(
        child: RunTypePickerScreen(
          onOpenLevels: () => levelsOpened++,
          onOpenArcade: () => arcadeOpened++,
        ),
      ),
    );

    expect(find.text('LEVELS'), findsOneWidget);
    expect(find.text('ARCADE'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('run-type-levels')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('run-type-arcade')));
    await tester.pump();
    expect(levelsOpened, 1);
    expect(arcadeOpened, 1);

    await tester.pumpWidget(
      _Harness(
        child: ModePickerScreen(
          account: AccountState(tutorialDone: true, bestClearedHeat: 12),
          onLaunch: (_) {},
          onOpenTutorial: () async {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('NORMAL RUN'), findsOneWidget);
    expect(find.text('DAILY CHALLENGE'), findsOneWidget);
    expect(find.text('GAUNTLET'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Level Select exposes frontier, cleared and locked tables', (
    tester,
  ) async {
    final opened = <int>[];
    await tester.pumpWidget(
      _Harness(
        child: LevelSelectScreen(
          catalog: catalog,
          account: AccountState(
            highestUnlockedLevel: 3,
            clearedLevelIds: <int>{1, 2},
            levelBestScores: <int, int>{1: 150},
            levelAttempts: <int, int>{1: 2},
          ),
          onOpenLevel: (level) => opened.add(level.id),
        ),
      ),
    );
    await tester.pump();

    final campaignScroll = find
        .descendant(
          of: find.byKey(const ValueKey('level-select-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('level-1')),
      420,
      scrollable: campaignScroll,
    );
    await tester.drag(campaignScroll, const Offset(0, -90));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('level-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('level-3')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('level-4')));
    await tester.pump();
    expect(opened, <int>[1, 3]);

    final chapterScroll = find
        .descendant(
          of: find.byKey(const ValueKey('level-chapter-selector')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('level-chapter-10')),
      450,
      scrollable: chapterScroll,
    );
    await tester.drag(chapterScroll, const Offset(-100, 0));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('level-chapter-10')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('level-chapter-path-10')),
      450,
      scrollable: campaignScroll,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('level-100')),
      450,
      scrollable: campaignScroll,
    );
    expect(find.byKey(const ValueKey('level-100')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Level Select makes frontier continuation prominent', (
    tester,
  ) async {
    final opened = <int>[];
    await tester.pumpWidget(
      _Harness(
        child: LevelSelectScreen(
          catalog: catalog,
          account: AccountState(
            highestUnlockedLevel: 13,
            clearedLevelIds: <int>{for (var id = 1; id <= 12; id++) id},
            levelBestScores: <int, int>{13: 925},
            levelAttempts: <int, int>{13: 3},
          ),
          onOpenLevel: (level) => opened.add(level.id),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('campaign-progress-hero')), findsOne);
    expect(find.text('BEST SCORE'), findsOne);
    expect(find.text('925'), findsOne);
    expect(find.text('ATTEMPTS'), findsOne);
    expect(find.text('3'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('continue-frontier-button')));
    await tester.pump();
    expect(opened, <int>[13]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Level Brief requires the exact authored Joker count', (
    tester,
  ) async {
    final level = catalog.levels.firstWhere(
      (candidate) => candidate.chooseJokers > 0,
    );
    LevelLaunchRequest? launched;
    await tester.pumpWidget(
      _Harness(
        child: LevelBriefScreen(
          level: level,
          onLaunch: (request) => launched = request,
        ),
      ),
    );
    await tester.pump();

    WildcardButton startButton() => tester.widget<WildcardButton>(
      find.byKey(const ValueKey('start-level-button')),
    );
    expect(startButton().onPressed, isNull);

    for (final id in level.jokerOptionIds.take(level.chooseJokers)) {
      final option = find.byKey(ValueKey('level-joker-option-$id'));
      await tester.scrollUntilVisible(
        option,
        420,
        scrollable: find
            .descendant(
              of: find.byKey(ValueKey('level-brief-${level.id}')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(option);
      await tester.pump();
    }

    expect(startButton().onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('start-level-button')));
    await tester.pump();
    expect(launched, isNotNull);
    expect(launched!.selectedJokerIds, hasLength(level.chooseJokers));
    expect(
      launched!.selectedJokerIds.toSet(),
      level.jokerOptionIds.take(level.chooseJokers).toSet(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fixed-Joker Level Brief renders in its scrolling layout', (
    tester,
  ) async {
    final level = catalog.level(64);
    expect(level.fixedJokerIds, isNotEmpty);

    await tester.pumpWidget(
      _Harness(
        child: LevelBriefScreen(level: level, onLaunch: (_) {}),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('HELPFUL FIXED JOKERS'),
      420,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('level-brief-64')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('HELPFUL FIXED JOKERS'), findsOneWidget);
    expect(find.byKey(const ValueKey('start-level-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Level Brief reveals burden and authored help after 3 failures', (
    tester,
  ) async {
    final level = catalog.level(75);
    expect(level.negativeJokerId, isNotNull);
    expect(level.recommendedLoadouts, isNotEmpty);

    await tester.pumpWidget(
      _Harness(
        child: LevelBriefScreen(
          level: level,
          priorAttempts: 2,
          onLaunch: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('level-authored-hint')), findsNothing);

    await tester.pumpWidget(
      _Harness(
        child: LevelBriefScreen(
          level: level,
          priorAttempts: 3,
          onLaunch: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('forced-burden-heading')),
      420,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('level-brief-75')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('FORCED BURDEN'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('level-authored-hint')),
      420,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('level-brief-75')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('AUTHORED HINT'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('level-recommended-loadouts')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Level campaign hub and brief remain scroll-safe at 320x568', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      _Harness(
        child: LevelSelectScreen(
          catalog: catalog,
          account: AccountState(highestUnlockedLevel: 1),
          onOpenLevel: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    final choiceLevel = catalog.levels.firstWhere(
      (level) => level.chooseJokers > 0,
    );
    await tester.pumpWidget(
      _Harness(
        child: LevelBriefScreen(level: choiceLevel, onLaunch: (_) {}),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(
        ValueKey('level-joker-option-${choiceLevel.jokerOptionIds.last}'),
      ),
      420,
      scrollable: find
          .descendant(
            of: find.byKey(ValueKey('level-brief-${choiceLevel.id}')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Level deck inspector distinguishes authored blocked cards', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final level = catalog.level(100);
    final layout = level.layouts.first;
    final blocked = level.blockedCardsFor(layout).first;
    await tester.pumpWidget(
      _Harness(
        child: DeckOverlay(
          allHeatCards: layout.deckOrder,
          liveDrawCards: layout.deckOrder,
          title: 'Level 100 Deck',
          showBlockedCards: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('BLOCKED'), findsOneWidget);
    expect(find.text('Blocked at deal'), findsOneWidget);
    final cell = find.byKey(
      ValueKey('deck-cell-${blocked.suit.name}-${blocked.rank.name}'),
    );
    expect(
      tester.getSemantics(cell).getSemanticsData().label,
      contains('blocked from this level'),
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}

class _Harness extends StatelessWidget {
  const _Harness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: WildcardTheme.build(),
    home: child,
  );
}
