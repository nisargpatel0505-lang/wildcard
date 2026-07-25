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
      MaterialApp(home: BootLoadingScreen(progress: progress)),
    );
    expect(find.text('Checking old progress…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    progress.value = const BootProgress(.84, 'Preparing Sly’s arcade…');
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Preparing Sly’s arcade…'), findsOneWidget);
    expect(tester.takeException(), isNull);

    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BootLoadingScreen(
          failed: true,
          onRetry: () => retries++,
        ),
      ),
    );
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
