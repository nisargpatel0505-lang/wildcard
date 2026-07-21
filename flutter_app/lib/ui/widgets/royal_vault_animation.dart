import 'dart:math' as math;

import 'package:flutter/material.dart';

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
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Royal Vault reward',
    barrierColor: const Color(0xE6000308),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, _, _) => RoyalVaultAnimation(
      tier: tier,
      reward: reward,
      fast: fast,
      onClaim: () => Navigator.of(dialogContext).pop(),
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.975, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    ),
  );
}

class RoyalVaultAnimation extends StatefulWidget {
  const RoyalVaultAnimation({
    required this.tier,
    required this.reward,
    required this.fast,
    required this.onClaim,
    this.durationOverride,
    super.key,
  });

  final RoyalVaultVisualTier tier;
  final RoyalVaultRewardViewModel reward;
  final bool fast;
  final VoidCallback onClaim;

  /// Exposed for deterministic widget tests; production uses Normal/Fast time.
  final Duration? durationOverride;

  @override
  State<RoyalVaultAnimation> createState() => _RoyalVaultAnimationState();
}

class _RoyalVaultAnimationState extends State<RoyalVaultAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _claimEnabled = false;
  bool _claimHandled = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration:
              widget.durationOverride ??
              (widget.fast
                  ? const Duration(milliseconds: 2050)
                  : const Duration(milliseconds: 3850)),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _claimEnabled = true);
          }
        });
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
    final tokens = context.wildcard;
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
                    maxWidth: 520,
                    maxHeight: 760,
                  ),
                  child: DecoratedBox(
                    key: const Key('royal-vault-dialog'),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: tokens.violet.withValues(alpha: 0.92),
                        width: 2.5,
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFA1A0A3B), Color(0xFC050B18)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: tokens.violet.withValues(alpha: 0.3),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => _VaultLayout(
                          progress: _controller.value,
                          tier: widget.tier,
                          reward: widget.reward,
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
      ),
    );
  }
}

class _VaultLayout extends StatelessWidget {
  const _VaultLayout({
    required this.progress,
    required this.tier,
    required this.reward,
    required this.claimEnabled,
    required this.onClaim,
  });

  final double progress;
  final RoyalVaultVisualTier tier;
  final RoyalVaultRewardViewModel reward;
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
    if (progress < .19) return 'THE LOCK IS READING YOUR PRIZE';
    if (progress < .39) return 'RARITY SIGNAL FOUND';
    if (progress < .55) return 'SEAL RELEASED';
    if (progress < .82) return 'REWARD EMERGING';
    return 'REWARD SECURED';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final compact = MediaQuery.sizeOf(context).height < 650;
    final rarityReveal = _interval(.20, .34, Curves.easeOutBack);
    final detailsReveal = _interval(.75, .91, Curves.easeOutCubic);

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
            _vaultName,
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
          const SizedBox(height: 4),
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
  });

  final double progress;
  final RoyalVaultVisualTier tier;
  final RoyalVaultRewardViewModel reward;
  final bool compact;

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
    final unlock = _interval(.39, .53, Curves.easeInOutBack);
    final opening = _interval(.51, .68, Curves.easeOutCubic);
    final burst = _interval(.55, .75, Curves.easeOutCubic);
    final rewardRise = _interval(.62, .84, Curves.easeOutBack);
    final lockPulse = .5 + .5 * math.sin(progress * math.pi * 12);
    final bodyColor = switch (tier) {
      RoyalVaultVisualTier.wooden => const Color(0xFF8B4B25),
      RoyalVaultVisualTier.golden => const Color(0xFF3E8F8A),
      RoyalVaultVisualTier.cosmetic => const Color(0xFF61378D),
    };

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
          final chestTop = math.max(
            compact ? 28.0 : 42.0,
            sceneHeight - chestHeight - (compact ? 8 : 14),
          );

          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: reward.rarityColor.withValues(alpha: .9),
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
                      burst: burst,
                      color: reward.rarityColor,
                      line: tokens.violet,
                    ),
                  ),
                  if (burst > 0)
                    Opacity(
                      opacity: (burst * .88).clamp(0, 1),
                      child: CustomPaint(
                        painter: _ParticlePainter(
                          progress: burst,
                          color: reward.rarityColor,
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
                  Positioned(
                    left: (sceneWidth - chestWidth) / 2,
                    top: chestTop,
                    width: chestWidth,
                    height: chestHeight * .49,
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, .0015)
                        ..rotateX(-opening * 1.05),
                      child: CustomPaint(
                        painter: _ChestLidPainter(
                          bodyColor: bodyColor,
                          gold: tokens.gold,
                          gem: tokens.mint,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: sceneWidth / 2 - 28,
                    top: chestTop + chestHeight * .39 + 22 * unlock,
                    width: 56,
                    height: 64,
                    child: Opacity(
                      opacity: 1 - unlock,
                      child: Transform.rotate(
                        angle: unlock * .42,
                        child: _AnimatedLock(
                          pulse: lockPulse,
                          color: tokens.gold,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: sceneWidth / 2 - (compact ? 34 : 40),
                    top:
                        chestTop +
                        chestHeight * .22 -
                        rewardRise * (compact ? 50 : 68),
                    width: compact ? 68 : 80,
                    height: compact ? 76 : 90,
                    child: Opacity(
                      opacity: rewardRise,
                      child: Transform.scale(
                        scale: .68 + .32 * rewardRise,
                        child: _RewardToken(reward: reward, glow: burst),
                      ),
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
  const _AnimatedLock({required this.pulse, required this.color});

  final double pulse;
  final Color color;

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
    child: const Icon(Icons.lock_rounded, color: Color(0xFF321607), size: 30),
  );
}

class _RewardToken extends StatelessWidget {
  const _RewardToken({required this.reward, required this.glow});

  final RoyalVaultRewardViewModel reward;
  final double glow;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF9E7), Color(0xFFE8DAC2)],
      ),
      border: Border.all(color: reward.rarityColor, width: 2.5),
      boxShadow: [
        BoxShadow(
          color: reward.rarityColor.withValues(alpha: .35 + .35 * glow),
          blurRadius: 14 + 18 * glow,
          spreadRadius: 1 + 2 * glow,
        ),
      ],
    ),
    child: Icon(reward.icon, color: const Color(0xFF23102F), size: 38),
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

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * .64);
    final fade = (1 - (progress - .62).clamp(0.0, 1.0)).clamp(0.0, 1.0);
    for (var index = 0; index < 24; index++) {
      final angle = -math.pi + (index / 23) * math.pi * 2;
      final speed = .22 + ((index * 37) % 10) / 42;
      final distance = size.shortestSide * speed * progress;
      final wobble = math.sin(index * 2.3 + progress * 7) * 6;
      final point = Offset(
        origin.dx + math.cos(angle) * distance + wobble,
        origin.dy + math.sin(angle) * distance - progress * size.height * .13,
      );
      final radius = 1.2 + (index % 4) * .55;
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color = (index.isEven ? color : const Color(0xFFFFD35C)).withValues(
            alpha: .18 + .7 * fade,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
