import 'package:flutter/material.dart';

import '../../domain/game_rules.dart';
import '../../domain/joker_catalog.dart';
import '../../domain/level_mode/level_definition.dart';
import '../../ui/wildcard_ui.dart';
import 'page_frame.dart';

class LevelLaunchRequest {
  const LevelLaunchRequest({
    required this.level,
    required this.selectedJokerIds,
  });

  final LevelDefinition level;
  final List<String> selectedJokerIds;
}

class LevelBriefScreen extends StatefulWidget {
  const LevelBriefScreen({
    required this.level,
    required this.onLaunch,
    this.priorAttempts = 0,
    super.key,
  });

  final LevelDefinition level;
  final ValueChanged<LevelLaunchRequest> onLaunch;

  /// Persisted attempts before this launch. Strategy help is intentionally
  /// revealed after three failures without changing the authored challenge.
  final int priorAttempts;

  @override
  State<LevelBriefScreen> createState() => _LevelBriefScreenState();
}

class _LevelBriefScreenState extends State<LevelBriefScreen> {
  final Set<String> selectedJokerIds = <String>{};

  LevelDefinition get level => widget.level;
  bool get selectionComplete => selectedJokerIds.length == level.chooseJokers;
  bool get showStrategyHelp => widget.priorAttempts >= 3;

  @override
  Widget build(BuildContext context) {
    final blocked = 52 - level.layouts.first.deckCodes.length;
    final missionItems = _missionItems(level);
    return WildcardPageFrame(
      title: 'Level ${level.id}',
      subtitle: level.chapter,
      room: WildcardRoom.runSetup,
      surface: WildcardUiSurface.modePicker,
      backgroundAsset: WildcardThemeTokens.levelCampaignBackground,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              key: ValueKey('level-brief-${level.id}'),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
              children: [
                _LevelMissionHero(level: level),
                const SizedBox(height: 14),
                const ScreenSectionTitle('Mission'),
                WildcardPanel(
                  key: const ValueKey('level-mission-stack'),
                  padding: const EdgeInsets.all(13),
                  borderColor: context.wildcard.mint,
                  child: Column(
                    children: [
                      for (var index = 0; index < missionItems.length; index++)
                        _MissionRow(
                          item: missionItems[index],
                          showDivider: index < missionItems.length - 1,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FactChip(
                      icon: Icons.style_rounded,
                      label: '${level.rules.hands} scoring hands',
                    ),
                    _FactChip(
                      icon: Icons.refresh_rounded,
                      label: '${level.rules.discards} discards',
                    ),
                    if (blocked > 0)
                      _FactChip(
                        icon: Icons.block_rounded,
                        label: '$blocked cards blocked',
                      ),
                    if (widget.priorAttempts > 0)
                      _FactChip(
                        icon: Icons.replay_rounded,
                        label:
                            '${widget.priorAttempts} prior ${widget.priorAttempts == 1 ? 'attempt' : 'attempts'}',
                      ),
                  ],
                ),
                if (level.visibleModifiers.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const ScreenSectionTitle('Table rules'),
                  for (final modifier in level.visibleModifiers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: WildcardCard(
                        accent: WildcardCardAccent.violet,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: context.wildcard.wild,
                              size: 21,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                modifier,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (level.fixedJokerIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const ScreenSectionTitle('Helpful fixed Jokers'),
                  Text(
                    'Already equipped for this table. They cost nothing and remain temporary.',
                    style: TextStyle(
                      color: context.wildcard.creamDim,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final id in level.fixedJokerIds)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _JokerChoiceCard(
                        joker: jokersById[id]!,
                        selected: true,
                        locked: true,
                        badge: 'FIXED HELP',
                      ),
                    ),
                ],
                if (level.negativeJokerId != null) ...[
                  const SizedBox(height: 10),
                  ScreenSectionTitle(
                    'Forced burden',
                    key: const ValueKey('forced-burden-heading'),
                  ),
                  Text(
                    'This Joker occupies a slot and works against the build. Plan around it.',
                    style: TextStyle(
                      color: context.wildcard.coral,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _JokerChoiceCard(
                    joker: jokersById[level.negativeJokerId]!,
                    selected: true,
                    locked: true,
                    forcedBurden: true,
                    badge: 'FORCED BURDEN',
                  ),
                ],
                if (showStrategyHelp) ...[
                  const SizedBox(height: 14),
                  const ScreenSectionTitle('Strategy help'),
                  _StrategyHint(level: level),
                ],
                if (level.requiresJokerSelection) ...[
                  const SizedBox(height: 14),
                  ScreenSectionTitle(
                    'Build your crew · ${selectedJokerIds.length}/${level.chooseJokers}',
                  ),
                  Text(
                    'Choose exactly ${level.chooseJokers}. Every option is temporary and available regardless of your collection.',
                    style: TextStyle(
                      color: context.wildcard.creamDim,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 9),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth < 350
                          ? 1
                          : constraints.maxWidth < 620
                          ? 2
                          : 3;
                      const spacing = 8.0;
                      final cardWidth =
                          (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final id in level.jokerOptionIds)
                            SizedBox(
                              width: cardWidth,
                              child: _JokerChoiceCard(
                                key: ValueKey('level-joker-option-$id'),
                                joker: jokersById[id]!,
                                selected: selectedJokerIds.contains(id),
                                badge: _jokerRole(jokersById[id]!),
                                onTap: () => _toggleJoker(id),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Level attempts use no coins, stake, Daily entry or Arcade shop. Campaign Jokers never enter permanent ownership.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.wildcard.creamDim,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          _LaunchDock(
            requiresSelection: level.requiresJokerSelection,
            selectionComplete: selectionComplete,
            remaining: level.chooseJokers - selectedJokerIds.length,
            onLaunch: _launch,
          ),
        ],
      ),
    );
  }

  void _toggleJoker(String id) {
    setState(() {
      if (!selectedJokerIds.remove(id) &&
          selectedJokerIds.length < level.chooseJokers) {
        selectedJokerIds.add(id);
      }
    });
  }

  void _launch() {
    level.validateJokerSelection(selectedJokerIds);
    widget.onLaunch(
      LevelLaunchRequest(
        level: level,
        selectedJokerIds: List<String>.unmodifiable(selectedJokerIds),
      ),
    );
  }
}

class _LevelMissionHero extends StatelessWidget {
  const _LevelMissionHero({required this.level});

  final LevelDefinition level;

  @override
  Widget build(BuildContext context) => WildcardPanel(
    padding: const EdgeInsets.all(16),
    borderColor: context.wildcard.gold,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.wildcard.gold.withValues(alpha: .14),
                border: Border.all(color: context.wildcard.gold, width: 1.6),
                boxShadow: [
                  BoxShadow(
                    color: context.wildcard.gold.withValues(alpha: .2),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Text(
                '${level.id}',
                style: TextStyle(
                  color: context.wildcard.cream,
                  fontFamily: 'Bungee',
                  fontSize: level.id >= 100 ? 14 : 17,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.chapter.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.wildcard.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                      letterSpacing: .65,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    level.name.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.wildcard.cream,
                      fontFamily: 'Bungee',
                      fontSize: 19,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          level.description,
          style: TextStyle(
            color: context.wildcard.cream,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class _MissionItem {
  const _MissionItem(this.icon, this.title, this.detail);

  final IconData icon;
  final String title;
  final String detail;
}

List<_MissionItem> _missionItems(LevelDefinition level) {
  final objective = level.objective;
  final items = <_MissionItem>[];
  if (objective.targetScore > 0) {
    items.add(
      _MissionItem(
        Icons.flag_rounded,
        'Reach the target',
        'Score at least ${objective.targetScore}.',
      ),
    );
  }
  if (objective.requiredSequence.isNotEmpty) {
    items.add(
      _MissionItem(
        Icons.route_rounded,
        'Play this exact order',
        objective.requiredSequence
            .map((type) => type.legacyName.toUpperCase())
            .join('  →  '),
      ),
    );
  }
  for (final entry in objective.requiredCounts.entries) {
    items.add(
      _MissionItem(
        Icons.checklist_rounded,
        'Score ${entry.key.legacyName}',
        '${entry.value} ${entry.value == 1 ? 'time' : 'times'} before the table ends.',
      ),
    );
  }
  if (objective.minVariety > 0) {
    items.add(
      _MissionItem(
        Icons.category_rounded,
        'Show variety',
        'Score ${objective.minVariety} different hand types.',
      ),
    );
  }
  if (objective.forbiddenTypes.isNotEmpty) {
    items.add(
      _MissionItem(
        Icons.do_not_disturb_alt_rounded,
        'Forbidden hands',
        'Do not score ${_handTypeList(objective.forbiddenTypes)}.',
      ),
    );
  }
  if (objective.minQualityCount > 0) {
    items.add(
      _MissionItem(
        Icons.workspace_premium_rounded,
        'Quality check',
        'Score ${objective.minQualityCount} ${objective.minQualityCount == 1 ? 'hand' : 'hands'} at ${objective.minQuality.legacyName} or better.',
      ),
    );
  }
  if (objective.minTypesFromCount > 0) {
    items.add(
      _MissionItem(
        Icons.filter_alt_rounded,
        'Choose from the premium pool',
        'Score ${objective.minTypesFromCount} types from ${_handTypeList(objective.minTypesFrom)}.',
      ),
    );
  }
  if (objective.checkpoints.isNotEmpty) {
    items.add(
      _MissionItem(
        Icons.stairs_rounded,
        'Clear every checkpoint',
        objective.checkpoints.join('  →  '),
      ),
    );
  }
  if (items.isEmpty) {
    items.add(
      const _MissionItem(
        Icons.flag_rounded,
        'Complete the table',
        'Use the authored deck and rules to finish the challenge.',
      ),
    );
  }
  return items;
}

String _handTypeList(Iterable<HandType> types) =>
    types.map((type) => type.legacyName).join(', ');

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.item, required this.showDivider});

  final _MissionItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.wildcard.mint.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: context.wildcard.mint.withValues(alpha: .7),
                ),
              ),
              child: Icon(item.icon, color: context.wildcard.mint, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.toUpperCase(),
                    style: TextStyle(
                      color: context.wildcard.cream,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      letterSpacing: .25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.detail,
                    style: TextStyle(
                      color: context.wildcard.creamDim,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (showDivider)
        Divider(height: 1, color: context.wildcard.line.withValues(alpha: .5)),
    ],
  );
}

class _StrategyHint extends StatelessWidget {
  const _StrategyHint({required this.level});

  final LevelDefinition level;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      WildcardCard(
        key: const ValueKey('level-authored-hint'),
        accent: WildcardCardAccent.gold,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lightbulb_rounded,
              color: context.wildcard.gold,
              size: 23,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AUTHORED HINT',
                    style: TextStyle(
                      color: context.wildcard.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: .6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level.hint,
                    style: const TextStyle(fontSize: 12.5, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (level.recommendedLoadouts.isNotEmpty) ...[
        const SizedBox(height: 9),
        WildcardCard(
          key: const ValueKey('level-recommended-loadouts'),
          accent: WildcardCardAccent.mint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RECOMMENDED LOADOUTS',
                style: TextStyle(
                  color: context.wildcard.mint,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: .55,
                ),
              ),
              const SizedBox(height: 7),
              for (
                var index = 0;
                index < level.recommendedLoadouts.length;
                index++
              )
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == level.recommendedLoadouts.length - 1
                        ? 0
                        : 7,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}.',
                        style: TextStyle(
                          color: context.wildcard.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          level.recommendedLoadouts[index].jokerNames.join(
                            ' + ',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${level.recommendedLoadouts[index].layoutCount} decks',
                        style: TextStyle(
                          color: context.wildcard.creamDim,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ],
  );
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: context.wildcard.panelStrong.withValues(alpha: .8),
      border: Border.all(color: context.wildcard.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.wildcard.mint),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _JokerChoiceCard extends StatelessWidget {
  const _JokerChoiceCard({
    required this.joker,
    required this.selected,
    required this.badge,
    this.locked = false,
    this.forcedBurden = false,
    this.onTap,
    super.key,
  });

  final JokerDefinition joker;
  final bool selected;
  final bool locked;
  final bool forcedBurden;
  final String badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = forcedBurden
        ? WildcardCardAccent.danger
        : switch (joker.rarity) {
            JokerRarity.common => WildcardCardAccent.gold,
            JokerRarity.uncommon => WildcardCardAccent.mint,
            JokerRarity.rare => WildcardCardAccent.rare,
            JokerRarity.wild => WildcardCardAccent.violet,
          };
    final color = forcedBurden
        ? context.wildcard.coral
        : switch (joker.rarity) {
            JokerRarity.common => context.wildcard.gold,
            JokerRarity.uncommon => context.wildcard.mint,
            JokerRarity.rare => context.wildcard.rare,
            JokerRarity.wild => context.wildcard.wild,
          };
    return Semantics(
      button: !locked,
      selected: selected,
      label:
          '${joker.name}, $badge, ${joker.rarity.name}, ${joker.description}',
      child: WildcardCard(
        accent: accent,
        selected: selected && !forcedBurden,
        onTap: locked ? null : onTap,
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    joker.name.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontFamily: 'Bungee',
                      fontSize: 12,
                      height: 1.18,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Icon(
                  forcedBurden
                      ? Icons.warning_rounded
                      : locked
                      ? Icons.push_pin_rounded
                      : selected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: color,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _JokerBadge(label: badge, color: color),
                _JokerBadge(
                  label: joker.rarity.name.toUpperCase(),
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              joker.description,
              style: TextStyle(
                color: context.wildcard.cream,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JokerBadge extends StatelessWidget {
  const _JokerBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: .7)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: .35,
      ),
    ),
  );
}

String _jokerRole(JokerDefinition joker) {
  final description = joker.description.toLowerCase();
  if (description.contains('coin')) return 'ECONOMY';
  if (description.contains('modifier') || description.contains('heat')) {
    return 'ADAPTER';
  }
  if (description.contains('copy') ||
      description.contains('destroy') ||
      description.contains('deck') ||
      description.contains('discard')) {
    return 'DECK CONTROL';
  }
  if (description.contains('mult') || description.contains('×')) {
    return 'MULTIPLIER';
  }
  if (description.contains('rank') || description.contains('value')) {
    return 'VALUE';
  }
  return 'UTILITY';
}

class _LaunchDock extends StatelessWidget {
  const _LaunchDock({
    required this.requiresSelection,
    required this.selectionComplete,
    required this.remaining,
    required this.onLaunch,
  });

  final bool requiresSelection;
  final bool selectionComplete;
  final int remaining;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final ready = !requiresSelection || selectionComplete;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 14),
      decoration: BoxDecoration(
        color: context.wildcard.ink.withValues(alpha: .96),
        border: Border(
          top: BorderSide(color: context.wildcard.line.withValues(alpha: .8)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xA8000000),
            blurRadius: 18,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: WildcardButton(
        key: const ValueKey('start-level-button'),
        label: ready
            ? 'Start Level'
            : 'Choose $remaining ${remaining == 1 ? 'Joker' : 'Jokers'}',
        icon: Icon(ready ? Icons.play_arrow_rounded : Icons.style_rounded),
        onPressed: ready ? onLaunch : null,
        variant: WildcardButtonVariant.primary,
        minHeight: 60,
        attention: ready,
      ),
    );
  }
}
