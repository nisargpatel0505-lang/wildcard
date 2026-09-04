import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../domain/progression_catalog.dart';
import '../../domain/astra_progression.dart';
import '../../ui/wildcard_ui.dart';
import 'page_frame.dart';
import '../../ui/widgets/wildcard_toast.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  bool busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.ensureWeeklyMissionsCurrent());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final account = widget.controller.account;
        return WildcardPageFrame(
          title: 'Weekly Missions',
          subtitle: account.missionWeek,
          surface: WildcardUiSurface.missions,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
            children: [
              for (final id in account.missionSet)
                if (_mission(id) case final mission?) _missionCard(mission),
              const SizedBox(height: 6),
              if (!astraEnabled)
                WildcardButton(
                  label: widget.controller.weeklyMissionRefreshUsed
                      ? 'Refresh Used This Week'
                      : 'Watch Ad & Refresh Missions',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed:
                      !busy &&
                          !widget.controller.weeklyMissionRefreshUsed &&
                          widget.controller.rewardedViewsLeftToday > 0
                      ? _refresh
                      : null,
                  variant: WildcardButtonVariant.ghost,
                ),
              const SizedBox(height: 8),
              Text(
                astraEnabled
                    ? 'Mission rewards are earned by playing. Ad refreshes are disabled in this offline experiment.'
                    : 'One optional rewarded refresh per week. It gives no coins; completed rewards, claimed rewards and all progress remain safe.',
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
    showWildcardToast(
      context,
      ok ? 'Weekly contracts refreshed.' : 'Refresh unavailable.',
    );
  }
}
