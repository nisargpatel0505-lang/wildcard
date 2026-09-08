# 9.1.1 validation evidence

Initial theme/starter source commit:
`ca981305e3bd63a8a93cf8bca813535e713a077f`. The final phone artifact also includes
the subsequent navigation-contrast follow-up; its exact commit is recorded in
the delivery notes.

## Automated checks

- Flutter analysis: no issues.
- Full suite initially reported 504 passed, 2 skipped and 2 failures. Both
  failures were outdated UI expectations: the Cabinet now includes four free
  previews, and Wardrobe now opens with the free theme studio rather than paid
  items. The corrected Cabinet and Shop tests, plus the adjacent Daily Board
  test, passed in a focused rerun (3 passed). No known failing test remains;
  this is **506 unique passes across the full run and focused rerun**, not a
  claim that a second complete suite was executed.
- Owner-compiled ad/Shop checks: 6 passed with
  `--dart-define=WILDCARD_OWNER_NO_ADS=true`.
- New theme presentation checks: 6 passed, including palette/artwork snapshots,
  selection persistence, motion, reduced motion and route/lifecycle pausing.
- Four home snapshots and the 2-column studio snapshot were visually inspected.
  These are Flutter-rendered test images, not phone performance measurements.
- Independent review found no blocking owner/public ad-separation issue.
  The owner APK guard allows APK assembly but rejects owner bundle/publishing
  tasks. Default public builds retain ads and the existing paid entitlement.
- Final phone-driven contrast follow-up: 7 theme/Shop checks passed, including
  header contrast over worst-case white artwork. The studio golden was updated
  to include the new dark navigation backing; no layout or scoring changed.

## Real-engine starter smoke simulations

The adjacent JSON/JSONL files retain 12 adaptive strategic runs: 6 newcomer and
6 full-collection runs. There were zero invariant/scoring-fidelity failures.
Three instrumentation-parity seed pairs also passed. No new reward/economy
constants were changed. This small sample checks integration, not statistically
reliable win rates, player enjoyment or a final starter-pool balance claim.

The simulation was run against the candidate's working files before committing.
Its `sourceHead` therefore records the preceding commit, with the actual file
blob hashes recorded alongside it. Do not interpret that head as a claim that
the preceding clean commit contained the starter changes.

## Protected remote branches

Verified after pushing the candidate source; none were changed:

- `main`: `5a1a0d0f82a6b25415760bc7a77085a4e4fa3dd1`
- `agent/flutter-v8-native-beta`: `26e0f30f1a7b27ef75d1d5cbd8dab1d83ca3e8de`
- `agent/flutter-v8.2.0-dev14-feel`: `0b3e9fa42b872ac7b65509aa3d3ed67a9b3e2c59`

Phone install and artifact evidence is recorded separately after installation.
No private player save, account data, phone screenshot or signing material is
included here.
