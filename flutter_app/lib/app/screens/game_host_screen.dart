import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';

import '../../domain/cards.dart';
import '../../domain/economy.dart';
import '../../domain/game_rules.dart';
import '../../domain/joker_catalog.dart';
import '../../domain/scoring_engine.dart';
import '../../domain/sly_quips.dart';
import '../../game/game_controller.dart';
import '../../game/game_models.dart';
import '../../game/scoring_timeline.dart';
import '../../services/haptics_service.dart';
import '../../services/sfx_service.dart';
import '../../ui/widgets/death_screen_overlay.dart';
import '../../ui/widgets/wildcard_toast.dart';
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

  /// Haptics follow the player's sound switch, so one toggle silences both.
  late final HapticsService _haptics = HapticsService(
    enabled: !widget.appController.account.muted,
  );

  /// Heat-opening wash. The WebView showed this at the start of every Heat and
  /// the port dropped it, so Heats began with no sense of occasion.
  int? _introShownForStage;
  bool _introVisible = false;
  bool _victorySequenceStarted = false;
  bool _terminalAdAttempted = false;
  bool _deathScreenShown = false;
  bool _claimingRunDouble = false;

  /// Sly's live table talk, drawn from the ported WebView quip pools. When
  /// null the passive state description is shown instead.
  final math.Random _slyRandom = math.Random();
  final ValueNotifier<SlyReaction?> _slyReaction = ValueNotifier<SlyReaction?>(
    null,
  );
  int _slySequence = 0;
  Timer? _slyHold;

  /// Score callout ("WILD!" / "MEGA!"…) stamped over the table when a hand
  /// resolves, mirroring the WebView's `calloutFor`.
  ///
  /// Held long enough to read a word and register the win. The stamp lands
  /// during `resultHold`, so it must not outlive that pause.
  static const Duration _calloutHold = Duration(milliseconds: 1200);
  String? _calloutWord;
  Color? _calloutColor;
  int _calloutSeq = 0;
  Timer? _calloutTimer;
  bool _lastPresentationComplete = false;

  Timer? _gradeChordTimer;

  GameController get game => widget.gameController;
  SfxService get _sfx => widget.appController.sfx;

  @override
  void initState() {
    super.initState();
    _lastPhase = game.phase;
    game.addListener(_onGameChanged);
    game.scoringTimeline.addListener(_onTimelineChanged);
    game.onScoreBeat = _onScoreBeat;
    // Pre-load the scoring sounds so the very first beat is on time.
    unawaited(_sfx.warmUp(SfxService.scoringSet));
    _syncAmbience();
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
    _slyHold?.cancel();
    _calloutTimer?.cancel();
    _gradeChordTimer?.cancel();
    unawaited(widget.appController.audio.syncAmbience(active: false));
    game.onScoreBeat = null;
    game.scoringTimeline.removeListener(_onTimelineChanged);
    game.removeListener(_onGameChanged);
    _slyReaction.dispose();
    game.dispose();
    super.dispose();
  }

  /// Applies presentation state changes safely from a controller notification.
  ///
  /// `notifyListeners()` fires synchronously from inside the scoring sequence,
  /// which can land while the framework is building. Calling `setState` there
  /// throws, and that exception used to propagate back into the controller and
  /// strand `isBusy`, locking the player out of the shop entirely. Presentation
  /// now always defers to the next frame and can never throw into gameplay.
  void _safeSetState(VoidCallback change) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    final building =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (!building) {
      if (mounted) setState(change);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(change);
    });
  }

  void _onGameChanged() {
    final previous = _lastPhase;
    final current = game.phase;
    _lastPhase = current;
    _syncAmbience();
    if (current == RunPhase.victory && previous != RunPhase.victory) {
      _startVictorySequence();
    } else if (current == RunPhase.ended && previous != RunPhase.ended) {
      if (game.endReason == RunEndReason.defeated ||
          game.endReason == RunEndReason.abandoned) {
        // The arcade game-over jingle: descending run, minor stinger, sub thud.
        _sfx.play('death');
        _haptics.failure();
        // The red "GAME OVER / RUN TERMINATED" pull-over plays first, then the
        // ad — matching the WebView's death sequence.
        _playDeathScreen(terminated: game.endReason == RunEndReason.abandoned);
      } else {
        _showTerminalAdOnce();
      }
    } else if (current == RunPhase.shop && previous == RunPhase.game) {
      _onHeatCleared();
    }
  }

  void _onTimelineChanged() {
    _maybeReactToScoring();
  }

  /// The eerie modifier loop follows the table exactly as in the WebView:
  /// only while a modifier Heat is actually being played.
  void _syncAmbience() {
    unawaited(
      widget.appController.audio.syncAmbience(
        active: game.phase == RunPhase.game && game.state.hasAnyModifier,
      ),
    );
  }

  void _onHeatCleared() {
    _sfx.play('heat_clear');
    _haptics.success();
    _saySly(SlyMood.clear);
    if (!mounted) return;
    // The cheering Sly stage overlay was removed at the player's request: it
    // fought the shop transition and read as clutter. The sound and the grade
    // chord stay as the reward beat.
    if (game.lastHeatReward?.grade.label == 'S') {
      _gradeChordTimer?.cancel();
      _gradeChordTimer = Timer(const Duration(milliseconds: 620), () {
        _sfx.play('grade_s');
      });
    }
  }

  /// Sound and haptic beat for each presented scoring event. The rising tone
  /// ladders are the WebView's: cards walk up from 320Hz, Jokers from 560Hz,
  /// Mult procs from 700Hz, all sharing one step counter per hand.
  void _onScoreBeat(ScorePresentationBeat beat, int ordinal) {
    final event = beat.event;
    final step = ordinal.clamp(0, 9);
    switch (event.type) {
      case ScoreEventType.card:
        _sfx.play('score_$step');
        _haptics.cardBeat();
        _reactSly(
          mood: SlyMood.meh,
          expression: SlyExpression.thoughtful,
          speech: event.amount == 0
              ? 'Blocked. That card scores zero.'
              : 'Count it.',
          priority: 1,
          motion: SlyMotionProfile.pop,
          hold: const Duration(milliseconds: 760),
        );
      case ScoreEventType.rankJoker:
        _sfx.play('joker_$step');
        _haptics.jokerBeat();
        _reactSly(
          mood: SlyMood.impressed,
          expression: SlyExpression.impressed,
          speech: 'That Joker changes the count.',
          priority: 2,
          motion: SlyMotionProfile.rock,
          hold: const Duration(milliseconds: 1100),
        );
      case ScoreEventType.retrigger:
        _sfx.play('retrigger');
        _haptics.retrigger();
        _reactSly(
          mood: SlyMood.impressed,
          expression: SlyExpression.shocked,
          speech: 'Again. Make it matter.',
          priority: 3,
          motion: SlyMotionProfile.rock,
          hold: const Duration(milliseconds: 1250),
        );
      case ScoreEventType.seven:
        if (beat.frame.chipStyle == ScoreChipStyle.suspense) {
          _sfx.play('seven_roll');
          _haptics.jokerBeat();
          _reactSly(
            mood: SlyMood.scared,
            expression: SlyExpression.scared,
            speech: 'The roll decides it.',
            priority: 3,
            motion: SlyMotionProfile.tremble,
            hold: const Duration(milliseconds: 900),
          );
        } else if (event.hit == true) {
          _sfx.play('jackpot');
          _saySly(SlyMood.sevenHit);
        } else {
          _sfx.play('seven_miss');
          _saySly(SlyMood.sevenMiss);
        }
      case ScoreEventType.mult:
      case ScoreEventType.xMult:
        _sfx.play('mult_$step');
        _haptics.multiplier();
        _reactSly(
          mood: event.type == ScoreEventType.xMult
              ? SlyMood.unbelievable
              : SlyMood.impressed,
          expression: event.type == ScoreEventType.xMult
              ? SlyExpression.shocked
              : SlyExpression.impressed,
          speech: event.type == ScoreEventType.xMult
              ? 'Now the hand has weight.'
              : 'Multiplier rising.',
          priority: event.type == ScoreEventType.xMult ? 4 : 2,
          motion: event.type == ScoreEventType.xMult
              ? SlyMotionProfile.rock
              : SlyMotionProfile.pop,
          hold: const Duration(milliseconds: 1200),
        );
    }
  }

  /// Fires once when a hand's presentation completes: callout stamp, chord,
  /// haptic and Sly's table reaction — the WebView's end-of-hand beat.
  void _maybeReactToScoring() {
    final presentation = game.scoringPresentation;
    final complete = presentation.complete && presentation.result != null;
    if (complete == _lastPresentationComplete) return;
    _lastPresentationComplete = complete;
    if (!complete) return;
    final result = presentation.result!;
    final target = math.max(1, game.state.target);
    final total = result.total;
    String? word;
    Color? color;
    String chord;
    if (total >= target) {
      word = 'WILD!';
      color = const Color(0xFFF7C548);
      chord = 'callout_wild';
    } else if (total >= target * 0.6) {
      word = 'MEGA!';
      color = const Color(0xFFB794FF);
      chord = 'callout_mega';
    } else if (total >= target * 0.35) {
      word = 'GREAT!';
      color = const Color(0xFF45E0C6);
      chord = 'callout_great';
    } else if (total >= target * 0.2) {
      word = 'NICE!';
      color = const Color(0xFF9B7BFF);
      chord = 'callout_nice';
    } else {
      chord = 'hand_total';
    }
    _sfx.play(chord);
    if (word != null) {
      if (word == 'WILD!') {
        _haptics.success();
      } else {
        _haptics.play();
      }
      _calloutTimer?.cancel();
      _safeSetState(() {
        _calloutWord = word;
        _calloutColor = color;
        _calloutSeq++;
      });
      _calloutTimer = Timer(_calloutHold, () {
        if (mounted) _safeSetState(() => _calloutWord = null);
      });
    }
    // Sly reacts to every played hand; one play left overrides everything.
    if (game.state.handsLeft == 1 &&
        game.state.stageScore < game.state.target) {
      _saySly(SlyMood.clutch);
    } else {
      _saySly(_moodForHand(result));
    }
  }

  SlyMood _moodForHand(ScoreResult result) {
    final target = math.max(1, game.state.target);
    final mood = switch (result.handType) {
      HandType.highCard => SlyMood.highCard,
      HandType.pair => SlyMood.pair,
      HandType.twoPair => SlyMood.twoPair,
      HandType.threeOfAKind => SlyMood.trips,
      HandType.straight => SlyMood.straight,
      HandType.flush => SlyMood.flush,
      HandType.fullHouse => SlyMood.fullHouse,
      HandType.fourOfAKind => SlyMood.quads,
      HandType.straightFlush => SlyMood.straightFlush,
      HandType.royalFlush => SlyMood.royalFlush,
    };
    // A weak shape that still lands a huge score leaves Sly speechless.
    if (result.total >= math.max(500, target * 0.7) &&
        (mood == SlyMood.highCard || mood == SlyMood.pair)) {
      return SlyMood.unbelievable;
    }
    return mood;
  }

  void _saySly(SlyMood mood) {
    final set = slyQuips[mood];
    if (set == null || !mounted) return;
    if (mood == SlyMood.laughing) _sfx.play('sly_laugh');
    _reactSly(
      mood: mood,
      expression: set.expression,
      speech: set.pick(_slyRandom),
      priority: _slyPriority(mood),
      motion: _slyMotion(mood),
      hold: slyHoldFor(mood),
    );
  }

  void _reactSly({
    required SlyMood mood,
    required SlyExpression expression,
    required String speech,
    required int priority,
    required SlyMotionProfile motion,
    required Duration hold,
  }) {
    if (!mounted) return;
    final current = _slyReaction.value;
    if (current != null && current.priority > priority) return;
    _slyHold?.cancel();
    _slyReaction.value = SlyReaction(
      mood: mood,
      priority: priority,
      expression: expression,
      speech: speech,
      motion: motion,
      hold: hold,
      sequence: ++_slySequence,
    );
    _slyHold = Timer(hold, () {
      if (mounted && _slyReaction.value?.sequence == _slySequence) {
        _slyReaction.value = null;
      }
    });
  }

  int _slyPriority(SlyMood mood) => switch (mood) {
    SlyMood.royalFlush ||
    SlyMood.straightFlush ||
    SlyMood.unbelievable ||
    SlyMood.sevenHit => 5,
    SlyMood.fullHouse ||
    SlyMood.quads ||
    SlyMood.clutch ||
    SlyMood.sevenMiss => 4,
    SlyMood.straight || SlyMood.flush || SlyMood.trips || SlyMood.clear => 3,
    SlyMood.pair ||
    SlyMood.twoPair ||
    SlyMood.modifier ||
    SlyMood.scared ||
    SlyMood.impressed => 2,
    _ => 1,
  };

  SlyMotionProfile _slyMotion(SlyMood mood) => switch (mood) {
    SlyMood.scared ||
    SlyMood.clutch ||
    SlyMood.sevenMiss => SlyMotionProfile.tremble,
    SlyMood.unbelievable ||
    SlyMood.quads ||
    SlyMood.straightFlush ||
    SlyMood.royalFlush ||
    SlyMood.sevenHit => SlyMotionProfile.rock,
    SlyMood.meh => SlyMotionProfile.none,
    _ => SlyMotionProfile.pop,
  };

  Future<void> _startVictorySequence() async {
    if (_victorySequenceStarted || !mounted) return;
    _victorySequenceStarted = true;
    // Let the won-state title and safely banked totals render first. The ad
    // remains in its existing single approved slot, but never precedes the
    // player's understanding that the run was won.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
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

  /// Plays the arcade death pull-over as a fullscreen route, then shows the ad.
  Future<void> _playDeathScreen({required bool terminated}) async {
    if (_deathScreenShown || !mounted) return;
    _deathScreenShown = true;
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        pageBuilder: (routeContext, _, _) => DeathScreenOverlay(
          terminated: terminated,
          onFinished: () {
            if (Navigator.of(routeContext).canPop()) {
              Navigator.of(routeContext).pop();
            }
          },
        ),
      ),
    );
    if (!mounted) return;
    await _showTerminalAdOnce();
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
        builder: (context, _) {
          _maybeStartRoundIntro();
          final screen = switch (game.phase) {
            RunPhase.game => _buildRunTable(),
            RunPhase.shop => _buildShop(),
            RunPhase.revive => _buildRevive(),
            RunPhase.victory => _buildVictory(),
            RunPhase.ended => _buildResult(),
          };
          final inGame = game.phase == RunPhase.game;
          final layers = <Widget>[screen];
          if (inGame) {
            layers.add(
              Positioned.fill(
                child: _ScoringFinaleLayer(timeline: game.scoringTimeline),
              ),
            );
          }
          // "WILD!" / "MEGA!" stamped over the table as a hand resolves.
          if (inGame && _calloutWord != null) {
            layers.add(
              Positioned.fill(
                child: _CalloutStamp(
                  key: ValueKey('callout-$_calloutSeq'),
                  word: _calloutWord!,
                  color: _calloutColor ?? const Color(0xFFF7C548),
                ),
              ),
            );
          }
          if (inGame && _introVisible) {
            final boss = game.state.hasBossModifier;
            final mods = game.state.modifiers;
            final detail = mods.isEmpty
                ? ''
                : '${mods.map((m) => m.displayName).join(' + ')} — '
                      '${mods.first.description} · ';
            // The Sly deal sprite was removed at the player's request — it read
            // as messy at the start of each Heat. Only the intro card remains.
            layers.add(
              Positioned.fill(
                child: RoundIntroOverlay(
                  kicker: boss
                      ? 'BOSS TABLE'
                      : mods.isNotEmpty
                      ? 'MODIFIER ACTIVE'
                      : 'NEW DEAL',
                  title:
                      '${game.state.mode == RunMode.gauntlet ? 'GAUNTLET' : 'HEAT'}'
                      ' ${game.state.stage}',
                  subtitle: '${detail}Target ${game.state.target}',
                  boss: boss,
                  onFinished: () {
                    if (mounted) setState(() => _introVisible = false);
                  },
                ),
              ),
            );
          }
          if (layers.length == 1) return screen;
          return Stack(children: layers);
        },
      ),
    );
  }

  /// Fires the Heat wash once per Heat, on entry to the table.
  void _maybeStartRoundIntro() {
    if (game.phase != RunPhase.game) return;
    final stage = game.state.stage;
    if (_introShownForStage == stage) return;
    _introShownForStage = stage;
    _haptics.success();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _safeSetState(() => _introVisible = true);
      // Sly still greets in his bubble; a modifier table gets the warning.
      _saySly(game.state.hasAnyModifier ? SlyMood.modifier : SlyMood.greet);
    });
  }

  Widget _buildRunTable() {
    final selectedHand = <PlayingCard>[
      for (final card in game.hand)
        card.copyWith(selected: game.selectedCardIds.contains(card.uid)),
    ];
    final score = game.previewSelected();
    return RunTableScreen(
      state: game.state,
      hand: selectedHand,
      slySpeech: _slySpeech(score),
      slyExpression: _slyExpression(score),
      slySkin: _slySkin(widget.appController.account.equipped.sly),
      tableFeltId: widget.appController.account.equipped.table,
      score: score,
      scoringTimeline: game.scoringTimeline,
      slyReaction: _slyReaction,
      stakeText: game.stake > 0
          ? '${game.stake} → ${game.stakePayoutAmount}'
          : null,
      sortLabel: game.sortMode == HandSortMode.rank ? 'Rank' : 'Suit',
      busy: game.isBusy,
      onToggleCard: (index) {
        if (index < 0 || index >= game.hand.length) return;
        final id = game.hand[index].uid;
        if (id != null) {
          // The WebView's two-tone pick-up/put-down, not a generic click.
          _sfx.play(game.selectedCardIds.contains(id) ? 'deselect' : 'select');
          _haptics.selection();
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
          ? () {
              _haptics.play();
              unawaited(_soundAndAct(game.playSelected()));
            }
          : null,
      onDiscard: game.canDiscard
          ? () {
              _haptics.discard();
              _sfx.play('discard');
              _saySly(SlyMood.discard);
              unawaited(_act(game.discardSelected()));
            }
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
          final result = await game.sellJoker(index);
          if (result.ok) {
            _sfx.play('sell');
          } else if (mounted) {
            _message(result.message);
          }
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
      celebration: true,
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
      final result = await game.buyJoker(joker.id);
      if (result.ok) {
        _sfx.play('buy');
      } else if (mounted) {
        _message(result.message);
      }
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
      final result = await game.buyJoker(joker.id, swapIndex: swapIndex);
      if (result.ok) {
        _sfx.play('buy');
      } else if (mounted) {
        _message(result.message);
      }
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
      final result = await game.buySupply(supply.id, selection);
      if (result.ok) {
        _sfx.play('buy');
      } else if (mounted) {
        _message(result.message);
      }
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

  void _message(String message) => showWildcardToast(context, message);

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
    this.celebration = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  final bool danger;
  final bool celebration;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? context.wildcard.coral : context.wildcard.gold;
    final content = SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 34, 18, 28),
        children: [
          Icon(icon, color: accent, size: 58),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: danger ? const Color(0xFFFFE3DE) : accent,
              fontFamily: 'Bungee',
              fontSize: danger ? 31 : 27,
              height: 1.05,
              letterSpacing: danger ? 1.2 : 0,
              shadows: danger
                  ? const [
                      Shadow(color: Color(0xCC2A0000), offset: Offset(0, 2)),
                      Shadow(color: Color(0x99FF3B2F), blurRadius: 18),
                    ]
                  : null,
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
    );
    return Scaffold(
      backgroundColor: const Color(0xFF080414),
      body: WildcardBackground(
        room: WildcardRoom.themedHome,
        energy: celebration ? 1 : 0,
        momentPulse: celebration ? 1 : 0,
        // The WebView build washed the whole screen red when a run died, and
        // that punch was missing here. Painted over the room art, under the
        // content, so the text stays legible.
        child: danger
            ? Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(0, -0.35),
                            radius: 1.15,
                            colors: [Color(0x8CFF2A1F), Color(0xD9370006)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  content,
                ],
              )
            : content,
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

class _ScoringFinaleLayer extends StatelessWidget {
  const _ScoringFinaleLayer({required this.timeline});

  final ValueListenable<ScoringPresentation> timeline;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<ScoringPresentation>(
        valueListenable: timeline,
        builder: (context, presentation, _) {
          if (!presentation.finalScoreVisible || presentation.result == null) {
            return const SizedBox.shrink();
          }
          return _FloatingFinalScore(
            key: ValueKey('final-score-${presentation.sequence}'),
            total: presentation.result!.total,
            significant:
                presentation.result!.handType.index >=
                    HandType.straightFlush.index ||
                presentation.result!.total >= 1000,
          );
        },
      ),
    );
  }
}

class _FloatingFinalScore extends StatefulWidget {
  const _FloatingFinalScore({
    required this.total,
    required this.significant,
    super.key,
  });

  final int total;
  final bool significant;

  @override
  State<_FloatingFinalScore> createState() => _FloatingFinalScoreState();
}

class _FloatingFinalScoreState extends State<_FloatingFinalScore>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1040),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final effects = EffectsProfile.resolve(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = (constraints.maxWidth * 0.14).clamp(40.0, 72.0);
        return Align(
          alignment: const Alignment(0, -0.04),
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                final entry = Curves.easeOutBack.transform(
                  (t / 0.24).clamp(0.0, 1.0),
                );
                final exit = Curves.easeInCubic.transform(
                  ((t - 0.72) / 0.28).clamp(0.0, 1.0),
                );
                final count = Curves.easeOutCubic.transform(
                  (t / .42).clamp(0.0, 1.0),
                );
                return Opacity(
                  opacity: (1 - exit).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -(reduced ? 12 : 62) * t),
                    child: Transform.scale(
                      scale: reduced
                          ? 0.94 + entry * 0.06
                          : 0.58 + entry * 0.42,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          if (widget.significant &&
                              !reduced &&
                              effects.particleScale > 0)
                            SizedBox(
                              width: 240,
                              height: 150,
                              child: CustomPaint(
                                painter: _FinaleParticlePainter(
                                  intensity: effects.particleScale,
                                ),
                              ),
                            ),
                          Text(
                            '+${_formatScore((widget.total * count).round())}',
                            style: TextStyle(
                              color: const Color(0xFFF7C548),
                              fontFamily: 'Bungee',
                              fontSize: fontSize,
                              height: 1,
                              shadows: const [
                                Shadow(
                                  color: Color(0xFF32150B),
                                  offset: Offset(0, 5),
                                  blurRadius: 1,
                                ),
                                Shadow(
                                  color: Color(0xCC000000),
                                  blurRadius: 8,
                                ),
                                Shadow(
                                  color: Color(0x99F7C548),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _FinaleParticlePainter extends CustomPainter {
  const _FinaleParticlePainter({required this.intensity});

  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2);
    final count = (18 * intensity).round().clamp(8, 24);
    for (var index = 0; index < count; index++) {
      final angle = index / count * math.pi * 2;
      final radius = 54.0 + (index * 17 % 38);
      final point = origin + Offset(math.cos(angle), math.sin(angle)) * radius;
      final paint = Paint()
        ..color =
            (index.isEven ? const Color(0xFFF7C548) : const Color(0xFFB794FF))
                .withValues(alpha: 0.62);
      canvas.drawCircle(point, 1.8 + (index % 3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FinaleParticlePainter oldDelegate) =>
      oldDelegate.intensity != intensity;
}

String _formatScore(int value) {
  final digits = value.abs().toString();
  final output = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) output.write(',');
    output.write(digits[index]);
  }
  return '${value < 0 ? '-' : ''}$output';
}

/// The end-of-hand callout ("NICE!" → "WILD!") stamped over the table.
///
/// Mirrors the WebView's `calloutpop`: slams in oversized, settles with an
/// overshoot, holds, then fades while lifting away.
class _CalloutStamp extends StatefulWidget {
  const _CalloutStamp({required this.word, required this.color, super.key});

  final String word;
  final Color color;

  @override
  State<_CalloutStamp> createState() => _CalloutStampState();
}

class _CalloutStampState extends State<_CalloutStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final effects = EffectsProfile.resolve(context);
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.34),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value;
            final entry = Curves.easeOutBack.transform((t / 0.22).clamp(0, 1));
            final exit = Curves.easeIn.transform(
              ((t - 0.72) / 0.28).clamp(0, 1),
            );
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Suit-symbol sparks burst outward behind the word.
                if (!reduced && effects.particleScale > .4)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CalloutSparkPainter(
                        progress: t,
                        color: widget.color,
                        intensity: effects.particleScale,
                      ),
                    ),
                  ),
                Opacity(
                  opacity: ((t < 0.05 ? t / 0.05 : 1) * (1 - exit)).clamp(
                    0.0,
                    1.0,
                  ),
                  child: Transform.translate(
                    offset: Offset(0, -26 * exit),
                    child: Transform.scale(
                      scale: 2.1 - 1.1 * entry,
                      child: Transform.rotate(angle: -0.06, child: child),
                    ),
                  ),
                ),
              ],
            );
          },
          child: Text(
            widget.word,
            style: TextStyle(
              color: widget.color,
              fontFamily: 'Bungee',
              fontSize: 46,
              height: 1,
              letterSpacing: 1.5,
              shadows: [
                const Shadow(color: Color(0xE6000000), offset: Offset(0, 3)),
                Shadow(
                  color: widget.color.withValues(alpha: 0.65),
                  blurRadius: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Radiating suit-glyph sparks behind a callout — the WebView's `sparks()`
/// moment, native. Deterministic per-index so the painter allocates nothing.
class _CalloutSparkPainter extends CustomPainter {
  const _CalloutSparkPainter({
    required this.progress,
    required this.color,
    required this.intensity,
  });

  final double progress;
  final Color color;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 0.9) return;
    final origin = Offset(size.width / 2, size.height / 2);
    final p = Curves.easeOutCubic.transform((progress / 0.7).clamp(0.0, 1.0));
    final fade = (1 - ((progress - 0.45) / 0.45)).clamp(0.0, 1.0);
    final count = (16 * intensity).round().clamp(8, 20);
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final seed = i * 97.0;
      final angle = (i / count) * math.pi * 2 + math.sin(seed) * 0.3;
      final dist = (70 + (seed % 60)) * p;
      final point = Offset(
        origin.dx + math.cos(angle) * dist,
        origin.dy + math.sin(angle) * dist - p * 8,
      );
      final glyphColor = i.isEven ? color : const Color(0xFFFFF3C8);
      paint.color = glyphColor.withValues(alpha: fade);
      final radius = 2.2 + (i % 3) * 1.2;
      if (i.isEven) {
        canvas.drawCircle(point, radius, paint);
      } else {
        canvas.save();
        canvas.translate(point.dx, point.dy);
        canvas.rotate(math.pi / 4 + p * .4);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: radius * 1.6,
            height: radius * 1.6,
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CalloutSparkPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.intensity != intensity;
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
