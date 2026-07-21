enum RandomStream {
  deck(0xA5A5A5A5),
  shop(0x5A5A5A5A),
  modifiers(0x01234567),
  luck(0x0077AA33),
  boss(0x51B055ED);

  const RandomStream(this.salt);

  final int salt;

  String get legacyName => switch (this) {
    RandomStream.modifiers => 'mods',
    _ => name,
  };

  static RandomStream fromLegacy(String value) =>
      RandomStream.values.firstWhere(
        (stream) => stream.legacyName == value,
        orElse: () => throw FormatException('Unknown RNG stream: $value'),
      );
}

const int _uint32Mask = 0xFFFFFFFF;

int _uint32(int value) => value & _uint32Mask;

/// Equivalent to JavaScript's `Math.imul(a, b) >>> 0`.
int _imul32(int a, int b) =>
    ((_uint32(a) * _uint32(b)) & _uint32Mask).toUnsigned(32);

/// Byte-for-byte parity with `seededRandomAt()` in the v6.9.14 web client.
double seededRandomAt(int seed, RandomStream stream, int index) {
  var x = _uint32(
    _uint32(seed) ^ stream.salt ^ _imul32(_uint32(index) + 1, 0x85EBCA6B),
  );
  x = _imul32(x ^ (x >>> 16), 0x7FEB352D);
  x = _imul32(x ^ (x >>> 15), 0x846CA68B);
  return _uint32(x ^ (x >>> 16)) / 4294967296.0;
}

/// FNV-1a date seed used by Daily Challenge (`YYYY-MM-DD`).
int dailySeed(String date) {
  var hash = 2166136261;
  for (final codeUnit in date.codeUnits) {
    hash = _imul32(hash ^ codeUnit, 16777619);
  }
  return _uint32(hash);
}

class RandomCounters {
  RandomCounters([Map<RandomStream, int>? values])
    : _values = <RandomStream, int>{
        for (final stream in RandomStream.values)
          // JavaScript numbers are exact only through 2^53 - 1. Keeping a
          // persisted counter inside that range makes deterministic resumes
          // portable between Android, tests and the browser preview.
          stream: (values?[stream] ?? 0).clamp(0, 0x1FFFFFFFFFFFFF),
      };

  factory RandomCounters.fromJson(Object? value) {
    final json = value is Map ? value : const <Object?, Object?>{};
    return RandomCounters(<RandomStream, int>{
      for (final stream in RandomStream.values)
        stream: _nonNegativeInt(json[stream.legacyName]),
    });
  }

  final Map<RandomStream, int> _values;

  int operator [](RandomStream stream) => _values[stream] ?? 0;

  void operator []=(RandomStream stream, int value) {
    _values[stream] = value < 0 ? 0 : value;
  }

  double next(RandomStream stream, int seed) {
    final index = this[stream];
    this[stream] = index + 1;
    return seededRandomAt(seed, stream, index);
  }

  RandomCounters copy() => RandomCounters(Map<RandomStream, int>.from(_values));

  Map<String, int> toJson() => <String, int>{
    for (final stream in RandomStream.values) stream.legacyName: this[stream],
  };
}

int _nonNegativeInt(Object? value) {
  final parsed = switch (value) {
    int number => number,
    num number => number.floor(),
    _ => int.tryParse(value?.toString() ?? '') ?? 0,
  };
  return parsed < 0 ? 0 : parsed;
}
