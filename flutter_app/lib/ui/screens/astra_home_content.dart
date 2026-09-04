import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/wildcard_background.dart';
import '../widgets/wildcard_button.dart';
import '../wildcard_theme.dart';

/// The field-test home keeps one next step visible without burying the art.
/// Milestone state is supplied by the account layer; this widget never awards it.
class AstraHomeContent extends StatelessWidget {
  const AstraHomeContent({
    required this.coins,
    required this.bestHeat,
    required this.hasSavedRun,
    required this.onPlay,
    required this.onResume,
    required this.onJourney,
    required this.onVault,
    required this.onShop,
    required this.onCabinet,
    required this.onMissions,
    required this.onSettings,
    required this.onMore,
    required this.onDailyReward,
    this.backgroundAsset,
    this.goalTitle,
    this.goalDescription,
    this.goalReward,
    this.goalProgress = 0,
    this.goalProgressLabel = '',
    this.goalReady = false,
    this.dailyRewardAvailable = false,
    this.dailyRewardLabel = '',
    this.cabinetAttention = false,
    this.missionsAttention = false,
    super.key,
  });

  final int coins;
  final int bestHeat;
  final bool hasSavedRun;
  final String? backgroundAsset;
  final String? goalTitle;
  final String? goalDescription;
  final String? goalReward;
  final double goalProgress;
  final String goalProgressLabel;
  final bool goalReady;
  final bool dailyRewardAvailable;
  final String dailyRewardLabel;
  final bool cabinetAttention;
  final bool missionsAttention;
  final VoidCallback onPlay;
  final VoidCallback onResume;
  final VoidCallback onJourney;
  final VoidCallback onVault;
  final VoidCallback onShop;
  final VoidCallback onCabinet;
  final VoidCallback onMissions;
  final VoidCallback onSettings;
  final VoidCallback onMore;
  final VoidCallback onDailyReward;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Scaffold(
      backgroundColor: tokens.ink,
      body: WildcardBackground(
        surface: WildcardUiSurface.home,
        asset: backgroundAsset,
        tintStrength: .85,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final heroHeight = (constraints.maxHeight * .14)
                  .clamp(54.0, 114.0)
                  .toDouble();
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _label(
                                  context,
                                  'ASTRA 6  /  FIELD TEST',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.ink.withValues(alpha: .88),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: tokens.gold.withValues(alpha: .5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.toll_rounded,
                                    color: tokens.gold,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${math.max(0, coins)}',
                                    style: _text(
                                      tokens.gold,
                                      15,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: heroHeight),
                        Semantics(
                          image: true,
                          label: 'WILDCARD Astra',
                          child: const AspectRatio(
                            aspectRatio: 2191 / 718,
                            child: Image(
                              image: AssetImage(
                                'assets/art/wildcard-logo-v692.webp',
                              ),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Text(
                          bestHeat > 0
                              ? 'YOUR BEST: HEAT $bestHeat  ·  BUILD SOMETHING BETTER'
                              : 'CHOOSE YOUR JOKER. BUILD YOUR RUN.',
                          textAlign: TextAlign.center,
                          style: _text(
                            tokens.cream,
                            11,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        WildcardButton(
                          key: const Key('astra-primary-play'),
                          label: hasSavedRun ? 'Continue Run' : 'Play',
                          icon: const Icon(Icons.play_arrow_rounded),
                          onPressed: hasSavedRun ? onResume : onPlay,
                          variant: WildcardButtonVariant.primary,
                          minHeight: 64,
                          fontSize: 20,
                        ),
                        if (hasSavedRun)
                          TextButton(
                            onPressed: onPlay,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            child: const Text('Choose a new run'),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 7, bottom: 10),
                            child: Text(
                              'Every Normal run starts with a free Joker draft.',
                              textAlign: TextAlign.center,
                              style: _text(tokens.creamDim, 12),
                            ),
                          ),
                        _journeyCard(context),
                        if (dailyRewardAvailable) ...[
                          const SizedBox(height: 10),
                          WildcardButton(
                            label: dailyRewardLabel,
                            icon: const Icon(Icons.card_giftcard_rounded),
                            onPressed: onDailyReward,
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 12,
                            minHeight: 50,
                            showIconFrame: false,
                            attention: true,
                          ),
                        ],
                        const SizedBox(height: 14),
                        _menuPair(
                          _menuButton(
                            'Vault',
                            Icons.lock_open_rounded,
                            onVault,
                          ),
                          _menuButton(
                            'Wardrobe & Shop',
                            Icons.diamond_outlined,
                            onShop,
                          ),
                        ),
                        const SizedBox(height: 9),
                        _menuPair(
                          _menuButton(
                            'Cabinet',
                            Icons.workspace_premium_outlined,
                            onCabinet,
                            attention: cabinetAttention,
                          ),
                          _menuButton(
                            'Missions',
                            Icons.flag_outlined,
                            onMissions,
                            attention: missionsAttention,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: onSettings,
                                icon: const Icon(
                                  Icons.settings_outlined,
                                  size: 18,
                                ),
                                label: const Text('Settings'),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: onMore,
                                icon: const Icon(Icons.more_horiz_rounded),
                                label: const Text('More'),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Local field test · separate progress · no real purchases',
                          textAlign: TextAlign.center,
                          style: _text(tokens.creamDim, 10),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _journeyCard(BuildContext context) {
    final tokens = context.wildcard;
    final accent = goalReady ? tokens.gold : tokens.mint;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: const Key('astra-journey-entry'),
        onTap: onJourney,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.surfaceStrong.withValues(alpha: .97),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: .7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goalReady ? 'REWARD READY' : 'YOUR NEXT MILESTONE',
                      style: _text(accent, 10, weight: FontWeight.w700),
                    ),
                  ),
                  if (goalReward != null)
                    Text(
                      goalReward!,
                      style: _text(tokens.gold, 12, weight: FontWeight.w700),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: accent, size: 19),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                goalTitle ?? 'Build your first engine',
                style: _text(tokens.cream, 17, weight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                goalDescription ??
                    'Pick a starter and see how far it takes you.',
                style: _text(tokens.creamDim, 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: goalProgress.clamp(0.0, 1.0).toDouble(),
                        minHeight: 5,
                        backgroundColor: accent.withValues(alpha: .13),
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    ),
                  ),
                  if (goalProgressLabel.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Text(
                      goalProgressLabel,
                      style: _text(tokens.cream, 11, weight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuButton(
    String title,
    IconData icon,
    VoidCallback onPressed, {
    bool attention = false,
  }) => WildcardButton(
    label: title,
    icon: Icon(icon, size: 21),
    onPressed: onPressed,
    minHeight: 58,
    fontFamily: 'SpaceGrotesk',
    fontSize: 13,
    showIconFrame: false,
    attention: attention,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
  );

  Widget _menuPair(Widget left, Widget right) => Row(
    children: [
      Expanded(child: left),
      const SizedBox(width: 9),
      Expanded(child: right),
    ],
  );

  Widget _label(BuildContext context, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: context.wildcard.ink.withValues(alpha: .85),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      value,
      style: _text(context.wildcard.mint, 10, weight: FontWeight.w700),
    ),
  );

  TextStyle _text(
    Color color,
    double size, {
    FontWeight weight = FontWeight.w500,
  }) => TextStyle(
    color: color,
    fontFamily: 'SpaceGrotesk',
    fontSize: size,
    fontWeight: weight,
    height: 1.3,
  );
}
