import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  testWidgets('WILDCARD home shell renders its primary action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: const WildcardHomeScreen(coins: 250, bestHeat: 6),
      ),
    );

    expect(find.text('NEW RUN'), findsOneWidget);
    expect(find.text('250'), findsOneWidget);
    expect(find.text('BEST HEAT 6'), findsOneWidget);
  });
}
