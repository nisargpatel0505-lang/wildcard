enum CardSuit {
  spades('♠', false, 0),
  hearts('♥', true, 1),
  clubs('♣', false, 2),
  diamonds('♦', true, 3);

  const CardSuit(this.symbol, this.isRed, this.sortOrder);

  final String symbol;
  final bool isRed;
  final int sortOrder;

  static CardSuit fromSymbol(String value) => CardSuit.values.firstWhere(
    (suit) => suit.symbol == value,
    orElse: () => throw FormatException('Unknown card suit: $value'),
  );
}

/// WILDCARD intentionally values an Ace at 15. There is no rank value 14.
enum CardRank {
  two('2', 2),
  three('3', 3),
  four('4', 4),
  five('5', 5),
  six('6', 6),
  seven('7', 7),
  eight('8', 8),
  nine('9', 9),
  ten('10', 10),
  jack('J', 11),
  queen('Q', 12),
  king('K', 13),
  ace('A', 15);

  const CardRank(this.label, this.value);

  final String label;
  final int value;

  static CardRank fromLabel(String value) => CardRank.values.firstWhere(
    (rank) => rank.label == value,
    orElse: () => throw FormatException('Unknown card rank: $value'),
  );

  static CardRank fromValue(int value) => CardRank.values.firstWhere(
    (rank) => rank.value == value,
    orElse: () => throw FormatException('Unknown card value: $value'),
  );
}

enum CardEnhancement {
  gild,
  neon,
  glass,
  wildsuit;

  static CardEnhancement? fromLegacy(Object? value) {
    if (value == null || value == '') return null;
    return CardEnhancement.values.cast<CardEnhancement?>().firstWhere(
      (enhancement) => enhancement!.name == value,
      orElse: () => null,
    );
  }
}

class PlayingCard {
  const PlayingCard({
    required this.rank,
    required this.suit,
    this.enhancement,
    this.copied = false,
    this.uid,
    this.selected = false,
    this.isNew = false,
  });

  final CardRank rank;
  final CardSuit suit;
  final CardEnhancement? enhancement;

  /// True when the card was created by Copier (or by dyeing into a duplicate).
  ///
  /// v7.1.0 limits a deck to two exact rank/suit copies, forbids enhancements
  /// on copied cards, and makes copied cards score zero during Counterfeit.
  final bool copied;
  final String? uid;
  final bool selected;
  final bool isNew;

  int get value => rank.value;
  bool get isRed => suit.isRed;

  PlayingCard copyWith({
    CardRank? rank,
    CardSuit? suit,
    CardEnhancement? enhancement,
    bool clearEnhancement = false,
    bool? copied,
    String? uid,
    bool? selected,
    bool? isNew,
  }) {
    return PlayingCard(
      rank: rank ?? this.rank,
      suit: suit ?? this.suit,
      enhancement: clearEnhancement ? null : (enhancement ?? this.enhancement),
      copied: copied ?? this.copied,
      uid: uid ?? this.uid,
      selected: selected ?? this.selected,
      isNew: isNew ?? this.isNew,
    );
  }

  factory PlayingCard.fromJson(Map<String, Object?> json) {
    final rankLabel = json['rank']?.toString();
    final encodedValue = _asInt(json['value']);
    final rank = rankLabel != null
        ? CardRank.fromLabel(rankLabel)
        : CardRank.fromValue(encodedValue);
    if (encodedValue != 0 && encodedValue != rank.value) {
      throw FormatException(
        'Card rank/value disagree: $rankLabel/$encodedValue',
      );
    }
    return PlayingCard(
      rank: rank,
      suit: CardSuit.fromSymbol(json['suit']?.toString() ?? ''),
      enhancement: CardEnhancement.fromLegacy(json['enh']),
      copied: json['copied'] == true,
      uid: json['uid']?.toString(),
      selected: json['selected'] == true,
      isNew: json['isNew'] == true,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'rank': rank.label,
    'value': rank.value,
    'suit': suit.symbol,
    'red': suit.isRed,
    if (enhancement != null) 'enh': enhancement!.name,
    if (copied) 'copied': true,
    if (uid != null) 'uid': uid,
    if (selected) 'selected': true,
    if (isNew) 'isNew': true,
  };

  @override
  String toString() => '${rank.label}${suit.symbol}';
}

List<PlayingCard> baseCardSet() => <PlayingCard>[
  for (final suit in CardSuit.values)
    for (final rank in CardRank.values) PlayingCard(rank: rank, suit: suit),
];

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.floor();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
