import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_controller.dart';
import '../../core/app_constants.dart';
import '../../core/daily_utc_date.dart';
import '../../services/pi_service.dart';
import '../../services/play_games_service.dart';
import '../../ui/wildcard_ui.dart';
import 'page_frame.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return WildcardPageFrame(
      title: 'More',
      subtitle: 'Rules, rankings and credits',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
        children: [
          _button(context, 'How To Play', Icons.menu_book_outlined, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HowToPlayScreen()),
            );
          }),
          _button(context, 'WILDCARD Daily Board', Icons.today_outlined, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DailyBoardScreen(controller: controller),
              ),
            );
          }),
          _button(
            context,
            'Official Play Games Rankings',
            Icons.emoji_events_outlined,
            () async {
              if (!controller.playGames.signedIn) {
                if (!await controller.playGames.signIn()) return;
              }
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OfficialRankingsScreen(controller: controller),
                  ),
                );
              }
            },
          ),
          _button(context, 'Privacy Policy', Icons.privacy_tip_outlined, () {
            launchUrl(
              Uri.parse(AppConstants.privacyPolicyUrl),
              mode: LaunchMode.externalApplication,
            );
          }),
          const ScreenSectionTitle('Credits'),
          const WildcardCard(
            child: Text(
              'WILDCARD\nA 145 Studios game\n\nMusic: “Bit Shift” — Kevin MacLeod (incompetech.com). Licensed under Creative Commons Attribution 4.0.\n\nThe in-game copy is tempo-adjusted to approximately 115 BPM with pitch preserved.\n\nBuilt as a native Flutter client with local-first play.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 8),
          WildcardButton(
            label: 'Music License · CC BY 4.0',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => launchUrl(
              Uri.parse('https://creativecommons.org/licenses/by/4.0/'),
              mode: LaunchMode.externalApplication,
            ),
            variant: WildcardButtonVariant.ghost,
          ),
        ],
      ),
    );
  }

  Widget _button(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: WildcardButton(label: label, icon: Icon(icon), onPressed: onTap),
  );
}

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  static const sections = <(String, String)>[
    (
      'Score',
      'Choose up to five cards. Only cards forming the hand contribute rank. Value × Multiplier becomes the play score.',
    ),
    (
      'Heat',
      'Reach the target before Plays run out. Discard weak cards to redraw without scoring.',
    ),
    (
      'Jokers',
      'Up to five Jokers form an engine. They resolve in equipped order and clearly highlight when they trigger.',
    ),
    (
      'Shop',
      'Run coins buy Jokers and supplies. Each offered supply can be bought once per shop; its price rises for the rest of the run.',
    ),
    (
      'Modifiers',
      'Rule-changing Heats appear every third round. THE HOUSE blocks two random equipped Jokers at the finale.',
    ),
    (
      'Endless',
      'After Heat 12 you may continue. Modifiers remain every three Heats until late Endless begins stacking hard rules.',
    ),
  ];

  @override
  Widget build(BuildContext context) => WildcardPageFrame(
    title: 'How To Play',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [
        for (final section in sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: WildcardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.$1.toUpperCase(),
                    style: const TextStyle(fontFamily: 'Bungee'),
                  ),
                  const SizedBox(height: 5),
                  Text(section.$2, style: const TextStyle(height: 1.4)),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class DailyBoardScreen extends StatefulWidget {
  const DailyBoardScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<DailyBoardScreen> createState() => _DailyBoardScreenState();
}

class _DailyBoardScreenState extends State<DailyBoardScreen> {
  late Future<DailyBoardSnapshot> board;

  @override
  void initState() {
    super.initState();
    board = widget.controller.pi.fetchDailyBoard(date: dailyUtcDateKey());
  }

  Future<void> _refresh() async {
    final next = widget.controller.pi.fetchDailyBoard(date: dailyUtcDateKey());
    setState(() => board = next);
    try {
      await next;
    } catch (_) {
      // FutureBuilder presents the retry state; RefreshIndicator must settle.
    }
  }

  @override
  Widget build(BuildContext context) => WildcardPageFrame(
    title: 'Daily Board',
    subtitle: 'Custom in-game daily scores',
    child: FutureBuilder<DailyBoardSnapshot>(
      future: board,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 80),
                const Icon(Icons.cloud_off_outlined, size: 42),
                const SizedBox(height: 12),
                const Text(
                  'Could not reach the Daily Board.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('daily-board-retry'),
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('TRY AGAIN'),
                ),
              ],
            ),
          );
        }
        final data = snapshot.data!;
        if (data.entries.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 80),
                Icon(
                  Icons.emoji_events_outlined,
                  size: 46,
                  color: context.wildcard.gold,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No scores have been posted yet today.\nFinish a Daily Challenge to set the pace.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('daily-board-empty-refresh'),
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('REFRESH'),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            itemCount: data.entries.length,
            itemBuilder: (context, index) {
              final row = data.entries[index];
              return ListTile(
                leading: Text(
                  '#${index + 1}',
                  style: const TextStyle(fontFamily: 'Bungee'),
                ),
                title: Text(row.name),
                trailing: Text(
                  '${row.score}',
                  style: TextStyle(
                    color: context.wildcard.gold,
                    fontFamily: 'Bungee',
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class OfficialRankingsScreen extends StatefulWidget {
  const OfficialRankingsScreen({required this.controller, super.key});
  final AppController controller;

  @override
  State<OfficialRankingsScreen> createState() => _OfficialRankingsScreenState();
}

class _OfficialRankingsScreenState extends State<OfficialRankingsScreen> {
  LeaderboardTimeSpan span = LeaderboardTimeSpan.allTime;
  late Future<List<PlayGamesScore>> scores;

  @override
  void initState() {
    super.initState();
    scores = widget.controller.playGames.loadScores(span);
  }

  Future<void> _refresh() async {
    final next = widget.controller.playGames.loadScores(span);
    setState(() => scores = next);
    try {
      await next;
    } catch (_) {
      // The FutureBuilder below owns the visible error state.
    }
  }

  @override
  Widget build(BuildContext context) => WildcardPageFrame(
    title: 'Official Rankings',
    subtitle: 'Google Play Games · legitimate scores only',
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: SegmentedButton<LeaderboardTimeSpan>(
            segments: const [
              ButtonSegment(
                value: LeaderboardTimeSpan.daily,
                label: Text('Daily'),
              ),
              ButtonSegment(
                value: LeaderboardTimeSpan.weekly,
                label: Text('Weekly'),
              ),
              ButtonSegment(
                value: LeaderboardTimeSpan.allTime,
                label: Text('All'),
              ),
            ],
            selected: <LeaderboardTimeSpan>{span},
            onSelectionChanged: (selection) {
              setState(() {
                span = selection.first;
                scores = widget.controller.playGames.loadScores(span);
              });
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<PlayGamesScore>>(
            future: scores,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Rankings are unavailable.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const Key('official-rankings-retry'),
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('TRY AGAIN'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final rows = snapshot.data ?? const <PlayGamesScore>[];
              if (rows.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 80),
                      const Text(
                        'No ranked scores are available for this period.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('REFRESH'),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return ListTile(
                      leading: Text(
                        row.displayRank.isEmpty
                            ? '#${row.rank}'
                            : row.displayRank,
                      ),
                      title: Text(row.displayName),
                      trailing: Text(
                        row.displayScore.isEmpty
                            ? '${row.rawScore}'
                            : row.displayScore,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
