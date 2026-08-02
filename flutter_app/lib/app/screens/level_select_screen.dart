import 'package:flutter/material.dart';

import '../../domain/account_state.dart';
import '../../domain/level_mode/level_catalog.dart';
import '../../domain/level_mode/level_definition.dart';
import '../../ui/wildcard_ui.dart';
import 'page_frame.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({
    required this.catalog,
    required this.account,
    required this.onOpenLevel,
    super.key,
  });

  final LevelCatalog catalog;
  final AccountState account;
  final ValueChanged<LevelDefinition> onOpenLevel;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    String? chapter;
    for (final level in catalog.levels) {
      if (chapter != level.chapter) {
        chapter = level.chapter;
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 4 : 18, bottom: 8),
            child: Text(
              chapter.toUpperCase(),
              style: TextStyle(
                color: context.wildcard.gold,
                fontFamily: 'Bungee',
                fontSize: 13,
                letterSpacing: .45,
              ),
            ),
          ),
        );
      }
      children.add(_levelTile(context, level));
      children.add(const SizedBox(height: 8));
    }

    return WildcardPageFrame(
      title: 'Levels',
      subtitle:
          '${account.clearedLevelIds.length} cleared · frontier ${account.highestUnlockedLevel}/100',
      room: WildcardRoom.runSetup,
      surface: WildcardUiSurface.modePicker,
      child: ListView(
        key: const ValueKey('level-select-list'),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
        children: children,
      ),
    );
  }

  Widget _levelTile(BuildContext context, LevelDefinition level) {
    final cleared = account.clearedLevelIds.contains(level.id);
    final unlocked = cleared || level.id <= account.highestUnlockedLevel;
    final frontier =
        unlocked && !cleared && level.id == account.highestUnlockedLevel;
    final best = account.levelBestScores[level.id] ?? 0;
    final attempts = account.levelAttempts[level.id] ?? 0;
    return WildcardCard(
      key: ValueKey('level-${level.id}'),
      accent: cleared
          ? WildcardCardAccent.mint
          : frontier
          ? WildcardCardAccent.gold
          : WildcardCardAccent.neutral,
      onTap: unlocked ? () => onOpenLevel(level) : null,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  (cleared
                          ? context.wildcard.mint
                          : frontier
                          ? context.wildcard.gold
                          : context.wildcard.line)
                      .withValues(alpha: .13),
              border: Border.all(
                color: cleared
                    ? context.wildcard.mint
                    : frontier
                    ? context.wildcard.gold
                    : context.wildcard.line,
              ),
            ),
            child: unlocked
                ? Text(
                    '${level.id}',
                    style: TextStyle(
                      color: cleared
                          ? context.wildcard.mint
                          : context.wildcard.cream,
                      fontFamily: 'Bungee',
                      fontSize: 14,
                    ),
                  )
                : Icon(
                    Icons.lock_rounded,
                    color: context.wildcard.creamDim,
                    size: 21,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unlocked ? level.name.toUpperCase() : 'LOCKED',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unlocked
                        ? context.wildcard.cream
                        : context.wildcard.creamDim,
                    fontFamily: 'Bungee',
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  unlocked
                      ? level.description
                      : 'Clear Level ${level.id - 1} to unlock.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.wildcard.creamDim,
                    fontSize: 11.5,
                    height: 1.2,
                  ),
                ),
                if (unlocked && (best > 0 || attempts > 0)) ...[
                  const SizedBox(height: 5),
                  Text(
                    'BEST $best · $attempts ${attempts == 1 ? 'ATTEMPT' : 'ATTEMPTS'}',
                    style: TextStyle(
                      color: context.wildcard.gold,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            cleared
                ? Icons.check_circle_rounded
                : unlocked
                ? Icons.chevron_right_rounded
                : Icons.lock_outline_rounded,
            color: cleared
                ? context.wildcard.mint
                : unlocked
                ? context.wildcard.gold
                : context.wildcard.creamDim,
          ),
        ],
      ),
    );
  }
}
