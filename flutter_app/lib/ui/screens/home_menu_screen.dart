import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/wildcard_background.dart';
import '../widgets/wildcard_button.dart';
import '../wildcard_theme.dart';

void _noOp() {}

/// Phone-first reconstruction of the v7.1.0 WILDCARD home menu.
///
/// The screen is deliberately stateless: app/domain state can be connected by
/// passing values and callbacks without pulling services into the UI layer.
class WildcardHomeScreen extends StatelessWidget {
  const WildcardHomeScreen({
    this.coins = 0,
    this.bestHeat,
    this.playerTitle,
    this.hasSavedRun = false,
    this.dailyRewardAvailable = false,
    this.weeklyMissionsAttention = false,
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.fastScoring = false,
    this.backgroundAsset,
    this.onResume,
    this.onNewRun,
    this.onJokerUnlocks,
    this.onShop,
    this.onCabinet,
    this.onWeeklyMissions,
    this.onSettings,
    this.onMore,
    this.onDailyReward,
    this.onToggleSound,
    this.onToggleMusic,
    this.onToggleScoringSpeed,
    super.key,
  });

  final int coins;
  final int? bestHeat;
  final String? playerTitle;
  final bool hasSavedRun;
  final bool dailyRewardAvailable;
  final bool weeklyMissionsAttention;
  final bool soundEnabled;
  final bool musicEnabled;
  final bool fastScoring;
  final String? backgroundAsset;

  final VoidCallback? onResume;
  final VoidCallback? onNewRun;
  final VoidCallback? onJokerUnlocks;
  final VoidCallback? onShop;
  final VoidCallback? onCabinet;
  final VoidCallback? onWeeklyMissions;
  final VoidCallback? onSettings;
  final VoidCallback? onMore;
  final VoidCallback? onDailyReward;
  final VoidCallback? onToggleSound;
  final VoidCallback? onToggleMusic;
  final VoidCallback? onToggleScoringSpeed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080414),
      body: WildcardBackground(
        asset: backgroundAsset,
        child: SafeArea(
          minimum: const EdgeInsets.only(bottom: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final metrics = _HomeMetrics.from(
                constraints.biggest,
                fullWidthButtonCount:
                    1 + (hasSavedRun ? 1 : 0) + (dailyRewardAvailable ? 1 : 0),
              );
              return Stack(
                children: [
                  Positioned.fill(
                    child: _buildScrollableMenu(context, metrics),
                  ),
                  Positioned(
                    top: metrics.compact ? 5 : 10,
                    right: metrics.horizontalPadding,
                    child: _CoinBadge(coins: math.max(0, coins)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableMenu(BuildContext context, _HomeMetrics metrics) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        metrics.horizontalPadding,
        0,
        metrics.horizontalPadding,
        8,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: metrics.viewportHeight - 8),
        child: Column(
          children: [
            SizedBox(height: metrics.heroGap),
            Semantics(
              image: true,
              label: 'WILDCARD',
              child: SizedBox(
                width: metrics.logoWidth,
                child: const AspectRatio(
                  aspectRatio: 2191 / 718,
                  child: Image(
                    image: AssetImage('assets/art/wildcard-logo-v692.webp'),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
            SizedBox(height: metrics.compact ? 2 : 4),
            _ProgressChips(bestHeat: bestHeat, playerTitle: playerTitle),
            SizedBox(height: metrics.compact ? 8 : 11),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _buildButtons(metrics),
            ),
            SizedBox(height: metrics.bottomSpacer),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WildcardSquareButton(
                    size: metrics.utilityButtonSize,
                    icon: Icon(
                      soundEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                    ),
                    semanticLabel: soundEnabled
                        ? 'Mute sound effects'
                        : 'Enable sound effects',
                    onPressed: onToggleSound ?? _noOp,
                    active: soundEnabled,
                  ),
                  SizedBox(width: metrics.compact ? 8 : 10),
                  WildcardSquareButton(
                    size: metrics.utilityButtonSize,
                    icon: Icon(
                      musicEnabled
                          ? Icons.music_note_rounded
                          : Icons.music_off_rounded,
                    ),
                    semanticLabel: musicEnabled ? 'Mute music' : 'Enable music',
                    onPressed: onToggleMusic ?? _noOp,
                    active: musicEnabled,
                  ),
                  SizedBox(width: metrics.compact ? 8 : 10),
                  WildcardSquareButton(
                    size: metrics.utilityButtonSize,
                    icon: Icon(
                      fastScoring
                          ? Icons.fast_forward_rounded
                          : Icons.movie_filter_rounded,
                    ),
                    semanticLabel: fastScoring
                        ? 'Use normal scoring pace'
                        : 'Use fast scoring pace',
                    onPressed: onToggleScoringSpeed ?? _noOp,
                    active: fastScoring,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtons(_HomeMetrics metrics) {
    final tileText = metrics.narrow ? 9.6 : (metrics.compact ? 11.3 : 13.2);
    final tilePadding = metrics.narrow
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    final gap = metrics.buttonGap;
    return Column(
      children: [
        if (hasSavedRun) ...[
          WildcardButton(
            label: 'Resume Run',
            icon: const Icon(Icons.play_arrow_rounded),
            onPressed: onResume ?? _noOp,
            variant: WildcardButtonVariant.secondary,
            minHeight: metrics.primaryButtonHeight,
            fontSize: metrics.compact ? 15 : 17,
          ),
          SizedBox(height: gap),
        ],
        WildcardButton(
          label: 'New Run',
          icon: const Icon(Icons.play_arrow_rounded),
          onPressed: onNewRun ?? _noOp,
          variant: WildcardButtonVariant.primary,
          minHeight: metrics.primaryButtonHeight,
          fontSize: metrics.compact ? 16 : 18,
        ),
        SizedBox(height: gap),
        _MenuRow(
          gap: gap,
          height: metrics.tileHeight,
          children: [
            WildcardButton(
              label: 'Joker Unlocks',
              icon: const Text('J'),
              onPressed: onJokerUnlocks ?? _noOp,
              minHeight: metrics.tileHeight,
              fontSize: tileText,
              padding: tilePadding,
            ),
            WildcardButton(
              label: 'Shop',
              icon: const Icon(Icons.diamond_outlined),
              onPressed: onShop ?? _noOp,
              minHeight: metrics.tileHeight,
              fontSize: tileText,
              padding: tilePadding,
            ),
          ],
        ),
        SizedBox(height: gap),
        _MenuRow(
          gap: gap,
          height: metrics.tileHeight,
          children: [
            WildcardButton(
              label: 'Cabinet',
              icon: const Icon(Icons.workspace_premium_outlined),
              onPressed: onCabinet ?? _noOp,
              minHeight: metrics.tileHeight,
              fontSize: tileText,
              padding: tilePadding,
            ),
            WildcardButton(
              label: 'Weekly Missions',
              icon: const Icon(Icons.check_rounded),
              onPressed: onWeeklyMissions ?? _noOp,
              minHeight: metrics.tileHeight,
              fontSize: tileText,
              padding: tilePadding,
              attention: weeklyMissionsAttention,
            ),
          ],
        ),
        SizedBox(height: gap),
        _MenuRow(
          gap: gap,
          height: metrics.tileHeight,
          children: [
            WildcardButton(
              label: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: onSettings ?? _noOp,
              minHeight: metrics.tileHeight,
              fontSize: tileText,
              padding: tilePadding,
              variant: WildcardButtonVariant.ghost,
            ),
            WildcardButton(
              label: 'More',
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: onMore ?? _noOp,
              minHeight: metrics.tileHeight,
              fontSize: tileText,
              padding: tilePadding,
              variant: WildcardButtonVariant.ghost,
            ),
          ],
        ),
        if (dailyRewardAvailable) ...[
          SizedBox(height: gap),
          WildcardButton(
            label: 'Daily Reward',
            icon: const Icon(Icons.star_rounded),
            onPressed: onDailyReward ?? _noOp,
            minHeight: metrics.primaryButtonHeight,
            fontSize: metrics.compact ? 14 : 16,
            attention: true,
          ),
        ],
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.children,
    required this.gap,
    required this.height,
  });

  final List<Widget> children;
  final double gap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: children[0]),
          SizedBox(width: gap),
          Expanded(child: children[1]),
        ],
      ),
    );
  }
}

class _ProgressChips extends StatelessWidget {
  const _ProgressChips({required this.bestHeat, required this.playerTitle});

  final int? bestHeat;
  final String? playerTitle;

  @override
  Widget build(BuildContext context) {
    final title = playerTitle?.trim();
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 5,
      children: [
        _StatusChip(
          label: 'BEST HEAT ${bestHeat == null ? '—' : math.max(0, bestHeat!)}',
        ),
        if (title != null && title.isNotEmpty)
          _StatusChip(label: '“${title.toUpperCase()}”'),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Container(
      constraints: const BoxConstraints(minHeight: 26, maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xB8060814),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.line.withValues(alpha: 0.86)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: tokens.gold,
          fontFamily: 'Bungee',
          fontSize: 9,
          height: 1,
          letterSpacing: 0.55,
        ),
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Semantics(
      label: '$coins account coins',
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
        decoration: BoxDecoration(
          color: const Color(0xC2050812),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tokens.line.withValues(alpha: 0.92)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x61000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _CoinDisc(),
            const SizedBox(width: 7),
            Text(
              coins.toString(),
              style: TextStyle(
                color: tokens.gold,
                fontFamily: 'Bungee',
                fontSize: 13,
                height: 1,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinDisc extends StatelessWidget {
  const _CoinDisc();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.35),
          colors: [Color(0xFFFFF6D0), Color(0xFFFFD75E), Color(0xFFA87718)],
          stops: [0, 0.46, 1],
        ),
        border: Border.all(color: const Color(0xFFB8860B), width: 1.4),
        boxShadow: const [BoxShadow(color: Color(0x99FFD75E), blurRadius: 6)],
      ),
      child: const Icon(Icons.star_rounded, size: 11, color: Color(0xFF8A6412)),
    );
  }
}

class _HomeMetrics {
  const _HomeMetrics({
    required this.viewportHeight,
    required this.horizontalPadding,
    required this.heroGap,
    required this.logoWidth,
    required this.primaryButtonHeight,
    required this.tileHeight,
    required this.buttonGap,
    required this.utilityButtonSize,
    required this.bottomSpacer,
    required this.compact,
    required this.narrow,
  });

  factory _HomeMetrics.from(Size size, {required int fullWidthButtonCount}) {
    final compact = size.height < 680 || size.width < 340;
    final narrow = size.width < 340;
    final veryShort = size.height < 610;
    final horizontalPadding = (size.width * 0.055).clamp(12.0, 22.0).toDouble();
    final availableWidth = math.max(0.0, size.width - horizontalPadding * 2);
    final logoWidth = math.min(680.0, availableWidth * (compact ? 0.98 : 0.96));
    final logoHeight = logoWidth * (718 / 2191);
    final heroGap = veryShort
        ? (size.height * 0.10).clamp(36.0, 58.0).toDouble()
        : compact
        ? (size.height * 0.15).clamp(72.0, 112.0).toDouble()
        // Keep the illustrated Sly hero, but do not make a modern tall phone
        // scroll just to reach the three quick audio/pace controls.
        : (size.height * 0.18).clamp(118.0, 150.0).toDouble();
    final primaryButtonHeight = veryShort ? 58.0 : (compact ? 64.0 : 72.0);
    final tileHeight = veryShort ? 56.0 : (compact ? 64.0 : 72.0);
    final buttonGap = veryShort ? 7.0 : 9.0;
    final utilityButtonSize = veryShort ? 46.0 : 52.0;
    final menuGaps = fullWidthButtonCount + 2;
    final menuHeight =
        primaryButtonHeight * fullWidthButtonCount +
        tileHeight * 3 +
        buttonGap * menuGaps;
    final fixedHeight =
        heroGap +
        logoHeight +
        4 +
        31 +
        (compact ? 8 : 11) +
        menuHeight +
        utilityButtonSize +
        8;
    final minimumSpacer = veryShort ? 8.0 : 24.0;
    final bottomSpacer = math.max(minimumSpacer, size.height - fixedHeight);
    return _HomeMetrics(
      viewportHeight: size.height,
      horizontalPadding: horizontalPadding,
      heroGap: heroGap,
      logoWidth: logoWidth,
      primaryButtonHeight: primaryButtonHeight,
      tileHeight: tileHeight,
      buttonGap: buttonGap,
      utilityButtonSize: utilityButtonSize,
      bottomSpacer: bottomSpacer,
      compact: compact,
      narrow: narrow,
    );
  }

  final double viewportHeight;
  final double horizontalPadding;
  final double heroGap;
  final double logoWidth;
  final double primaryButtonHeight;
  final double tileHeight;
  final double buttonGap;
  final double utilityButtonSize;
  final double bottomSpacer;
  final bool compact;
  final bool narrow;
}
