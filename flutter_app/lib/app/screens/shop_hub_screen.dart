import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../app/app_controller.dart';
import '../../core/app_constants.dart';
import '../../domain/progression_catalog.dart';
import '../../services/billing_service.dart';
import '../../ui/wildcard_ui.dart';
import 'page_frame.dart';

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
        subtitle: '${widget.controller.account.coins} account coins',
        room: WildcardRoom.shop,
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
        WildcardButton(
          label:
              'Watch Ad · +25 Coins (${widget.controller.rewardedViewsLeftToday} left)',
          icon: const Icon(Icons.smart_display_outlined),
          onPressed: !busy && widget.controller.rewardedViewsLeftToday > 0
              ? _rewardedCoins
              : null,
          variant: WildcardButtonVariant.ghost,
        ),
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

  Widget _productRow(String id, ProductDetails? product) {
    final isNoAds = id == 'remove_ads';
    final coins = AppConstants.playCoinGrants[id];
    final title = isNoAds ? 'Remove Ads' : '$coins Coins';
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: WildcardCard(
        accent: isNoAds ? WildcardCardAccent.violet : WildcardCardAccent.gold,
        child: Row(
          children: [
            Icon(isNoAds ? Icons.block_rounded : Icons.star_rounded),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(fontFamily: 'Bungee'),
                  ),
                  Text(product?.price ?? 'Unavailable'),
                ],
              ),
            ),
            FilledButton(
              onPressed: !busy && product != null && widget.controller.signedIn
                  ? () => _buy(id)
                  : null,
              child: const Text('BUY'),
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
        WildcardButton(
          label:
              'Watch Ad · +25 Coins (${widget.controller.rewardedViewsLeftToday} left)',
          icon: const Icon(Icons.smart_display_outlined),
          onPressed: !busy && widget.controller.rewardedViewsLeftToday > 0
              ? _rewardedCoins
              : null,
          variant: WildcardButtonVariant.ghost,
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
                  if (!owned)
                    Text(
                      '${cosmetic.price} coins',
                      style: TextStyle(
                        color: context.wildcard.gold,
                        fontWeight: FontWeight.w700,
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
          width: 46,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.wildcard.panelStrong,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.wildcard.violet),
          ),
          clipBehavior: Clip.antiAlias,
          child: SlySprite(
            skin: _slySkin(cosmetic.id),
            size: 46,
            borderRadius: 0,
          ),
        ),
        CosmeticKind.table => SizedBox(
          width: 46,
          child: TableFeltSurface(
            feltId: cosmetic.id,
            borderRadius: BorderRadius.circular(10),
            child: const SizedBox(
              height: 58,
              child: Icon(Icons.style_rounded, size: 20),
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
      width: 46,
      height: 58,
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

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

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
  _ => WildcardThemeId.classic,
};
