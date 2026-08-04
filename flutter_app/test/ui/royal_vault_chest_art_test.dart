import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/progression_catalog.dart';
import 'package:wildcard/ui/widgets/royal_vault_animation.dart'
    show RoyalVaultChestEmblem;
import 'package:wildcard/ui/widgets/royal_vault_chest_art.dart';
import 'package:wildcard/ui/widgets/royal_vault_reward_art.dart';

void main() {
  test('each Vault tier resolves four distinct generated runtime layers', () {
    final allPaths = <String>{};
    for (final tier in RoyalVaultVisualTier.values) {
      final assets = RoyalVaultChestAssetSet.forTier(tier);
      final paths = <String>{
        assets.body,
        assets.lid,
        assets.lock,
        assets.crest,
      };
      expect(paths, hasLength(4));
      expect(
        paths.every((path) => path.startsWith('assets/art/chests/')),
        true,
      );
      allPaths.addAll(paths);
    }
    expect(allPaths, hasLength(12));
  });

  testWidgets(
    'runtime bundle includes layers and excludes high-resolution masters',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final bundled = manifest.listAssets();
      final expected = <String>{
        'assets/art/chests/wildcard-sly-vault-room.webp',
        for (final tier in RoyalVaultVisualTier.values) ...<String>[
          RoyalVaultChestAssetSet.forTier(tier).body,
          RoyalVaultChestAssetSet.forTier(tier).lid,
          RoyalVaultChestAssetSet.forTier(tier).lock,
          RoyalVaultChestAssetSet.forTier(tier).crest,
        ],
      };

      expect(bundled, containsAll(expected));
      expect(
        bundled.where((path) => path.startsWith('assets/art/masters/')),
        isEmpty,
      );
    },
  );

  test('every public Vault reward has an exact production artwork mapping', () {
    final jokerArtwork = [
      for (final joker in jokerCatalog) RoyalVaultRewardArtwork.forJoker(joker),
    ];
    final cosmeticArtwork = [
      for (final cosmetic in cosmeticCatalog)
        RoyalVaultRewardArtwork.forCosmetic(cosmetic),
    ];

    expect(jokerArtwork, hasLength(jokerCatalog.length));
    expect(cosmeticArtwork, hasLength(cosmeticCatalog.length));
    expect({
      ...jokerArtwork.map((art) => art.catalogId),
    }, hasLength(jokerCatalog.length));
    expect({
      ...cosmeticArtwork.map((art) => art.catalogId),
    }, hasLength(cosmeticCatalog.length));
  });

  for (final tier in RoyalVaultVisualTier.values) {
    testWidgets('${tier.name} generated chest emblem loads at phone size', (
      tester,
    ) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(320, 568);
      addTearDown(() {
        tester.view
          ..resetDevicePixelRatio()
          ..resetPhysicalSize();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: RoyalVaultChestEmblem(tier: tier, width: 180)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }
}
