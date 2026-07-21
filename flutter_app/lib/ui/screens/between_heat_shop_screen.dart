import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/economy.dart';
import '../../domain/game_rules.dart';
import '../../domain/joker_catalog.dart';
import '../models/game_ui_models.dart';
import '../widgets/compact_joker_card.dart';
import '../widgets/wildcard_background.dart';
import '../widgets/wildcard_button.dart';
import '../wildcard_theme.dart';

/// Phone-first between-Heat shop.
///
/// Supply prices come from the durable domain ledger. A supply already present
/// in [purchasedSupplyIdsThisShop] remains visible but cannot call its purchase
/// callback again, preserving the once-per-shop rule in the presentation layer.
class BetweenHeatShopScreen extends StatelessWidget {
  const BetweenHeatShopScreen({
    required this.stageCleared,
    required this.runCoins,
    required this.heldJokers,
    required this.jokerOffers,
    required this.supplyOffers,
    required this.supplyLedger,
    this.purchasedSupplyIdsThisShop = const <SupplyId>{},
    this.heatReward,
    this.grade,
    this.inflation = false,
    this.jokerBuysUsed = 0,
    this.jokerBuyLimit = 1,
    this.rerollCost = shopRerollCost,
    this.rerollAvailable = true,
    this.busy = false,
    this.onBack,
    this.onInspectHeldJoker,
    this.onSellHeldJoker,
    this.onInspectJokerOffer,
    this.onBuyJoker,
    this.onBuySupply,
    this.onReroll,
    this.onOpenDeck,
    this.onNextHeat,
    super.key,
  });

  final int stageCleared;
  final int runCoins;
  final List<JokerDefinition> heldJokers;
  final List<JokerShopOffer> jokerOffers;
  final List<SupplyDefinition> supplyOffers;
  final SupplyPurchaseLedger supplyLedger;
  final Set<SupplyId> purchasedSupplyIdsThisShop;
  final int? heatReward;
  final String? grade;
  final bool inflation;
  final int jokerBuysUsed;
  final int jokerBuyLimit;
  final int rerollCost;
  final bool rerollAvailable;
  final bool busy;

  final VoidCallback? onBack;
  final ValueChanged<JokerDefinition>? onInspectHeldJoker;
  final ValueChanged<JokerDefinition>? onSellHeldJoker;
  final ValueChanged<JokerShopOffer>? onInspectJokerOffer;
  final ValueChanged<JokerShopOffer>? onBuyJoker;
  final ValueChanged<SupplyDefinition>? onBuySupply;
  final VoidCallback? onReroll;
  final VoidCallback? onOpenDeck;
  final VoidCallback? onNextHeat;

  @override
  Widget build(BuildContext context) {
    final buyLimitReached = jokerBuysUsed >= jokerBuyLimit;
    return Scaffold(
      backgroundColor: const Color(0xFF080414),
      body: WildcardBackground(
        room: WildcardRoom.shop,
        tintStrength: 0.9,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(0, 4, 0, 5),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 340;
              final side = compact ? 8.0 : 12.0;
              return Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      key: const Key('between-heat-shop-scroll'),
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(side, 2, side, 82),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ShopHeader(
                            stageCleared: stageCleared,
                            runCoins: runCoins,
                            heatReward: heatReward,
                            grade: grade,
                            compact: compact,
                            onBack: busy ? null : onBack,
                          ),
                          const SizedBox(height: 10),
                          _SectionHeading(
                            title: 'YOUR JOKERS',
                            trailing:
                                '${heldJokers.length} of $maxJokers equipped',
                          ),
                          const SizedBox(height: 5),
                          _HeldJokerStrip(
                            jokers: heldJokers,
                            busy: busy,
                            onInspect: onInspectHeldJoker,
                            onSell: onSellHeldJoker,
                          ),
                          const SizedBox(height: 13),
                          _ShopOfferHeader(
                            buysUsed: jokerBuysUsed,
                            buyLimit: jokerBuyLimit,
                            rerollCost: rerollCost,
                            canReroll:
                                !busy &&
                                rerollAvailable &&
                                !buyLimitReached &&
                                runCoins >= rerollCost &&
                                onReroll != null,
                            onReroll: onReroll,
                          ),
                          const SizedBox(height: 7),
                          if (jokerOffers.isEmpty)
                            _EmptyShopMessage(
                              message:
                                  'No new Jokers available. Unlock more between runs.',
                            )
                          else
                            _JokerOfferGrid(
                              offers: jokerOffers,
                              runCoins: runCoins,
                              buyLimitReached: buyLimitReached,
                              busy: busy,
                              onInspect: onInspectJokerOffer,
                              onBuy: onBuyJoker,
                            ),
                          const SizedBox(height: 14),
                          _SectionHeading(
                            title: 'SUPPLIES',
                            trailing: 'Each offer once this shop',
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Each use raises that supply\'s price for the rest of this run.',
                            style: TextStyle(
                              color: context.wildcard.creamDim,
                              fontSize: compact ? 9 : 10,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 7),
                          _SupplyGrid(
                            offers: supplyOffers,
                            ledger: supplyLedger,
                            boughtThisShop: purchasedSupplyIdsThisShop,
                            inflation: inflation,
                            runCoins: runCoins,
                            busy: busy,
                            onBuy: onBuySupply,
                          ),
                          const SizedBox(height: 12),
                          WildcardButton(
                            label: 'View This Heat\'s Deck',
                            icon: const Icon(Icons.style_outlined),
                            onPressed: busy ? null : onOpenDeck,
                            variant: WildcardButtonVariant.ghost,
                            minHeight: 48,
                            fontSize: compact ? 10.5 : 11.5,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: side,
                    right: side,
                    bottom: 5,
                    child: WildcardButton(
                      key: const Key('next-heat-button'),
                      label: 'Next Heat',
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: busy ? null : onNextHeat,
                      variant: WildcardButtonVariant.primary,
                      minHeight: 56,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({
    required this.stageCleared,
    required this.runCoins,
    required this.heatReward,
    required this.grade,
    required this.compact,
    required this.onBack,
  });

  final int stageCleared;
  final int runCoins;
  final int? heatReward;
  final String? grade;
  final bool compact;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Row(
      children: [
        _BackButton(onPressed: onBack),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SLY\'S SHOP',
                style: TextStyle(
                  color: tokens.gold,
                  fontFamily: 'Bungee',
                  fontSize: compact ? 18 : 21,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Heat $stageCleared cleared${heatReward == null ? '' : '  \u00b7  +$heatReward run coins'}${grade == null ? '' : '  \u00b7  Grade $grade'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.creamDim,
                  fontSize: compact ? 9 : 10.5,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _RunCoinBadge(coins: math.max(0, runCoins)),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: 'Back',
      onTap: onPressed,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.panelStrong,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.line, width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(11),
                child: Icon(Icons.arrow_back_rounded, color: tokens.cream),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunCoinBadge extends StatelessWidget {
  const _RunCoinBadge({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Container(
      constraints: const BoxConstraints(minWidth: 62, minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.panelStrong,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.gold.withValues(alpha: 0.7)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'RUN COINS',
            style: TextStyle(color: tokens.creamDim, fontSize: 8.5, height: 1),
          ),
          const SizedBox(height: 3),
          Text(
            '$coins',
            style: TextStyle(
              color: tokens.gold,
              fontFamily: 'Bungee',
              fontSize: 13,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: tokens.gold,
            fontFamily: 'Bungee',
            fontSize: 10,
            height: 1,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            trailing,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(color: tokens.creamDim, fontSize: 9, height: 1),
          ),
        ),
      ],
    );
  }
}

class _HeldJokerStrip extends StatelessWidget {
  const _HeldJokerStrip({
    required this.jokers,
    required this.busy,
    required this.onInspect,
    required this.onSell,
  });

  final List<JokerDefinition> jokers;
  final bool busy;
  final ValueChanged<JokerDefinition>? onInspect;
  final ValueChanged<JokerDefinition>? onSell;

  @override
  Widget build(BuildContext context) {
    if (jokers.isEmpty) {
      return const _EmptyShopMessage(
        message: 'No Jokers equipped yet. Your first engine starts here.',
      );
    }
    return SizedBox(
      height: 119,
      child: ListView.separated(
        key: const Key('held-joker-strip'),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: jokers.length,
        separatorBuilder: (context, index) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final joker = jokers[index];
          return SizedBox(
            width: 148,
            child: Column(
              children: [
                Expanded(
                  child: CompactJokerCard(
                    joker: joker,
                    height: 67,
                    onTap: busy || onInspect == null
                        ? null
                        : () => onInspect!(joker),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: busy || onSell == null
                        ? null
                        : () => onSell!(joker),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.wildcard.gold,
                      side: BorderSide(color: context.wildcard.line),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'SELL +${math.max(1, joker.price ~/ 2)}',
                      style: const TextStyle(fontFamily: 'Bungee', fontSize: 8),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShopOfferHeader extends StatelessWidget {
  const _ShopOfferHeader({
    required this.buysUsed,
    required this.buyLimit,
    required this.rerollCost,
    required this.canReroll,
    required this.onReroll,
  });

  final int buysUsed;
  final int buyLimit;
  final int rerollCost;
  final bool canReroll;
  final VoidCallback? onReroll;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'JOKER OFFERS',
                style: TextStyle(
                  color: tokens.gold,
                  fontFamily: 'Bungee',
                  fontSize: 10,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${math.min(buysUsed, buyLimit)} of $buyLimit bought this shop',
                style: TextStyle(
                  color: tokens.creamDim,
                  fontSize: 9,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: canReroll ? onReroll : null,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: Text(
              'REROLL \u00b7 $rerollCost',
              style: const TextStyle(fontFamily: 'Bungee', fontSize: 8.5),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.cream,
              side: BorderSide(color: tokens.violet),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ),
      ],
    );
  }
}

class _JokerOfferGrid extends StatelessWidget {
  const _JokerOfferGrid({
    required this.offers,
    required this.runCoins,
    required this.buyLimitReached,
    required this.busy,
    required this.onInspect,
    required this.onBuy,
  });

  final List<JokerShopOffer> offers;
  final int runCoins;
  final bool buyLimitReached;
  final bool busy;
  final ValueChanged<JokerShopOffer>? onInspect;
  final ValueChanged<JokerShopOffer>? onBuy;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final offer in offers)
              SizedBox(
                width: width,
                child: _JokerOfferTile(
                  offer: offer,
                  canBuy:
                      !busy &&
                      !buyLimitReached &&
                      !offer.soldOut &&
                      (offer.canBuy ?? runCoins >= offer.effectivePrice) &&
                      onBuy != null,
                  onInspect: busy || onInspect == null
                      ? null
                      : () => onInspect!(offer),
                  onBuy: () => onBuy!(offer),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _JokerOfferTile extends StatelessWidget {
  const _JokerOfferTile({
    required this.offer,
    required this.canBuy,
    required this.onInspect,
    required this.onBuy,
  });

  final JokerShopOffer offer;
  final bool canBuy;
  final VoidCallback? onInspect;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final accent = _rarityColor(tokens, offer.joker.rarity);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Container(
      height: 172 + math.max(0, textScale - 1) * 145,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: tokens.panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onInspect,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.joker.rarity.name.toUpperCase(),
                    style: TextStyle(color: accent, fontSize: 9, height: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    offer.joker.name.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontFamily: 'Bungee',
                      fontSize: 10.5,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    offer.joker.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.creamDim,
                      fontSize: 10,
                      height: 1.18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${offer.effectivePrice} run coins',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.gold,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: canBuy ? onBuy : null,
              style: FilledButton.styleFrom(
                backgroundColor: tokens.mint,
                foregroundColor: const Color(0xFF061512),
                disabledBackgroundColor: tokens.line.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(horizontal: 5),
              ),
              child: Text(
                offer.soldOut ? 'SOLD' : 'BUY',
                style: const TextStyle(fontFamily: 'Bungee', fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplyGrid extends StatelessWidget {
  const _SupplyGrid({
    required this.offers,
    required this.ledger,
    required this.boughtThisShop,
    required this.inflation,
    required this.runCoins,
    required this.busy,
    required this.onBuy,
  });

  final List<SupplyDefinition> offers;
  final SupplyPurchaseLedger ledger;
  final Set<SupplyId> boughtThisShop;
  final bool inflation;
  final int runCoins;
  final bool busy;
  final ValueChanged<SupplyDefinition>? onBuy;

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) {
      return const _EmptyShopMessage(message: 'No supply offers this Heat.');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final supply in offers)
              SizedBox(
                width: width,
                child: _SupplyTile(
                  supply: supply,
                  price: supplyPrice(
                    supply,
                    ledger: ledger,
                    inflation: inflation,
                  ),
                  bought: boughtThisShop.contains(supply.id),
                  canAfford:
                      runCoins >=
                      supplyPrice(supply, ledger: ledger, inflation: inflation),
                  busy: busy,
                  onBuy: onBuy == null ? null : () => onBuy!(supply),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SupplyTile extends StatelessWidget {
  const _SupplyTile({
    required this.supply,
    required this.price,
    required this.bought,
    required this.canAfford,
    required this.busy,
    required this.onBuy,
  });

  final SupplyDefinition supply;
  final int price;
  final bool bought;
  final bool canAfford;
  final bool busy;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Container(
      height: 164 + math.max(0, textScale - 1) * 75,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: tokens.panel.withValues(alpha: bought ? 0.72 : 0.94),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: bought ? tokens.line : tokens.mint.withValues(alpha: 0.75),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_supplyIcon(supply.id), color: tokens.mint, size: 19),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  supply.name.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.mint,
                    fontFamily: 'Bungee',
                    fontSize: 9,
                    height: 1.08,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _supplyDescription(supply.id),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.creamDim,
              fontSize: 10,
              height: 1.18,
            ),
          ),
          const Spacer(),
          Text(
            '$price run coins',
            style: TextStyle(
              color: tokens.gold,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              key: ValueKey('buy-supply-${supply.id.name}'),
              onPressed: !busy && !bought && canAfford ? onBuy : null,
              style: FilledButton.styleFrom(
                backgroundColor: tokens.mint,
                foregroundColor: const Color(0xFF061512),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text(
                bought ? 'BOUGHT THIS SHOP' : 'BUY & USE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Bungee', fontSize: 8.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyShopMessage extends StatelessWidget {
  const _EmptyShopMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.wildcard.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.wildcard.line),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.wildcard.creamDim, fontSize: 10),
      ),
    );
  }
}

Color _rarityColor(WildcardThemeTokens tokens, JokerRarity rarity) =>
    switch (rarity) {
      JokerRarity.common => tokens.gold,
      JokerRarity.uncommon => tokens.mint,
      JokerRarity.rare => tokens.rare,
      JokerRarity.wild => tokens.wild,
    };

IconData _supplyIcon(SupplyId id) => switch (id) {
  SupplyId.scalpel => Icons.content_cut_rounded,
  SupplyId.copier => Icons.copy_all_rounded,
  SupplyId.dye => Icons.palette_outlined,
  SupplyId.enhance => Icons.auto_awesome_rounded,
  SupplyId.boost => Icons.trending_up_rounded,
};

String _supplyDescription(SupplyId id) => switch (id) {
  SupplyId.scalpel => 'Remove one card from your deck.',
  SupplyId.copier => 'Copy one card already in your deck.',
  SupplyId.dye => 'Change one card\'s suit.',
  SupplyId.enhance => 'Add a lasting card enhancement.',
  SupplyId.boost => 'Raise one poker hand\'s base value.',
};
