import 'package:flutter/material.dart';

/// Presentation-only effect budgets. They never alter game state, timing,
/// probability or rewards; they only cap decorative work.
enum EffectsQuality { batterySaver, reduced, full, ultra }

@immutable
class EffectsProfile {
  const EffectsProfile._({
    required this.quality,
    required this.backgroundMotion,
    required this.particleScale,
    required this.glowScale,
    required this.maxSimultaneousEffects,
    required this.highRefreshMotion,
  });

  const EffectsProfile.batterySaver()
    : this._(
        quality: EffectsQuality.batterySaver,
        backgroundMotion: false,
        particleScale: 0,
        glowScale: .35,
        maxSimultaneousEffects: 1,
        highRefreshMotion: false,
      );

  const EffectsProfile.reduced()
    : this._(
        quality: EffectsQuality.reduced,
        backgroundMotion: true,
        particleScale: .45,
        glowScale: .65,
        maxSimultaneousEffects: 2,
        highRefreshMotion: false,
      );

  const EffectsProfile.full()
    : this._(
        quality: EffectsQuality.full,
        backgroundMotion: true,
        particleScale: 1,
        glowScale: 1,
        maxSimultaneousEffects: 4,
        highRefreshMotion: true,
      );

  const EffectsProfile.ultra()
    : this._(
        quality: EffectsQuality.ultra,
        backgroundMotion: true,
        particleScale: 1.2,
        glowScale: 1.12,
        maxSimultaneousEffects: 5,
        highRefreshMotion: true,
      );

  final EffectsQuality quality;
  final bool backgroundMotion;
  final double particleScale;
  final double glowScale;
  final int maxSimultaneousEffects;
  final bool highRefreshMotion;

  /// Safe automatic default without changing the durable save schema.
  ///
  /// Very small/short devices receive the reduced budget. Large inner displays
  /// can afford Ultra; standard Android phones use Full. System reduced motion
  /// always wins and retains the readable sequence with decorative motion off.
  static EffectsProfile resolve(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) return const EffectsProfile.full();
    if (media.disableAnimations) return const EffectsProfile.batterySaver();
    final size = media.size;
    if (size.shortestSide < 350 || size.height < 620) {
      return const EffectsProfile.reduced();
    }
    if (size.shortestSide >= 600) return const EffectsProfile.ultra();
    return const EffectsProfile.full();
  }
}
