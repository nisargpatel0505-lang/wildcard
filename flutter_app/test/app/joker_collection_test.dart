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

  test('collection filter and sort remain usable without direct prices', () {
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
      reason: 'legacy developer IDs must not inflate active collection totals',
    );
  });

  test(
    'fresh accounts contain the starter discoveries and no paid unlock',
    () async {
      final app = await AppController.bootstrap();
      addTearDown(app.dispose);
      final joker = jokerCatalog.firstWhere(
        (candidate) => candidate.unlock > 0,
      );
      expect(app.account.unlockedJokerIds, starterJokerIds.toSet());
      expect(app.account.unlockedJokerIds, isNot(contains(joker.id)));
      expect(app.account.coins, 0);
    },
  );

  testWidgets('locked collection details and Vault direction fit 320x568', (
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
      coins: 100000,
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
            children: [JokerCollectionSection(account: account)],
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

    final discover = find.byKey(Key('collection-discover-${target.id}'));
    await tester.ensureVisible(discover);
    await tester.pumpAndSettle();
    expect(find.text(target.description), findsOneWidget);
    expect(find.text('Discover through Joker Vaults'), findsOneWidget);
    expect(find.byKey(Key('collection-unlock-${target.id}')), findsNothing);
    await tester.tap(find.byKey(Key('collection-joker-${target.id}')));
    await tester.pumpAndSettle();

    expect(account.unlockedJokerIds, isNot(contains(target.id)));
    expect(find.text('LOCKED · DISCOVER THROUGH JOKER VAULTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
