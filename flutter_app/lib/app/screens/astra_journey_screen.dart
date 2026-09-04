import 'package:flutter/material.dart';

import '../../domain/astra_journey.dart';
import '../../ui/wildcard_ui.dart';
import '../../ui/widgets/wildcard_toast.dart';
import 'page_frame.dart';

/// A visible ladder of finite rewards, then long-term feats of mastery.
/// The account layer checks and persists every claim before the UI celebrates it.
class AstraJourneyScreen extends StatefulWidget {
  const AstraJourneyScreen({
    required this.steps,
    required this.onClaim,
    super.key,
  });

  final List<AstraJourneyStep> steps;
  final Future<int> Function(String) onClaim;

  @override
  State<AstraJourneyScreen> createState() => _AstraJourneyScreenState();
}

class _AstraJourneyScreenState extends State<AstraJourneyScreen> {
  final Set<String> _claimedThisVisit = {};
  String? _claiming;

  bool _isClaimed(AstraJourneyStep step) =>
      step.claimed || _claimedThisVisit.contains(step.id);

  @override
  Widget build(BuildContext context) {
    final tokens = context.wildcard;
    final claimed = widget.steps.where(_isClaimed).length;
    return PopScope(
      canPop: _claiming == null,
      child: WildcardPageFrame(
        title: 'Your Journey',
        subtitle: 'Small wins. Stronger builds. Something worth chasing.',
        surface: WildcardUiSurface.cabinet,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            WildcardPanel(
              borderColor: tokens.mint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$claimed / ${widget.steps.length} MILESTONES CLAIMED',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: tokens.mint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'One good decision at a time.',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Each reward is earned once. Try another starter, build a new engine, and push your personal best.',
                    style: TextStyle(
                      color: tokens.creamDim,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            for (var index = 0; index < widget.steps.length; index++) ...[
              _step(context, widget.steps[index], index),
              const SizedBox(height: 10),
            ],
            Text(
              'Your earned coins can open Vaults and collect new looks. A fresh Normal run always includes a free starter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tokens.creamDim,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(BuildContext context, AstraJourneyStep step, int index) {
    final tokens = context.wildcard;
    final claimed = _isClaimed(step);
    final ready = step.ready && !claimed;
    final accent = ready
        ? tokens.gold
        : claimed
        ? tokens.mint
        : tokens.violet;
    return Container(
      key: ValueKey('astra-journey-${step.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panelStrong.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: accent.withValues(alpha: ready ? .95 : .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 31,
                height: 31,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: claimed
                    ? Icon(Icons.check_rounded, color: accent, size: 20)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.title,
                  style: TextStyle(
                    color: tokens.cream,
                    fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+${step.rewardCoins}',
                style: TextStyle(
                  color: tokens.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            step.description,
            style: TextStyle(color: tokens.creamDim, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: claimed
                        ? 1
                        : step.progress.clamp(0.0, 1.0).toDouble(),
                    minHeight: 5,
                    backgroundColor: accent.withValues(alpha: .13),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                claimed ? 'CLAIMED' : step.progressLabel,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (ready) ...[
            const SizedBox(height: 12),
            WildcardButton(
              key: ValueKey('astra-claim-${step.id}'),
              label: _claiming == step.id
                  ? 'Saving reward…'
                  : 'Claim ${step.rewardCoins} coins',
              onPressed: _claiming == null ? () => _claim(step) : null,
              variant: WildcardButtonVariant.primary,
              minHeight: 50,
              fontFamily: 'SpaceGrotesk',
              fontSize: 14,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _claim(AstraJourneyStep step) async {
    if (_claiming != null) return;
    setState(() => _claiming = step.id);
    try {
      final reward = await widget.onClaim(step.id);
      if (!mounted) return;
      if (reward > 0) {
        setState(() => _claimedThisVisit.add(step.id));
        showWildcardToast(context, '${step.title} · +$reward coins');
      } else {
        showWildcardToast(
          context,
          'This reward has already been claimed or is not ready yet.',
        );
      }
    } catch (_) {
      if (mounted) {
        showWildcardToast(
          context,
          'Could not save the reward. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = null);
    }
  }
}
