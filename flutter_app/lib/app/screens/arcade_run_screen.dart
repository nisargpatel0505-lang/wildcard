import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/joker_catalog.dart';
import '../../game/arcade_controller.dart';
import '../../ui/wildcard_ui.dart';

class ArcadeRunScreen extends StatefulWidget {
  const ArcadeRunScreen({required this.controller, super.key});

  final ArcadeController controller;

  @override
  State<ArcadeRunScreen> createState() => _ArcadeRunScreenState();
}

class _ArcadeRunScreenState extends State<ArcadeRunScreen> {
  ArcadeController get controller => widget.controller;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        backgroundColor: context.wildcard.ink,
        body: WildcardBackground(
          // The equipped UI theme owns Arcade too; it is not a hard-coded room.
          room: WildcardRoom.themedHome,
          surface: WildcardUiSurface.arcadeGameplay,
          energy: controller.phase == ArcadePhase.resolving ? .8 : .28,
          momentPulse: controller.lastResult?.total.toDouble() ?? 0,
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _table(),
                if (controller.phase == ArcadePhase.shop) _shop(),
                if (controller.phase == ArcadePhase.won ||
                    controller.phase == ArcadePhase.lost)
                  _terminal(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _table() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 650 || constraints.maxWidth < 350;
      return Padding(
        padding: EdgeInsets.fromLTRB(compact ? 8 : 12, 6, compact ? 8 : 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(compact),
            SizedBox(height: compact ? 7 : 10),
            _scoreStrip(compact),
            if (controller.lastMilestone case final milestone?) ...[
              SizedBox(height: compact ? 5 : 7),
              WildcardCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                accent: WildcardCardAccent.gold,
                child: Text(
                  'ENDLESS MILESTONE $milestone CLEARED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.wildcard.gold,
                    fontFamily: 'Bungee',
                    fontSize: compact ? 9 : 10.5,
                  ),
                ),
              ),
            ],
            SizedBox(height: compact ? 7 : 10),
            _jokerStrip(compact),
            const Spacer(),
            _resultPanel(compact),
            SizedBox(height: compact ? 8 : 12),
            _cards(constraints.maxWidth, compact),
            SizedBox(height: compact ? 8 : 12),
            WildcardButton(
              key: const Key('arcade-score-button'),
              label: controller.isBusy
                  ? 'Resolving'
                  : controller.selectedCardIds.length == 3
                  ? 'Score Three'
                  : 'Choose ${3 - controller.selectedCardIds.length} More',
              icon: const Icon(Icons.bolt_rounded),
              onPressed: controller.canScore
                  ? () => unawaited(controller.scoreSelected())
                  : null,
              variant: WildcardButtonVariant.primary,
              minHeight: compact ? 50 : 56,
              fontSize: compact ? 12 : 14,
            ),
          ],
        ),
      );
    },
  );

  Widget _header(bool compact) => Row(
    children: [
      WildcardSquareButton(
        icon: const Icon(Icons.close_rounded),
        semanticLabel: 'Leave Arcade',
        onPressed: controller.isBusy ? null : () => Navigator.maybePop(context),
        size: compact ? 44 : 48,
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ARCADE · ROUND ${controller.round}',
              maxLines: 1,
              style: TextStyle(
                color: context.wildcard.gold,
                fontFamily: 'Bungee',
                fontSize: compact ? 15 : 18,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              controller.config.length.displayName,
              style: TextStyle(
                color: context.wildcard.creamDim,
                fontSize: compact ? 9.5 : 11,
              ),
            ),
          ],
        ),
      ),
      RunCoinBadge(coins: controller.runCoins, compact: true),
      const SizedBox(width: 7),
      Semantics(
        toggled: controller.turbo,
        label: 'Turbo scoring',
        child: FilterChip(
          key: const Key('arcade-turbo-toggle'),
          selected: controller.turbo,
          label: const Text('TURBO'),
          onSelected: controller.isBusy ? null : controller.setTurbo,
          labelStyle: TextStyle(
            color: controller.turbo
                ? context.wildcard.onSecondaryAccent
                : context.wildcard.cream,
            fontFamily: 'Bungee',
            fontSize: 8,
          ),
          selectedColor: context.wildcard.gold,
          backgroundColor: context.wildcard.panel,
          side: BorderSide(color: context.wildcard.violet),
          visualDensity: VisualDensity.compact,
        ),
      ),
    ],
  );

  Widget _scoreStrip(bool compact) => WildcardCard(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 10 : 14,
      vertical: compact ? 8 : 11,
    ),
    accent: WildcardCardAccent.mint,
    child: Row(
      children: [
        _metric('TARGET', '${controller.target}', context.wildcard.coral),
        _divider(),
        _metric('RUN SCORE', '${controller.totalScore}', context.wildcard.gold),
        _divider(),
        _metric(
          'CLEARED',
          '${controller.clearedRounds}',
          context.wildcard.mint,
        ),
      ],
    ),
  );

  Widget _metric(String label, String value, Color color) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.wildcard.creamDim,
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontFamily: 'Bungee',
              fontSize: 20,
              height: 1,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _divider() => Container(
    width: 1,
    height: 34,
    color: context.wildcard.line.withValues(alpha: .45),
  );

  Widget _jokerStrip(bool compact) {
    final jokers = controller.heldJokers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'JOKERS',
              style: TextStyle(
                color: context.wildcard.mint,
                fontFamily: 'Bungee',
                fontSize: 10,
              ),
            ),
            const Spacer(),
            Text(
              '${jokers.length} / 5',
              style: TextStyle(color: context.wildcard.creamDim, fontSize: 9),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: compact ? 48 : 54,
          child: Row(
            children: [
              for (var index = 0; index < 5; index++) ...[
                Expanded(
                  child: CompactJokerCard(
                    joker: index < jokers.length ? jokers[index] : null,
                    height: compact ? 48 : 54,
                    highlighted:
                        index < jokers.length &&
                        controller.lastTriggerLabels.any(
                          (label) => label.startsWith(jokers[index].name),
                        ),
                    triggerLabel: index < jokers.length
                        ? _triggerFor(jokers[index])
                        : null,
                  ),
                ),
                if (index < 4) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String? _triggerFor(JokerDefinition joker) {
    for (final label in controller.lastTriggerLabels) {
      if (label.startsWith('${joker.name}:')) {
        return label.substring(joker.name.length + 1).trim();
      }
    }
    return null;
  }

  Widget _resultPanel(bool compact) {
    final result = controller.lastResult;
    final evaluation = controller.lastEvaluation;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 170),
      child: result == null || evaluation == null
          ? WildcardPanel(
              key: const ValueKey('arcade-prompt'),
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: compact ? 9 : 13,
              ),
              child: Text(
                'SELECT EXACTLY THREE · THE OTHER TWO BECOME SHOP CHANGE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.wildcard.cream,
                  fontSize: compact ? 9 : 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : WildcardPanel(
              key: ValueKey('arcade-result-${controller.round}'),
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: compact ? 8 : 12,
              ),
              borderColor: result.total >= controller.target
                  ? context.wildcard.mint
                  : context.wildcard.coral,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          evaluation.type.displayName.toUpperCase(),
                          style: TextStyle(
                            color: context.wildcard.gold,
                            fontFamily: 'Bungee',
                            fontSize: compact ? 10 : 12,
                          ),
                        ),
                        Text(
                          '${result.valuePoints} × ${result.multiplier.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: context.wildcard.creamDim,
                            fontSize: compact ? 10 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${result.total}',
                    style: TextStyle(
                      color: result.total >= controller.target
                          ? context.wildcard.mint
                          : context.wildcard.coral,
                      fontFamily: 'Bungee',
                      fontSize: compact ? 25 : 31,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _cards(double availableWidth, bool compact) {
    const gaps = 4 * 5.0;
    final width = math.min(
      compact ? 58.0 : 66.0,
      (availableWidth - (compact ? 16 : 24) - gaps) / 5,
    );
    final height = width * 1.62;
    return Semantics(
      label: '${controller.selectedCardIds.length} of 3 Arcade cards selected',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < controller.hand.length; index++) ...[
            PlayingCardTile(
              key: ValueKey('arcade-card-${controller.hand[index].uid}'),
              card: controller.hand[index].copyWith(
                selected: controller.selectedCardIds.contains(
                  controller.hand[index].uid,
                ),
              ),
              width: width,
              height: height,
              liftWhenSelected: !controller.isBusy,
              selectionDisabled:
                  !controller.selectedCardIds.contains(
                    controller.hand[index].uid,
                  ) &&
                  controller.selectedCardIds.length >= 3,
              highlighted:
                  controller.isBusy &&
                  controller.selectedCardIds.contains(
                    controller.hand[index].uid,
                  ),
              onTap: controller.phase == ArcadePhase.choosing
                  ? () => controller.toggleCard(controller.hand[index].uid!)
                  : null,
            ),
            if (index < controller.hand.length - 1) const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }

  Widget _shop() => ColoredBox(
    color: context.wildcard.overlayScrim.withValues(alpha: .86),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: WildcardPanel(
          borderColor: context.wildcard.gold,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ARCADE SHOP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.wildcard.gold,
                  fontFamily: 'Bungee',
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Round ${controller.clearedRounds} cleared · choose one discovered Joker',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.wildcard.creamDim,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              if (controller.shopOffers.isEmpty)
                const Text(
                  'No new discovered Jokers are available.',
                  textAlign: TextAlign.center,
                )
              else
                for (final joker in controller.shopOffers) ...[
                  WildcardCard(
                    accent: _rarityAccent(joker.rarity),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                joker.name.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'Bungee',
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                joker.description,
                                style: const TextStyle(fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed:
                              controller.jokerBoughtThisShop ||
                                  controller.runCoins < joker.price
                              ? null
                              : () => controller.buyJoker(joker.id),
                          child: Text('${joker.price} COINS'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
              const SizedBox(height: 10),
              WildcardButton(
                key: const Key('leave-arcade-shop'),
                label: 'Next Deal',
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: controller.leaveShop,
                variant: WildcardButtonVariant.primary,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _terminal() {
    final won = controller.phase == ArcadePhase.won;
    return ColoredBox(
      color: context.wildcard.overlayScrim.withValues(alpha: .91),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: WildcardPanel(
            borderColor: won ? context.wildcard.mint : context.wildcard.coral,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  won ? Icons.emoji_events_rounded : Icons.close_rounded,
                  color: won ? context.wildcard.gold : context.wildcard.coral,
                  size: 54,
                ),
                const SizedBox(height: 8),
                Text(
                  won ? 'ARCADE CLEARED' : 'ARCADE OVER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: won ? context.wildcard.mint : context.wildcard.coral,
                    fontFamily: 'Bungee',
                    fontSize: 25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${controller.clearedRounds} rounds · ${controller.totalScore} points',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                if (controller.lastMilestone case final milestone?) ...[
                  const SizedBox(height: 8),
                  Text(
                    'ENDLESS MILESTONE $milestone',
                    style: TextStyle(
                      color: context.wildcard.gold,
                      fontFamily: 'Bungee',
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                WildcardButton(
                  label: 'Back to Arcade',
                  onPressed: () => Navigator.pop(context),
                  variant: WildcardButtonVariant.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static WildcardCardAccent _rarityAccent(JokerRarity rarity) =>
      switch (rarity) {
        JokerRarity.common => WildcardCardAccent.gold,
        JokerRarity.uncommon => WildcardCardAccent.mint,
        JokerRarity.rare => WildcardCardAccent.rare,
        JokerRarity.wild => WildcardCardAccent.violet,
      };
}
