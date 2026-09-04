import 'account_state.dart';
import 'long_term_progression.dart';

/// One-time goals, with no timers, streak penalties or wagers.
const astraJourneyClaimKey = 'astraJourneyClaimsV1';

class AstraJourneyStep {
  const AstraJourneyStep({
    required this.id,
    required this.title,
    required this.description,
    required this.current,
    required this.target,
    required this.rewardCoins,
    required this.claimed,
  });
  final String id;
  final String title;
  final String description;
  final int current;
  final int target;
  final int rewardCoins;
  final bool claimed;
  bool get ready => !claimed && current >= target;
  double get progress => (current / target).clamp(0.0, 1.0);
  String get progressLabel => '${current.clamp(0, target)} / $target';
}

List<AstraJourneyStep> astraJourneySteps(AccountState account) {
  final rawClaims = account.unknownFields[astraJourneyClaimKey];
  final claims = rawClaims is List
      ? rawClaims.whereType<String>().toSet()
      : <String>{};
  final bestHand =
      account.progressCounters[ProgressCounterKey.bestSingleHand] ?? 0;
  final variety = account.unknownFields.entries
      .where(
        (entry) =>
            entry.key.startsWith('hand:') &&
            entry.value is num &&
            (entry.value! as num) > 0,
      )
      .length;
  AstraJourneyStep goal(
    String id,
    String title,
    String description,
    int current,
    int target,
    int reward,
  ) => AstraJourneyStep(
    id: id,
    title: title,
    description: description,
    current: current,
    target: target,
    rewardCoins: reward,
    claimed: claims.contains(id),
  );
  return [
    goal(
      'first_heat',
      'Find your opening',
      'Clear Heat 1 with your free starter.',
      account.bestClearedHeat,
      1,
      20,
    ),
    goal(
      'first_build',
      'Make it click',
      'Clear Heat 3. Your first Vault is within reach.',
      account.bestClearedHeat,
      3,
      40,
    ),
    goal(
      'fifteen_hands',
      'Read the table',
      'Play 15 hands across completed runs.',
      account.stats.hands,
      15,
      30,
    ),
    goal(
      'five_hundred',
      'A real engine',
      'Score 500 in one hand, then finish the run.',
      bestHand,
      500,
      50,
    ),
    goal(
      'halfway',
      'Past the warm-up',
      'Clear Heat 6 with any starter route.',
      account.bestClearedHeat,
      6,
      60,
    ),
    goal(
      'five_hands',
      'Change your angle',
      'Score five different poker hand types across completed runs.',
      variety,
      5,
      80,
    ),
    goal(
      'beat_sly',
      'Beat the house',
      'Win a Normal run by clearing Heat 12.',
      account.progressCounters[ProgressCounterKey.runsWon] ?? 0,
      1,
      100,
    ),
    goal(
      'three_thousand',
      'Make the numbers sing',
      'Score 3,000 in one hand, then finish the run.',
      bestHand,
      3000,
      150,
    ),
    goal(
      'five_wins',
      'You own this table',
      'Win five Normal runs. Try a different route.',
      account.progressCounters[ProgressCounterKey.runsWon] ?? 0,
      5,
      250,
    ),
  ];
}
