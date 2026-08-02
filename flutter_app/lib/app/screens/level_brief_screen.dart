import 'package:flutter/material.dart';

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
    super.key,
  });

  final LevelDefinition level;
  final ValueChanged<LevelLaunchRequest> onLaunch;

  @override
  State<LevelBriefScreen> createState() => _LevelBriefScreenState();
}

class _LevelBriefScreenState extends State<LevelBriefScreen> {
  final Set<String> selectedJokerIds = <String>{};

  LevelDefinition get level => widget.level;
  bool get selectionComplete => selectedJokerIds.length == level.chooseJokers;

  @override
  Widget build(BuildContext context) {
    final blocked = 52 - level.layouts.first.deckCodes.length;
    return WildcardPageFrame(
      title: 'Level ${level.id}',
      subtitle: level.chapter,
      room: WildcardRoom.runSetup,
      surface: WildcardUiSurface.modePicker,
      child: ListView(
        key: ValueKey('level-brief-${level.id}'),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
        children: [
          WildcardPanel(
            borderColor: context.wildcard.gold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level.name.toUpperCase(),
                  style: TextStyle(
                    color: context.wildcard.gold,
                    fontFamily: 'Bungee',
                    fontSize: 21,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  level.description,
                  style: const TextStyle(fontSize: 14, height: 1.35),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (level.objective.targetScore > 0)
                      _FactChip(
                        icon: Icons.flag_rounded,
                        label: 'Target ${level.objective.targetScore}',
                      ),
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
                  ],
                ),
              ],
            ),
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
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          modifier,
                          style: const TextStyle(fontSize: 12.5, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (level.fixedJokerIds.isNotEmpty ||
              level.negativeJokerId != null) ...[
            const SizedBox(height: 10),
            const ScreenSectionTitle('Fixed Jokers'),
            for (final id in <String>[
              ...level.fixedJokerIds,
              if (level.negativeJokerId != null) level.negativeJokerId!,
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _JokerChoiceCard(
                  joker: jokersById[id]!,
                  selected: true,
                  locked: true,
                ),
              ),
          ],
          if (level.requiresJokerSelection) ...[
            const SizedBox(height: 10),
            ScreenSectionTitle(
              'Choose exactly ${level.chooseJokers} Jokers '
              '(${selectedJokerIds.length}/${level.chooseJokers})',
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.18,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: level.jokerOptionIds.length,
              itemBuilder: (context, index) {
                final joker = jokersById[level.jokerOptionIds[index]]!;
                final selected = selectedJokerIds.contains(joker.id);
                return _JokerChoiceCard(
                  joker: joker,
                  selected: selected,
                  onTap: () => _toggleJoker(joker.id),
                );
              },
            ),
          ],
          const SizedBox(height: 20),
          WildcardButton(
            key: const ValueKey('start-level-button'),
            label: level.requiresJokerSelection
                ? selectionComplete
                      ? 'Start Level'
                      : 'Choose ${level.chooseJokers - selectedJokerIds.length} More'
                : 'Start Level',
            icon: const Icon(Icons.play_arrow_rounded),
            onPressed: level.requiresJokerSelection && !selectionComplete
                ? null
                : _launch,
            variant: WildcardButtonVariant.primary,
            minHeight: 60,
          ),
          const SizedBox(height: 10),
          Text(
            'Campaign Jokers are temporary. This table uses no coins, stake, Daily attempt or Arcade shop.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.wildcard.creamDim,
              fontSize: 11.5,
              height: 1.3,
            ),
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

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
    this.locked = false,
    this.onTap,
  });

  final JokerDefinition joker;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (joker.rarity) {
      JokerRarity.common => WildcardCardAccent.gold,
      JokerRarity.uncommon => WildcardCardAccent.mint,
      JokerRarity.rare => WildcardCardAccent.rare,
      JokerRarity.wild => WildcardCardAccent.violet,
    };
    final color = switch (joker.rarity) {
      JokerRarity.common => context.wildcard.gold,
      JokerRarity.uncommon => context.wildcard.mint,
      JokerRarity.rare => context.wildcard.rare,
      JokerRarity.wild => context.wildcard.wild,
    };
    return WildcardCard(
      accent: accent,
      selected: selected,
      onTap: locked ? null : onTap,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  joker.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              Icon(
                locked
                    ? Icons.push_pin_rounded
                    : selected
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: color,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            joker.description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.wildcard.cream,
              fontSize: 10.5,
              height: 1.2,
            ),
          ),
          Text(
            joker.rarity.name.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}
