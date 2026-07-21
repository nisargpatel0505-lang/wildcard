import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_controller.dart';
import '../../domain/account_state.dart';
import '../../domain/joker_catalog.dart';
import '../../domain/progression_catalog.dart';
import '../../ui/wildcard_ui.dart';
import 'page_frame.dart';

class CabinetScreen extends StatefulWidget {
  const CabinetScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<CabinetScreen> createState() => _CabinetScreenState();
}

class _CabinetScreenState extends State<CabinetScreen> {
  static final NumberFormat _number = NumberFormat.decimalPattern('en_GB');
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final account = widget.controller.account;
        final snapshot = widget.controller.progressionSnapshot;
        final summary = CabinetSummary.fromAccount(account, snapshot);
        return WildcardPageFrame(
          title: 'Cabinet',
          subtitle: 'Lifetime stats, badges, achievements and titles',
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
            children: [
              _personalBest(account.bestHeat),
              const SizedBox(height: 10),
              _StatsGrid(
                entries: [
                  _StatValue('Best run score', _format(account.bestScore)),
                  _StatValue('Account coins', _format(account.coins)),
                  _StatValue(
                    'Achievements',
                    '${summary.achievementsEarned} / ${achievementCatalog.length}',
                  ),
                  _StatValue('Runs played', _format(account.stats.runs)),
                  _StatValue('Wins', _format(account.stats.wins)),
                  _StatValue(
                    'Total collection',
                    '${summary.collectionPercent}%',
                  ),
                ],
              ),
              const ScreenSectionTitle('Performance'),
              _StatsGrid(
                entries: [
                  _StatValue('Best Heat cleared', account.bestClearedHeat),
                  _StatValue('Win rate', summary.winRate),
                  _StatValue('Average hands / run', summary.averageHands),
                  _StatValue(
                    'Recent average score',
                    summary.recentAverageScore,
                  ),
                  _StatValue('Recent average Heat', summary.recentAverageHeat),
                  _StatValue('Daily best', _format(account.dailyBest.score)),
                ],
              ),
              const ScreenSectionTitle('Collection'),
              _StatsGrid(
                entries: [
                  _StatValue(
                    'Jokers',
                    '${publicUnlockedJokerCount(account.unlockedJokerIds)} / ${jokerCatalog.length}',
                  ),
                  _StatValue(
                    'UI themes',
                    '${summary.themesOwned} / ${summary.themesTotal}',
                  ),
                  _StatValue(
                    'Tables',
                    '${summary.tablesOwned} / ${summary.tablesTotal}',
                  ),
                  _StatValue(
                    'Sly looks',
                    '${summary.slyLooksOwned} / ${summary.slyLooksTotal}',
                  ),
                  _StatValue(
                    'Badges earned',
                    '${summary.badgesEarned} / ${badgeCatalog.length}',
                  ),
                  _StatValue('Current title', summary.equippedTitleName),
                ],
              ),
              ScreenSectionTitle(
                'Badges (${summary.badgesEarned}/${badgeCatalog.length}) · tap for requirement',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final badge in badgeCatalog)
                    _badge(badge, _badgeEarned(badge.id, snapshot, account)),
                ],
              ),
              const ScreenSectionTitle('Player title · tap to wear'),
              for (final title in titleCatalog)
                _titleRow(title, titleIsUnlocked(title.id, snapshot)),
              const ScreenSectionTitle('Lifetime'),
              _StatsGrid(
                entries: [
                  _StatValue('Runs played', _format(account.stats.runs)),
                  _StatValue('Wins', _format(account.stats.wins)),
                  _StatValue('Standard wins', _format(summary.standardWins)),
                  _StatValue(
                    'Gauntlet wins',
                    _format(account.stats.gauntletWins),
                  ),
                  _StatValue('Hands played', _format(account.stats.hands)),
                  _StatValue('Losses / folds', _format(summary.lossesAndFolds)),
                ],
              ),
              if (account.runLog.isNotEmpty) ...[
                const ScreenSectionTitle('Recent runs'),
                for (final run in account.runLog.take(5)) _recentRun(run),
              ],
              const ScreenSectionTitle('Achievements'),
              for (final achievement in achievementCatalog)
                _achievementRow(achievement, snapshot),
            ],
          ),
        );
      },
    );
  }

  Widget _personalBest(int bestHeat) => WildcardCard(
    accent: WildcardCardAccent.gold,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PERSONAL BEST',
                style: TextStyle(fontFamily: 'Bungee', fontSize: 12),
              ),
              SizedBox(height: 2),
              Text('Highest Heat reached', style: TextStyle(fontSize: 11.5)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'HEAT $bestHeat',
          style: TextStyle(
            color: context.wildcard.gold,
            fontFamily: 'Bungee',
            fontSize: 25,
          ),
        ),
      ],
    ),
  );

  Widget _badge(BadgeDefinition badge, bool earned) => Semantics(
    button: true,
    label: '${badge.name}. ${earned ? 'Earned' : 'Locked'}',
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            badge.name.toUpperCase(),
            style: const TextStyle(fontFamily: 'Bungee'),
          ),
          content: Text(
            '${earned ? 'Earned' : 'Locked'}\n\n${badge.description}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      ),
      child: Container(
        width: 104,
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: earned ? const Color(0xD51B1535) : const Color(0xD20A1010),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: earned ? context.wildcard.gold : context.wildcard.line,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              earned
                  ? Icons.workspace_premium_rounded
                  : Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 5),
            Text(
              badge.name.toUpperCase(),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Bungee', fontSize: 9),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _titleRow(TitleDefinition title, bool unlocked) {
    final equippedId = canonicalTitleId(widget.controller.account.title);
    final equipped = equippedId == title.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: WildcardCard(
        selected: equipped,
        child: Row(
          children: [
            Icon(unlocked ? Icons.sell_outlined : Icons.lock_outline_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title.name.toUpperCase(),
                style: const TextStyle(fontFamily: 'Bungee'),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: busy || !unlocked || equipped
                  ? null
                  : () async {
                      setState(() => busy = true);
                      await widget.controller.equipTitle(
                        title.id,
                        widget.controller.progressionSnapshot,
                      );
                      if (mounted) setState(() => busy = false);
                    },
              child: Text(equipped ? 'ON' : (unlocked ? 'WEAR' : 'LOCKED')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentRun(RunLogRecord run) {
    final mode = switch (run.modeCode) {
      'G' => 'Gauntlet',
      'D' => 'Daily',
      _ => 'Run',
    };
    final outcome = run.won
        ? 'WIN'
        : run.abandoned
        ? 'TERMINATED'
        : 'OUT';
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: WildcardCard(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$mode · Heat ${run.heat}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (run.date.isNotEmpty)
                    Text(run.date, style: const TextStyle(fontSize: 10.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_format(run.score)} pts',
                  style: TextStyle(
                    color: context.wildcard.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(outcome, style: const TextStyle(fontSize: 10.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _achievementRow(
    AchievementDefinition definition,
    ProgressionSnapshot snapshot,
  ) {
    final earned =
        achievementIsDone(definition.id, snapshot) ||
        widget.controller.account.achievements[definition.id] != null;
    final claimed =
        widget.controller.account.achievementClaimed[definition.id] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: WildcardCard(
        accent: earned ? WildcardCardAccent.mint : WildcardCardAccent.neutral,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              earned ? Icons.emoji_events_outlined : Icons.lock_outline_rounded,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.name.toUpperCase(),
                    style: const TextStyle(fontFamily: 'Bungee', fontSize: 11),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    definition.description,
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(52, 48)),
              onPressed: busy || !earned || claimed
                  ? null
                  : () => _claimAchievement(definition.id),
              child: Text(claimed ? '✓' : '+${definition.reward}'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _claimAchievement(String id) async {
    setState(() => busy = true);
    await widget.controller.claimAchievement(
      id,
      widget.controller.progressionSnapshot,
    );
    if (mounted) setState(() => busy = false);
  }

  static String _format(int value) => _number.format(value);
}

class _StatValue {
  const _StatValue(this.label, this.value);

  final String label;
  final Object value;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.entries});

  final List<_StatValue> entries;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: entries.length,
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 220,
      mainAxisExtent: 88,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
    ),
    itemBuilder: (context, index) {
      final entry = entries[index];
      final value = '${entry.value}';
      return WildcardCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              entry.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, height: 1.1),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.wildcard.mint,
                fontFamily: 'Bungee',
                fontSize: value.length > 13 ? 13 : 17,
                height: 1.05,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Cabinet calculations are kept deterministic so migrated v7.1 saves show
/// the same profile values as the shipped phone client.
class CabinetSummary {
  const CabinetSummary({
    required this.achievementsEarned,
    required this.collectionPercent,
    required this.winRate,
    required this.averageHands,
    required this.recentAverageScore,
    required this.recentAverageHeat,
    required this.themesOwned,
    required this.themesTotal,
    required this.tablesOwned,
    required this.tablesTotal,
    required this.slyLooksOwned,
    required this.slyLooksTotal,
    required this.badgesEarned,
    required this.equippedTitleName,
    required this.standardWins,
    required this.lossesAndFolds,
  });

  factory CabinetSummary.fromAccount(
    AccountState account,
    ProgressionSnapshot snapshot,
  ) {
    final ownedCosmetics = <String>{
      ...defaultCosmeticIds,
      ...account.cosmeticsOwned,
    };
    int ownedFor(CosmeticKind kind) => cosmeticCatalog
        .where((item) => item.kind == kind && ownedCosmetics.contains(item.id))
        .length;
    int totalFor(CosmeticKind kind) =>
        cosmeticCatalog.where((item) => item.kind == kind).length;

    final logs = account.runLog;
    final recentAverageScore = logs.isEmpty
        ? '—'
        : NumberFormat.decimalPattern('en_GB').format(
            (logs.fold<int>(0, (sum, run) => sum + run.score) / logs.length)
                .round(),
          );
    final recentAverageHeat = logs.isEmpty
        ? '—'
        : (logs.fold<int>(0, (sum, run) => sum + run.heat) / logs.length)
              .toStringAsFixed(1);
    final runs = account.stats.runs;
    final wins = account.stats.wins;
    final ownedCollection =
        publicUnlockedJokerCount(account.unlockedJokerIds) +
        cosmeticCatalog
            .where((item) => ownedCosmetics.contains(item.id))
            .length;
    final totalCollection = jokerCatalog.length + cosmeticCatalog.length;
    final titleId = canonicalTitleId(account.title);
    final titleName = titleCatalog
        .where((title) => title.id == titleId)
        .map((title) => title.name)
        .firstOrNull;

    return CabinetSummary(
      achievementsEarned: account.achievements.length,
      collectionPercent: totalCollection == 0
          ? 0
          : (ownedCollection * 100 / totalCollection).round(),
      winRate: runs == 0 ? '—' : '${(wins * 100 / runs).round()}%',
      averageHands: runs == 0
          ? '—'
          : (account.stats.hands / runs).toStringAsFixed(1),
      recentAverageScore: recentAverageScore,
      recentAverageHeat: recentAverageHeat,
      themesOwned: ownedFor(CosmeticKind.theme),
      themesTotal: totalFor(CosmeticKind.theme),
      tablesOwned: ownedFor(CosmeticKind.table),
      tablesTotal: totalFor(CosmeticKind.table),
      slyLooksOwned: ownedFor(CosmeticKind.sly),
      slyLooksTotal: totalFor(CosmeticKind.sly),
      badgesEarned: badgeCatalog
          .where((badge) => _badgeEarned(badge.id, snapshot, account))
          .length,
      equippedTitleName: titleName ?? 'None',
      standardWins: (wins - account.stats.gauntletWins).clamp(0, wins),
      lossesAndFolds: (runs - wins).clamp(0, runs),
    );
  }

  final int achievementsEarned;
  final int collectionPercent;
  final String winRate;
  final String averageHands;
  final String recentAverageScore;
  final String recentAverageHeat;
  final int themesOwned;
  final int themesTotal;
  final int tablesOwned;
  final int tablesTotal;
  final int slyLooksOwned;
  final int slyLooksTotal;
  final int badgesEarned;
  final String equippedTitleName;
  final int standardWins;
  final int lossesAndFolds;
}

String? canonicalTitleId(String stored) {
  final normalized = stored.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  for (final title in titleCatalog) {
    if (title.id.toLowerCase() == normalized ||
        title.name.toLowerCase() == normalized) {
      return title.id;
    }
  }
  return null;
}

bool _badgeEarned(
  String id,
  ProgressionSnapshot snapshot,
  AccountState account,
) => badgeIsEarned(
  id,
  snapshot,
  bankroll2000Achievement: account.achievements.containsKey('bankroll_2000'),
);
