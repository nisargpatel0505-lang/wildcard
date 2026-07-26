import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/app/screens/mode_picker_screen.dart';
import 'package:wildcard/domain/account_state.dart';
import 'package:wildcard/ui/wildcard_ui.dart';

void main() {
  const phoneSizes = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(393, 873),
    Size(600, 960),
    Size(800, 1280),
  ];

  for (final size in phoneSizes) {
    testWidgets('Choose Run atmosphere fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: WildcardTheme.build(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: ModePickerScreen(
            account: AccountState(tutorialDone: true, bestClearedHeat: 12),
            onLaunch: (_) {},
            onOpenTutorial: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final background = tester.widget<WildcardBackground>(
        find.byType(WildcardBackground),
      );
      expect(background.room, WildcardRoom.runSetup);
      expect(find.text('CHOOSE RUN'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('run-setup-atmosphere')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('run-setup-sly-silhouette')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('run-setup-floating-suits')),
        findsOneWidget,
      );

      final silhouette = tester.getRect(
        find.byKey(const ValueKey('run-setup-sly-silhouette')),
      );
      expect(silhouette.width, greaterThan(0));
      expect(silhouette.height, greaterThan(0));
      expect(silhouette.overlaps(Offset.zero & size), isTrue);

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(find.text('DEAL THIS RUN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion keeps the setup atmosphere still', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 873);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const WildcardBackground(
          room: WildcardRoom.runSetup,
          runSetupMotionInTests: true,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();

    final suitBefore = tester.getRect(
      find.byKey(const ValueKey('run-setup-suit-0')),
    );
    final slyBefore = tester.getRect(
      find.byKey(const ValueKey('run-setup-sly-silhouette')),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.getRect(find.byKey(const ValueKey('run-setup-suit-0'))),
      suitBefore,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('run-setup-sly-silhouette'))),
      slyBefore,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('setup atmosphere drifts when motion is enabled', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 873);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: WildcardTheme.build(),
        home: const WildcardBackground(
          room: WildcardRoom.runSetup,
          runSetupMotionInTests: true,
          child: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();

    List<double> firstTransform(String key) =>
        tester
            .widget<Transform>(
              find
                  .descendant(
                    of: find.byKey(ValueKey(key)),
                    matching: find.byType(Transform),
                  )
                  .first,
            )
            .transform
            .storage
            .toList();

    final suitBefore = firstTransform('run-setup-suit-0');
    final slyBefore = tester
        .widget<Transform>(find.byKey(const ValueKey('run-setup-sly-motion')))
        .transform
        .storage
        .toList();
    await tester.pump(const Duration(seconds: 3));
    expect(
      firstTransform('run-setup-suit-0'),
      isNot(equals(suitBefore)),
    );
    expect(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('run-setup-sly-motion')),
          )
          .transform
          .storage
          .toList(),
      isNot(equals(slyBefore)),
    );
    expect(tester.takeException(), isNull);
  });
}
