import 'dart:convert';

import 'economy.dart';
import 'joker_catalog.dart';

enum ScoringPace { normal, fast }

class TopRunRecord {
  const TopRunRecord({
    required this.score,
    required this.heat,
    this.provisionalStamp,
  });

  final int score;
  final int heat;
  final int? provisionalStamp;

  Map<String, Object?> toJson() => <String, Object?>{
    'score': score,
    'heat': heat,
    if (provisionalStamp != null) '_provisional': provisionalStamp,
  };
}

class DailyBestRecord {
  const DailyBestRecord({this.date = '', this.score = 0});

  final String date;
  final int score;

  Map<String, Object?> toJson() => <String, Object?>{
    'date': date,
    'score': score,
  };
}

class PlayerStatistics {
  const PlayerStatistics({
    this.runs = 0,
    this.wins = 0,
    this.gauntletWins = 0,
    this.hands = 0,
  });

  final int runs;
  final int wins;
  final int gauntletWins;
  final int hands;

  Map<String, Object?> toJson() => <String, Object?>{
    'runs': runs,
    'wins': wins,
    'gWins': gauntletWins,
    'hands': hands,
  };
}

class RunLogRecord {
  const RunLogRecord({
    required this.date,
    required this.heat,
    required this.cleared,
    required this.score,
    required this.modeCode,
    required this.won,
    required this.abandoned,
  });

  final String date;
  final int heat;
  final int cleared;
  final int score;
  final String modeCode;
  final bool won;
  final bool abandoned;

  Map<String, Object?> toJson() => <String, Object?>{
    'd': date,
    'h': heat,
    'c': cleared,
    's': score,
    'm': modeCode,
    'w': won,
    'a': abandoned,
  };
}

class PurchaseClaim {
  const PurchaseClaim({required this.productId, required this.claimedAt});

  final String productId;
  final int claimedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'productId': productId,
    'claimedAt': claimedAt,
  };
}

class EquippedCosmetics {
  const EquippedCosmetics({
    this.table = 'felt_classic',
    this.theme = 'theme_default',
    this.sly = 'sly_classic',
  });

  final String table;
  final String theme;
  final String sly;

  Map<String, Object?> toJson() => <String, Object?>{
    'table': table,
    'theme': theme,
    'sly': sly,
  };
}

/// Typed account model for `wildcard_save_v1` from the recovered phone APK.
///
/// The backend treats `accountJson` as an opaque payload. Unknown fields are
/// retained on write so a Flutter update (or rollback) does not erase metadata.
class AccountState {
  AccountState({
    this.savedAt = 0,
    this.coins = 0,
    Set<String>? unlockedJokerIds,
    this.tutorialDone = false,
    this.starterGiftClaimed = false,
    this.firstRunStarted = false,
    this.firstLossCoached = false,
    this.tutorialChestClaimed = false,
    this.bestHeat = 0,
    this.bestScore = 0,
    this.muted = false,
    List<TopRunRecord>? topRuns,
    this.speed = ScoringPace.normal,
    this.pacingVersion = 2,
    this.noAds = false,
    this.lastDaily = '',
    this.dailyStreak = 0,
    Map<String, Object?>? achievements,
    Map<String, Object?>? achievementClaimed,
    this.adDate = '',
    this.adViews = 0,
    Set<String>? cosmeticsOwned,
    this.equipped = const EquippedCosmetics(),
    this.title = '',
    this.missionWeek = '',
    Map<String, int>? missionStats,
    Map<String, bool>? missionClaimed,
    List<String>? missionSet,
    this.missionRotation = 0,
    this.missionRefreshDate = '',
    this.dailyRunDate = '',
    this.dailyBest = const DailyBestRecord(),
    this.bestClearedHeat = 0,
    this.musicOn = true,
    this.playerName = '',
    this.stats = const PlayerStatistics(),
    List<RunLogRecord>? runLog,
    List<String>? rewardClaims,
    Map<String, PurchaseClaim>? purchaseClaims,
    Map<String, Object?>? unknownFields,
  }) : unlockedJokerIds = unlockedJokerIds ?? <String>{},
       topRuns = topRuns ?? <TopRunRecord>[],
       achievements = achievements ?? <String, Object?>{},
       achievementClaimed = achievementClaimed ?? <String, Object?>{},
       cosmeticsOwned = cosmeticsOwned ?? <String>{},
       missionStats = missionStats ?? <String, int>{},
       missionClaimed = missionClaimed ?? <String, bool>{},
       missionSet = missionSet ?? <String>[],
       runLog = runLog ?? <RunLogRecord>[],
       rewardClaims = rewardClaims ?? <String>[],
       purchaseClaims = purchaseClaims ?? <String, PurchaseClaim>{},
       unknownFields = unknownFields ?? <String, Object?>{};

  factory AccountState.decode(String encoded) {
    final value = jsonDecode(encoded);
    if (value is! Map) {
      throw const FormatException('Account save is not an object');
    }
    return AccountState.fromJson(
      value.map((key, item) => MapEntry(key.toString(), item)),
    );
  }

  factory AccountState.fromJson(Map<String, Object?> json) {
    final tutorialDone = json['tutorialDone'] == true;
    final muted = json['muted'] == true;
    final achievements = _objectMap(json['achievements']);
    final claimedSource = json['achievementClaimed'];
    final validJokers = jokersById.keys.toSet();
    final topRuns = _topRuns(json['topRuns']);
    final rawBestHeat = _clampInt(json['bestHeat'], max: 999);
    final known = <String>{
      '_savedAt',
      'coins',
      'unlocked',
      'tutorialDone',
      'starterGiftClaimed',
      'firstRunStarted',
      'firstLossCoached',
      'tutorialChestClaimed',
      'bestHeat',
      'bestScore',
      'muted',
      'topRuns',
      'speed',
      'pacingVersion',
      'noAds',
      'lastDaily',
      'dailyStreak',
      'achievements',
      'achievementClaimed',
      'adDate',
      'adViews',
      'cosmeticsOwned',
      'equipped',
      'title',
      'missionWeek',
      'missionStats',
      'missionClaimed',
      'missionSet',
      'missionRotation',
      'missionRefreshDate',
      'dailyRunDate',
      'dailyBest',
      'bestClearedHeat',
      'musicOn',
      'playerName',
      'stats',
      'runLog',
      'rewardClaims',
      'purchaseClaims',
    };
    return AccountState(
      savedAt: _clampInt(json['_savedAt'], max: 9999999999999),
      coins: _clampInt(json['coins']),
      unlockedJokerIds: _strings(
        json['unlocked'],
      ).where(validJokers.contains).toSet(),
      tutorialDone: tutorialDone,
      starterGiftClaimed: json['starterGiftClaimed'] is bool
          ? json['starterGiftClaimed'] == true
          : tutorialDone,
      firstRunStarted: json['firstRunStarted'] is bool
          ? json['firstRunStarted'] == true
          : tutorialDone,
      firstLossCoached: json['firstLossCoached'] == true,
      tutorialChestClaimed: json['tutorialChestClaimed'] == true,
      bestHeat: rawBestHeat,
      bestScore: _clampInt(json['bestScore']),
      muted: muted,
      topRuns: topRuns,
      speed:
          _clampInt(json['pacingVersion'], max: 99) >= 2 &&
              json['speed'] == 'fast'
          ? ScoringPace.fast
          : ScoringPace.normal,
      pacingVersion: 2,
      noAds: json['noAds'] == true,
      lastDaily: json['lastDaily']?.toString() ?? '',
      dailyStreak: _clampInt(json['dailyStreak'], max: 999),
      achievements: achievements,
      achievementClaimed: claimedSource is Map
          ? _objectMap(claimedSource)
          : <String, Object?>{for (final key in achievements.keys) key: 1},
      adDate: json['adDate']?.toString() ?? '',
      adViews: _clampInt(json['adViews'], max: 9999),
      cosmeticsOwned: _strings(json['cosmeticsOwned']).toSet(),
      equipped: _equipped(json['equipped']),
      title: json['title'] is String ? json['title']! as String : '',
      missionWeek: json['missionWeek']?.toString() ?? '',
      missionStats: _nonNegativeIntMap(json['missionStats']),
      missionClaimed: _boolMap(json['missionClaimed']),
      missionSet: _strings(json['missionSet']).take(3).toList(),
      missionRotation: _clampInt(json['missionRotation'], max: 9999),
      missionRefreshDate: json['missionRefreshDate'] is String
          ? json['missionRefreshDate']! as String
          : '',
      dailyRunDate: json['dailyRunDate']?.toString() ?? '',
      dailyBest: _dailyBest(json['dailyBest']),
      bestClearedHeat: json.containsKey('bestClearedHeat')
          ? _clampInt(json['bestClearedHeat'], max: 999)
          : (rawBestHeat - 1).clamp(0, 999),
      musicOn: json['musicOn'] is bool ? json['musicOn'] == true : !muted,
      playerName: _sanitizePlayerName(json['playerName']),
      stats: _stats(json['stats']),
      runLog: _runLog(json['runLog']),
      rewardClaims: _rewardClaims(json['rewardClaims']),
      purchaseClaims: _purchaseClaims(json['purchaseClaims']),
      unknownFields: <String, Object?>{
        for (final entry in json.entries)
          if (!known.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  int savedAt;
  int coins;
  final Set<String> unlockedJokerIds;
  bool tutorialDone;
  bool starterGiftClaimed;
  bool firstRunStarted;
  bool firstLossCoached;
  bool tutorialChestClaimed;
  int bestHeat;
  int bestScore;
  bool muted;
  final List<TopRunRecord> topRuns;
  ScoringPace speed;
  int pacingVersion;
  bool noAds;
  String lastDaily;
  int dailyStreak;
  final Map<String, Object?> achievements;
  final Map<String, Object?> achievementClaimed;
  String adDate;
  int adViews;
  final Set<String> cosmeticsOwned;
  EquippedCosmetics equipped;
  String title;
  String missionWeek;
  final Map<String, int> missionStats;
  final Map<String, bool> missionClaimed;
  final List<String> missionSet;
  int missionRotation;
  String missionRefreshDate;
  String dailyRunDate;
  DailyBestRecord dailyBest;
  int bestClearedHeat;
  bool musicOn;
  String playerName;
  PlayerStatistics stats;
  final List<RunLogRecord> runLog;
  final List<String> rewardClaims;
  final Map<String, PurchaseClaim> purchaseClaims;
  final Map<String, Object?> unknownFields;

  Map<String, Object?> toLegacyJson({int? savedAtOverride}) =>
      <String, Object?>{
        ...unknownFields,
        '_savedAt': savedAtOverride ?? savedAt,
        'coins': coins,
        'unlocked': unlockedJokerIds.toList(),
        'tutorialDone': tutorialDone,
        'starterGiftClaimed': starterGiftClaimed,
        'firstRunStarted': firstRunStarted,
        'firstLossCoached': firstLossCoached,
        'tutorialChestClaimed': tutorialChestClaimed,
        'bestHeat': bestHeat,
        'bestScore': bestScore,
        'muted': muted,
        'topRuns': topRuns.map((run) => run.toJson()).toList(),
        'speed': speed.name,
        'pacingVersion': 2,
        'noAds': noAds,
        'lastDaily': lastDaily,
        'dailyStreak': dailyStreak,
        'achievements': achievements,
        'achievementClaimed': achievementClaimed,
        'adDate': adDate,
        'adViews': adViews,
        'cosmeticsOwned': cosmeticsOwned.toList(),
        'equipped': equipped.toJson(),
        'title': title,
        'missionWeek': missionWeek,
        'missionStats': missionStats,
        'missionClaimed': missionClaimed,
        'missionSet': missionSet,
        'missionRotation': missionRotation,
        'missionRefreshDate': missionRefreshDate,
        'dailyRunDate': dailyRunDate,
        'dailyBest': dailyBest.toJson(),
        'bestClearedHeat': bestClearedHeat,
        'musicOn': musicOn,
        'playerName': playerName,
        'stats': stats.toJson(),
        'runLog': runLog.map((record) => record.toJson()).toList(),
        'rewardClaims': rewardClaims,
        'purchaseClaims': <String, Object?>{
          for (final entry in purchaseClaims.entries)
            entry.key: entry.value.toJson(),
        },
      };

  String encode({int? savedAtOverride}) =>
      jsonEncode(toLegacyJson(savedAtOverride: savedAtOverride));
}

List<TopRunRecord> _topRuns(Object? value) {
  if (value is! List) return <TopRunRecord>[];
  final result = <TopRunRecord>[];
  for (final item in value) {
    if (item is! Map) continue;
    final score = _clampInt(item['score']);
    if (score <= 0) continue;
    final provisional = num.tryParse('${item['_provisional'] ?? ''}');
    result.add(
      TopRunRecord(
        score: score,
        heat: _clampInt(item['heat'], max: 999),
        provisionalStamp: provisional == null
            ? null
            : _clampInt(provisional, max: 9999999999999),
      ),
    );
  }
  result.sort((left, right) => right.score.compareTo(left.score));
  return result.take(5).toList();
}

DailyBestRecord _dailyBest(Object? value) {
  if (value is! Map) return const DailyBestRecord();
  final date = value['date']?.toString() ?? '';
  return DailyBestRecord(
    date: RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ? date : '',
    score: _clampInt(value['score']),
  );
}

PlayerStatistics _stats(Object? value) {
  if (value is! Map) return const PlayerStatistics();
  return PlayerStatistics(
    runs: _clampInt(value['runs']),
    wins: _clampInt(value['wins']),
    gauntletWins: _clampInt(value['gWins']),
    hands: _clampInt(value['hands']),
  );
}

List<RunLogRecord> _runLog(Object? value) {
  if (value is! List) return <RunLogRecord>[];
  final result = <RunLogRecord>[];
  for (final item in value) {
    if (item is! Map) continue;
    final date = item['d']?.toString() ?? '';
    final mode = const <String>{'G', 'D', 'S'}.contains(item['m'])
        ? item['m']! as String
        : 'S';
    result.add(
      RunLogRecord(
        date: RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ? date : '',
        heat: _clampInt(item['h'], max: 999),
        cleared: _clampInt(item['c'], max: 999),
        score: _clampInt(item['s']),
        modeCode: mode,
        won: item['w'] == true,
        abandoned: item['a'] == true,
      ),
    );
  }
  return result.take(10).toList();
}

List<String> _rewardClaims(Object? value) {
  final unique = <String>[];
  for (final claim in _strings(value)) {
    if (claim.length <= 96 && !unique.contains(claim)) unique.add(claim);
  }
  return unique.length <= 256 ? unique : unique.sublist(unique.length - 256);
}

Map<String, PurchaseClaim> _purchaseClaims(Object? value) {
  if (value is! Map) return <String, PurchaseClaim>{};
  final result = <MapEntry<String, PurchaseClaim>>[];
  final tokenPattern = RegExp(r'^[a-f0-9]{64}$');
  for (final entry in value.entries) {
    final tokenHash = entry.key.toString();
    final claim = entry.value;
    if (!tokenPattern.hasMatch(tokenHash) || claim is! Map) continue;
    final productId = claim['productId']?.toString() ?? '';
    if (!playProductIds.contains(productId)) continue;
    result.add(
      MapEntry(
        tokenHash,
        PurchaseClaim(
          productId: productId,
          claimedAt: _clampInt(claim['claimedAt'], max: 9999999999999),
        ),
      ),
    );
  }
  result.sort(
    (left, right) => left.value.claimedAt.compareTo(right.value.claimedAt),
  );
  return Map<String, PurchaseClaim>.fromEntries(
    result.length <= 256 ? result : result.sublist(result.length - 256),
  );
}

EquippedCosmetics _equipped(Object? value) {
  if (value is! Map) return const EquippedCosmetics();
  return EquippedCosmetics(
    table: value['table'] is String
        ? value['table']! as String
        : 'felt_classic',
    theme: value['theme'] is String
        ? value['theme']! as String
        : 'theme_default',
    sly: value['sly'] is String ? value['sly']! as String : 'sly_classic',
  );
}

Map<String, Object?> _objectMap(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : <String, Object?>{};

Map<String, int> _nonNegativeIntMap(Object? value) => value is Map
    ? <String, int>{
        for (final entry in value.entries)
          entry.key.toString(): _clampInt(entry.value),
      }
    : <String, int>{};

Map<String, bool> _boolMap(Object? value) => value is Map
    ? <String, bool>{
        for (final entry in value.entries)
          entry.key.toString(): _truthy(entry.value),
      }
    : <String, bool>{};

bool _truthy(Object? value) => switch (value) {
  null => false,
  false => false,
  num number when number == 0 => false,
  String text when text.isEmpty => false,
  _ => true,
};

List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const <String>[];

String _sanitizePlayerName(Object? value) {
  final clean = (value is String ? value : '').replaceAll(
    RegExp('[^A-Za-z0-9]'),
    '',
  );
  return clean.length <= 8 ? clean : clean.substring(0, 8);
}

int _clampInt(Object? value, {int min = 0, int max = 9999999}) {
  final parsed = switch (value) {
    int number => number,
    num number => number.floor(),
    _ => int.tryParse('${value ?? ''}'),
  };
  return (parsed ?? min).clamp(min, max);
}
