# WILDCARD Astra 6 — phone experiment

Version: **9.0.0+73**. Branch: `agent/astra-6-experiment`.

## Baseline and safety

Built from the pre-Level native Play release **8.5.3+72**, exact commit
`33fa0ab85deb0fc4139478247121cb786b763f81`, not the later Level/House Rules prototype.
No Play Console, production release, Pi, Firebase configuration, or original
phone save is updated by this branch.

Astra installs alongside WILDCARD as `com.nisarg.wildcard.astra`. It has a fresh,
separate local save. It cannot use Internet or Billing permissions; native
Play Games and legacy-save migration are disabled. Dart service entrypoints
also reject online initialization. No real purchases, advertising, analytics,
cloud writes, or leaderboard submissions occur. Daily is offline practice here.
Ad revive, coin-double and mission-refresh offers are removed from this build;
defeats proceed directly to earned results.
Developer tools remain available through the existing Settings code. No developer
Joker or free coin grant is automatically enabled.

## What is different, and why

- **A build from the first hand:** every Normal run offers a free Pair Polisher,
  Flush Fund or Straight Wire. The choice borrows one Joker for the run without
  purchasing its permanent unlock. It does not consume the deck or luck RNG.
- **Opening shops offer actual decisions:** three offers, an extra three earned
  run coins after each of the first three Heats, and one free reroll in each of
  those shops. Ordinary purchase limits stay intact. Free rerolls survive restart.
- **Learning pays:** Normal clear rewards are 8, 8, 10 coins per three-Heat group
  (26 through Heat 3, 104 through Heat 12, plus the existing win bonus).
- **A reachable collection:** Wood is 60 coins below 15 discovered Jokers, then
  100; Gold is 300. Existing rarity probabilities and duplicate protection remain.
- **A visible next goal:** nine one-time Journey goals go from first Heat to
  five wins and 3,000-point hands. Claims and coins save together before feedback.
  There are no goal deadlines or missed-day penalties. Existing dailies/missions
  remain separate; simulations exclude their income and finite Journey rewards.
- **No wagering in the experiment:** progress comes from play, not the old Stake
  Contract. This makes the economy comparison interpretable.
- **A clearer home and run picker:** one primary action, goal progress, readable
  starter-route descriptions, and existing high-quality themed artwork.

Poker mathematics, Joker effects, Heat targets, Normal scoring-animation timing,
and the Daily scoring/economy path are not retuned. This is a run-loop experiment,
not a claim that simulations can prove fun or maximize retention.

## Build

Use Flutter 3.44.7 / Dart 3.12.2 and JDK 17 or compatible installed JDK.

```
cd flutter_app
flutter pub get
flutter test --concurrency=1 --dart-define=WILDCARD_ASTRA_BUILD=true test/app/astra_account_test.dart test/app/astra_presentation_test.dart test/game/astra_progression_test.dart test/release_startup_keep_rule_test.dart
flutter analyze --no-pub
flutter build apk --release --target-platform android-arm64 --dart-define=WILDCARD_ASTRA_BUILD=true
```

Android configuration rejects builds missing the Astra define. All variants use
the experiment-only key at `~/.android/wildcard-astra.keystore`; this is not the
Play signing key. CI restores the same key from the Astra-only GitHub secret so
future Astra APKs can update this experiment without resetting its save. Do not
commit the keystore. Never use the old root Capacitor release workflow for Astra.

The dedicated `astra-android.yml` workflow only runs on this branch and uploads
an ARM64 APK with identity, permission, signing and SHA-256 evidence. It does not
publish to Play or create an AAB.

## Evidence and playtest questions

See [economy experiment](ECONOMY-EXPERIMENT.md) and [raw output](astra-economy.json)
for 300 matched-seed policy runs. Small per-cohort samples and simplified shop
policy limit conclusions; no human win-rate or enjoyment claim is made.

On phone, compare the three starter routes over a few runs. Are decisions clear
before the first shop? Does a lost run still feel worthwhile? Is the next unlock
close enough to care about? Do expert builds have meaningful choices? Those
answers should drive the next revision, not more simultaneous systems or blind
scoring-speed changes.
