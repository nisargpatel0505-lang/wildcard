import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/account_state.dart';
import '../../domain/economy.dart';
import '../../domain/joker_catalog.dart';
import '../../domain/progression_catalog.dart';
import '../../ui/wildcard_ui.dart';
import '../../ui/widgets/royal_vault_animation.dart';
import 'joker_collection_section.dart';
import 'page_frame.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  bool _actionInFlight = false;
  _VaultSection _section = _VaultSection.collection;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final account = widget.controller.account;
        final publicUnlocked = publicUnlockedJokerCount(
          account.unlockedJokerIds,
        );
        return WildcardPageFrame(
          title: 'Joker Unlocks',
          subtitle: '$publicUnlocked / ${jokerCatalog.length} Jokers unlocked',
          room: WildcardRoom.vault,
          actions: [_coinBadge(account.coins)],
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _sectionButton(
                        section: _VaultSection.collection,
                        label: 'Collection',
                        icon: Icons.style_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _sectionButton(
                        section: _VaultSection.vaults,
                        label: 'Royal Vault',
                        icon: Icons.inventory_2_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  key: PageStorageKey<String>('joker-${_section.name}'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
                  children: _section == _VaultSection.collection
                      ? <Widget>[
                          JokerCollectionSection(
                            account: account,
                            onUnlock: widget.controller.unlockJoker,
                          ),
                        ]
                      : <Widget>[
                          _vaultCard(JokerChestTier.wood),
                          const SizedBox(height: 10),
                          _vaultCard(JokerChestTier.gold),
                          const SizedBox(height: 10),
                          _cosmeticVaultCard(),
                          const SizedBox(height: 10),
                          WildcardButton(
                            label:
                                'Watch Ad · +25 Coins (${widget.controller.rewardedViewsLeftToday} left)',
                            icon: const Icon(Icons.smart_display_outlined),
                            onPressed:
                                !_actionInFlight &&
                                    widget.controller.rewardedViewsLeftToday > 0
                                ? _rewardedCoins
                                : null,
                            variant: WildcardButtonVariant.ghost,
                          ),
                        ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionButton({
    required _VaultSection section,
    required String label,
    required IconData icon,
  }) {
    final selected = section == _section;
    return SizedBox(
      height: 48,
      child: FilledButton.tonalIcon(
        key: Key('joker-section-${section.name}'),
        onPressed: () => setState(() => _section = section),
        icon: Icon(icon, size: 18),
        label: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Bungee', fontSize: 10),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: selected
              ? context.wildcard.violet.withValues(alpha: .55)
              : context.wildcard.panelStrong.withValues(alpha: .9),
          foregroundColor: selected
              ? context.wildcard.cream
              : context.wildcard.creamDim,
          side: BorderSide(
            color: selected ? context.wildcard.violet : context.wildcard.line,
            width: selected ? 2 : 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9),
        ),
      ),
    );
  }

  Widget _vaultCard(JokerChestTier tier) {
    final chest = jokerChests[tier]!;
    final account = widget.controller.account;
    final locked = jokerCatalog
        .where((joker) => !account.unlockedJokerIds.contains(joker.id))
        .toList();
    final odds = chest.effectiveOdds(locked);
    final price = chest.price(
      publicUnlockedJokerCount(account.unlockedJokerIds),
    );
    final label = tier == JokerChestTier.wood
        ? 'WOODEN JOKER VAULT'
        : 'GOLDEN JOKER VAULT';
    final available = odds.isNotEmpty;
    return WildcardCard(
      accent: tier == JokerChestTier.wood
          ? WildcardCardAccent.mint
          : WildcardCardAccent.gold,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          RoyalVaultChestEmblem(
            tier: tier == JokerChestTier.wood
                ? RoyalVaultVisualTier.wooden
                : RoyalVaultVisualTier.golden,
          ),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.wildcard.gold,
              fontFamily: 'Bungee',
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            available
                ? odds.entries
                      .map(
                        (entry) =>
                            '${_rarityName(entry.key)} ${(entry.value * 100).toStringAsFixed(entry.value < .01 ? 1 : 0)}%',
                      )
                      .join(' · ')
                : 'All eligible Jokers owned',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.wildcard.creamDim, fontSize: 12),
          ),
          const SizedBox(height: 12),
          WildcardButton(
            label: available ? 'Open · $price Coins' : 'Complete',
            onPressed: !_actionInFlight && available && account.coins >= price
                ? () => _openJokerVault(tier)
                : null,
            variant: tier == JokerChestTier.gold
                ? WildcardButtonVariant.primary
                : WildcardButtonVariant.secondary,
          ),
        ],
      ),
    );
  }

  Widget _cosmeticVaultCard() {
    final account = widget.controller.account;
    final left = cosmeticCatalog
        .where(
          (item) =>
              !item.isDefault && !account.cosmeticsOwned.contains(item.id),
        )
        .length;
    return WildcardCard(
      accent: WildcardCardAccent.violet,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          const RoyalVaultChestEmblem(tier: RoyalVaultVisualTier.cosmetic),
          const SizedBox(height: 7),
          Text(
            'COSMETIC VAULT',
            style: TextStyle(
              color: context.wildcard.gold,
              fontFamily: 'Bungee',
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            left == 0
                ? 'Every cosmetic is owned'
                : '$left rewards remain · UI theme chance 0.8% while both pools remain',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.wildcard.creamDim, fontSize: 12),
          ),
          const SizedBox(height: 12),
          WildcardButton(
            label: left == 0 ? 'Complete' : 'Open · $cosmeticVaultPrice Coins',
            onPressed:
                !_actionInFlight &&
                    left > 0 &&
                    account.coins >= cosmeticVaultPrice
                ? _openCosmeticVault
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _openJokerVault(JokerChestTier tier) async {
    if (_actionInFlight) return;
    setState(() => _actionInFlight = true);
    try {
      // The controller persists both the spend and unlock before returning.
      final reward = await widget.controller.openJokerVault(tier);
      if (!mounted) return;
      if (reward == null) {
        _message('This Vault is not available right now.');
        return;
      }
      await showRoyalVaultAnimation(
        context: context,
        tier: tier == JokerChestTier.wood
            ? RoyalVaultVisualTier.wooden
            : RoyalVaultVisualTier.golden,
        reward: RoyalVaultRewardViewModel(
          name: reward.name,
          description: reward.description,
          rarity: _rarityName(reward.rarity).toUpperCase(),
          rarityColor: _rarityColor(context, reward.rarity),
          categoryLabel: 'NEW JOKER UNLOCKED',
          icon: Icons.style_rounded,
        ),
        fast: widget.controller.account.speed == ScoringPace.fast,
      );
    } catch (_) {
      if (mounted) {
        _message('The Vault could not open. Your save remains safe.');
      }
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _openCosmeticVault() async {
    if (_actionInFlight) return;
    setState(() => _actionInFlight = true);
    try {
      // Ownership is durable before the first frame of the reveal.
      final reward = await widget.controller.openCosmeticVault();
      if (!mounted) return;
      if (reward == null) {
        _message('The Cosmetic Vault is complete or unavailable.');
        return;
      }
      await showRoyalVaultAnimation(
        context: context,
        tier: RoyalVaultVisualTier.cosmetic,
        reward: RoyalVaultRewardViewModel(
          name: reward.name,
          description: reward.description,
          rarity: _rarityName(reward.rarity).toUpperCase(),
          rarityColor: _rarityColor(context, reward.rarity),
          categoryLabel: 'NEW COSMETIC UNLOCKED',
          icon: switch (reward.kind) {
            CosmeticKind.table => Icons.table_restaurant_rounded,
            CosmeticKind.theme => Icons.palette_rounded,
            CosmeticKind.sly => Icons.theater_comedy_rounded,
          },
        ),
        fast: widget.controller.account.speed == ScoringPace.fast,
      );
    } catch (_) {
      if (mounted) {
        _message('The Vault could not open. Your save remains safe.');
      }
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _rewardedCoins() async {
    if (_actionInFlight) return;
    setState(() => _actionInFlight = true);
    try {
      final earned = await widget.controller.claimRewardedCoins();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            earned ? '+25 coins added.' : 'Rewarded ad unavailable.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) _message('Rewarded ad unavailable. Please try again.');
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Widget _coinBadge(int coins) => Semantics(
    label: '$coins account coins',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Text(
          '★ $coins',
          style: TextStyle(
            color: context.wildcard.gold,
            fontFamily: 'Bungee',
            fontSize: 13,
          ),
        ),
      ),
    ),
  );

  static String _rarityName(JokerRarity rarity) => switch (rarity) {
    JokerRarity.common => 'Common',
    JokerRarity.uncommon => 'Uncommon',
    JokerRarity.rare => 'Rare',
    JokerRarity.wild => 'WILD',
  };

  static Color _rarityColor(BuildContext context, JokerRarity rarity) =>
      switch (rarity) {
        JokerRarity.common => context.wildcard.creamDim,
        JokerRarity.uncommon => context.wildcard.mint,
        JokerRarity.rare => context.wildcard.rare,
        JokerRarity.wild => context.wildcard.wild,
      };
}

enum _VaultSection { collection, vaults }
