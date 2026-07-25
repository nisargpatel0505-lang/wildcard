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
      RoyalVaultVisualTier.golden => const Color(0xFF57277A),
      RoyalVaultVisualTier.cosmetic => const Color(0xFF8B286C),
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
  final rarityKey = reward.rarity.toLowerCase().contains('wild')
      ? 'wild'
      : reward.rarity.toLowerCase().contains('rare')
      ? 'rare'
      : 'common';
  // AudioPool cannot stop or fade the 2.17-second scan sample, so warm only
  // the short cues used by this non-overlapping ceremony.
  sfx?.warmUp(<String>[
    'chest_charge',
    'seal_common',
    'burst_common',
    'reveal_$rarityKey',
  ]).ignore();
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
  bool _started = false;
  final Set<int> _firedCues = <int>{};

  /// Short, non-overlapping sound and haptic cues on each phase edge. The
  /// rarity-specific cue is held until the visual reveal.
  static const List<(double, String, int)> _cues = <(double, String, int)>[
    // (progress, sound, haptic: 0 none · 1 medium · 2 heavy)
    (0.10, 'chest_charge', 1),
    (0.56, 'seal', 2),
    (0.72, 'burst', 2),
    (0.86, 'reveal', 1),
  ];

  String get _rarityKey {
    final rarity = widget.reward.rarity.toLowerCase();
    if (rarity.contains('wild')) return 'wild';
    if (rarity.contains('rare')) return 'rare';
    return 'common';
  }

  Duration get _ceremonyDuration {
    final rarity = widget.reward.rarity.toLowerCase();
    final base = widget.fast ? 2600 : 4200;
    final extra = rarity.contains('wild')
        ? (widget.fast ? 180 : 320)
        : rarity.contains('rare')
        ? (widget.fast ? 110 : 180)
        : rarity.contains('uncommon')
        ? (widget.fast ? 60 : 90)
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
      final name = switch (sound) {
        'seal' => 'seal_common',
        'burst' => 'burst_common',
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.durationOverride == null &&
        MediaQuery.disableAnimationsOf(context)) {
      _controller.duration = const Duration(milliseconds: 720);
    }
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
    if (progress < .86) return '';
    if (progress < .94) return reward.rarity.toUpperCase();
    return 'REWARD SECURED';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final compact = MediaQuery.sizeOf(context).height < 700;
    // The prize identity remains out of the tree until the physical reward has
    // cleared the chest. This prevents both a visual and accessibility leak.
    final detailsReveal = _interval(.885, .90, Curves.easeOutCubic);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 6 : 14,
        compact ? 7 : 14,
        compact ? 6 : 14,
        compact ? 6 : 12,
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
              fontSize: compact ? 16 : 22,
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
              fontSize: compact ? 8 : 10,
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Expanded(
            child: _VaultStage(
              progress: progress,
              tier: tier,
              reward: reward,
              compact: compact,
              reducedMotion: reducedMotion,
            ),
          ),
          SizedBox(height: compact ? 5 : 8),
          SizedBox(
            height: compact ? 18 : 22,
            child: AnimatedSwitcher(
              duration: reducedMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 130),
              child: Text(
                _status,
                key: ValueKey(_status),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  color: progress >= .86 ? reward.rarityColor : tokens.creamDim,
                  fontFamily: 'Bungee',
                  fontSize: compact ? 8.5 : 10,
                  letterSpacing: .45,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 4 : 7),
          SizedBox(
            height: compact ? 70 : 88,
            child: detailsReveal <= 0
                ? const SizedBox(
                    key: Key('royal-vault-reward-details-placeholder'),
                  )
                : Opacity(
                    opacity: detailsReveal,
                    child: Transform.translate(
                      offset: Offset(0, 7 * (1 - detailsReveal)),
                      child: _RewardDetails(reward: reward, compact: compact),
                    ),
                  ),
          ),
          SizedBox(height: compact ? 4 : 7),
          SizedBox(
            height: compact ? 48 : 54,
            child: claimEnabled
                ? WildcardButton(
                    key: const Key('royal-vault-claim'),
                    label: 'Claim ${reward.name}',
                    icon: const Icon(Icons.done_rounded),
                    onPressed: onClaim,
                    variant: WildcardButtonVariant.primary,
                    minHeight: compact ? 48 : 54,
                    fontSize: compact ? 10.5 : 13,
                    textAlign: TextAlign.center,
                  )
                : const ExcludeSemantics(
                    child: SizedBox(key: Key('royal-vault-claim-placeholder')),
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
    final anticipation = _interval(.02, .10, Curves.easeInOut);
    final scan = _interval(.10, .56, Curves.easeInOut);
    final scanSweep = progress < .10
        ? 0.0
        : progress < .56
        ? scan
        : progress < .60
        ? 1 - _interval(.56, .60, Curves.easeIn)
        : 0.0;
    final rarityLock = _interval(.54, .60, Curves.easeOutCubic);
    final unlock = _interval(.56, .62, Curves.easeInOutCubic);
    final opening = _interval(.61, .75, Curves.easeInOutCubic);
    final beam = _interval(.72, .82, Curves.easeOutCubic);
    final beamFade = _interval(.90, .98, Curves.easeIn);
    final burst = _interval(.72, .84, Curves.easeOutCubic);
    final rewardRise = _interval(.74, .86, Curves.easeOutCubic);
    final rewardReveal = _interval(.86, .91, Curves.easeOutCubic);
    final shine = _interval(.91, .98, Curves.easeInOut);
    final lockPulse = .5 + .5 * math.sin(progress * math.pi * 10);
    final physicalUnlock = reducedMotion ? (unlock > 0 ? 1.0 : 0.0) : unlock;
    final physicalOpening = reducedMotion ? (opening > 0 ? 1.0 : 0.0) : opening;
    final physicalRewardRise = reducedMotion
        ? (rewardRise > 0 ? 1.0 : 0.0)
        : rewardRise;

    // The chest fights the seal: jitter grows through the charge and a hard
    // decaying kick punctuates the burst.
    final rarityWeight = switch (reward.rarity.toLowerCase()) {
      final value when value.contains('wild') => 1.25,
      final value when value.contains('rare') => 1.0,
      _ => .66,
    };

    final tutorialChest = reward.categoryLabel.toLowerCase().contains(
      'comeback',
    );
    final bodyColor = tutorialChest
        ? const Color(0xFF176068)
        : switch (tier) {
            RoyalVaultVisualTier.wooden => const Color(0xFF8B4B25),
            RoyalVaultVisualTier.golden => const Color(0xFF57277A),
            RoyalVaultVisualTier.cosmetic => const Color(0xFF8B286C),
          };
    final scanTick = (scan * 10.999).floor();
    final locked = progress >= .86;
    final scanLabel = locked ? reward.rarity.toUpperCase() : 'SEARCHING';
    // The real rarity is protected until the reward clears the chest rim.
    // Before then, the scan uses the Vault's neutral mint/violet signal only.
    final neutralScanColor = Color.lerp(
      tokens.mint,
      tokens.violet,
      .28 + .18 * math.sin(progress * math.pi * 6),
    )!;
    final scanColor = locked
        ? Color.lerp(neutralScanColor, reward.rarityColor, rewardReveal)!
        : neutralScanColor;

    return RepaintBoundary(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: compact ? 250 : 340,
            maxHeight: compact ? 340 : 460,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sceneWidth = constraints.maxWidth;
              final sceneHeight = constraints.maxHeight;
              final chestWidth = math.min(
                sceneWidth * .78,
                compact ? 224.0 : 286.0,
              );
              final baseHeight = chestWidth * .36;
              final lidHeight = chestWidth * .34;
              final chestBottom = compact ? 12.0 : 18.0;
              final baseTop = sceneHeight - chestBottom - baseHeight;
              final lidTop = baseTop - lidHeight + chestWidth * .045;
              final mouth = Offset(sceneWidth / 2, baseTop + 3);
              final rewardWidth = math.min(
                sceneWidth * .64,
                compact ? 185.0 : 210.0,
              );
              final rewardHeight = rewardWidth * .88;
              final scanHeight = compact ? 47.0 : 56.0;
              final rewardStartTop = baseTop + baseHeight * .24;
              final rewardEndTop = math.max(
                scanHeight + (compact ? 13 : 19),
                baseTop - rewardHeight - (compact ? 8 : 16),
              );
              final rewardTop =
                  rewardStartTop +
                  (rewardEndTop - rewardStartTop) *
                      physicalRewardRise.clamp(0.0, 1.0);
              final visualWeight = progress < .86
                  ? .82
                  : .82 + (rarityWeight - .82) * rewardReveal;
              final stageBurst =
                  (burst *
                          visualWeight *
                          effects.glowScale *
                          (reducedMotion ? .38 : 1))
                      .clamp(0.0, 1.0);

              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: scanColor.withValues(alpha: .92),
                    width: locked ? 2.2 : 1.6,
                  ),
                  gradient: RadialGradient(
                    center: const Alignment(0, -.28),
                    radius: 1.05,
                    colors: [
                      scanColor.withValues(alpha: .14 + .08 * rarityLock),
                      const Color(0xFF170A30),
                      const Color(0xFF030B12),
                    ],
                    stops: const [0, .42, 1],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scanColor.withValues(
                        alpha: .10 + .16 * rarityLock + .13 * stageBurst,
                      ),
                      blurRadius: 12 + 15 * rarityLock,
                      spreadRadius: rarityLock,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _VaultAtmospherePainter(
                          progress: progress,
                          burst: stageBurst,
                          scanProgress: scanSweep,
                          color: locked ? reward.rarityColor : scanColor,
                          line: tokens.violet,
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: scanColor.withValues(alpha: .28),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: compact ? 12 : 18,
                        right: compact ? 12 : 18,
                        top: compact ? 8 : 11,
                        height: scanHeight,
                        child: _RarityScan(
                          value: scanLabel,
                          color: scanColor,
                          compact: compact,
                          locked: locked,
                          pulse: reducedMotion
                              ? 1
                              : .93 +
                                    .07 *
                                        math.sin(
                                          scanTick * 1.73 +
                                              progress * math.pi * 8,
                                        ),
                        ),
                      ),
                      Positioned(
                        left: sceneWidth * .16,
                        right: sceneWidth * .16,
                        top: baseTop + baseHeight * .82,
                        height: compact ? 18 : 24,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            border: Border(
                              top: BorderSide(
                                color: tokens.gold.withValues(alpha: .62),
                                width: 1.4,
                              ),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                scanColor.withValues(
                                  alpha: .16 + stageBurst * .22,
                                ),
                                const Color(0xE0000000),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (beam > 0)
                        CustomPaint(
                          painter: _BeamPainter(
                            spread: beam,
                            fade: (1 - beamFade) * visualWeight.clamp(.65, 1.0),
                            color: scanColor,
                            mouth: mouth,
                          ),
                        ),
                      Positioned(
                        left: (sceneWidth - chestWidth * .74) / 2,
                        top: baseTop - 5,
                        width: chestWidth * .74,
                        height: compact ? 14 : 18,
                        child: Opacity(
                          opacity: .28 + .52 * physicalOpening,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF010508),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: scanColor.withValues(
                                  alpha: .25 + .4 * physicalOpening,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: scanColor.withValues(
                                    alpha: .12 + .26 * stageBurst,
                                  ),
                                  blurRadius: 13 + 18 * stageBurst,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: (sceneWidth - chestWidth) / 2,
                        top: lidTop,
                        width: chestWidth,
                        height: lidHeight,
                        child: Transform(
                          alignment: Alignment.bottomCenter,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, .0018)
                            ..rotateX(-physicalOpening * 1.42),
                          child: CustomPaint(
                            key: const Key('royal-vault-chest-lid'),
                            painter: _ChestLidPainter(
                              bodyColor: bodyColor,
                              gold: tokens.gold,
                              gem: scanColor,
                              opening: physicalOpening,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: (sceneWidth - chestWidth * .70) / 2,
                        top: baseTop - (compact ? 5 : 6),
                        width: chestWidth * .70,
                        height: compact ? 10 : 12,
                        child: CustomPaint(
                          key: const Key('royal-vault-rear-hinge'),
                          painter: _ChestHingePainter(gold: tokens.gold),
                        ),
                      ),
                      if (rewardRise > 0)
                        Positioned(
                          key: const Key('royal-vault-reward-token'),
                          left: sceneWidth / 2 - rewardWidth / 2,
                          top: rewardTop,
                          width: rewardWidth,
                          height: rewardHeight,
                          child: Opacity(
                            opacity: _interval(.74, .80, Curves.easeOut),
                            child: Transform.scale(
                              scale: reducedMotion ? 1 : .82 + .18 * rewardRise,
                              alignment: Alignment.bottomCenter,
                              child: _RewardToken(
                                reward: reward,
                                glow: stageBurst,
                                shine: reducedMotion ? 0 : shine,
                                revealed: locked,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: (sceneWidth - chestWidth) / 2,
                        top: baseTop,
                        width: chestWidth,
                        height: baseHeight,
                        child: CustomPaint(
                          key: const Key('royal-vault-chest-base'),
                          painter: _ChestBasePainter(
                            bodyColor: bodyColor,
                            gold: tokens.gold,
                            gem: scanColor,
                          ),
                        ),
                      ),
                      Positioned(
                        key: const Key('royal-vault-lock'),
                        left: sceneWidth / 2 - (compact ? 22 : 27),
                        top:
                            baseTop +
                            baseHeight * .04 +
                            (compact ? 11 : 15) * physicalUnlock,
                        width: compact ? 44 : 54,
                        height: compact ? 54 : 65,
                        child: Transform.rotate(
                          angle: reducedMotion ? 0 : physicalUnlock * .13,
                          child: Opacity(
                            opacity: 1 - .34 * physicalUnlock,
                            child: _AnimatedLock(
                              pulse:
                                  lockPulse *
                                  (.42 + .24 * anticipation + .34 * scan),
                              color: tokens.gold,
                              unlocked: physicalUnlock,
                            ),
                          ),
                        ),
                      ),
                      if (burst > 0 &&
                          !reducedMotion &&
                          effects.particleScale > 0)
                        CustomPaint(
                          painter: _DebrisPainter(
                            progress: burst,
                            color: scanColor,
                            origin: mouth,
                            intensity: visualWeight * effects.particleScale,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
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
  final double unlocked;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _VaultLockPainter(color: color, pulse: pulse, unlocked: unlocked),
  );
}

class _VaultLockPainter extends CustomPainter {
  const _VaultLockPainter({
    required this.color,
    required this.pulse,
    required this.unlocked,
  });

  final Color color;
  final double pulse;
  final double unlocked;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = color.withValues(alpha: .18 + .23 * pulse)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + 5 * pulse);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .12,
          size.height * .30,
          size.width * .76,
          size.height * .62,
        ),
        Radius.circular(size.width * .16),
      ),
      glow,
    );

    final shackle = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFF0A6), Color(0xFFD29A2E), Color(0xFF8D4B0F)],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .12
      ..strokeCap = StrokeCap.round;
    final rightLift = size.height * .20 * unlocked;
    final shacklePath = Path()
      ..moveTo(size.width * .30, size.height * .43)
      ..lineTo(size.width * .30, size.height * .26)
      ..cubicTo(
        size.width * .30,
        size.height * .04,
        size.width * .70,
        size.height * .04,
        size.width * .70,
        size.height * .26 - rightLift,
      )
      ..lineTo(
        size.width * .70 + size.width * .08 * unlocked,
        size.height * .43 - rightLift,
      );
    canvas.drawPath(shacklePath, shackle);

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .08,
        size.height * .32,
        size.width * .84,
        size.height * .64,
      ),
      Radius.circular(size.width * .15),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE47B), Color(0xFFD39A2E), Color(0xFF8D4B0F)],
        ).createShader(bodyRect.outerRect),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = const Color(0xFFFFF0B2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final spade = Path()
      ..moveTo(size.width * .50, size.height * .49)
      ..cubicTo(
        size.width * .42,
        size.height * .59,
        size.width * .31,
        size.height * .63,
        size.width * .31,
        size.height * .70,
      )
      ..cubicTo(
        size.width * .31,
        size.height * .80,
        size.width * .45,
        size.height * .78,
        size.width * .50,
        size.height * .71,
      )
      ..cubicTo(
        size.width * .55,
        size.height * .78,
        size.width * .69,
        size.height * .80,
        size.width * .69,
        size.height * .70,
      )
      ..cubicTo(
        size.width * .69,
        size.height * .63,
        size.width * .58,
        size.height * .59,
        size.width * .50,
        size.height * .49,
      )
      ..close();
    canvas.drawPath(spade, Paint()..color = const Color(0xFF2F1508));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .45,
          size.height * .70,
          size.width * .10,
          size.height * .13,
        ),
        Radius.circular(size.width * .03),
      ),
      Paint()..color = const Color(0xFF2F1508),
    );
  }

  @override
  bool shouldRepaint(covariant _VaultLockPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.pulse != pulse ||
      oldDelegate.unlocked != unlocked;
}

class _RewardToken extends StatelessWidget {
  const _RewardToken({
    required this.reward,
    required this.glow,
    required this.revealed,
    this.shine = 0,
  });

  final RoyalVaultRewardViewModel reward;
  final double glow;
  final bool revealed;

  /// 0..1 sweep of a light band across the settled token.
  final double shine;

  @override
  Widget build(BuildContext context) {
    final displayColor = revealed ? reward.rarityColor : context.wildcard.mint;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF30134E), Color(0xFF160A2A), Color(0xFF050B15)],
          stops: [0, .58, 1],
        ),
        border: Border.all(color: displayColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: displayColor.withValues(alpha: .28 + .42 * glow),
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
            Positioned(
              right: -17,
              bottom: -24,
              child: Icon(
                Icons.style_rounded,
                size: 90,
                color: displayColor.withValues(alpha: .07),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 8, 7, 7),
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: displayColor.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      child: Text(
                        revealed ? reward.categoryLabel : 'SEALED PRIZE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: displayColor,
                          fontFamily: 'Bungee',
                          fontSize: 6.5,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: displayColor.withValues(alpha: .14),
                      border: Border.all(
                        color: displayColor.withValues(alpha: .55),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: displayColor.withValues(
                            alpha: .18 + .25 * glow,
                          ),
                          blurRadius: 12 + 9 * glow,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        revealed ? reward.icon : Icons.question_mark_rounded,
                        color: const Color(0xFFFFF0C2),
                        size: 32,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (revealed)
                    Text(
                      reward.name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: displayColor,
                        fontFamily: 'Bungee',
                        fontSize: 11,
                        height: 1.04,
                      ),
                    )
                  else
                    Text(
                      'IDENTIFYING\u2026',
                      style: TextStyle(
                        color: displayColor.withValues(alpha: .74),
                        fontFamily: 'Bungee',
                        fontSize: 8,
                        letterSpacing: .6,
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
}

class _RarityScan extends StatelessWidget {
  const _RarityScan({
    required this.value,
    required this.color,
    required this.compact,
    required this.locked,
    required this.pulse,
  });

  final String value;
  final Color color;
  final bool compact;
  final bool locked;
  final double pulse;

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: pulse,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: color.withValues(alpha: .84),
            width: locked ? 1.4 : 1,
          ),
        ),
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            color.withValues(alpha: locked ? .22 : .12),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            locked ? 'RARITY LOCKED' : 'RARITY SCAN',
            style: TextStyle(
              color: const Color(0xFFD7D0C3),
              fontFamily: 'Bungee',
              fontSize: compact ? 6.5 : 7.5,
              letterSpacing: 1.25,
            ),
          ),
          SizedBox(height: compact ? 3 : 5),
          Text(
            value,
            key: const Key('royal-vault-rarity'),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: color,
              fontFamily: 'Bungee',
              fontSize: compact ? 13 : 17,
              letterSpacing: 1.15,
              shadows: locked
                  ? [
                      Shadow(
                        color: color.withValues(alpha: .78),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
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
    final footPaint = Paint()
      ..shader = LinearGradient(
        colors: [gold, const Color(0xFF6B370A)],
      ).createShader(Offset.zero & size);
    for (final x in <double>[.15, .70]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * x,
            size.height * .76,
            size.width * .15,
            size.height * .22,
          ),
          Radius.circular(size.width * .035),
        ),
        footPaint,
      );
    }
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
    final frontRim = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .075,
        size.height * .01,
        size.width * .85,
        size.height * .17,
      ),
      Radius.circular(size.height * .08),
    );
    canvas.drawRRect(
      frontRim,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFFFF0A6), gold, const Color(0xFF8A4A0F)],
        ).createShader(frontRim.outerRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .11,
          size.height * .05,
          size.width * .78,
          size.height * .08,
        ),
        Radius.circular(size.height * .04),
      ),
      Paint()..color = Color.lerp(bodyColor, Colors.black, .18)!,
    );
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
    this.opening = 0,
  });

  final Color bodyColor;
  final Color gold;
  final Color gem;
  final double opening;

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
    if (opening > 0) {
      canvas.drawPath(
        lidPath,
        Paint()
          ..color = const Color(
            0xFF080311,
          ).withValues(alpha: (.82 * opening).clamp(0.0, 1.0)),
      );
    }
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
      oldDelegate.gem != gem ||
      oldDelegate.opening != opening;
}

class _ChestHingePainter extends CustomPainter {
  const _ChestHingePainter({required this.gold});

  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    final bar = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF7B3D0A), gold, const Color(0xFFFFE997), gold],
        stops: const [0, .28, .52, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height * .28, size.width, size.height * .46),
        Radius.circular(size.height * .23),
      ),
      bar,
    );
    for (final x in <double>[.12, .50, .88]) {
      canvas.drawCircle(
        Offset(size.width * x, size.height * .51),
        size.height * .23,
        Paint()..color = const Color(0xFFFFEBA0),
      );
      canvas.drawCircle(
        Offset(size.width * x, size.height * .51),
        size.height * .11,
        Paint()..color = const Color(0xFF6A3208),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChestHingePainter oldDelegate) =>
      oldDelegate.gold != gold;
}

class _VaultAtmospherePainter extends CustomPainter {
  const _VaultAtmospherePainter({
    required this.progress,
    required this.burst,
    required this.scanProgress,
    required this.color,
    required this.line,
  });

  final double progress;
  final double burst;
  final double scanProgress;
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

    if (scanProgress > 0) {
      final scanY = size.height * (.10 + .76 * ((progress * 2.7) % 1));
      canvas.drawRect(
        Rect.fromLTWH(0, scanY, size.width, 1.5),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              color.withValues(alpha: .46 * scanProgress),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(0, scanY, size.width, 2)),
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
  }

  @override
  bool shouldRepaint(covariant _VaultAtmospherePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.burst != burst ||
      oldDelegate.scanProgress != scanProgress ||
      oldDelegate.color != color ||
      oldDelegate.line != line;
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
