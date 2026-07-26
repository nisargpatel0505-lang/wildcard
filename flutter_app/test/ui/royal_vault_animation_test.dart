import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/ui/widgets/royal_vault_animation.dart';
import 'package:wildcard/ui/wildcard_theme.dart';

void main() {
  const phoneSizes = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(360, 800),
    Size(393, 873),
    Size(412, 915),
    Size(600, 960),
    Size(800, 1280),
  ];

  for (final size in phoneSizes) {
    testWidgets(
      'Royal Vault reveal fits ${size.width.toInt()}x${size.height.toInt()} and claims once',
      (tester) async {
        await _setPhoneSize(tester, size);
        var claimCount = 0;

        await tester.pumpWidget(
          _Harness(
            child: RoyalVaultAnimation(
              tier: size.width == 320
                  ? RoyalVaultVisualTier.golden
                  : RoyalVaultVisualTier.cosmetic,
              reward: const RoyalVaultRewardViewModel(
                name: 'Frequency Meter',
                description:
                    '×1.4 Multiplier if your deck has one most common rank and you play it.',
                rarity: 'UNCOMMON',
                rarityColor: Color(0xFF45E0C6),
                categoryLabel: 'NEW JOKER UNLOCKED',
                icon: Icons.style_rounded,
              ),
              fast: false,
              durationOverride: const Duration(milliseconds: 120),
              onClaim: () => claimCount++,
            ),
          ),
        );

        final openingButton = tester.widget<RoyalVaultAnimation>(
          find.byType(RoyalVaultAnimation),
        );
        expect(openingButton.fast, isFalse);
        expect(find.byKey(const Key('royal-vault-dialog')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpAndSettle();

        expect(find.text('REWARD SECURED'), findsOneWidget);
        expect(
          find.byKey(const Key('royal-vault-reward-name')),
          findsOneWidget,
        );
        expect(find.text('UNCOMMON'), findsWidgets);
        expect(find.byKey(const Key('royal-vault-claim')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('royal-vault-claim')));
        await tester.tap(find.byKey(const Key('royal-vault-claim')));
        await tester.pump();
        expect(claimCount, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Fast reveal completes while Normal remains in progress', (
    tester,
  ) async {
    await _setPhoneSize(tester, const Size(360, 800));

    Widget buildVault({required bool fast, required Key key}) => _Harness(
      child: RoyalVaultAnimation(
        key: key,
        tier: RoyalVaultVisualTier.wooden,
        reward: const RoyalVaultRewardViewModel(
          name: 'Copper',
          description: '+12 value when a scoring card is a Diamond.',
          rarity: 'COMMON',
          rarityColor: Color(0xFFCFC6B2),
          categoryLabel: 'NEW JOKER UNLOCKED',
          icon: Icons.style_rounded,
        ),
        fast: fast,
        onClaim: () {},
      ),
    );

    await tester.pumpWidget(buildVault(fast: true, key: const Key('fast')));
    await tester.pump(const Duration(milliseconds: 2800));
    final fastButton = tester.widget<Widget>(
      find.byKey(const Key('royal-vault-claim')),
    );
    expect(fastButton, isNotNull);
    expect(find.text('REWARD SECURED'), findsOneWidget);

    await tester.pumpWidget(buildVault(fast: false, key: const Key('normal')));
    await tester.pump(const Duration(milliseconds: 2800));
    expect(find.text('REWARD SECURED'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward remains readable at 1.3 text scale and reduced motion', (
    tester,
  ) async {
    await _setPhoneSize(tester, const Size(360, 640));
    await tester.pumpWidget(
      _Harness(
        textScale: 1.3,
        disableAnimations: true,
        child: RoyalVaultAnimation(
          tier: RoyalVaultVisualTier.golden,
          reward: const RoyalVaultRewardViewModel(
            name: 'Frequency Meter',
            description:
                '×1.4 Multiplier if your deck has one most common rank and you play it.',
            rarity: 'RARE',
            rarityColor: Color(0xFF9B7BFF),
            categoryLabel: 'NEW JOKER UNLOCKED',
            icon: Icons.style_rounded,
          ),
          fast: false,
          durationOverride: const Duration(milliseconds: 120),
          onClaim: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('royal-vault-claim')), findsOneWidget);
    expect(
      find.byKey(const Key('royal-vault-reward-description')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'neutral scan does not reveal rarity, reward, or Claim semantics early',
    (tester) async {
      await _setPhoneSize(tester, const Size(360, 800));
      await tester.pumpWidget(
        _Harness(
          child: RoyalVaultAnimation(
            tier: RoyalVaultVisualTier.golden,
            reward: const RoyalVaultRewardViewModel(
              name: 'Frequency Meter',
              description: 'A deliberately secret effect.',
              rarity: 'WILD',
              rarityColor: Color(0xFFF04FD8),
              categoryLabel: 'NEW JOKER UNLOCKED',
              icon: Icons.style_rounded,
            ),
            fast: false,
            durationOverride: const Duration(milliseconds: 1000),
            onClaim: () {},
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('SEARCHING'), findsOneWidget);
      expect(find.text('WILD'), findsNothing);
      expect(find.textContaining('Frequency Meter'), findsNothing);
      expect(find.byKey(const Key('royal-vault-reward-name')), findsNothing);
      expect(find.byKey(const Key('royal-vault-claim')), findsNothing);
      expect(
        find.byKey(const Key('royal-vault-claim-placeholder')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('royal-vault-reward-token')), findsOneWidget);
      expect(find.text('SEALED PRIZE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reward clears the rim as a large card before Claim appears', (
    tester,
  ) async {
    await _setPhoneSize(tester, const Size(393, 873));
    await tester.pumpWidget(
      _Harness(
        child: RoyalVaultAnimation(
          tier: RoyalVaultVisualTier.cosmetic,
          reward: const RoyalVaultRewardViewModel(
            name: 'Velvet Sly',
            description: 'A premium Sly look for every room.',
            rarity: 'RARE',
            rarityColor: Color(0xFF9B7BFF),
            categoryLabel: 'NEW COSMETIC UNLOCKED',
            icon: Icons.face_rounded,
          ),
          fast: false,
          durationOverride: const Duration(milliseconds: 1000),
          onClaim: () {},
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 900));

    final token = find.byKey(const Key('royal-vault-reward-token'));
    expect(token, findsOneWidget);
    expect(tester.getSize(token).width, greaterThanOrEqualTo(185));
    expect(find.text('RARE'), findsWidgets);
    expect(find.text('VELVET SLY'), findsWidgets);
    expect(find.byKey(const Key('royal-vault-claim')), findsNothing);
    expect(find.byKey(const Key('royal-vault-rear-hinge')), findsOneWidget);

    final stage = tester.getRect(find.byKey(const Key('royal-vault-dialog')));
    expect(stage.contains(tester.getCenter(token)), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion uses the short safe ceremony', (tester) async {
    await _setPhoneSize(tester, const Size(360, 640));
    await tester.pumpWidget(
      _Harness(
        disableAnimations: true,
        child: RoyalVaultAnimation(
          tier: RoyalVaultVisualTier.wooden,
          reward: const RoyalVaultRewardViewModel(
            name: 'Copper',
            description: '+12 value when a scoring card is a Diamond.',
            rarity: 'COMMON',
            rarityColor: Color(0xFFCFC6B2),
            categoryLabel: 'NEW JOKER UNLOCKED',
            icon: Icons.style_rounded,
          ),
          fast: false,
          onClaim: () {},
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 760));

    expect(find.byKey(const Key('royal-vault-claim')), findsOneWidget);
    expect(find.text('REWARD SECURED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Harness extends StatelessWidget {
  const _Harness({
    required this.child,
    this.textScale = 1,
    this.disableAnimations = false,
  });

  final Widget child;
  final double textScale;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: WildcardTheme.build(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child,
      ),
    ),
  );
}

Future<void> _setPhoneSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}
