import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

typedef SystemSoundPlayer = Future<void> Function(SystemSoundType type);

/// Lightweight looping soundtrack service.
///
/// The recovered 115 BPM edit is already the slower mobile mix requested for
/// WILDCARD. It is decoded once and looped by the platform player, leaving the
/// scoring/UI isolate free of audio timing work.
class AudioService {
  AudioService({SystemSoundPlayer? playSystemSound})
    : _playSystemSound = playSystemSound ?? SystemSound.play;

  static const String musicAsset = 'audio/bit-shift-kevin-macleod-115bpm.mp3';
  static const String bundledMusicAsset = 'assets/$musicAsset';

  /// Mirrors the WebView's BGM_VOLUME / BGM_DUCK_VOLUME pair: the main track
  /// dips under the eerie modifier loop instead of fighting it.
  static const double _musicVolume = 0.16;
  static const double _musicDucked = 0.035;
  static const String _ambienceAsset = 'audio/sfx/ambience_loop.wav';

  final SystemSoundPlayer _playSystemSound;
  AudioPlayer? _music;
  AudioPlayer? _ambience;
  bool _started = false;
  bool _enabled = false;
  bool _effectsEnabled = true;
  bool _ambienceActive = false;
  bool _ceremonyDucked = false;
  int _syncGeneration = 0;
  int _ambienceGeneration = 0;

  bool get effectsEnabled => _effectsEnabled;

  double get _currentMusicVolume =>
      _ambienceActive || _ceremonyDucked ? _musicDucked : _musicVolume;

  /// Enables the native click channel used by table actions.
  ///
  /// This uses Android's system click rather than a decoded sound asset, so it
  /// does not add an audio player or any work to the scoring animation loop.
  void setEffectsEnabled(bool enabled) => _effectsEnabled = enabled;

  Future<void> playUiClick() async {
    if (!_effectsEnabled) return;
    try {
      await _playSystemSound(SystemSoundType.click);
    } catch (_) {
      // Sound feedback is optional and must never block an action.
    }
  }

  Future<void> sync({required bool enabled}) async {
    if (_enabled == enabled && (_started || !enabled)) return;
    _enabled = enabled;
    final generation = ++_syncGeneration;
    try {
      if (!enabled) {
        await _music?.pause();
        // The eerie loop follows the same switch: no music, no ambience.
        _ambienceActive = false;
        _ambienceGeneration++;
        await _ambience?.pause();
        return;
      }
      if (!_started) {
        final music = _music ??= AudioPlayer(playerId: 'wildcard_bgm');
        await music.setReleaseMode(ReleaseMode.loop);
        await music.setVolume(_currentMusicVolume);
        if (!_enabled || generation != _syncGeneration) return;
        await music.play(AssetSource(musicAsset));
        if (!_enabled || generation != _syncGeneration) {
          await music.pause();
          return;
        }
        _started = true;
      } else {
        await _music?.resume();
        if (!_enabled || generation != _syncGeneration) {
          await _music?.pause();
        }
      }
    } catch (_) {
      // Audio is cosmetic and must never interrupt a run or save operation.
    }
  }

  /// The WebView's modifier-heat ambience: a quiet D-minor arcade-horror loop
  /// that plays over a ducked main track while a modifier table is active.
  /// The loop is the same pattern the old client synthesized live, pre-rendered
  /// so it costs one looping platform player and no per-frame work.
  Future<void> syncAmbience({required bool active}) async {
    // Ambience follows the music switch exactly as the WebView did.
    final wanted = active && _enabled;
    if (_ambienceActive == wanted) return;
    _ambienceActive = wanted;
    final generation = ++_ambienceGeneration;
    try {
      await _music?.setVolume(_currentMusicVolume);
      if (!wanted) {
        await _ambience?.pause();
        return;
      }
      final ambience = _ambience ??= AudioPlayer(playerId: 'wildcard_ambience');
      if (generation != _ambienceGeneration) return;
      await ambience.setReleaseMode(ReleaseMode.loop);
      await ambience.setVolume(1);
      if (generation != _ambienceGeneration || !_ambienceActive) return;
      await ambience.play(AssetSource(_ambienceAsset));
      if (generation != _ambienceGeneration || !_ambienceActive) {
        await ambience.pause();
      }
    } catch (_) {
      // Ambience is cosmetic and must never interrupt a run or save operation.
    }
  }

  /// Gives premium reveal audio room without stopping or restarting music.
  /// This is presentation-only and intentionally survives overlapping calls.
  Future<void> setCeremonyDuck(bool active) async {
    if (_ceremonyDucked == active) return;
    _ceremonyDucked = active;
    if (!_enabled) return;
    try {
      await _music?.setVolume(_currentMusicVolume);
    } catch (_) {
      // A volume failure must never block a saved reward from being shown.
    }
  }

  Future<void> dispose() async {
    _enabled = false;
    _effectsEnabled = false;
    _ambienceActive = false;
    _ceremonyDucked = false;
    _syncGeneration++;
    _ambienceGeneration++;
    await _music?.dispose();
    await _ambience?.dispose();
    _music = null;
    _ambience = null;
    _started = false;
  }
}
