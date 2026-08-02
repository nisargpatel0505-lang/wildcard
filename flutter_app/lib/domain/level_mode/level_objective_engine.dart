import 'dart:math' as math;

import '../game_rules.dart';
import 'level_definition.dart';

/// Durable progress for one authored Level objective.
///
/// This engine deliberately knows nothing about dealing or scoring formulas;
/// it consumes the real native [HandType] and committed score produced by the
/// existing scoring engine.
class LevelObjectiveProgress {
  LevelObjectiveProgress({
    Map<HandType, int>? handCounts,
    List<HandType>? handHistory,
    this.totalScore = 0,
    this.sequenceIndex = 0,
    this.sequenceViolated = false,
    this.forbiddenViolated = false,
    this.checkpointViolated = false,
  }) : handCounts = Map<HandType, int>.from(
         handCounts ?? const <HandType, int>{},
       ),
       handHistory = List<HandType>.from(handHistory ?? const <HandType>[]);

  final Map<HandType, int> handCounts;
  final List<HandType> handHistory;
  int totalScore;
  int sequenceIndex;
  bool sequenceViolated;
  bool forbiddenViolated;
  bool checkpointViolated;

  int get scoringHandsPlayed => handHistory.length;
  Set<HandType> get distinctHandTypes => handCounts.keys.toSet();

  /// Records one committed scoring result exactly once.
  void record({
    required LevelObjective objective,
    required HandType handType,
    required int score,
  }) {
    final safeScore = math.max(0, score);
    handHistory.add(handType);
    handCounts[handType] = (handCounts[handType] ?? 0) + 1;
    totalScore += safeScore;

    if (objective.forbiddenTypes.contains(handType)) {
      forbiddenViolated = true;
    }

    if (sequenceIndex < objective.requiredSequence.length) {
      if (handType == objective.requiredSequence[sequenceIndex]) {
        sequenceIndex++;
      } else {
        // Sequence objectives are exact. A wrong scoring hand before the
        // authored order is complete cannot be repaired by later hands.
        sequenceViolated = true;
      }
    }

    final checkpointIndex = handHistory.length - 1;
    if (checkpointIndex < objective.checkpoints.length &&
        totalScore < objective.checkpoints[checkpointIndex]) {
      checkpointViolated = true;
    }
  }

  bool isComplete(LevelObjective objective, {required int dynamicTarget}) {
    if (sequenceViolated || forbiddenViolated || checkpointViolated) {
      return false;
    }
    if (math.max(objective.targetScore, dynamicTarget) > totalScore) {
      return false;
    }
    for (final entry in objective.requiredCounts.entries) {
      if ((handCounts[entry.key] ?? 0) < entry.value) return false;
    }
    if (sequenceIndex < objective.requiredSequence.length) return false;
    if (distinctHandTypes.length < objective.minVariety) return false;

    final qualityCount = handHistory
        .where((type) => type.index >= objective.minQuality.index)
        .length;
    if (qualityCount < objective.minQualityCount) return false;

    final fromCount = distinctHandTypes
        .where(objective.minTypesFrom.contains)
        .length;
    if (fromCount < objective.minTypesFromCount) return false;

    // Every authored checkpoint is tied to the cumulative score after the
    // corresponding scoring hand. A route with too few hands has not met it.
    if (handHistory.length < objective.checkpoints.length) return false;
    return true;
  }

  String progressText(LevelObjective objective, {required int dynamicTarget}) {
    final parts = <String>[];
    if (objective.requiredSequence.isNotEmpty) {
      parts.add(
        objective.requiredSequence.indexed
            .map(
              (entry) => entry.$1 < sequenceIndex
                  ? '${entry.$2.legacyName.toUpperCase()} ✓'
                  : entry.$2.legacyName.toUpperCase(),
            )
            .join(' → '),
      );
    } else if (objective.requiredCounts.isNotEmpty) {
      parts.add(
        objective.requiredCounts.entries
            .map(
              (entry) =>
                  '${entry.key.legacyName.toUpperCase()} '
                  '${math.min(handCounts[entry.key] ?? 0, entry.value)}/${entry.value}',
            )
            .join(' · '),
      );
    }
    if (objective.minVariety > 0) {
      parts.add(
        'VARIETY ${math.min(distinctHandTypes.length, objective.minVariety)}/${objective.minVariety}',
      );
    }
    if (objective.minQualityCount > 0) {
      final value = handHistory
          .where((type) => type.index >= objective.minQuality.index)
          .length;
      parts.add(
        '${objective.minQuality.legacyName.toUpperCase()}+ '
        '${math.min(value, objective.minQualityCount)}/${objective.minQualityCount}',
      );
    }
    if (objective.minTypesFromCount > 0) {
      final value = distinctHandTypes
          .where(objective.minTypesFrom.contains)
          .length;
      parts.add(
        'QUALIFYING TYPES '
        '${math.min(value, objective.minTypesFromCount)}/${objective.minTypesFromCount}',
      );
    }
    if (objective.checkpoints.isNotEmpty) {
      final index = handHistory.length.clamp(
        0,
        objective.checkpoints.length - 1,
      );
      final target = objective.checkpoints[index];
      parts.add('CHECKPOINT $totalScore / $target');
    }
    final scoreTarget = math.max(objective.targetScore, dynamicTarget);
    if (scoreTarget > 0) parts.add('SCORE $totalScore / $scoreTarget');
    if (forbiddenViolated) parts.add('FORBIDDEN HAND PLAYED');
    if (sequenceViolated) parts.add('ORDER BROKEN');
    if (checkpointViolated) parts.add('CHECKPOINT MISSED');
    return parts.isEmpty ? 'CLEAR THE TABLE' : parts.join('\n');
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'handCounts': <String, int>{
      for (final entry in handCounts.entries) entry.key.legacyName: entry.value,
    },
    'handHistory': handHistory.map((type) => type.legacyName).toList(),
    'totalScore': totalScore,
    'sequenceIndex': sequenceIndex,
    'sequenceViolated': sequenceViolated,
    'forbiddenViolated': forbiddenViolated,
    'checkpointViolated': checkpointViolated,
  };

  factory LevelObjectiveProgress.fromJson(Object? value) {
    if (value is! Map) return LevelObjectiveProgress();
    final counts = <HandType, int>{};
    final rawCounts = value['handCounts'];
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        final type = _tryHandType(entry.key);
        final count = _asInt(entry.value);
        if (type != null && count > 0) counts[type] = count;
      }
    }
    final history = <HandType>[];
    final rawHistory = value['handHistory'];
    if (rawHistory is List) {
      for (final raw in rawHistory) {
        final type = _tryHandType(raw);
        if (type != null) history.add(type);
      }
    }
    return LevelObjectiveProgress(
      handCounts: counts,
      handHistory: history,
      totalScore: math.max(0, _asInt(value['totalScore'])),
      sequenceIndex: math.max(0, _asInt(value['sequenceIndex'])),
      sequenceViolated: value['sequenceViolated'] == true,
      forbiddenViolated: value['forbiddenViolated'] == true,
      checkpointViolated: value['checkpointViolated'] == true,
    );
  }
}

HandType? _tryHandType(Object? raw) {
  try {
    return HandType.fromLegacy(raw?.toString() ?? '');
  } on FormatException {
    return null;
  }
}

int _asInt(Object? value) => switch (value) {
  int number => number,
  num number => number.floor(),
  _ => int.tryParse(value?.toString() ?? '') ?? 0,
};
