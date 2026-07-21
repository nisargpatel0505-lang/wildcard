import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_constants.dart';
import '../core/daily_utc_date.dart';
import '../domain/account_state.dart';
import '../domain/economy.dart';
import '../domain/game_rules.dart';
import '../domain/joker_catalog.dart';
import '../game/game_controller.dart';
import '../game/game_models.dart';
import '../ui/wildcard_ui.dart';
import 'app_controller.dart';
import 'screens/cabinet_screen.dart';
import 'screens/game_host_screen.dart';
import 'screens/missions_screen.dart';
import 'screens/mode_picker_screen.dart';
import 'screens/more_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shop_hub_screen.dart';
import 'screens/tutorial_screen.dart';
import 'screens/vault_screen.dart';

class WildcardApp extends StatefulWidget {
  const WildcardApp({required this.controller, super.key});

  final AppController controller;

  @override
  State<WildcardApp> createState() => _WildcardAppState();
}

class _WildcardAppState extends State<WildcardApp> {
  final navigatorKey = GlobalKey<NavigatorState>();
  bool acceptingPrivacy = false;
  bool launchingRun = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: AppConstants.appName,
        theme: WildcardTheme.build(
          themeId: _themeId(widget.controller.account.equipped.theme),
        ),
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.35,
          child: child!,
        ),
        home: Builder(
          builder: (context) => Stack(
            fit: StackFit.expand,
            children: [
              WildcardHomeScreen(
                coins: widget.controller.account.coins,
                bestHeat: widget.controller.account.bestHeat,
                playerTitle: widget.controller.equippedTitleName,
                hasSavedRun: widget.controller.hasResumableRun,
                dailyRewardAvailable:
                    widget.controller.dailyLoginOffer.available,
                weeklyMissionsAttention:
                    widget.controller.weeklyMissionsNeedAttention,
                soundEnabled: !widget.controller.account.muted,
                musicEnabled: widget.controller.account.musicOn,
                fastScoring:
                    widget.controller.account.speed == ScoringPace.fast,
                onResume: () => _resumeRun(context),
                onNewRun: () => _openModePicker(context),
                onJokerUnlocks: () =>
                    _push(context, VaultScreen(controller: widget.controller)),
                onShop: () => _push(
                  context,
                  ShopHubScreen(controller: widget.controller),
                ),
                onCabinet: () => _push(
                  context,
                  CabinetScreen(controller: widget.controller),
                ),
                onWeeklyMissions: () => _push(
                  context,
                  MissionsScreen(controller: widget.controller),
                ),
                onSettings: () => _push(
                  context,
                  SettingsScreen(controller: widget.controller),
                ),
                onMore: () =>
                    _push(context, MoreScreen(controller: widget.controller)),
                onDailyReward: () => _claimDaily(context),
                onToggleSound: () => widget.controller.mutateAccount(
                  (account) => account.muted = !account.muted,
                ),
                onToggleMusic: () => widget.controller.mutateAccount(
                  (account) => account.musicOn = !account.musicOn,
                ),
                onToggleScoringSpeed: () => widget.controller.mutateAccount(
                  (account) => account.speed = account.speed == ScoringPace.fast
                      ? ScoringPace.normal
                      : ScoringPace.fast,
                ),
              ),
              if (!widget.controller.privacyAccepted)
                WildcardPrivacyGate(
                  accepting: acceptingPrivacy,
                  onAccept: _acceptPrivacy,
                  onOpenPrivacyPolicy: () => launchUrl(
                    Uri.parse(AppConstants.privacyPolicyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acceptPrivacy() async {
    if (acceptingPrivacy) return;
    setState(() => acceptingPrivacy = true);
    try {
      await widget.controller.acceptPrivacyPolicy();
    } finally {
      if (mounted) setState(() => acceptingPrivacy = false);
    }
  }

  Future<void> _claimDaily(BuildContext context) async {
    final reward = await widget.controller.claimDailyLoginReward();
    if (context.mounted && reward > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Daily reward · +$reward coins')));
    }
  }

  void _openModePicker(BuildContext context) {
    _push(
      context,
      ModePickerScreen(
        account: widget.controller.account,
        onLaunch: (request) => unawaited(_launchRun(request)),
        onOpenTutorial: () => _push(
          context,
          TutorialScreen(onComplete: widget.controller.completeTutorial),
        ),
      ),
    );
  }

  Future<void> _launchRun(RunLaunchRequest request) async {
    if (launchingRun) return;
    launchingRun = true;
    final dailyDate = request.mode == RunMode.daily ? dailyUtcDateKey() : '';
    final guided =
        request.mode == RunMode.normal &&
        !widget.controller.account.firstRunStarted;
    final starter = request.startJokerId == null
        ? null
        : jokersById[request.startJokerId];
    try {
      final game = await GameController.startNew(
        config: GameRunConfig(
          rngSeed: math.Random.secure().nextInt(0x7fffffff),
          mode: request.mode,
          difficulty: request.difficulty,
          dailyDate: dailyDate,
          unlockedJokerIds: widget.controller.account.unlockedJokerIds,
          initialJokerIds: guided ? const ['copper', 'polish'] : const [],
          startBoostJokerId: starter?.id,
          startBoostCost: starter == null ? 0 : starterJokerPrice(starter),
          stake: request.mode == RunMode.daily ? 0 : request.stake,
          guidedFirstRun: guided,
          scoringPace: widget.controller.account.speed,
        ),
        callbacks: widget.controller.gamePersistenceCallbacks(
          dailyDate: dailyDate,
        ),
      );
      widget.controller.pi.queueRunStart(request.mode.name);
      final navigator = navigatorKey.currentState;
      if (navigator == null) {
        game.dispose();
        return;
      }
      // Close the mode picker before placing the live run on the stack.
      if (navigator.canPop()) navigator.pop();
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => GameHostScreen(
            appController: widget.controller,
            gameController: game,
          ),
        ),
      );
    } catch (error) {
      _message('Run could not start: $error');
    } finally {
      launchingRun = false;
    }
  }

  Future<void> _resumeRun(BuildContext context) async {
    if (launchingRun || widget.controller.activeRunJson == null) return;
    launchingRun = true;
    try {
      final game = await GameController.resume(
        encoded: widget.controller.activeRunJson!,
        callbacks: widget.controller.gamePersistenceCallbacks(),
        unlockedJokerIds: widget.controller.account.unlockedJokerIds,
        pace: widget.controller.account.speed,
      );
      widget.controller.pi.queueRunStart(game.state.mode.name);
      final navigator = navigatorKey.currentState;
      if (navigator == null) {
        game.dispose();
        return;
      }
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => GameHostScreen(
            appController: widget.controller,
            gameController: game,
            resumed: true,
          ),
        ),
      );
    } catch (error) {
      _message('Saved run could not resume: $error');
    } finally {
      launchingRun = false;
    }
  }

  Future<void> _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  void _message(String value) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  static WildcardThemeId _themeId(String id) => switch (id) {
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
}
