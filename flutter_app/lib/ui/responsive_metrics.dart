import 'package:flutter/material.dart';

enum WildcardWindowClass {
  veryShortPhone,
  smallPhone,
  standardPhone,
  tallPhone,
  largePhone,
  foldable,
  tablet,
}

@immutable
class WildcardResponsiveMetrics {
  const WildcardResponsiveMetrics({
    required this.windowClass,
    required this.pagePadding,
    required this.verticalDensity,
    required this.contentMaxWidth,
    required this.columns,
  });

  factory WildcardResponsiveMetrics.from(Size size) {
    final width = size.width;
    final height = size.height;
    final windowClass = width >= 720
        ? WildcardWindowClass.tablet
        : width >= 540
        ? WildcardWindowClass.foldable
        : width >= 410
        ? WildcardWindowClass.largePhone
        : height >= 840
        ? WildcardWindowClass.tallPhone
        : width < 350 || height < 640
        ? WildcardWindowClass.veryShortPhone
        : width < 390
        ? WildcardWindowClass.smallPhone
        : WildcardWindowClass.standardPhone;

    return WildcardResponsiveMetrics(
      windowClass: windowClass,
      pagePadding: switch (windowClass) {
        WildcardWindowClass.veryShortPhone => 6,
        WildcardWindowClass.smallPhone => 8,
        WildcardWindowClass.standardPhone ||
        WildcardWindowClass.tallPhone => 10,
        WildcardWindowClass.largePhone => 12,
        WildcardWindowClass.foldable || WildcardWindowClass.tablet => 16,
      },
      verticalDensity: switch (windowClass) {
        WildcardWindowClass.veryShortPhone => .78,
        WildcardWindowClass.smallPhone => .9,
        _ => 1,
      },
      contentMaxWidth: switch (windowClass) {
        WildcardWindowClass.foldable => 680,
        WildcardWindowClass.tablet => 760,
        _ => double.infinity,
      },
      columns: switch (windowClass) {
        WildcardWindowClass.foldable => 2,
        WildcardWindowClass.tablet => 3,
        _ => 2,
      },
    );
  }

  final WildcardWindowClass windowClass;
  final double pagePadding;
  final double verticalDensity;
  final double contentMaxWidth;
  final int columns;

  bool get isVeryShort => windowClass == WildcardWindowClass.veryShortPhone;
  bool get isCompact =>
      isVeryShort || windowClass == WildcardWindowClass.smallPhone;
  bool get isLarge =>
      windowClass == WildcardWindowClass.foldable ||
      windowClass == WildcardWindowClass.tablet;
}
