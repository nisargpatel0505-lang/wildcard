import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../app/app_controller.dart';
import '../../core/app_constants.dart';
import '../../domain/progression_catalog.dart';
import '../../services/billing_service.dart';
import '../../ui/wildcard_ui.dart';
import 'page_frame.dart';
import '../../ui/widgets/wildcard_toast.dart';

class ShopHubScreen extends StatefulWidget {
  const ShopHubScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<ShopHubScreen> createState() => _ShopHubScreenState();
}

class _ShopHubScreenState extends State<ShopHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => WildcardPageFrame(
        title: 'Shop',
        subtitle: 'Coins, table style and Sly looks.',
        room: WildcardRoom.shop,
        surface: WildcardUiSurface.accountShop,
        actions: [
          RunCoinBadge(
            coins: widget.controller.account.coins,
            account: true,
            compact: true,
          ),
        ],
        child: Column(
          children: [
            TabBar(
              controller: tabs,
              tabs: const [
                Tab(text: 'COIN STORE'),
                Tab(text: 'WARDROBE'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: tabs,
                children: [_coinStore(), _wardrobe()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coinStore() {
    final billing = widget.controller.billing;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        _accountWalletCard(),
        const SizedBox(height: 10),
        _rewardCoinsButton(),
        if (kDebugMode) ...[
          const SizedBox(height: 10),
          const WildcardCard(
            accent: WildcardCardAccent.gold,
            child: Text(
              'TEST BUILD\nDemo ads are expected in this sideloaded APK. Google Play products become available when the app is installed from the Internal Testing track.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, height: 1.3),
            ),
          ),
        ],
        const ScreenSectionTitle('Google Play products'),
        if (!widget.controller.signedIn)
          const WildcardCard(
            accent: WildcardCardAccent.gold,
            child: Text(
              'Sign in with Google in Settings before buying. Guest play stays free.',
            ),
          ),
        if (billing.state == BillingState.loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: CircularProgressIndicator(),
            ),
          ),
        for (final id in AppConstants.playCoinGrants.keys)
          _productRow(id, billing.products[id]),
        _productRow('remove_ads', billing.products['remove_ads']),
        if (billing.notFoundProductIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Unavailable in this Play track: ${billing.notFoundProductIds.join(', ')}',
              style: TextStyle(color: context.wildcard.coral, fontSize: 12),
            ),
          ),
        const SizedBox(height: 12),
        WildcardButton(
          label: 'Restore Purchases',
          onPressed: !busy && widget.controller.signedIn
              ? _restorePurchases
              : null,
          variant: WildcardButtonVariant.ghost,
        ),
      ],
    );
  }

  Widget _accountWalletCard() {
    final coins = widget.controller.account.coins;
    return WildcardCard(
      accent: WildcardCardAccent.gold,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      child: Row(
        children: [
          const WildcardCoinIcon(size: 48),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACCOUNT WALLET',
                  style: TextStyle(
                    color: context.wildcard.gold,
                    fontFamily: 'Bungee',
                    fontSize: 12,
                    letterSpacing: .35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Permanent coins for Vaults, cosmetics and run boosts.',
                  style: TextStyle(
                    color: context.wildcard.creamDim,
                    fontSize: 11.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          RunCoinBadge(coins: coins, account: true),
        ],
      ),
    );
  }

  Widget _rewardCoinsButton() {
    final left = widget.controller.rewardedViewsLeftToday;
    return WildcardButton(
      key: const Key('shop-reward-coins'),
      label: 'Watch Ad · +25 Coins ($left left today)',
      icon: const Icon(Icons.smart_display_outlined),
      onPressed: !busy && left > 0 ? _rewardedCoins : null,
      variant: WildcardButtonVariant.ghost,
    );
  }

  Widget _productRow(String id, ProductDetails? product) {
    final isNoAds = id == 'remove_ads';
    final coins = AppConstants.playCoinGrants[id];
    final ownedNoAds = isNoAds && widget.controller.account.noAds;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: WildcardCard(
        accent: isNoAds ? WildcardCardAccent.violet : WildcardCardAccent.gold,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isNoAds
                    ? context.wildcard.violet.withValues(alpha: .18)
                    : context.wildcard.gold.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: isNoAds
                      ? context.wildcard.violet
                      : context.wildcard.gold.withValues(alpha: .62),
                ),
              ),
              child: isNoAds
                  ? Icon(
                      Icons.block_rounded,
                      color: context.wildcard.violet,
                      size: 31,
                    )
                  : const WildcardCoinIcon(size: 38),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isNoAds)
                    Text(
                      ownedNoAds ? 'FORCED ADS REMOVED' : 'REMOVE FORCED ADS',
                      style: TextStyle(
                        color: context.wildcard.violet,
                        fontFamily: 'Bungee',
                        fontSize: 12,
                      ),
                    )
                  else
                    CoinPrice(coins!, label: 'ACCOUNT', compact: true),
                  const SizedBox(height: 3),
                  Text(
                    isNoAds
                        ? 'Stops forced interstitials. Optional rewarded ads remain available.'
                        : 'Delivered to your permanent account wallet.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.wildcard.creamDim,
                      fontSize: 10.5,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ownedNoAds ? 'Owned' : (product?.price ?? 'Unavailable'),
                    style: TextStyle(
                      color: ownedNoAds
                          ? context.wildcard.mint
                          : context.wildcard.cream,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed:
                  !busy &&
                      !ownedNoAds &&
                      product != null &&
                      widget.controller.signedIn
                  ? () => _buy(id)
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(68, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(ownedNoAds ? 'OWNED' : 'BUY'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wardrobe() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        WildcardCard(
          accent: WildcardCardAccent.violet,
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: context.wildcard.violet,
                size: 30,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MAKE THE TABLE YOURS',
                      style: TextStyle(
                        color: context.wildcard.gold,
                        fontFamily: 'Bungee',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Buy once, then switch your felts, themes and Sly looks whenever you like.',
                      style: TextStyle(
                        color: context.wildcard.creamDim,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final kind in CosmeticKind.values) ...[
          ScreenSectionTitle(switch (kind) {
            CosmeticKind.table => 'Table felts',
            CosmeticKind.theme => 'UI themes',
            CosmeticKind.sly => 'Sly looks',
          }),
          for (final cosmetic in cosmeticCatalog.where(
            (item) => item.kind == kind,
          ))
            _cosmeticRow(cosmetic),
        ],
      ],
    );
  }

  Widget _cosmeticRow(CosmeticDefinition cosmetic) {
    final account = widget.controller.account;
    final owned =
        cosmetic.isDefault || account.cosmeticsOwned.contains(cosmetic.id);
    final equipped = switch (cosmetic.kind) {
      CosmeticKind.table => account.equipped.table == cosmetic.id,
      CosmeticKind.theme => account.equipped.theme == cosmetic.id,
      CosmeticKind.sly => account.equipped.sly == cosmetic.id,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: WildcardCard(
        selected: equipped,
        accent: WildcardCardAccent.violet,
        child: Row(
          children: [
            _swatch(cosmetic),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cosmetic.name.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Bungee',
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cosmetic.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  const SizedBox(height: 4),
                  if (!owned)
                    CoinPrice(cosmetic.price, label: 'ACCOUNT', compact: true)
                  else
                    Text(
                      equipped ? 'EQUIPPED' : 'OWNED',
                      style: TextStyle(
                        color: equipped
                            ? context.wildcard.mint
                            : context.wildcard.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: .4,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: busy || equipped
                  ? null
                  : () =>
                        owned ? _equip(cosmetic.id) : _buyCosmetic(cosmetic.id),
              style: FilledButton.styleFrom(
                minimumSize: const Size(72, 48),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(equipped ? 'ON' : (owned ? 'EQUIP' : 'BUY')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(CosmeticDefinition cosmetic) {
    return ExcludeSemantics(
      key: ValueKey('cosmetic-preview-${cosmetic.id}'),
      child: switch (cosmetic.kind) {
        CosmeticKind.sly => Container(
          width: 58,
          height: 70,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.wildcard.panelStrong,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.wildcard.violet),
          ),
          clipBehavior: Clip.antiAlias,
          child: SlySprite(
            skin: _slySkin(cosmetic.id),
            size: 58,
            borderRadius: 0,
            animate: false,
          ),
        ),
        CosmeticKind.table => SizedBox(
          width: 58,
          child: TableFeltSurface(
            feltId: cosmetic.id,
            borderRadius: BorderRadius.circular(10),
            child: const SizedBox(
              height: 70,
              child: Icon(Icons.style_rounded, size: 23),
            ),
          ),
        ),
        CosmeticKind.theme => _themeSwatch(cosmetic.id),
      },
    );
  }

  Widget _themeSwatch(String id) {
    final preview = WildcardThemeTokens.forId(_themeId(id));
    return Container(
      width: 58,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: preview.gold, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(preview.homeBackgroundAsset, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [preview.artTintTop, preview.artTintBottom],
              ),
            ),
          ),
          Icon(Icons.palette_outlined, color: preview.mint, size: 20),
        ],
      ),
    );
  }

  Future<void> _buy(String id) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.controller.billing.buy(id);
    } catch (error) {
      if (mounted) _snack(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _buyCosmetic(String id) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final ok = await widget.controller.buyCosmetic(id);
      if (mounted && !ok) _snack('Not enough coins.');
    } catch (_) {
      if (mounted) _snack('The cosmetic could not be purchased. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _equip(String id) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.controller.equipCosmetic(id);
    } catch (_) {
      if (mounted) _snack('That cosmetic could not be equipped. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _rewardedCoins() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final ok = await widget.controller.claimRewardedCoins();
      if (mounted) {
        _snack(ok ? '+25 coins added.' : 'Rewarded ad unavailable.');
      }
    } catch (_) {
      if (mounted) _snack('Rewarded ad unavailable. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restorePurchases() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.controller.billing.restorePurchases();
      await widget.controller.restorePlayEntitlements();
      if (mounted) _snack('Purchases restored.');
    } catch (_) {
      if (mounted) _snack('Purchases could not be restored. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _snack(String message) => showWildcardToast(context, message);

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }
}

SlySkin _slySkin(String id) => switch (id) {
  'sly_gold' => SlySkin.gold,
  'sly_shadow' => SlySkin.shadow,
  'sly_robot' => SlySkin.robot,
  'sly_king' => SlySkin.king,
  'sly_alien' => SlySkin.alien,
  'sly_devil' => SlySkin.devil,
  'sly_clown' => SlySkin.clown,
  'sly_block_drop' => SlySkin.blockDrop,
  'sly_abyssal' => SlySkin.abyssal,
  'sly_desert' => SlySkin.desertMirage,
  _ => SlySkin.classic,
};

WildcardThemeId _themeId(String id) => switch (id) {
  'theme_sunset' => WildcardThemeId.sunset,
  'theme_ice' => WildcardThemeId.ice,
  'theme_neon_elite' => WildcardThemeId.neonElite,
  'theme_gold' => WildcardThemeId.midas,
  'theme_vapor' => WildcardThemeId.vaporwave,
  'theme_blood' => WildcardThemeId.bloodMoon,
  'theme_cosmic' => WildcardThemeId.cosmicWilds,
  'theme_neon_heist' => WildcardThemeId.neonHeist,
  'theme_moonlit_mask' => WildcardThemeId.moonlitMasquerade,
  'theme_ember' => WildcardThemeId.emberCasino,
  'theme_emerald_throne' => WildcardThemeId.emeraldThrone,
  'theme_haunted' => WildcardThemeId.hauntedCarnival,
  'theme_clockwork' => WildcardThemeId.clockworkRoyale,
  'theme_block_drop' => WildcardThemeId.blockDropArcade,
  'theme_abyssal' => WildcardThemeId.abyssalJackpot,
  'theme_desert_mirage' => WildcardThemeId.desertMirage,
  _ => WildcardThemeId.classic,
};
