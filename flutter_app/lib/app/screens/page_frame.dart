import 'package:flutter/material.dart';

import '../../ui/wildcard_ui.dart';

class WildcardPageFrame extends StatelessWidget {
  const WildcardPageFrame({
    required this.title,
    required this.child,
    this.subtitle,
    this.room = WildcardRoom.themedHome,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final WildcardRoom room;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    return Scaffold(
      backgroundColor: tokens.ink,
      body: WildcardBackground(
        room: room,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 12, 4),
                child: Row(
                  children: [
                    WildcardSquareButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      semanticLabel: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                      size: 50,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.gold,
                              fontFamily: 'Bungee',
                              fontSize: 22,
                              height: 1.05,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.creamDim,
                                fontSize: 12,
                                height: 1.25,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class ScreenSectionTitle extends StatelessWidget {
  const ScreenSectionTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: context.wildcard.gold,
          fontFamily: 'Bungee',
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    ),
  );
}
