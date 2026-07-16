# WILDCARD v6.9.9 Development and Release Report

Report snapshot: 16 July 2026 (Europe/London)
Audience: technical/product release handoff
Canonical game source: `www/index.html`
Android package: `com.nisarg.wildcard`

## Technical summary

WILDCARD v6.9.9 is a mobile-performance and presentation release built on the v6.9.8 economy/rewarded-recovery branch. Its most important change is the scoring path: the v6.9.8 authored waits made a representative five-card, two-Joker Heat-clear sequence last about **6,145 ms** before browser/render overhead. The same modeled sequence is **3,160 ms in v6.9.9 Normal** and **2,008 ms in Fast**, reductions of 48.6% and 45.7% respectively. The score result and Joker maths were not changed.

The release also removes Win FX completely from the live catalogue, Wardrobe, save defaults, preview code and runtime; makes individual Joker triggers and Sly's reaction readable without full-screen effects; brightens the room artwork; compacts and improves the phone-first home screen; and externalizes the large embedded fonts and sprite sheets. The canonical HTML fell from **4,438,040 bytes to 487,641 bytes** (89.01% smaller) while the generated standalone work-laptop build remains self-contained.

Current repository verification passes, including 10,000 randomized scoring/Joker cases, 5,000 six-card Cheat comparisons and 550 complete runs with zero scoring/data failures, hook exceptions, run-invariant failures or Cheat mismatches. A 390 x 844 manual browser smoke completed a no-Joker Pair play in 1,735 ms with the expected score and hand refill. That is a useful end-to-end observation, not a laboratory frame-time benchmark.

**Release assessment:** v6.9.9 is suitable for the next **Google Play Internal testing** build after the final commit/artifact manifest is locked. It is not yet ready for a public production rollout. The Play-distributed account, cloud-save, Play Games, billing and production-ad paths still require console-backed and physical-device validation. The recommended sequence is internal-track validation first, then a 14-person closed-test cohort (14 provides a buffer if the account's Play Console eligibility screen requires 12 continuously opted-in testers for 14 days).

## Evidence status and release identity

This report uses three evidence labels:

- **Verified in repository/session:** inspected source, generated report, test output, built artifact or direct browser observation.
- **Previously verified:** documented by an earlier release report but not rerun for this v6.9.9 snapshot.
- **Console-only/unverified:** cannot be proved from GitHub or local source and must be checked in Firebase, AdMob or Play Console.

| Item | Status at this snapshot | Evidence |
| --- | --- | --- |
| Version name | 6.9.9 | `package.json`, `android/app/build.gradle`, `www/index.html` |
| Android release code | 26 | Raised above the developer code 25 already installed on the test phone; repository Google audit passed |
| Android developer code | 27 | Developer variant override in `android/app/build.gradle` |
| Working branch | `agent/v699-scoring-mobile-polish` | Local Git worktree |
| Source baseline | `3dba9343034f7016d4c5af5afa4ce4a33585b5e1` (v6.9.8 economy/rewarded recovery) | Git history |
| Release implementation commit | Recorded in the GitHub draft PR after publication | The PR/branch is the authoritative review trail |
| Remote state | v6.9.9 was uncommitted at report snapshot; `origin/main` was still the v6.9.1 merge | Must be resolved before Pi/work-laptop handoff |
| Release APK | Built and v2-signature verified | `releases/WILDCARD-v6.9.9.apk` |
| Release AAB | Built | `releases/WILDCARD-v6.9.9.aab` |
| Developer APK | Built, code 27 | `releases/WILDCARD-v6.9.9-developer.apk` |
| Physical v6.9.9 install | Earlier developer code 25 snapshot installed and visually smoked | Final code-26 production artifact remains to be installed from Play Internal after the phone was disconnected |
| Google Play Internal upload | Not verified/performed by this report | Play Console action required |

## How the release evolved

The current release is the result of several focused iterations rather than a single rewrite.

| Version | Android code | Main purpose and retained outcome |
| --- | ---: | --- |
| v6.8 | 12 | Rewarded weekly-mission refresh and the animated Royal Vault chest system; 10k/5k/550 quick simulation passed. |
| v6.9 | 13 | Optional Google sign-in, local-first Firestore backup, owner-only Rules, App Check integration and official Play Games leaderboard bridge. |
| v6.9.1 | 14 | Authoritative source recovery, Android immersive mode, safe-area/card/chest phone fixes, room artwork and Play Games diagnostics. |
| v6.9.4 | 17 | Completed the JavaScript-to-native leaderboard score-loading bridge and added safer diagnostics. |
| v6.9.5 | 18 | Added visible Win FX to scored hands; retained 1.08 Normal and 0.65 Fast scoring multipliers. |
| v6.9.6 | 19 | Reduced some mobile Win FX cost, restored artwork under legacy themes and introduced the run-mode picker. |
| v6.9.7 | 20 | Removed gameplay Win FX calls, reorganized the phone menu, added Daily Challenge, improved Sly reactions and introduced the at-a-glance deck matrix. |
| v6.9.8 | 22 (23 developer) | Rebalanced the economy, added save-safe rewarded revive and one-time run-coin doubling, and hardened reward idempotency. |
| v6.9.9 | 26 (27 developer) | Corrects the scoring regression, retires Win FX completely, improves Joker/Sly clarity and mobile presentation, externalizes binary assets, and keeps the Play upgrade path above the installed developer snapshot. |

Earlier release notes remain the authoritative detailed history for their own versions under `docs/release/`. The key branch caveat is that GitHub `main` lagged behind the later feature branches at this snapshot. v6.9.9 must be committed, pushed, reviewed and merged before `main` or the Pi can be treated as authoritative.

## Scoring is materially faster without changing the maths

### The v6.9.8 regression was authored delay, not only device jank

The v6.9.8 scoring path used a Normal multiplier of 1.08 and a Fast multiplier of 0.65. It also converted terminal transitions into scaled `beat()` waits and raised several raw delays. This compounded the slowdown: both the event waits and the post-score transitions were multiplied by the pace factor.

For a representative Heat-clear path with five card events and two ordinary Joker multiplier events, the source-defined wait budget was:

| Stage | v6.9.8 raw wait | v6.9.8 Normal effective | v6.9.9 wait | Why it changed |
| --- | ---: | ---: | ---: | --- |
| Score-board introduction | 320 ms | 345.6 ms | 180 ms | The equation is already visible; a shorter acknowledgement is sufficient. |
| Five card events | 5 x 400 ms | 2,160 ms | 5 x 220 ms = 1,100 ms | Preserve ordered card readability without holding every card for almost half a second. |
| Two Joker events | 2 x 380 ms | 820.8 ms | 2 x 260 ms = 520 ms | Keep distinct Joker beats while improving input-to-result time. |
| Equation settle | 520 ms | 561.6 ms | 240 ms | The final equation no longer needs a second long pause. |
| Score reveal | 500 ms | 540 ms | 300 ms | The callout remains readable, but no full-screen Win FX competes with it. |
| Card exit | 340 ms | 367.2 ms | 220 ms | CSS and JavaScript timings now agree more closely. |
| Heat-clear transition | 1,250 ms | 1,350 ms | 600 ms unscaled `sleep()` | Prevent future pace settings from slowing the terminal transition twice. |
| **Modeled total** | 5,690 ms raw | **6,145.2 ms** | **3,160 ms** | **48.6% reduction in Normal.** |

Fast mode now applies 0.55 only to the 2,560 ms score-event portion, then keeps the 600 ms terminal transition unscaled: `2,560 x 0.55 + 600 = 2,008 ms`. The equivalent v6.9.8 Fast path was `5,690 x 0.65 = 3,698.5 ms`, so the new Fast path is 45.7% shorter in this scenario.

Actual duration varies with the number and type of card, enhancement, retrigger and Joker events. Lucky Seven deliberately retains several short suspense ticks. These calculations describe authored waits; they do not claim a device frame-time measurement.

### Rendering and persistence work was removed from the critical path

Timing alone was not enough. v6.9.9 also reduces work performed while the player is watching a score resolve:

- The Play tap locks only the scoring controls; it no longer performs an immediate full game render before the animation.
- `applyCosmetics()` caches the equipped table/theme/Sly signature. Routine renders no longer remove and re-add full-screen artwork and theme classes twice per hand.
- Card score chips and Joker proc chips are reused. Repeated score events no longer create and later destroy a fresh element for every beat.
- The old animated Heat score counter was removed. `renderGame()` already wrote the final score, so the counter had been rewinding it on the next animation frame and repainting it for another 450 ms.
- Mission counters can be incremented with persistence deferred, then the account is saved once after the hand instead of up to three separate writes.
- Modifier and first-run coaching blocks are updated only when their content signature changes, avoiding repeated `innerHTML` replacement.
- Short WebAudio oscillator/gain nodes explicitly disconnect at `onended`, preventing avoidable graph buildup over a long session.
- Phone/native `perf-lite` styling disables decorative blurred background blobs and uses hard outlines rather than blurred Joker-proc shadows.
- Score-chip, Joker-proc, callout, played-card and floating-score CSS timings were shortened to match the new JavaScript waits.

These changes target layout invalidation, DOM churn, paint cost and persistence overhead while preserving the ordered scoring sequence that tells the player where the total came from.

### Manual phone-sized browser smoke

**Verified session observation, not a formal benchmark:** Codex's in-app Chromium browser loaded the canonical `www` build from localhost at a 390 x 844 viewport with phone `perf-lite` CSS active. Normal speed played a two-card Pair (two tens) with no Jokers. The elapsed time from the Play click until the selected card detached and the refilled hand rendered was **1,735 ms**. Heat score became 35, hands changed 4 to 3, the hand refilled to 9 cards, and no console failure was observed.

This result is consistent with the shorter no-Joker path. It should not be interpreted as FPS, percentile latency or proof across Android WebView devices. The Play-distributed POCO X7 build still needs the same observation on hardware.

## Win FX is fully retired, not merely hidden during scoring

The explicit product decision for v6.9.9 is to keep Win FX gone. The current source contains no live Win FX catalogue entries, Wardrobe tab, equipped save field, preview function, trigger function, pulse class or Cabinet collection count.

This closes a gap left by v6.9.7/v6.9.8: gameplay calls had been removed, but paid cosmetics and dead preview/runtime code still existed. In v6.9.9:

- `COSMETICS` contains tables, UI themes and Sly skins only.
- `COSMETIC_DEFAULTS` and `account.equipped` contain `table`, `theme` and `sly` only.
- Save load/import validates current cosmetic IDs and silently drops retired Win FX identifiers rather than executing obsolete code.
- Wardrobe navigation is limited to Tables, UI Themes and Sly Skins.
- Cosmetic Vaults cannot award a Win FX item because none exists in the live pool.
- Cabinet totals no longer include a Win effects category.
- The verifier fails if `triggerWinFX`, `previewWinFX`, a `kind:'win'` catalogue item, `win-fx-pulse` or player-facing `Win effects` text returns.

**Migration note:** if any real external player acquired a Win FX item before this retirement, decide before public release whether to issue a one-time coin credit. The current import behavior safely removes the retired ID but does not itself compensate the account. For an internal-only population, documenting the retirement may be sufficient; for paying/public users, a deterministic migration is safer.

## Joker triggers and Sly reactions are clearer without heavy effects

The replacement for full-screen celebration is local, attributable feedback:

- Every proc lifts and outlines the exact Joker card that fired.
- A reusable badge on that Joker displays the trigger label, such as `RETRIGGER` or the applied multiplier.
- The Joker-row status changes from `Watching for triggers` to the most recent Joker and effect, then summarizes the number of triggers for the hand.
- No-proc hands explicitly say `No Joker triggered`, preventing silence from looking like a bug.
- Perf-lite phones keep the transform and hard outline but remove blur/filter cost.
- Joker short descriptions remain visible in the run and shop; tapping remains an optional route to the full effect/engine explanation.

Sly now receives the evaluated poker-hand result at score reveal. The classic expression sprite changes where available. Premium single-frame skins still communicate the reaction through a short card pulse, colored border/glow and a compact label such as `PAIR`, `FLUSH`, `QUADS`, `ROYAL` or `BIG SCORE`. Dialogue is short and game-focused rather than generic praise: it refers to the hand, Mult, target or Heat pressure.

The deep simulation confirms that all 57 Joker definitions are structurally valid and caused no hook exception. Five hooks were not activated by the quick coverage matrix (`sniper`, `tailor`, `doubledown`, `encore`, `redline`). That is a coverage gap, not proof those Jokers are broken. A targeted Joker stress suite should force each condition before public release.

## Mobile layout and art are brighter and more useful

### Home screen

The phone-first menu now prioritizes New Run, provides a compact Best Heat/title status, moves the coin balance into a small top-right badge and presents the remaining destinations with distinctive suit/arcade medallions rather than identical blocks. Shop groups Coin Store and Wardrobe. More groups achievements, local records, Daily Board, Play Games Rankings and help. New Run continues into the Normal/Gauntlet/Daily mode picker.

At widths up to 640 px, the menu uses the available safe viewport, compact gaps and flexible row heights rather than relying on desktop spacing. The Android activity remains portrait and immersive so the status/navigation bars do not permanently consume the game viewport.

### Game screen

The current mobile rules prioritize information needed to play:

- Sly dialogue and Heat/HUD values use larger phone-specific sizes.
- The Joker row has room for names and three lines of short effect text.
- The equation shows hand/rank, value, multiplier and score without the removed Rank Soup/base-detail essay.
- The table sits lower, selected cards lift within the available card area, and adjacent cards retain slightly more separable touch targets while nine cards still fit.
- Play/Discard remain compact; the redundant instruction under Abandon is hidden when empty.
- The deck inspector is a fixed 4 x 13 suit/rank matrix, avoiding a mid-run horizontal scroll.
- Heat intros show modifier name, effect and target together.

### Artwork and color

The default theme's art tint changed from approximately `0.08 / 0.50 / 0.90` alpha stops to `0.01 / 0.24 / 0.64`. Theme-specific bottom tints were reduced similarly, while accent lines and colors were strengthened. This exposes substantially more of the palace, Sly-room and themed artwork without making panels transparent enough to reduce text contrast.

The default menu, shop, chest, victory, Sly's Kingdom and themed screens continue to select real room art. Mobile backgrounds use `background-attachment: scroll` to avoid the costly fixed-background path in Android WebView. Perf-lite also removes decorative blurred layers.

## Externalizing binary assets fixed the apparent monolith

The previous canonical HTML was not large because the game logic required 4.23 MB. Most of the file was fonts and sprite art encoded as data URIs. The v6.9.8 baseline contained 12 inline data URIs (11 Base64 payloads, including four fonts and the large image sheets). v6.9.9 references real files under `www/fonts/` and `www/assets/art/`.

| Measure | v6.9.8 baseline | v6.9.9 | Change |
| --- | ---: | ---: | ---: |
| Canonical `www/index.html` | 4,438,040 bytes | 487,641 bytes | -3,950,399 bytes (-89.01%) |
| Base64 payloads in canonical HTML | 11 | 0 | Removed |
| Remaining inline data URI | 1 small non-Base64 image URI | 1 | Not a binary-size concern |
| Standalone work-laptop HTML | Self-contained | 15,305,562 bytes | Generated by embedding runtime assets intentionally |

Runtime assets include the Bungee and Space Grotesk font files; Sly expression, skin and stage-action grids; the boot logo; cosmic backgrounds; and menu key art. The service worker precaches these files for the installed/web build. `tools/build-standalone-html.js` reverses the externalization only for the portable desktop artifact, embedding the same files and recording canonical-source provenance.

This design gives developers a searchable, diffable ~0.49 MB game source; lets browsers cache art separately from code; avoids re-downloading megabytes of art for a code-only update; and retains a one-file work-laptop playtest when portability matters.

## Runtime architecture and save boundaries

WILDCARD remains a deliberately simple vanilla application rather than a framework rewrite:

1. **Canonical web game:** `www/index.html` contains the HTML, CSS, game data and JavaScript logic. External runtime art/fonts/audio live below `www/assets/` and `www/fonts/`.
2. **Offline/web shell:** `www/sw.js` caches the canonical shell and asset list. The Pi serves this tree and the latest APK through `deploy/update-pi.sh` after a `main` fast-forward.
3. **Portable desktop build:** `tools/build-standalone-html.js` embeds the external assets into `playtest/WILDCARD-work-laptop-standalone.html` and records the source hash.
4. **Android wrapper:** Capacitor copies/syncs the `www` application into the Android project. `MainActivity` owns immersive phone presentation. Capacitor/Cordova plugins provide Preferences, haptics, AdMob and Google Play Billing.
5. **Cloud/Play bridge:** `WildcardCloudPlugin.java` handles optional Firebase Google authentication, owner-scoped Firestore saves and Play Games sign-in, submission, score loading and diagnostics.
6. **Save strategy:** localStorage and Android Preferences remain the primary/offline backstop. Optional Firestore synchronizes the fixed `users/{uid}/saves/main` document after sign-in. Signing in reconciles rather than resets local progress.
7. **Boards:** official daily/weekly/all-time rankings use Play Games. The separately styled WILDCARD Daily Board posts to the Pi API and fails soft when offline.

Scoring and economy data were not split into a new framework or module system in this release. Externalizing binary data delivered the major maintainability and caching benefit with much lower regression risk.

## Firebase, Play Games, ads and billing status

### Firebase: code and Rules are ready for internal-track validation

**Verified in repository/session:** package `com.nisarg.wildcard`, Firebase project `wildcard-31d50`, project number `420107184674`, two expected Android OAuth fingerprints in `google-services.json`, Google Auth/Firestore/App Check dependencies, local-first merge logic and the fixed owner-scoped save path. The repository Google audit finished with zero failures and zero warnings.

The checked-in Firestore Rules permit only authenticated owners to read/create/update `users/{uid}/saves/main`; restrict field names, types and sizes; require the server timestamp; deny deletes; and default-deny every other path. Earlier releases documented 19 hostile emulator allow/deny cases passing. Those Rules tests were **not rerun as part of this report snapshot** and should be run before the release candidate is locked.

**Console-only/unverified:** Google provider state, currently deployed Rules parity, a real signed-in save document, App Check registration/enforcement state, budget alerts and live restore behavior. Keep App Check enforcement off until a build installed from Google Play passes sign-in and Firestore restore; a directly sideloaded build may not receive a Play-recognized Integrity verdict.

### Play Games: bridge and identifiers pass, service state needs Play installation

**Verified in repository/session:** Play Games v2 dependency, application ID `420107184674`, leaderboard ID `CgkIotTbgp0MEAIQAQ`, sign-in/submit/load/open bridge methods, safe diagnostic codes and repository identifier consistency.

**Console-only/unverified:** both signing credentials linked inside Play Games Services (not merely present in Firebase), tester/track access, leaderboard publication to testers, service changes published, and successful daily/weekly/all-time loading from a Play-installed v6.9.9 build. These are P0 internal-test checks.

### AdMob: real placements cannot be enabled without production IDs

The placement and callback logic exists and current native rewarded tests pass. Reward claims are idempotent; revive is checkpointed before the ad; coin double pays once; ad dismissal cannot reverse or duplicate an earned reward.

The current app deliberately uses Google's sample identifiers:

- application ID `ca-app-pub-3940256099942544~3347511713`;
- rewarded unit `ca-app-pub-3940256099942544/5224354917`;
- interstitial unit `ca-app-pub-3940256099942544/1033173712`;
- `AD_TESTING = true`.

These test ads earn **no revenue**. Real ads are possible after the owner supplies the WILDCARD AdMob application, rewarded and interstitial unit IDs; configures consent/privacy messaging; verifies account/payment/policy status; and explicitly changes the production build to non-test mode. No production identifier should be guessed or copied from another app. Use test-device configuration while validating production units.

### Google Play Billing: client integration exists; commercial readiness is unverified

The client registers `coins_250`, `coins_600`, `coins_1600`, `coins_3600`, `coins_8500` and non-consumable `remove_ads`, and includes a purchase-restore path. Repository tests do not prove those products are active, priced or available in Play Console.

Before public monetization, verify every product with Play license testers: success, cancel, pending, reconnect, duplicate callback, consume/acknowledge, reinstall/restore, refund/revoke and Remove Ads restoration. No repository-visible trusted server receipt-validation endpoint was found. That is a fraud/entitlement risk for a public coin economy; either add server verification or explicitly accept and monitor the client-only risk before production.

## Verification completed for this snapshot

| Check | Result | Interpretation |
| --- | --- | --- |
| `npm test` | Pass | Two scripts compiled; 147 unique HTML IDs; source/standalone provenance, external assets, Win FX retirement, cloud, missions, chest and simulation assertions passed. |
| Quick deep simulation | Pass | 57 Jokers, 10,000 scoring cases, 5,000 Cheat cases, 550 full runs; zero data, hook, invariant or Cheat failures. |
| Frostbite regression | Pass | Non-frozen scoring-card selection matched expectation. |
| `npm run test:economy-rewards` | Pass | 10 free/47 paid Jokers; direct catalogue 10,875 coins; daily/vault constants and idempotent reward protections matched. |
| `npm run test:native-ads` | Pass | Native rewarded callback lifecycle passed. |
| `npm run audit:google` | Pass | Version 6.9.9/code 26, Firebase/Play identifiers and both Firebase Android OAuth fingerprints passed with zero warnings. |
| `git diff --check` | Pass | No whitespace errors; only expected local line-ending notices. |
| Browser 390 x 844 Pair smoke | Pass, manual | 1,735 ms Play-to-refill observation, score 35, hands 4 to 3, hand back to 9, no console error. |
| Release APK signature | Pass | APK Signature Scheme v2; one RSA signer; certificate SHA-256 `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717`. |
| Android release APK/AAB build | Pass | Signed artifacts exist for version code 26. |
| Android developer APK build | Pass | Code 27 artifact exists for future in-place local testing. |
| Firestore hostile Rules suite | Previously passed, not fresh | Earlier report records 19/19; rerun for release lock. |
| Play-installed device validation | Pending | Required for Auth, Firestore, App Check, Play Games, Billing and production-like ads. |
| High-volume Joker condition stress | Pending | Quick sim did not activate five condition-specific hooks. |
| Fresh 180-day economy model | Pass | All nine economy gates passed for v6.9.9; report and JSON are included under `docs/release/`. |

The v6.9.9 quick simulation was generated from the live source on 16 July 2026 in 79.51 seconds. Its cohort outputs are diagnostic, not human-retention forecasts. In particular, the standard free-pool bot won 0.67% of 150 runs versus 28% for the all-unlocked bot. This may indicate a difficult starter curve, but the bots are not human skill or retention telemetry; closed-test feedback should decide whether balance changes are needed.

## Release gates and recommended pipeline

### P0 before the Internal testing upload

1. Commit the exact v6.9.9 source, generated standalone, tests, report and release notes; push the branch; open/review the PR; merge or otherwise make the selected commit authoritative.
2. Regenerate APK/AAB after the final commit and populate the final artifact manifest below. Confirm source-to-standalone provenance and signature again.
3. Run the fresh Firestore Rules emulator suite and the requested high-volume Joker/economy stress prompt. Investigate any condition-specific Joker that cannot be forced to trigger.
4. Perform one physical-device smoke if the phone becomes available: menu fit, card touch selection, selected-card lift, typical Pair/Flush/multi-Joker scoring, deck matrix, Sly reactions, rewarded failure recovery, safe-area/immersive behavior and save preservation.

### Internal testing first

Upload the code-26 AAB to Google Play **Internal testing**, not Production. Install from the Play opt-in link using the exact tester account, then validate:

- existing guest progress survives the upgrade;
- optional Google sign-in links rather than resets the local save;
- Firestore writes/reads the expected owner document and restores after an offline change;
- Play Integrity/App Check produces the expected verdict before enforcement is enabled;
- Play Games signs in, submits a legitimate score and loads Daily, Weekly and All Time;
- all Billing products appear and license-test purchase/restore behavior works;
- rewarded/interstitial placements settle correctly (test IDs until real IDs are supplied);
- no scoring hitch appears during longer sessions or multi-Joker/retrigger hands.

### Then use 14 testers while continuing noncritical polish

After the owner-device internal checks pass, move immediately to a closed test with **14 reliable testers**. If the personal developer account is subject to Google Play's production-access gate, the live Play Console eligibility screen is authoritative; 14 is recommended as a buffer above a possible 12-tester/14-continuous-day minimum. Do not wait for perfect decorative polish before gathering real-device evidence. Freeze scoring/economy unless a test proves a defect; continue only low-risk presentation fixes during the cohort.

Collect device model/Android version, install source, session length, Heat reached, scoring-latency complaints, save/sign-in outcome, Play Games outcome, ad outcome, purchase outcome and screenshots/logs for every failure. With Analytics and Crashlytics currently disabled, this structured manual log is the minimum viable beta telemetry.

### Public release remains blocked by external validation

Public production should wait for:

- successful Play-distributed Auth/Firestore/App Check/Play Games testing;
- real AdMob IDs and consent configuration if ads are intended to earn revenue;
- Play Billing product activation plus entitlement/receipt-security decision;
- closed-test completion/production-access approval where required;
- final store listing, Data safety, privacy policy, content rating, ads declaration and app-access review;
- a restore/uninstall plan proving players cannot lose progress;
- a decision on compensation for retired Win FX ownership, if any real players own it.

## Security and workpack exclusions

The source workpack should be reproducible without distributing credentials. Include tracked application source, Android/Gradle configuration, Firebase Rules/indexes, docs, tools, artwork, package lockfiles, deploy scripts and the portable playtest README/build where appropriate.

Exclude:

- `.git/`, `node_modules/`, Gradle/build caches and IDE folders;
- `android/local.properties` and machine-specific SDK paths;
- `wildcard-release.keystore`, `*.jks`, `keystore-password.txt` and all signing/password material;
- SSH private keys, Pi deploy keys, access tokens, cookies and personal attachments;
- generated Android build directories, developer APKs and redundant historical release binaries unless the recipient explicitly needs them;
- temporary audit files, logs and unrelated untracked user files.

`android/app/google-services.json` contains public Firebase project/app configuration, not an administrative credential, and is needed for a reproducible Android build. Its API key should still be restricted in Google Cloud/Firebase to the required Android package/certificates and APIs. Never include service-account JSON, OAuth client secrets, ID/access tokens or private save documents in the archive/report.

## Reproducible validation and build commands

Run from the repository root in PowerShell with Node.js, Java and Android SDK installed:

```powershell
npm ci
npm run build:standalone

$env:SIM_QUICK = '1'
npm run test:deep
Remove-Item Env:SIM_QUICK

npm test
npm run test:economy-rewards
npm run test:native-ads
npm run audit:google
npm run test:rules
git diff --check
```

Run the full economy model for the final evidence package:

```powershell
npm run test:economy
```

Build Android artifacts only after the source/tests are final:

```powershell
npm run sync:android
npm run build:android:release
npm run build:android:developer
Push-Location android
.\gradlew.bat :app:bundleRelease
Pop-Location
```

Verify and hash final artifacts (adjust the Android SDK build-tools path if necessary):

```powershell
& 'C:\Android\sdk\build-tools\35.0.0\apksigner.bat' verify --verbose --print-certs releases\WILDCARD-v6.9.9.apk
Get-FileHash -Algorithm SHA256 www\index.html,releases\WILDCARD-v6.9.9.apk,releases\WILDCARD-v6.9.9.aab,playtest\WILDCARD-work-laptop-standalone.html
git rev-parse HEAD
git status --short --branch
```

## Final artifact manifest

These hashes were recorded after the final signed build. If canonical game source changes, rebuild and replace every dependent hash.

| Artifact | Version/code | Size | SHA-256 / identity |
| --- | --- | ---: | --- |
| Canonical `www/index.html` | v6.9.9 | 487,834 bytes | `64bbcfe2e2141260bf8ed948af12ad5db7f1e3cfe3d5b8e62555ee3244b642c3` |
| Standalone HTML | v6.9.9 | 15,305,755 bytes | `e900609e41b084b2197e2c652c2bca8c6e4bd5534f94b86b34afc8c229e73cfc` |
| Release APK | 6.9.9 / 26 | 23,005,184 bytes | `7ef00910252f6ba547651ec851c32a43b2be051da3a6fbd940d264f4b97b55a2` |
| Release AAB | 6.9.9 / 26 | 22,630,772 bytes | `8f5445ec05ab561ca93471e0586eb7ceccb4d3909f15738d87a97ca5a7771246` |
| Developer APK | 6.9.9 / 27 | 23,006,600 bytes | `cbf827155eea49680415c31e39728563232d205e27443cbec5403e0b07ad9291` |
| Release signing certificate | shared release identity | - | `c3c281d1470aebf2d99656221ada7815c6b873f4e8a748d7284f5fae5d764717` |
| Source workpack ZIP | published branch | Recorded in the delivery email | Computed after the clean Git archive is created, so the archive does not claim its own circular hash |

The release APK was additionally verified with APK Signature Scheme v2 and reports package `com.nisarg.wildcard`, version `6.9.9`, code `26`, min SDK 24 and target SDK 36.

## Remaining questions that can change the release decision

1. Are the real WILDCARD AdMob application/rewarded/interstitial unit IDs available, and has the account completed consent/payment/policy setup?
2. Are all six Play Billing products active and license-testable, and will public entitlement validation be client-only or server-backed?
3. Does the Play-installed v6.9.9 build pass Google account linking, Firestore restore, Play Integrity and all three Play Games spans on the intended tester account?
4. Does the live Play Console require the personal-account closed-test production-access gate, and what exact cohort status does its eligibility screen show?
5. Do targeted tests activate the five condition-specific Joker hooks absent from quick-sim coverage?
6. Does closed-test human play confirm the starter-pool difficulty, or is the 0.67% bot win rate an artifact of bot policy?
7. Did any non-developer account acquire a retired Win FX cosmetic, requiring a deterministic coin credit?

## Evidence map

The principal repository evidence for this report is:

- `www/index.html` - live v6.9.9 game, mobile styling, scoring, cosmetics, ads and billing registration.
- `android/app/build.gradle` - release/developer version codes, Firebase/Play dependencies and signing configuration shape.
- `android/app/src/main/java/com/nisarg/wildcard/WildcardCloudPlugin.java` - Google/Firebase cloud save and Play Games native bridge.
- `android/app/src/main/java/com/nisarg/wildcard/WildcardApplication.java` - Firebase/App Check and Play Games initialization.
- `android/app/src/main/AndroidManifest.xml` - Android app metadata and current AdMob test application ID.
- `firestore.rules` and `docs/FIREBASE.md` - owner-only save model, Rules contract and console caveats.
- `tools/verify-v68.js` - executable release invariants, including full Win FX retirement and asset externalization.
- `docs/release/wildcard-v6.9.9-sim-results.json` and `docs/release/wildcard-v6.9.9-sim-report.md` - quick deep-simulation results.
- `docs/release/wildcard-v6.9.8-economy-report.md` and `docs/release/WILDCARD-v6.9.8-fix-notes.md` - unchanged economy/reward baseline and prior high-volume evidence.
- `docs/release/WILDCARD-v6.8-fix-notes.md` through `WILDCARD-v6.9.7-fix-notes.md` - feature and verification history.
- `deploy/update-pi.sh` and `tools/build-standalone-html.js` - Pi and portable-build reproducibility.

The report distinguishes repository-verifiable behavior from authenticated console state throughout. A passing source audit is not represented as proof that an unpublished or misconfigured Google/AdMob/Play Console service works in production.
