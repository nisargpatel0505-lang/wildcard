import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_constants.dart';

class LegacySaveSnapshot {
  const LegacySaveSnapshot({
    this.accountJson,
    this.runJson,
    this.privacyMarker,
    this.cloudOwner,
  });

  final String? accountJson;
  final String? runJson;
  final String? privacyMarker;
  final String? cloudOwner;

  bool get hasAnyValue =>
      accountJson != null ||
      runJson != null ||
      privacyMarker != null ||
      cloudOwner != null;

  factory LegacySaveSnapshot.fromPlatformMap(Map<Object?, Object?> values) {
    String? stringValue(String key) {
      final value = values[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return LegacySaveSnapshot(
      accountJson: stringValue(AppConstants.legacyAccountKey),
      runJson: stringValue(AppConstants.legacyRunKey),
      privacyMarker: stringValue(AppConstants.privacyAcceptedKey),
      cloudOwner: stringValue(AppConstants.cloudOwnerKey),
    );
  }
}

class MigrationResult {
  const MigrationResult({
    required this.attempted,
    required this.copiedKeys,
    this.error,
  });

  final bool attempted;
  final Set<String> copiedKeys;
  final Object? error;

  bool get succeeded => error == null;
  bool get migratedAnything => copiedKeys.isNotEmpty;
}

/// Owns the Flutter save and performs the one-time, non-destructive import from
/// Capacitor's `CapacitorStorage.xml`. The old values are deliberately retained
/// so a rollback to the web client cannot erase a player's progress.
class LocalSaveRepository {
  LocalSaveRepository._(this._preferences);

  static const _migrationChannel = MethodChannel(
    'com.nisarg.wildcard/save_migration',
  );

  final SharedPreferences _preferences;

  static Future<LocalSaveRepository> open() async {
    return LocalSaveRepository._(await SharedPreferences.getInstance());
  }

  Future<MigrationResult> migrateLegacySaveIfNeeded() async {
    if (_preferences.getBool(AppConstants.migrationMarkerKey) == true) {
      return const MigrationResult(attempted: false, copiedKeys: {});
    }

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      await _preferences.setBool(AppConstants.migrationMarkerKey, true);
      return const MigrationResult(attempted: false, copiedKeys: {});
    }

    try {
      final raw = await _migrationChannel.invokeMapMethod<Object?, Object?>(
        'readLegacyPreferences',
      );
      final legacy = LegacySaveSnapshot.fromPlatformMap(raw ?? const {});
      final copied = <String>{};

      Future<void> copyString(String key, String? value) async {
        if (value == null || _preferences.containsKey(key)) return;
        if (await _preferences.setString(key, value)) copied.add(key);
      }

      await copyString(AppConstants.legacyAccountKey, legacy.accountJson);
      await copyString(AppConstants.legacyRunKey, legacy.runJson);
      await copyString(AppConstants.cloudOwnerKey, legacy.cloudOwner);
      await copyString(AppConstants.privacyAcceptedKey, legacy.privacyMarker);

      // A successful platform read is enough to mark the migration, even if a
      // first-time player had no legacy save. The native values are never cleared.
      await _preferences.setBool(AppConstants.migrationMarkerKey, true);
      return MigrationResult(attempted: true, copiedKeys: copied);
    } on MissingPluginException catch (error) {
      return MigrationResult(
        attempted: true,
        copiedKeys: const {},
        error: error,
      );
    } on PlatformException catch (error) {
      return MigrationResult(
        attempted: true,
        copiedKeys: const {},
        error: error,
      );
    }
  }

  bool get privacyAccepted {
    final stored = _preferences.get(AppConstants.privacyAcceptedKey);
    final marker = stored is String ? stored : null;
    if (marker == null || marker.isEmpty) {
      // Support only old Flutter development installs that briefly wrote a
      // boolean. The shipped Capacitor client has always used a JSON marker.
      return stored is bool ? stored : false;
    }
    try {
      final decoded = jsonDecode(marker);
      return decoded is Map &&
          decoded['version'] == AppConstants.privacyPolicyVersion &&
          (decoded['acceptedAt'] as num? ?? 0) > 0;
    } on FormatException {
      return false;
    }
  }

  Future<void> acceptPrivacy() async {
    final acceptedAt = DateTime.now().millisecondsSinceEpoch;
    await _preferences.setString(
      AppConstants.privacyAcceptedKey,
      jsonEncode(<String, Object>{
        'version': AppConstants.privacyPolicyVersion,
        'acceptedAt': acceptedAt,
        '_savedAt': acceptedAt,
      }),
    );
  }

  String? get accountJson =>
      _preferences.getString(AppConstants.legacyAccountKey);

  String? get runJson => _preferences.getString(AppConstants.legacyRunKey);

  String? get cloudOwner => _preferences.getString(AppConstants.cloudOwnerKey);

  String? readString(String key) => _preferences.getString(key);

  int readInt(String key, {int fallback = 0}) =>
      _preferences.getInt(key) ?? fallback;

  bool readBool(String key, {bool fallback = false}) =>
      _preferences.getBool(key) ?? fallback;

  Future<void> writeString(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _preferences.remove(key);
    } else {
      await _preferences.setString(key, value);
    }
  }

  Future<void> writeInt(String key, int value) =>
      _preferences.setInt(key, value);

  Future<void> writeBool(String key, bool value) =>
      _preferences.setBool(key, value);

  Future<void> remove(String key) => _preferences.remove(key);

  Map<String, dynamic>? decodeAccount() => _decodeObject(accountJson);

  Map<String, dynamic>? decodeRun() => _decodeObject(runJson);

  Map<String, dynamic>? _decodeObject(String? source) {
    if (source == null || source.isEmpty) return null;
    try {
      final value = jsonDecode(source);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> writeAccount(Map<String, dynamic> account) =>
      writeAccountJson(jsonEncode(account));

  Future<void> writeRun(Map<String, dynamic>? run) =>
      run == null ? clearRun() : writeRunJson(jsonEncode(run));

  Future<void> writeAccountJson(String value) async {
    if (value.length > 150000) {
      throw const FormatException('Account save is too large');
    }
    jsonDecode(value);
    await _preferences.setString(AppConstants.legacyAccountKey, value);
  }

  Future<void> writeRunJson(String value) async {
    if (value.length > 150000) {
      throw const FormatException('Run save is too large');
    }
    jsonDecode(value);
    await _preferences.setString(AppConstants.legacyRunKey, value);
  }

  Future<void> writeCloudOwner(String? uid) async {
    if (uid == null || uid.isEmpty) {
      await _preferences.remove(AppConstants.cloudOwnerKey);
    } else {
      await _preferences.setString(AppConstants.cloudOwnerKey, uid);
    }
  }

  Future<void> clearRun() => _preferences.remove(AppConstants.legacyRunKey);

  Future<void> clearPlayerData({bool retainPrivacyAcceptance = true}) async {
    await _preferences.remove(AppConstants.legacyAccountKey);
    await _preferences.remove(AppConstants.legacyRunKey);
    await _preferences.remove(AppConstants.cloudOwnerKey);
    await _preferences.remove(AppConstants.dailyScoreOutboxKey);
    if (!retainPrivacyAcceptance) {
      await _preferences.remove(AppConstants.privacyAcceptedKey);
    }
  }
}
