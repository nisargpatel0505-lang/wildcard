import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/ui/screens/boot_loading_screen.dart';

void main() {
  testWidgets('boot screen renders real milestone labels and failure recovery', (
    tester,
  ) async {
    final progress = ValueNotifier<BootProgress>(
      const BootProgress(.22, 'Checking old progress…'),
    );
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: BootLoadingScreen(
          progress: progress,
          visualProgress: const AlwaysStoppedAnimation<double>(.5),
        ),
      ),
    );
    expect(find.text('Checking old progress…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('boot-logo-image')), findsOneWidget);
    expect(find.byKey(const Key('boot-logo-fallback')), findsNothing);
    expect(
      tester.getRect(find.byKey(const Key('boot-logo-image'))).bottom,
      lessThan(
        tester.getRect(find.byKey(const Key('boot-progress-panel'))).top,
      ),
    );
    expect(
      DefaultTextStyle.of(
        tester.element(find.byKey(const Key('boot-status-label'))),
      ).style.decoration,
      isNot(TextDecoration.underline),
      reason: 'Loading text must not inherit Flutter emergency underlines.',
    );
    expect(find.text('50%'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'boot-progress-segment-',
            ),
      ),
      findsNWidgets(12),
    );
    for (var index = 0; index < 12; index++) {
      expect(
        tester
            .getSize(find.byKey(ValueKey('boot-progress-segment-$index')))
            .height,
        16,
        reason:
            'A segment must have painted height, not an invisible zero-height child.',
      );
    }
    expect(
      find.byKey(const ValueKey('boot-tip-Commit to one hand type early.')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1000));
    expect(
      find.byKey(const ValueKey('boot-tip-Commit to one hand type early.')),
      findsOneWidget,
      reason: 'Do not change tips before the player can read them.',
    );
    await tester.pump(const Duration(milliseconds: 3500));
    expect(
      find.byKey(const ValueKey('boot-tip-Wild Jokers bend the rules.')),
      findsOneWidget,
    );

    progress.value = const BootProgress(.84, 'Preparing Sly’s arcade…');
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Preparing Sly’s arcade…'), findsOneWidget);
    expect(tester.takeException(), isNull);

    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BootLoadingScreen(failed: true, onRetry: () => retries++),
      ),
    );
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
