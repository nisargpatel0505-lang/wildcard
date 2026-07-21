import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_controller.dart';
import 'app/wildcard_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // WILDCARD's table, card spacing and cinematics are authored for a phone in
  // portrait. Android may still override this on large/foldable displays, so
  // every surface remains responsive, but ordinary phones should not rotate a
  // live hand when the player tilts the device.
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  final controller = await AppController.bootstrap();
  runApp(WildcardApp(controller: controller));
}
