import 'package:flutter/material.dart';

import '../../ui/widgets/wildcard_toast.dart';
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

  static const steps = <_TutorialStep>[
    _TutorialStep(
      icon: Icons.local_fire_department_rounded,
      expression: SlyExpression.idle,
      title: 'Clear the table',
      speech:
          'Twelve Heats stand between you and the crown. Read the target before you spend a play.',
      body:
          'Reach each Heat target before your Plays run out. Beat Heat 12 to win the main run, then you may continue into Endless.',
    ),
    _TutorialStep(
      icon: Icons.style_rounded,
      expression: SlyExpression.impressed,
      title: 'Build a poker hand',
      speech:
          'You hold nine cards. Select up to five, then play them or discard the cards that do not fit your plan.',
      body:
          'Only cards that form the named poker hand add rank value. Kickers score nothing. Discarded cards stay out until the next Heat.',
    ),
    _TutorialStep(
      icon: Icons.calculate_outlined,
      expression: SlyExpression.thoughtful,
      title: 'Read the score',
      speech:
          'Value gives the hand weight. Multiplier makes it dangerous. Watch both climb during scoring.',
      body:
          'Value = hand base + 60% of scoring-card ranks. Jokers and enhancements build Multiplier. Value × Multiplier is the final score.',
    ),
    _TutorialStep(
      icon: Icons.auto_awesome_rounded,
      expression: SlyExpression.triumphant,
      title: 'Build one engine',
      speech:
          'Jokers trigger in order. Buy effects that support the same hand instead of collecting unrelated bonuses.',
      body:
          'Between Heats, spend run coins on Jokers and supplies. Supplies rise in price for the rest of the run, while held coins earn interest.',
    ),
    _TutorialStep(
      icon: Icons.redeem_rounded,
      expression: SlyExpression.angry,
      title: 'Your starter table',
      speech:
          'I will sit through your first run. Use Copper Chip and Pair Polisher, then prove you can build from there.',
      body:
          'Finishing this lesson permanently unlocks 10 starter Jokers and grants 200 account coins. Your first Normal run includes two clear starter effects and table coaching.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = steps[page];
    final size = MediaQuery.sizeOf(context);
    final compact = size.width <= 340 || size.height <= 650;
    final slySize = compact ? 72.0 : 90.0;
    return WildcardPageFrame(
      title: "Sly's Lesson",
      subtitle: 'Five quick rules. Then the table is yours.',
      surface: WildcardUiSurface.tutorial,
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Padding(
              key: ValueKey<int>(page),
              padding: EdgeInsets.fromLTRB(
                compact ? 10 : 14,
                6,
                compact ? 10 : 14,
                5,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SlySprite(
                    expression: step.expression,
                    size: slySize,
                    borderRadius: 14,
                    semanticLabel: 'Sly explains rule ${page + 1}',
                    // Keep the lesson calm and allow accessibility/widget
                    // checks to settle. Sly's reactive motion remains active
                    // at the live table where it communicates scoring events.
                    animate: false,
                  ),
                  SizedBox(width: compact ? 7 : 9),
                  Expanded(
                    child: Container(
                      constraints: BoxConstraints(minHeight: slySize),
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 10 : 13,
                        vertical: compact ? 8 : 11,
                      ),
                      decoration: BoxDecoration(
                        color: context.wildcard.cream,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.wildcard.violet,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        step.speech,
                        maxLines: compact ? 6 : null,
                        overflow: compact
                            ? TextOverflow.ellipsis
                            : TextOverflow.visible,
                        style: TextStyle(
                          color: context.wildcard.ink,
                          fontSize: compact ? 12.5 : 13.5,
                          fontWeight: FontWeight.w500,
                          height: 1.28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              key: const Key('tutorial-pages'),
              controller: controller,
              itemCount: steps.length,
              onPageChanged: (value) => setState(() => page = value),
              itemBuilder: (context, index) {
                final item = steps[index];
                return Semantics(
                  container: true,
                  label: 'Rule ${index + 1} of ${steps.length}',
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    child: WildcardPanel(
                      borderColor: context.wildcard.violet,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 48,
                            color: context.wildcard.gold,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.title.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.wildcard.mint,
                              fontFamily: 'Bungee',
                              fontSize: 18,
                              height: 1.08,
                            ),
                          ),
                          const SizedBox(height: 11),
                          Text(
                            item.body,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, height: 1.42),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Semantics(
            label: 'Tutorial progress, rule ${page + 1} of ${steps.length}',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < steps.length; index++)
                  AnimatedContainer(
                    key: Key('tutorial-dot-$index'),
                    duration: const Duration(milliseconds: 160),
                    width: index == page ? 22 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == page
                          ? context.wildcard.gold
                          : context.wildcard.line,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 16),
            child: Row(
              children: [
                if (page > 0) ...[
                  Expanded(
                    child: WildcardButton(
                      key: const Key('tutorial-back'),
                      label: 'Back',
                      onPressed: finishing ? null : _previous,
                      variant: WildcardButtonVariant.ghost,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  flex: page > 0 ? 2 : 1,
                  child: WildcardButton(
                    key: const Key('tutorial-next'),
                    label: page == steps.length - 1
                        ? (finishing ? 'Saving…' : 'Claim Gift & Choose Run')
                        : 'Next Rule',
                    onPressed: finishing ? null : _next,
                    variant: WildcardButtonVariant.primary,
                    fontSize: page == steps.length - 1 ? 11 : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _previous() => controller.previousPage(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOut,
  );

  Future<void> _next() async {
    if (page < steps.length - 1) {
      await controller.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }
    setState(() => finishing = true);
    try {
      await widget.onComplete();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      showWildcardToast(
        context,
        'The lesson could not be saved. Please try again.',
      );
      setState(() => finishing = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _TutorialStep {
  const _TutorialStep({
    required this.icon,
    required this.expression,
    required this.title,
    required this.speech,
    required this.body,
  });

  final IconData icon;
  final SlyExpression expression;
  final String title;
  final String speech;
  final String body;
}
