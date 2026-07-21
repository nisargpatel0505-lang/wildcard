import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_controller.dart';
import '../../app/developer_access.dart';
import '../../core/app_constants.dart';
import '../../domain/account_state.dart';
import '../../domain/joker_catalog.dart';
import '../../services/ad_service.dart';
import '../../services/billing_service.dart';
import '../../ui/wildcard_ui.dart';
import 'page_frame.dart';
import 'tutorial_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool busy = false;
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final account = widget.controller.account;
        return WildcardPageFrame(
          title: 'Settings',
          subtitle: 'Phone, account and online services',
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 34),
            children: [
              const ScreenSectionTitle('Game'),
              _switch(
                'Sound effects',
                !account.muted,
                (value) => widget.controller.mutateAccount(
                  (state) => state.muted = !value,
                ),
              ),
              _switch(
                'Background music',
                account.musicOn,
                (value) => widget.controller.mutateAccount(
                  (state) => state.musicOn = value,
                ),
              ),
              _switch(
                'Fast scoring',
                account.speed == ScoringPace.fast,
                (value) => widget.controller.mutateAccount(
                  (state) => state.speed = value
                      ? ScoringPace.fast
                      : ScoringPace.normal,
                ),
                subtitle:
                    'Normal remains readable. Fast shortens pauses without changing results.',
              ),
              if (kDebugMode) ...[
                const ScreenSectionTitle('Developer build'),
                _developerPanel(account),
              ],
              const ScreenSectionTitle('Daily Board'),
              DailyBoardNameEditor(
                accountName: account.playerName,
                signedIn: widget.controller.signedIn,
                disabled: busy,
                onSave: _saveBoardName,
              ),
              const ScreenSectionTitle('Google account & cloud'),
              _statusCard(
                icon: widget.controller.signedIn
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                title: widget.controller.signedIn
                    ? (widget.controller.firebase.user?.displayName ??
                          widget.controller.firebase.user?.email ??
                          'Google player')
                    : 'Guest play',
                subtitle: widget.controller.cloudStatus,
              ),
              const SizedBox(height: 8),
              if (!widget.controller.signedIn)
                WildcardButton(
                  label: 'Sign in with Google',
                  icon: const Icon(Icons.login_rounded),
                  onPressed: busy ? null : _signIn,
                )
              else ...[
                WildcardButton(
                  label: 'Back Up Now',
                  icon: const Icon(Icons.cloud_upload_outlined),
                  onPressed: busy ? null : _cloudSave,
                ),
                const SizedBox(height: 8),
                WildcardButton(
                  label: 'Sign Out',
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: busy ? null : _signOut,
                  variant: WildcardButtonVariant.ghost,
                ),
              ],
              const ScreenSectionTitle('Play services'),
              _serviceStatus(
                'Play Games rankings',
                widget.controller.playGames.signedIn,
                widget.controller.playGames.lastError,
              ),
              const SizedBox(height: 8),
              WildcardButton(
                label: widget.controller.playGames.signedIn
                    ? 'Open Official Rankings'
                    : 'Connect Play Games',
                onPressed: busy ? null : _playGames,
                variant: WildcardButtonVariant.ghost,
              ),
              const SizedBox(height: 8),
              _serviceStatus(
                'Google Play Billing',
                widget.controller.billing.state == BillingState.ready,
                widget.controller.billing.lastError,
              ),
              const SizedBox(height: 8),
              _serviceStatus(
                'Advertising consent',
                widget.controller.ads.state == AdServiceState.ready,
                widget.controller.ads.lastError,
              ),
              if (widget.controller.ads.privacyOptionsRequired) ...[
                const SizedBox(height: 8),
                WildcardButton(
                  label: 'Advertising Privacy Choices',
                  onPressed: busy
                      ? null
                      : () => widget.controller.ads.showPrivacyOptions(),
                  variant: WildcardButtonVariant.ghost,
                ),
              ],
              const ScreenSectionTitle('Privacy & data'),
              WildcardButton(
                label: 'Privacy Policy',
                icon: const Icon(Icons.privacy_tip_outlined),
                onPressed: () => _openUrl(AppConstants.privacyPolicyUrl),
                variant: WildcardButtonVariant.ghost,
              ),
              const SizedBox(height: 8),
              WildcardButton(
                label: 'Account Deletion Information',
                onPressed: () => _openUrl(AppConstants.accountDeletionUrl),
                variant: WildcardButtonVariant.ghost,
              ),
              const SizedBox(height: 8),
              if (widget.controller.signedIn)
                WildcardButton(
                  label: 'Delete Google Account & Cloud Data',
                  onPressed: busy ? null : _confirmDeleteAccount,
                  variant: WildcardButtonVariant.danger,
                ),
              const SizedBox(height: 8),
              WildcardButton(
                label: 'Reset Phone Progress',
                onPressed: busy ? null : _confirmReset,
                variant: WildcardButtonVariant.danger,
              ),
              const SizedBox(height: 16),
              FutureBuilder<PackageInfo>(
                future: _packageInfo,
                builder: (context, snapshot) => Text(
                  snapshot.hasData
                      ? 'WILDCARD v${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                      : 'WILDCARD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.wildcard.creamDim,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _switch(
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    String? subtitle,
  }) => WildcardCard(
    padding: EdgeInsets.zero,
    child: SwitchListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: busy ? null : onChanged,
    ),
  );

  Widget _statusCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) => WildcardCard(
    child: Row(
      children: [
        Icon(icon, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(subtitle, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _serviceStatus(String title, bool ready, Object? error) => _statusCard(
    icon: ready ? Icons.check_circle_outline_rounded : Icons.info_outline,
    title: title,
    subtitle: ready
        ? 'Ready'
        : error == null
        ? 'Not connected yet'
        : 'Unavailable on this install or network',
  );

  Widget _developerPanel(AccountState account) {
    final unlocked = developerToolsUnlocked(account);
    if (!unlocked) {
      return WildcardCard(
        accent: WildcardCardAccent.violet,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LOCAL TEST TOOLS',
              style: TextStyle(fontFamily: 'Bungee', fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              'Available only in a debug APK. Developer changes stay on this test install.',
              style: TextStyle(
                color: context.wildcard.creamDim,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 10),
            WildcardButton(
              key: const Key('open-developer-code'),
              label: 'Enter Developer Code',
              icon: const Icon(Icons.developer_mode_rounded),
              onPressed: busy ? null : _unlockDeveloperTools,
              variant: WildcardButtonVariant.ghost,
            ),
          ],
        ),
      );
    }

    final gauntlet = developerGauntletUnlocked(account);
    return WildcardCard(
      accent: WildcardCardAccent.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.developer_mode_rounded),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'DEVELOPER ACCESS ACTIVE',
                  style: TextStyle(fontFamily: 'Bungee', fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Local testing only. Best Heat and scores are never changed by these buttons.',
            style: TextStyle(color: context.wildcard.creamDim, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _developerAction(
                key: const Key('developer-grant-coins'),
                label: '+5,000 Coins',
                icon: Icons.monetization_on_outlined,
                onPressed: _grantDeveloperCoins,
              ),
              _developerAction(
                key: const Key('developer-toggle-gauntlet'),
                label: gauntlet ? 'Gauntlet: Open' : 'Open Gauntlet',
                icon: Icons.local_fire_department_outlined,
                onPressed: _toggleDeveloperGauntlet,
              ),
              _developerAction(
                label: 'Unlock Jokers',
                icon: Icons.style_outlined,
                onPressed: _unlockDeveloperJokers,
              ),
              _developerAction(
                label: 'Reset Daily',
                icon: Icons.today_outlined,
                onPressed: _resetDeveloperDaily,
              ),
              _developerAction(
                key: const Key('developer-replay-tutorial'),
                label: 'Replay Tutorial',
                icon: Icons.school_outlined,
                onPressed: _replayTutorial,
              ),
              _developerAction(
                key: const Key('developer-reset-first-run'),
                label: 'Reset First-Run Test',
                icon: Icons.restart_alt_rounded,
                onPressed: _resetFirstRunForTesting,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _developerAction({
    Key? key,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) => OutlinedButton.icon(
    key: key,
    onPressed: busy ? null : onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
  );

  Future<void> _unlockDeveloperTools() async {
    if (!kDebugMode) return;
    final input = TextEditingController();
    String? error;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'DEVELOPER CODE',
            style: TextStyle(fontFamily: 'Bungee'),
          ),
          content: TextField(
            key: const Key('developer-code-field'),
            controller: input,
            obscureText: true,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Local tester code',
              errorText: error,
            ),
            onSubmitted: (value) {
              if (developerCodeMatches(value)) {
                Navigator.pop(dialogContext, true);
              } else {
                setDialogState(() => error = 'Invalid code.');
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              key: const Key('unlock-developer-tools'),
              onPressed: () {
                if (developerCodeMatches(input.text)) {
                  Navigator.pop(dialogContext, true);
                } else {
                  setDialogState(() => error = 'Invalid code.');
                }
              },
              child: const Text('UNLOCK'),
            ),
          ],
        ),
      ),
    );
    input.dispose();
    if (accepted != true) return;
    await widget.controller.mutateAccount((state) {
      captureDeveloperBaseline(state);
      state.unknownFields[developerUnlockedField] = true;
      state.unknownFields[developerGauntletField] = true;
    }, syncCloud: false);
    _snack('Developer tools unlocked on this debug install.');
  }

  Future<void> _grantDeveloperCoins() async {
    await _debugMutation((state) {
      final before = state.coins;
      final next = before + 5000;
      state.coins = next > 9999999 ? 9999999 : next;
      final granted = state.coins - before;
      final previous = state.unknownFields[developerCoinGrantField];
      state.unknownFields[developerCoinGrantField] =
          (previous is num ? previous.floor() : 0) + granted;
    });
    _snack('+5,000 testing coins.');
  }

  Future<void> _toggleDeveloperGauntlet() async {
    await _debugMutation((state) {
      state.unknownFields[developerGauntletField] =
          state.unknownFields[developerGauntletField] != true;
    });
    _snack(
      developerGauntletUnlocked(widget.controller.account)
          ? 'Gauntlet testing access open.'
          : 'Gauntlet testing access closed.',
    );
  }

  Future<void> _unlockDeveloperJokers() async {
    await _debugMutation((state) {
      final added = jokerCatalog
          .map((joker) => joker.id)
          .where((id) => !state.unlockedJokerIds.contains(id))
          .toList(growable: false);
      state.unlockedJokerIds.addAll(added);
      final previous = state.unknownFields[developerJokerGrantField];
      state.unknownFields[developerJokerGrantField] = <String>{
        if (previous is List) ...previous.whereType<String>(),
        ...added,
      }.toList(growable: false);
    });
    _snack('All public Jokers unlocked for local testing.');
  }

  Future<void> _resetDeveloperDaily() async {
    await _debugMutation((state) {
      state.dailyRunDate = '';
      state.dailyBest = const DailyBestRecord();
    });
    _snack('Daily attempt reset on this test install.');
  }

  Future<void> _replayTutorial() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TutorialScreen(onComplete: () async {}),
      ),
    );
  }

  Future<void> _resetFirstRunForTesting() async {
    await _debugMutation(resetDeveloperFirstRunState);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            TutorialScreen(onComplete: widget.controller.completeTutorial),
      ),
    );
  }

  Future<void> _debugMutation(void Function(AccountState state) mutation) {
    if (!kDebugMode || !developerToolsUnlocked(widget.controller.account)) {
      return Future<void>.value();
    }
    return widget.controller.mutateAccount(mutation, syncCloud: false);
  }

  Future<void> _signIn() => _run(() async {
    await widget.controller.signInWithGoogle();
    _snack('Google account linked.');
  });

  Future<void> _signOut() => _run(() async {
    await widget.controller.signOut();
    _snack('Signed out. Phone progress remains available.');
  });

  Future<void> _cloudSave() => _run(() async {
    final saved = await widget.controller.cloudSaveNow();
    _snack(
      saved
          ? 'Cloud backup verified.'
          : 'Phone save is safe; cloud will retry.',
    );
  });

  Future<void> _saveBoardName(String name) => _run(() async {
    await widget.controller.mutateAccount(
      (state) => state.playerName = sanitizeDailyBoardName(name),
    );
    _snack('Daily Board name saved as ${sanitizeDailyBoardName(name)}.');
  });

  Future<void> _playGames() => _run(() async {
    if (!widget.controller.playGames.signedIn) {
      final signedIn = await widget.controller.playGames.signIn();
      if (!signedIn) throw StateError('Play Games sign-in was not completed.');
    } else {
      await widget.controller.playGames.showLeaderboard();
    }
  });

  Future<void> _confirmDeleteAccount() async {
    final text = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'DELETE ACCOUNT',
          style: TextStyle(fontFamily: 'Bungee'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This permanently deletes Firebase Authentication and cloud progress. Type DELETE to continue.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: text,
              decoration: const InputDecoration(labelText: 'DELETE'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, text.text.trim() == 'DELETE'),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    text.dispose();
    if (confirmed == true) {
      await _run(() => widget.controller.deleteFirebaseAccountAndData());
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RESET PHONE PROGRESS'),
        content: const Text(
          'Coins, unlocks, cosmetics, stats and the active run on this phone will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESET'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() async {
        await widget.controller.resetLocalProgress();
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _snack(error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openUrl(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

String sanitizeDailyBoardName(String value) {
  final sanitized = value.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();
  return sanitized.length <= 8 ? sanitized : sanitized.substring(0, 8);
}

class DailyBoardNameEditor extends StatefulWidget {
  const DailyBoardNameEditor({
    required this.accountName,
    required this.signedIn,
    required this.onSave,
    this.disabled = false,
    super.key,
  });

  final String accountName;
  final bool signedIn;
  final bool disabled;
  final Future<void> Function(String name) onSave;

  @override
  State<DailyBoardNameEditor> createState() => _DailyBoardNameEditorState();
}

class _DailyBoardNameEditorState extends State<DailyBoardNameEditor> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: sanitizeDailyBoardName(widget.accountName),
    );
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant DailyBoardNameEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = sanitizeDailyBoardName(widget.accountName);
    if (!_focusNode.hasFocus && incoming != _controller.text) {
      _controller.value = TextEditingValue(
        text: incoming,
        selection: TextSelection.collapsed(offset: incoming.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unavailable = widget.disabled || _saving;
    return WildcardCard(
      accent: WildcardCardAccent.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GLOBAL DAILY BOARD NAME',
            style: TextStyle(fontFamily: 'Bungee', fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            widget.signedIn
                ? 'Signed in. This name is shown when you choose to post a Daily Challenge score.'
                : 'Choose a name now. You must sign in with Google before a Daily Challenge score can be posted.',
            style: TextStyle(
              color: context.wildcard.creamDim,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('daily-board-name-field'),
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !unavailable,
                  maxLength: 8,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final sanitized = sanitizeDailyBoardName(newValue.text);
                      return TextEditingValue(
                        text: sanitized,
                        selection: TextSelection.collapsed(
                          offset: sanitized.length,
                        ),
                      );
                    }),
                  ],
                  decoration: InputDecoration(
                    labelText: '1–8 letters or numbers',
                    hintText: 'SLYACE',
                    errorText: _error,
                    counterText: '',
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('save-daily-board-name'),
                style: FilledButton.styleFrom(minimumSize: const Size(72, 52)),
                onPressed: unavailable ? null : _save,
                child: Text(_saving ? '…' : 'SAVE'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = sanitizeDailyBoardName(_controller.text);
    if (name.isEmpty) {
      setState(() => _error = 'Enter at least 1 letter or number.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.onSave(name);
      if (mounted) _focusNode.unfocus();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
