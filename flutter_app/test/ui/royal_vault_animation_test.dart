import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/ui/widgets/royal_vault_animation.dart';
import 'package:wildcard/ui/wildcard_theme.dart';

void main() {
  const phoneSizes = <Size>[Size(320, 568), Size(360, 800)];

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
        expect(find.text('FREQUENCY METER'), findsOneWidget);
        expect(find.text('RARITY  UNCOMMON'), findsOneWidget);
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
    await tester.pump(const Duration(milliseconds: 2200));
    final fastButton = tester.widget<Widget>(
      find.byKey(const Key('royal-vault-claim')),
    );
    expect(fastButton, isNotNull);
    expect(find.text('REWARD SECURED'), findsOneWidget);

    await tester.pumpWidget(buildVault(fast: false, key: const Key('normal')));
    await tester.pump(const Duration(milliseconds: 2200));
    expect(find.text('REWARD SECURED'), findsNothing);
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

Future<void> _setPhoneSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}
