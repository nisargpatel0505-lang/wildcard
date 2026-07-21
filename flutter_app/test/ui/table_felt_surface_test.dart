import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  test('all collectible table felts resolve to distinct static treatments', () {
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
    };

    expect(tableFeltVisuals.keys.toSet(), ids);
    expect(
      tableFeltVisuals.values.map((felt) => felt.pattern).toSet(),
      hasLength(ids.length),
    );
    expect(resolveTableFeltVisual('missing').id, 'felt_classic');
  });

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
}
