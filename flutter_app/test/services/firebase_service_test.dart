import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/services/firebase_service.dart';

void main() {
  test('Daily submission claim IDs become deterministic backend-safe keys', () {
    const claim = '1784665706112-7fffffff:finished';
    final first = FirebaseService.dailySubmissionKey(claim);
    final retry = FirebaseService.dailySubmissionKey(claim);

    expect(first, retry);
    expect(first, hasLength(64));
    expect(RegExp(r'^[A-Za-z0-9_-]{16,80}$').hasMatch(first), isTrue);
    expect(first, isNot(contains(':')));
  });

  test('Daily submission rejects an empty or oversized local claim', () {
    expect(() => FirebaseService.dailySubmissionKey(''), throwsFormatException);
    expect(
      () => FirebaseService.dailySubmissionKey('x' * 97),
      throwsFormatException,
    );
  });

  test('Daily submission rejects a score above the protected board cap', () {
    final service = FirebaseService();
    addTearDown(service.dispose);
    expect(
      () => service.submitDailyScore(
        name: 'NIS',
        score: 10000001,
        idempotencyKey: 'daily-run:finished',
      ),
      throwsFormatException,
    );
  });
}
