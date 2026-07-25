import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../wildcard_theme.dart';

@immutable
class BootProgress {
  const BootProgress(this.fraction, this.label);

  final double fraction;
  final String label;
}

/// First Flutter frame shown while local save recovery and bootstrap run.
///
/// The progress bar is driven by real local milestones. Firebase, ads, billing
/// and Play Games start later, after privacy consent, so none can block this
/// screen or local play.
class BootLoadingScreen extends StatelessWidget {
  const BootLoadingScreen({
    this.failed = false,
    this.onRetry,
    this.progress,
    super.key,
  });

  final bool failed;
  final VoidCallback? onRetry;
  final ValueListenable<BootProgress>? progress;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFF7C548);
    const mint = Color(0xFF45E0C6);
    return ColoredBox(
      color: const Color(0xFF080414),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            WildcardThemeTokens.palaceBackground,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF0A0620)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66080414), Color(0xE6080414)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/art/wildcard-logo-v692.webp',
                    width: 260,
                    errorBuilder: (_, _, _) => const Text(
                      'WILDCARD',
                      style: TextStyle(
                        fontFamily: 'Bungee',
                        fontSize: 34,
                        color: gold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (failed)
                    _RetryPrompt(onRetry: onRetry)
                  else
                    SizedBox(
                      width: 240,
                      child: _BootProgressPanel(
                        progress: progress,
                        fill: gold,
                        track: mint,
                      ),
                    ),
                  if (failed) ...[
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BootProgressPanel extends StatelessWidget {
  const _BootProgressPanel({
    required this.progress,
    required this.fill,
    required this.track,
  });

  final ValueListenable<BootProgress>? progress;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final listenable = progress;
    if (listenable == null) {
      return _content(const BootProgress(.08, 'Opening the table…'));
    }
    return ValueListenableBuilder<BootProgress>(
      valueListenable: listenable,
      builder: (context, value, _) => _content(value),
    );
  }

  Widget _content(BootProgress value) => Column(
    children: [
      _LoadBar(progress: value.fraction, fill: fill, track: track),
      const SizedBox(height: 14),
      Text(
        value.label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: track,
          fontFamily: 'Bungee',
          fontSize: 11,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );
}

class _LoadBar extends StatelessWidget {
  const _LoadBar({
    required this.progress,
    required this.fill,
    required this.track,
  });

  final double progress;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      height: 10,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF15102E),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: track.withValues(alpha: 0.4)),
              ),
            ),
          ),
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: progress.clamp(0.02, 1).toDouble(),
              ),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 210),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      colors: [
                        fill.withValues(alpha: .72),
                        fill,
                        fill.withValues(alpha: .86),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: fill.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
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
