import 'package:flutter/material.dart';

import '../wildcard_theme.dart';

/// Branded loading screen shown while [AppController.bootstrap] runs.
///
/// The native Android splash is a static image; the port had no in-app loading
/// state at all, so a slow cold start showed a frozen frame. This adds the
/// animated gold load bar the player expected, on the palace art.
class BootLoadingScreen extends StatefulWidget {
  const BootLoadingScreen({this.failed = false, this.onRetry, super.key});

  final bool failed;
  final VoidCallback? onRetry;

  @override
  State<BootLoadingScreen> createState() => _BootLoadingScreenState();
}

class _BootLoadingScreenState extends State<BootLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

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
            errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF0A0620)),
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
          Center(
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
                SizedBox(
                  width: 220,
                  child: widget.failed
                      ? _RetryPrompt(onRetry: widget.onRetry)
                      : _LoadBar(controller: _c, fill: gold, track: mint),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.failed ? 'Could not start' : 'Shuffling the deck…',
                  style: TextStyle(
                    color: widget.failed ? const Color(0xFFFF9A8A) : mint,
                    fontFamily: 'Bungee',
                    fontSize: 11,
                    letterSpacing: 1.2,
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

class _LoadBar extends StatelessWidget {
  const _LoadBar({
    required this.controller,
    required this.fill,
    required this.track,
  });

  final AnimationController controller;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF15102E),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: track.withValues(alpha: 0.4)),
              ),
            ),
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                // A ~40% wide gold sweep that travels across the track and
                // loops — an indeterminate bar that still reads as progress.
                final t = Curves.easeInOut.transform(controller.value);
                return FractionallySizedBox(
                  alignment: Alignment(-1 + 2 * t, 0),
                  widthFactor: 0.42,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        colors: [
                          fill.withValues(alpha: 0),
                          fill,
                          fill.withValues(alpha: 0),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(color: fill.withValues(alpha: 0.5), blurRadius: 10),
                      ],
                    ),
                  ),
                );
              },
            ),
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
    ),
    child: const Text('Retry', style: TextStyle(fontFamily: 'Bungee')),
  );
}
