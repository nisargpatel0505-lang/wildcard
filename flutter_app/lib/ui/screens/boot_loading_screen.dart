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

    if (widget.failed) {
      _tipTimer?.cancel();
      _tipTimer = null;
    } else {
      _tipTimer ??= Timer.periodic(const Duration(milliseconds: 1050), (_) {
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
    const gold = Color(0xFFF7C548);
    const mint = Color(0xFF45E0C6);
    final width = MediaQuery.sizeOf(context).width;
    final logoWidth = (width * .60).clamp(205.0, 240.0).toDouble();
    final panelWidth = (width - 48).clamp(230.0, 300.0).toDouble();
    return ColoredBox(
      color: const Color(0xFF080414),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _palaceReveal,
              curve: Curves.easeOutCubic,
            ),
            child: Image.asset(
              WildcardThemeTokens.palaceBackground,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(0xFF080414)),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x76080414), Color(0xED080414)],
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
                    (constraints.maxHeight / 2 + logoWidth * .165 + 22)
                        .clamp(0.0, constraints.maxHeight - 96)
                        .toDouble();
                return Stack(
                  children: [
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
                    Positioned(
                      top: panelTop,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SizedBox(
                          width: panelWidth,
                          child: widget.failed
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _RetryPrompt(onRetry: widget.onRetry),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'Could not start',
                                      style: TextStyle(
                                        color: Color(0xFFFF9A8A),
                                        fontFamily: 'Bungee',
                                        fontSize: 11,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                )
                              : _BootProgressPanel(
                                  progress: widget.progress,
                                  visualProgress: widget.visualProgress,
                                  tip: _bootTips[_tipIndex],
                                  motionDisabled: _motionDisabled,
                                  fill: gold,
                                  track: mint,
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
      child: Image.asset(
        'assets/art/wildcard-logo-v692.webp',
        key: const Key('boot-logo-image'),
        width: width,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => Text(
          'WILDCARD',
          key: const Key('boot-logo-fallback'),
          style: TextStyle(fontFamily: 'Bungee', fontSize: 34, color: gold),
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
  });

  final ValueListenable<BootProgress>? progress;
  final Animation<double>? visualProgress;
  final String tip;
  final bool motionDisabled;
  final Color fill;
  final Color track;

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

  Widget _content(BootProgress value, double visibleProgress) => Column(
    children: [
      Text(
        value.label,
        key: const Key('boot-status-label'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: track,
          fontFamily: 'Bungee',
          fontSize: 9.5,
          letterSpacing: .85,
        ),
      ),
      const SizedBox(height: 9),
      _SegmentedLoadBar(progress: visibleProgress, fill: fill, track: track),
      const SizedBox(height: 14),
      AnimatedSwitcher(
        duration: motionDisabled
            ? Duration.zero
            : const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: Text.rich(
          key: ValueKey('boot-tip-$tip'),
          TextSpan(
            children: [
              TextSpan(
                text: 'SLY’S TIP  ',
                style: TextStyle(
                  color: fill,
                  fontFamily: 'Bungee',
                  fontSize: 9,
                  letterSpacing: .45,
                ),
              ),
              TextSpan(
                text: tip,
                style: const TextStyle(
                  color: Color(0xFFF6EFDF),
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
      ),
    ],
  );
}

class _SegmentedLoadBar extends StatelessWidget {
  const _SegmentedLoadBar({
    required this.progress,
    required this.fill,
    required this.track,
  });

  static const int segmentCount = 12;

  final double progress;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    return Semantics(
      label: 'Loading WILDCARD',
      value: '${(value * 100).round()} percent',
      child: SizedBox(
        key: const Key('boot-segmented-progress'),
        height: 12,
        child: Row(
          children: [
            for (var index = 0; index < segmentCount; index++) ...[
              Expanded(
                child: DecoratedBox(
                  key: ValueKey('boot-progress-segment-$index'),
                  decoration: BoxDecoration(
                    color: value >= (index + 1) / segmentCount
                        ? fill
                        : const Color(0xFF15102E),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: value >= (index + 1) / segmentCount
                          ? fill.withValues(alpha: .95)
                          : track.withValues(alpha: .34),
                    ),
                    boxShadow: value >= (index + 1) / segmentCount
                        ? [
                            BoxShadow(
                              color: fill.withValues(alpha: .28),
                              blurRadius: 4,
                            ),
                          ]
                        : const [],
                  ),
                ),
              ),
              if (index != segmentCount - 1) const SizedBox(width: 3),
            ],
          ],
        ),
      ),
    );
  }
}

class _RetryPrompt extends StatelessWidget {
  const _RetryPrompt({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onRetry,
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFFF7C548),
      foregroundColor: const Color(0xFF23180A),
      minimumSize: const Size(140, 48),
    ),
    child: const Text('Retry', style: TextStyle(fontFamily: 'Bungee')),
  );
}
