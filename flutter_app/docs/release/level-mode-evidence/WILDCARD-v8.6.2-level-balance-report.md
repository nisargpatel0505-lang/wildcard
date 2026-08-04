# WILDCARD v8.6.2 Level Mode balance evidence

## Outcome

The shipping Flutter Level Mode catalog was rebuilt after applying the chapter
hand/discard budget caps. Score targets were measured with the native
`LevelSimulationHarness`, using the best result from the deterministic
`handRanking` and `adaptivePlanning` policies for each authored layout.

The supplied redesign CSV was retained as a design specification, not copied
directly into production: 87 of its 100 `oldTarget` values did not match the
current catalog. Fresh native results therefore determine the shipped score
targets.

## Player-facing rules preserved

- The 27 explicitly objective-only tables retain `target_score: 0`.
- Level 11 completes immediately when the third Pair is scored.
- No hidden score floor was added to an objective-only table.
- Resource bands act as ceilings and never grant more hands or discards than an
  authored table previously allowed.
- Copy for Levels 50, 80 and 91 now states the effective play/discard budget.

## Final deterministic measurements

- Native policy attempts: **2,920** across **1,460** authored layouts.
- Score-bearing mean absolute clear-rate error: **6.00 percentage points**.
- Score-bearing maximum clear-rate error: **13.67 percentage points**.
- Score-bearing rate gate: **passed** (`mean < 10pp`, `max < 20pp`).
- Level 100: target **4,585**, **4** hands, **2** discards, measured clear rate
  **25%** against a **22%** design rate.
- Production catalog SHA-256:
  `C87C34A30B93FDD2659E6E57D328C131225D89B059F2866D525605A835E3D533`.

Ten tables received tracked focused-sweep overrides after the coarse retuner:
20, 40, 58, 60, 63, 75, 78, 85, 89 and 98. Their values and rationale are in
`tool/level_mode_balance_overrides.csv`; the final combined confirmation pass
measured the exact resulting catalog.

## Honest limitation

The all-level rate gate is intentionally not claimed. Several explicit
objective-only tables are easier than their aspirational clear-rate bands;
Level 93, for example, remains easy even with no hidden score target. Those
tables need future visible objective redesign if a harder curve is desired.

The two deterministic policies failed to clear 583 layout/table combinations.
That is not proof that those layouts are impossible: the exhaustive solver
route artifact is absent, and the policies are not exhaustive. This release
therefore claims measured policy balance, not proof of universal solvability.

## Validation

- 54 domain/catalog/objective/simulation tests passed.
- 11 Level Mode app and presentation tests passed.
- `flutter analyze --no-pub`: **No issues found**.
- Profile APK built and installed in-place on the physical phone as
  **8.6.2 (69)**; cold launch succeeded with no crash or ANR in the checked
  log window.
- The unfiltered whole-project `flutter test --no-pub` invocation reached its
  10-minute command cap without emitting a failure, so it is recorded as a
  timeout rather than a pass.

The machine-readable confirmation report is
`WILDCARD-v8.6.2-level-balance-report.json` in this directory.
