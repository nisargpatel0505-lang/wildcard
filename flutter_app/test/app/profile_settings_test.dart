import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/app/screens/cabinet_screen.dart';
import 'package:wildcard/app/screens/settings_screen.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/domain/progression_catalog.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  test('Cabinet summary preserves v7.1 metrics and legacy title names', () {
    final account = AccountState(
      bestHeat: 13,
      bestScore: 9000,
      bestClearedHeat: 12,
      title: 'House Champion',
      stats: const PlayerStatistics(
        runs: 10,
        wins: 3,
        gauntletWins: 1,
        hands: 149,
      ),
      runLog: const <RunLogRecord>[
        RunLogRecord(
          date: '2026-07-20',
          heat: 5,
          cleared: 4,
          score: 1000,
          modeCode: 'S',
          won: false,
          abandoned: false,
        ),
        RunLogRecord(
          date: '2026-07-21',
          heat: 10,
          cleared: 9,
          score: 3000,
          modeCode: 'G',
          won: false,
          abandoned: true,
        ),
      ],
      cosmeticsOwned: <String>{'theme_sunset', 'felt_neon', 'sly_gold'},
    );
    const snapshot = ProgressionSnapshot(
      bestHeat: 13,
      bestClearedHeat: 12,
      bestScore: 9000,
      coins: 2000,
      unlockedJokers: 40,
      achievementsEarned: 20,
      cosmeticsOwned: 6,
    );

    final summary = CabinetSummary.fromAccount(account, snapshot);

    expect(summary.winRate, '30%');
    expect(summary.averageHands, '14.9');
    expect(summary.recentAverageScore, '2,000');
    expect(summary.recentAverageHeat, '7.5');
    expect(summary.standardWins, 2);
    expect(summary.lossesAndFolds, 7);
    expect(summary.themesOwned, 2);
    expect(summary.tablesOwned, 2);
    expect(summary.slyLooksOwned, 2);
    expect(summary.badgesEarned, 9);
    expect(summary.equippedTitleName, 'House Champion');
    expect(canonicalTitleId('t_champ'), 't_champ');
    expect(canonicalTitleId(' house champion '), 't_champ');
  });

  testWidgets('Daily Board editor sanitizes, limits and saves the name', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    String? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: DailyBoardNameEditor(
              accountName: '',
              signedIn: false,
              onSave: (name) async => saved = name,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('must sign in with Google'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('daily-board-name-field')),
      r'ni$ sar-42xyz',
    );
    expect(find.text('NISAR42X'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-daily-board-name')));
    await tester.pumpAndSettle();

    expect(saved, 'NISAR42X');
    expect(tester.takeException(), isNull);
  });
}
