import 'dart:convert';
import 'dart:math' as math;

import '../cards.dart';
import '../game_rules.dart';
import '../scoring_engine.dart';
import 'level_definition.dart';
import 'level_objective_engine.dart';

/// Deterministic native policies. Both call [WildcardScoringEngine] for every
/// candidate; neither contains a second scoring formula.
enum LevelSimulationPolicy { handRanking, adaptivePlanning }

enum LevelSimulationOutcome { cleared, failed, routeExhausted, invalid }

sealed class LevelSimulationAction {
  const LevelSimulationAction(this.cardCodes);

  final List<String> cardCodes;
}

class LevelPlayAction extends LevelSimulationAction {
  LevelPlayAction(
    Iterable<String> cardCodes, {
    this.expectedHandType,
    this.expectedScore,
    this.expectedCumulativeScore,
  }) : super(List<String>.unmodifiable(cardCodes));

  final HandType? expectedHandType;
  final int? expectedScore;
  final int? expectedCumulativeScore;
}

class LevelDiscardAction extends LevelSimulationAction {
  LevelDiscardAction(Iterable<String> cardCodes)
    : super(List<String>.unmodifiable(cardCodes));
}

class LevelSimulationPlayRecord {
  const LevelSimulationPlayRecord({
    required this.playNumber,
    required this.cardCodes,
    required this.handType,
    required this.score,
    required this.cumulativeScore,
  });

  final int playNumber;
  final List<String> cardCodes;
  final HandType handType;
  final int score;
  final int cumulativeScore;
}

class LevelSimulationResult {
  LevelSimulationResult({
    required this.levelId,
    required this.layoutId,
    required this.policyId,
    required this.outcome,
    required this.totalScore,
    required this.dynamicTarget,
    required this.handsPlayed,
    required this.discardsUsed,
    required this.objectiveComplete,
    required List<LevelSimulationPlayRecord> plays,
    required List<String> validationErrors,
  }) : plays = List<LevelSimulationPlayRecord>.unmodifiable(plays),
       validationErrors = List<String>.unmodifiable(validationErrors);

  final int levelId;
  final String layoutId;
  final String policyId;
  final LevelSimulationOutcome outcome;
  final int totalScore;
  final int dynamicTarget;
  final int handsPlayed;
  final int discardsUsed;
  final bool objectiveComplete;
  final List<LevelSimulationPlayRecord> plays;
  final List<String> validationErrors;

  bool get cleared => outcome == LevelSimulationOutcome.cleared;
  bool get valid => validationErrors.isEmpty;
}

/// One authored route from the optional development-only solver artifact.
class LevelSolverRoute {
  LevelSolverRoute({
    required this.levelId,
    required this.layoutId,
    required Iterable<String> selectedJokerIds,
    required Iterable<LevelSimulationAction> actions,
    this.expectedCleared = true,
  }) : selectedJokerIds = List<String>.unmodifiable(selectedJokerIds),
       actions = List<LevelSimulationAction>.unmodifiable(actions);

  final int levelId;
  final String layoutId;
  final List<String> selectedJokerIds;
  final List<LevelSimulationAction> actions;
  final bool expectedCleared;

  factory LevelSolverRoute.fromJson(
    Map<String, Object?> json, {
    required String path,
  }) {
    final levelId = _requiredInt(
      json['levelId'] ?? json['level_id'],
      '$path.levelId',
    );
    final layoutId = _requiredString(
      json['layoutId'] ?? json['layout_id'],
      '$path.layoutId',
    );
    final jokerSource =
        json['selectedJokerIds'] ??
        json['selectedJokers'] ??
        json['jokerIds'] ??
        const <Object?>[];
    final actionsSource = json['actions'] ?? json['steps'];
    if (actionsSource is! List || actionsSource.isEmpty) {
      throw FormatException('$path.actions must be a non-empty array');
    }
    return LevelSolverRoute(
      levelId: levelId,
      layoutId: layoutId,
      selectedJokerIds: _stringList(jokerSource, '$path.selectedJokerIds'),
      actions: actionsSource.indexed.map((entry) {
        final actionPath = '$path.actions[${entry.$1}]';
        final raw = _objectMap(entry.$2, actionPath);
        final type = _requiredString(
          raw['type'] ?? raw['action'],
          '$actionPath.type',
        ).toLowerCase();
        final cards = _stringList(
          raw['cards'] ?? raw['cardCodes'],
          '$actionPath.cards',
        );
        return switch (type) {
          'play' => LevelPlayAction(
            cards,
            expectedHandType: _requiredHandType(
              raw['expectedHandType'] ?? raw['handType'],
              '$actionPath.expectedHandType',
            ),
            expectedScore: _requiredInt(
              raw['expectedScore'] ?? raw['score'],
              '$actionPath.expectedScore',
            ),
            expectedCumulativeScore: _requiredInt(
              raw['expectedCumulativeScore'] ?? raw['cumulativeScore'],
              '$actionPath.expectedCumulativeScore',
            ),
          ),
          'discard' => LevelDiscardAction(cards),
          _ => throw FormatException('$actionPath.type is not play/discard'),
        };
      }),
      expectedCleared: json['expectedCleared'] is bool
          ? json['expectedCleared']! as bool
          : true,
    );
  }
}

class LevelSolverRouteBundle {
  LevelSolverRouteBundle(Iterable<LevelSolverRoute> routes)
    : routes = List<LevelSolverRoute>.unmodifiable(routes) {
    if (this.routes.isEmpty) {
      throw const FormatException('Solver route artifact contains no routes');
    }
  }

  final List<LevelSolverRoute> routes;

  factory LevelSolverRouteBundle.fromJsonString(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Invalid solver route JSON: ${error.message}');
    }
    final List<Object?> rawRoutes;
    if (decoded is List) {
      rawRoutes = List<Object?>.from(decoded);
    } else if (decoded is Map) {
      final root = _objectMap(decoded, r'$');
      final value = root['routes'] ?? root['solverRoutes'];
      if (value is! List) {
        throw const FormatException(
          r'$.routes must be present in the solver artifact',
        );
      }
      rawRoutes = List<Object?>.from(value);
    } else {
      throw const FormatException('Solver route root must be an object/list');
    }
    return LevelSolverRouteBundle(
      rawRoutes.indexed.map(
        (entry) => LevelSolverRoute.fromJson(
          _objectMap(entry.$2, '\$.routes[${entry.$1}]'),
          path: '\$.routes[${entry.$1}]',
        ),
      ),
    );
  }
}

class LevelSolverReplayReport {
  LevelSolverReplayReport._({
    required this.artifactAvailable,
    required this.unavailableReason,
    required this.routesSupplied,
    required this.routesPassed,
    required List<LevelSimulationResult> results,
    required Set<String> successfulLayoutKeys,
    required Set<String> missingLayoutKeys,
  }) : results = List<LevelSimulationResult>.unmodifiable(results),
       successfulLayoutKeys = Set<String>.unmodifiable(successfulLayoutKeys),
       missingLayoutKeys = Set<String>.unmodifiable(missingLayoutKeys);

  factory LevelSolverReplayReport.unavailable(String reason) =>
      LevelSolverReplayReport._(
        artifactAvailable: false,
        unavailableReason: reason,
        routesSupplied: 0,
        routesPassed: 0,
        results: const <LevelSimulationResult>[],
        successfulLayoutKeys: const <String>{},
        missingLayoutKeys: const <String>{},
      );

  final bool artifactAvailable;
  final String? unavailableReason;
  final int routesSupplied;
  final int routesPassed;
  final List<LevelSimulationResult> results;
  final Set<String> successfulLayoutKeys;
  final Set<String> missingLayoutKeys;

  bool get allRoutesPassed =>
      artifactAvailable &&
      routesSupplied > 0 &&
      routesPassed == routesSupplied &&
      missingLayoutKeys.isEmpty;
}

class LevelPolicyBatchReport {
  LevelPolicyBatchReport(Iterable<LevelSimulationResult> results)
    : results = List<LevelSimulationResult>.unmodifiable(results);

  final List<LevelSimulationResult> results;

  int get attempts => results.length;
  int get clears => results.where((result) => result.cleared).length;
  double get clearRate => attempts == 0 ? 0 : clears / attempts;
  List<String> get layoutFailures => <String>[
    for (final result in results)
      if (!result.cleared) result.layoutId,
  ];

  Set<String> get uniqueLayoutFailures => Set<String>.unmodifiable(
    results.where((result) => !result.cleared).map((result) => result.layoutId),
  );

  int get medianScore {
    if (results.isEmpty) return 0;
    final scores = results.map((result) => result.totalScore).toList()..sort();
    final middle = scores.length ~/ 2;
    return scores.length.isOdd
        ? scores[middle]
        : ((scores[middle - 1] + scores[middle]) / 2).round();
  }
}

/// One policy attempt paired with the catalog-authored loadout used by the
/// harness. This is validation metadata only; production never auto-selects a
/// player's Jokers.
class LevelPolicyAttempt {
  LevelPolicyAttempt({
    required this.result,
    required Iterable<String> recommendedLoadoutJokerIds,
  }) : recommendedLoadoutJokerIds = List<String>.unmodifiable(
         recommendedLoadoutJokerIds,
       );

  final LevelSimulationResult result;
  final List<String> recommendedLoadoutJokerIds;
}

class LevelRecommendedLoadoutFrequency {
  LevelRecommendedLoadoutFrequency({
    required Iterable<String> jokerIds,
    required this.layoutCount,
    required this.attempts,
  }) : jokerIds = List<String>.unmodifiable(jokerIds);

  final List<String> jokerIds;
  final int layoutCount;
  final int attempts;

  Map<String, Object?> toJson() => <String, Object?>{
    'jokerIds': jokerIds,
    'layoutCount': layoutCount,
    'attempts': attempts,
  };
}

class LevelCampaignPolicyLevelReport {
  LevelCampaignPolicyLevelReport._({
    required this.levelId,
    required this.levelName,
    required this.chapter,
    required this.targetSuccess,
    required this.shippingLayoutCount,
    required this.attemptedLayoutCount,
    required _LevelPolicyMetrics metrics,
  }) : attempts = metrics.attempts,
       clears = metrics.clears,
       clearRate = metrics.clearRate,
       medianScore = metrics.medianScore,
       uniqueLayoutFailures = metrics.uniqueLayoutFailures,
       recommendedLoadoutFrequency = metrics.recommendedLoadoutFrequency;

  final int levelId;
  final String levelName;
  final String chapter;
  final double targetSuccess;
  final int shippingLayoutCount;
  final int attemptedLayoutCount;
  final int attempts;
  final int clears;
  final double clearRate;
  final int medianScore;
  final Set<String> uniqueLayoutFailures;
  final List<LevelRecommendedLoadoutFrequency> recommendedLoadoutFrequency;

  Map<String, Object?> toJson() => <String, Object?>{
    'levelId': levelId,
    'levelName': levelName,
    'chapter': chapter,
    'targetSuccess': targetSuccess,
    'shippingLayoutCount': shippingLayoutCount,
    'attemptedLayoutCount': attemptedLayoutCount,
    'attempts': attempts,
    'clears': clears,
    'clearRate': clearRate,
    'medianScore': medianScore,
    'uniqueLayoutFailures': uniqueLayoutFailures.toList()..sort(),
    'recommendedLoadoutFrequency': recommendedLoadoutFrequency
        .map((frequency) => frequency.toJson())
        .toList(growable: false),
  };
}

class LevelCampaignPolicyChapterReport {
  LevelCampaignPolicyChapterReport._({
    required this.chapter,
    required this.levelIds,
    required _LevelPolicyMetrics metrics,
  }) : attempts = metrics.attempts,
       clears = metrics.clears,
       clearRate = metrics.clearRate,
       medianScore = metrics.medianScore,
       uniqueLayoutFailures = metrics.uniqueLayoutFailures,
       recommendedLoadoutFrequency = metrics.recommendedLoadoutFrequency;

  final String chapter;
  final List<int> levelIds;
  final int attempts;
  final int clears;
  final double clearRate;
  final int medianScore;
  final Set<String> uniqueLayoutFailures;
  final List<LevelRecommendedLoadoutFrequency> recommendedLoadoutFrequency;

  Map<String, Object?> toJson() => <String, Object?>{
    'chapter': chapter,
    'levelIds': levelIds,
    'attempts': attempts,
    'clears': clears,
    'clearRate': clearRate,
    'medianScore': medianScore,
    'uniqueLayoutFailures': uniqueLayoutFailures.toList()..sort(),
    'recommendedLoadoutFrequency': recommendedLoadoutFrequency
        .map((frequency) => frequency.toJson())
        .toList(growable: false),
  };
}

/// Structured campaign evidence from deterministic competent policies.
class LevelCampaignPolicyReport {
  LevelCampaignPolicyReport._({
    required Iterable<LevelSimulationPolicy> policies,
    required Iterable<LevelPolicyAttempt> policyAttempts,
    required Iterable<LevelCampaignPolicyLevelReport> levels,
    required Iterable<LevelCampaignPolicyChapterReport> chapters,
  }) : policies = List<LevelSimulationPolicy>.unmodifiable(policies),
       policyAttempts = List<LevelPolicyAttempt>.unmodifiable(policyAttempts),
       levels = List<LevelCampaignPolicyLevelReport>.unmodifiable(levels),
       chapters = List<LevelCampaignPolicyChapterReport>.unmodifiable(
         chapters,
       ) {
    final metrics = _LevelPolicyMetrics.fromAttempts(
      this.policyAttempts,
      qualifyLayoutIds: true,
    );
    attempts = metrics.attempts;
    clears = metrics.clears;
    clearRate = metrics.clearRate;
    medianScore = metrics.medianScore;
    uniqueLayoutFailures = metrics.uniqueLayoutFailures;
    recommendedLoadoutFrequency = metrics.recommendedLoadoutFrequency;
  }

  final List<LevelSimulationPolicy> policies;
  final List<LevelPolicyAttempt> policyAttempts;
  final List<LevelCampaignPolicyLevelReport> levels;
  final List<LevelCampaignPolicyChapterReport> chapters;
  late final int attempts;
  late final int clears;
  late final double clearRate;
  late final int medianScore;
  late final Set<String> uniqueLayoutFailures;
  late final List<LevelRecommendedLoadoutFrequency> recommendedLoadoutFrequency;

  Map<String, Object?> toJson() => <String, Object?>{
    'policies': policies.map((policy) => policy.name).toList(growable: false),
    'attempts': attempts,
    'clears': clears,
    'clearRate': clearRate,
    'medianScore': medianScore,
    'uniqueLayoutFailures': uniqueLayoutFailures.toList()..sort(),
    'recommendedLoadoutFrequency': recommendedLoadoutFrequency
        .map((frequency) => frequency.toJson())
        .toList(growable: false),
    'chapters': chapters
        .map((chapter) => chapter.toJson())
        .toList(growable: false),
    'levels': levels.map((level) => level.toJson()).toList(growable: false),
  };
}

class _LevelPolicyMetrics {
  _LevelPolicyMetrics._({
    required this.attempts,
    required this.clears,
    required this.clearRate,
    required this.medianScore,
    required this.uniqueLayoutFailures,
    required this.recommendedLoadoutFrequency,
  });

  factory _LevelPolicyMetrics.fromAttempts(
    Iterable<LevelPolicyAttempt> source, {
    required bool qualifyLayoutIds,
  }) {
    final attempts = source.toList(growable: false);
    final scores = attempts.map((attempt) => attempt.result.totalScore).toList()
      ..sort();
    final failures = <String>{};
    final loadouts = <String, _MutableLoadoutFrequency>{};
    for (final attempt in attempts) {
      final result = attempt.result;
      final layoutKey = qualifyLayoutIds
          ? _layoutKey(result.levelId, result.layoutId)
          : result.layoutId;
      if (!result.cleared) failures.add(layoutKey);
      final ids = List<String>.from(attempt.recommendedLoadoutJokerIds)..sort();
      final loadoutKey = ids.join('\u001f');
      final frequency = loadouts.putIfAbsent(
        loadoutKey,
        () => _MutableLoadoutFrequency(ids),
      );
      frequency.attempts++;
      frequency.layoutKeys.add(_layoutKey(result.levelId, result.layoutId));
    }
    final clears = attempts.where((attempt) => attempt.result.cleared).length;
    final frequencies =
        loadouts.values
            .map(
              (frequency) => LevelRecommendedLoadoutFrequency(
                jokerIds: frequency.jokerIds,
                layoutCount: frequency.layoutKeys.length,
                attempts: frequency.attempts,
              ),
            )
            .toList()
          ..sort((left, right) {
            final attempts = right.attempts.compareTo(left.attempts);
            if (attempts != 0) return attempts;
            return left.jokerIds
                .join('\u001f')
                .compareTo(right.jokerIds.join('\u001f'));
          });
    return _LevelPolicyMetrics._(
      attempts: attempts.length,
      clears: clears,
      clearRate: attempts.isEmpty ? 0 : clears / attempts.length,
      medianScore: _median(scores),
      uniqueLayoutFailures: Set<String>.unmodifiable(failures),
      recommendedLoadoutFrequency:
          List<LevelRecommendedLoadoutFrequency>.unmodifiable(frequencies),
    );
  }

  final int attempts;
  final int clears;
  final double clearRate;
  final int medianScore;
  final Set<String> uniqueLayoutFailures;
  final List<LevelRecommendedLoadoutFrequency> recommendedLoadoutFrequency;
}

class _MutableLoadoutFrequency {
  _MutableLoadoutFrequency(this.jokerIds);

  final List<String> jokerIds;
  final Set<String> layoutKeys = <String>{};
  int attempts = 0;
}

/// Native campaign validation runner.
///
/// It owns only deterministic dealing/action orchestration. Poker evaluation,
/// score arithmetic and objective completion remain authoritative in
/// [WildcardScoringEngine] and [LevelObjectiveProgress].
class LevelSimulationHarness {
  const LevelSimulationHarness();

  LevelSimulationResult runRoute({
    required LevelDefinition level,
    required LevelLayout layout,
    required LevelSolverRoute route,
  }) {
    final errors = <String>[];
    if (route.levelId != level.id) {
      errors.add('Route level ${route.levelId} does not match ${level.id}.');
    }
    if (route.layoutId != layout.id) {
      errors.add('Route layout ${route.layoutId} does not match ${layout.id}.');
    }
    late _LevelSimulationSession session;
    try {
      session = _LevelSimulationSession(
        level: level,
        layout: layout,
        selectedJokerIds: route.selectedJokerIds,
      );
    } on Object catch (error) {
      errors.add('Route setup failed: $error');
      return _invalidSetupResult(level, layout, 'solver-route', errors);
    }

    for (var index = 0; index < route.actions.length; index++) {
      if (session.terminal) {
        errors.add('Action ${index + 1} occurs after the attempt ended.');
        break;
      }
      final action = route.actions[index];
      final actionError = session.applyAction(action, actionNumber: index + 1);
      if (actionError != null) {
        errors.add(actionError);
        break;
      }
    }

    if (!session.terminal) {
      errors.add('Route ended before the objective cleared or attempt failed.');
      session.routeExhausted = true;
    }
    if (session.cleared != route.expectedCleared) {
      errors.add(
        'Expected cleared=${route.expectedCleared}, got ${session.cleared}.',
      );
    }
    return session.result('solver-route', externalErrors: errors);
  }

  LevelSimulationResult runPolicy({
    required LevelDefinition level,
    required LevelLayout layout,
    required Iterable<String> selectedJokerIds,
    required LevelSimulationPolicy policy,
  }) {
    late _LevelSimulationSession session;
    try {
      session = _LevelSimulationSession(
        level: level,
        layout: layout,
        selectedJokerIds: selectedJokerIds,
      );
    } on Object catch (error) {
      return _invalidSetupResult(level, layout, policy.name, <String>[
        'Policy setup failed: $error',
      ]);
    }
    var guard = level.rules.hands + level.rules.discards + 4;
    while (!session.terminal && guard-- > 0) {
      final action = session.chooseAction(policy);
      final error = session.applyAction(
        action,
        actionNumber:
            session.progress.scoringHandsPlayed + session.discardsUsed + 1,
      );
      if (error != null) {
        session.validationErrors.add(error);
        break;
      }
    }
    if (!session.terminal) {
      session.validationErrors.add('Policy exhausted its legal-action guard.');
      session.routeExhausted = true;
    }
    return session.result(policy.name);
  }

  LevelPolicyBatchReport runPolicyBatch({
    required LevelDefinition level,
    required Iterable<String> selectedJokerIds,
    Iterable<LevelSimulationPolicy> policies = LevelSimulationPolicy.values,
  }) => LevelPolicyBatchReport(<LevelSimulationResult>[
    for (final layout in level.layouts)
      for (final policy in policies)
        runPolicy(
          level: level,
          layout: layout,
          selectedJokerIds: selectedJokerIds,
          policy: policy,
        ),
  ]);

  /// Resolves the hidden authored recommendation for validation only.
  ///
  /// Production Level Mode must continue requiring the player to make this
  /// choice. The priority is the exact layout recommendation, then the most
  /// frequently authored level recommendation, then catalog option order.
  List<String> recommendedJokerSelectionFor({
    required LevelDefinition level,
    required LevelLayout layout,
  }) {
    if (!level.layouts.any((candidate) => candidate.id == layout.id)) {
      throw ArgumentError.value(
        layout.id,
        'layout',
        'Layout does not belong to Level ${level.id}',
      );
    }
    if (layout.recommendedJokerIds.isNotEmpty) {
      return _selectedChoicesFromLoadout(
        level,
        layout.recommendedJokerIds,
        source: 'layout ${layout.id}',
      );
    }
    if (level.recommendedLoadouts.isNotEmpty) {
      final recommendations =
          List<LevelRecommendedLoadout>.from(level.recommendedLoadouts)
            ..sort((left, right) {
              final frequency = right.layoutCount.compareTo(left.layoutCount);
              if (frequency != 0) return frequency;
              return left.jokerIds
                  .join('\u001f')
                  .compareTo(right.jokerIds.join('\u001f'));
            });
      return _selectedChoicesFromLoadout(
        level,
        recommendations.first.jokerIds,
        source: 'level ${level.id} recommendation',
      );
    }
    final selected = level.jokerOptionIds
        .take(level.chooseJokers)
        .toList(growable: false);
    level.validateJokerSelection(selected);
    return List<String>.unmodifiable(selected);
  }

  /// Runs a bounded, deterministic campaign report using only native scoring
  /// and objective evaluation. Recommended Jokers are selected here solely to
  /// validate campaign balance; this method is not called by production play.
  LevelCampaignPolicyReport runCampaignPolicies({
    required Iterable<LevelDefinition> levels,
    Iterable<LevelSimulationPolicy> policies = LevelSimulationPolicy.values,
    int? maxLevels,
    int? maxLayoutsPerLevel,
  }) {
    if (maxLevels != null && maxLevels <= 0) {
      throw ArgumentError.value(maxLevels, 'maxLevels', 'must be positive');
    }
    if (maxLayoutsPerLevel != null && maxLayoutsPerLevel <= 0) {
      throw ArgumentError.value(
        maxLayoutsPerLevel,
        'maxLayoutsPerLevel',
        'must be positive',
      );
    }
    final policyList = policies.toList(growable: false);
    if (policyList.isEmpty) {
      throw ArgumentError.value(policies, 'policies', 'must not be empty');
    }
    if (policyList.toSet().length != policyList.length) {
      throw ArgumentError.value(policies, 'policies', 'must be unique');
    }
    final sourceLevels = levels.toList(growable: false);
    final selectedLevels = maxLevels == null
        ? sourceLevels
        : sourceLevels.take(maxLevels).toList(growable: false);
    final allAttempts = <LevelPolicyAttempt>[];
    final levelReports = <LevelCampaignPolicyLevelReport>[];
    final chapterAttempts = <String, List<LevelPolicyAttempt>>{};
    final chapterLevelIds = <String, List<int>>{};

    for (final level in selectedLevels) {
      final layouts = maxLayoutsPerLevel == null
          ? level.layouts
          : level.layouts.take(maxLayoutsPerLevel).toList(growable: false);
      final levelAttempts = <LevelPolicyAttempt>[];
      for (final layout in layouts) {
        final selectedJokers = recommendedJokerSelectionFor(
          level: level,
          layout: layout,
        );
        final loadout = level.temporaryJokerIds(selectedJokers);
        for (final policy in policyList) {
          final attempt = LevelPolicyAttempt(
            result: runPolicy(
              level: level,
              layout: layout,
              selectedJokerIds: selectedJokers,
              policy: policy,
            ),
            recommendedLoadoutJokerIds: loadout,
          );
          levelAttempts.add(attempt);
          allAttempts.add(attempt);
          chapterAttempts
              .putIfAbsent(level.chapter, () => <LevelPolicyAttempt>[])
              .add(attempt);
        }
      }
      chapterLevelIds.putIfAbsent(level.chapter, () => <int>[]).add(level.id);
      levelReports.add(
        LevelCampaignPolicyLevelReport._(
          levelId: level.id,
          levelName: level.name,
          chapter: level.chapter,
          targetSuccess: level.targetSuccess,
          shippingLayoutCount: level.layouts.length,
          attemptedLayoutCount: layouts.length,
          metrics: _LevelPolicyMetrics.fromAttempts(
            levelAttempts,
            qualifyLayoutIds: false,
          ),
        ),
      );
    }

    final chapterReports = <LevelCampaignPolicyChapterReport>[
      for (final entry in chapterAttempts.entries)
        LevelCampaignPolicyChapterReport._(
          chapter: entry.key,
          levelIds: List<int>.unmodifiable(chapterLevelIds[entry.key]!),
          metrics: _LevelPolicyMetrics.fromAttempts(
            entry.value,
            qualifyLayoutIds: true,
          ),
        ),
    ];
    return LevelCampaignPolicyReport._(
      policies: policyList,
      policyAttempts: allAttempts,
      levels: levelReports,
      chapters: chapterReports,
    );
  }

  /// Replays only supplied solver evidence. A missing artifact returns an
  /// explicit unavailable report and never substitutes policy simulations.
  LevelSolverReplayReport replaySolverRoutes({
    required Iterable<LevelDefinition> levels,
    String? solverRouteJson,
  }) {
    if (solverRouteJson == null || solverRouteJson.trim().isEmpty) {
      return LevelSolverReplayReport.unavailable(
        'WILDCARD-solver-results-v8.5.2.generated.json was not supplied.',
      );
    }
    final bundle = LevelSolverRouteBundle.fromJsonString(solverRouteJson);
    final levelMap = <int, LevelDefinition>{
      for (final level in levels) level.id: level,
    };
    final shippingLayouts = <String>{
      for (final level in levels)
        for (final layout in level.layouts) _layoutKey(level.id, layout.id),
    };
    final results = <LevelSimulationResult>[];
    final successfulLayouts = <String>{};
    for (final route in bundle.routes) {
      final level = levelMap[route.levelId];
      if (level == null) {
        results.add(
          _invalidUnknownRouteResult(route, 'Unknown level ${route.levelId}.'),
        );
        continue;
      }
      LevelLayout? layout;
      for (final candidate in level.layouts) {
        if (candidate.id == route.layoutId) {
          layout = candidate;
          break;
        }
      }
      if (layout == null) {
        results.add(
          _invalidUnknownRouteResult(
            route,
            'Unknown layout ${route.layoutId} for level ${route.levelId}.',
          ),
        );
        continue;
      }
      final result = runRoute(level: level, layout: layout, route: route);
      results.add(result);
      if (result.valid && result.cleared) {
        successfulLayouts.add(_layoutKey(level.id, layout.id));
      }
    }
    return LevelSolverReplayReport._(
      artifactAvailable: true,
      unavailableReason: null,
      routesSupplied: bundle.routes.length,
      routesPassed: results
          .where((result) => result.valid && result.cleared)
          .length,
      results: results,
      successfulLayoutKeys: successfulLayouts,
      missingLayoutKeys: shippingLayouts.difference(successfulLayouts),
    );
  }
}

class _LevelSimulationSession {
  _LevelSimulationSession({
    required this.level,
    required this.layout,
    required Iterable<String> selectedJokerIds,
  }) : dynamicTarget = level.objective.targetScore,
       state = ScoringState(
         rngSeed: layout.seed,
         stage: level.rules.stage,
         targetOverride: level.objective.targetScore,
         handsPerHeatOverride: level.rules.hands,
         discardsOverride: level.rules.discards,
         handSizeOverride: level.rules.handSize,
         maxSelectOverride: level.rules.maxSelect,
         handsLeft: level.rules.hands,
         discardsLeft: level.rules.discards,
         runCoins: level.rules.runCoins,
         stagesCleared: level.rules.heatsCleared,
         destroyedCount: level.rules.destroyed,
         copiedCount: level.rules.copied,
         cards: layout.deckOrder,
         handLevels: Map<HandType, int>.from(level.rules.handLevels),
         jokerIds: level.temporaryJokerIds(selectedJokerIds),
         legacyJokerEffects: true,
         modifierStack: <HeatModifier>[
           if (level.rules.nullField) HeatModifier.nullField,
           if (level.rules.deadAir) HeatModifier.deadAir,
           if (level.rules.bossModifier) HeatModifier.theHouse,
         ],
       ) {
    if (state.jokerIds.length > maxJokers) {
      throw StateError('Level installs more than $maxJokers Jokers.');
    }
    drawPile.addAll(state.cards.reversed);
    _prepareTurnRules();
    _refillHand();
    state.deckCardsLeft = drawPile.length;
  }

  final LevelDefinition level;
  final LevelLayout layout;
  final ScoringState state;
  final LevelObjectiveProgress progress = LevelObjectiveProgress();
  final List<PlayingCard> drawPile = <PlayingCard>[];
  final List<PlayingCard> hand = <PlayingCard>[];
  final Set<String> fadedJokerIds = <String>{};
  final List<LevelSimulationPlayRecord> playRecords =
      <LevelSimulationPlayRecord>[];
  final List<String> validationErrors = <String>[];

  int dynamicTarget;
  int discardsUsed = 0;
  CardSuit? disabledSuit;
  bool cleared = false;
  bool failed = false;
  bool routeExhausted = false;

  bool get terminal => cleared || failed;

  WildcardScoringEngine get engine => WildcardScoringEngine(
    state,
    levelOverride: LevelScoringOverride(
      highCardScoresZero: level.rules.highCardZero,
      allowedHandTypes: level.rules.allowedHandTypes,
      faceRanksScoreZero: level.rules.faceRankZero,
      scoringColor: switch (level.rules.scoreColor) {
        LevelCardColor.red => LevelRankColor.red,
        LevelCardColor.black => LevelRankColor.black,
        null => null,
      },
      redRankFactor: level.rules.colorRankMultipliers[LevelCardColor.red] ?? 1,
      blackRankFactor:
          level.rules.colorRankMultipliers[LevelCardColor.black] ?? 1,
      previousHandCounts: progress.handCounts,
      repeatDecay: level.rules.repeatDecay,
      repeatedHandsScoreZero: level.rules.noRepeat,
      playIndex: progress.scoringHandsPlayed,
      perPlayScoreFactors: level.rules.handScoreMultipliers,
      disabledSuit: disabledSuit,
      hasAuthoredModifier: level.rules.hasModifier,
      authoredModifierCount: level.rules.modifierCount,
    ),
  );

  String? applyAction(
    LevelSimulationAction action, {
    required int actionNumber,
  }) {
    if (terminal) return 'Action $actionNumber is after the attempt ended.';
    final selectionError = _validateSelection(action.cardCodes);
    if (selectionError != null) return 'Action $actionNumber: $selectionError';
    final wanted = action.cardCodes.toSet();
    final selected = hand
        .where((card) {
          return wanted.contains(LevelCardCodec.encode(card));
        })
        .toList(growable: false);
    if (action is LevelDiscardAction) {
      if (state.discardsLeft <= 0) {
        return 'Action $actionNumber: no discards remain.';
      }
      hand.removeWhere(selected.toSet().contains);
      state.discardsLeft--;
      discardsUsed++;
      if (level.rules.discardTargetTax > 0) {
        dynamicTarget += level.rules.discardTargetTax;
        state.targetOverride = dynamicTarget;
      }
      _refillHand();
      state.deckCardsLeft = drawPile.length;
      if (hand.isEmpty) failed = true;
      return null;
    }
    if (action is! LevelPlayAction) {
      return 'Action $actionNumber has an unsupported type.';
    }
    if (state.handsLeft <= 0) {
      return 'Action $actionNumber: no scoring hands remain.';
    }

    final scoringEngine = engine;
    final result = scoringEngine.scoreHand(selected, commit: true);
    state.stageScore += result.total;
    state.handsLeft--;
    state.handsPlayedThisStage++;
    progress.record(
      objective: level.objective,
      handType: result.handType,
      score: result.total,
    );
    _validateExpected(action, result, actionNumber);
    playRecords.add(
      LevelSimulationPlayRecord(
        playNumber: progress.scoringHandsPlayed,
        cardCodes: List<String>.unmodifiable(
          selected.map(LevelCardCodec.encode),
        ),
        handType: result.handType,
        score: result.total,
        cumulativeScore: progress.totalScore,
      ),
    );
    scoringEngine.applyOnScored(result);
    scoringEngine.resolveGlassCardShatters(selected, result.scoringFlags);
    hand.removeWhere(selected.toSet().contains);
    _applyPostScoreRules(selected, result);
    _refillHand();
    state.deckCardsLeft = drawPile.length;

    cleared = progress.isComplete(
      level.objective,
      dynamicTarget: dynamicTarget,
    );
    if (!cleared && (state.handsLeft <= 0 || hand.isEmpty)) failed = true;
    if (!terminal) _prepareTurnRules();
    return null;
  }

  LevelSimulationAction chooseAction(LevelSimulationPolicy policy) {
    final candidates = <_PolicyCandidate>[];
    for (final cards in _cardSelections(hand, state.effectiveMaxSelect)) {
      final score = engine.scoreHand(cards, commit: false);
      candidates.add(
        _PolicyCandidate(
          cards,
          score,
          utility: policy == LevelSimulationPolicy.handRanking
              ? score.total.toDouble()
              : _adaptiveUtility(score),
          advancesObjective: _advancesObjective(score.handType),
        ),
      );
    }
    candidates.sort(_compareCandidates);
    final best = candidates.first;
    if (policy == LevelSimulationPolicy.adaptivePlanning &&
        state.discardsLeft > 0 &&
        drawPile.isNotEmpty &&
        ((_hasUrgentStructuralObjective && !best.advancesObjective) ||
            _bestIsBelowRequiredScorePace(best.score))) {
      final bestCodes = best.cards.map(LevelCardCodec.encode).toSet();
      final replaceable = hand
          .where((card) => !bestCodes.contains(LevelCardCodec.encode(card)))
          .toList(growable: true);
      final discardPool = replaceable.isEmpty
          ? List<PlayingCard>.from(hand)
          : replaceable;
      final discardCount = math.min(
        state.effectiveMaxSelect,
        math.min(discardPool.length, math.max(1, hand.length ~/ 3)),
      );
      discardPool.sort((left, right) {
        final rank = engine
            .cardEffectiveRankForScoring(left)
            .compareTo(engine.cardEffectiveRankForScoring(right));
        if (rank != 0) return rank;
        return LevelCardCodec.encode(
          left,
        ).compareTo(LevelCardCodec.encode(right));
      });
      return LevelDiscardAction(
        discardPool.take(discardCount).map(LevelCardCodec.encode),
      );
    }
    return LevelPlayAction(best.cards.map(LevelCardCodec.encode));
  }

  LevelSimulationResult result(
    String policyId, {
    List<String> externalErrors = const <String>[],
  }) {
    final errors = <String>[...externalErrors, ...validationErrors];
    final outcome = errors.isNotEmpty
        ? LevelSimulationOutcome.invalid
        : cleared
        ? LevelSimulationOutcome.cleared
        : failed
        ? LevelSimulationOutcome.failed
        : LevelSimulationOutcome.routeExhausted;
    return LevelSimulationResult(
      levelId: level.id,
      layoutId: layout.id,
      policyId: policyId,
      outcome: outcome,
      totalScore: progress.totalScore,
      dynamicTarget: dynamicTarget,
      handsPlayed: progress.scoringHandsPlayed,
      discardsUsed: discardsUsed,
      objectiveComplete: progress.isComplete(
        level.objective,
        dynamicTarget: dynamicTarget,
      ),
      plays: playRecords,
      validationErrors: errors,
    );
  }

  String? _validateSelection(List<String> codes) {
    if (codes.isEmpty) return 'selection is empty.';
    if (codes.length > state.effectiveMaxSelect) {
      return 'selection exceeds max ${state.effectiveMaxSelect}.';
    }
    if (codes.toSet().length != codes.length) {
      return 'selection repeats a physical card.';
    }
    final handCodes = hand.map(LevelCardCodec.encode).toSet();
    final missing = codes.where((code) => !handCodes.contains(code)).toList();
    if (missing.isNotEmpty) {
      return 'cards are not in hand: ${missing.join(', ')}.';
    }
    return null;
  }

  void _validateExpected(
    LevelPlayAction action,
    ScoreResult result,
    int actionNumber,
  ) {
    if (action.expectedHandType case final expected?) {
      if (result.handType != expected) {
        validationErrors.add(
          'Action $actionNumber hand type: expected '
          '${expected.legacyName}, got ${result.handType.legacyName}.',
        );
      }
    }
    if (action.expectedScore case final expected?) {
      if (result.total != expected) {
        validationErrors.add(
          'Action $actionNumber score: expected $expected, got ${result.total}.',
        );
      }
    }
    if (action.expectedCumulativeScore case final expected?) {
      if (progress.totalScore != expected) {
        validationErrors.add(
          'Action $actionNumber cumulative score: expected $expected, '
          'got ${progress.totalScore}.',
        );
      }
    }
  }

  void _prepareTurnRules() {
    final playIndex = progress.scoringHandsPlayed;
    final rotation = level.rules.disabledSuitRotation;
    disabledSuit = rotation.isEmpty
        ? null
        : rotation[playIndex % rotation.length];
    state.blockedJokerIds
      ..clear()
      ..addAll(fadedJokerIds);
    if (level.rules.jokerBlackout && state.jokerIds.isNotEmpty) {
      state.blockedJokerIds.add(
        state.jokerIds[playIndex % state.jokerIds.length],
      );
    }
    if (level.rules.rotatingJoker && state.jokerIds.length > 1) {
      final activeIndex = playIndex % state.jokerIds.length;
      for (var index = 0; index < state.jokerIds.length; index++) {
        if (index != activeIndex) {
          state.blockedJokerIds.add(state.jokerIds[index]);
        }
      }
    }
  }

  void _applyPostScoreRules(List<PlayingCard> played, ScoreResult result) {
    if (level.rules.burnPlayedCards || level.rules.burnScoringCards) {
      final burnedCodes = <String>{
        if (level.rules.burnPlayedCards) ...played.map(LevelCardCodec.encode),
        if (level.rules.burnScoringCards)
          for (var index = 0; index < played.length; index++)
            if (result.scoringFlags[index])
              LevelCardCodec.encode(played[index]),
      };
      state.cards.removeWhere(
        (card) => burnedCodes.contains(LevelCardCodec.encode(card)),
      );
    }
    if (level.rules.burnPlayedRanks) {
      final ranks = played.map((card) => card.rank).toSet();
      bool sharesRank(PlayingCard card) => ranks.contains(card.rank);
      hand.removeWhere(sharesRank);
      drawPile.removeWhere(sharesRank);
      state.cards.removeWhere(sharesRank);
    }
    if (level.rules.fadingJokers && state.jokerIds.isNotEmpty) {
      final next = state.jokerIds.firstWhere(
        (id) => !fadedJokerIds.contains(id),
        orElse: () => '',
      );
      if (next.isNotEmpty) fadedJokerIds.add(next);
    }
    if (level.rules.shrinkingDiscards) {
      final allowance = math.max(
        0,
        level.rules.discards - progress.scoringHandsPlayed,
      );
      state.discardsLeft = math.min(state.discardsLeft, allowance);
    }
  }

  void _refillHand() {
    while (hand.length < state.effectiveHandSize && drawPile.isNotEmpty) {
      hand.add(drawPile.removeLast());
    }
    hand.sort((left, right) {
      final rank = right.value.compareTo(left.value);
      if (rank != 0) return rank;
      return left.suit.sortOrder.compareTo(right.suit.sortOrder);
    });
  }

  bool get _hasUrgentStructuralObjective {
    if (progress.sequenceIndex < level.objective.requiredSequence.length) {
      return true;
    }
    if (level.objective.requiredCounts.entries.any(
      (entry) => (progress.handCounts[entry.key] ?? 0) < entry.value,
    )) {
      return true;
    }
    if (progress.distinctHandTypes.length < level.objective.minVariety) {
      return true;
    }
    final qualityCount = progress.handHistory
        .where((type) => type.index >= level.objective.minQuality.index)
        .length;
    if (qualityCount < level.objective.minQualityCount) return true;
    final fromCount = progress.distinctHandTypes
        .where(level.objective.minTypesFrom.contains)
        .length;
    return fromCount < level.objective.minTypesFromCount;
  }

  bool _bestIsBelowRequiredScorePace(ScoreResult best) {
    final handsRemaining = math.max(1, state.handsLeft);
    final nextPlayIndex = progress.scoringHandsPlayed;

    // Checkpoints are hard per-play gates: missing one permanently fails the
    // objective, so a competent policy must redraw when the best legal hand
    // cannot reach the next cumulative checkpoint.
    if (nextPlayIndex < level.objective.checkpoints.length) {
      final checkpointGap = math.max(
        0,
        level.objective.checkpoints[nextPlayIndex] - progress.totalScore,
      );
      if (best.total < checkpointGap) return true;
    }

    // Discarding may itself raise the target. Compare the best legal hand with
    // the average score still required after paying that authored tax.
    final targetAfterDiscard = math.max(
      level.objective.targetScore,
      dynamicTarget + level.rules.discardTargetTax,
    );
    final scoreGap = math.max(0, targetAfterDiscard - progress.totalScore);
    if (scoreGap == 0) return false;
    final requiredPerHand = (scoreGap / handsRemaining).ceil();
    return best.total < requiredPerHand;
  }

  bool _advancesObjective(HandType type) {
    if (level.objective.forbiddenTypes.contains(type)) return false;
    if (progress.sequenceIndex < level.objective.requiredSequence.length) {
      return type == level.objective.requiredSequence[progress.sequenceIndex];
    }
    final required = level.objective.requiredCounts[type];
    if (required != null && (progress.handCounts[type] ?? 0) < required) {
      return true;
    }
    if (progress.distinctHandTypes.length < level.objective.minVariety &&
        !progress.distinctHandTypes.contains(type)) {
      return true;
    }
    final qualityCount = progress.handHistory
        .where((played) => played.index >= level.objective.minQuality.index)
        .length;
    if (qualityCount < level.objective.minQualityCount &&
        type.index >= level.objective.minQuality.index) {
      return true;
    }
    final fromCount = progress.distinctHandTypes
        .where(level.objective.minTypesFrom.contains)
        .length;
    return fromCount < level.objective.minTypesFromCount &&
        level.objective.minTypesFrom.contains(type) &&
        !progress.distinctHandTypes.contains(type);
  }

  double _adaptiveUtility(ScoreResult score) {
    if (level.objective.forbiddenTypes.contains(score.handType)) return -1e12;
    var utility = score.total.toDouble();
    if (_advancesObjective(score.handType)) utility += 1e9;
    if (progress.distinctHandTypes.length < level.objective.minVariety &&
        !progress.distinctHandTypes.contains(score.handType)) {
      utility += 1e5;
    }
    utility += score.handType.index * 100;
    return utility;
  }
}

class _PolicyCandidate {
  const _PolicyCandidate(
    this.cards,
    this.score, {
    required this.utility,
    required this.advancesObjective,
  });

  final List<PlayingCard> cards;
  final ScoreResult score;
  final double utility;
  final bool advancesObjective;
}

int _compareCandidates(_PolicyCandidate left, _PolicyCandidate right) {
  final utility = right.utility.compareTo(left.utility);
  if (utility != 0) return utility;
  final hand = right.score.handType.index.compareTo(left.score.handType.index);
  if (hand != 0) return hand;
  final score = right.score.total.compareTo(left.score.total);
  if (score != 0) return score;
  final leftKey = left.cards.map(LevelCardCodec.encode).join(',');
  final rightKey = right.cards.map(LevelCardCodec.encode).join(',');
  return leftKey.compareTo(rightKey);
}

Iterable<List<PlayingCard>> _cardSelections(
  List<PlayingCard> hand,
  int maxSelect,
) sync* {
  final selected = <PlayingCard>[];
  Iterable<List<PlayingCard>> choose(int start, int wanted) sync* {
    if (selected.length == wanted) {
      yield List<PlayingCard>.unmodifiable(selected);
      return;
    }
    final remaining = wanted - selected.length;
    for (var index = start; index <= hand.length - remaining; index++) {
      selected.add(hand[index]);
      yield* choose(index + 1, wanted);
      selected.removeLast();
    }
  }

  for (var size = 1; size <= math.min(maxSelect, hand.length); size++) {
    yield* choose(0, size);
  }
}

LevelSimulationResult _invalidSetupResult(
  LevelDefinition level,
  LevelLayout layout,
  String policyId,
  List<String> errors,
) => LevelSimulationResult(
  levelId: level.id,
  layoutId: layout.id,
  policyId: policyId,
  outcome: LevelSimulationOutcome.invalid,
  totalScore: 0,
  dynamicTarget: level.objective.targetScore,
  handsPlayed: 0,
  discardsUsed: 0,
  objectiveComplete: false,
  plays: const <LevelSimulationPlayRecord>[],
  validationErrors: errors,
);

LevelSimulationResult _invalidUnknownRouteResult(
  LevelSolverRoute route,
  String error,
) => LevelSimulationResult(
  levelId: route.levelId,
  layoutId: route.layoutId,
  policyId: 'solver-route',
  outcome: LevelSimulationOutcome.invalid,
  totalScore: 0,
  dynamicTarget: 0,
  handsPlayed: 0,
  discardsUsed: 0,
  objectiveComplete: false,
  plays: const <LevelSimulationPlayRecord>[],
  validationErrors: <String>[error],
);

String _layoutKey(int levelId, String layoutId) => '$levelId:$layoutId';

List<String> _selectedChoicesFromLoadout(
  LevelDefinition level,
  Iterable<String> loadout, {
  required String source,
}) {
  final fullLoadout = loadout.toList(growable: false);
  final selected = fullLoadout
      .where(level.jokerOptionIds.contains)
      .toList(growable: false);
  level.validateJokerSelection(selected);
  final expected = level.temporaryJokerIds(selected);
  if (fullLoadout.length != expected.length ||
      !fullLoadout.toSet().containsAll(expected) ||
      !expected.toSet().containsAll(fullLoadout)) {
    throw StateError(
      'The $source loadout does not match Level ${level.id} fixed, selected, '
      'and negative Jokers.',
    );
  }
  return List<String>.unmodifiable(selected);
}

int _median(List<int> sortedValues) {
  if (sortedValues.isEmpty) return 0;
  final middle = sortedValues.length ~/ 2;
  return sortedValues.length.isOdd
      ? sortedValues[middle]
      : ((sortedValues[middle - 1] + sortedValues[middle]) / 2).round();
}

Map<String, Object?> _objectMap(Object? value, String path) {
  if (value is! Map) throw FormatException('$path must be an object');
  return <String, Object?>{
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

String _requiredString(Object? value, String path) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$path must be a non-empty string');
  }
  return value;
}

int _requiredInt(Object? value, String path) {
  if (value is! int) throw FormatException('$path must be an integer');
  return value;
}

HandType _requiredHandType(Object? value, String path) {
  try {
    return HandType.fromLegacy(_requiredString(value, path));
  } on FormatException {
    throw FormatException('$path contains an unknown hand type');
  }
}

List<String> _stringList(Object? value, String path) {
  if (value is! List) throw FormatException('$path must be an array');
  return List<String>.unmodifiable(
    value.indexed.map(
      (entry) => _requiredString(entry.$2, '$path[${entry.$1}]'),
    ),
  );
}
