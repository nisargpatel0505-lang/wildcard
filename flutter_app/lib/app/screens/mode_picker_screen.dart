import 'package:flutter/material.dart';

import '../../app/developer_access.dart';
import '../../core/daily_utc_date.dart';
import '../../domain/account_state.dart';
import '../../domain/economy.dart';
import '../../domain/game_rules.dart';
import '../../domain/joker_catalog.dart';
import '../../domain/progression_catalog.dart';
import '../../ui/wildcard_ui.dart';
import 'page_frame.dart';

class RunLaunchRequest {
  const RunLaunchRequest({
    required this.mode,
    required this.difficulty,
    required this.stake,
    this.startJokerId,
  });

  final RunMode mode;
  final RunDifficulty difficulty;
  final int stake;
  final String? startJokerId;
}

class ModePickerScreen extends StatefulWidget {
  const ModePickerScreen({
    required this.account,
    required this.onLaunch,
    required this.onOpenTutorial,
    super.key,
  });

  final AccountState account;
  final ValueChanged<RunLaunchRequest> onLaunch;
  final Future<void> Function() onOpenTutorial;

  @override
  State<ModePickerScreen> createState() => _ModePickerScreenState();
}

class _ModePickerScreenState extends State<ModePickerScreen> {
  RunMode mode = RunMode.normal;
  RunDifficulty difficulty = RunDifficulty.medium;
  int stake = 0;
  String? startJokerId;

  ProgressionGates get gates => ProgressionGates(
    tutorialDone: widget.account.tutorialDone,
    bestClearedHeat: widget.account.bestClearedHeat,
    unlockedJokers: publicUnlockedJokerCount(widget.account.unlockedJokerIds),
  );

  bool get dailyUsed => dailyAttemptUsedToday(
    storedDate: widget.account.dailyRunDate,
    utcMigrationComplete:
        widget.account.unknownFields[dailyRunDateUtcMarkerKey] == true,
  );

  bool get gauntletAvailable =>
      gates.gauntletUnlocked || developerGauntletUnlocked(widget.account);

  int get maxStake => mode == RunMode.daily
      ? 0
      : maximumStake(widget.account.coins, gauntlet: mode == RunMode.gauntlet);

  @override
  Widget build(BuildContext context) {
    return WildcardPageFrame(
      title: 'Choose Run',
      subtitle: 'Pick a table, then set your risk.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
        children: [
          if (!widget.account.tutorialDone) ...[
            WildcardPanel(
              borderColor: context.wildcard.gold,
              child: Column(
                children: [
                  Text(
                    'FIRST DEAL',
                    style: _heading(context, context.wildcard.gold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Learn scoring, Jokers, Heat targets and the shop before your first full run.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  WildcardButton(
                    label: 'Play Tutorial',
                    onPressed: _openTutorial,
                    variant: WildcardButtonVariant.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const ScreenSectionTitle('Run mode'),
          _modeCard(
            RunMode.normal,
            'Normal Run',
            'Build an engine across 12 Heats, then choose whether to enter Endless.',
            Icons.style_outlined,
          ),
          const SizedBox(height: 9),
          _modeCard(
            RunMode.daily,
            'Daily Challenge',
            dailyUsed
                ? 'Completed today — the next seeded challenge arrives tomorrow.'
                : 'The same Medium seed and Joker pool for every player today.',
            Icons.today_rounded,
            locked: !gates.dailyChallengeUnlocked || dailyUsed,
          ),
          const SizedBox(height: 9),
          _modeCard(
            RunMode.gauntlet,
            'Gauntlet',
            gauntletAvailable
                ? developerGauntletUnlocked(widget.account) &&
                          !gates.gauntletUnlocked
                      ? 'Debug access active. Eight modified Heats. No quiet rounds.'
                      : 'Eight modified Heats. No quiet rounds.'
                : 'Locked — clear Heat 12 to enter.',
            Icons.local_fire_department_outlined,
            locked: !gauntletAvailable,
          ),
          if (mode == RunMode.normal) ...[
            const ScreenSectionTitle('Difficulty'),
            SegmentedButton<RunDifficulty>(
              showSelectedIcon: false,
              segments: [
                for (final option in RunDifficulty.values)
                  ButtonSegment(value: option, label: Text(option.displayName)),
              ],
              selected: <RunDifficulty>{difficulty},
              onSelectionChanged: (selection) =>
                  setState(() => difficulty = selection.first),
            ),
          ],
          if (mode != RunMode.daily) ...[
            const ScreenSectionTitle('Starter Joker'),
            _starterPicker(),
          ],
          const ScreenSectionTitle("Sly's contract"),
          if (mode == RunMode.daily)
            const WildcardCard(
              accent: WildcardCardAccent.neutral,
              child: Text(
                'DAILY TABLE · NO STAKE\nEvery player gets the same Medium seed and full Joker pool.',
                textAlign: TextAlign.center,
              ),
            )
          else
            _stakePanel(),
          const SizedBox(height: 16),
          WildcardButton(
            label: 'Deal This Run',
            icon: const Icon(Icons.play_arrow_rounded),
            onPressed: widget.account.tutorialDone ? _launch : null,
            variant: WildcardButtonVariant.primary,
            minHeight: 60,
            fontSize: 16,
          ),
        ],
      ),
    );
  }

  Widget _modeCard(
    RunMode value,
    String title,
    String description,
    IconData icon, {
    bool locked = false,
  }) {
    final selected = mode == value;
    return WildcardCard(
      selected: selected,
      accent: selected ? WildcardCardAccent.gold : WildcardCardAccent.violet,
      onTap: locked
          ? null
          : () => setState(() {
              mode = value;
              if (mode == RunMode.daily) {
                stake = 0;
                startJokerId = null;
              } else {
                stake = stake.clamp(0, maxStake);
              }
              if (mode != RunMode.normal) {
                difficulty = RunDifficulty.medium;
              }
            }),
      child: Row(
        children: [
          Icon(locked ? Icons.lock_outline_rounded : icon, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: _heading(context, null)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _starterPicker() {
    final unlocked = jokerCatalog
        .where((joker) => widget.account.unlockedJokerIds.contains(joker.id))
        .toList();
    return DropdownButtonFormField<String?>(
      initialValue: startJokerId,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Optional start boost',
      ),
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem(value: null, child: Text('No starter Joker')),
        for (final joker in unlocked)
          DropdownMenuItem(
            value: joker.id,
            child: Text(
              '${joker.name} · ${starterJokerPrice(joker)} coins',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) => setState(() => startJokerId = value),
    );
  }

  Widget _stakePanel() {
    if (!gates.stakeUnlocked) {
      return const WildcardCard(
        accent: WildcardCardAccent.neutral,
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "SLY'S CONTRACT — LOCKED",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Bungee', fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    final safeMax = maxStake;
    final effectiveStake = stake.clamp(0, safeMax);
    if (effectiveStake != stake) stake = effectiveStake;
    return WildcardCard(
      accent: WildcardCardAccent.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stake == 0 ? 'NO CONTRACT' : '$stake COINS STAKED',
            style: _heading(context, context.wildcard.gold),
          ),
          const SizedBox(height: 7),
          const Text('• Clear more Heats to improve the return.'),
          const Text('• The result is skill-based; there is no random payout.'),
          if (mode == RunMode.gauntlet)
            const Text('• A Gauntlet loss can cost double the stake.'),
          if (safeMax > 0)
            Slider(
              value: stake.toDouble().clamp(0, safeMax.toDouble()),
              min: 0,
              max: safeMax.toDouble(),
              divisions: safeMax ~/ stakeStep,
              label: '$stake',
              onChanged: (value) => setState(
                () => stake = (value / stakeStep).round() * stakeStep,
              ),
            ),
        ],
      ),
    );
  }

  void _launch() {
    final joker = startJokerId == null ? null : jokersById[startJokerId];
    final cost = joker == null ? 0 : starterJokerPrice(joker);
    final launchStake = mode == RunMode.daily ? 0 : stake;
    if (launchStake + cost > widget.account.coins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough account coins.')),
      );
      return;
    }
    widget.onLaunch(
      RunLaunchRequest(
        mode: mode,
        difficulty: mode == RunMode.normal ? difficulty : RunDifficulty.medium,
        stake: launchStake,
        startJokerId: startJokerId,
      ),
    );
  }

  Future<void> _openTutorial() async {
    await widget.onOpenTutorial();
    if (mounted) setState(() {});
  }

  TextStyle _heading(BuildContext context, Color? color) => TextStyle(
    color: color ?? context.wildcard.mint,
    fontFamily: 'Bungee',
    fontSize: 13,
  );
}
