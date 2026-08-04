import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/economy.dart';
import 'package:wildcard/domain/joker_catalog.dart';

void main() {
  test('owner DEV card stays isolated from the public catalogue', () {
    expect(jokerCatalog, hasLength(89));
    expect(
      jokerCatalog.map((joker) => joker.id),
      isNot(contains(devTwentyXJoker.id)),
    );
    expect(publicUnlockedJokerCount(<String>{devTwentyXJoker.id}), 0);

    if (devJokerAvailable) {
      expect(jokersById[devTwentyXJoker.id], devTwentyXJoker);
      expect(selectableJokers.first, devTwentyXJoker);
      expect(starterJokerPrice(devTwentyXJoker), 0);
    } else {
      expect(jokersById, isNot(contains(devTwentyXJoker.id)));
      expect(selectableJokers, orderedEquals(jokerCatalog));
    }
  });
}
