import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/app/developer_access.dart';
import 'package:wildcard/app/screens/mode_picker_screen.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/domain/game_rules.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  test('developer digest comparison normalizes without storing plaintext', () {
    final expected = sha256.convert('sample'.codeUnits).toString();

    expect(
      digestMatches(input: '  SAMPLE  ', expectedDigest: expected),
      isTrue,
    );
    expect(digestMatches(input: 'wrong', expectedDigest: expected), isFalse);
    expect(digestMatches(input: '', expectedDigest: expected), isFalse);
    expect(digestMatches(input: 'sample', expectedDigest: 'short'), isFalse);
  });

  test('developer flags survive legacy account serialization', () {
    final account = AccountState(
      unknownFields: <String, Object?>{
        developerUnlockedField: true,
        developerGauntletField: true,
      },
    );

    final decoded = AccountState.decode(account.encode());

    expect(developerToolsUnlocked(decoded), isTrue);
    expect(developerGauntletUnlocked(decoded), isTrue);
  });

  test('release upgrade restores the complete pre-developer account', () {
    final account = AccountState(
      coins: 2318,
      unlockedJokerIds: <String>{'copper', 'polish'},
      tutorialDone: true,
      bestHeat: 21,
      bestScore: 58652,
    );
    captureDeveloperBaseline(account);
    account.unknownFields[developerUnlockedField] = true;
    account.unknownFields[developerGauntletField] = true;
    account.unknownFields[developerCoinGrantField] = 10000;
    account.unknownFields[developerJokerGrantField] = <String>['allin'];
    account.coins += 10000;
    account.unlockedJokerIds.add('allin');
    account.bestHeat = 99;
    account.bestScore = 9999999;

    final restored = releaseSafeDeveloperAccount(account, releaseBuild: true);

    expect(restored.coins, 2318);
    expect(restored.unlockedJokerIds, <String>{'copper', 'polish'});
    expect(restored.bestHeat, 21);
    expect(restored.bestScore, 58652);
    expect(restored.unknownFields, isNot(contains(developerUnlockedField)));
    expect(restored.unknownFields, isNot(contains(developerBaselineField)));
  });

  test('old debug grant ledger is removed when no baseline exists', () {
    final account = AccountState(
      coins: 7318,
      unlockedJokerIds: <String>{'copper', 'polish', 'allin'},
      unknownFields: <String, Object?>{
        developerUnlockedField: true,
        developerCoinGrantField: 5000,
        developerJokerGrantField: <String>['allin'],
      },
    );

    final restored = releaseSafeDeveloperAccount(account, releaseBuild: true);

    expect(restored.coins, 2318);
    expect(restored.unlockedJokerIds, <String>{'copper', 'polish'});
    expect(restored.unknownFields, isEmpty);
  });

  test('first-run reset retains the one-time gift guard', () {
    final account = AccountState(
      tutorialDone: true,
      starterGiftClaimed: false,
      firstRunStarted: true,
      firstLossCoached: true,
      tutorialChestClaimed: true,
      unknownFields: <String, Object?>{developerUnlockedField: true},
    );

    resetDeveloperFirstRunState(account);

    expect(account.tutorialDone, isFalse);
    expect(account.firstRunStarted, isFalse);
    expect(account.firstLossCoached, isFalse);
    expect(account.tutorialChestClaimed, isFalse);
    expect(account.starterGiftClaimed, isTrue);
  });

  testWidgets('debug Gauntlet override opens mode without changing Best Heat', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    RunLaunchRequest? launched;
    final account = AccountState(
      tutorialDone: true,
      bestClearedHeat: 0,
      unknownFields: <String, Object?>{
        developerUnlockedField: true,
        developerGauntletField: true,
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: ModePickerScreen(
          account: account,
          onLaunch: (request) => launched = request,
          onOpenTutorial: () async {},
        ),
      ),
    );

    expect(find.textContaining('Debug access active'), findsOneWidget);
    await tester.tap(find.text('GAUNTLET'));
    await tester.pump();
    await tester.ensureVisible(find.text('DEAL THIS RUN'));
    await tester.tap(find.text('DEAL THIS RUN'));
    await tester.pump();

    expect(launched?.mode, RunMode.gauntlet);
    expect(account.bestClearedHeat, 0);
    expect(account.bestHeat, 0);
  });
}
