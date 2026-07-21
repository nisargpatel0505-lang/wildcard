import 'package:flutter/material.dart';

import '../../ui/wildcard_ui.dart';
import 'page_frame.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({required this.onComplete, super.key});

  final Future<void> Function() onComplete;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final controller = PageController();
  var page = 0;
  var finishing = false;

  static const steps = <(IconData, String, String)>[
    (
      Icons.style_rounded,
      'Make a poker hand',
      'Select up to five cards. Only cards that form the named hand add rank value; kickers score nothing.',
    ),
    (
      Icons.calculate_outlined,
      'Read the score',
      'The hand base plus 60% of scoring-card rank becomes Value. Jokers and enhancements build Multiplier. Value × Multiplier is your score.',
    ),
    (
      Icons.auto_awesome_rounded,
      'Build a Joker engine',
      'Jokers trigger in order. Their short description stays visible, and a soft highlight shows exactly which effect changed the score.',
    ),
    (
      Icons.local_fire_department_rounded,
      'Beat the Heat',
      'Reach the target before Plays run out. Every third Endless Heat adds a modifier, and THE HOUSE waits at Heat 12.',
    ),
    (
      Icons.storefront_rounded,
      'Use the shop',
      'Spend run coins between Heats on Jokers and one of each offered supply. Supply prices rise for the rest of that run.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return WildcardPageFrame(
      title: "Sly's Lesson",
      subtitle: 'Five quick rules. Then the table is yours.',
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: controller,
              itemCount: steps.length,
              onPageChanged: (value) => setState(() => page = value),
              itemBuilder: (context, index) {
                final step = steps[index];
                return Semantics(
                  container: true,
                  label: 'Rule ${index + 1} of ${steps.length}',
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    child: Center(
                      child: WildcardPanel(
                        borderColor: context.wildcard.violet,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              step.$1,
                              size: 62,
                              color: context.wildcard.gold,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              step.$2.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.wildcard.mint,
                                fontFamily: 'Bungee',
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              step.$3,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: WildcardButton(
              label: page == steps.length - 1
                  ? (finishing ? 'Saving…' : 'Deal Me In')
                  : 'Next Rule',
              onPressed: finishing
                  ? null
                  : () async {
                      if (page < steps.length - 1) {
                        await controller.nextPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        );
                      } else {
                        setState(() => finishing = true);
                        try {
                          await widget.onComplete();
                          if (!mounted) return;
                          Navigator.pop(this.context);
                        } catch (_) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'The lesson could not be saved. Please try again.',
                              ),
                            ),
                          );
                          setState(() => finishing = false);
                        }
                      }
                    },
              variant: WildcardButtonVariant.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
