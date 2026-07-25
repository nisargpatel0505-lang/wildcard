import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/audio_service.dart';
import '../../services/haptics_service.dart';
import '../../services/sfx_service.dart';
import '../effects_profile.dart';
import '../wildcard_theme.dart';
import 'wildcard_background.dart';
import 'wildcard_button.dart';

enum RoyalVaultVisualTier { wooden, golden, cosmetic }

/// A compact painted chest used by the Vault catalogue cards. It shares the
/// opening sequence geometry, so the purchase tile previews the real chest.
class RoyalVaultChestEmblem extends StatelessWidget {
  const RoyalVaultChestEmblem({
    required this.tier,
    this.width = 112,
    super.key,
  });

  final RoyalVaultVisualTier tier;
  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final bodyColor = switch (tier) {
      RoyalVaultVisualTier.wooden => const Color(0xFF8B4B25),
      RoyalVaultVisualTier.golden => const Color(0xFF3E8F8A),
      RoyalVaultVisualTier.cosmetic => const Color(0xFF61378D),
    };
    return SizedBox(
      width: width,
      height: width * .62,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 4,
            right: 4,
            bottom: 0,
            height: width * .38,
            child: CustomPaint(
              painter: _ChestBasePainter(
                bodyColor: bodyColor,
                gold: tokens.gold,
                gem: tokens.mint,
              ),
            ),
          ),
          Positioned(
            left: 4,
            right: 4,
            top: 0,
            height: width * .31,
            child: CustomPaint(
              painter: _ChestLidPainter(
                bodyColor: bodyColor,
                gold: tokens.gold,
                gem: tokens.mint,
              ),
            ),
          ),
          Positioned(
            bottom: width * .11,
            child: Container(
              width: width * .18,
              height: width * .2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: LinearGradient(
                  colors: [const Color(0xFFFFE47B), tokens.gold],
                ),
                border: Border.all(color: const Color(0xFFFFEFAE)),
                boxShadow: const [
                  BoxShadow(color: Color(0x66000000), offset: Offset(0, 3)),
                ],
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Color(0xFF321607),
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class RoyalVaultRewardViewModel {
  const RoyalVaultRewardViewModel({
    required this.name,
    required this.description,
    required this.rarity,
    required this.rarityColor,
    required this.categoryLabel,
    required this.icon,
  });

  final String name;
  final String description;
  final String rarity;
  final Color rarityColor;
  final String categoryLabel;
  final IconData icon;
}

/// Displays the complete Royal Vault sequence as a safe-area-aware modal.
///
/// The caller must save the reward before opening this route. The dialog cannot
/// be dismissed with back or an outside tap, so the reward is always shown in
/// full before the player claims it.
Future<void> showRoyalVaultAnimation({
  required BuildContext context,
  required RoyalVaultVisualTier tier,
  required RoyalVaultRewardViewModel reward,
  required bool fast,
  AudioService? audio,
  SfxService? sfx,
  HapticsService? haptics,
}) async {
  await audio?.setCeremonyDuck(true);
  if (!context.mounted) {
    await audio?.setCeremonyDuck(false);
    return;
  }
  try {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Royal Vault reward',
      barrierColor: const Color(0xE6000308),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, _) => RoyalVaultAnimation(
        tier: tier,
        reward: reward,
        fast: fast,
        sfx: sfx,
        haptics: haptics,
        onClaim: () => Navigator.of(dialogContext).pop(),
      ),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  } finally {
    await audio?.setCeremonyDuck(false);
  }
}

class RoyalVaultAnimation extends StatefulWidget {
  const RoyalVaultAnimation({
    required this.tier,
    required this.reward,
    required this.fast,
    required this.onClaim,
    this.durationOverride,
    this.sfx,
    this.haptics,
    super.key,
  });

  final RoyalVaultVisualTier tier;
  final RoyalVaultRewardViewModel reward;
  final bool fast;
  final VoidCallback onClaim;

  /// Exposed for deterministic widget tests; production uses Normal/Fast time.
  final Duration? durationOverride;

  /// Optional sound and feel; null in tests and previews.
  final SfxService? sfx;
  final HapticsService? haptics;

  @override
  State<RoyalVaultAnimation> createState() => _RoyalVaultAnimationState();
}

class _RoyalVaultAnimationState extends State<RoyalVaultAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _claimEnabled = false;
  bool _claimHandled = false;
  final Set<int> _firedCues = <int>{};

  /// The WebView chest ceremony had a sound and a haptic on every phase edge:
  /// charge rumble, rarity scan ticks, the seal chord, the burst chord and the
  /// reveal chord, each scaled to the win's rarity.
  static const List<(double, String, int)> _cues = <(double, String, int)>[
    // (progress, sound, haptic: 0 none · 1 medium · 2 heavy)
    (0.18, 'chest_charge', 1),
    (0.29, 'chest_scan', 0),
    (0.45, 'seal', 2),
    (0.55, 'burst', 2),
    (0.84, 'reveal', 1),
  ];

  String get _rarityKey {
    final rarity = widget.reward.rarity.toLowerCase();
    if (rarity.contains('wild')) return 'wild';
    if (rarity.contains('rare')) return 'rare';
    return 'common';
  }

  Duration get _ceremonyDuration {
    final rarity = widget.reward.rarity.toLowerCase();
    final base = widget.fast ? 1950 : 3650;
    final extra = rarity.contains('wild')
        ? (widget.fast ? 430 : 680)
        : rarity.contains('rare')
        ? (widget.fast ? 260 : 420)
        : rarity.contains('uncommon')
        ? (widget.fast ? 120 : 220)
        : 0;
    return Duration(milliseconds: base + extra);
  }

  void _fireCues() {
    final sfx = widget.sfx;
    if (sfx == null && widget.haptics == null) return;
    final p = _controller.value;
    for (var index = 0; index < _cues.length; index++) {
      if (_firedCues.contains(index)) continue;
      final (at, sound, haptic) = _cues[index];
      if (p < at) continue;
      _firedCues.add(index);
      // The pre-rendered scan ladder outlasts the compressed fast charge.
      if (sound == 'chest_scan' && widget.fast) continue;
      final name = switch (sound) {
        'seal' => 'seal_$_rarityKey',
        'burst' => 'burst_$_rarityKey',
        'reveal' => 'reveal_$_rarityKey',
        _ => sound,
      };
      sfx?.play(name);
      final feel = widget.haptics;
      if (feel == null || haptic == 0) continue;
      switch (sound) {
        case 'chest_charge':
          feel.light();
          break;
        case 'seal':
        case 'burst':
          feel.medium();
          break;
        case 'reveal':
          if (_rarityKey == 'wild') {
            feel.wildSuccess();
          } else if (_rarityKey == 'rare') {
            feel.success();
          } else {
            feel.light();
          }
          break;
        default:
          break;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: widget.durationOverride ?? _ceremonyDuration,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _claimEnabled = true);
          }
        });
    _controller.addListener(_fireCues);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _claim() {
    if (!_claimEnabled || _claimHandled) return;
    _claimHandled = true;
    widget.onClaim();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        scopesRoute: true,
        namesRoute: true,
        label: 'Royal Vault reward',
        child: Material(
          color: Colors.transparent,
          child: WildcardBackground(
            room: WildcardRoom.vault,
            tintStrength: 0.7,
            child: SafeArea(
              minimum: const EdgeInsets.all(8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 620,
                    maxHeight: 860,
                  ),
                  // The Vault is the room, rather than a modal card floating
                  // above it. A single repaint boundary contains the ceremony.
                  child: RepaintBoundary(
                    key: const Key('royal-vault-dialog'),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => _VaultLayout(
                        progress: _controller.value,
                        tier: widget.tier,
                        reward: widget.reward,
                        reducedMotion: MediaQuery.disableAnimationsOf(context),
                        claimEnabled: _claimEnabled,
                        onClaim: _claim,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VaultLayout extends StatelessWidget {
  const _VaultLayout({
    required this.progress,
    required this.tier,
    required this.reward,
    required this.reducedMotion,
    required this.claimEnabled,
    required this.onClaim,
  });

  final double progress;
  final RoyalVaultVisualTier tier;
  final RoyalVaultRewardViewModel reward;
  final bool reducedMotion;
  final bool claimEnabled;
  final VoidCallback onClaim;

  double _interval(double begin, double end, [Curve curve = Curves.easeOut]) {
    if (progress <= begin) return 0;
    if (progress >= end) return 1;
    return curve
        .transform((progress - begin) / (end - begin))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  String get _vaultName => switch (tier) {
    RoyalVaultVisualTier.wooden => 'WOODEN VAULT',
    RoyalVaultVisualTier.golden => 'GOLDEN VAULT',
    RoyalVaultVisualTier.cosmetic => 'COSMETIC VAULT',
  };

  String get _status {
    return progress < .90 ? '' : 'REWARD SECURED';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final compact = MediaQuery.sizeOf(context).height < 650;
    // Nothing names or colours the actual rarity until the object has risen.
    final rarityReveal = _interval(.82, .91, Curves.easeOutCubic);
    final detailsReveal = _interval(.90, .98, Curves.easeOutCubic);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 16,
        compact ? 10 : 15,
        compact ? 10 : 16,
        compact ? 9 : 14,
      ),
      child: Column(
        children: [
          Text(
            'SLY\u2019S ROYAL VAULT',
            key: const Key('royal-vault-title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.gold,
              fontFamily: 'Bungee',
              fontSize: compact ? 18 : 23,
              height: 1.05,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _vaultName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.mint.withValues(alpha: .88),
              fontFamily: 'Bungee',
              fontSize: compact ? 8.5 : 10,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 120),
            child: Text(
              _status,
              key: ValueKey(_status),
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                color: tokens.creamDim,
                fontFamily: 'Bungee',
                fontSize: compact ? 10 : 11,
                letterSpacing: .45,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(height: compact ? 7 : 11),
          Expanded(
            child: _VaultStage(
              progress: progress,
              tier: tier,
              reward: reward,
              compact: compact,
              reducedMotion: reducedMotion,
            ),
          ),
          SizedBox(height: compact ? 7 : 10),
          Opacity(
            opacity: rarityReveal,
            child: Transform.scale(
              scale: .9 + .1 * rarityReveal,
              child: _RarityScan(
                rarity: reward.rarity,
                color: reward.rarityColor,
                compact: compact,
              ),
            ),
          ),
          SizedBox(height: compact ? 6 : 9),
          SizedBox(
            height: compact ? 76 : 94,
            child: Opacity(
              opacity: detailsReveal,
              child: Transform.translate(
                offset: Offset(0, 9 * (1 - detailsReveal)),
                child: _RewardDetails(reward: reward, compact: compact),
              ),
            ),
          ),
          SizedBox(height: compact ? 7 : 10),
          IgnorePointer(
            ignoring: !claimEnabled,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: claimEnabled ? 1 : .38,
              child: WildcardButton(
                key: const Key('royal-vault-claim'),
                label: claimEnabled
                    ? 'Claim ${reward.name}'
                    : 'Opening Vault...',
                icon: Icon(
                  claimEnabled ? Icons.done_rounded : Icons.lock_clock,
                ),
                onPressed: claimEnabled ? onClaim : null,
                variant: WildcardButtonVariant.primary,
                minHeight: compact ? 48 : 54,
                fontSize: compact ? 11 : 13,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultStage extends StatelessWidget {
  const _VaultStage({
    required this.progress,
    required this.tier,
    required this.reward,
    required this.compact,
    required this.reducedMotion,
  });

  final double progress;
  final RoyalVaultVisualTier tier;
  final RoyalVaultRewardViewModel reward;
  final bool compact;
  final bool reducedMotion;

  double _interval(double begin, double end, [Curve curve = Curves.easeOut]) {
    if (progress <= begin) return 0;
    if (progress >= end) return 1;
    return curve
        .transform((progress - begin) / (end - begin))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final effects = EffectsProfile.resolve(context);
    // ---- Phase map (single forward timeline, so tests always settle) ----
    // charge 0–.36: the chest strains against the seal, energy converges.
    // seal  .36–.46: flash; the lock loses.
    // burst .46–.62: lid slams open, beam and debris erupt, stage kicks.
    // reveal .56–.86: the prize rises out of the light and settles.
    final arrival = _interval(0, .08, Curves.easeOutCubic);
    final anticipation = _interval(.08, .18, Curves.easeInOut);
    final charge = _interval(.18, .35, Curves.easeIn);
    final scan = _interval(.27, .42, Curves.easeInOut);
    final unlock = _interval(.42, .50, Curves.easeInOutCubic);
    final opening = _interval(.50, .68, Curves.easeInOutCubic);
    final beam = _interval(.53, .72, Curves.easeOutCubic);
    final beamFade = _interval(.82, .98, Curves.easeIn);
    final burst = _interval(.55, .82, Curves.easeOutCubic);
    final rewardRise = _interval(.66, .84, Curves.easeOutCubic);
    final shine = _interval(.88, .98, Curves.easeInOut);
    final lockPulse = .5 + .5 * math.sin(progress * math.pi * 12);

    // The chest fights the seal: jitter grows through the charge and a hard
    // decaying kick punctuates the burst.
    final rarityWeight = switch (reward.rarity.toLowerCase()) {
      final value when value.contains('wild') => 1.25,
      final value when value.contains('rare') => 1.0,
      _ => .66,
    };

    final bodyColor = switch (tier) {
      RoyalVaultVisualTier.wooden => const Color(0xFF8B4B25),
      RoyalVaultVisualTier.golden => const Color(0xFF3E8F8A),
      RoyalVaultVisualTier.cosmetic => const Color(0xFF61378D),
    };
    // During the charge the stage scans through the rarity ladder before
    // locking onto the real colour, exactly like the WebView's scan cycle.
    const cycle = <Color>[
      Color(0xFFCFC6B2),
      Color(0xFF45E0C6),
      Color(0xFF9B7BFF),
      Color(0xFFF7C548),
    ];
    final scanColor = reducedMotion && progress < .82
        ? tokens.violet
        : progress < .27
        ? tokens.violet
        : progress < .82
        ? cycle[(scan * (cycle.length - .001)).floor() % cycle.length]
        : reward.rarityColor;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sceneWidth = constraints.maxWidth;
          final sceneHeight = constraints.maxHeight;
          final chestWidth = math.min(
            sceneWidth * .76,
            compact ? 226.0 : 290.0,
          );
          final chestHeight = chestWidth * .55;
          final chestTop =
              math.max(
                compact ? 28.0 : 42.0,
                sceneHeight - chestHeight - (compact ? 8 : 14),
              ) +
              14 * (1 - arrival);
          final mouth = Offset(sceneWidth / 2, chestTop + chestHeight * .34);
          final rewardWidth = compact ? 102.0 : 126.0;
          final rewardHeight = compact ? 118.0 : 146.0;
          final stageBurst =
              (burst *
                      rarityWeight *
                      effects.glowScale *
                      (reducedMotion ? .38 : 1))
                  .clamp(0.0, 1.0);

          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scanColor.withValues(alpha: .9),
                width: 1.6,
              ),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF210A43), Color(0xFF06141A)],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _VaultAtmospherePainter(
                      progress: progress,
                      burst: stageBurst,
                      color: progress < .82 ? scanColor : reward.rarityColor,
                      line: tokens.violet,
                    ),
                  ),
                  Positioned(
                    left: sceneWidth * .16,
                    right: sceneWidth * .16,
                    top: chestTop + chestHeight * .82,
                    height: compact ? 12 : 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: RadialGradient(
                          colors: [
                            reward.rarityColor.withValues(
                              alpha: .16 + stageBurst * .22,
                            ),
                            const Color(0xC8000000),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (charge > 0 && unlock < 1)
                    CustomPaint(
                      painter: _ConvergePainter(
                        progress: charge,
                        fade: 1 - unlock,
                        color: scanColor,
                        focus: mouth.translate(0, chestHeight * .12),
                      ),
                    ),
                  if (beam > 0)
                    CustomPaint(
                      painter: _BeamPainter(
                        spread: beam,
                        fade: (1 - beamFade) * rarityWeight.clamp(.65, 1.0),
                        color: reward.rarityColor,
                        mouth: mouth,
                      ),
                    ),
                  // The lid is a real hinge rotation: no rubber-band overshoot.
                  Positioned(
                    left: (sceneWidth - chestWidth) / 2,
                    top: chestTop,
                    width: chestWidth,
                    height: chestHeight * .49,
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, .0015)
                        ..rotateX(-opening * 1.12),
                      child: CustomPaint(
                        painter: _ChestLidPainter(
                          bodyColor: bodyColor,
                          gold: tokens.gold,
                          gem: tokens.mint,
                        ),
                      ),
                    ),
                  ),
                  // Draw the reward before the chest front. Its lower edge is
                  // naturally occluded while it is still inside the cavity.
                  Positioned(
                    left: sceneWidth / 2 - rewardWidth / 2,
                    top:
                        chestTop +
                        chestHeight * .26 -
                        rewardRise *
                            (compact ? 88 : 112) *
                            (reducedMotion ? .72 : 1),
                    width: rewardWidth,
                    height: rewardHeight,
                    child: Opacity(
                      opacity: rewardRise.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: .82 + .18 * rewardRise,
                        alignment: Alignment.bottomCenter,
                        child: _RewardToken(
                          reward: reward,
                          glow: stageBurst,
                          shine: reducedMotion ? 0 : shine,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (sceneWidth - chestWidth) / 2,
                    top: chestTop + chestHeight * .32,
                    width: chestWidth,
                    height: chestHeight * .68,
                    child: CustomPaint(
                      painter: _ChestBasePainter(
                        bodyColor: bodyColor,
                        gold: tokens.gold,
                        gem: tokens.mint,
                      ),
                    ),
                  ),
                  // The released lock drops a short, believable distance and
                  // stays attached to the chest instead of flying away.
                  Positioned(
                    left: sceneWidth / 2 - 28,
                    top: chestTop + chestHeight * .39 + 12 * unlock,
                    width: 56,
                    height: 64,
                    child: _AnimatedLock(
                      pulse:
                          lockPulse * (.45 + .25 * anticipation + .30 * charge),
                      color: tokens.gold,
                      unlocked: unlock > .55,
                    ),
                  ),
                  if (burst > 0 && !reducedMotion && effects.particleScale > 0)
                    CustomPaint(
                      painter: _DebrisPainter(
                        progress: burst,
                        color: reward.rarityColor,
                        origin: mouth,
                        intensity: rarityWeight * effects.particleScale,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedLock extends StatelessWidget {
  const _AnimatedLock({
    required this.pulse,
    required this.color,
    required this.unlocked,
  });

  final double pulse;
  final Color color;
  final bool unlocked;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFFFFE47B), color, const Color(0xFFA75B12)],
      ),
      border: Border.all(color: const Color(0xFFFFEFAE), width: 2),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: .25 + .32 * pulse),
          blurRadius: 8 + 8 * pulse,
        ),
        const BoxShadow(color: Color(0x66000000), offset: Offset(0, 5)),
      ],
    ),
    child: Icon(
      unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
      color: const Color(0xFF321607),
      size: 30,
    ),
  );
}

class _RewardToken extends StatelessWidget {
  const _RewardToken({
    required this.reward,
    required this.glow,
    this.shine = 0,
  });

  final RoyalVaultRewardViewModel reward;
  final double glow;

  /// 0..1 sweep of a light band across the settled token.
  final double shine;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0xFFFFF9E7), Color(0xFFF0DFC1), Color(0xFFD5BE91)],
        stops: const [0, .56, 1],
      ),
      border: Border.all(color: reward.rarityColor, width: 3),
      boxShadow: [
        BoxShadow(
          color: reward.rarityColor.withValues(alpha: .28 + .42 * glow),
          blurRadius: 13 + 20 * glow,
          spreadRadius: 1 + 2 * glow,
        ),
        const BoxShadow(color: Color(0x88000000), offset: Offset(0, 7)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 8, 7, 7),
            child: Column(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: reward.rarityColor.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    child: Text(
                      reward.categoryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF23102F),
                        fontFamily: 'Bungee',
                        fontSize: 6.5,
                        letterSpacing: .35,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Icon(reward.icon, color: const Color(0xFF23102F), size: 43),
                const Spacer(),
                Text(
                  reward.name.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF23102F),
                    fontFamily: 'Bungee',
                    fontSize: 9,
                    height: 1.04,
                  ),
                ),
              ],
            ),
          ),
          if (shine > 0 && shine < 1)
            Align(
              alignment: Alignment(-1.6 + 3.2 * shine, 0),
              child: Transform.rotate(
                angle: .42,
                child: Container(
                  width: 18,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: .72),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _RarityScan extends StatelessWidget {
  const _RarityScan({
    required this.rarity,
    required this.color,
    required this.compact,
  });

  final String rarity;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.symmetric(
        horizontal: BorderSide(color: color.withValues(alpha: .82), width: 1.2),
      ),
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          color.withValues(alpha: .14),
          Colors.transparent,
        ],
      ),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 3 : 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: compact ? 12 : 14,
            color: color,
          ),
          const SizedBox(width: 7),
          Text(
            'RARITY  $rarity',
            key: const Key('royal-vault-rarity'),
            style: TextStyle(
              color: color,
              fontFamily: 'Bungee',
              fontSize: compact ? 11 : 14,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(width: 7),
          Icon(
            Icons.auto_awesome_rounded,
            size: compact ? 12 : 14,
            color: color,
          ),
        ],
      ),
    ),
  );
}

class _RewardDetails extends StatelessWidget {
  const _RewardDetails({required this.reward, required this.compact});

  final RoyalVaultRewardViewModel reward;
  final bool compact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xB9051018),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: reward.rarityColor.withValues(alpha: .68)),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 13,
        vertical: compact ? 5 : 8,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            reward.categoryLabel,
            style: TextStyle(
              color: reward.rarityColor,
              fontFamily: 'Bungee',
              fontSize: compact ? 7.5 : 9,
              letterSpacing: .45,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            reward.name.toUpperCase(),
            key: const Key('royal-vault-reward-name'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.wildcard.cream,
              fontFamily: 'Bungee',
              fontSize: compact ? 11 : 14,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              reward.description,
              key: const Key('royal-vault-reward-description'),
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.wildcard.creamDim,
                fontSize: compact ? 9.5 : 11,
                height: 1.16,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChestBasePainter extends CustomPainter {
  const _ChestBasePainter({
    required this.bodyColor,
    required this.gold,
    required this.gem,
  });

  final Color bodyColor;
  final Color gold;
  final Color gem;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .08, 0, size.width * .84, size.height * .91),
      Radius.circular(size.width * .09),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xB0000000));
    canvas.save();
    canvas.translate(0, -size.height * .07);
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(bodyColor, Colors.white, .16)!,
            bodyColor,
            Color.lerp(bodyColor, Colors.black, .36)!,
          ],
        ).createShader(body.outerRect),
    );
    final border = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .035;
    canvas.drawRRect(body, border);
    final band = Paint()..color = Color.lerp(gold, Colors.white, .18)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .12,
          size.height * .36,
          size.width * .76,
          size.height * .14,
        ),
        Radius.circular(size.height * .06),
      ),
      band,
    );
    for (final x in <double>[.27, .73]) {
      canvas.drawRect(
        Rect.fromLTWH(size.width * x, 0, size.width * .035, size.height * .85),
        band,
      );
    }
    for (final x in <double>[.18, .82]) {
      final center = Offset(size.width * x, size.height * .66);
      final path = Path()
        ..moveTo(center.dx, center.dy - size.width * .035)
        ..lineTo(center.dx + size.width * .035, center.dy)
        ..lineTo(center.dx, center.dy + size.width * .035)
        ..lineTo(center.dx - size.width * .035, center.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = gem);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChestBasePainter oldDelegate) =>
      oldDelegate.bodyColor != bodyColor ||
      oldDelegate.gold != gold ||
      oldDelegate.gem != gem;
}

class _ChestLidPainter extends CustomPainter {
  const _ChestLidPainter({
    required this.bodyColor,
    required this.gold,
    required this.gem,
  });

  final Color bodyColor;
  final Color gold;
  final Color gem;

  @override
  void paint(Canvas canvas, Size size) {
    final lidPath = Path()
      ..moveTo(size.width * .09, size.height)
      ..lineTo(size.width * .09, size.height * .52)
      ..quadraticBezierTo(
        size.width * .12,
        size.height * .08,
        size.width * .5,
        size.height * .04,
      )
      ..quadraticBezierTo(
        size.width * .88,
        size.height * .08,
        size.width * .91,
        size.height * .52,
      )
      ..lineTo(size.width * .91, size.height)
      ..close();
    canvas.drawPath(
      lidPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(bodyColor, Colors.white, .2)!,
            bodyColor,
            Color.lerp(bodyColor, Colors.black, .25)!,
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      lidPath,
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .035
        ..strokeJoin = StrokeJoin.round,
    );
    final band = Paint()..color = Color.lerp(gold, Colors.white, .18)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .13,
          size.height * .63,
          size.width * .74,
          size.height * .18,
        ),
        Radius.circular(size.height * .09),
      ),
      band,
    );
    for (final x in <double>[.3, .7]) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * x,
          size.height * .14,
          size.width * .035,
          size.height * .75,
        ),
        band,
      );
    }
    final center = Offset(size.width * .5, size.height * .31);
    final gemPath = Path()
      ..moveTo(center.dx, center.dy - size.width * .045)
      ..lineTo(center.dx + size.width * .045, center.dy)
      ..lineTo(center.dx, center.dy + size.width * .045)
      ..lineTo(center.dx - size.width * .045, center.dy)
      ..close();
    canvas.drawPath(gemPath, Paint()..color = gem);
  }

  @override
  bool shouldRepaint(covariant _ChestLidPainter oldDelegate) =>
      oldDelegate.bodyColor != bodyColor ||
      oldDelegate.gold != gold ||
      oldDelegate.gem != gem;
}

class _VaultAtmospherePainter extends CustomPainter {
  const _VaultAtmospherePainter({
    required this.progress,
    required this.burst,
    required this.color,
    required this.line,
  });

  final double progress;
  final double burst;
  final Color color;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = line.withValues(alpha: .08)
      ..strokeWidth = 1;
    for (var y = 18.0; y < size.height; y += 20) {
      canvas.drawLine(
        Offset.zero.translate(0, y),
        Offset(size.width, y),
        linePaint,
      );
    }

    if (burst <= 0) return;
    final origin = Offset(size.width / 2, size.height * .66);
    final beamPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: .48 * burst),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: origin, radius: size.width * .72));
    canvas.drawCircle(origin, size.width * .65, beamPaint);

    final rayPaint = Paint()..color = color.withValues(alpha: .13 * burst);
    for (var index = 0; index < 11; index++) {
      final offset = (index - 5) * .105;
      final path = Path()
        ..moveTo(origin.dx - 5, origin.dy)
        ..lineTo(size.width * (.5 + offset - .045), 0)
        ..lineTo(size.width * (.5 + offset + .045), 0)
        ..lineTo(origin.dx + 5, origin.dy)
        ..close();
      canvas.drawPath(path, rayPaint);
    }

    final scanY = size.height * ((progress * 2.4) % 1);
    canvas.drawRect(
      Rect.fromLTWH(0, scanY, size.width, 2),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            color.withValues(alpha: .55),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, scanY, size.width, 2)),
    );
  }

  @override
  bool shouldRepaint(covariant _VaultAtmospherePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.burst != burst ||
      oldDelegate.color != color ||
      oldDelegate.line != line;
}

/// Energy streaming INTO the lock while the chest charges — anticipation the
/// old sequence never had. Deterministic per-index pseudo-randomness keeps the
/// painter allocation-free.
class _ConvergePainter extends CustomPainter {
  const _ConvergePainter({
    required this.progress,
    required this.fade,
    required this.color,
    required this.focus,
  });

  final double progress;
  final double fade;
  final Color color;
  final Offset focus;

  @override
  void paint(Canvas canvas, Size size) {
    if (fade <= 0) return;
    final paint = Paint();
    for (var index = 0; index < 18; index++) {
      final seed = index * 37.0;
      final angle = (seed * .61) % (math.pi * 2);
      final phase =
          ((progress * (1.1 + (index % 5) * .18)) + (seed * .137)) % 1;
      final distance = size.shortestSide * .58 * (1 - phase);
      final point = Offset(
        focus.dx + math.cos(angle) * distance,
        focus.dy + math.sin(angle) * distance * .7,
      );
      paint.color = (index % 3 == 0 ? const Color(0xFFFFE9A8) : color)
          .withValues(alpha: (phase * .8 * fade).clamp(0.0, 1.0));
      canvas.drawCircle(point, 1.1 + phase * 2.1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConvergePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fade != fade ||
      oldDelegate.color != color;
}

/// The vertical light column out of the opened chest.
class _BeamPainter extends CustomPainter {
  const _BeamPainter({
    required this.spread,
    required this.fade,
    required this.color,
    required this.mouth,
  });

  final double spread;
  final double fade;
  final Color color;
  final Offset mouth;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = (spread * fade).clamp(0.0, 1.0);
    if (alpha <= 0) return;
    final halfTop = size.width * (.10 + .16 * spread);
    final halfBase = 16.0 + 10 * spread;
    final path = Path()
      ..moveTo(mouth.dx - halfBase, mouth.dy)
      ..lineTo(mouth.dx - halfTop, 0)
      ..lineTo(mouth.dx + halfTop, 0)
      ..lineTo(mouth.dx + halfBase, mouth.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.white.withValues(alpha: .55 * alpha),
            color.withValues(alpha: .34 * alpha),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .4, 1],
        ).createShader(Rect.fromLTWH(0, 0, size.width, mouth.dy)),
    );
    // A hot core line up the middle sells the intensity.
    canvas.drawRect(
      Rect.fromLTRB(mouth.dx - 2.5, 0, mouth.dx + 2.5, mouth.dy),
      Paint()..color = Colors.white.withValues(alpha: .38 * alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _BeamPainter oldDelegate) =>
      oldDelegate.spread != spread ||
      oldDelegate.fade != fade ||
      oldDelegate.color != color;
}

/// The burst debris: sparks and card-shaped shards thrown out of the chest on
/// ballistic arcs with gravity, tumbling as they fly.
class _DebrisPainter extends CustomPainter {
  const _DebrisPainter({
    required this.progress,
    required this.color,
    required this.origin,
    this.intensity = 1,
  });

  final double progress;
  final Color color;
  final Offset origin;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1 - ((progress - .55) / .45).clamp(0.0, 1.0)).clamp(0.0, 1.0);
    if (fade <= 0) return;
    final paint = Paint();
    final particleCount = (20 + 14 * intensity).round().clamp(18, 38);
    for (var index = 0; index < particleCount; index++) {
      final seed = index * 97.0;
      // Launch mostly upward in a fan.
      final angle = -math.pi / 2 + math.sin(seed) * 1.15;
      final speed = size.shortestSide * (.5 + ((seed * .173) % .55));
      final t = progress;
      final x = origin.dx + math.cos(angle) * speed * t;
      final y =
          origin.dy +
          math.sin(angle) * speed * t +
          size.height * .62 * t * t; // gravity
      if (y > size.height + 8) continue;
      final baseColor = switch (index % 4) {
        0 => const Color(0xFFFFD35C),
        1 => Colors.white,
        _ => color,
      };
      paint.color = baseColor.withValues(
        alpha: (.78 * intensity.clamp(.65, 1.0) * fade).clamp(0.0, 1.0),
      );
      if (index % 3 == 0) {
        // Tumbling card-shard.
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(seed + t * (4 + index % 5));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: 5.4 + (index % 3) * 2,
              height: 7.4 + (index % 4) * 2,
            ),
            const Radius.circular(1.4),
          ),
          paint,
        );
        canvas.restore();
      } else {
        canvas.drawCircle(Offset(x, y), 1.3 + (index % 4) * .6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DebrisPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.intensity != intensity;
}
