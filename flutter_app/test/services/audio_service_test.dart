import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sound preference gates native click feedback without an audio asset',
    () async {
      final played = <SystemSoundType>[];
      final audio = AudioService(
        playSystemSound: (type) async => played.add(type),
      );

      await audio.playUiClick();
      audio.setEffectsEnabled(false);
      await audio.playUiClick();
      audio.setEffectsEnabled(true);
      await audio.playUiClick();

      expect(played, <SystemSoundType>[
        SystemSoundType.click,
        SystemSoundType.click,
      ]);
      await audio.dispose();
    },
  );

  testWidgets('the supplied 115 BPM soundtrack is bundled', (tester) async {
    final bytes = await rootBundle.load(AudioService.bundledMusicAsset);
    expect(bytes.lengthInBytes, greaterThan(1000000));
  });
}
