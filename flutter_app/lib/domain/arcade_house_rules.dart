import 'cards.dart';

/// Optional, run-wide rules for the normal Arcade loop.
///
/// These are deliberately separate from [RunMode] and Level Mode. A House
/// Rule run still uses the normal Heat/shop/endless flow, but is kept off the
/// standard score boards so a modified ruleset cannot displace a Classic run.
enum ArcadeHouseRule {
  paupersTable(
    id: 'paupers_table',
    name: "Paupers' Table",
    summary: 'Jacks, Queens and Kings still form hands but score 0 rank.',
    icon: '♟',
  ),
  royalCourt(
    id: 'royal_court',
    name: 'Royal Court',
    summary: 'Only Jacks, Queens, Kings and Aces contribute printed rank.',
    icon: '♛',
  ),
  colourBlind(
    id: 'colour_blind',
    name: 'Colour Blind',
    summary: 'Red scores rank on odd Heats; black scores rank on even Heats.',
    icon: '◐',
  ),
  suitCarousel(
    id: 'suit_carousel',
    name: 'Suit Carousel',
    summary: 'One suit scores 0 rank each play, rotating in a visible order.',
    icon: '♠',
  ),
  echoTable(
    id: 'echo_table',
    name: 'Echo Table',
    summary: 'Repeat a hand type in the same Heat and it loses 35% each time.',
    icon: '↻',
  ),
  discardDuty(
    id: 'discard_duty',
    name: 'Discard Duty',
    summary: 'Each discard raises the current target by 5%.',
    icon: '↑',
  ),
  closingWindow(
    id: 'closing_window',
    name: 'Closing Window',
    summary: 'After every scored hand, one remaining discard expires.',
    icon: '⌛',
  ),
  modifierMarathon(
    id: 'modifier_marathon',
    name: 'Modifier Marathon',
    summary: 'Every Heat receives a normal eligible modifier.',
    icon: '⚡',
  );

  const ArcadeHouseRule({
    required this.id,
    required this.name,
    required this.summary,
    required this.icon,
  });

  final String id;
  final String name;
  final String summary;
  final String icon;

  static ArcadeHouseRule? fromId(Object? value) {
    if (value is! String || value.isEmpty) return null;
    for (final rule in values) {
      if (rule.id == value) return rule;
    }
    return null;
  }

  /// Short, live rule copy shown over the table.
  String tableSummary({
    required int stage,
    required int handsPlayedThisStage,
    required int targetTax,
  }) => switch (this) {
    ArcadeHouseRule.colourBlind =>
      '${stage.isOdd ? 'RED' : 'BLACK'} cards score rank this Heat.',
    ArcadeHouseRule.suitCarousel =>
      '${disabledSuitForPlay(handsPlayedThisStage).name.toUpperCase()} scores 0 rank this play.',
    ArcadeHouseRule.discardDuty =>
      targetTax == 0
          ? 'Each discard raises this Heat target by 5%.'
          : 'Discard tax has added +$targetTax to this Heat target.',
    ArcadeHouseRule.closingWindow =>
      'One remaining discard expires after every scored hand.',
    _ => summary,
  };

  CardSuit disabledSuitForPlay(int playIndex) =>
      CardSuit.values[playIndex.abs() % CardSuit.values.length];
}

const int arcadeHouseRuleUnlockHeat = 12;
