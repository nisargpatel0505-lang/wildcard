import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release build preserves Room database constructors', () {
    final buildFile =
        File('android/app/build.gradle.kts').readAsStringSync();
    final rulesFile = File('android/app/proguard-rules.pro').readAsStringSync();

    expect(buildFile, contains('proguardFiles("proguard-rules.pro")'));
    expect(
      rulesFile,
      contains('-keep class * extends androidx.room.RoomDatabase'),
    );
    expect(rulesFile, contains('public <init>();'));
  });
}
