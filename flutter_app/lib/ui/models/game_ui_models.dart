import 'package:flutter/foundation.dart';

import '../../domain/joker_catalog.dart';

/// Presentation state for a Joker offered by a between-Heat shop.
///
/// The underlying definition remains the domain catalogue object. The UI only
/// adds ephemeral offer state and never owns purchase logic.
@immutable
class JokerShopOffer {
  const JokerShopOffer({
    required this.joker,
    this.price,
    this.soldOut = false,
    this.canBuy,
  });

  final JokerDefinition joker;
  final int? price;
  final bool soldOut;
  final bool? canBuy;

  int get effectivePrice => price ?? joker.price;
}
