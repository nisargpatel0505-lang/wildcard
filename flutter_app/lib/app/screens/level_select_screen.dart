import 'package:flutter/material.dart';

import '../../domain/account_state.dart';
import '../../domain/level_mode/level_catalog.dart';
import '../../domain/level_mode/level_definition.dart';
import '../../ui/wildcard_ui.dart';
import 'page_frame.dart';

class LevelSelectScreen extends StatefulWidget {
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
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  late int selectedChapterIndex;
  late final ScrollController chapterScrollController;

  List<List<LevelDefinition>> get chapters {
    final result = <List<LevelDefinition>>[];
    for (final level in widget.catalog.levels) {
      if (result.isEmpty || result.last.first.chapter != level.chapter) {
        result.add(<LevelDefinition>[level]);
      } else {
        result.last.add(level);
      }
    }
    return result;
  }

  int get frontierId => widget.account.highestUnlockedLevel.clamp(
    AccountState.firstLevelId,
    widget.catalog.levels.length,
  );

  LevelDefinition get frontier => widget.catalog.level(frontierId);

  @override
  void initState() {
    super.initState();
    selectedChapterIndex = _chapterIndexFor(frontierId);
    chapterScrollController = ScrollController(
      initialScrollOffset: selectedChapterIndex == 0
          ? 0
          : (selectedChapterIndex * 130.0) - 12,
    );
  }

  @override
  void dispose() {
    chapterScrollController.dispose();
    super.dispose();
  }

  int _chapterIndexFor(int levelId) {
    final allChapters = chapters;
    final found = allChapters.indexWhere(
      (chapter) => chapter.any((level) => level.id == levelId),
    );
    return found < 0 ? 0 : found;
  }

  bool _isUnlocked(LevelDefinition level) =>
      widget.account.clearedLevelIds.contains(level.id) ||
      level.id <= frontierId;

  @override
  Widget build(BuildContext context) {
    final allChapters = chapters;
    if (selectedChapterIndex >= allChapters.length) {
      selectedChapterIndex = allChapters.length - 1;
    }
    final selectedChapter = allChapters[selectedChapterIndex];
    final cleared = widget.account.clearedLevelIds
        .where((id) => id >= 1 && id <= widget.catalog.levels.length)
        .length;
    final overallProgress = cleared / widget.catalog.levels.length;

    return WildcardPageFrame(
      title: 'Levels',
      subtitle: 'A 100-table campaign built for poker mastery.',
      room: WildcardRoom.runSetup,
      surface: WildcardUiSurface.modePicker,
      backgroundAsset: WildcardThemeTokens.levelCampaignBackground,
      child: ListView(
        key: const ValueKey('level-select-list'),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
        children: [
          _CampaignHero(
            cleared: cleared,
            total: widget.catalog.levels.length,
            progress: overallProgress,
            frontier: frontier,
            frontierCleared: widget.account.clearedLevelIds.contains(
              frontier.id,
            ),
            bestScore: widget.account.levelBestScores[frontier.id] ?? 0,
            attempts: widget.account.levelAttempts[frontier.id] ?? 0,
            onContinue: () => widget.onOpenLevel(frontier),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: ScreenSectionTitle('Choose a chapter')),
              Text(
                '${selectedChapterIndex + 1} / ${allChapters.length}',
                style: TextStyle(
                  color: context.wildcard.creamDim,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 94,
            child: ListView.separated(
              key: const ValueKey('level-chapter-selector'),
              controller: chapterScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: allChapters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final chapter = allChapters[index];
                final chapterCleared = chapter
                    .where(
                      (level) =>
                          widget.account.clearedLevelIds.contains(level.id),
                    )
                    .length;
                final containsFrontier = chapter.any(
                  (level) => level.id == frontier.id,
                );
                return _ChapterCard(
                  key: ValueKey('level-chapter-${index + 1}'),
                  number: index + 1,
                  name: chapter.first.chapter,
                  cleared: chapterCleared,
                  total: chapter.length,
                  selected: index == selectedChapterIndex,
                  current: containsFrontier,
                  locked: chapter.every((level) => !_isUnlocked(level)),
                  onTap: () => setState(() => selectedChapterIndex = index),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          _ChapterPathPanel(
            chapterNumber: selectedChapterIndex + 1,
            chapterName: selectedChapter.first.chapter,
            levels: selectedChapter,
            account: widget.account,
            frontierId: frontierId,
            isUnlocked: _isUnlocked,
            onOpenLevel: widget.onOpenLevel,
          ),
          const SizedBox(height: 14),
          Text(
            'Cleared tables stay replayable. A failed attempt costs no coins, energy or Daily entry.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.wildcard.creamDim,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignHero extends StatelessWidget {
  const _CampaignHero({
    required this.cleared,
    required this.total,
    required this.progress,
    required this.frontier,
    required this.frontierCleared,
    required this.bestScore,
    required this.attempts,
    required this.onContinue,
  });

  final int cleared;
  final int total;
  final double progress;
  final LevelDefinition frontier;
  final bool frontierCleared;
  final int bestScore;
  final int attempts;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => WildcardPanel(
    key: const ValueKey('campaign-progress-hero'),
    padding: const EdgeInsets.all(16),
    borderColor: frontierCleared
        ? context.wildcard.mint
        : context.wildcard.gold,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    frontierCleared ? 'CAMPAIGN COMPLETE' : 'YOUR FRONTIER',
                    style: TextStyle(
                      color: frontierCleared
                          ? context.wildcard.mint
                          : context.wildcard.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$cleared OF $total CLEARED',
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
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                color: context.wildcard.mint,
                fontFamily: 'Bungee',
                fontSize: 25,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            key: const ValueKey('campaign-progress-bar'),
            value: progress.clamp(0, 1),
            minHeight: 9,
            color: context.wildcard.mint,
            backgroundColor: context.wildcard.line.withValues(alpha: .42),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          'LEVEL ${frontier.id} · ${frontier.name.toUpperCase()}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.wildcard.gold,
            fontFamily: 'Bungee',
            fontSize: 14,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          frontier.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.wildcard.creamDim,
            fontSize: 12,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ProgressStat(
                label: 'BEST SCORE',
                value: bestScore > 0 ? '$bestScore' : '—',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ProgressStat(label: 'ATTEMPTS', value: '$attempts'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        WildcardButton(
          key: const ValueKey('continue-frontier-button'),
          label: frontierCleared
              ? 'Replay Final Level'
              : 'Continue · Level ${frontier.id}',
          icon: Icon(
            frontierCleared ? Icons.replay_rounded : Icons.play_arrow_rounded,
          ),
          onPressed: onContinue,
          variant: WildcardButtonVariant.primary,
          minHeight: 56,
          attention: !frontierCleared,
        ),
      ],
    ),
  );
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: context.wildcard.panelStrong.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: context.wildcard.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.wildcard.creamDim,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: .45,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: context.wildcard.cream,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.number,
    required this.name,
    required this.cleared,
    required this.total,
    required this.selected,
    required this.current,
    required this.locked,
    required this.onTap,
    super.key,
  });

  final int number;
  final String name;
  final int cleared;
  final int total;
  final bool selected;
  final bool current;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 122,
    child: Semantics(
      button: true,
      selected: selected,
      label:
          'Chapter $number, $name, $cleared of $total cleared${locked ? ', locked' : ''}',
      child: WildcardCard(
        selected: selected,
        accent: cleared == total
            ? WildcardCardAccent.mint
            : current
            ? WildcardCardAccent.gold
            : WildcardCardAccent.violet,
        onTap: onTap,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CHAPTER $number',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: current
                          ? context.wildcard.gold
                          : context.wildcard.creamDim,
                      fontWeight: FontWeight.w800,
                      fontSize: 9.5,
                      letterSpacing: .2,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  cleared == total
                      ? Icons.check_circle_rounded
                      : locked
                      ? Icons.lock_rounded
                      : Icons.circle_outlined,
                  size: 15,
                  color: cleared == total
                      ? context.wildcard.mint
                      : current
                      ? context.wildcard.gold
                      : context.wildcard.creamDim,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: locked
                    ? context.wildcard.creamDim
                    : context.wildcard.cream,
                fontFamily: 'Bungee',
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Text(
              '$cleared / $total',
              style: TextStyle(
                color: cleared == total
                    ? context.wildcard.mint
                    : context.wildcard.gold,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ChapterPathPanel extends StatelessWidget {
  const _ChapterPathPanel({
    required this.chapterNumber,
    required this.chapterName,
    required this.levels,
    required this.account,
    required this.frontierId,
    required this.isUnlocked,
    required this.onOpenLevel,
  });

  final int chapterNumber;
  final String chapterName;
  final List<LevelDefinition> levels;
  final AccountState account;
  final int frontierId;
  final bool Function(LevelDefinition level) isUnlocked;
  final ValueChanged<LevelDefinition> onOpenLevel;

  @override
  Widget build(BuildContext context) {
    final cleared = levels
        .where((level) => account.clearedLevelIds.contains(level.id))
        .length;
    final firstRow = levels.take(5).toList(growable: false);
    final secondRow = levels
        .skip(5)
        .take(5)
        .toList()
        .reversed
        .toList(growable: false);
    final chapterUnlocked = levels.any(isUnlocked);

    return WildcardPanel(
      key: ValueKey('level-chapter-path-$chapterNumber'),
      padding: const EdgeInsets.all(14),
      borderColor: chapterUnlocked
          ? context.wildcard.violet
          : context.wildcard.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHAPTER $chapterNumber',
                      style: TextStyle(
                        color: context.wildcard.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                        letterSpacing: .65,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      chapterName.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.wildcard.cream,
                        fontFamily: 'Bungee',
                        fontSize: 16,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: context.wildcard.panelStrong,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: context.wildcard.line),
                ),
                child: Text(
                  '$cleared / ${levels.length}',
                  style: TextStyle(
                    color: cleared == levels.length
                        ? context.wildcard.mint
                        : context.wildcard.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PathRow(
            levels: firstRow,
            account: account,
            frontierId: frontierId,
            isUnlocked: isUnlocked,
            onOpenLevel: onOpenLevel,
          ),
          if (secondRow.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 21),
                child: Container(
                  width: 2,
                  height: 12,
                  color: context.wildcard.line,
                ),
              ),
            ),
            _PathRow(
              levels: secondRow,
              account: account,
              frontierId: frontierId,
              isUnlocked: isUnlocked,
              onOpenLevel: onOpenLevel,
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: const [
              _PathLegend(colorKind: _LegendColor.mint, label: 'Cleared'),
              _PathLegend(colorKind: _LegendColor.gold, label: 'Frontier'),
              _PathLegend(colorKind: _LegendColor.dim, label: 'Locked'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.levels,
    required this.account,
    required this.frontierId,
    required this.isUnlocked,
    required this.onOpenLevel,
  });

  final List<LevelDefinition> levels;
  final AccountState account;
  final int frontierId;
  final bool Function(LevelDefinition level) isUnlocked;
  final ValueChanged<LevelDefinition> onOpenLevel;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var index = 0; index < levels.length; index++) {
      final level = levels[index];
      if (index > 0) {
        final previous = levels[index - 1];
        final active =
            account.clearedLevelIds.contains(previous.id) && isUnlocked(level);
        children.add(
          Expanded(
            child: Container(
              height: 2,
              color: active
                  ? context.wildcard.mint.withValues(alpha: .7)
                  : context.wildcard.line.withValues(alpha: .68),
            ),
          ),
        );
      }
      children.add(
        _LevelNode(
          level: level,
          cleared: account.clearedLevelIds.contains(level.id),
          unlocked: isUnlocked(level),
          frontier:
              level.id == frontierId &&
              !account.clearedLevelIds.contains(level.id),
          bestScore: account.levelBestScores[level.id] ?? 0,
          attempts: account.levelAttempts[level.id] ?? 0,
          onTap: () => onOpenLevel(level),
        ),
      );
    }
    return Row(children: children);
  }
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.level,
    required this.cleared,
    required this.unlocked,
    required this.frontier,
    required this.bestScore,
    required this.attempts,
    required this.onTap,
  });

  final LevelDefinition level;
  final bool cleared;
  final bool unlocked;
  final bool frontier;
  final int bestScore;
  final int attempts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = cleared
        ? context.wildcard.mint
        : frontier
        ? context.wildcard.gold
        : unlocked
        ? context.wildcard.violet
        : context.wildcard.line;
    final status = cleared
        ? 'cleared'
        : frontier
        ? 'current frontier'
        : unlocked
        ? 'unlocked'
        : 'locked';
    final stats = <String>[
      if (bestScore > 0) 'best score $bestScore',
      if (attempts > 0) '$attempts attempts',
    ].join(', ');
    return Semantics(
      button: true,
      enabled: unlocked,
      label:
          'Level ${level.id}, ${level.name}, $status${stats.isEmpty ? '' : ', $stats'}',
      child: SizedBox.square(
        key: ValueKey('level-${level.id}'),
        dimension: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.alphaBlend(
              color.withValues(alpha: unlocked ? .15 : .06),
              context.wildcard.panelStrong,
            ),
            border: Border.all(color: color, width: frontier ? 2.4 : 1.5),
            boxShadow: frontier
                ? [
                    BoxShadow(
                      color: context.wildcard.gold.withValues(alpha: .45),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: unlocked ? onTap : null,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '${level.id}',
                    style: TextStyle(
                      color: unlocked
                          ? context.wildcard.cream
                          : context.wildcard.creamDim,
                      fontFamily: 'Bungee',
                      fontSize: level.id >= 100 ? 9.5 : 11,
                    ),
                  ),
                  if (cleared)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: context.wildcard.mint,
                        size: 14,
                      ),
                    )
                  else if (!unlocked)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Icon(
                        Icons.lock_rounded,
                        color: context.wildcard.creamDim,
                        size: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _LegendColor { mint, gold, dim }

class _PathLegend extends StatelessWidget {
  const _PathLegend({required this.colorKind, required this.label});

  final _LegendColor colorKind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (colorKind) {
      _LegendColor.mint => context.wildcard.mint,
      _LegendColor.gold => context.wildcard.gold,
      _LegendColor.dim => context.wildcard.line,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: context.wildcard.creamDim,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
