import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildcard/app/app_controller.dart';
import 'package:wildcard/app/screens/joker_collection_section.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PackageInfo.setMockInitialValues(
      appName: 'WILDCARD',
      packageName: 'com.nisarg.wildcard',
      version: '8.0.0-dev.1',
      buildNumber: '46',
      buildSignature: 'test',
      installerStore: null,
    );
  });

  test('collection filter and sort match the shipped v7.1 rules', () {
    final common = jokerCatalog.firstWhere(
      (joker) => joker.rarity == JokerRarity.common && joker.unlock > 0,
    );
    final rare = jokerCatalog.firstWhere(
      (joker) => joker.rarity == JokerRarity.rare && joker.unlock > 0,
    );
    final owned = <String>{rare.id};

    final lockedOnly = filteredJokerCollection(
      jokers: <JokerDefinition>[rare, common],
      ownedIds: owned,
      filter: JokerCollectionFilter.locked,
    );
    expect(lockedOnly, <JokerDefinition>[common]);

    final statusFirst = filteredJokerCollection(
      jokers: <JokerDefinition>[common, rare],
      ownedIds: owned,
      sort: JokerCollectionSort.status,
    );
    expect(statusFirst.first.id, rare.id);

    final search = filteredJokerCollection(
      jokers: jokerCatalog,
      ownedIds: owned,
      search: rare.description,
    );
    expect(search.map((joker) => joker.id), contains(rare.id));

    expect(
      publicUnlockedJokerCount(<String>{rare.id, 'developer_test_joker'}),
      1,
      reason: 'legacy developer IDs must not produce 58 / 57',
    );
  });

  test('direct Joker unlock debits once and is durably owned', () async {
    final app = await AppController.bootstrap();
    addTearDown(app.dispose);
    final joker = jokerCatalog.firstWhere((candidate) => candidate.unlock > 0);
    final openingCoins = joker.collectionUnlockCost + 250;
    await app.mutateAccount((account) {
      account.coins = openingCoins;
      account.unlockedJokerIds.clear();
    }, syncCloud: false);

    expect(await app.unlockJoker(joker.id), isTrue);
    expect(app.account.unlockedJokerIds, contains(joker.id));
    expect(app.account.coins, openingCoins - joker.collectionUnlockCost);

    expect(await app.unlockJoker(joker.id), isFalse);
    expect(app.account.coins, openingCoins - joker.collectionUnlockCost);

    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString('wildcard_save_v1');
    expect(saved, isNotNull);
    expect(AccountState.decode(saved!).unlockedJokerIds, contains(joker.id));
  });

  testWidgets('collection search and unlock fit a 320x568 phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final target = jokerCatalog.firstWhere(
      (joker) => joker.name == 'Frequency Meter',
    );
    final account = AccountState(
      coins: target.collectionUnlockCost + 100,
      unlockedJokerIds: jokerCatalog
          .where((joker) => joker.starter)
          .map((joker) => joker.id)
          .toSet(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              JokerCollectionSection(
                account: account,
                onUnlock: (id) async {
                  final joker = jokerCatalog.firstWhere(
                    (candidate) => candidate.id == id,
                  );
                  if (account.coins < joker.collectionUnlockCost ||
                      !account.unlockedJokerIds.add(id)) {
                    return false;
                  }
                  account.coins -= joker.collectionUnlockCost;
                  return true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('collection-search')),
      'frequency meter',
    );
    await tester.pump();
    expect(find.byKey(Key('collection-joker-${target.id}')), findsOneWidget);
    expect(find.text('Showing 1 of 1 Jokers'), findsOneWidget);

    final unlock = find.byKey(Key('collection-unlock-${target.id}'));
    await tester.ensureVisible(unlock);
    await tester.pumpAndSettle();
    await tester.tap(unlock);
    await tester.pumpAndSettle();

    expect(account.unlockedJokerIds, contains(target.id));
    expect(find.text(target.description), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
