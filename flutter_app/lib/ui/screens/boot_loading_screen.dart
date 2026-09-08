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
      _tipTimer ??= Timer.periodic(const Duration(milliseconds: 4500), (_) {
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
    final width = MediaQuery.sizeOf(context).width;
    final logoWidth = (width - 56).clamp(180.0, 340.0).toDouble();
    return Scaffold(
      key: const ValueKey('wildcard-surface-loading'),
      backgroundColor: tokens.pageBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _palaceReveal,
              curve: Curves.easeOutCubic,
            ),
            child: Image.asset(
              tokens.backgroundAssetFor(WildcardUiSurface.loading)!,
              fit: BoxFit.cover,
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
                  tokens.ink.withValues(alpha: .34),
                  tokens.ink.withValues(alpha: .88),
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Keep one coherent, scroll-safe composition. Positioned text
                // previously overlapped at larger text sizes. Scaffold also
                // supplies a real Material text style instead of Flutter's
                // yellow-double-underlined emergency fallback.
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'THE HOUSE IS OPEN',
                            style: TextStyle(
                              color: tokens.cream.withValues(alpha: .80),
                              fontFamily: 'SpaceGrotesk',
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 2.2,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _BootLogo(
                            pulse: _logoPulse,
                            motionDisabled: _motionDisabled,
                            width: logoWidth,
                            gold: gold,
                            mint: mint,
                          ),
                          const SizedBox(height: 28),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: widget.failed
                                ? Card(
                                    color: tokens.surfaceStrong,
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Your table could not open.',
                                            style: TextStyle(
                                              color: tokens.cream,
                                              fontFamily: 'SpaceGrotesk',
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Your saved progress has not been reset.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: tokens.cream.withValues(
                                                alpha: .72,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          _RetryPrompt(onRetry: widget.onRetry),
                                        ],
                                      ),
                                    ),
                                  )
                                : _BootProgressPanel(
                                    progress: widget.progress,
                                    visualProgress: widget.visualProgress,
                                    tip: _bootTips[_tipIndex],
                                    fill: gold,
                                    track: mint,
                                    textColor: tokens.cream,
                                    background: tokens.surfaceStrong,
                                    emptySegmentColor: tokens.disabledFill,
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
    required this.fill,
    required this.track,
    required this.textColor,
    required this.background,
    required this.emptySegmentColor,
  });

  final ValueListenable<BootProgress>? progress;
  final Animation<double>? visualProgress;
  final String tip;
  final Color fill;
  final Color track;
  final Color textColor;
  final Color background;
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

  Widget _content(BootProgress value, double visibleProgress) => Container(
    key: const Key('boot-progress-panel'),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: background.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: fill.withValues(alpha: .46)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'PREPARING YOUR TABLE',
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(visibleProgress * 100).round()}%',
              key: const Key('boot-progress-percent'),
              style: TextStyle(
                color: fill,
                fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SegmentedLoadBar(
          progress: visibleProgress,
          fill: fill,
          track: track,
          emptyColor: emptySegmentColor,
        ),
        const SizedBox(height: 12),
        Text(
          value.label,
          key: const Key('boot-status-label'),
          style: TextStyle(
            color: track,
            fontFamily: 'SpaceGrotesk',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.35,
            decoration: TextDecoration.none,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 17),
          child: Divider(height: 1, color: fill.withValues(alpha: .20)),
        ),
        Text(
          'SLY’S TIP',
          style: TextStyle(
            color: fill,
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1.3,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 7),
        // One readable tip per ordinary launch. No simultaneous old/new text
        // layers; slow boots can move to another tip after 4.5 seconds.
        Text(
          tip,
          key: ValueKey('boot-tip-$tip'),
          style: TextStyle(
            color: textColor,
            fontFamily: 'SpaceGrotesk',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.4,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    ),
  );
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
        height: 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < segmentCount; index++) ...[
              Expanded(
                child: ClipRRect(
                  key: ValueKey('boot-progress-segment-$index'),
                  borderRadius: BorderRadius.circular(2),
                  child: ColoredBox(
                    color: Color.alphaBlend(
                      track.withValues(alpha: .14),
                      emptyColor,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (value * segmentCount - index).clamp(
                          0.0,
                          1.0,
                        ),
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color.lerp(fill, Colors.white, .25)!,
                                fill,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return FilledButton(
      onPressed: onRetry,
      style: FilledButton.styleFrom(
        backgroundColor: tokens.gold,
        foregroundColor: tokens.onSecondaryAccent,
        minimumSize: const Size(140, 48),
      ),
      child: const Text('Retry', style: TextStyle(fontFamily: 'Bungee')),
    );
  }
}
