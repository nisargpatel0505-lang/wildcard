import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../wildcard_theme.dart';

@immutable
class BootProgress {
  const BootProgress(this.fraction, this.label);

  final double fraction;
  final String label;
}

const List<String> _bootTips = <String>[
  'Commit to one hand type early.',
  'Wild Jokers bend the rules.',
  'A planned discard can save the whole Heat.',
  'Read the modifier before spending a play.',
  'Coins earned during a run stay safe.',
];

/// First Flutter frame shown while local save recovery and bootstrap run.
///
/// Real recovery milestones remain visible as status text, while
/// [visualProgress] follows a deliberate two-second presentation timeline.
/// Firebase, ads, billing and Play Games start later, after privacy consent, so
/// none can block this screen or local play.
class BootLoadingScreen extends StatefulWidget {
  const BootLoadingScreen({
    this.failed = false,
    this.onRetry,
    this.progress,
    this.visualProgress,
    super.key,
  });

  final bool failed;
  final VoidCallback? onRetry;
  final ValueListenable<BootProgress>? progress;
  final Animation<double>? visualProgress;

  @override
  State<BootLoadingScreen> createState() => _BootLoadingScreenState();
}

class _BootLoadingScreenState extends State<BootLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
    value: .5,
  );
  late final AnimationController _palaceReveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  Timer? _tipTimer;
  int _tipIndex = 0;
  bool _motionDisabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPresentation();
  }

  @override
  void didUpdateWidget(covariant BootLoadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.failed != widget.failed) {
      _tipIndex = 0;
      _syncPresentation();
    }
  }

  void _syncPresentation() {
    _motionDisabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_motionDisabled || widget.failed) {
      _logoPulse
        ..stop()
        ..value = .5;
    } else if (!_logoPulse.isAnimating) {
      _logoPulse.repeat(reverse: true);
    }

    if (_motionDisabled) {
      _palaceReveal.value = 1;
    } else if (!_palaceReveal.isCompleted && !_palaceReveal.isAnimating) {
      _palaceReveal.forward();
    }

    if (widget.failed || _motionDisabled) {
      _tipTimer?.cancel();
      _tipTimer = null;
    } else {
      _tipTimer ??= Timer.periodic(const Duration(milliseconds: 1500), (_) {
        if (!mounted || widget.failed) return;
        setState(() => _tipIndex = (_tipIndex + 1) % _bootTips.length);
      });
    }
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _logoPulse.dispose();
    _palaceReveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final gold = tokens.gold;
    final mint = tokens.mint;
    final size = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final compact = size.width <= 340 || size.height <= 620;
    final logoWidth = (size.width * (compact ? .68 : .64))
        .clamp(205.0, 260.0)
        .toDouble();
    final panelWidth = (size.width - (compact ? 24 : 40))
        .clamp(280.0, 340.0)
        .toDouble();
    return ColoredBox(
      key: const ValueKey('wildcard-surface-loading'),
      color: tokens.pageBackground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _palaceReveal,
              curve: Curves.easeOutCubic,
            ),
            child: Image.asset(
              key: const Key('boot-palace-background'),
              tokens.backgroundAssetFor(WildcardUiSurface.loading)!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  ColoredBox(color: tokens.pageBackground),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tokens.ink.withValues(alpha: .18),
                  tokens.ink.withValues(alpha: .43),
                  tokens.ink.withValues(alpha: .82),
                ],
                stops: const [0, .50, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -.02),
                radius: .72,
                colors: [
                  Colors.transparent,
                  tokens.ink.withValues(alpha: .10),
                  tokens.ink.withValues(alpha: .48),
                ],
                stops: const [0, .64, 1],
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: _BootLogo(
                pulse: _logoPulse,
                motionDisabled: _motionDisabled,
                width: logoWidth,
                gold: gold,
                mint: mint,
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The native splash centres only the logo. Keep that anchor
                // independent from the progress copy so Flutter inherits the
                // exact same position instead of jumping upward.
                final panelTop =
                    (size.height / 2 -
                            safePadding.top +
                            logoWidth * .165 +
                            (compact ? 14 : 22))
                        .clamp(0.0, constraints.maxHeight - 132)
                        .toDouble();
                return Stack(
                  children: [
                    Positioned(
                      top: compact ? 10 : 18,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _PalaceKicker(
                          gold: gold,
                          mint: mint,
                          ink: tokens.ink,
                          textColor: tokens.cream,
                        ),
                      ),
                    ),
                    Positioned(
                      top: panelTop,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SizedBox(
                          width: panelWidth,
                          child: widget.failed
                              ? _BootFailurePanel(
                                  onRetry: widget.onRetry,
                                  fill: tokens.surfaceStrong,
                                  border: tokens.coral,
                                  titleColor: tokens.coral,
                                  textColor: tokens.cream,
                                  buttonColor: gold,
                                  buttonTextColor: tokens.onSecondaryAccent,
                                )
                              : _BootProgressPanel(
                                  progress: widget.progress,
                                  visualProgress: widget.visualProgress,
                                  tip: _bootTips[_tipIndex],
                                  motionDisabled: _motionDisabled,
                                  fill: gold,
                                  track: mint,
                                  textColor: tokens.cream,
                                  panelColor: tokens.surfaceStrong,
                                  panelBorder: tokens.violet,
                                  emptySegmentColor: tokens.disabledFill,
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PalaceKicker extends StatelessWidget {
  const _PalaceKicker({
    required this.gold,
    required this.mint,
    required this.ink,
    required this.textColor,
  });

  final Color gold;
  final Color mint;
  final Color ink;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Sly’s Palace',
    child: Container(
      key: const Key('boot-palace-kicker'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: .68),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gold.withValues(alpha: .58)),
        boxShadow: [
          BoxShadow(color: mint.withValues(alpha: .14), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('♠', style: TextStyle(color: mint, fontSize: 11, height: 1)),
          const SizedBox(width: 7),
          Text(
            'SLY’S PALACE',
            style: TextStyle(
              color: textColor,
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1,
              letterSpacing: 1.35,
            ),
          ),
          const SizedBox(width: 7),
          Text('♦', style: TextStyle(color: gold, fontSize: 10, height: 1)),
        ],
      ),
    ),
  );
}

class _BootLogo extends StatelessWidget {
  const _BootLogo({
    required this.pulse,
    required this.motionDisabled,
    required this.width,
    required this.gold,
    required this.mint,
  });

  final Animation<double> pulse;
  final bool motionDisabled;
  final double width;
  final Color gold;
  final Color mint;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: pulse,
    child: RepaintBoundary(
      child: SizedBox(
        width: width,
        height: width / 3.2,
        child: Image.asset(
          'assets/art/wildcard-logo-v692.webp',
          key: const Key('boot-logo-image'),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          semanticLabel: 'WILDCARD',
          errorBuilder: (_, _, _) => Center(
            child: Text(
              'WILDCARD',
              key: const Key('boot-logo-fallback'),
              style: TextStyle(fontFamily: 'Bungee', fontSize: 34, color: gold),
            ),
          ),
        ),
      ),
    ),
    builder: (context, child) {
      final amount = motionDisabled
          ? .5
          : Curves.easeInOut.transform(pulse.value);
      return Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: .20 + amount * .16,
            child: Transform.scale(
              scale: 1.02 + amount * .08,
              child: SizedBox(
                width: width * 1.08,
                height: width * .42,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        mint.withValues(alpha: .34),
                        gold.withValues(alpha: .13),
                        Colors.transparent,
                      ],
                      stops: const [0, .46, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.scale(scale: 1 + amount * .012, child: child),
        ],
      );
    },
  );
}

class _BootProgressPanel extends StatelessWidget {
  const _BootProgressPanel({
    required this.progress,
    required this.visualProgress,
    required this.tip,
    required this.motionDisabled,
    required this.fill,
    required this.track,
    required this.textColor,
    required this.panelColor,
    required this.panelBorder,
    required this.emptySegmentColor,
  });

  final ValueListenable<BootProgress>? progress;
  final Animation<double>? visualProgress;
  final String tip;
  final bool motionDisabled;
  final Color fill;
  final Color track;
  final Color textColor;
  final Color panelColor;
  final Color panelBorder;
  final Color emptySegmentColor;

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[?progress, ?visualProgress];
    if (listenables.isEmpty) {
      return _content(const BootProgress(.08, 'Opening the table…'), .08);
    }
    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        final status =
            progress?.value ?? const BootProgress(.08, 'Opening the table…');
        return _content(
          status,
          (visualProgress?.value ?? status.fraction).clamp(0.0, 1.0),
        );
      },
    );
  }

  Widget _content(BootProgress value, double visibleProgress) {
    final percent = (visibleProgress * 100).round();
    return Container(
      key: const Key('boot-progress-panel'),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            panelColor.withValues(alpha: .96),
            panelColor.withValues(alpha: .84),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: panelBorder.withValues(alpha: .82),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .42),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(color: track.withValues(alpha: .10), blurRadius: 12),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: track,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: track.withValues(alpha: .55),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  value.label,
                  key: const Key('boot-status-label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    height: 1.1,
                    letterSpacing: .25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                key: const Key('boot-progress-percent'),
                style: TextStyle(
                  color: fill,
                  fontFamily: 'Bungee',
                  fontSize: 12,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SegmentedLoadBar(
            progress: visibleProgress,
            fill: fill,
            track: track,
            emptyColor: emptySegmentColor,
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: panelBorder.withValues(alpha: .32)),
          const SizedBox(height: 9),
          AnimatedSwitcher(
            duration: motionDisabled
                ? Duration.zero
                : const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Row(
              key: ValueKey('boot-tip-$tip'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_rounded, color: fill, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'SLY’S TIP  ',
                          style: TextStyle(
                            color: fill,
                            fontFamily: 'SpaceGrotesk',
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                            letterSpacing: .35,
                          ),
                        ),
                        TextSpan(
                          text: tip,
                          style: TextStyle(
                            color: textColor,
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            height: 1.24,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedLoadBar extends StatelessWidget {
  const _SegmentedLoadBar({
    required this.progress,
    required this.fill,
    required this.track,
    required this.emptyColor,
  });

  static const int segmentCount = 12;

  final double progress;
  final Color fill;
  final Color track;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    return Semantics(
      label: 'Loading WILDCARD',
      value: '${(value * 100).round()} percent',
      child: SizedBox(
        key: const Key('boot-segmented-progress'),
        height: 18,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: emptyColor.withValues(alpha: .74),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: track.withValues(alpha: .34)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < segmentCount; index++) ...[
                  Expanded(
                    child: _LoadSegment(
                      index: index,
                      progress: value,
                      fill: fill,
                      track: track,
                      emptyColor: emptyColor,
                    ),
                  ),
                  if (index != segmentCount - 1) const SizedBox(width: 2),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadSegment extends StatelessWidget {
  const _LoadSegment({
    required this.index,
    required this.progress,
    required this.fill,
    required this.track,
    required this.emptyColor,
  });

  final int index;
  final double progress;
  final Color fill;
  final Color track;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    final start = index / _SegmentedLoadBar.segmentCount;
    final fraction = ((progress - start) * _SegmentedLoadBar.segmentCount)
        .clamp(0.0, 1.0)
        .toDouble();
    final activeColor = Color.lerp(
      fill,
      track,
      index / (_SegmentedLoadBar.segmentCount - 1) * .58,
    )!;
    return ClipRRect(
      key: ValueKey('boot-progress-segment-$index'),
      borderRadius: BorderRadius.circular(2.5),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: emptyColor),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              key: ValueKey('boot-progress-fill-$index'),
              widthFactor: fraction,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: activeColor,
                  boxShadow: fraction > 0 && fraction < 1
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: .78),
                            blurRadius: 5,
                          ),
                        ]
                      : const [],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BootFailurePanel extends StatelessWidget {
  const _BootFailurePanel({
    required this.onRetry,
    required this.fill,
    required this.border,
    required this.titleColor,
    required this.textColor,
    required this.buttonColor,
    required this.buttonTextColor,
  });

  final VoidCallback? onRetry;
  final Color fill;
  final Color border;
  final Color titleColor;
  final Color textColor;
  final Color buttonColor;
  final Color buttonTextColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('boot-failure-panel'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: fill.withValues(alpha: .95),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border.withValues(alpha: .82), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_reset_rounded, color: titleColor, size: 20),
              const SizedBox(width: 7),
              Text(
                'TABLE LOCKED',
                style: TextStyle(
                  color: titleColor,
                  fontFamily: 'Bungee',
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'WILDCARD could not finish opening. Your local save is safe.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontFamily: 'SpaceGrotesk',
              fontSize: 11.5,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 11),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            style: FilledButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: buttonTextColor,
              minimumSize: const Size(160, 48),
            ),
            label: const Text(
              'RETRY',
              style: TextStyle(fontFamily: 'Bungee', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
