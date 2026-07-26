import 'dart:math' as math;

import '../ui/widgets/sly_sprite.dart';

/// Sly's full table-talk script, ported verbatim from the WebView build.
///
/// The original `SLY` object held 26 reaction categories with a random quip
/// pool for each. The first Flutter port replaced all of it with a handful of
/// fixed strings, so Sly repeated the same sentence for every Pair forever
/// and the game lost its voice. The data lives here as a plain catalogue;
/// the host picks a mood, and [SlyQuipSet.pick] draws a line.
enum SlyMood {
  unbelievable,
  scared,
  impressed,
  meh,
  laughing,
  highCard,
  pair,
  twoPair,
  trips,
  straight,
  flush,
  fullHouse,
  quads,
  straightFlush,
  royalFlush,
  discard,
  greet,
  clear,
  clutch,
  modifier,
  sevenHit,
  sevenMiss,
  wildBuy,
  buy,
  boost,
  heatFail,
  fold,
}

enum SlyMotionProfile { none, pop, rock, tremble }

/// One visible Sly reaction. Sequence identity guarantees that two consecutive
/// reactions with the same line still replay their motion.
class SlyReaction {
  const SlyReaction({
    required this.mood,
    required this.priority,
    required this.expression,
    required this.speech,
    required this.label,
    required this.motion,
    required this.hold,
    required this.sequence,
    required this.generation,
  });

  final SlyMood mood;
  final int priority;
  final SlyExpression expression;
  final String speech;

  /// Short, glanceable counterpart to the speech line. The WebView surfaced
  /// these as badges ("PAIR", "JOKER", "JACKPOT"...) while the longer quip
  /// changed alongside Sly's face.
  final String label;
  final SlyMotionProfile motion;
  final Duration hold;
  final int sequence;

  /// Reactions compete only within one scoring/action context. A high-priority
  /// finale from the previous hand must never swallow the first beat of the
  /// next hand.
  final int generation;

  bool blocks({required int generation, required int priority}) =>
      this.generation == generation && this.priority > priority;
}

class SlyQuipSet {
  const SlyQuipSet({required this.expression, required this.quips});

  /// The sprite frame that matches the WebView's emoji face pool.
  final SlyExpression expression;
  final List<String> quips;

  String pick(math.Random random) => quips[random.nextInt(quips.length)];
}

/// How long Sly's bubble holds before returning to the passive line. Longer
/// than the WebView so the quip is comfortably readable.
Duration slyHoldFor(SlyMood mood) => switch (mood) {
  SlyMood.fullHouse ||
  SlyMood.quads ||
  SlyMood.straightFlush ||
  SlyMood.royalFlush ||
  SlyMood.unbelievable => const Duration(milliseconds: 5600),
  _ => const Duration(milliseconds: 4400),
};

/// The compact reaction badge used beside Sly's speech.
String slyLabelFor(SlyMood mood) => switch (mood) {
  SlyMood.unbelievable => 'BIG SCORE',
  SlyMood.scared => 'DANGER',
  SlyMood.impressed => 'NICE',
  SlyMood.meh => 'LOW SCORE',
  SlyMood.laughing || SlyMood.highCard => 'HIGH CARD',
  SlyMood.pair => 'PAIR',
  SlyMood.twoPair => '2 PAIR',
  SlyMood.trips => 'TRIPS',
  SlyMood.straight => 'STRAIGHT',
  SlyMood.flush => 'FLUSH',
  SlyMood.fullHouse => 'FULL HOUSE',
  SlyMood.quads => 'QUADS',
  SlyMood.straightFlush => 'STRAIGHT FLUSH',
  SlyMood.royalFlush => 'ROYAL',
  SlyMood.discard => 'DISCARD',
  SlyMood.greet => 'NEW DEAL',
  SlyMood.clear => 'HEAT CLEAR',
  SlyMood.clutch => 'LAST PLAY',
  SlyMood.modifier => 'MODIFIER',
  SlyMood.sevenHit => 'JACKPOT',
  SlyMood.sevenMiss => 'MISS',
  SlyMood.wildBuy => 'WILD',
  SlyMood.buy => 'BOUGHT',
  SlyMood.boost => 'LEVEL UP',
  SlyMood.heatFail => 'TARGET HELD',
  SlyMood.fold => 'FOLD',
};

/// The scoring finale is emitted before [ScoringState] commits the hand, so
/// both values must be projected to decide whether exactly one play remains.
bool slyShouldWarnClutch({
  required int handsLeftBeforePlay,
  required int stageScoreBeforePlay,
  required int handTotal,
  required int target,
}) {
  final remainingHands = math.max(0, handsLeftBeforePlay - 1);
  final projectedScore = stageScoreBeforePlay + handTotal;
  return remainingHands == 1 && projectedScore < target;
}

const Map<SlyMood, SlyQuipSet> slyQuips = <SlyMood, SlyQuipSet>{
  SlyMood.unbelievable: SlyQuipSet(
    expression: SlyExpression.shocked,
    quips: [
      'That score just crossed the table.',
      'Your multiplier finally has teeth.',
      'The target felt that one.',
      'Fine. That was a real hand.',
    ],
  ),
  SlyMood.scared: SlyQuipSet(
    expression: SlyExpression.scared,
    quips: [
      'That engine is scaling too fast.',
      'The target is suddenly looking small.',
      'Your Jokers are doing real work now.',
    ],
  ),
  SlyMood.impressed: SlyQuipSet(
    expression: SlyExpression.impressed,
    quips: [
      'Useful score. Do it again.',
      'That keeps the Heat alive.',
      'Better. You found the scoring cards.',
    ],
  ),
  SlyMood.meh: SlyQuipSet(
    expression: SlyExpression.disappointed,
    quips: [
      'The target barely moved.',
      'You spent a play on that?',
      'Your multiplier needs help.',
    ],
  ),
  SlyMood.laughing: SlyQuipSet(
    expression: SlyExpression.laughing,
    quips: [
      'High Card. The House is terrified.',
      'That play did more for me than you.',
      'Try selecting cards that agree with each other.',
    ],
  ),
  SlyMood.highCard: SlyQuipSet(
    expression: SlyExpression.disappointed,
    quips: [
      'High Card. Bold way to waste a play.',
      'One card scored. The rest watched.',
      'The target barely noticed that hand.',
    ],
  ),
  SlyMood.pair: SlyQuipSet(
    expression: SlyExpression.thoughtful,
    quips: [
      'A Pair. At least two cards had a plan.',
      'Two matching ranks. Now find some Mult.',
      'A Pair keeps you breathing, not winning.',
    ],
  ),
  SlyMood.twoPair: SlyQuipSet(
    expression: SlyExpression.thoughtful,
    quips: [
      'Two Pair. Four cards finally cooperated.',
      'Two Pair is tidy. The target wants more.',
      'Better shape. Still not enough pressure.',
    ],
  ),
  SlyMood.trips: SlyQuipSet(
    expression: SlyExpression.impressed,
    quips: [
      'Three of a Kind. That line has teeth.',
      'Trips found the rank value. Feed the Mult.',
      'Three matching ranks. Keep that engine focused.',
    ],
  ),
  SlyMood.straight: SlyQuipSet(
    expression: SlyExpression.impressed,
    quips: [
      'Straight. Five ranks, no excuses.',
      'Clean sequence. Now make it scale.',
      'A Straight moves the target. Keep pace.',
    ],
  ),
  SlyMood.flush: SlyQuipSet(
    expression: SlyExpression.impressed,
    quips: [
      'Flush. One suit finally did its job.',
      'Five suited cards. That engine can work.',
      'A Flush is pressure. Do it again.',
    ],
  ),
  SlyMood.fullHouse: SlyQuipSet(
    expression: SlyExpression.shocked,
    quips: [
      'Full House. The table is getting crowded.',
      'Trips and a Pair. That is proper scoring.',
      'Full House. Now the target is listening.',
    ],
  ),
  SlyMood.quads: SlyQuipSet(
    expression: SlyExpression.shocked,
    quips: [
      'Four of a Kind. You found the loaded rank.',
      'Quads. Even I cannot mock that hand.',
      'Four matching cards. The House noticed.',
    ],
  ),
  SlyMood.straightFlush: SlyQuipSet(
    expression: SlyExpression.shocked,
    quips: [
      'Straight Flush. That is the line.',
      'Five suited ranks. The target is in trouble.',
      'Straight Flush. Keep your foot down.',
    ],
  ),
  SlyMood.royalFlush: SlyQuipSet(
    expression: SlyExpression.shocked,
    quips: [
      'Royal Flush. I have nothing to add.',
      'The top five, one suit. You win this argument.',
      'Royal Flush. The House will remember that.',
    ],
  ),
  SlyMood.discard: SlyQuipSet(
    expression: SlyExpression.thoughtful,
    quips: [
      'Cut the dead cards.',
      'A discard is only smart if the refill scores.',
      'Throw them out. The deck owes you nothing.',
    ],
  ),
  SlyMood.greet: SlyQuipSet(
    expression: SlyExpression.idle,
    quips: [
      'New Heat. Show me an engine.',
      'Fresh target. Same weak excuses.',
      'Spend each play like it matters.',
    ],
  ),
  SlyMood.clear: SlyQuipSet(
    expression: SlyExpression.triumphant,
    quips: [
      'Heat cleared. The next target is worse.',
      'You cleared it. Do not slow down.',
      'One target down. The House is still ahead.',
    ],
  ),
  SlyMood.clutch: SlyQuipSet(
    expression: SlyExpression.scared,
    quips: [
      'One play left. Beat the target.',
      'Last play. Find your strongest hand.',
      'No spare plays now. Make the Mult count.',
    ],
  ),
  SlyMood.modifier: SlyQuipSet(
    expression: SlyExpression.thoughtful,
    quips: [
      'Read the modifier before you spend a play.',
      'This Heat changes the rules. Adapt.',
      'The modifier is active. Build around it.',
    ],
  ),
  SlyMood.sevenHit: SlyQuipSet(
    expression: SlyExpression.shocked,
    quips: [
      'Lucky Seven paid. Bank the score.',
      'The Seven hit. Do not mistake it for a plan.',
      'That roll rescued the hand.',
    ],
  ),
  SlyMood.sevenMiss: SlyQuipSet(
    expression: SlyExpression.disappointed,
    quips: [
      'The Seven missed. Build a safer engine.',
      'No payout. The target still wants points.',
      'Luck passed. Your Jokers still have work.',
    ],
  ),
  SlyMood.wildBuy: SlyQuipSet(
    expression: SlyExpression.scared,
    quips: [
      'WILD Joker. Now prove it fits the engine.',
      'Big effect, big price. Make it score.',
      'That Joker can carry a run if you use it.',
    ],
  ),
  SlyMood.buy: SlyQuipSet(
    expression: SlyExpression.impressed,
    quips: [
      'That Joker fits the run.',
      'Good buy. Now trigger it.',
      'The engine has a new part.',
    ],
  ),
  SlyMood.boost: SlyQuipSet(
    expression: SlyExpression.impressed,
    quips: [
      'Hand level up. Use it.',
      'The base score improved. Feed it Mult.',
      'That hand type is worth chasing now.',
    ],
  ),
  SlyMood.heatFail: SlyQuipSet(
    expression: SlyExpression.laughing,
    quips: [
      'No plays left. The target held.',
      'That was your last hand. The House wins this Heat.',
      'Target missed. Build a better engine next run.',
    ],
  ),
  SlyMood.fold: SlyQuipSet(
    expression: SlyExpression.disappointed,
    quips: [
      'Run terminated. The coins already earned are safe.',
      'Fold accepted. The House keeps the Heat.',
      'You left the table before the target did.',
    ],
  ),
};

/// Picks the finale reaction from projected state because scoring presentation
/// completes before the controller commits the hand. This keeps clear/fail
/// faces accurate without changing any score or transition timing.
SlyMood slyFinaleMood({
  required SlyMood handMood,
  required int handsLeftBeforePlay,
  required int stageScoreBeforePlay,
  required int handTotal,
  required int target,
}) {
  final projectedScore = stageScoreBeforePlay + handTotal;
  if (projectedScore >= target) return SlyMood.clear;
  if (handsLeftBeforePlay <= 1) return SlyMood.heatFail;
  if (slyShouldWarnClutch(
    handsLeftBeforePlay: handsLeftBeforePlay,
    stageScoreBeforePlay: stageScoreBeforePlay,
    handTotal: handTotal,
    target: target,
  )) {
    return SlyMood.clutch;
  }
  return handMood;
}
