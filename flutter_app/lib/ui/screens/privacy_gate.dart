import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../widgets/wildcard_button.dart';
import '../widgets/wildcard_panel.dart';
import '../wildcard_theme.dart';

/// Mandatory first-launch privacy gate recovered from the v7.1.0 phone build.
///
/// Place this last in a [Stack] above the app while acceptance is false. The
/// opaque barrier and [PopScope] keep all game and service controls locked.
class WildcardPrivacyGate extends StatelessWidget {
  const WildcardPrivacyGate({
    required this.onAccept,
    required this.onOpenPrivacyPolicy,
    this.accepting = false,
    super.key,
  });

  final VoidCallback onAccept;
  final VoidCallback onOpenPrivacyPolicy;
  final bool accepting;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return PopScope(
      canPop: false,
      child: Material(
        color: const Color(0xFC03050E),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          scopesRoute: true,
          namesRoute: true,
          label: 'Privacy before play',
          child: SafeArea(
            minimum: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 620;
                return Center(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: WildcardPanel(
                        borderColor: tokens.violet,
                        borderWidth: 3,
                        radius: compact ? 18 : 22,
                        padding: EdgeInsets.all(compact ? 17 : 24),
                        child: FocusTraversalGroup(
                          policy: OrderedTraversalPolicy(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  'PRIVACY BEFORE PLAY',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: tokens.gold,
                                    fontFamily: 'Bungee',
                                    fontSize: compact ? 20 : 24,
                                    height: 1.12,
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 10 : 14),
                              _PrivacyParagraph(
                                compact: compact,
                                child: const TextSpan(
                                  text:
                                      'Before WILDCARD can open your account, connect online services, load advertising or send anonymous aggregate counters, please read and accept the current Privacy Policy.',
                                ),
                              ),
                              SizedBox(height: compact ? 8 : 12),
                              _PrivacyParagraph(
                                compact: compact,
                                child: const TextSpan(
                                  text:
                                      'The game stores progress on this device. Google sign-in, cloud backup, Play Games, advertising and purchases are optional services described in the policy.',
                                ),
                              ),
                              SizedBox(height: compact ? 8 : 12),
                              _PolicyLink(onTap: onOpenPrivacyPolicy),
                              SizedBox(height: compact ? 8 : 12),
                              _PrivacyParagraph(
                                compact: compact,
                                child: const TextSpan(
                                  text:
                                      'Acceptance is not pre-selected. If you do not accept, close the app; the game and its online services will remain locked.',
                                ),
                              ),
                              SizedBox(height: compact ? 14 : 18),
                              WildcardButton(
                                label: accepting
                                    ? 'Accepting…'
                                    : 'I have read and accept',
                                icon: accepting
                                    ? SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: tokens.cream,
                                        ),
                                      )
                                    : const Icon(Icons.verified_user_outlined),
                                onPressed: accepting ? null : onAccept,
                                minHeight: 54,
                                fontSize: compact ? 12 : 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyParagraph extends StatelessWidget {
  const _PrivacyParagraph({required this.child, required this.compact});

  final InlineSpan child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      child,
      style: TextStyle(
        color: context.wildcard.creamDim,
        fontFamily: 'SpaceGrotesk',
        fontSize: compact ? 12.3 : 14,
        height: compact ? 1.42 : 1.55,
      ),
    );
  }
}

class _PolicyLink extends StatefulWidget {
  const _PolicyLink({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_PolicyLink> createState() => _PolicyLinkState();
}

class _PolicyLinkState extends State<_PolicyLink> {
  late final TapGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = TapGestureRecognizer()..onTap = widget.onTap;
  }

  @override
  void didUpdateWidget(covariant _PolicyLink oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recognizer.onTap = widget.onTap;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Semantics(
      link: true,
      label: 'Read the full WILDCARD Privacy Policy',
      child: Text.rich(
        TextSpan(
          text: 'Read the full WILDCARD Privacy Policy',
          recognizer: _recognizer,
          style: TextStyle(
            color: tokens.mint,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: tokens.mint.withValues(alpha: 0.7),
          ),
        ),
        style: const TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }
}
