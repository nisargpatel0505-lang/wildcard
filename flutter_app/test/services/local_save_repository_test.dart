import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildcard/core/app_constants.dart';
import 'package:wildcard/services/local_save_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy boolean cannot acknowledge the current privacy revision',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.privacyAcceptedKey: true,
      });

      final repository = await LocalSaveRepository.open();

      expect(repository.privacyAccepted, isFalse);
    },
  );

  test('only the current versioned privacy marker is accepted', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.privacyAcceptedKey: jsonEncode(<String, Object>{
        'version': AppConstants.privacyPolicyVersion,
        'acceptedAt': 1,
      }),
    });

    final repository = await LocalSaveRepository.open();

    expect(repository.privacyAccepted, isTrue);
  });

  test('an older privacy revision requires acknowledgement again', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.privacyAcceptedKey: jsonEncode(<String, Object>{
        'version': '2026-07-19-v1',
        'acceptedAt': 1,
      }),
    });

    final repository = await LocalSaveRepository.open();

    expect(repository.privacyAccepted, isFalse);
  });
}
