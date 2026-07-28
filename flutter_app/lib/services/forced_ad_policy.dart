import 'package:flutter/foundation.dart';

/// Why a forced terminal interstitial was allowed or suppressed.
enum ForcedInterstitialDecision {
  allowed,
  forcedAdsRemoved,
  tutorial,
  arcade,
  firstRun,
  shortAbandon,
  alreadyAttemptedForRun,
  cooldown,
}

/// The small amount of run state needed to make a terminal-ad decision.
///
/// Keeping this separate from the game controller prevents ads from being
/// requested from a scoring beat, Vault animation, or other mid-run surface.
@immutable
class TerminalInterstitialContext {
  const TerminalInterstitialContext({
    required this.runId,
    this.isTutorial = false,
    this.isArcade = false,
    this.isFirstRun = false,
    this.abandoned = false,
    this.handsPlayed = 0,
    this.stagesCleared = 0,
  });

  final String runId;
  final bool isTutorial;
  final bool isArcade;
  final bool isFirstRun;
  final bool abandoned;
  final int handsPlayed;
  final int stagesCleared;

  bool get isVeryShortAbandon =>
      abandoned && stagesCleared == 0 && handsPlayed <= 1;
}

/// Session-level guard for forced interstitials.
///
/// A nine-minute interval sits in the requested 8–10 minute window. A run is
/// marked as soon as an eligible request begins, so route rebuilds or repeated
/// terminal notifications cannot stack multiple fullscreen ads.
class ForcedInterstitialPolicy {
  ForcedInterstitialPolicy({
    DateTime Function()? now,
    this.cooldown = const Duration(minutes: 9),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration cooldown;
  final Set<String> _attemptedRunIds = <String>{};
  DateTime? _lastShownAt;

  @visibleForTesting
  DateTime? get lastShownAt => _lastShownAt;

  ForcedInterstitialDecision evaluate(
    TerminalInterstitialContext context, {
    required bool forcedAdsRemoved,
  }) {
    if (forcedAdsRemoved) {
      return ForcedInterstitialDecision.forcedAdsRemoved;
    }
    if (context.isTutorial) return ForcedInterstitialDecision.tutorial;
    if (context.isArcade) return ForcedInterstitialDecision.arcade;
    if (context.isFirstRun) return ForcedInterstitialDecision.firstRun;
    if (context.isVeryShortAbandon) {
      return ForcedInterstitialDecision.shortAbandon;
    }
    if (_attemptedRunIds.contains(context.runId)) {
      return ForcedInterstitialDecision.alreadyAttemptedForRun;
    }
    final lastShownAt = _lastShownAt;
    if (lastShownAt != null && _now().difference(lastShownAt) < cooldown) {
      return ForcedInterstitialDecision.cooldown;
    }
    return ForcedInterstitialDecision.allowed;
  }

  ForcedInterstitialDecision beginAttempt(
    TerminalInterstitialContext context, {
    required bool forcedAdsRemoved,
  }) {
    final decision = evaluate(context, forcedAdsRemoved: forcedAdsRemoved);
    if (decision != ForcedInterstitialDecision.allowed) return decision;
    final id = context.runId.trim();
    if (id.isEmpty) return ForcedInterstitialDecision.alreadyAttemptedForRun;
    _attemptedRunIds.add(id);
    if (_attemptedRunIds.length > 128) {
      _attemptedRunIds.remove(_attemptedRunIds.first);
    }
    return ForcedInterstitialDecision.allowed;
  }

  void recordShown() {
    _lastShownAt = _now();
  }
}
