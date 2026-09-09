import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../app/app_controller.dart';
import '../../core/app_constants.dart';
import '../../domain/progression_catalog.dart';
import '../../domain/astra_progression.dart';
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
  CosmeticKind wardrobeKind = CosmeticKind.theme;

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
            ColoredBox(
              key: const ValueKey('shop-tabs-backing'),
              color: context.wildcard.liveBackdrop != WildcardLiveBackdrop.none
                  ? context.wildcard.panelStrong.withValues(alpha: .94)
                  : Colors.transparent,
              child: TabBar(
                controller: tabs,
                tabs: const [
                  Tab(text: astraEnabled ? 'EARN COINS' : 'COIN STORE'),
                  Tab(text: 'WARDROBE'),
                ],
              ),
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
    if (astraEnabled) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _accountWalletCard(),
          const SizedBox(height: 12),
          const WildcardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenSectionTitle('Play. Build. Discover.'),
                Text(
                  'Clear Heats to earn coins, claim Journey goals from Home, and open Vaults to grow your collection.\n\nYour first Wood Vaults cost 60 coins until you own 15 Jokers, then 100. Gold Vaults cost 300.\n\nAstra has no ads or real-money purchases. Everything here is earned by playing.',
                  style: TextStyle(fontSize: 15, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      );
    }
    final billing = widget.controller.billing;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        _accountWalletCard(),
        const SizedBox(height: 10),
        _rewardCoinsButton(),
        const SizedBox(height: 10),
        const WildcardCard(
          accent: WildcardCardAccent.mint,
          child: Text(
            'Play to discover: every Normal run includes a free starter Joker. '
            'Clear Heats and claim Journey milestones to open Vaults. '
            'Wood costs 60 coins until you own 15 Jokers, then 100. Gold costs 300.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        if (kDebugMode && widget.controller.ads.adsEnabled) ...[
          const SizedBox(height: 10),
          const WildcardCard(
            accent: WildcardCardAccent.gold,
            child: Text(
              'TEST BUILD\nDemo ads are enabled. Test purchases require configured Google Play products and a license-testing account.',
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
        for (final id in AppConstants.storefrontCoinProductIds)
          _productRow(id, billing.products[id]),
        _productRow('remove_ads', billing.products['remove_ads']),
        if (billing.notFoundProductIds.any(
          (id) =>
              AppConstants.storefrontCoinProductIds.contains(id) ||
              id == 'remove_ads',
        ))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Some purchases are unavailable right now. Try reopening the shop after connecting to Google Play.',
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
                  'Permanent coins for Vaults and cosmetics.',
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
    if (!widget.controller.ads.adsEnabled) return const SizedBox.shrink();
    final left = widget.controller.rewardedViewsLeftToday;
    return WildcardButton(
      key: const Key('shop-reward-coins'),
      label: widget.controller.instantRewardBonuses
          ? 'Claim +25 Coins · Ad-free ($left left today)'
          : 'Watch Ad · +25 Coins ($left left today)',
      icon: Icon(
        widget.controller.instantRewardBonuses
            ? Icons.card_giftcard_rounded
            : Icons.smart_display_outlined,
      ),
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
                        ? 'No between-run ads. Optional bonuses are instant and ad-free; the shared 5-per-day limit still applies.'
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
                      'Try four free live rooms, or browse your tables and Sly looks.',
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
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final kind in [
              CosmeticKind.theme,
              CosmeticKind.table,
              CosmeticKind.sly,
            ])
              ChoiceChip(
                label: Text(switch (kind) {
                  CosmeticKind.theme => 'Themes',
                  CosmeticKind.table => 'Tables',
                  CosmeticKind.sly => 'Sly',
                }),
                selected: wardrobeKind == kind,
                labelStyle: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.wildcard.cream,
                ),
                onSelected: (_) => setState(() => wardrobeKind = kind),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
          ],
        ),
        if (wardrobeKind == CosmeticKind.theme) ...[
          const ScreenSectionTitle('Live theme studio · free previews'),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final cosmetic in cosmeticCatalog.where(
                  (c) => previewThemeIds.contains(c.id),
                ))
                  SizedBox(
                    width: (constraints.maxWidth - 10) / 2,
                    child: _liveThemeCard(cosmetic),
                  ),
              ],
            ),
          ),
          const ScreenSectionTitle('Your other themes'),
        ],
        for (final cosmetic in cosmeticCatalog.where(
          (item) =>
              item.kind == wardrobeKind && !previewThemeIds.contains(item.id),
        ))
          _cosmeticRow(cosmetic),
      ],
    );
  }

  Widget _liveThemeCard(CosmeticDefinition cosmetic) {
    final palette = WildcardThemeTokens.forId(
      resolveWildcardThemeId(cosmetic.id),
    );
    final equipped = widget.controller.account.equipped.theme == cosmetic.id;
    return Container(
      key: ValueKey('studio-${cosmetic.id}'),
      decoration: BoxDecoration(
        color: palette.surfaceStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: equipped ? palette.mint : palette.gold.withValues(alpha: .5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset(
            palette.homeBackgroundAsset,
            height: 88,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            cacheWidth: 400,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 0),
            child: Text(
              cosmetic.name,
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: palette.cream,
                height: 1.15,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
            child: TextButton(
              key: ValueKey('equip-${cosmetic.id}'),
              onPressed: busy || equipped ? null : () => _equip(cosmetic.id),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: palette.mint,
                disabledForegroundColor: palette.cream,
              ),
              child: Text(
                equipped ? 'EQUIPPED' : 'TRY THEME',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
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
            skin: resolveSlySkin(cosmetic.id),
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
    final preview = WildcardThemeTokens.forId(resolveWildcardThemeId(id));
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
