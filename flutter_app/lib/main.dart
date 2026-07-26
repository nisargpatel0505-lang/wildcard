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

class _BootstrapGateState extends State<_BootstrapGate>
    with SingleTickerProviderStateMixin {
  AppController? _controller;
  bool _failed = false;
  int _bootAttempt = 0;
  final ValueNotifier<BootProgress> _progress = ValueNotifier<BootProgress>(
    const BootProgress(.03, 'Opening the table…'),
  );
  late final AnimationController _visualProgress = AnimationController(
    vsync: this,
    value: .02,
    // Reduced Motion removes movement inside the boot screen, but it must not
    // collapse the reading time of the loading sequence.
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final attempt = ++_bootAttempt;
    if (_failed || _controller != null) {
      setState(() {
        _failed = false;
        _controller = null;
      });
    }
    _visualProgress
      ..stop()
      ..value = .02;
    _progress.value = const BootProgress(.03, 'Opening the table…');
    try {
      // The visible timeline is deliberately independent of the very fast
      // local bootstrap milestones. It reaches 90% over 1.8 seconds, waits
      // there if recovery is genuinely slow, then ticks through the final
      // segment only when the controller is ready.
      final results = await Future.wait(<Future<Object?>>[
        AppController.bootstrap(
          onProgress: (fraction, label) {
            if (mounted && attempt == _bootAttempt) {
              // Bootstrap often reaches its final callback in a few
              // milliseconds. Keep the last real milestone visible until the
              // presentation timeline catches up instead of announcing
              // "Ready" over an almost-empty bar.
              if (fraction < 1) {
                _progress.value = BootProgress(fraction, label);
              }
            }
          },
        ),
        _visualProgress
            .animateTo(
              .90,
              duration: const Duration(milliseconds: 1800),
              curve: Curves.easeInOutCubic,
            )
            .orCancel,
      ]);
      if (!mounted || attempt != _bootAttempt) return;
      _progress.value = const BootProgress(.90, 'Finalising the table…');
      await _visualProgress
          .animateTo(
            1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .orCancel;
      _progress.value = const BootProgress(1, 'The table is ready.');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted || attempt != _bootAttempt) return;
      setState(() => _controller = results.first as AppController);
    } catch (_) {
      if (mounted && attempt == _bootAttempt) {
        _visualProgress.stop();
        setState(() => _failed = true);
      }
    }
  }

  @override
  void dispose() {
    _bootAttempt++;
    _visualProgress.dispose();
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
        visualProgress: _visualProgress,
      ),
    );
  }
}
