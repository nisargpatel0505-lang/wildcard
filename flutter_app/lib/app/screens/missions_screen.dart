import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/progression_catalog.dart';
import '../../ui/wildcard_ui.dart';
import 'page_frame.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final account = widget.controller.account;
        return WildcardPageFrame(
          title: 'Weekly Missions',
          subtitle: account.missionWeek,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
            children: [
              for (final id in account.missionSet)
                if (_mission(id) case final mission?) _missionCard(mission),
              const SizedBox(height: 6),
              WildcardButton(
                label: account.missionRefreshDate == _today()
                    ? 'Refresh Available Tomorrow'
                    : widget.controller.weeklyMissionsNeedAttention
                    ? 'Claim Ready Reward First'
                    : 'Watch Ad & Refresh All Three',
                icon: const Icon(Icons.refresh_rounded),
                onPressed:
                    !busy &&
                        account.missionRefreshDate != _today() &&
                        !widget.controller.weeklyMissionsNeedAttention &&
                        widget.controller.rewardedViewsLeftToday > 0
                    ? _refresh
                    : null,
                variant: WildcardButtonVariant.ghost,
              ),
              const SizedBox(height: 8),
              Text(
                'One refresh per day · uses the shared rewarded-ad daily limit · existing progress and claimed rewards remain safe.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.wildcard.creamDim,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _missionCard(WeeklyContractDefinition mission) {
    final account = widget.controller.account;
    final progress = account.missionStats[mission.stat] ?? 0;
    final ready = progress >= mission.target;
    final claimed = account.missionClaimed[mission.id] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WildcardCard(
        accent: ready ? WildcardCardAccent.gold : WildcardCardAccent.mint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mission.name.toUpperCase(),
              style: const TextStyle(fontFamily: 'Bungee'),
            ),
            const SizedBox(height: 4),
            Text(mission.description),
            const SizedBox(height: 9),
            LinearProgressIndicator(
              value: (progress / mission.target).clamp(0, 1),
              minHeight: 9,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(child: Text('$progress / ${mission.target}')),
                FilledButton(
                  onPressed: busy || !ready || claimed
                      ? null
                      : () => _claim(mission.id),
                  child: Text(claimed ? 'CLAIMED' : '+${mission.reward}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  WeeklyContractDefinition? _mission(String id) {
    for (final mission in weeklyContractCatalog) {
      if (mission.id == id) return mission;
    }
    return null;
  }

  Future<void> _claim(String id) async {
    setState(() => busy = true);
    await widget.controller.claimWeeklyMission(id);
    if (mounted) setState(() => busy = false);
  }

  Future<void> _refresh() async {
    setState(() => busy = true);
    final ok = await widget.controller.refreshWeeklyMissionsWithRewardedAd();
    if (!mounted) return;
    setState(() => busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Weekly contracts refreshed.' : 'Refresh unavailable.',
        ),
      ),
    );
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
