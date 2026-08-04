import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum LeaderboardTimeSpan {
  daily('daily'),
  weekly('weekly'),
  allTime('all');

  const LeaderboardTimeSpan(this.wireName);
  final String wireName;
}

class PlayGamesScore {
  const PlayGamesScore({
    required this.rank,
    required this.displayRank,
    required this.displayScore,
    required this.rawScore,
    required this.displayName,
    this.iconUrl,
  });

  final int rank;
  final String displayRank;
  final String displayScore;
  final int rawScore;
  final String displayName;
  final String? iconUrl;

  factory PlayGamesScore.fromMap(Map<Object?, Object?> map) {
    return PlayGamesScore(
      rank: (map['rank'] as num?)?.toInt() ?? 0,
      displayRank: map['displayRank']?.toString() ?? '',
      displayScore: map['displayScore']?.toString() ?? '',
      rawScore: (map['rawScore'] as num?)?.toInt() ?? 0,
      displayName: map['displayName']?.toString() ?? 'Player',
      iconUrl: map['iconUrl']?.toString(),
    );
  }
}

class PlayGamesService extends ChangeNotifier {
  static const _channel = MethodChannel('com.nisarg.wildcard/play_games');

  bool _initialized = false;
  bool _signedIn = false;
  Object? _lastError;

  bool get initialized => _initialized;
  bool get signedIn => _signedIn;
  Object? get lastError => _lastError;

  Future<bool> initializeAfterPrivacyAcceptance() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await _channel.invokeMethod<void>('initialize');
      _initialized = true;
      return refreshState();
    } catch (error) {
      _lastError = error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> refreshState() async {
    if (!_initialized) return false;
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'isAuthenticated',
      );
      _signedIn = result?['signedIn'] == true;
      _lastError = null;
    } catch (error) {
      _lastError = error;
      _signedIn = false;
    }
    notifyListeners();
    return _signedIn;
  }

  Future<bool> signIn() async {
    if (!_initialized) return false;
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>('signIn');
      _signedIn = result?['signedIn'] == true;
      _lastError = null;
    } catch (error) {
      _lastError = error;
      _signedIn = false;
    }
    notifyListeners();
    return _signedIn;
  }

  Future<bool> submitScore(int score) async {
    if (!_signedIn || score <= 0) return false;
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'submitScore',
      <String, Object>{'score': score},
    );
    return result?['submitted'] == true;
  }

  Future<void> showLeaderboard() =>
      _channel.invokeMethod<void>('showLeaderboard');

  Future<List<PlayGamesScore>> loadScores(LeaderboardTimeSpan span) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'loadScores',
      <String, Object>{'span': span.wireName},
    );
    final rows = result?['scores'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map((row) => PlayGamesScore.fromMap(row))
        .toList(growable: false);
  }
}
