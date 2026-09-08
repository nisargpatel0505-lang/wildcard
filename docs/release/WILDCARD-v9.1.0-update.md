# WILDCARD 9.1.0 — official Astra update

Build 74, package `com.nisarg.wildcard`, branch `release/v9.1.0-astra`.

This update brings the owner's approved Astra experiment into the official
native app. It is based on the existing Play 8.5.3 release, including its
release-startup fix. The separate Level/House Rules prototype is not included.

## Play and presentation

- The Astra home has a single Play/Continue action, visible Journey progress,
  a compact wallet and direct Vault, Shop, Cabinet and Missions navigation.
- Every new Normal run offers a free loan of Pair Polisher, Flush Fund or
  Straight Wire. No permanent discovery is purchased or removed by this choice.
- The first three shops have three Joker offers, one free reroll and an extra
  three run coins per clear. Free-reroll use persists through restart.
- The run picker keeps its Deal button visible while its content scrolls.
  Tutorial completion, Daily eligibility and Gauntlet gates remain effective.
- Existing themes, illustrated backgrounds, table styles, card artwork, Sly
  reactions and scoring presentation are retained from the approved build.

## Earned economy

| Mode | New direct account rewards |
| --- | --- |
| Normal | 4 per clear at Heats 1–3, 7 at 4–6, 10 at 7–9, 13 at 10–12; +20 once for Heat 12: **122 total** |
| Gauntlet | Same first eight clear rewards, +10 once for completion: **63 total** |
| Endless | +13 per clear beyond Heat 12; no repeated completion multiplier |
| Daily | Existing mission/achievement rewards; no new direct run or board-prize payout |

Wood Vaults cost **60** below 15 discovered public Jokers, then **100**. Gold
costs **300**. Duplicate protection and odds from the remaining pool are intact.
Journey adds nine once-only milestones worth 780 coins in total. Existing
players can claim milestones they have already earned; the durable claim ledger
prevents claiming them again after reopening or syncing.

New stake wagers are removed. Existing saved stake contracts settle at their
original terms. Optional run-end ads grant up to **25** bonus coins, clearly
labelled, rather than doubling a whole deep run. Coin-reward ads retain the
shared five-per-day limit. Forced-ad removal ownership is preserved.

The shop now presents the three smaller existing coin products (250, 600 and
1,600) plus Remove Forced Ads. The 3,600 and 8,500 bundles are hidden to reduce
collection bypass. All five historical product IDs remain valid for verified
delivery and recovery at their original quantities. Prices still come from
Google Play's localized offers. The research proposal for new 300/600/1,500
products is not a live catalogue change.

## Save and service compatibility

The official app keeps its original package, certificate and save keys. On its
first upgraded launch it stores one local recovery snapshot of existing raw
account/run/owner/privacy data before migration or normalization. Older WebView
players retain the original Capacitor migration path. A failed save now rolls
back the in-memory reward claim so a retry cannot silently skip payment.

Coins, purchased entitlements, collections, theme selections, tutorial progress,
scores and active runs are preserved. Journey coins and claims use the normal
cloud save path. Firebase, billing, ads, Play Games and Daily Board services use
their existing consent gates. Official builds reject the offline Astra define,
and release developer-state cleanup remains enabled.

The separately installed `com.nisarg.wildcard.astra` app retains its own save.
There is no automatic cross-app merge or replacement of the official wallet.

## Verification

- 3,000 fresh-seed native engine runs across eight cohorts; zero invariant,
  scorer-fidelity or reward-formula failures. The 40-run pilot is separate.
- The previous 7,550-run study and the complete new raw data are preserved.
- Full regression run: 469 passed, two experiment-only skips, three outdated
  Vault price assertions. Those assertions were corrected to the new prices;
  all 17 Vault acquisition tests then passed, retaining odds and idempotency
  coverage. Targeted save and presentation suites also passed.
- Presentation coverage: 320×568, 375×812 and 393×873 at normal and 1.3× text,
  including all home actions, free starter choices and tutorial/Daily gates.
- Static Flutter analysis: no issues found.

Device installation, packaged signatures and the closed-testing publication
result are recorded separately in the delivery evidence after verification.

## Reproduction

Use Flutter 3.44.7 / Dart 3.12.2 and the existing official signing files kept
outside Git. In `flutter_app/`, run:

```sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --concurrency=2
flutter build apk --release --no-pub
flutter build appbundle --release --no-pub
```

Economy source, seed results and confidence intervals are in
`docs/release/v9.1.0-economy/`. Bot outcomes estimate affordability, not human
enjoyment, retention or willingness to pay. The remaining observed early-exit
advantage (at most 1.069× in the modeled scenarios) is a playtest diagnostic.
