import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/account_state.dart';
import '../../domain/arcade_rules.dart';
import '../../game/arcade_controller.dart';
import '../../ui/wildcard_ui.dart';
import 'arcade_run_screen.dart';
import 'page_frame.dart';

class ArcadeModePickerScreen extends StatefulWidget {
  const ArcadeModePickerScreen({required this.account, super.key});

  final AccountState account;

  @override
  State<ArcadeModePickerScreen> createState() => _ArcadeModePickerScreenState();
}

class _ArcadeModePickerScreenState extends State<ArcadeModePickerScreen> {
  ArcadeRunLength selected = ArcadeRunLength.sprint8;

  bool get challengeUnlocked =>
      widget.account.bestClearedHeat >= ArcadeRules.challengeUnlockHeat;

  @override
  Widget build(BuildContext context) {
    return WildcardPageFrame(
      title: 'WILDCARD Arcade',
      subtitle: 'Deal five. Choose exactly three. Beat the target.',
      room: WildcardRoom.themedHome,
      surface: WildcardUiSurface.arcadeModePicker,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
        children: [
          WildcardPanel(
            padding: const EdgeInsets.all(14),
            borderColor: context.wildcard.mint,
            child: const Text(
              'Fast three-card poker with one decision per round. '
              'There are no discards; Sly opens the shop every three clears.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
          const ScreenSectionTitle('Run length'),
          for (final length in ArcadeRunLength.values) ...[
            _lengthCard(length),
            const SizedBox(height: 9),
          ],
          const SizedBox(height: 8),
          WildcardButton(
            key: const Key('start-arcade-run'),
            label: 'Deal ${selected.displayName}',
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: _start,
            variant: WildcardButtonVariant.primary,
            minHeight: 60,
            fontSize: 14,
          ),
        ],
      ),
    );
  }

  Widget _lengthCard(ArcadeRunLength length) {
    final locked = length == ArcadeRunLength.challenge30 && !challengeUnlocked;
    final active = selected == length;
    final milestoneCopy = length == ArcadeRunLength.endless
        ? ' Milestones: 25, 50, 75 and 100.'
        : '';
    return WildcardCard(
      key: ValueKey('arcade-length-${length.name}'),
      selected: active,
      accent: active ? WildcardCardAccent.gold : WildcardCardAccent.violet,
      onTap: locked ? null : () => setState(() => selected = length),
      child: Row(
        children: [
          Icon(
            locked
                ? Icons.lock_outline_rounded
                : length.isEndless
                ? Icons.all_inclusive_rounded
                : Icons.bolt_rounded,
            color: locked ? context.wildcard.creamDim : context.wildcard.gold,
            size: 29,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  length.displayName.toUpperCase(),
                  style: TextStyle(
                    color: active
                        ? context.wildcard.gold
                        : context.wildcard.cream,
                    fontFamily: 'Bungee',
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  locked
                      ? 'Locked — clear Heat ${ArcadeRules.challengeUnlockHeat} in a normal run.'
                      : '${length.description}$milestoneCopy',
                  style: TextStyle(
                    color: context.wildcard.creamDim,
                    fontSize: 11.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _start() {
    final controller = ArcadeController.start(
      ArcadeRunConfig(
        length: selected,
        rngSeed: math.Random.secure().nextInt(0x7fffffff),
        discoveredJokerIds: widget.account.unlockedJokerIds,
        turbo: false,
      ),
    );
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ArcadeRunScreen(controller: controller),
      ),
    );
  }
}
