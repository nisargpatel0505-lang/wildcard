import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildcard/ui/effects_profile.dart';
import 'package:wildcard/ui/responsive_metrics.dart';

void main() {
  test('required Android sizes resolve to explicit responsive classes', () {
    expect(
      WildcardResponsiveMetrics.from(const Size(320, 568)).windowClass,
      WildcardWindowClass.veryShortPhone,
    );
    expect(
      WildcardResponsiveMetrics.from(const Size(360, 640)).windowClass,
      WildcardWindowClass.smallPhone,
    );
    expect(
      WildcardResponsiveMetrics.from(const Size(393, 873)).windowClass,
      WildcardWindowClass.tallPhone,
    );
    expect(
      WildcardResponsiveMetrics.from(const Size(412, 915)).windowClass,
      WildcardWindowClass.largePhone,
    );
    expect(
      WildcardResponsiveMetrics.from(const Size(600, 960)).windowClass,
      WildcardWindowClass.foldable,
    );
    final tablet = WildcardResponsiveMetrics.from(const Size(800, 1280));
    expect(tablet.windowClass, WildcardWindowClass.tablet);
    expect(tablet.columns, 3);
    expect(tablet.contentMaxWidth, lessThan(800));
  });

  testWidgets('effects budget follows screen class and reduced motion', (
    tester,
  ) async {
    EffectsProfile? profile;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 568)),
          child: Builder(
            builder: (context) {
              profile = EffectsProfile.resolve(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(profile?.quality, EffectsQuality.reduced);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(412, 915),
            disableAnimations: true,
          ),
          child: Builder(
            builder: (context) {
              profile = EffectsProfile.resolve(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(profile?.quality, EffectsQuality.batterySaver);
    expect(profile?.particleScale, 0);
    expect(profile?.backgroundMotion, isFalse);
  });
}
