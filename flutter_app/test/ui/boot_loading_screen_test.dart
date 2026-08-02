import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/ui/screens/boot_loading_screen.dart';

void main() {
  testWidgets('phone boot is branded, centered and readable at 320x568', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    final progress = ValueNotifier<BootProgress>(
      const BootProgress(.22, 'Checking old progress…'),
    );
    addTearDown(progress.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: BootLoadingScreen(
          progress: progress,
          visualProgress: const AlwaysStoppedAnimation<double>(.375),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('boot-palace-background')), findsOneWidget);
    expect(find.byKey(const Key('boot-palace-kicker')), findsOneWidget);
    expect(find.text('SLY’S PALACE'), findsOneWidget);
    expect(find.byKey(const Key('boot-logo-image')), findsOneWidget);
    expect(find.byKey(const Key('boot-logo-fallback')), findsNothing);
    expect(find.byKey(const Key('boot-progress-panel')), findsOneWidget);
    expect(find.text('Checking old progress…'), findsOneWidget);
    expect(find.text('38%'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final surface = tester.getRect(
      find.byKey(const ValueKey('wildcard-surface-loading')),
    );
    final logo = tester.getRect(find.byKey(const Key('boot-logo-image')));
    final panel = tester.getRect(find.byKey(const Key('boot-progress-panel')));
    final bar = tester.getRect(
      find.byKey(const Key('boot-segmented-progress')),
    );
    expect(logo.center.dy, closeTo(surface.center.dy, 1));
    expect(logo.width / logo.height, greaterThan(2.9));
    expect(panel.left, greaterThanOrEqualTo(surface.left));
    expect(panel.right, lessThanOrEqualTo(surface.right));
    expect(panel.bottom, lessThanOrEqualTo(surface.bottom));
    expect(bar.height, 18);

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
    final partial = tester.widget<FractionallySizedBox>(
      find.byKey(const ValueKey('boot-progress-fill-4')),
    );
    expect(partial.widthFactor, closeTo(.5, .001));
    expect(
      find.byKey(const ValueKey('boot-tip-Commit to one hand type early.')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byKey(const ValueKey('boot-tip-Wild Jokers bend the rules.')),
      findsOneWidget,
    );

    progress.value = const BootProgress(.84, 'Preparing Sly’s arcade…');
    await tester.pump();
    expect(find.text('Preparing Sly’s arcade…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('segmented track exposes smooth partial progress', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    final progress = ValueNotifier<BootProgress>(
      const BootProgress(.10, 'Opening the table…'),
    );
    addTearDown(progress.dispose);

    await tester.pumpWidget(
      MaterialApp(home: BootLoadingScreen(progress: progress)),
    );
    await tester.pump();

    progress.value = const BootProgress(.4125, 'Dealing the first hand…');
    await tester.pump();

    expect(find.text('41%'), findsOneWidget);
    expect(
      tester
          .widget<FractionallySizedBox>(
            find.byKey(const ValueKey('boot-progress-fill-4')),
          )
          .widthFactor,
      closeTo(.95, .001),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failure recovery stays inside a small phone safe area', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BootLoadingScreen(failed: true, onRetry: () => retries++),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('boot-failure-panel')), findsOneWidget);
    expect(find.text('TABLE LOCKED'), findsOneWidget);
    expect(find.textContaining('local save is safe'), findsOneWidget);
    final surface = tester.getRect(
      find.byKey(const ValueKey('wildcard-surface-loading')),
    );
    final panel = tester.getRect(find.byKey(const Key('boot-failure-panel')));
    expect(panel.left, greaterThanOrEqualTo(surface.left));
    expect(panel.right, lessThanOrEqualTo(surface.right));
    expect(panel.bottom, lessThanOrEqualTo(surface.bottom));

    await tester.tap(find.text('RETRY'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'logo stays screen-centred while controls respect system insets',
    (tester) async {
      await _setPhoneSize(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 568),
              padding: EdgeInsets.only(top: 28, bottom: 24),
            ),
            child: BootLoadingScreen(
              visualProgress: AlwaysStoppedAnimation<double>(.5),
            ),
          ),
        ),
      );
      await tester.pump();

      final surface = tester.getRect(
        find.byKey(const ValueKey('wildcard-surface-loading')),
      );
      final logo = tester.getRect(find.byKey(const Key('boot-logo-image')));
      final kicker = tester.getRect(
        find.byKey(const Key('boot-palace-kicker')),
      );
      final panel = tester.getRect(
        find.byKey(const Key('boot-progress-panel')),
      );
      expect(logo.center.dy, closeTo(surface.center.dy, 1));
      expect(kicker.top, greaterThanOrEqualTo(28));
      expect(panel.bottom, lessThanOrEqualTo(568 - 24));
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _setPhoneSize(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(320, 568));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}
