# WILDCARD v6.9.9 — full deep simulation validation (§7 of the protocol)

**Verdict for this section: PASS — every hard simulation gate passed on the exact required source.**

This supersedes, for the simulation section only, the earlier `BLOCKED_SOURCE_OR_ENVIRONMENT`
return (which applied to the first handoff, a v6.9.1 `main` ZIP). Scope of this run: source
identity (§5, git-verified this time), the full committed deep simulation (§7), and the §7 tail
(committed verifier rerun on the fresh evidence). Sections 8–17 (independent Joker harness,
economy, ads, Google audit, standalone, Win FX, performance, Android builds) were not run.

## Source identity — GIT_REMOTE_HEAD_VERIFIED

- Repository: https://github.com/nisargpatel0505-lang/wildcard.git
- Branch: `agent/v699-scoring-mobile-polish`
- Commit: `38dd4c2e9ec9934734c9ea0066412d921ea0115e` — "Release WILDCARD v6.9.9 mobile scoring polish"
- Detached checkout SHA == remote branch head: verified
- `www/index.html` SHA-256: `64bbcfe2e2141260bf8ed948af12ad5db7f1e3cfe3d5b8e62555ee3244b642c3` (== canonical, == the user-supplied v6.9.9 APK's embedded `assets/public/index.html`, == the Codex workpack)
- `package-lock.json` SHA-256: `543d31b04a1b5e4a2b44d9440ef2650e0b5b4dd643b0e5bb208daf5747325a67`
- `package.json` version 6.9.9; `build.gradle` versionName "6.9.9", release versionCode 26
- Canonical source unchanged after the run: verified (index.html re-hashed identical; only `docs/release/wildcard-v6.9.9-sim-{results.json,report.md}` regenerated — an expected generated simulation report)
- Line-endings note: the Codex workpack reports `android/app/build.gradle` as `66454a86…`; this LF checkout hashes it `31cdc035…`. LF→CRLF conversion of the checkout file reproduces the workpack hash exactly — content-identical, CRLF vs LF only. (`.gitattributes` pins `*.html` to LF, which is why `www/index.html` matches byte-for-byte across git, workpack, and APK.)

## Execution

- Host: Linux sandbox, Node v22.22.2 (protocol's Windows/PowerShell steps adapted; the sim tool is pure Node built-ins — no `npm ci` needed for it)
- `SIM_QUICK` explicitly removed from the environment
- Runner: `node tools/deep-sim-v57.js` from the committed v6.9.9 tree (byte-identical to the v6.9.1 copy, SHA-256 `45aa3697c7ae6cdf6acd4f3f316b4fcb1507b18fcf9ad5596499b218fc45e3cc`)
- Duration: 363.111 s (from the result JSON's `durationMs`); completed within the 30-minute guard
- Process-exit caveat, disclosed: the shell wrapper that captured the exit code was accidentally killed mid-run by my own process cleanup (the node sim itself was unaffected). Exit 0 is therefore inferred from: complete log ("Scoring sweep complete: 50000", "Cheat subset sweep complete: 15000 mismatches: 0", all three cohorts complete), a fully-formed result JSON, and the committed verifier passing on that fresh JSON.

## §7 hard gates — all PASS

| Gate | Required | Actual |
|---|---|---|
| version | 6.9.9 | 6.9.9 |
| Jokers | 57 (10 free / 47 paid) | 57 (10 free / 47 paid) |
| Randomized scoring cases | exactly 50,000 | 50,000 |
| The Cheat six-card cases | exactly 15,000 | 15,000 |
| Complete runs | exactly 2,600 (1,500 + 700 + 400) | 2,600 (1,500 + 700 + 400) |
| dataFailures | 0 | 0 |
| hookErrors | 0 | 0 |
| invariantFailures | 0 | 0 |
| Cheat mismatches | 0 (0%) | 0 / 15,000 (0%) |
| Frostbite fixture | K♥ scores, frozen A♠ does not | scoringFlags [A♠ false, K♥ true] — PASS |
| Cohort completion | all requested counts, no crash/guard abort | all complete |
| Coverage row per Joker | 57 rows | 57 rows |

Zero-activation hooks in the generic sweep (permitted by the protocol for highly conditional
Jokers; §8's targeted fixtures are what would deliberately trigger them): `sniper`, `tailor`,
`doubledown`, `encore`, `redline`.

Cohort statistics (report-only; no rebalance performed per §2): standard_all_unlocked
29.07% win, avg 10.22 Heats cleared; standard_free_pool 1% win, avg 9.82; gauntlet_all_unlocked
35% win, avg 7.05.

## §7 tail — committed verifier on fresh evidence

`tools/verify-v68.js` (the committed `npm test`) run after the simulation: **exit 0,
failures: 0**. It independently re-confirmed version 6.9.9, source SHA `64bbcfe2…`, and read the
freshly generated 50,000/15,000/2,600 result JSON (not the stale committed one).

## Finding worth reporting to Codex

The **committed** `docs/release/wildcard-v6.9.9-sim-results.json` at this commit was generated
with the quick cohort (counts 10,000 / 5,000 / 550 — the `SIM_QUICK=1` sizes). On its own it does
not satisfy §7's mandatory counts; this run's regenerated full-scale results do. Quick-vs-full
statistics are consistent (win rates 28→29.07%, 0.67→1%, 34→35%; zero failures in both), so this
is an evidence-scale gap, not a behaviour defect. Recommended: commit the full-scale results (or
regenerate on the author machine with `SIM_QUICK` unset) so the repository's committed evidence
meets the protocol.

## Artifacts (in `deep/` of the results folder)

- `wildcard-v6.9.9-sim-results.json` — raw full-scale result (this run)
- `wildcard-v6.9.9-sim-report.md` — generated Markdown report (this run)
- `gate-summary.json` — machine-readable gate table above
- `05-deep-sim-full.log`, `05-deep-sim-timing.json` — run log and timing (with the exit-code caveat)
- `12-verify-after-sim.log` — committed verifier output on fresh evidence
- `git-status-after-sim.txt` — working-tree accounting
- `committed-baseline/` — the pre-run committed (quick) results, preserved for comparison
