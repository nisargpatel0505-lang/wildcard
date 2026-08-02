import 'package:flutter/material.dart';

import '../../ui/wildcard_ui.dart';
import 'page_frame.dart';

/// First decision after New Run.
///
/// Arcade deliberately remains a separate callback so the existing
/// [ModePickerScreen] can stay intact behind it.
class RunTypePickerScreen extends StatelessWidget {
  const RunTypePickerScreen({
    required this.onOpenLevels,
    required this.onOpenArcade,
    super.key,
  });

  final VoidCallback onOpenLevels;
  final VoidCallback onOpenArcade;

  @override
  Widget build(BuildContext context) {
    return WildcardPageFrame(
      title: 'New Run',
      subtitle: 'Choose how you want to challenge Sly.',
      room: WildcardRoom.runSetup,
      surface: WildcardUiSurface.modePicker,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          _RunTypeCard(
            key: const ValueKey('run-type-levels'),
            title: 'Levels',
            eyebrow: '100 authored tables',
            description:
                'Solve focused poker challenges with fixed decks, special rules and permanent campaign progress.',
            icon: Icons.map_rounded,
            accent: context.wildcard.gold,
            onTap: onOpenLevels,
          ),
          const SizedBox(height: 16),
          _RunTypeCard(
            key: const ValueKey('run-type-arcade'),
            title: 'Arcade',
            eyebrow: 'The original WILDCARD run',
            description:
                'Play Normal, Daily or Gauntlet with stakes, shops and your permanent Joker collection.',
            icon: Icons.style_rounded,
            accent: context.wildcard.mint,
            onTap: onOpenArcade,
          ),
          const SizedBox(height: 18),
          Text(
            'Level tables never spend coins, consume Daily attempts or change Arcade rewards.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.wildcard.creamDim,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _RunTypeCard extends StatelessWidget {
  const _RunTypeCard({
    required this.title,
    required this.eyebrow,
    required this.description,
    required this.icon,
    required this.accent,
    required this.onTap,
    super.key,
  });

  final String title;
  final String eyebrow;
  final String description;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $description',
      child: WildcardCard(
        accent: title == 'Levels'
            ? WildcardCardAccent.gold
            : WildcardCardAccent.mint,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 176),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: .13),
                    border: Border.all(color: accent, width: 1.6),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: .18),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: accent, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow.toUpperCase(),
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          color: context.wildcard.cream,
                          fontFamily: 'Bungee',
                          fontSize: 25,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        description,
                        style: TextStyle(
                          color: context.wildcard.creamDim,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: accent, size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
