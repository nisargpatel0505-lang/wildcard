import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_controller.dart';
import 'app/wildcard_app.dart';
import 'ui/screens/boot_loading_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // WILDCARD's table, card spacing and cinematics are authored for a phone in
  // portrait. Android may still override this on large/foldable displays, so
  // every surface remains responsive, but ordinary phones should not rotate a
  // live hand when the player tilts the device.
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  // Show a branded, animated loading screen immediately, then bootstrap in the
  // background. Bootstrap used to be awaited before runApp, so a slow cold
  // start showed only the frozen native splash with no progress at all.
  runApp(const _BootstrapGate());
}

class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate();

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  AppController? _controller;
  bool _failed = false;
  final ValueNotifier<BootProgress> _progress = ValueNotifier<BootProgress>(
    const BootProgress(.03, 'Opening the table…'),
  );

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => _failed = false);
    _progress.value = const BootProgress(.03, 'Opening the table…');
    try {
      // Hold the loading screen for at least a beat so the load bar reads as
      // intentional rather than flashing for a single frame.
      final results = await Future.wait(<Future<Object?>>[
        AppController.bootstrap(
          onProgress: (fraction, label) {
            if (mounted) {
              _progress.value = BootProgress(fraction, label);
            }
          },
        ),
        Future<void>.delayed(const Duration(milliseconds: 750)),
      ]);
      if (!mounted) return;
      setState(() => _controller = results.first as AppController);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) return WildcardApp(controller: controller);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BootLoadingScreen(
        failed: _failed,
        onRetry: _failed ? _boot : null,
        progress: _progress,
      ),
    );
  }
}
