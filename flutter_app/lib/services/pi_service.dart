import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../core/app_constants.dart';

class DailyBoardEntry {
  const DailyBoardEntry({required this.name, required this.score});

  final String name;
  final int score;

  factory DailyBoardEntry.fromJson(Map<String, dynamic> json) {
    return DailyBoardEntry(
      name: json['n']?.toString() ?? '',
      score: (json['s'] as num?)?.toInt() ?? 0,
    );
  }
}

class DailyBoardSnapshot {
  const DailyBoardSnapshot({required this.entries, this.date});

  final List<DailyBoardEntry> entries;
  final String? date;

  factory DailyBoardSnapshot.fromJson(Map<String, dynamic> json) {
    final rows = json['top'];
    return DailyBoardSnapshot(
      date: json['date']?.toString(),
      entries: rows is List
          ? rows
                .whereType<Map>()
                .map(
                  (row) =>
                      DailyBoardEntry.fromJson(Map<String, dynamic>.from(row)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

/// Fail-soft client for the public Pi board and privacy-minimised product
/// counters. Analytics never contains a name, score, install/session ID,
/// cards, save data, or a Google/Firebase identifier.
class PiService {
  PiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final List<Map<String, String>> _analyticsQueue = [];
  Timer? _flushTimer;
  String _appVersion = '8.0.0';

  Future<void> initialize() async {
    final package = await PackageInfo.fromPlatform();
    _appVersion = package.version;
  }

  Future<DailyBoardSnapshot> fetchDailyBoard({String? date}) async {
    final query = date == null || date.isEmpty
        ? null
        : <String, String>{'date': date};
    final uri = Uri.parse(
      AppConstants.dailyBoardUrl,
    ).replace(queryParameters: query);

    Object? firstError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _client
            .get(uri, headers: const {'Cache-Control': 'no-store'})
            .timeout(const Duration(seconds: 8));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw http.ClientException('HTTP ${response.statusCode}', uri);
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) throw const FormatException('Invalid board');
        return DailyBoardSnapshot.fromJson(Map<String, dynamic>.from(decoded));
      } catch (error) {
        firstError ??= error;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    }
    throw firstError ?? StateError('Daily Board unavailable');
  }

  void queueAppOpen() => _queue(const {'n': 'app_open'});

  void queueRunStart(String mode) {
    if (!_validMode(mode)) return;
    _queue({'n': 'run_start', 'm': mode});
  }

  void queueRunEnd({
    required String mode,
    required String outcome,
    required int heat,
  }) {
    if (!_validMode(mode) ||
        !const {'won', 'lost', 'terminated'}.contains(outcome)) {
      return;
    }
    _queue({'n': 'run_end', 'm': mode, 'o': outcome, 'h': _heatBand(heat)});
  }

  void _queue(Map<String, String> event) {
    if (_analyticsQueue.length >= 12) _analyticsQueue.removeAt(0);
    _analyticsQueue.add(event);
    _flushTimer ??= Timer(const Duration(seconds: 45), () {
      _flushTimer = null;
      unawaited(flushAnalytics());
    });
  }

  Future<void> flushAnalytics() async {
    if (_analyticsQueue.isEmpty) return;
    final events = _analyticsQueue.take(12).toList(growable: false);
    _analyticsQueue.removeRange(0, events.length);
    try {
      await _client
          .post(
            Uri.parse(AppConstants.analyticsUrl),
            headers: const {'Content-Type': 'text/plain;charset=UTF-8'},
            body: jsonEncode({
              'v': _appVersion,
              'p': 'android',
              'events': events,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Metrics can be dropped; they must never delay or destabilise play.
    }
  }

  static bool _validMode(String mode) =>
      const {'normal', 'daily', 'gauntlet'}.contains(mode);

  static String _heatBand(int heat) {
    if (heat <= 3) return '1-3';
    if (heat <= 6) return '4-6';
    if (heat <= 9) return '7-9';
    if (heat <= 12) return '10-12';
    return '13+';
  }

  void dispose() {
    _flushTimer?.cancel();
    _client.close();
  }
}
