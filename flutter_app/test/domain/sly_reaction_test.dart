import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/domain/sly_quips.dart';
import 'package:wildcard/ui/widgets/sly_sprite.dart';

void main() {
  test(
    'hand moods expose the same glanceable badges as the table reaction',
    () {
      expect(slyLabelFor(SlyMood.highCard), 'HIGH CARD');
      expect(slyLabelFor(SlyMood.twoPair), '2 PAIR');
      expect(slyLabelFor(SlyMood.fullHouse), 'FULL HOUSE');
      expect(slyLabelFor(SlyMood.straightFlush), 'STRAIGHT FLUSH');
      expect(slyLabelFor(SlyMood.sevenHit), 'JACKPOT');
      expect(slyLabelFor(SlyMood.clutch), 'LAST PLAY');
    },
  );

  test('clutch warning projects both consumed play and committed score', () {
    expect(
      slyShouldWarnClutch(
        handsLeftBeforePlay: 2,
        stageScoreBeforePlay: 40,
        handTotal: 30,
        target: 100,
      ),
      isTrue,
    );
    expect(
      slyShouldWarnClutch(
        handsLeftBeforePlay: 1,
        stageScoreBeforePlay: 40,
        handTotal: 30,
        target: 100,
      ),
      isFalse,
      reason: 'The play being presented was already the final play.',
    );
    expect(
      slyShouldWarnClutch(
        handsLeftBeforePlay: 2,
        stageScoreBeforePlay: 70,
        handTotal: 30,
        target: 100,
      ),
      isFalse,
      reason: 'A hand that reaches the target must not ask for another play.',
    );
  });

  test('reaction priority is isolated to its generation', () {
    const reaction = SlyReaction(
      mood: SlyMood.royalFlush,
      priority: 5,
      expression: SlyExpression.shocked,
      speech: 'Royal Flush.',
      label: 'ROYAL',
      motion: SlyMotionProfile.rock,
      hold: Duration(seconds: 1),
      sequence: 4,
      generation: 8,
    );

    expect(reaction.blocks(generation: 8, priority: 1), isTrue);
    expect(reaction.blocks(generation: 8, priority: 5), isFalse);
    expect(
      reaction.blocks(generation: 9, priority: 1),
      isFalse,
      reason: 'A finale from the prior hand cannot suppress the next hand.',
    );
  });

  test('finale mood projects big hand, Heat clear and failed final play', () {
    expect(
      slyFinaleMood(
        handMood: SlyMood.fullHouse,
        handsLeftBeforePlay: 3,
        stageScoreBeforePlay: 20,
        handTotal: 50,
        target: 100,
      ),
      SlyMood.fullHouse,
    );
    expect(slyQuips[SlyMood.fullHouse]!.expression, SlyExpression.shocked);

    expect(
      slyFinaleMood(
        handMood: SlyMood.pair,
        handsLeftBeforePlay: 2,
        stageScoreBeforePlay: 75,
        handTotal: 25,
        target: 100,
      ),
      SlyMood.clear,
    );
    expect(slyQuips[SlyMood.clear]!.expression, SlyExpression.triumphant);

    expect(
      slyFinaleMood(
        handMood: SlyMood.highCard,
        handsLeftBeforePlay: 1,
        stageScoreBeforePlay: 40,
        handTotal: 10,
        target: 100,
      ),
      SlyMood.heatFail,
    );
    expect(slyQuips[SlyMood.heatFail]!.expression, SlyExpression.laughing);
  });

  test('expression atlas mapping is explicit and complete', () {
    expect({
      for (final expression in SlyExpression.values)
        slyExpressionFrameIndex(expression),
    }, hasLength(SlyExpression.values.length));
    expect(slyExpressionFrameIndex(SlyExpression.shocked), 5);
    expect(slyExpressionFrameIndex(SlyExpression.triumphant), 7);
    expect(slyExpressionFrameIndex(SlyExpression.disappointed), 8);
  });
}
