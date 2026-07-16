# WILDCARD v6.9.9 — Claude work-laptop validation prompt

Copy everything below the line into Claude on the work laptop. Give Claude this
prompt together with the v6.9.9 Codex email. Do not substitute an older HTML,
APK, ZIP, branch, or `main` checkout.

---

You are the independent release-validation engineer for **WILDCARD v6.9.9**.
Work methodically, preserve evidence, and return a result that home Codex can
verify without trusting a prose summary.

## 1. Mission and immutable source target

Validate the source on this exact GitHub repository and branch:

- Repository: `https://github.com/nisargpatel0505-lang/wildcard.git`
- Required branch: `agent/v699-scoring-mobile-polish`
- Expected product version: `6.9.9`
- Android application ID: `com.nisarg.wildcard`
- Expected Play/release version code: `26`
- Expected local developer APK version code: `27`
- Expected canonical `www/index.html` SHA-256 at handoff:
  `64bbcfe2e2141260bf8ed948af12ad5db7f1e3cfe3d5b8e62555ee3244b642c3`
- Firebase project: `wildcard-31d50`
- Google project/Play Games app ID: `420107184674`
- Leaderboard resource ID: `CgkIotTbgp0MEAIQAQ`

The branch head at the moment you begin is the immutable validation input. Record
its full 40-character commit SHA before installing dependencies or generating
anything. The related draft PR is the PR whose **head branch** is
`agent/v699-scoring-mobile-polish`; record its number and URL if it exists.

Before doing any test work, hash `www/index.html`. It must equal the expected
handoff SHA-256 above. If the branch head has intentionally advanced and the Codex
email explicitly supplies a replacement canonical hash, use that newer email hash
and record both values; otherwise a mismatch is `SOURCE_IDENTITY_MISMATCH` and you
must stop rather than validate an unknown revision.

`main` may still be older. **Never fall back to `main`, v6.9.8, v6.9.1, a phone
APK, or a standalone HTML.** If the required remote branch does not exist, stop
and return `SOURCE_NOT_PUBLISHED`; do not validate a different source and call it
v6.9.9.

Your job is to:

1. prove source identity and provenance;
2. run the committed audits and full deterministic simulation;
3. independently stress all 57 Jokers, not merely compile them;
4. regression-test economy, rewards, saves, ads, and Google configuration;
5. prove the standalone HTML comes from the canonical source;
6. prove production and developer variants remain separated;
7. build a release APK and AAB only when the local Android toolchain and already
   configured secure signing environment make that possible;
8. measure scoring smoothness/timing and mobile UI invariants;
9. return reports, raw JSON, logs, screenshots where possible, and SHA-256 hashes.

## 2. Absolute safety and scope rules

These rules override any tempting shortcut:

- Do **not** upload anything to Play Console, Firebase, AdMob, GitHub Releases,
  the Raspberry Pi, or any production/test track.
- Do **not** deploy Firestore rules or change a Google/Firebase/Play console.
- Do **not** push, merge, rebase, force-push, tag, or open/close a PR.
- Do **not** run `git reset`, `git clean`, destructive checkout commands, or
  delete an existing repository. Start in a new validation directory.
- Do **not** request, display, copy, hash, archive, transmit, or inspect a
  keystore, signing password, private key, SSH key, token, OAuth secret, API
  credential, or developer unlock code. Presence/absence of an already
  configured signing environment may be reported as one Boolean only.
- Never enumerate the entire environment (`Get-ChildItem Env:` or `set`) because
  it may print credentials. Inspect only the named tool variables you actually
  need, such as whether `ANDROID_HOME` is set; do not print its contents beyond
  the path.
- Do not put `node_modules`, Gradle caches, signing material, local properties,
  private logs, or credentials into the return ZIP.
- Do not bypass work-laptop policy or install system-wide software. Prefer the
  existing runtime. A user-space official Node distribution is acceptable only
  if workplace policy permits it.
- Native ad callback tests must be mocked/local. Do not request live ads and do
  not invent production AdMob IDs.
- This is validation, not a rebalance. Do not change Joker values, scoring,
  prices, rewards, drop rates, targets, animation pacing, or UI based on taste.
- **Win FX is intentionally retired. Do not restore it, even if an old note or
  report says paid Win FX should return.** Any dormant Win FX runtime/catalog/UI
  code is a release defect and must be reported.

If cloning is blocked by corporate policy, use the v6.9.9 source workpack from
the Codex email only as a fallback, validate its manifest and SHA-256, and label
the source status `WORKPACK_VERIFIED_NOT_GIT_CHECKED_OUT`. Do not claim Git branch
identity in that case. If neither the branch nor a manifested workpack is
available, stop.

## 3. Change policy

Begin in detached-HEAD validation mode and do not edit tracked production files.
Generated reports under `docs/release` and generated Android assets may make the
working tree dirty; classify each generated change, but do not conceal it.

Only propose a code change when all of the following are true:

1. there is a concrete, reproducible defect rather than an aesthetic preference
   or a simulation outcome you dislike;
2. it reproduces twice with the same seed/fixture;
3. you have saved the smallest reproduction and expected-versus-actual result;
4. you first create a failing regression test;
5. you create a new local branch named
   `claude/v699-validation-fix-YYYYMMDD` before editing;
6. the fix is minimal and does not alter unrelated balance or pacing;
7. all affected suites, and the full deep suite for scoring/Joker/save/economy
   changes, pass afterward.

Do not push that branch. Export a patch to the validation output folder and list
every changed line/file and why. If no defect needs a fix, do not create a branch.

## 4. Work-laptop environment setup (Windows/PowerShell)

Use PowerShell. Do not run these in an existing WILDCARD directory.

```powershell
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Repo = 'https://github.com/nisargpatel0505-lang/wildcard.git'
$Branch = 'agent/v699-scoring-mobile-polish'
$WorkRoot = Join-Path $HOME 'WILDCARD-v699-validation'
$RepoRoot = Join-Path $WorkRoot 'repo'
$Out = Join-Path $WorkRoot 'output\claude-v699-validation'

if (Test-Path -LiteralPath $WorkRoot) {
  throw "Validation folder already exists; choose a fresh timestamped folder. Do not delete it: $WorkRoot"
}
New-Item -ItemType Directory -Path $WorkRoot, $Out | Out-Null

Get-Command git,node,npm -ErrorAction SilentlyContinue |
  Select-Object Name,Source,Version |
  Format-Table -AutoSize | Out-String |
  Set-Content -Encoding UTF8 (Join-Path $Out 'environment-tools.txt')

git --version
node --version
npm --version
```

Use Node.js 22 LTS or Node.js 24 and the npm shipped with it. Do not use an old
global dependency tree. `npm ci` must consume the committed lockfile exactly.

For optional Android work, inspect tools without dumping environment secrets:

```powershell
$AndroidHomeSet = [bool]($env:ANDROID_HOME -or $env:ANDROID_SDK_ROOT)
$Java = Get-Command java -ErrorAction SilentlyContinue
$Adb = Get-Command adb -ErrorAction SilentlyContinue
[pscustomobject]@{
  AndroidSdkVariablePresent = $AndroidHomeSet
  JavaPresent = [bool]$Java
  AdbPresent = [bool]$Adb
} | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $Out 'android-environment.json')
if ($Java) { java -version }
```

Preferred Android environment is JDK 21, Gradle Wrapper 8.14.3, and Android SDK
platform 36. Do not install these globally or bypass policy. Android packaging is
an explicitly reportable `SKIPPED_TOOLCHAIN` if they are unavailable; all Node
validation must still continue.

## 5. Clone and prove source identity

```powershell
git ls-remote --heads $Repo "refs/heads/$Branch" |
  Tee-Object -FilePath (Join-Path $Out 'remote-branch.txt')
if ($LASTEXITCODE -ne 0) { throw 'Unable to query required remote branch.' }
if (-not (Get-Content (Join-Path $Out 'remote-branch.txt') -Raw).Trim()) {
  throw 'SOURCE_NOT_PUBLISHED: required branch is absent. Do not use main.'
}

git clone --filter=blob:none --no-checkout $Repo $RepoRoot
Set-Location $RepoRoot
git fetch origin "refs/heads/${Branch}:refs/remotes/origin/${Branch}"
$RemoteSha = (git rev-parse "origin/$Branch").Trim()
git switch --detach $RemoteSha
$HeadSha = (git rev-parse HEAD).Trim()
if ($HeadSha -ne $RemoteSha) { throw 'Checked-out SHA differs from remote branch head.' }

git remote -v | Set-Content -Encoding UTF8 (Join-Path $Out 'git-remotes.txt')
git show -s --format=fuller HEAD | Set-Content -Encoding UTF8 (Join-Path $Out 'git-commit.txt')
git status --short --branch | Set-Content -Encoding UTF8 (Join-Path $Out 'git-status-before.txt')
git diff --check
git fsck --no-reflogs
```

If GitHub CLI is already installed and authenticated, discover the PR read-only:

```powershell
$Gh = Get-Command gh -ErrorAction SilentlyContinue
if ($Gh) {
  gh pr list --repo nisargpatel0505-lang/wildcard --head $Branch `
    --state all --json number,url,state,headRefName,headRefOid,baseRefName `
    | Set-Content -Encoding UTF8 (Join-Path $Out 'github-pr.json')
}
```

Do not authenticate GitHub from this prompt and do not treat a missing `gh` CLI
as a test failure. The remote branch checkout is the source proof. If a PR is
found, its `headRefOid` must equal `$HeadSha`; otherwise report a PR/source
mismatch.

Create a source-identity record:

```powershell
$Pkg = Get-Content package.json -Raw | ConvertFrom-Json
$ExpectedIndexHash = '64bbcfe2e2141260bf8ed948af12ad5db7f1e3cfe3d5b8e62555ee3244b642c3'
$IndexHash = (Get-FileHash www/index.html -Algorithm SHA256).Hash.ToLowerInvariant()
if ($IndexHash -ne $ExpectedIndexHash) {
  throw "SOURCE_IDENTITY_MISMATCH: expected $ExpectedIndexHash, found $IndexHash"
}
$LockHash = (Get-FileHash package-lock.json -Algorithm SHA256).Hash.ToLowerInvariant()
$GradleHash = (Get-FileHash android/app/build.gradle -Algorithm SHA256).Hash.ToLowerInvariant()
[pscustomobject]@{
  repository = $Repo
  branch = $Branch
  commit = $HeadSha
  packageVersion = $Pkg.version
  indexSha256 = $IndexHash
  packageLockSha256 = $LockHash
  buildGradleSha256 = $GradleHash
  validatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
} | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 (Join-Path $Out 'source-identity.json')
```

Before testing, independently confirm all of these and record exact line refs:

- `package.json` reports `6.9.9`;
- the visible app version in `www/index.html` is `v6.9.9`;
- `android/app/build.gradle` says `versionName "6.9.9"`, release
  `versionCode 26`, and developer output code `27`;
- `capacitor.config.json` has app ID `com.nisarg.wildcard` and webDir `www`;
- `tools/audit-google-config.js`, the standalone builder, developer builder, and
  verification script expect v6.9.9 rather than an older version;
- `www/sw.js` has a newly versioned cache and does not knowingly serve v6.9.8;
- no tracked release script still names v6.8 or v6.9.8 as the current output.

Any mismatch is a hard source-version failure. Do not silently rename artifacts.

## 6. Install exact dependencies and take a clean baseline

```powershell
Set-Location $RepoRoot
npm ci
if ($LASTEXITCODE -ne 0) { throw 'npm ci failed.' }
npm ls --depth=0 | Set-Content -Encoding UTF8 (Join-Path $Out 'npm-top-level.txt')
git status --short | Set-Content -Encoding UTF8 (Join-Path $Out 'git-status-after-npm-ci.txt')
```

Do not run an automated dependency upgrade, `npm update`, lockfile rewrite, or
framework migration. Record vulnerability warnings, if npm prints any, without
changing versions during validation.

Run the fast committed gates first, saving full stdout/stderr and exit codes:

```powershell
npm test 2>&1 | Tee-Object -FilePath (Join-Path $Out '01-npm-test-baseline.log')
if ($LASTEXITCODE -ne 0) { throw 'Baseline verification failed.' }

npm run test:economy-rewards 2>&1 |
  Tee-Object -FilePath (Join-Path $Out '02-economy-reward-regression.log')
if ($LASTEXITCODE -ne 0) { throw 'Economy/reward regression failed.' }

npm run test:native-ads 2>&1 |
  Tee-Object -FilePath (Join-Path $Out '03-native-ad-callbacks.log')
if ($LASTEXITCODE -ne 0) { throw 'Native ad callback regression failed.' }

npm run audit:google 2>&1 |
  Tee-Object -FilePath (Join-Path $Out '04-google-config-audit.log')
if ($LASTEXITCODE -ne 0) { throw 'Google hard configuration audit failed.' }
```

Do not stop the whole assignment at the first product defect after the clean
baseline is recorded. Continue independent, non-mutating audits where safe and
return a complete failure inventory. Only stop for source ambiguity, unsafe
credential requests, or an unusable runtime.

## 7. Full committed deep simulation — mandatory counts

Run the full suite with `SIM_QUICK` unset. Explicitly remove it from the process
so a previous terminal cannot accidentally run only the quick cohort.

```powershell
Remove-Item Env:SIM_QUICK -ErrorAction SilentlyContinue
$DeepStart = Get-Date
npm run test:deep 2>&1 | Tee-Object -FilePath (Join-Path $Out '05-deep-sim-full.log')
$DeepExit = $LASTEXITCODE
$DeepDuration = (Get-Date) - $DeepStart
[pscustomobject]@{ exitCode=$DeepExit; elapsedSeconds=[math]::Round($DeepDuration.TotalSeconds,3) } |
  ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $Out '05-deep-sim-timing.json')
if ($DeepExit -ne 0) { throw 'Full deep simulation process failed.' }
```

The full run may legitimately take many minutes. Do not cancel it merely because
it is slower than the quick suite. It has a 30-minute internal guard.

The generated JSON must be `docs/release/wildcard-v6.9.9-sim-results.json` and
must satisfy every hard gate below:

- `version == "6.9.9"`;
- exactly **57 Jokers**, with **10 free** and **47 paid**;
- exactly **50,000 randomized scoring cases**;
- exactly **15,000 The Cheat six-card subset cases**;
- exactly **2,600 complete runs** (1,500 standard-all-unlocked, 700 standard
  free-pool, 400 Gauntlet-all-unlocked);
- `dataFailures.length == 0`;
- `hookErrors.length == 0`;
- `invariantFailures.length == 0`;
- `cheatAudit.mismatches == 0` and mismatch rate is 0%;
- the deterministic Frostbite fixture scores the non-frozen King of Hearts and
  does not score the frozen Ace of Spades;
- every cohort completes its requested run count without a crash or guard abort;
- every Joker has a coverage row and was tested. A generic fixture may legitimately
  show zero activation for a highly conditional Joker, but the independent Joker
  suite in the next section must deliberately trigger it.

Copy the raw result and Markdown report before any later run overwrites them:

```powershell
New-Item -ItemType Directory -Force (Join-Path $Out 'deep') | Out-Null
Copy-Item docs/release/wildcard-v6.9.9-sim-results.json (Join-Path $Out 'deep\wildcard-v6.9.9-sim-results.json')
Copy-Item docs/release/wildcard-v6.9.9-sim-report.md (Join-Path $Out 'deep\wildcard-v6.9.9-sim-report.md')
```

Parse the JSON and print a one-screen gate summary rather than relying only on
the process exit code. Rerun `npm test` after the fresh simulation so the verifier
checks the newly generated evidence, not only the committed report.

## 8. Independent all-57-Joker stress harness

The existing deep simulator is broad but does not prove each conditional Joker
with a deliberate positive and negative fixture. Build an **independent QA
harness outside tracked source**, at:

`output/claude-v699-validation/harness/stress-jokers-v699.js`

It may reuse the safe VM/DOM-stub extraction approach in
`tools/deep-sim-v57.js`, but it must load the live definitions from
`www/index.html`; do not paste a second Joker catalogue or scoring engine into
the oracle. The harness itself is a returned test artifact, not a production
file. Use deterministic named seeds and include each seed in failures.

### 8.1 Catalogue and exact fixture coverage

Construct `fixtureMap` keyed by live Joker ID. Assert:

- its key set exactly equals the live 57-ID `JOKERS` set;
- there are no missing or extra fixtures;
- IDs and display names are unique;
- every rarity, price, unlock cost, description, optional `stateKey`, and hook
  type is structurally valid;
- each Joker has at least one deliberate **trigger** fixture and at least one
  **non-trigger/control** fixture, except an unconditional Joker, whose control
  is the same hand without that Joker;
- the independent expected delta/factor/state transition is encoded in the
  fixture. Do not call the production hook to calculate its own expected value.

For each Joker alone, check as applicable:

- hand classification before/after rule-changing Jokers;
- exact rank delta and per-card scoring flags;
- exact additive Mult delta;
- exact multiplicative factor;
- exact retrigger amount and ordering;
- exact `onScored` state mutation;
- exact `onHeatClear` coins/state/Joker-list mutation;
- event type, amount, valid `jokerIdx`, and readable trigger label;
- no mutation during preview (`commit=false`);
- permitted mutation happens once, and only once, on commit;
- score, rank sum, Value Points, Mult, and total remain finite and non-negative;
- repeated evaluation with the same seed and state is deterministic;
- unequip/control removes the effect.

Produce a row for every Joker containing ID, name, hook/rule category, trigger
fixture, control fixture, expected, actual, UI-event/side-effect classification,
seed, and PASS/FAIL.

### 8.2 Rule breakers and probabilistic effects

Give these special coverage beyond the generic fixtures:

**The Cheat**

- Retain the committed 15,000 random comparisons.
- Add targeted six-card fixtures for every hand type, ties, duplicated ranks,
  same-colour alternatives, enhancements, Boost levels, previous-hand state,
  and every conditional hand-type Joker.
- For each six-card fixture, independently enumerate all six five-card subsets;
  compare The Cheat result to the maximum **final score**, not merely the highest
  poker hand name.
- Stress The Cheat with Pair Polisher, Flush Fund, Straight Wire, Boost Fiend,
  Double Down, Master Class, Shortcut, Pocket Flush, and mixtures of those.
- Confirm six-card play is allowed only with The Cheat, while Low Ceiling takes
  precedence and limits selection to four.
- Confirm the original six selected cards are not mutated by preview or subset
  search and that ties are stable/reproducible.

**Lucky Seven**

- Prove preview mode makes no luck roll and cannot consume/change random state.
- Run at least **100,000 committed scoring-Seven trials** with a deterministic
  RNG. Expected hit probability is `1/3`.
- Pass the distribution if
  `abs(observed - 1/3) <= max(0.01, 5 * sqrt(p*(1-p)/N))`.
- On a hit, prove the Seven's already modified rank value is counted exactly ten
  times: the bonus event is nine additional copies, not ten additional copies.
- Test multiple scoring Sevens, non-scoring Sevens, Gild enhancement, rank-mod
  Jokers, Heartless/Frostbite suppression, save/reload around the play, and
  duplicate/late render calls. There must be exactly one committed luck roll per
  eligible scoring Seven.

**Royal Scam**

- J/Q/K score exactly twice, while Ace/10/non-scoring face cards do not retrigger.
- The retrigger repeats the combined card rank value after applicable rank mods
  and Gild, exactly once.
- Heartless/Frostbite suppression prevents a zero-value card retrigger.

**Shortcut and Pocket Flush**

- Test positive and near-miss 3-card Straights/4-card Flushes, ordinary five-card
  hands, Low Ceiling, and Cheat combinations.

**Glass Joystick**

- Prove x3 scoring independently of shatter.
- Run at least 50,000 seeded Heat-clear trials. Expected self-removal probability
  is 0.2, using the same five-sigma/1-percentage-point tolerance rule.
- A clear may remove it at most once; preview/scoring may never remove it.

### 8.3 Pairwise, modifier, enhancement, and state stress

Run all **1,596 unordered Joker pairs**. For every pair, evaluate a deterministic
scenario pack containing at least:

- one-card High Card;
- Pair, Two Pair, Three of a Kind, Straight, Flush, Full House, Four of a Kind,
  Straight Flush, and Royal Flush;
- four-card Straight and Flush candidates;
- a six-card Cheat candidate where legal;
- first play, middle play, and final play of a Heat;
- zero and non-zero discards;
- empty/small/large run-coin states;
- boosted and unboosted hand levels;
- copied, destroyed, compact-deck, and repeated-rank deck states;
- below and above the 55% Heat-score boundary;
- Heat 1, Heat 10, and Heat 12+ contexts.

Hard pairwise gates:

- zero throws, NaN, Infinity, negative score, invalid event indices, or state
  corruption;
- no duplicate equipped IDs and no more than five equipped Jokers;
- equipping pair A/B versus B/A produces the same final numeric score unless a
  documented stateful sequence makes order intentionally observable; list every
  exception and justify it;
- the pair result agrees with independently composed rank/additive/multiplicative
  expectations;
- preview is idempotent and side-effect free.

Run all 57 Jokers against all ten normal modifiers plus The House boss modifier
(at least **627 Joker/modifier cases**), including targeted checks that:

- Heartless and Frostbite zero the relevant card rank before rank-Joker,
  enhancement, retrigger, and Lucky Seven processing;
- Dead Air and The House suppress xMult Jokers but do not suppress card rank,
  rank-Joker, Neon, Glass, or additive Mult behavior outside their documented
  rules;
- Low Ceiling selection rules override six-card play;
- Cold Deck, Short Stack, Famine, Inflation, Tax, and High Stakes affect only
  their documented systems;
- Modded Out, Survivor, Storm Harness, Cold Adapter, and other modifier-aware
  Jokers trigger only in valid contexts.

Run all card enhancements with all relevant rank/retrigger/probability/Joker
paths. Verify event ordering and final arithmetic for Gild, Neon, Glass, and
Wild Suit.

Add curated 3-to-5-Joker engine fixtures for rank stacks, additive stacks,
xMult stacks, retrigger stacks, same-colour/Flush, Straight, deck sculpting,
Boosts, repeat-hand engines, final-play engines, economy engines, and
modifier/boss engines. Include especially:

- Royal Retainer + Royal Scam + Gild face card;
- Lucky Seven + every applicable rank booster;
- Cheat + hand-type Jokers + Boost Fiend/Master Class;
- Double Down + Encore + Danger Music;
- Modded Out + Survivor + Storm Harness under normal, modified, Dead Air, and
  boss states;
- Butcher/Cleaner/Guillotine after valid deck destruction;
- Collector/Printer/Tailor/Frequency Meter after valid copies;
- Trainer growth across multiple committed hands;
- Dividend and Glass Joystick across Heat clear/save/reload.

Finally run at least **100,000 seeded random combination cases** using zero to
five unique Jokers, all hand types, all modifiers, all enhancements, Boost
levels, stage boundaries, and deck states. This is additional to the committed
50,000-case sweep.

### 8.4 Save/reload and event/UI invariants

For every Joker ID and each `stateKey` Joker:

- serialize a valid active run at a trigger boundary;
- reload using the actual save/restore shape or a faithful invocation of the
  production serializers;
- confirm equipped IDs, `jokerState`, deck counts/enhancements, Heat, score,
  plays/discards, hand levels, eligibility flags, and run coins survive;
- confirm the next scored hand has the same deterministic result as the
  pre-reload branch;
- confirm `onScored`, `onHeatClear`, reward, and shatter callbacks do not replay
  because of restoration;
- confirm invalid/unknown historical cosmetic IDs, including retired Win FX
  save values if present, are ignored safely without making Win FX live again.

Classify trigger observability for each Joker as `score-event`,
`state-side-effect`, `economy-side-effect`, or `rule-change`. Every numeric score
contribution must have a valid event tied to the correct Joker. Stateful/economy
effects must be understandable from the resulting UI/state. Flag a silent or
misattributed effect; do not invent a cosmetic celebration to hide it.

Hard UI-event invariants:

- event amounts reconcile exactly to final `rankSum`, Mult, and total;
- event card/Joker indices are in range;
- no contribution fires twice from duplicate render/callback work;
- trigger chips are reused, not permanently appended on every hand;
- after 100 rendered scoring cycles, score-chip/proc-chip counts remain bounded
  by card/Joker slots and total DOM nodes return to baseline plus at most 20;
- no orphan scoring classes, invisible overlays, or stale status text remain;
- no Win FX pulse, particle layer, confetti, screen flash, or Win FX callback is
  created.

Write:

- `joker/wildcard-v6.9.9-joker-stress-results.json`
- `joker/wildcard-v6.9.9-joker-stress-report.md`
- `harness/stress-jokers-v699.js`

The JSON must include exact counts for individual fixtures, controls, pairwise
pairs/scenarios, modifier cases, enhancement cases, save/reloads, Lucky Seven
trials/hits/rate/tolerance, Glass Joystick trials/removals/rate/tolerance,
targeted Cheat cases/mismatches, random combinations, every failure, every seed,
and overall PASS/FAIL.

## 9. Economy and reward regression

After the full gameplay simulation has generated fresh cohort inputs:

```powershell
npm run test:economy 2>&1 | Tee-Object -FilePath (Join-Path $Out '06-economy-simulation-run1.log')
if ($LASTEXITCODE -ne 0) { throw 'Economy model failed a release gate.' }
```

The economy tool and its output filenames must identify v6.9.9. If they still
say v6.9.8, report a version/provenance defect; do not rename the output by hand.

Hard economy gates:

- 57 Jokers = 10 free + 47 paid;
- total direct paid-Joker sink = exactly 10,875 coins and remains inside the
  10,000–12,000 intended band;
- daily reward curve = 30 base, +18/day, cap 192;
- daily totals = 588 (7 days), 4,950 (30 days), 33,750 (180 days);
- Wooden Vault = 100 coins and Golden Vault = 300 coins;
- mean Vault-route discount remains 15–22%;
- minimum simulated wallet is non-negative in every cohort/route/scenario;
- at least 1,000 deterministic trials per economy cohort/route/scenario;
- every gate in the generated result is true.

Run the deterministic economy command twice, copying run-one JSON before run two.
The reported `modelHash` and all deterministic fields must match. Timestamps and
wall-clock duration may differ.

Also independently exercise reward transactions and reload boundaries:

- starter gift granted exactly once;
- daily claim exactly once per date/streak and correct cap;
- mission claims exactly once, with ready rewards blocking refresh;
- rewarded mission refresh changes all three missions, preserves all progress
  and claimed rewards, consumes the shared daily rewarded-ad allowance, and does
  **not** also grant the normal 25 ad coins;
- normal coin ad grants exactly 25 and respects the five-per-day limit;
- run revive grants exactly one play, is offered only on a natural out-of-plays
  loss, saves before controls resume, cannot recur, and makes the score
  leaderboard-ineligible;
- run-coin double uses the frozen end-of-run amount and pays exactly once across
  reward/dismiss/failure callback permutations and app reload;
- Heat rewards are idempotent across checkpoint/reload;
- chest double taps cannot spend/grant twice, duplicates cannot be awarded, and
  the unlock is saved before reveal animation;
- the bounded cloud reward-claim merge preserves the newest local claim even
  when the cloud ledger is already full;
- malformed or repeated callbacks never create negative balances, duplicate
  unlocks, repeated currency, or a resurrected completed run.

Use at least 10,000 seeded randomized reward-event order/reload sequences. Return
the seed and minimal sequence for any failure. Write:

- `economy/wildcard-v6.9.9-economy-results.json`
- `economy/wildcard-v6.9.9-economy-report.md`
- `economy/wildcard-v6.9.9-reward-transaction-stress.json`

Do not change balance because a cohort win rate or completion day feels high or
low. Report distributions for a later design decision.

## 10. Native rewarded-ad callback audit

Run and preserve `npm run test:native-ads`. Then extend the local mock harness
outside tracked production source to enumerate at least these event orders:

- reward → dismiss → late fail;
- reward → reward → dismiss;
- dismiss without reward → late reward;
- failed-to-show → dismiss → late reward;
- show Promise rejection → SDK failure/dismiss events;
- SDK reward before the show Promise microtask settles;
- overlapping second request while one ad is in flight;
- duplicate dismiss/fail events;
- preload success/failure and next-ad preparation after every terminal path.

For every permutation:

- the caller settles exactly once;
- success occurs only after the SDK reward event;
- dismiss/fail/rejection without reward settles false;
- late/duplicate events cannot change the settled result or pay again;
- a second placement cannot overlap the first;
- exactly one replacement preload is requested after dismissal/failure;
- placement-specific game reward logic remains idempotent after save/reload.

Inspect release configuration read-only and state clearly whether it uses test,
placeholder, or real production AdMob identifiers. Callback tests prove local
logic only; they do **not** prove live inventory, consent readiness, policy
approval, fill, or revenue. Never insert IDs. Write:

- `ads/wildcard-v6.9.9-native-ad-callback-results.json`
- `ads/wildcard-v6.9.9-native-ad-callback-report.md`

## 11. Google/Firebase/Play Games configuration audit

Run `npm run audit:google` and save its JSON. Hard pass requires all repository
`hardChecks` true and `failures` empty. Independently confirm:

- package `com.nisarg.wildcard` agrees across Gradle, Capacitor, manifest, and
  Firebase config;
- version 6.9.9/code 26 agree across release/audit inputs;
- Firebase project `wildcard-31d50` and number `420107184674` agree;
- manifest references the Play Games APP_ID resource;
- leaderboard ID is `CgkIotTbgp0MEAIQAQ`;
- Firebase Google Auth/Firestore/App Check and Play Games v2 dependencies remain
  structurally wired;
- no token, ID token, access token, player ID, email, exception text, or other
  personal data is exposed to browser diagnostics;
- Firestore rules remain authenticated, owner-scoped to the fixed save document,
  field/type/size constrained, server-timestamped, delete-denied, and default
  deny.

If Java and network policy permit the local Firebase emulator dependency, run:

```powershell
npm run test:rules 2>&1 | Tee-Object -FilePath (Join-Path $Out '07-firestore-rules-emulator.log')
```

Do not deploy rules. Mark this `SKIPPED_TOOLCHAIN_OR_POLICY` if it cannot run.

Treat repository checks and console readiness separately:

- a missing Play app-signing SHA-1 in the committed Firebase config is a release
  blocker/warning to report, not something to fabricate;
- Play Games credentials linked to both signing certificates, tester allowlist,
  leaderboard publishing, Play Games publishing, OAuth consent, and App Check
  enforcement are **NOT VERIFIABLE FROM SOURCE**;
- never label those console states PASS without authenticated console evidence;
- do not open or change the consoles in this assignment.

Write `google/wildcard-v6.9.9-google-config-audit.json` and a short Markdown
interpretation separating `PASS`, `FAIL`, `WARNING`, `UNVERIFIED`, and `SKIPPED`.

## 12. Standalone HTML provenance and offline proof

Build from canonical source:

```powershell
npm run build:standalone 2>&1 |
  Tee-Object -FilePath (Join-Path $Out '08-build-standalone.log')
if ($LASTEXITCODE -ne 0) { throw 'Standalone build failed.' }

$CanonicalHash = (Get-FileHash www/index.html -Algorithm SHA256).Hash.ToLowerInvariant()
$Standalone = 'playtest/WILDCARD-work-laptop-standalone.html'
$StandaloneHash = (Get-FileHash $Standalone -Algorithm SHA256).Hash.ToLowerInvariant()
$Text = Get-Content $Standalone -Raw
$Match = [regex]::Match($Text, 'Canonical source: www/index\.html - SHA-256 ([0-9a-f]{64})')
if (-not $Match.Success) { throw 'Standalone provenance marker missing.' }
if ($Match.Groups[1].Value -ne $CanonicalHash) { throw 'Standalone provenance hash mismatch.' }
```

Prove:

- the marker hash exactly equals current canonical `www/index.html` SHA-256;
- the standalone reports v6.9.9;
- all runtime backgrounds, Sly sheets, logos, fonts, audio, and icons are embedded;
- there is no runtime `<script src>`, external stylesheet/manifest dependency, or
  unresolved relative asset/font/audio URL;
- ordinary external hyperlinks are not confused with runtime dependencies;
- it opens from `file://` with network disabled and reaches the menu;
- a mobile-size new run can start offline and render cards/Jokers/Sly;
- browser-console errors are zero for this smoke path.

Create `standalone/wildcard-v6.9.9-standalone-provenance.json` containing canonical
hash, standalone hash, byte size, embedded asset count/list, unresolved runtime
reference count/list, detected version, offline smoke result, and console errors.
You may link to the generated standalone rather than duplicating the large file
inside the results ZIP, but include its SHA-256 and exact path.

## 13. Win FX retirement audit — hard gate

Search runtime and build code, not only prose documentation:

```powershell
rg -n -i --glob '!docs/**' --glob '!releases/**' --glob '!output/**' `
  --glob '!node_modules/**' `
  'triggerWinFX|previewWinFX|win[-_ ]?fx|win-fx-pulse|kind\s*:\s*["'']win["'']' `
  www tools android package.json capacitor.config.json `
  | Set-Content -Encoding UTF8 (Join-Path $Out 'win-fx-search.txt')
```

Negative assertions in a verification test that ensure Win FX is absent are
allowed and should be identified as tests. PASS requires:

- no Win FX runtime function/call site;
- no preview function/control;
- no live cosmetic catalogue entry of kind `win`;
- no Cabinet/wardrobe Win FX purchase/equip UI;
- no Win FX CSS layer, pulse, full-screen particle celebration, or persisted
  runtime activation;
- old save values are tolerated/ignored, not revived.

Any dormant runtime code is FAIL with exact file/line references. **Do not restore
or replace it with another full-screen celebration.**

## 14. Scoring timing, smoothness, and Joker clarity

### 14.1 Static authored-timeline gates

Verify the live source still uses:

- Normal speed multiplier `1.0`;
- Fast speed multiplier `0.55`;
- intro beat 180 ms;
- card beat 220 ms;
- rank-Joker/retrigger/xMult beat 260 ms;
- settle 240 ms;
- payoff 300 ms;
- card fly-out 220 ms;
- terminal clear/fail waits unscaled at 600/400 ms so speed changes are not
  accidentally applied twice;
- card score/fly CSS around 0.20 seconds and trigger/callout CSS around
  0.68–0.72 seconds;
- Win FX fully absent.

Instrument `sleep`/`beat` in the QA harness and compute the authored wait budget
for named fixtures. For a typical five-card, two-triggering-Joker Heat-clear
fixture, hard targets are:

- Normal authored timeline no more than **3.4 seconds**;
- Fast authored timeline no more than **2.2 seconds**;
- no unexplained individual gap above 600 ms;
- Fast must be at least 30% shorter than Normal for the scaled scoring portion.

The exact score, reward, state, and event order must be identical between Normal
and Fast; only presentation timing may differ.

### 14.2 Runtime smoothness and leak checks

Where a Chromium browser/performance tool is available, test the standalone at
393×873 touch/mobile emulation, then at 360×800 and 412×915. Record browser and
hardware context. Run at least 25 hands/100 synthetic scoring cycles, including
five-card + five-Joker events. Measure:

- wall-clock score sequence median/p95 for Normal and Fast;
- long tasks, dropped/janky frames, maximum frame gap, and peak DOM nodes;
- style/layout recalculation count if available;
- WebAudio oscillator/gain node cleanup;
- storage/cloud checkpoint calls per hand;
- score/proc chip node count before and after;
- browser-console errors and unhandled rejections.

Performance acceptance targets (report hardware caveats rather than fudging):

- Normal typical fixture median ≤4.0 s and p95 ≤4.8 s;
- Fast median ≤2.7 s and p95 ≤3.4 s;
- no main-thread task above 100 ms caused by scoring code;
- fewer than 5% visibly missed animation frames in the measured scoring window;
- DOM returns to baseline +20 nodes or fewer after the cycle;
- score/proc chips are reused and bounded by current card/Joker slots;
- audio nodes disconnect after completion and do not grow monotonically;
- no duplicate save per individual scoring event;
- no animation class remains stuck after completion.

If browser tooling is unavailable, still run authored-timeline/DOM-stub tests and
mark real rendering performance `UNVERIFIED_ON_WORK_LAPTOP`; do not claim a phone
performance pass.

### 14.3 Mobile layout smoke

Preserve the praised v6.9.9 layout. At all three mobile viewports verify and
capture screenshots where possible:

- no horizontal page overflow or desktop viewport;
- nine cards fit, have a tiny usable gap, and every top/bottom rank/suit remains
  inside its card (especially the Ace);
- adjacent selected cards can be selected reliably, lift visibly, animate back,
  and never overlap controls;
- Sly portrait and speech are legible and inside their boxes;
- Heat, modifier, target, score, Value Points, Multiplier, and projected score
  are readable;
- Joker names/short descriptions/triggers are readable without mandatory tap;
- the table does not leave a large dead area below the cards;
- Play/Discard/Abandon controls and overlays respect safe-area/nav bounds;
- Deck view shows all 13 ranks at a glance without a mandatory vertical scroll;
- home menu, mode picker, Daily Challenge, shop/wardrobe/settings/cabinet routes
  do not clip or create inaccessible buttons;
- retired Win FX never appears.

Visual failures are defects to document with viewport and screenshot. Do not
redesign the praised layout during validation.

Write:

- `performance/wildcard-v6.9.9-scoring-performance.json`
- `performance/wildcard-v6.9.9-scoring-performance.md`
- screenshots/traces only when the tools are available.

## 15. Production/developer separation and optional Android builds

### 15.1 Source separation hard gates

Before any Android build, prove:

- production `www/index.html` contains no `WILDCARD_DEV_BUILD`, developer screen,
  `applyDevCode`, grant-coins control, unlock-all control, or developer setting;
- developer controls exist only as build-time injection in
  `tools/build-developer-apk.js`;
- production release code is 26 and developer APK output code is 27;
- the actual developer code and its hash are never printed in your output;
- `android/app/src/developer` does not exist before or after the developer build;
- developer build tooling guarantees the canonical production HTML is unchanged
  and cleans its temporary source set in `finally`.

### 15.2 Build decision

An Android package build is allowed only if:

- JDK 21, Android SDK/platform 36, and Gradle Wrapper can run; and
- the already configured secure local signing setup is available without you
  opening, reading, copying, hashing, or asking for its files.

Record only `secureSigningEnvironmentPresent: true/false`. If false, do not edit
Gradle to bypass signing, create a new key, use a debug key as release, download
home signing files, or ask the user to send secrets. Mark release APK/AAB build
`SKIPPED_SIGNING_MATERIALS`. You may still run non-packaging compile tasks if
safe.

If the environment is available, run:

```powershell
npm run sync:android 2>&1 | Tee-Object -FilePath (Join-Path $Out '09-capacitor-sync.log')
Push-Location android
.\gradlew.bat --version 2>&1 | Tee-Object -FilePath (Join-Path $Out '10-gradle-version.log')
.\gradlew.bat :app:clean :app:assembleRelease :app:bundleRelease --no-daemon 2>&1 |
  Tee-Object -FilePath (Join-Path $Out '11-android-release-build.log')
if ($LASTEXITCODE -ne 0) { throw 'Android release APK/AAB build failed.' }
Pop-Location
```

Copy, without uploading:

- `android/app/build/outputs/apk/release/app-release.apk` to
  `build/WILDCARD-v6.9.9-release.apk`;
- `android/app/build/outputs/bundle/release/app-release.aab` to
  `build/WILDCARD-v6.9.9-release.aab`.

Then, only if separation validation is required and secure signing is already
available, run `npm run build:android:developer`, copy its APK to
`build/WILDCARD-v6.9.9-developer.apk`, and prove production source hash is
unchanged afterward.

Use available official Android tools (`apkanalyzer`, `aapt2`, `apksigner`,
`jarsigner`) read-only to record:

- package ID, version name, version code, min/target SDK;
- release APK code 26 and developer APK code 27;
- APK signature verification and public certificate digest only;
- AAB JAR signature verification;
- SHA-256 and byte size of each output;
- embedded `assets/public/index.html` version and SHA-256;
- release APK/AAB embedded HTML equals canonical production HTML after sync;
- developer marker exists in developer APK only;
- production release APK/AAB contains no developer marker/function/control;
- `android/app/src/developer` is absent and `www/index.html` hash equals the
  pre-build source-identity hash after the build.

Do not claim a pre-existing repository APK/AAB was newly built. You may inspect
pre-existing artifacts for comparison, but label them `PREEXISTING_UNPROVENANCE`
until embedded-source/hash/signature checks establish otherwise.

## 16. Final regression pass and working-tree accounting

After any generated evidence/build work:

```powershell
npm test 2>&1 | Tee-Object -FilePath (Join-Path $Out '12-npm-test-final.log')
npm run test:economy-rewards 2>&1 |
  Tee-Object -FilePath (Join-Path $Out '13-economy-rewards-final.log')
npm run test:native-ads 2>&1 |
  Tee-Object -FilePath (Join-Path $Out '14-native-ads-final.log')
git diff --check
git status --short --branch | Set-Content -Encoding UTF8 (Join-Path $Out 'git-status-final.txt')
git diff --stat | Set-Content -Encoding UTF8 (Join-Path $Out 'git-diff-stat-final.txt')
```

Classify every final working-tree difference as one of:

- expected generated simulation/economy report;
- expected Capacitor/Gradle generated output;
- independent QA artifact outside tracked source;
- proposed defect fix on the dedicated local branch;
- unexpected/unexplained (automatic FAIL until understood).

Recompute `www/index.html`, `package-lock.json`, and `android/app/build.gradle`
hashes. Unless you created an explicitly documented fix branch, all three must
equal their source-identity hashes.

## 17. Required result folder, hashes, and safe ZIP

Use this exact layout where applicable:

```text
output/claude-v699-validation/
  source-identity.json
  environment-tools.txt
  android-environment.json
  git-commit.txt
  git-status-before.txt
  git-status-final.txt
  command-and-exit-summary.md
  deep/
    wildcard-v6.9.9-sim-results.json
    wildcard-v6.9.9-sim-report.md
  joker/
    wildcard-v6.9.9-joker-stress-results.json
    wildcard-v6.9.9-joker-stress-report.md
  harness/
    stress-jokers-v699.js
  economy/
    wildcard-v6.9.9-economy-results.json
    wildcard-v6.9.9-economy-report.md
    wildcard-v6.9.9-reward-transaction-stress.json
  ads/
    wildcard-v6.9.9-native-ad-callback-results.json
    wildcard-v6.9.9-native-ad-callback-report.md
  google/
    wildcard-v6.9.9-google-config-audit.json
    wildcard-v6.9.9-google-config-audit.md
  standalone/
    wildcard-v6.9.9-standalone-provenance.json
  performance/
    wildcard-v6.9.9-scoring-performance.json
    wildcard-v6.9.9-scoring-performance.md
    screenshots/                 (if available)
  build/                          (only if genuinely built)
    WILDCARD-v6.9.9-release.apk
    WILDCARD-v6.9.9-release.aab
    WILDCARD-v6.9.9-developer.apk (optional)
  proposed-fix.patch              (only if a defect was fixed locally)
  SHA256SUMS.txt
  WILDCARD-v6.9.9-Claude-validation-report.md
  RETURN-TO-CODEX.md
```

Write a deterministic SHA-256 list for every returned file except the hash list
itself. Paths must be relative to the result folder. Never hash or include
signing material.

```powershell
$HashFile = Join-Path $Out 'SHA256SUMS.txt'
Get-ChildItem -LiteralPath $Out -Recurse -File |
  Where-Object { $_.FullName -ne $HashFile } |
  Sort-Object FullName |
  ForEach-Object {
    $h = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $rel = [System.IO.Path]::GetRelativePath($Out, $_.FullName).Replace('\','/')
    "$h  $rel"
  } | Set-Content -Encoding UTF8 $HashFile
```

Create a ZIP containing only the safe result folder, not the repository,
dependencies, caches, or secrets:

```powershell
$Stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$Zip = Join-Path $WorkRoot "WILDCARD-v6.9.9-Claude-validation-results-$Stamp.zip"
Compress-Archive -Path (Join-Path $Out '*') -DestinationPath $Zip -CompressionLevel Optimal
Get-FileHash -LiteralPath $Zip -Algorithm SHA256
```

If APK/AAB files make the ZIP too large for the chat, leave them outside the ZIP
and return their exact paths, sizes, and hashes; do not omit the reports/raw JSON.

## 18. Pass/fail policy

Overall status can be:

- `PASS_INTERNAL_TEST_CANDIDATE`: every hard source, scoring, Joker, economy,
  reward, ad-callback, provenance, separation, and final regression gate passes;
  skipped console/device checks are clearly separated.
- `PASS_WITH_EXTERNAL_BLOCKERS`: all source/code tests pass, but release still
  needs Play/Firebase/AdMob console setup, a Play-installed test, physical-device
  validation, or unavailable Android packaging.
- `FAIL_REPRODUCIBLE_DEFECT`: at least one hard gate fails with a saved minimal
  reproduction.
- `BLOCKED_SOURCE_OR_ENVIRONMENT`: exact source or a required Node runtime cannot
  be obtained safely.

Do not say “release ready” merely because Node tests pass. Live ads, Play Games
credentials/testers/leaderboard publishing, Google sign-in on a Play-installed
build, App Check enforcement, billing products/receipt security, and physical
phone smoothness require external evidence.

## 19. Exact return report template for home Codex

Fill every field. Use `PASS`, `FAIL`, `WARNING`, `UNVERIFIED`, or `SKIPPED` rather
than vague language. Paste `RETURN-TO-CODEX.md` into the home Codex task and attach
the safe results ZIP.

```markdown
# WILDCARD v6.9.9 independent validation return

## Verdict

- Overall: <PASS_INTERNAL_TEST_CANDIDATE | PASS_WITH_EXTERNAL_BLOCKERS | FAIL_REPRODUCIBLE_DEFECT | BLOCKED_SOURCE_OR_ENVIRONMENT>
- One-sentence reason: <...>
- Validation UTC: <ISO-8601>
- Work-laptop OS/runtime: <Windows version; Node; npm; Java/Android if used>

## Exact source identity

- Repository: https://github.com/nisargpatel0505-lang/wildcard
- Branch: agent/v699-scoring-mobile-polish
- Commit: <40-char SHA>
- PR: <number + URL, or NOT FOUND>
- Checkout status: <GIT_REMOTE_HEAD_VERIFIED | WORKPACK_VERIFIED_NOT_GIT_CHECKED_OUT>
- `www/index.html` SHA-256: <hash>
- `package-lock.json` SHA-256: <hash>
- Version/package/code: <6.9.9 / com.nisarg.wildcard / release 26 / developer 27>
- Final canonical source unchanged: <PASS/FAIL, or documented fix branch>

## Committed test gates

- `npm test`: <PASS/FAIL; exit; key counts>
- Economy/reward regression: <PASS/FAIL>
- Native rewarded-ad callbacks: <PASS/FAIL>
- Google repository hard checks: <PASS/FAIL>
- Firestore emulator: <PASS/FAIL/SKIPPED + reason>

## Full simulation

- Scoring: <50,000 / failures>
- The Cheat: <15,000 / mismatches>
- Complete runs: <2,600 = 1,500 + 700 + 400 / invariant failures>
- Joker count: <57; 10 free; 47 paid>
- Hook exceptions: <n>
- Frostbite deterministic check: <PASS/FAIL>
- Duration: <seconds>
- Raw result SHA-256: <hash>

## Independent Joker stress

- Individual trigger/control fixtures: <57/57; failures>
- Pairwise pairs/scenarios: <1,596 / count / failures>
- Joker × modifier cases: <at least 627 / failures>
- Enhancement cases: <count / failures>
- Save/reload cases: <count / failures>
- Targeted Cheat cases/mismatches: <count / n>
- Lucky Seven: <trials; hits; observed rate; tolerance; PASS/FAIL>
- Glass Joystick: <trials; removals; observed rate; tolerance; PASS/FAIL>
- Random Joker combinations: <at least 100,000 / failures>
- Trigger observability defects: <none or exact IDs/evidence>
- Raw result/report SHA-256: <hashes>

## Economy and reward safety

- Economy model/gates: <PASS/FAIL>
- Model hash deterministic across two runs: <PASS/FAIL; hash>
- Paid-Joker sink: <10,875 expected / actual>
- Daily totals: <588 / 4,950 / 33,750 expected vs actual>
- Vault prices/discount: <100 / 300 / percent>
- Negative wallet cases: <n>
- Reward-event/reload sequences: <at least 10,000 / failures>
- Duplicate grants/unlocks/revives/doubles: <n>

## Ads

- Callback permutation suite: <PASS/FAIL; cases>
- Exactly-once settlement/reward: <PASS/FAIL>
- Overlap/preload behavior: <PASS/FAIL>
- Runtime ad configuration: <TEST | PLACEHOLDER | PRODUCTION IDs PRESENT, without printing IDs>
- What remains unproved: <live inventory/consent/policy/fill/revenue>

## Win FX retirement

- Runtime functions/calls: <0 expected / actual>
- Live catalogue/UI entries: <0 expected / actual>
- Dormant CSS/pulse/particle code: <0 expected / exact refs>
- Old-save tolerance without activation: <PASS/FAIL>
- Win FX restored: NO

## Scoring performance and mobile UI

- Authored timeline Normal/Fast: <ms / ms; PASS/FAIL against 3,400/2,200>
- Runtime median/p95 Normal: <ms/ms or UNVERIFIED>
- Runtime median/p95 Fast: <ms/ms or UNVERIFIED>
- Longest scoring long task/frame gap: <ms or UNVERIFIED>
- DOM/audio/save leak gates: <PASS/FAIL/UNVERIFIED>
- 360×800 / 393×873 / 412×915 layout: <PASS/FAIL/UNVERIFIED>
- Console errors: <n>
- Screenshot/trace paths: <...>

## Standalone provenance

- Build: <PASS/FAIL>
- Canonical marker equals source SHA: <PASS/FAIL; hash>
- Standalone SHA-256/bytes: <hash / bytes>
- Unresolved runtime assets: <0 expected / actual>
- Offline mobile smoke: <PASS/FAIL/UNVERIFIED>

## Google/Firebase/Play Games

- Repository identifiers/dependencies: <PASS/FAIL>
- Firebase Play-signing SHA configuration: <PASS/WARNING>
- Play Games credentials/tester/publishing state: UNVERIFIED FROM SOURCE
- Leaderboard live behavior: UNVERIFIED unless separately tested on a Play-installed build
- App Check enforcement readiness: <WARNING/UNVERIFIED>
- Console changes made: NONE

## Android artifacts

- Build status: <BUILT | SKIPPED_TOOLCHAIN | SKIPPED_SIGNING_MATERIALS | FAILED>
- Release APK: <path; SHA-256; bytes; version; code; signature verification>
- Release AAB: <path; SHA-256; bytes; version; code; signature verification>
- Developer APK: <path/hash/code or SKIPPED>
- Embedded production HTML provenance: <PASS/FAIL>
- Production contains developer controls: <NO expected / actual>
- Temporary developer source set removed: <PASS/FAIL>
- Uploads performed: NONE

## Reproducible defects

For each defect:
1. Severity and affected gate
2. File/function and commit
3. Seed/fixture and exact reproduction command
4. Expected versus actual
5. Two-run reproduction evidence
6. Player impact
7. Proposed minimal fix, or “no change made”
8. Regression results after fix, if any

If none: `None found in the tested scope.`

## Local fix branch/diff

- Created: <NO | claude/v699-validation-fix-YYYYMMDD>
- Files changed: <none/list>
- Balance or pacing changed: NO
- Patch path/SHA-256: <none/path/hash>
- Pushed/uploaded: NO

## External blockers before public release

- <real AdMob configuration/live consent validation>
- <Play Games credentials/testers/leaderboard publishing>
- <Play-installed Google sign-in/cloud/App Check validation>
- <billing product + receipt/security validation>
- <physical-phone regression/closed test evidence>
- <anything else proven by this run>

## Returned artifacts

- Results ZIP: <path>
- Results ZIP SHA-256: <hash>
- `SHA256SUMS.txt`: <path/hash>
- Main report: <path/hash>
- Raw JSON files: <paths/hashes>
- Build artifacts kept outside ZIP: <paths/hashes or none>

## Recommended next action for Codex

<one precise next action based on evidence; do not propose a rebalance without data>
```

Do not end with “everything looks good.” End with the filled template, exact
artifact paths, hashes, explicit unknowns, and the smallest next action.
