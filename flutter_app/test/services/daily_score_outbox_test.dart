import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildcard/services/daily_score_outbox.dart';
import 'package:wildcard/services/local_save_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  PendingDailyScore score({
    String owner = 'firebase-user-a',
    String date = '2026-07-21',
    String name = 'NIS',
    int value = 4671,
    String claim = 'daily-run-a:finished',
    int queuedAt = 1000,
  }) => PendingDailyScore(
    ownerUid: owner,
    date: date,
    name: name,
    score: value,
    claimId: claim,
    queuedAt: queuedAt,
  );

  test(
    'failed post survives restart and successful replay is removed',
    () async {
      final firstRepository = await LocalSaveRepository.open();
      final firstOutbox = DailyScoreOutbox(firstRepository);
      await firstOutbox.enqueue(score());

      // Reusing a claim with different data cannot mutate the possibly committed
      // server request behind that idempotency key.
      await firstOutbox.enqueue(score(name: 'OTHER', value: 9999));
      expect(firstOutbox.readPending(), hasLength(1));
      expect(firstOutbox.readPending().single.name, 'NIS');
      expect(firstOutbox.readPending().single.score, 4671);

      final restartedRepository = await LocalSaveRepository.open();
      final restartedOutbox = DailyScoreOutbox(restartedRepository);
      var attempts = 0;
      final failed = await restartedOutbox.retry(
        ownerUid: 'firebase-user-a',
        utcDate: '2026-07-21',
        submit: (_) async {
          attempts += 1;
          throw StateError('offline');
        },
      );
      expect(failed.submitted, 0);
      expect(failed.remaining, 1);
      expect(restartedOutbox.readPending(), hasLength(1));

      final replayed = <PendingDailyScore>[];
      final recovered = await restartedOutbox.retry(
        ownerUid: 'firebase-user-a',
        utcDate: '2026-07-21',
        submit: (submission) async {
          attempts += 1;
          replayed.add(submission);
        },
      );
      expect(attempts, 2);
      expect(replayed.single.claimId, 'daily-run-a:finished');
      expect(recovered.submitted, 1);
      expect(recovered.remaining, 0);
      expect(restartedOutbox.readPending(), isEmpty);

      await restartedOutbox.retry(
        ownerUid: 'firebase-user-a',
        utcDate: '2026-07-21',
        submit: (_) async => attempts += 1,
      );
      expect(attempts, 2);
    },
  );

  test(
    'retry is account scoped and never moves a stale score to a new day',
    () async {
      final outbox = DailyScoreOutbox(await LocalSaveRepository.open());
      await outbox.enqueue(score());
      await outbox.enqueue(
        score(
          owner: 'firebase-user-a',
          date: '2026-07-20',
          claim: 'stale-run:finished',
          queuedAt: 900,
        ),
      );
      await outbox.enqueue(
        score(
          owner: 'firebase-user-b',
          claim: 'other-account:finished',
          queuedAt: 1100,
        ),
      );

      final posted = <String>[];
      final result = await outbox.retry(
        ownerUid: 'firebase-user-a',
        utcDate: '2026-07-21',
        submit: (submission) async => posted.add(submission.claimId),
      );

      expect(posted, <String>['daily-run-a:finished']);
      expect(result.submitted, 1);
      expect(result.droppedStale, 1);
      expect(outbox.readPending().single.ownerUid, 'firebase-user-b');
    },
  );

  test('outbox storage is bounded to the newest sixteen claims', () async {
    final outbox = DailyScoreOutbox(await LocalSaveRepository.open());
    for (var index = 0; index < 20; index++) {
      await outbox.enqueue(
        score(claim: 'daily-$index:finished', queuedAt: index),
      );
    }

    final pending = outbox.readPending();
    expect(pending, hasLength(DailyScoreOutbox.maxPending));
    expect(pending.first.claimId, 'daily-4:finished');
    expect(pending.last.claimId, 'daily-19:finished');
  });
}
