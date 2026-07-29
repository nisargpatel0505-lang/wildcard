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
import '../../ui/widgets/wildcard_toast.dart';

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
      room: WildcardRoom.runSetup,
      surface: WildcardUiSurface.modePicker,
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

  static Color _rarityColor(WildcardThemeTokens tokens, JokerRarity rarity) =>
      switch (rarity) {
        JokerRarity.common => tokens.gold,
        JokerRarity.uncommon => tokens.mint,
        JokerRarity.rare => tokens.rare,
        JokerRarity.wild => tokens.wild,
      };

  /// The old picker was a bare dropdown of "name · cost", which gave the player
  /// no basis for choosing. Each option now carries its rarity colour and what
  /// the Joker actually does, and the current pick is previewed underneath.
  Widget _starterPicker() {
    final tokens = context.wildcard;
    final unlocked =
        selectableJokers
            .where(
              (joker) =>
                  widget.account.unlockedJokerIds.contains(joker.id) ||
                  (devJokerAvailable && joker.effect == JokerEffect.devTwentyX),
            )
            .toList()
          ..sort((a, b) {
            final byRarity = a.rarity.index.compareTo(b.rarity.index);
            return byRarity != 0 ? byRarity : a.name.compareTo(b.name);
          });
    final selected = startJokerId == null ? null : jokersById[startJokerId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: startJokerId,
          isExpanded: true,
          selectedItemBuilder: (context) => <Widget>[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No starter Joker'),
            ),
            for (final joker in unlocked)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${joker.name} · ${starterJokerPrice(joker)} coins',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Optional start boost',
          ),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem(
              value: null,
              child: Text('No starter Joker'),
            ),
            for (final joker in unlocked)
              DropdownMenuItem(
                value: joker.id,
                child: _JokerOption(
                  joker: joker,
                  accent: _rarityColor(tokens, joker.rarity),
                ),
              ),
          ],
          onChanged: (value) => setState(() => startJokerId = value),
        ),
        if (selected != null) ...[
          const SizedBox(height: 8),
          _JokerPreview(
            joker: selected,
            accent: _rarityColor(tokens, selected.rarity),
          ),
        ],
      ],
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
          Row(
            children: [
              Expanded(
                child: Text(
                  stake == 0 ? 'NO CONTRACT' : '$stake COINS STAKED',
                  style: _heading(context, context.wildcard.gold),
                ),
              ),
              // A tappable payout key: what the contract returns at each Heat,
              // for Easy / Medium / Hard.
              Semantics(
                button: true,
                label: 'View contract payout by difficulty',
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _showPayoutInfo,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 17,
                          color: context.wildcard.gold,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: context.wildcard.creamDim,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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

  /// Shows what Sly's Contract pays out at each Heat for every difficulty.
  void _showPayoutInfo() {
    final tokens = context.wildcard;
    final gauntlet = mode == RunMode.gauntlet;
    // Show the return for the chosen stake, defaulting to a clean 100 so the
    // table reads even before the player commits coins.
    final refStake = stake > 0 ? stake : 100;
    final maxHeat = gauntlet ? gauntletHeats : 12;
    // A readable milestone set rather than every Heat.
    final heats = gauntlet ? const [2, 4, 6, 8] : const [3, 6, 9, 12];

    int payoutFor(int heat, RunDifficulty difficulty) => gauntlet
        ? gauntletStakePayout(refStake, heat)
        : stakePayout(refStake, heat, difficulty: difficulty);

    Widget cell(String text, {Color? color, bool head = false}) => Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color ?? tokens.cream,
          fontFamily: head ? 'Bungee' : 'SpaceGrotesk',
          fontWeight: head ? null : FontWeight.w700,
          fontSize: head ? 10 : 13,
        ),
      ),
    );

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.panelStrong,
        title: Row(
          children: [
            Icon(Icons.payments_outlined, color: tokens.gold, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'CONTRACT PAYOUT',
                style: TextStyle(fontFamily: 'Bungee', fontSize: 15),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Coins returned for $refStake staked, by Heats cleared'
              '${stake > 0 ? '' : ' (per 100)'}.',
              style: TextStyle(color: tokens.creamDim, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (gauntlet)
              Row(
                children: [
                  cell('HEAT', head: true),
                  cell('PAYOUT', color: tokens.gold, head: true),
                ],
              )
            else
              Row(
                children: [
                  cell('HEAT', head: true),
                  cell('EASY', color: tokens.mint, head: true),
                  cell('MED', color: tokens.cream, head: true),
                  cell('HARD', color: tokens.coral, head: true),
                ],
              ),
            const Divider(height: 14),
            for (final heat in heats)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: gauntlet
                    ? Row(
                        children: [
                          cell('$heat'),
                          cell(
                            '+${payoutFor(heat, RunDifficulty.medium)}',
                            color: tokens.gold,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          cell('$heat'),
                          cell(
                            '+${payoutFor(heat, RunDifficulty.easy)}',
                            color: tokens.mint,
                          ),
                          cell('+${payoutFor(heat, RunDifficulty.medium)}'),
                          cell(
                            '+${payoutFor(heat, RunDifficulty.hard)}',
                            color: tokens.coral,
                          ),
                        ],
                      ),
              ),
            const SizedBox(height: 4),
            Text(
              gauntlet
                  ? 'Clear all $maxHeat Heats for the full pot. A loss can cost double.'
                  : 'Hard pays the most, Easy the least. Full run ($maxHeat) pays the most.',
              style: TextStyle(
                color: tokens.creamDim,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GOT IT'),
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
      showWildcardToast(context, 'Not enough account coins.');
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

/// A dropdown row for one Joker: rarity colour, name, cost and what it does.
class _JokerOption extends StatelessWidget {
  const _JokerOption({required this.joker, required this.accent});

  final JokerDefinition joker;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Rarity swatch — the fastest signal of how strong a pick is.
        Container(
          width: 5,
          height: 34,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${joker.name} · ${starterJokerPrice(joker)} coins',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  height: 1.1,
                ),
              ),
              Text(
                joker.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.creamDim,
                  fontSize: 10.5,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Preview of the chosen Joker, so the effect stays readable after the
/// dropdown closes.
class _JokerPreview extends StatelessWidget {
  const _JokerPreview({required this.joker, required this.accent});

  final JokerDefinition joker;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.16),
            tokens.panelStrong.withValues(alpha: 0.65),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  joker.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontFamily: 'Bungee',
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                joker.rarity.name.toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            joker.description,
            style: TextStyle(color: tokens.cream, fontSize: 11.5, height: 1.25),
          ),
        ],
      ),
    );
  }
}
