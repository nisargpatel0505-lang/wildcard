import 'dart:async';

import 'package:flutter/material.dart';

import '../wildcard_theme.dart';

OverlayEntry? _activeToast;

/// WILDCARD's own toast, replacing the stock Material SnackBar.
///
/// The WebView build never showed a grey Material bar; its toasts were dark
/// navy cards with a coloured accent that slid up from the bottom. The stock
/// SnackBar was the one surface in the port that instantly read as "not the
/// same app", so every message now routes through this.
///
/// Every timer lives inside the toast's own state, so a disposed widget tree
/// (or a widget test) never leaves a dangling removal timer behind.
void showWildcardToast(
  BuildContext context,
  String message, {
  Color? accent,
  IconData? icon,
  Duration duration = const Duration(milliseconds: 2600),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  hideWildcardToast();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _WildcardToast(
      message: message,
      accent: accent,
      icon: icon,
      duration: duration,
      onDismissed: () {
        if (_activeToast == entry) _activeToast = null;
        try {
          entry.remove();
        } catch (_) {
          // The overlay may already be tearing down; nothing to remove.
        }
      },
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
}

void hideWildcardToast() {
  final entry = _activeToast;
  _activeToast = null;
  if (entry == null) return;
  try {
    entry.remove();
  } catch (_) {
    // Already removed with its overlay.
  }
}

class _WildcardToast extends StatefulWidget {
  const _WildcardToast({
    required this.message,
    required this.duration,
    required this.onDismissed,
    this.accent,
    this.icon,
  });

  final String message;
  final Duration duration;
  final VoidCallback onDismissed;
  final Color? accent;
  final IconData? icon;

  @override
  State<_WildcardToast> createState() => _WildcardToastState();
}

class _WildcardToastState extends State<_WildcardToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..forward();
  Timer? _out;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        // Fade-out finished: retire the overlay entry from within the
        // widget's own lifecycle.
        widget.onDismissed();
      }
    });
    _out = Timer(widget.duration, () {
      if (mounted) _c.reverse();
    });
  }

  @override
  void dispose() {
    _out?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final accent = widget.accent ?? tokens.gold;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 20,
      right: 20,
      bottom: bottom + 76,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = Curves.easeOutCubic.transform(_c.value);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 18 * (1 - t)),
                child: child,
              ),
            );
          },
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xF20A0820),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.85),
                    width: 1.4,
                  ),
                  boxShadow: [
                    const BoxShadow(
                      color: Color(0xB3000000),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                    BoxShadow(
                      color: accent.withValues(alpha: 0.22),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: accent, size: 16),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.cream,
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
