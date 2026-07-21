import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/cards.dart';
import '../../domain/economy.dart';
import '../../domain/game_rules.dart';
import '../../domain/joker_catalog.dart';
import '../../domain/scoring_engine.dart';
import '../../game/game_controller.dart';
import '../../game/game_models.dart';
import '../../ui/wildcard_ui.dart';
import '../app_controller.dart';

/// Binds the native run state machine to the phone-first Flutter surfaces.
///
/// The controller owns every gameplay mutation. This widget only translates
/// taps into controller actions and presents the resulting phase.
class GameHostScreen extends StatefulWidget {
  const GameHostScreen({
    required this.appController,
    required this.gameController,
    this.resumed = false,
    super.key,
  });

  final AppController appController;
  final GameController gameController;
  final bool resumed;

  @override
  State<GameHostScreen> createState() => _GameHostScreenState();
}

class _GameHostScreenState extends State<GameHostScreen> {
  RunPhase? _lastPhase;
  bool _victorySequenceStarted = false;
  bool _terminalAdAttempted = false;
  bool _claimingRunDouble = false;

  GameController get game => widget.gameController;

  @override
  void initState() {
    super.initState();
    _lastPhase = game.phase;
    game.addListener(_onGameChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (game.pendingTransition != null) {
        unawaited(game.recoverPendingTransition());
      }
      if (game.phase == RunPhase.victory && !widget.resumed) {
        _startVictorySequence();
      }
    });
  }

  @override
  void dispose() {
    game.removeListener(_onGameChanged);
    game.dispose();
    super.dispose();
  }

  void _onGameChanged() {
    final previous = _lastPhase;
    final current = game.phase;
    _lastPhase = current;
    if (current == RunPhase.victory && previous != RunPhase.victory) {
      _startVictorySequence();
    } else if (current == RunPhase.ended && previous != RunPhase.ended) {
      _showTerminalAdOnce();
    }
  }

  Future<void> _startVictorySequence() async {
    if (_victorySequenceStarted || !mounted) return;
    _victorySequenceStarted = true;
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, _, _) => const _SlyTearCinematic(),
        transitionDuration: const Duration(milliseconds: 180),
      ),
    );
    if (!mounted) return;
    await widget.appController.ads.showInterstitial();
  }

  Future<void> _showTerminalAdOnce() async {
    if (_terminalAdAttempted || !mounted) return;
    _terminalAdAttempted = true;
    if (game.endReason == RunEndReason.abandoned ||
        game.endReason == RunEndReason.defeated) {
      await widget.appController.ads.showInterstitial();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: game.phase == RunPhase.ended,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmAbandon());
      },
      child: ListenableBuilder(
        listenable: game,
        builder: (context, _) => switch (game.phase) {
          RunPhase.game => _buildRunTable(),
          RunPhase.shop => _buildShop(),
          RunPhase.revive => _buildRevive(),
          RunPhase.victory => _buildVictory(),
          RunPhase.ended => _buildResult(),
        },
      ),
    );
  }

  Widget _buildRunTable() {
    final selectedHand = <PlayingCard>[
      for (final card in game.hand)
        card.copyWith(selected: game.selectedCardIds.contains(card.uid)),
    ];
    final presentation = game.scoringPresentation;
    final activeCardId = presentation.activeCardId;
    final highlightedCard = activeCardId == null
        ? null
        : selectedHand.indexWhere((card) => card.uid == activeCardId);
    final score = presentation.result ?? game.previewSelected();
    return RunTableScreen(
      state: game.state,
      hand: selectedHand,
      slySpeech: _slySpeech(score),
      slyExpression: _slyExpression(score),
      slySkin: _slySkin(widget.appController.account.equipped.sly),
      tableFeltId: widget.appController.account.equipped.table,
      score: score,
      activeScoreEvent: presentation.activeEvent,
      highlightedHandIndex: highlightedCard == null || highlightedCard < 0
          ? null
          : highlightedCard,
      highlightedJokerIndex: presentation.activeJokerIndex,
      stakeText: game.stake > 0
          ? '${game.stake} → ${game.stakePayoutAmount}'
          : null,
      jokerSummary: presentation.label.isEmpty ? null : presentation.label,
      sortLabel: game.sortMode == HandSortMode.rank ? 'Rank' : 'Suit',
      busy: game.isBusy,
      onToggleCard: (index) {
        if (index < 0 || index >= game.hand.length) return;
        final id = game.hand[index].uid;
        if (id != null) {
          unawaited(widget.appController.audio.playUiClick());
          unawaited(_act(game.toggleCard(id)));
        }
      },
      onInspectJoker: _inspectJoker,
      onOpenHands: _openHands,
      onOpenDeck: _openDeck,
      onSortCards: () => unawaited(
        _soundAndAct(
          game.sortHand(
            game.sortMode == HandSortMode.rank
                ? HandSortMode.suit
                : HandSortMode.rank,
          ),
        ),
      ),
      onPlay: game.canPlay
          ? () => unawaited(_soundAndAct(game.playSelected()))
          : null,
      onDiscard: game.canDiscard
          ? () => unawaited(_soundAndAct(game.discardSelected()))
          : null,
      onAbandon: _confirmAbandon,
    );
  }

  Widget _buildShop() {
    final held = <JokerDefinition>[
      for (final id in game.state.jokerIds) ?jokersById[id],
    ];
    return BetweenHeatShopScreen(
      stageCleared: game.state.stage,
      runCoins: game.state.runCoins,
      heldJokers: held,
      jokerOffers: [
        for (final joker in game.jokerOffers)
          JokerShopOffer(
            joker: joker,
            price: joker.price + (game.inflationForShop ? 2 : 0),
          ),
      ],
      supplyOffers: game.supplyOffers,
      supplyLedger: game.supplyLedger,
      purchasedSupplyIdsThisShop: game.suppliesBoughtThisShop,
      heatReward: game.lastHeatReward == null
          ? null
          : game.lastHeatReward!.runCoins +
                game.lastHeatReward!.interest +
                game.lastHeatReward!.grade.bonus,
      grade: game.lastHeatReward?.grade.label,
      inflation: game.inflationForShop,
      jokerBuysUsed: game.shopBuysUsed,
      jokerBuyLimit: game.currentJokerBuyLimit,
      rerollAvailable: game.canReroll,
      busy: game.isBusy,
      onBack: _confirmAbandon,
      onInspectHeldJoker: _inspectJoker,
      onSellHeldJoker: (joker) async {
        final index = game.state.jokerIds.indexOf(joker.id);
        if (index < 0) return;
        if (await _confirm(
          'Sell ${joker.name} for ${game.sellValue(joker)} run coins?',
        )) {
          await _act(game.sellJoker(index));
        }
      },
      onInspectJokerOffer: (offer) => _inspectJoker(offer.joker),
      onBuyJoker: (offer) => _buyJoker(offer.joker),
      onBuySupply: _buySupply,
      onReroll: () => unawaited(_act(game.rerollShop())),
      onOpenDeck: _openDeck,
      onNextHeat: () => unawaited(_act(game.leaveShop())),
    );
  }

  Widget _buildRevive() {
    final needed = (game.target - game.state.stageScore).clamp(0, game.target);
    return _PhaseScaffold(
      title: 'ONE MORE PLAY?',
      subtitle: 'Sly has one last deal for this Heat.',
      icon: Icons.favorite_outline_rounded,
      children: [
        _StatRow(
          'Heat ${game.state.stage} score',
          '${game.state.stageScore} / ${game.target}',
        ),
        _StatRow('Still needed', '$needed points'),
        const _StatRow('Revive', '+1 play · once per run'),
        const _StatRow('Leaderboard', 'Revived runs stay local'),
        const SizedBox(height: 18),
        WildcardButton(
          label: widget.appController.account.noAds
              ? 'Use Ad-Free Revive'
              : 'Watch Ad · +1 Play',
          icon: const Icon(Icons.ondemand_video_rounded),
          onPressed: _revive,
          variant: WildcardButtonVariant.primary,
        ),
        const SizedBox(height: 10),
        WildcardButton(
          label: 'End Run',
          onPressed: () => unawaited(_act(game.declineRevive())),
          variant: WildcardButtonVariant.ghost,
        ),
      ],
    );
  }

  Widget _buildVictory() {
    final normalChoice = !game.state.isDaily && !game.state.isGauntlet;
    return _PhaseScaffold(
      title: game.state.isGauntlet
          ? 'GAUNTLET CONQUERED'
          : game.state.isDaily
          ? 'DAILY COMPLETE'
          : 'RUN COMPLETE',
      subtitle: normalChoice
          ? 'All 12 Heats cleared. Bank the run or enter Endless.'
          : 'The table is cleared. Your result is safely banked next.',
      icon: Icons.emoji_events_outlined,
      children: [
        _StatRow('Heats cleared', '${game.state.stagesCleared}'),
        _StatRow('Total score', '${game.totalScore}'),
        _StatRow('Best play', '${game.bestPlay}'),
        if (game.stake > 0)
          _StatRow(
            'Sly\'s contract',
            '${game.stake} → ${game.stakePayoutAmount}',
          ),
        const SizedBox(height: 18),
        if (normalChoice) ...[
          WildcardButton(
            label: 'Continue → Endless',
            onPressed: () => unawaited(_act(game.continueEndless())),
            variant: WildcardButtonVariant.primary,
          ),
          const SizedBox(height: 10),
        ],
        WildcardButton(
          label: normalChoice ? 'Bank Run & Finish' : 'Finish Run',
          onPressed: () => unawaited(_act(game.bankVictory())),
          variant: normalChoice
              ? WildcardButtonVariant.secondary
              : WildcardButtonVariant.primary,
        ),
      ],
    );
  }

  Widget _buildResult() {
    final result = game.resultSummary;
    final defeated = result?.reason == RunEndReason.defeated;
    final abandoned = result?.reason == RunEndReason.abandoned;
    final doubleBase = result?.accountCoinsEarned ?? 0;
    final doubleClaimId = '${game.runId}:double';
    final doubleClaimed = widget.appController.account.rewardClaims.contains(
      doubleClaimId,
    );
    final doubleEligible =
        !abandoned &&
        result?.reason != RunEndReason.dailyComplete &&
        doubleBase > 0;
    return _PhaseScaffold(
      title: abandoned
          ? 'RUN TERMINATED'
          : defeated && game.state.endless
          ? 'ENDLESS OVER'
          : defeated
          ? 'GAME OVER'
          : 'RUN BANKED',
      subtitle: abandoned
          ? 'Player folded. Rewards already earned remain safe.'
          : defeated && game.state.endless
          ? 'The curve caught up at Heat ${game.state.stage}. The main run remains a win.'
          : defeated
          ? 'The curve caught up. Your earned progress is safe.'
          : 'The house recorded your result.',
      icon: defeated || abandoned
          ? Icons.heart_broken_outlined
          : Icons.savings_outlined,
      danger: defeated || abandoned,
      children: [
        _StatRow(
          'Heats cleared',
          '${result?.heatsCleared ?? game.state.stagesCleared}',
        ),
        _StatRow('Total score', '${result?.totalScore ?? game.totalScore}'),
        _StatRow('Best play', '${game.bestPlay}'),
        _StatRow('Account coins earned', '+$doubleBase'),
        if (doubleEligible) ...[
          WildcardButton(
            label: doubleClaimed
                ? 'Run Coins Doubled · +$doubleBase'
                : widget.appController.account.noAds
                ? 'Claim Ad-Free Double · +$doubleBase'
                : 'Watch Ad · Double +$doubleBase',
            icon: Icon(
              doubleClaimed
                  ? Icons.check_circle_outline_rounded
                  : Icons.smart_display_outlined,
            ),
            onPressed:
                doubleClaimed ||
                    _claimingRunDouble ||
                    widget.appController.rewardedViewsLeftToday <= 0
                ? null
                : () => unawaited(_claimRunDouble(doubleBase)),
            variant: WildcardButtonVariant.secondary,
          ),
          const SizedBox(height: 7),
        ],
        _StatRow(
          'Jokers held',
          '${result?.jokerIds.length ?? game.state.jokerIds.length}',
        ),
        const SizedBox(height: 18),
        WildcardButton(
          label: 'Return Home',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => Navigator.of(context).pop(),
          variant: WildcardButtonVariant.primary,
        ),
      ],
    );
  }

  Future<void> _revive() async {
    if (!widget.appController.account.noAds) {
      final reward = await widget.appController.ads.showRewarded();
      if (reward == null) {
        if (mounted) {
          _message('Rewarded ad is not ready. Your revive is still safe.');
        }
        return;
      }
    }
    await _act(game.acceptRevive());
  }

  Future<void> _claimRunDouble(int baseCoins) async {
    if (_claimingRunDouble) return;
    setState(() => _claimingRunDouble = true);
    try {
      final claimed = await widget.appController.claimRunCoinDouble(
        runId: game.runId,
        baseCoins: baseCoins,
        mode: game.state.mode,
      );
      if (mounted && !claimed) {
        _message('Rewarded ad is not ready. The double offer remains safe.');
      }
    } catch (error) {
      if (mounted) _message('Coins were not doubled: $error');
    } finally {
      if (mounted) setState(() => _claimingRunDouble = false);
    }
  }

  Future<void> _buyJoker(JokerDefinition joker) async {
    if (game.state.jokerIds.length < maxJokers) {
      await _act(game.buyJoker(joker.id));
      return;
    }
    final swapIndex = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      backgroundColor: context.wildcard.panelStrong,
      builder: (context) =>
          _JokerSwapSheet(incoming: joker, heldIds: game.state.jokerIds),
    );
    if (swapIndex != null) {
      await _act(game.buyJoker(joker.id, swapIndex: swapIndex));
    }
  }

  Future<void> _buySupply(SupplyDefinition supply) async {
    final selection = await showModalBottomSheet<SupplySelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.wildcard.panelStrong,
      builder: (context) => _SupplySelectionSheet(
        supply: supply,
        cards: game.state.cards,
        handLevels: game.state.handLevels,
      ),
    );
    if (selection != null) {
      await _act(game.buySupply(supply.id, selection));
    }
  }

  void _openDeck() {
    unawaited(widget.appController.audio.playUiClick());
    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (context) => DeckOverlay(
        allHeatCards: game.heatDeck.isEmpty ? game.state.cards : game.heatDeck,
        liveDrawCards: game.drawPile,
        currentHand: game.hand,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  void _openHands() {
    unawaited(widget.appController.audio.playUiClick());
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: context.wildcard.panelStrong,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('POKER HANDS', style: _sheetHeading(context)),
          const SizedBox(height: 12),
          for (final type in HandType.values)
            _StatRow(
              type.legacyName,
              'Level ${game.state.handLevels[type] ?? 0} · Base ${handBasePoints[type]}',
            ),
        ],
      ),
    );
  }

  void _inspectJoker(JokerDefinition joker) {
    unawaited(widget.appController.audio.playUiClick());
    final blocked = game.state.blockedJokerIds.contains(joker.id);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(joker.name.toUpperCase()),
        content: Text(
          '${joker.description}\n\n${blocked ? 'Blocked by this Heat\'s modifier.' : 'Active this Heat.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAbandon() async {
    if (game.phase == RunPhase.ended) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (await _confirm(
      'Abandon this run? Account rewards already earned stay safe.',
    )) {
      await _act(game.abandon());
    }
  }

  Future<bool> _confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _act(Future<GameActionResult> action) async {
    final result = await action;
    if (!result.ok && mounted) _message(result.message);
  }

  Future<void> _soundAndAct(Future<GameActionResult> action) async {
    unawaited(widget.appController.audio.playUiClick());
    await _act(action);
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _slySpeech(ScoreResult? score) {
    if (game.isBusy && game.scoringPresentation.activeEvent != null) {
      final event = game.scoringPresentation.activeEvent!;
      if (event.jokerIndex != null && event.jokerIndex! >= 0) {
        final id = game.state.jokerIds[event.jokerIndex!];
        return '${jokersById[id]?.name ?? 'Joker'} changes the count.';
      }
      return score == null
          ? 'Count every card.'
          : '${score.handType.legacyName}. Keep up.';
    }
    if (score != null) {
      if (score.handType.index >= HandType.fullHouse.index) {
        return 'A serious hand. Finally.';
      }
      if (score.handType.index >= HandType.pair.index) {
        return '${score.handType.legacyName}. It might be enough.';
      }
      return 'High Card. The target will not pity you.';
    }
    if (game.state.hasAnyModifier) {
      return 'The modifier is active. Build around it.';
    }
    return 'Choose the hand that moves the target.';
  }

  SlyExpression _slyExpression(ScoreResult? score) {
    if (game.isBusy && game.scoringPresentation.activeEvent?.hit == false) {
      return SlyExpression.laughing;
    }
    if (score == null) return SlyExpression.idle;
    if (score.handType.index >= HandType.straightFlush.index) {
      return SlyExpression.shocked;
    }
    if (score.handType.index >= HandType.fullHouse.index) {
      return SlyExpression.impressed;
    }
    if (score.handType == HandType.highCard) return SlyExpression.laughing;
    return SlyExpression.thoughtful;
  }
}

class _PhaseScaffold extends StatelessWidget {
  const _PhaseScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.danger = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? context.wildcard.coral : context.wildcard.gold;
    return Scaffold(
      backgroundColor: const Color(0xFF080414),
      body: WildcardBackground(
        room: WildcardRoom.themedHome,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 34, 18, 28),
            children: [
              Icon(icon, color: accent, size: 58),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent,
                  fontFamily: 'Bungee',
                  fontSize: 27,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 10),
              Text(subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              WildcardPanel(
                borderColor: accent,
                child: Column(children: children),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    margin: const EdgeInsets.only(bottom: 7),
    decoration: BoxDecoration(
      color: context.wildcard.ink.withValues(alpha: 0.54),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: context.wildcard.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _JokerSwapSheet extends StatelessWidget {
  const _JokerSwapSheet({required this.incoming, required this.heldIds});

  final JokerDefinition incoming;
  final List<String> heldIds;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Text(
        'MAKE ROOM FOR ${incoming.name.toUpperCase()}',
        style: _sheetHeading(context),
      ),
      const SizedBox(height: 8),
      const Text('Choose one equipped Joker to sell and replace.'),
      const SizedBox(height: 12),
      for (var index = 0; index < heldIds.length; index++)
        if (jokersById[heldIds[index]] case final joker?)
          ListTile(
            minTileHeight: 56,
            title: Text(joker.name),
            subtitle: Text(
              joker.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text('+${(joker.price ~/ 2).clamp(1, joker.price)}'),
            onTap: () => Navigator.pop(context, index),
          ),
    ],
  );
}

class _SupplySelectionSheet extends StatefulWidget {
  const _SupplySelectionSheet({
    required this.supply,
    required this.cards,
    required this.handLevels,
  });

  final SupplyDefinition supply;
  final List<PlayingCard> cards;
  final Map<HandType, int> handLevels;

  @override
  State<_SupplySelectionSheet> createState() => _SupplySelectionSheetState();
}

class _SupplySelectionSheetState extends State<_SupplySelectionSheet> {
  String? cardId;
  CardSuit? suit;
  CardEnhancement? enhancement;
  HandType? handType;

  @override
  Widget build(BuildContext context) {
    final needsCard = widget.supply.id != SupplyId.boost;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.supply.name.toUpperCase(),
              style: _sheetHeading(context),
            ),
            const SizedBox(height: 12),
            if (needsCard)
              DropdownButtonFormField<String>(
                initialValue: cardId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Choose card',
                ),
                items: [
                  for (final card in widget.cards)
                    DropdownMenuItem(
                      value: card.uid,
                      child: Text(
                        '${card.rank.label}${card.suit.symbol}${card.copied ? ' · copy' : ''}',
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => cardId = value),
              ),
            if (widget.supply.id == SupplyId.dye) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<CardSuit>(
                initialValue: suit,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'New suit',
                ),
                items: [
                  for (final value in CardSuit.values)
                    DropdownMenuItem(value: value, child: Text(value.symbol)),
                ],
                onChanged: (value) => setState(() => suit = value),
              ),
            ],
            if (widget.supply.id == SupplyId.enhance) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<CardEnhancement>(
                initialValue: enhancement,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Enhancement',
                ),
                items: [
                  for (final value in CardEnhancement.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(value.name.toUpperCase()),
                    ),
                ],
                onChanged: (value) => setState(() => enhancement = value),
              ),
            ],
            if (widget.supply.id == SupplyId.boost)
              DropdownButtonFormField<HandType>(
                initialValue: handType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Poker hand',
                ),
                items: [
                  for (final value in HandType.values)
                    if ((widget.handLevels[value] ?? 0) < 5)
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          '${value.legacyName} · Level ${widget.handLevels[value] ?? 0}',
                        ),
                      ),
                ],
                onChanged: (value) => setState(() => handType = value),
              ),
            const SizedBox(height: 16),
            WildcardButton(
              label: 'Buy & Apply',
              onPressed: _ready
                  ? () => Navigator.pop(
                      context,
                      SupplySelection(
                        cardId: cardId,
                        targetSuit: suit,
                        enhancement: enhancement,
                        handType: handType,
                      ),
                    )
                  : null,
              variant: WildcardButtonVariant.primary,
            ),
          ],
        ),
      ),
    );
  }

  bool get _ready => switch (widget.supply.id) {
    SupplyId.scalpel || SupplyId.copier => cardId != null,
    SupplyId.dye => cardId != null && suit != null,
    SupplyId.enhance => cardId != null && enhancement != null,
    SupplyId.boost => handType != null,
  };
}

class _SlyTearCinematic extends StatefulWidget {
  const _SlyTearCinematic();

  @override
  State<_SlyTearCinematic> createState() => _SlyTearCinematicState();
}

class _SlyTearCinematicState extends State<_SlyTearCinematic> {
  late final VideoPlayerController video;
  Timer? watchdog;
  bool closing = false;

  @override
  void initState() {
    super.initState();
    video = VideoPlayerController.asset('assets/video/sly-single-tear.mp4');
    unawaited(_play());
  }

  Future<void> _play() async {
    try {
      await video.initialize();
      if (!mounted) return;
      setState(() {});
      video
        ..setVolume(0)
        ..addListener(_ended);
      await video.play();
    } catch (_) {
      _close();
      return;
    }
    watchdog = Timer(const Duration(seconds: 4), _close);
  }

  void _ended() {
    if (video.value.isInitialized &&
        video.value.position >=
            video.value.duration - const Duration(milliseconds: 80)) {
      _close();
    }
  }

  void _close() {
    if (closing || !mounted) return;
    closing = true;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  void dispose() {
    watchdog?.cancel();
    video.removeListener(_ended);
    video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        if (video.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: video.value.size.width,
              height: video.value.size.height,
              child: VideoPlayer(video),
            ),
          )
        else
          const Center(child: CircularProgressIndicator()),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: IconButton(
              tooltip: 'Skip',
              onPressed: _close,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}

TextStyle _sheetHeading(BuildContext context) =>
    TextStyle(color: context.wildcard.gold, fontFamily: 'Bungee', fontSize: 17);

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
