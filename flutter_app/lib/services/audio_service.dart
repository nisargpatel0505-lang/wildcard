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

  final SystemSoundPlayer _playSystemSound;
  AudioPlayer? _music;
  bool _started = false;
  bool _enabled = false;
  bool _effectsEnabled = true;
  int _syncGeneration = 0;

  bool get effectsEnabled => _effectsEnabled;

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
        return;
      }
      if (!_started) {
        final music = _music ??= AudioPlayer(playerId: 'wildcard_bgm');
        await music.setReleaseMode(ReleaseMode.loop);
        await music.setVolume(0.16);
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

  Future<void> dispose() async {
    _enabled = false;
    _effectsEnabled = false;
    _syncGeneration++;
    await _music?.dispose();
    _music = null;
    _started = false;
  }
}
