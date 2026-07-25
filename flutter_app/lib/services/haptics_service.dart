import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralised haptics.
///
/// The WebView build called a native `nativeHaptic()` on selection, play,
/// discard and Heat transitions. The first Flutter port dropped it entirely, so
/// the game felt inert in the hand. Everything here is fire-and-forget: a
/// failed or unsupported vibration must never interrupt gameplay, and haptics
/// follow the player's sound preference so one switch silences the whole feel.
class HapticsService {
  HapticsService({this.enabled = true});

  /// Mirrors the player's sound preference.
  bool enabled;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void _fire(Future<void> Function() action) {
    if (!enabled || !_supported) return;
    // Deliberately not awaited: haptics must never add latency to a tap.
    action().catchError((_) {});
  }

  /// Card picked up or put down.
  void selection() => _fire(HapticFeedback.selectionClick);

  /// A hand is committed.
  void play() => _fire(HapticFeedback.mediumImpact);

  /// Cards discarded.
  void discard() => _fire(HapticFeedback.lightImpact);

  /// A Joker fires during scoring.
  void jokerBeat() => _fire(HapticFeedback.selectionClick);

  /// Heat cleared.
  void success() => _fire(HapticFeedback.heavyImpact);

  /// Run lost or abandoned.
  void failure() => _fire(HapticFeedback.vibrate);
}
