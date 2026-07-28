import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/joker_catalog.dart';
import 'package:wildcard/domain/progression_catalog.dart';
import 'package:wildcard/ui/widgets/royal_vault_animation.dart';
import 'package:wildcard/ui/widgets/royal_vault_chest_art.dart';
import 'package:wildcard/ui/widgets/sly_sprite.dart';
import 'package:wildcard/ui/wildcard_theme.dart';

const _captureKey = Key('royal-vault-golden-root');

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Bungee',
    )..addFont(rootBundle.load('assets/fonts/bungee-regular.ttf'))).load();
    await (FontLoader('SpaceGrotesk')
          ..addFont(rootBundle.load('assets/fonts/space-grotesk-400.ttf'))
          ..addFont(rootBundle.load('assets/fonts/space-grotesk-700.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  final common = _jokerReward('copper');
  final rare = _jokerReward('polish');
  final wild = _jokerReward('overclock');
  final sly = _cosmeticReward('sly_gold');
  final table = _cosmeticReward('felt_neon');
  final theme = _cosmeticReward('theme_neon_elite');

  final captures = <_VaultCapture>[
    _VaultCapture(
      name: 'wood-closed-320x568',
      size: const Size(320, 568),
      tier: RoyalVaultVisualTier.wooden,
      reward: common,
      progress: .04,
    ),
    _VaultCapture(
      name: 'wood-open-360x640',
      size: const Size(360, 640),
      tier: RoyalVaultVisualTier.wooden,
      reward: common,
      progress: .80,
    ),
    _VaultCapture(
      name: 'gold-opening-390x844',
      size: const Size(390, 844),
      tier: RoyalVaultVisualTier.golden,
      reward: rare,
      progress: .69,
    ),
    _VaultCapture(
      name: 'cosmetic-opening-393x873',
      size: const Size(393, 873),
      tier: RoyalVaultVisualTier.cosmetic,
      reward: sly,
      progress: .76,
    ),
    _VaultCapture(
      name: 'joker-common-reveal-360x800',
      size: const Size(360, 800),
      tier: RoyalVaultVisualTier.wooden,
      reward: common,
      progress: .92,
    ),
    _VaultCapture(
      name: 'joker-rare-reveal-390x844',
      size: const Size(390, 844),
      tier: RoyalVaultVisualTier.golden,
      reward: rare,
      progress: .92,
    ),
    _VaultCapture(
      name: 'joker-wild-reveal-412x915',
      size: const Size(412, 915),
      tier: RoyalVaultVisualTier.golden,
      reward: wild,
      progress: .92,
    ),
    _VaultCapture(
      name: 'sly-skin-reveal-393x873',
      size: const Size(393, 873),
      tier: RoyalVaultVisualTier.cosmetic,
      reward: sly,
      progress: .92,
    ),
    _VaultCapture(
      name: 'table-reveal-390x844',
      size: const Size(390, 844),
      tier: RoyalVaultVisualTier.cosmetic,
      reward: table,
      progress: .92,
    ),
    _VaultCapture(
      name: 'theme-reveal-412x915',
      size: const Size(412, 915),
      tier: RoyalVaultVisualTier.cosmetic,
      reward: theme,
      progress: .92,
    ),
  ];

  for (final capture in captures) {
    testWidgets('captures ${capture.name}', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = capture.size;
      addTearDown(() {
        tester.view
          ..resetDevicePixelRatio()
          ..resetPhysicalSize();
      });

      await _precacheVaultAssets(tester, capture.size);
      await tester.pumpWidget(
        _GoldenHarness(
          tier: capture.tier,
          reward: capture.reward,
          progress: capture.progress,
        ),
      );
      await tester.pumpAndSettle();
      // Asset decoding completes off the fake clock. Advancing one explicit
      // frame makes the first capture of each generated tier include every
      // WebP layer, rather than relying on a previous test warming the cache.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(_captureKey),
        matchesGoldenFile('goldens/royal_vault/${capture.name}.png'),
      );
    });
  }
}

class _VaultCapture {
  const _VaultCapture({
    required this.name,
    required this.size,
    required this.tier,
    required this.reward,
    required this.progress,
  });

  final String name;
  final Size size;
  final RoyalVaultVisualTier tier;
  final RoyalVaultRewardViewModel reward;
  final double progress;
}

class _GoldenHarness extends StatelessWidget {
  const _GoldenHarness({
    required this.tier,
    required this.reward,
    required this.progress,
  });

  final RoyalVaultVisualTier tier;
  final RoyalVaultRewardViewModel reward;
  final double progress;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: WildcardTheme.build(),
    home: RepaintBoundary(
      key: _captureKey,
      child: RoyalVaultAnimation(
        tier: tier,
        reward: reward,
        fast: false,
        progressOverride: progress,
        onClaim: () {},
      ),
    ),
  );
}

RoyalVaultRewardViewModel _jokerReward(String id) {
  final joker = jokersById[id]!;
  return RoyalVaultRewardViewModel(
    name: joker.name,
    description: joker.description,
    rarity: _rarityLabel(joker.rarity),
    rarityColor: _rarityColor(joker.rarity),
    categoryLabel: 'NEW JOKER UNLOCKED',
    artwork: RoyalVaultRewardArtwork.forJoker(joker),
  );
}

RoyalVaultRewardViewModel _cosmeticReward(String id) {
  final cosmetic = cosmeticById(id)!;
  return RoyalVaultRewardViewModel(
    name: cosmetic.name,
    description: cosmetic.description,
    rarity: _rarityLabel(cosmetic.rarity),
    rarityColor: _rarityColor(cosmetic.rarity),
    categoryLabel: 'NEW COSMETIC UNLOCKED',
    artwork: RoyalVaultRewardArtwork.forCosmetic(cosmetic),
  );
}

String _rarityLabel(JokerRarity rarity) => switch (rarity) {
  JokerRarity.common => 'COMMON',
  JokerRarity.uncommon => 'UNCOMMON',
  JokerRarity.rare => 'RARE',
  JokerRarity.wild => 'WILD',
};

Future<void> _precacheVaultAssets(WidgetTester tester, Size size) async {
  const contextKey = Key('royal-vault-precache-context');
  await tester.pumpWidget(
    MaterialApp(
      theme: WildcardTheme.build(),
      home: const SizedBox(key: contextKey),
    ),
  );
  final context = tester.element(find.byKey(contextKey));
  final providers = <ImageProvider<Object>>{
    ResizeImage.resizeIfNeeded(
      size.width.ceil(),
      null,
      const AssetImage(WildcardThemeTokens.vaultBackground),
    ),
    const AssetImage(WildcardThemeTokens.palaceBackground),
    ResizeImage.resizeIfNeeded(
      58 * 4,
      58 * 2,
      const AssetImage(slySkinSpriteAsset),
    ),
    for (final tier in RoyalVaultVisualTier.values) ...<ImageProvider<Object>>[
      AssetImage(RoyalVaultChestAssetSet.forTier(tier).body),
      AssetImage(RoyalVaultChestAssetSet.forTier(tier).lid),
      AssetImage(RoyalVaultChestAssetSet.forTier(tier).lock),
      AssetImage(RoyalVaultChestAssetSet.forTier(tier).crest),
    ],
  };
  await tester.runAsync(() async {
    for (final provider in providers) {
      await precacheImage(provider, context);
    }
  });
  await tester.pump();
}

Color _rarityColor(JokerRarity rarity) => switch (rarity) {
  JokerRarity.common => const Color(0xFFCFC6B2),
  JokerRarity.uncommon => const Color(0xFF45E0C6),
  JokerRarity.rare => const Color(0xFFFF8A3D),
  JokerRarity.wild => const Color(0xFFFF4FD8),
};
