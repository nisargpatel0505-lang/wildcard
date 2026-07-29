import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/ui/widgets/table_felt_surface.dart';
import 'package:wildcard/ui/wildcard_theme.dart';

void main() {
  test('all collectible table felts resolve to their intended treatments', () {
    const ids = <String>{
      'felt_classic',
      'felt_neon',
      'felt_royal',
      'felt_void',
      'felt_jade',
      'felt_ocean',
      'felt_crimson',
      'felt_galaxy',
      'felt_circuit',
      'felt_sakura',
      'felt_herringbone',
      'felt_art_deco',
      'felt_honeycomb',
      'felt_tartan',
      'felt_circuit_v2',
      'felt_nebula',
      'felt_midnight_velvet',
      'felt_emerald_royale',
      'felt_neon_grid',
      'felt_obsidian_marble',
      'felt_hearts_kingdom',
      'felt_spades_kingdom',
      'felt_diamonds_kingdom',
      'felt_clubs_kingdom',
    };

    expect(tableFeltVisuals.keys.toSet(), ids);
    final procedural = tableFeltVisuals.values
        .where((felt) => !felt.isImageBased)
        .toList();
    final imageBased = tableFeltVisuals.values
        .where((felt) => felt.isImageBased)
        .toList();
    expect(
      procedural.map((felt) => felt.pattern).toSet(),
      hasLength(procedural.length),
    );
    expect(imageBased, hasLength(8));
    expect(
      imageBased.map((felt) => felt.assetPath).toSet(),
      hasLength(imageBased.length),
    );
    expect(resolveTableFeltVisual('missing').id, 'felt_classic');
  });

  test(
    'premium texture placeholders are registered 1024px WebP assets',
    () async {
      final textures = tableFeltVisuals.values.where(
        (felt) => felt.isImageBased,
      );
      for (final texture in textures) {
        expect(texture.assetPath, endsWith('.webp'));
        final bytes = await rootBundle.load(texture.assetPath!);
        expect(bytes.lengthInBytes, greaterThan(1000), reason: texture.id);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 1024, reason: texture.id);
        expect(frame.image.height, 1024, reason: texture.id);
        frame.image.dispose();
        codec.dispose();
      }
    },
  );

  testWidgets('equipped felt is exposed on the painted table surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: const Scaffold(
          body: TableFeltSurface(
            feltId: 'felt_galaxy',
            child: SizedBox(width: 300, height: 180),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('table-felt-felt_galaxy')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('new procedural treatments paint without runtime effects', (
    tester,
  ) async {
    const ids = <String>[
      'felt_herringbone',
      'felt_art_deco',
      'felt_honeycomb',
      'felt_tartan',
      'felt_circuit_v2',
      'felt_nebula',
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: Scaffold(
          body: Wrap(
            children: [
              for (final id in ids)
                TableFeltSurface(
                  feltId: id,
                  width: 240,
                  child: const SizedBox(height: 120),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    for (final id in ids) {
      expect(find.byKey(ValueKey('table-felt-$id')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('image-based felt repeats its cached tile under live content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: const Scaffold(
          body: TableFeltSurface(
            feltId: 'felt_midnight_velvet',
            child: SizedBox(width: 360, height: 220),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('table-felt-texture-felt_midnight_velvet')),
    );
    expect(image.repeat, ImageRepeat.repeat);
    expect(image.fit, BoxFit.none);
    expect(image.image, isA<ResizeImage>());
    final resized = image.image as ResizeImage;
    expect(resized.width, 512);
    expect(resized.height, 512);
    expect(image.filterQuality, FilterQuality.low);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live table content sits outside the static felt boundary', (
    tester,
  ) async {
    const liveContentKey = ValueKey('live-table-content');
    const feltKey = ValueKey('table-felt-felt_classic');
    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: const Scaffold(
          body: TableFeltSurface(
            feltId: 'felt_classic',
            padding: EdgeInsets.all(12),
            child: SizedBox(key: liveContentKey, width: 300, height: 180),
          ),
        ),
      ),
    );

    expect(find.byKey(feltKey), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(liveContentKey),
        matching: find.byKey(feltKey),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
