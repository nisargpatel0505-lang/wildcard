import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/app/screens/tutorial_screen.dart';
import 'package:wildcard/ui/wildcard_theme.dart';

void main() {
  testWidgets('tutorial completes all five rules exactly once and returns', (
    tester,
  ) async {
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(size: const Size(375, 812), disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-tutorial'),
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        TutorialScreen(onComplete: () async => completions++),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-tutorial')));
    await tester.pumpAndSettle();
    expect(find.text("SLY'S LESSON"), findsOneWidget);
    expect(find.text('NEXT RULE'), findsOneWidget);

    for (var step = 0; step < 4; step++) {
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('CLAIM GIFT & CHOOSE RUN'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial-next')));
    await tester.pumpAndSettle();

    expect(completions, 1);
    expect(find.byKey(const Key('open-tutorial')), findsOneWidget);
    expect(find.byType(TutorialScreen), findsNothing);
  });
}
