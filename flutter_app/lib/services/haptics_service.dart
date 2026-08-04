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

  /// A card contributes rank.
  void cardBeat() => _fire(HapticFeedback.selectionClick);

  /// A retrigger is a deliberately distinct double pulse.
  void retrigger() => _fire(() async {
    await HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 65));
    await HapticFeedback.selectionClick();
  });

  /// Additive or multiplicative score lift.
  void multiplier() => _fire(HapticFeedback.mediumImpact);

  /// Heat cleared.
  void success() => _fire(HapticFeedback.heavyImpact);

  /// A restrained presentation pulse (Vault charge/common reward).
  void light() => _fire(HapticFeedback.lightImpact);

  /// A mechanical presentation click (Vault latch/lid).
  void medium() => _fire(HapticFeedback.mediumImpact);

  /// Premium WILD impact with one short follow-up, never awaited by gameplay.
  void wildSuccess() => _fire(() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  });

  /// Run lost or abandoned.
  void failure() => _fire(HapticFeedback.vibrate);
}
