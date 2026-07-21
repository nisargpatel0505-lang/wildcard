import 'dart:convert';

import '../core/app_constants.dart';
import '../core/daily_utc_date.dart';
import 'local_save_repository.dart';

class PendingDailyScore {
  const PendingDailyScore({
    required this.ownerUid,
    required this.date,
    required this.name,
    required this.score,
    required this.claimId,
    required this.queuedAt,
  });

  final String ownerUid;
  final String date;
  final String name;
  final int score;
  final String claimId;
  final int queuedAt;

  String get localIdentity => '$ownerUid\u0000$claimId';

  bool get isValid =>
      ownerUid.isNotEmpty &&
      ownerUid.length <= 128 &&
      isCalendarDateKey(date) &&
      RegExp(r'^[A-Z0-9]{1,8}$').hasMatch(name) &&
      score > 0 &&
      score <= 10000000 &&
      claimId.trim() == claimId &&
      claimId.isNotEmpty &&
      claimId.length <= 96 &&
      queuedAt >= 0 &&
      queuedAt <= 9999999999999;

  Map<String, Object> toJson() => <String, Object>{
    'ownerUid': ownerUid,
    'date': date,
    'name': name,
    'score': score,
    'claimId': claimId,
    'queuedAt': queuedAt,
  };

  factory PendingDailyScore.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.floor();
      return int.tryParse('${value ?? ''}') ?? -1;
    }

    return PendingDailyScore(
      ownerUid: json['ownerUid']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      score: asInt(json['score']),
      claimId: json['claimId']?.toString() ?? '',
      queuedAt: asInt(json['queuedAt']),
    );
  }
}

class DailyScoreRetryResult {
  const DailyScoreRetryResult({
    required this.submitted,
    required this.remaining,
    required this.droppedStale,
  });

  final int submitted;
  final int remaining;
  final int droppedStale;
}

/// A tiny durable outbox for authenticated Daily Board posts.
///
/// Firebase and the Pi both deduplicate with the hash of [claimId]. If the app
/// dies after the server commits but before this outbox removes the row, replay
/// sends the exact same owner/name/score/claim tuple and is therefore harmless.
class DailyScoreOutbox {
  DailyScoreOutbox(this._local);

  static const storageKey = AppConstants.dailyScoreOutboxKey;
  static const maxPending = 16;

  final LocalSaveRepository _local;

  List<PendingDailyScore> readPending() {
    final raw = _local.readString(storageKey);
    if (raw == null || raw.isEmpty) return <PendingDailyScore>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <PendingDailyScore>[];
      return decoded
          .whereType<Map>()
          .map(
            (value) =>
                PendingDailyScore.fromJson(Map<String, dynamic>.from(value)),
          )
          .where((entry) => entry.isValid)
          .take(maxPending)
          .toList(growable: true);
    } on FormatException {
      return <PendingDailyScore>[];
    }
  }

  Future<void> enqueue(PendingDailyScore submission) async {
    if (!submission.isValid) {
      throw const FormatException('Invalid pending Daily score');
    }
    final entries = readPending();
    final existing = entries.indexWhere(
      (entry) => entry.localIdentity == submission.localIdentity,
    );
    if (existing >= 0) {
      // Never replace the payload behind an idempotency key. A retry must use
      // exactly the same data as a request that may already exist server-side.
      return;
    }
    entries.add(submission);
    entries.sort((left, right) => left.queuedAt.compareTo(right.queuedAt));
    if (entries.length > maxPending) {
      entries.removeRange(0, entries.length - maxPending);
    }
    await _write(entries);
  }

  Future<DailyScoreRetryResult> retry({
    required String ownerUid,
    required String utcDate,
    required Future<void> Function(PendingDailyScore submission) submit,
  }) async {
    if (ownerUid.isEmpty || !isCalendarDateKey(utcDate)) {
      return DailyScoreRetryResult(
        submitted: 0,
        remaining: readPending().length,
        droppedStale: 0,
      );
    }

    var entries = readPending();
    final beforePrune = entries.length;
    // The callable assigns a board day using its server clock. If a request was
    // wholly offline until after UTC midnight, posting it now would contaminate
    // the next challenge. Drop only stale rows belonging to this account; rows
    // for another signed-out account remain safely scoped to that owner.
    entries = entries
        .where((entry) => entry.ownerUid != ownerUid || entry.date == utcDate)
        .toList(growable: true);
    final droppedStale = beforePrune - entries.length;
    if (droppedStale > 0) await _write(entries);

    var submitted = 0;
    for (final entry in List<PendingDailyScore>.from(entries)) {
      if (entry.ownerUid != ownerUid || entry.date != utcDate) continue;
      try {
        await submit(entry);
      } catch (_) {
        // Stop after the first network/auth failure rather than hammering a
        // recovering service. Connectivity or the next launch retries it.
        break;
      }
      entries.removeWhere(
        (candidate) => candidate.localIdentity == entry.localIdentity,
      );
      submitted += 1;
      // Persist after each acknowledgement. A process kill can replay at most
      // one already-committed idempotent request.
      await _write(entries);
    }

    return DailyScoreRetryResult(
      submitted: submitted,
      remaining: entries.length,
      droppedStale: droppedStale,
    );
  }

  Future<void> clear() => _local.remove(storageKey);

  Future<void> _write(List<PendingDailyScore> entries) => _local.writeString(
    storageKey,
    entries.isEmpty
        ? null
        : jsonEncode(entries.map((entry) => entry.toJson()).toList()),
  );
}
