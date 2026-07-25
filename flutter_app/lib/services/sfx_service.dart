import 'package:audioplayers/audioplayers.dart';

/// Low-latency effect player for the WebView build's synth sounds.
///
/// The original client generated every effect live with WebAudio — a rising
/// tone ladder as cards scored, chords for cleared targets, a descending
/// arcade jingle on death. The port shipped with only the Android system
/// click, which is most of why scoring felt silent. Those exact tones are now
/// pre-rendered into `assets/audio/sfx/` and played through pooled
/// low-latency players, so firing one adds no work to the scoring loop.
class SfxService {
  SfxService();

  /// Follows the player's sound switch; flipping it silences effects at once.
  bool enabled = true;

  final Map<String, AudioPool> _pools = <String, AudioPool>{};
  final Map<String, Future<AudioPool?>> _loading = <String, Future<AudioPool?>>{};
  bool _disposed = false;

  /// The sounds needed the moment a hand is played. Warmed when a run opens so
  /// the first scoring beat is not late while a pool spins up.
  static const List<String> scoringSet = <String>[
    'select', 'deselect', 'discard',
    'score_0', 'score_1', 'score_2', 'score_3', 'score_4',
    'joker_0', 'joker_1', 'mult_0', 'mult_1',
    'hand_total', 'callout_nice', 'callout_great', 'callout_mega',
    'callout_wild', 'heat_clear',
  ];

  /// Fire-and-forget. Sound must never block or fail an action.
  void play(String name, {double volume = 1}) {
    if (!enabled || _disposed) return;
    final pool = _pools[name];
    if (pool != null) {
      pool.start(volume: volume).ignore();
      return;
    }
    _load(name).then((loaded) {
      if (loaded != null && enabled && !_disposed) {
        loaded.start(volume: volume).ignore();
      }
    }).ignore();
  }

  Future<void> warmUp(Iterable<String> names) async {
    for (final name in names) {
      if (_disposed) return;
      await _load(name);
    }
  }

  Future<AudioPool?> _load(String name) {
    return _loading[name] ??= AudioPool.createFromAsset(
      path: 'audio/sfx/$name.wav',
      maxPlayers: 3,
      playerMode: PlayerMode.lowLatency,
    ).then<AudioPool?>((pool) {
      if (_disposed) return null;
      return _pools[name] = pool;
    }).catchError((Object _) => null);
  }

  Future<void> dispose() async {
    _disposed = true;
    enabled = false;
    for (final pool in _pools.values) {
      try {
        await pool.dispose();
      } catch (_) {
        // Best effort: pooled players are cheap and the process is ending.
      }
    }
    _pools.clear();
    _loading.clear();
  }
}
